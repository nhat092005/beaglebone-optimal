#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/gpio/consumer.h>
#include <linux/hwmon.h>
#include <linux/iio/consumer.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/timekeeping.h>
#include <linux/jiffies.h>
#include <linux/i2c.h>
#include <linux/device.h>
#include <linux/sysfs.h>
#include <linux/backlight.h>

#define OP_ENV_IOC_MAGIC  'O'
#define OP_ENV_IOCTL_TEST_ALARM_ON    _IO(OP_ENV_IOC_MAGIC, 1)
#define OP_ENV_IOCTL_TEST_ALARM_OFF   _IO(OP_ENV_IOC_MAGIC, 2)
#define OP_ENV_IOCTL_CLEAR_HISTORY    _IO(OP_ENV_IOC_MAGIC, 3)
#define OP_ENV_IOCTL_TRIGGER_MEASURE  _IO(OP_ENV_IOC_MAGIC, 4)

struct env_record {
	u64 timestamp_ms;
	s32 temperature;
	s32 humidity;
	s32 lux;
} __packed;

#define RECORD_COUNT 10
static struct env_record ring_buffer[RECORD_COUNT];
static int ring_buffer_head = 0;
static int ring_buffer_count = 0;
static DEFINE_MUTEX(buffer_mutex);

static void push_record(u64 time_ms, s32 temp, s32 humid, s32 lux)
{
	mutex_lock(&buffer_mutex);
	ring_buffer[ring_buffer_head].timestamp_ms = time_ms;
	ring_buffer[ring_buffer_head].temperature = temp;
	ring_buffer[ring_buffer_head].humidity = humid;
	ring_buffer[ring_buffer_head].lux = lux;
	ring_buffer_head = (ring_buffer_head + 1) % RECORD_COUNT;
	if (ring_buffer_count < RECORD_COUNT)
		ring_buffer_count++;
	mutex_unlock(&buffer_mutex);
}

static int alarm_state = 0;
static int night_mode = 0;
static int sensor_status = 0;

static int temp_alarm_limit = 45;
static int humid_alarm_limit = 80;
static int lux_dark_limit = 10;
static int lux_light_limit = 15;

static bool test_alarm_mode = false;
static unsigned long test_mode_expires = 0;

static DEFINE_SPINLOCK(state_lock);

#define MAX_LEDS 3
static struct gpio_desc *leds[MAX_LEDS];
static int led_count = 0;

static struct i2c_client *sht3x_client = NULL;
static struct device *hwmon_dev = NULL;
static struct iio_channel *lux_chan = NULL;
static struct backlight_device *bd = NULL;

static struct task_struct *monitor_task = NULL;
static DECLARE_WAIT_QUEUE_HEAD(measure_wait);
static bool trigger_measure = false;

static dev_t dev_num;
static struct cdev optimal_cdev;
static struct class *optimal_class = NULL;
static struct device *optimal_device = NULL;

static u8 sht3x_crc8(const u8 *data, size_t len)
{
	u8 crc = 0xFF;
	size_t i, j;

	for (i = 0; i < len; i++) {
		crc ^= data[i];
		for (j = 0; j < 8; j++) {
			if (crc & 0x80)
				crc = (crc << 1) ^ 0x31;
			else
				crc <<= 1;
		}
	}
	return crc;
}

static int sht3x_read_temp_humid(struct i2c_client *client, int *temp, int *humid)
{
	u8 cmd[2] = { 0x24, 0x00 }; /* High repeatability, clock stretching disabled */
	u8 buf[6];
	int ret;
	u16 raw_temp, raw_humid;

	ret = i2c_master_send(client, cmd, 2);
	if (ret < 0) {
		dev_err(&client->dev, "SHT3x send command failed: %d\n", ret);
		return ret;
	} else if (ret != 2) {
		dev_err(&client->dev, "SHT3x send command short write: %d\n", ret);
		return -EIO;
	}

	msleep(20);

	ret = i2c_master_recv(client, buf, 6);
	if (ret < 0) {
		dev_err(&client->dev, "SHT3x read data failed: %d\n", ret);
		return ret;
	} else if (ret != 6) {
		dev_err(&client->dev, "SHT3x read data short read: %d\n", ret);
		return -EIO;
	}

	if (sht3x_crc8(buf, 2) != buf[2]) {
		dev_err(&client->dev, "SHT3x temp CRC mismatch\n");
		return -EBADMSG;
	}
	if (sht3x_crc8(buf + 3, 2) != buf[5]) {
		dev_err(&client->dev, "SHT3x humid CRC mismatch\n");
		return -EBADMSG;
	}

	raw_temp = (buf[0] << 8) | buf[1];
	raw_humid = (buf[3] << 8) | buf[4];

	/* Formulas from SHT3x datasheet:
	 * T_milli = -45000 + (175000 * raw_temp) / 65535
	 * H_milli = (100000 * raw_humid) / 65535
	 */
	*temp = (int)(-45000 + (175000 * (u32)raw_temp) / 65535);
	*humid = (int)((100000 * (u32)raw_humid) / 65535);

	return 0;
}

static umode_t optimal_hwmon_is_visible(const void *drvdata, enum hwmon_sensor_types type,
					u32 attr, int channel)
{
	if (type == hwmon_temp && attr == hwmon_temp_input)
		return 0444;
	if (type == hwmon_humidity && attr == hwmon_humidity_input)
		return 0444;
	return 0;
}

static int optimal_hwmon_read(struct device *dev, enum hwmon_sensor_types type,
			      u32 attr, int channel, long *val)
{
	if (type == hwmon_temp && attr == hwmon_temp_input) {
		mutex_lock(&buffer_mutex);
		if (ring_buffer_count > 0) {
			int last_idx = (ring_buffer_head - 1 + RECORD_COUNT) % RECORD_COUNT;
			*val = ring_buffer[last_idx].temperature * 1000;
		} else {
			*val = 0;
		}
		mutex_unlock(&buffer_mutex);
		return 0;
	}
	if (type == hwmon_humidity && attr == hwmon_humidity_input) {
		mutex_lock(&buffer_mutex);
		if (ring_buffer_count > 0) {
			int last_idx = (ring_buffer_head - 1 + RECORD_COUNT) % RECORD_COUNT;
			*val = ring_buffer[last_idx].humidity * 1000;
		} else {
			*val = 0;
		}
		mutex_unlock(&buffer_mutex);
		return 0;
	}
	return -EINVAL;
}

static const struct hwmon_ops optimal_hwmon_ops = {
	.is_visible = optimal_hwmon_is_visible,
	.read = optimal_hwmon_read,
};

static const struct hwmon_channel_info *const optimal_hwmon_info[] = {
	HWMON_CHANNEL_INFO(chip, HWMON_C_REGISTER_TZ),
	HWMON_CHANNEL_INFO(temp, HWMON_T_INPUT),
	HWMON_CHANNEL_INFO(humidity, HWMON_H_INPUT),
	NULL
};

static const struct hwmon_chip_info optimal_hwmon_chip_info = {
	.ops = &optimal_hwmon_ops,
	.info = optimal_hwmon_info,
};

static ssize_t temperature_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int temp = 0;
	mutex_lock(&buffer_mutex);
	if (ring_buffer_count > 0) {
		int last_idx = (ring_buffer_head - 1 + RECORD_COUNT) % RECORD_COUNT;
		temp = ring_buffer[last_idx].temperature;
	}
	mutex_unlock(&buffer_mutex);
	return sysfs_emit(buf, "%d\n", temp);
}
static DEVICE_ATTR_RO(temperature);

static ssize_t humidity_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int humid = 0;
	mutex_lock(&buffer_mutex);
	if (ring_buffer_count > 0) {
		int last_idx = (ring_buffer_head - 1 + RECORD_COUNT) % RECORD_COUNT;
		humid = ring_buffer[last_idx].humidity;
	}
	mutex_unlock(&buffer_mutex);
	return sysfs_emit(buf, "%d\n", humid);
}
static DEVICE_ATTR_RO(humidity);

static ssize_t lux_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int lx = 0;
	mutex_lock(&buffer_mutex);
	if (ring_buffer_count > 0) {
		int last_idx = (ring_buffer_head - 1 + RECORD_COUNT) % RECORD_COUNT;
		lx = ring_buffer[last_idx].lux;
	}
	mutex_unlock(&buffer_mutex);
	return sysfs_emit(buf, "%d\n", lx);
}
static DEVICE_ATTR_RO(lux);

static ssize_t temp_alarm_limit_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = temp_alarm_limit;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t temp_alarm_limit_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	int val, ret;
	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&state_lock);
	temp_alarm_limit = val;
	spin_unlock(&state_lock);
	return count;
}
static DEVICE_ATTR_RW(temp_alarm_limit);

static ssize_t humid_alarm_limit_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = humid_alarm_limit;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t humid_alarm_limit_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	int val, ret;
	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&state_lock);
	humid_alarm_limit = val;
	spin_unlock(&state_lock);
	return count;
}
static DEVICE_ATTR_RW(humid_alarm_limit);

static ssize_t lux_dark_limit_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = lux_dark_limit;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t lux_dark_limit_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	int val, ret;
	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&state_lock);
	lux_dark_limit = val;
	spin_unlock(&state_lock);
	return count;
}
static DEVICE_ATTR_RW(lux_dark_limit);

static ssize_t lux_light_limit_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = lux_light_limit;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t lux_light_limit_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	int val, ret;
	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&state_lock);
	lux_light_limit = val;
	spin_unlock(&state_lock);
	return count;
}
static DEVICE_ATTR_RW(lux_light_limit);

static ssize_t alarm_state_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = alarm_state;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(alarm_state);

static ssize_t night_mode_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = night_mode;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(night_mode);

static ssize_t sensor_status_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int val;
	spin_lock(&state_lock);
	val = sensor_status;
	spin_unlock(&state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(sensor_status);

static struct attribute *optimal_attrs[] = {
	&dev_attr_temperature.attr,
	&dev_attr_humidity.attr,
	&dev_attr_lux.attr,
	&dev_attr_temp_alarm_limit.attr,
	&dev_attr_humid_alarm_limit.attr,
	&dev_attr_lux_dark_limit.attr,
	&dev_attr_lux_light_limit.attr,
	&dev_attr_alarm_state.attr,
	&dev_attr_night_mode.attr,
	&dev_attr_sensor_status.attr,
	NULL,
};

static const struct attribute_group optimal_attr_group = {
	.attrs = optimal_attrs,
};

static ssize_t optimal_env_read(struct file *file, char __user *buf, size_t count, loff_t *ppos)
{
	struct env_record temp_buf[RECORD_COUNT];
	size_t total_size;
	int i, idx;

	mutex_lock(&buffer_mutex);
	if (ring_buffer_count == 0) {
		mutex_unlock(&buffer_mutex);
		return 0;
	}

	idx = (ring_buffer_head - ring_buffer_count + RECORD_COUNT) % RECORD_COUNT;
	for (i = 0; i < ring_buffer_count; i++) {
		temp_buf[i] = ring_buffer[idx];
		idx = (idx + 1) % RECORD_COUNT;
	}
	total_size = ring_buffer_count * sizeof(struct env_record);
	mutex_unlock(&buffer_mutex);

	if (*ppos >= total_size)
		return 0;

	if (count > total_size - *ppos)
		count = total_size - *ppos;

	if (copy_to_user(buf, (char *)temp_buf + *ppos, count))
		return -EFAULT;

	*ppos += count;
	return count;
}

static long optimal_env_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	if (!capable(CAP_SYS_ADMIN))
		return -EPERM;

	switch (cmd) {
	case OP_ENV_IOCTL_TEST_ALARM_ON:
		spin_lock(&state_lock);
		test_alarm_mode = true;
		test_mode_expires = jiffies + 60 * HZ;
		spin_unlock(&state_lock);
		wake_up_interruptible(&measure_wait);
		break;

	case OP_ENV_IOCTL_TEST_ALARM_OFF:
		spin_lock(&state_lock);
		test_alarm_mode = false;
		spin_unlock(&state_lock);
		wake_up_interruptible(&measure_wait);
		break;

	case OP_ENV_IOCTL_CLEAR_HISTORY:
		mutex_lock(&buffer_mutex);
		ring_buffer_head = 0;
		ring_buffer_count = 0;
		memset(ring_buffer, 0, sizeof(ring_buffer));
		mutex_unlock(&buffer_mutex);
		break;

	case OP_ENV_IOCTL_TRIGGER_MEASURE:
		trigger_measure = true;
		wake_up_interruptible(&measure_wait);
		break;

	default:
		return -ENOTTY;
	}
	return 0;
}

static const struct file_operations optimal_env_fops = {
	.owner = THIS_MODULE,
	.read = optimal_env_read,
	.unlocked_ioctl = optimal_env_ioctl,
};

static int optimal_bl_update_status(struct backlight_device *bd_dev)
{
	return 0;
}

static const struct backlight_ops optimal_bl_ops = {
	.update_status = optimal_bl_update_status,
};

static int optimal_env_thread(void *data)
{
	struct device *dev = (struct device *)data;
	int temp, humid, lux;
	int ret;
	int bh1750_lux = 0;
	u64 now_ms;
	struct timespec64 ts;
	int i;
	int alarm, night;
	int fault_status;

	while (!kthread_should_stop()) {
		wait_event_interruptible_timeout(measure_wait, trigger_measure || kthread_should_stop(), HZ);
		trigger_measure = false;

		if (kthread_should_stop())
			break;

		temp = 0;
		humid = 0;
		fault_status = 0;

		if (sht3x_client) {
			int t_milli = 0, h_milli = 0;
			ret = sht3x_read_temp_humid(sht3x_client, &t_milli, &h_milli);
			if (ret < 0) {
				fault_status |= 1;
			} else {
				temp = t_milli / 1000;
				humid = h_milli / 1000;
			}
		} else {
			fault_status |= 1;
		}

		lux = 0;
		if (lux_chan) {
			ret = iio_read_channel_raw(lux_chan, &bh1750_lux);
			if (ret < 0) {
				fault_status |= 2;
			} else {
				lux = bh1750_lux;
			}
		} else {
			fault_status |= 2;
		}

		ktime_get_real_ts64(&ts);
		now_ms = (u64)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;

		if (fault_status == 0) {
			push_record(now_ms, temp, humid, lux);
		}

		spin_lock(&state_lock);

		alarm = 0;
		if (fault_status == 0) {
			if (temp >= temp_alarm_limit || humid >= humid_alarm_limit) {
				alarm = 1;
			}
		}

		if (test_alarm_mode) {
			if (time_after(jiffies, test_mode_expires)) {
				test_alarm_mode = false;
			} else {
				alarm = 1;
			}
		}

		night = night_mode;
		if (fault_status == 0) {
			if (lux < lux_dark_limit) {
				night = 1;
			} else if (lux > lux_light_limit) {
				night = 0;
			}
		}

		if (alarm != alarm_state) {
			alarm_state = alarm;
			sysfs_notify(&optimal_device->kobj, NULL, "alarm_state");
		}

		if (night != night_mode) {
			night_mode = night;
			sysfs_notify(&optimal_device->kobj, NULL, "night_mode");
		}

		if (fault_status != sensor_status) {
			sensor_status = fault_status;
			sysfs_notify(&optimal_device->kobj, NULL, "sensor_status");
		}

		spin_unlock(&state_lock);

		if (bd && fault_status == 0) {
			int brightness = 20 + (lux * (255 - 20)) / 1000;
			if (brightness > 255)
				brightness = 255;
			if (brightness < 20)
				brightness = 20;
			bd->props.brightness = brightness;
			backlight_update_status(bd);
		}

		if (alarm_state) {
			for (i = 0; i < led_count; i++) {
				gpiod_set_value(leds[i], 1);
			}
			msleep(100);
			for (i = 0; i < led_count; i++) {
				gpiod_set_value(leds[i], 0);
			}
			msleep(100);
		} else if (sensor_status != 0) {
			static int running_led = 0;
			for (i = 0; i < led_count; i++) {
				gpiod_set_value(leds[i], (i == running_led));
			}
			running_led = (running_led + 1) % led_count;
			msleep(500);
		} else {
			gpiod_set_value(leds[0], 0);
			gpiod_set_value(leds[1], night_mode);

			gpiod_set_value(leds[2], 1);
			msleep(50);
			gpiod_set_value(leds[2], 0);
		}
	}

	for (i = 0; i < led_count; i++) {
		gpiod_set_value(leds[i], 0);
	}
	return 0;
}

static int optimal_env_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *sensor_node;
	struct backlight_properties props;
	int ret;
	int i;

	led_count = gpiod_count(dev, "status");
	if (led_count < 0) {
		dev_err(dev, "Failed to get LED count\n");
		return led_count;
	}
	if (led_count > MAX_LEDS)
		led_count = MAX_LEDS;

	for (i = 0; i < led_count; i++) {
		leds[i] = devm_gpiod_get_index(dev, "status", i, GPIOD_OUT_LOW);
		if (IS_ERR(leds[i])) {
			dev_err(dev, "Failed to get LED %d\n", i);
			return PTR_ERR(leds[i]);
		}
	}

	lux_chan = devm_iio_channel_get(dev, "lux");
	if (IS_ERR(lux_chan)) {
		if (PTR_ERR(lux_chan) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		dev_warn(dev, "Failed to get IIO channel 'lux': %ld\n", PTR_ERR(lux_chan));
		lux_chan = NULL;
	}

	sensor_node = of_parse_phandle(dev->of_node, "hwmon-sensor", 0);
	if (sensor_node) {
		struct device *sensor_dev = bus_find_device_by_of_node(&i2c_bus_type, sensor_node);
		of_node_put(sensor_node);
		if (sensor_dev) {
			sht3x_client = to_i2c_client(sensor_dev);
		} else {
			dev_warn(dev, "Failed to find SHT3x I2C client device, deferring probe\n");
			return -EPROBE_DEFER;
		}
	} else {
		dev_err(dev, "Missing 'hwmon-sensor' phandle in device tree\n");
		return -EINVAL;
	}

	ret = alloc_chrdev_region(&dev_num, 0, 1, "optimal_env");
	if (ret < 0) {
		dev_err(dev, "Failed to allocate chrdev region\n");
		goto err_put_sensor;
	}
	cdev_init(&optimal_cdev, &optimal_env_fops);
	optimal_cdev.owner = THIS_MODULE;
	ret = cdev_add(&optimal_cdev, dev_num, 1);
	if (ret < 0) {
		dev_err(dev, "Failed to add cdev\n");
		goto err_unregister_chrdev;
	}

	optimal_class = class_create("optimal-env");
	if (IS_ERR(optimal_class)) {
		ret = PTR_ERR(optimal_class);
		goto err_cdev_del;
	}

	optimal_device = device_create(optimal_class, dev, dev_num, NULL, "optimal_env");
	if (IS_ERR(optimal_device)) {
		ret = PTR_ERR(optimal_device);
		goto err_class_destroy;
	}

	ret = sysfs_create_group(&optimal_device->kobj, &optimal_attr_group);
	if (ret < 0) {
		goto err_device_destroy;
	}

	hwmon_dev = devm_hwmon_device_register_with_info(dev, "sht3x", NULL, &optimal_hwmon_chip_info, NULL);
	if (IS_ERR(hwmon_dev)) {
		ret = PTR_ERR(hwmon_dev);
		dev_err(dev, "Failed to register hwmon device: %d\n", ret);
		goto err_sysfs_remove;
	}

	memset(&props, 0, sizeof(props));
	props.type = BACKLIGHT_RAW;
	props.max_brightness = 255;
	props.brightness = 255;
	bd = devm_backlight_device_register(dev, "optimal_backlight", dev, NULL, &optimal_bl_ops, &props);
	if (IS_ERR(bd)) {
		dev_err(dev, "Failed to register backlight device\n");
		bd = NULL;
	}

	monitor_task = kthread_run(optimal_env_thread, dev, "optimal_env_monitor");
	if (IS_ERR(monitor_task)) {
		ret = PTR_ERR(monitor_task);
		monitor_task = NULL;
		goto err_sysfs_remove;
	}

	dev_info(dev, "Optimal Environment Manager probed successfully\n");
	return 0;

err_sysfs_remove:
	sysfs_remove_group(&optimal_device->kobj, &optimal_attr_group);
err_device_destroy:
	device_destroy(optimal_class, dev_num);
err_class_destroy:
	class_destroy(optimal_class);
err_cdev_del:
	cdev_del(&optimal_cdev);
err_unregister_chrdev:
	unregister_chrdev_region(dev_num, 1);
err_put_sensor:
	if (sht3x_client) {
		put_device(&sht3x_client->dev);
		sht3x_client = NULL;
	}
	return ret;
}

static int optimal_env_remove(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	int i;

	if (monitor_task) {
		kthread_stop(monitor_task);
		monitor_task = NULL;
	}

	if (optimal_device && !IS_ERR(optimal_device)) {
		sysfs_remove_group(&optimal_device->kobj, &optimal_attr_group);
		device_destroy(optimal_class, dev_num);
	}

	if (optimal_class && !IS_ERR(optimal_class)) {
		class_destroy(optimal_class);
	}

	cdev_del(&optimal_cdev);
	unregister_chrdev_region(dev_num, 1);

	for (i = 0; i < led_count; i++) {
		gpiod_set_value(leds[i], 0);
	}

	if (sht3x_client) {
		put_device(&sht3x_client->dev);
		sht3x_client = NULL;
	}

	dev_info(dev, "Optimal Environment Manager removed successfully\n");
	return 0;
}

static const struct of_device_id optimal_env_of_match[] = {
	{ .compatible = "optimal,env-manager" },
	{ }
};
MODULE_DEVICE_TABLE(of, optimal_env_of_match);

static struct platform_driver optimal_env_driver = {
	.driver = {
		.name = "optimal-env-manager",
		.of_match_table = optimal_env_of_match,
	},
	.probe = optimal_env_probe,
	.remove = optimal_env_remove,
};

module_platform_driver(optimal_env_driver);

MODULE_AUTHOR("Antigravity Team");
MODULE_DESCRIPTION("Optimal Environment and Power Manager Kernel Module");
MODULE_LICENSE("GPL");
