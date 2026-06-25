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
	int fault_status;
	u64 now_ms;
	struct timespec64 ts;
	int temp_alarm = 0, humid_alarm = 0, alarm, night;
	int prev_alarm = -1, prev_status = -1;
	unsigned long next_sensor_read = jiffies;

	while (!kthread_should_stop()) {
		if (time_is_before_eq_jiffies(next_sensor_read) ||
		    priv->trigger_measure) {
			priv->trigger_measure = false;
			next_sensor_read = jiffies + HZ;

			fault_status = optimal_env_sensors_measure(priv, &temp,
								   &humid, &lux);

			ktime_get_real_ts64(&ts);
			now_ms = (u64)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;

			if (fault_status == 0)
				push_record(priv, now_ms, temp, humid, lux);

			spin_lock(&priv->state_lock);

			temp_alarm = 0;
			humid_alarm = 0;
			if (fault_status == 0) {
				if (temp >= priv->temp_alarm_limit * 1000)
					temp_alarm = 1;
				if (humid >= priv->humid_alarm_limit * 1000)
					humid_alarm = 1;
			}

			alarm = (temp_alarm ? 1 : 0) | (humid_alarm ? 2 : 0);

			night = priv->night_mode;
			if (fault_status == 0)
				night = (lux < priv->lux_alarm_limit) ? 1 : 0;

			priv->alarm_state = alarm;
			priv->night_mode = night;
			priv->sensor_status = fault_status;

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

			if (alarm != prev_alarm || fault_status != prev_status) {
				unsigned long on_ms, off_ms;

				if (alarm) {
					on_ms = 50; off_ms = 50;
					if (temp_alarm)
						led_blink_set(priv->alarm_leds[0],
							      &on_ms, &off_ms);
					else
						led_set_brightness(
							priv->alarm_leds[0],
							LED_OFF);
					on_ms = 50; off_ms = 50;
					if (humid_alarm)
						led_blink_set(priv->alarm_leds[1],
							      &on_ms, &off_ms);
					else
						led_set_brightness(
							priv->alarm_leds[1],
							LED_OFF);
				} else if (fault_status != 0) {
					on_ms = 500; off_ms = 500;
					led_blink_set(priv->alarm_leds[0],
						      &on_ms, &off_ms);
					led_blink_set(priv->alarm_leds[1],
						      &on_ms, &off_ms);
				} else {
					led_set_brightness(priv->alarm_leds[0],
							   LED_OFF);
					led_set_brightness(priv->alarm_leds[1],
							   LED_OFF);
				}

				prev_alarm = alarm;
				prev_status = fault_status;
			}
		}

		wait_event_interruptible_timeout(
			priv->measure_wait,
			priv->trigger_measure || kthread_should_stop(),
			HZ);
	}

	led_set_brightness(priv->alarm_leds[0], LED_OFF);
	led_set_brightness(priv->alarm_leds[1], LED_OFF);
	return 0;
}

static int optimal_env_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct optimal_env_priv *priv;
	struct backlight_properties props;
	int ret;

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

	priv->alarm_leds[0] = devm_led_get(dev, "alarm0");
	if (IS_ERR(priv->alarm_leds[0])) {
		dev_err(dev, "Failed to get alarm0 LED\n");
		return PTR_ERR(priv->alarm_leds[0]);
	}
	priv->alarm_leds[1] = devm_led_get(dev, "alarm1");
	if (IS_ERR(priv->alarm_leds[1])) {
		dev_err(dev, "Failed to get alarm1 LED\n");
		return PTR_ERR(priv->alarm_leds[1]);
	}

	/* Initialize Sensors (SHT3x and BH1750 via raw I2C) */
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

	if (priv->monitor_task) {
		kthread_stop(priv->monitor_task);
		priv->monitor_task = NULL;
	}

	led_set_brightness(priv->alarm_leds[0], LED_OFF);
	led_set_brightness(priv->alarm_leds[1], LED_OFF);

	optimal_env_sysfs_remove(priv);
	optimal_env_chardev_remove(priv);
	optimal_env_sensors_cleanup(priv);

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
