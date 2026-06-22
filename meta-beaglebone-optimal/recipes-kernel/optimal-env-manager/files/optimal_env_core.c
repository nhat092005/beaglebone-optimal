#include "optimal_env_core.h"

void push_record(struct optimal_env_priv *priv, u64 time_ms, s32 temp,
		 s32 humid, s32 lux)
{
	mutex_lock(&priv->buffer_mutex);
	priv->ring_buffer[priv->ring_buffer_head].timestamp_ms = time_ms;
	priv->ring_buffer[priv->ring_buffer_head].temperature = temp;
	priv->ring_buffer[priv->ring_buffer_head].humidity = humid;
	priv->ring_buffer[priv->ring_buffer_head].lux = lux;
	priv->ring_buffer_head = (priv->ring_buffer_head + 1) % RECORD_COUNT;
	if (priv->ring_buffer_count < RECORD_COUNT)
		priv->ring_buffer_count++;
	mutex_unlock(&priv->buffer_mutex);
}

static int optimal_bl_update_status(struct backlight_device *bd_dev)
{
	return 0;
}

static const struct backlight_ops optimal_bl_ops = {
	.update_status = optimal_bl_update_status,
};

static int optimal_env_thread(void *data)
{
	struct optimal_env_priv *priv = (struct optimal_env_priv *)data;
	int temp = 0, humid = 0, lux = 0;
	int ret;
	int bh1750_lux = 0;
	u64 now_ms;
	struct timespec64 ts;
	int i;
	int temp_alarm = 0, humid_alarm = 0, alarm, night;
	int fault_status = 0;
	unsigned long next_sensor_read = jiffies;

	while (!kthread_should_stop()) {
		if (time_is_before_eq_jiffies(next_sensor_read) ||
		    priv->trigger_measure) {
			priv->trigger_measure = false;
			next_sensor_read = jiffies + HZ;

			temp = 0;
			humid = 0;
			fault_status = 0;

			if (priv->sht3x_client) {
				int t_milli = 0, h_milli = 0;
				ret = sht3x_read_temp_humid(priv->sht3x_client,
							    &t_milli, &h_milli);
				if (ret < 0) {
					fault_status |= 1;
				} else {
					temp = t_milli;
					humid = h_milli;
				}
			} else {
				fault_status |= 1;
			}

			lux = 0;
			if (priv->lux_chan) {
				ret = iio_read_channel_raw(priv->lux_chan,
							   &bh1750_lux);
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
				push_record(priv, now_ms, temp, humid, lux);
			}

			spin_lock(&priv->state_lock);

			temp_alarm = 0;
			humid_alarm = 0;
			if (fault_status == 0) {
				if (temp >= priv->temp_alarm_limit * 1000) {
					temp_alarm = 1;
				}
				if (humid >= priv->humid_alarm_limit * 1000) {
					humid_alarm = 1;
				}
			}

			alarm = temp_alarm || humid_alarm;

			night = priv->night_mode;
			if (fault_status == 0) {
				if (lux < priv->lux_alarm_limit) {
					night = 1;
				} else {
					night = 0;
				}
			}

			if (alarm != priv->alarm_state) {
				priv->alarm_state = alarm;
				sysfs_notify(&priv->optimal_device->kobj, NULL,
					     "alarm_state");
			}

			if (night != priv->night_mode) {
				priv->night_mode = night;
				sysfs_notify(&priv->optimal_device->kobj, NULL,
					     "night_mode");
			}

			if (fault_status != priv->sensor_status) {
				priv->sensor_status = fault_status;
				sysfs_notify(&priv->optimal_device->kobj, NULL,
					     "sensor_status");
			}

			spin_unlock(&priv->state_lock);

			if (priv->bd && fault_status == 0) {
				int brightness = 20 + (lux * (255 - 20)) / 1000;
				if (brightness > 255)
					brightness = 255;
				if (brightness < 20)
					brightness = 20;
				priv->bd->props.brightness = brightness;
				backlight_update_status(priv->bd);
			}
		}

		if (priv->alarm_state) {
			if (temp_alarm)
				gpiod_set_value(priv->leds[0], 1);
			if (humid_alarm)
				gpiod_set_value(priv->leds[1], 1);
			msleep(50);
			if (temp_alarm)
				gpiod_set_value(priv->leds[0], 0);
			if (humid_alarm)
				gpiod_set_value(priv->leds[1], 0);
			msleep(50);
		} else if (priv->sensor_status != 0) {
			static int toggle = 0;
			gpiod_set_value(priv->leds[0], toggle);
			gpiod_set_value(priv->leds[1], !toggle);
			toggle = !toggle;
			msleep(500);
		} else {
			gpiod_set_value(priv->leds[0], 0);
			gpiod_set_value(priv->leds[1], 0);
			wait_event_interruptible_timeout(
				priv->measure_wait,
				priv->trigger_measure || kthread_should_stop(),
				HZ);
		}
	}

	for (i = 0; i < priv->led_count; i++) {
		gpiod_set_value(priv->leds[i], 0);
	}
	return 0;
}

static int optimal_env_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct optimal_env_priv *priv;
	struct backlight_properties props;
	int ret;
	int i;

	priv = devm_kzalloc(dev, sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->dev = dev;
	platform_set_drvdata(pdev, priv);

	spin_lock_init(&priv->state_lock);
	mutex_init(&priv->buffer_mutex);
	init_waitqueue_head(&priv->measure_wait);

	priv->temp_alarm_limit = 45;
	priv->humid_alarm_limit = 80;
	priv->lux_alarm_limit = 20;

	priv->led_count = gpiod_count(dev, "status");
	if (priv->led_count < 0) {
		dev_err(dev, "Failed to get LED count\n");
		return priv->led_count;
	}
	if (priv->led_count > MAX_LEDS)
		priv->led_count = MAX_LEDS;

	for (i = 0; i < priv->led_count; i++) {
		priv->leds[i] =
			devm_gpiod_get_index(dev, "status", i, GPIOD_OUT_LOW);
		if (IS_ERR(priv->leds[i])) {
			dev_err(dev, "Failed to get LED %d\n", i);
			return PTR_ERR(priv->leds[i]);
		}
	}

	/* Initialize Sensors (SHT3x and BH1750 IIO) */
	ret = optimal_env_sensors_init(priv);
	if (ret < 0) {
		return ret;
	}

	/* Initialize Character Device Node */
	ret = optimal_env_chardev_init(priv);
	if (ret < 0) {
		goto err_sensors_cleanup;
	}

	/* Initialize Sysfs and hwmon interface */
	ret = optimal_env_sysfs_init(priv);
	if (ret < 0) {
		goto err_chardev_cleanup;
	}

	/* Register virtual backlight device */
	memset(&props, 0, sizeof(props));
	props.type = BACKLIGHT_RAW;
	props.max_brightness = 255;
	props.brightness = 255;
	priv->bd = devm_backlight_device_register(
		dev, "optimal_backlight", dev, priv, &optimal_bl_ops, &props);
	if (IS_ERR(priv->bd)) {
		dev_err(dev, "Failed to register backlight device\n");
		priv->bd = NULL;
	}

	/* Start kernel monitoring thread */
	priv->monitor_task =
		kthread_run(optimal_env_thread, priv, "optimal_env_monitor");
	if (IS_ERR(priv->monitor_task)) {
		ret = PTR_ERR(priv->monitor_task);
		priv->monitor_task = NULL;
		goto err_sysfs_cleanup;
	}

	dev_info(dev, "Optimal Environment Manager probed successfully\n");
	return 0;

err_sysfs_cleanup:
	optimal_env_sysfs_remove(priv);
err_chardev_cleanup:
	optimal_env_chardev_remove(priv);
err_sensors_cleanup:
	optimal_env_sensors_cleanup(priv);
	return ret;
}

static int optimal_env_remove(struct platform_device *pdev)
{
	struct optimal_env_priv *priv = platform_get_drvdata(pdev);
	int i;

	if (priv->monitor_task) {
		kthread_stop(priv->monitor_task);
		priv->monitor_task = NULL;
	}

	optimal_env_sysfs_remove(priv);
	optimal_env_chardev_remove(priv);
	optimal_env_sensors_cleanup(priv);

	for (i = 0; i < priv->led_count; i++) {
		gpiod_set_value(priv->leds[i], 0);
	}

	dev_info(&pdev->dev,
		 "Optimal Environment Manager removed successfully\n");
	return 0;
}

static const struct of_device_id optimal_env_of_match[] = {
	{ .compatible = "optimal,env-manager" },
	{}
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

MODULE_AUTHOR("minhnhat092005");
MODULE_DESCRIPTION("Optimal Environment and Power Manager Kernel Module");
MODULE_LICENSE("GPL");
