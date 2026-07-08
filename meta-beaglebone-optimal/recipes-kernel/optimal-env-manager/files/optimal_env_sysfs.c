/* SPDX-License-Identifier: MIT */
/*
 * optimal_env_sysfs.c - Sysfs attributes for sensor data and thresholds.
 *
 * Copyright (c) 2026 MinhNhat <minhnhat092005@gmail.com>
 */

#include "optimal_env_core.h"

static ssize_t temperature_show(struct device *dev,
				struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int temp = 0;

	mutex_lock(&priv->buffer_mutex);
	if (priv->ring_buffer_count > 0) {
		int last_idx = (priv->ring_buffer_head - 1 + RECORD_COUNT) %
			       RECORD_COUNT;
		temp = priv->ring_buffer[last_idx].temperature;
	}
	mutex_unlock(&priv->buffer_mutex);
	return sysfs_emit(buf, "%d\n", temp);
}
static DEVICE_ATTR_RO(temperature);

static ssize_t humidity_show(struct device *dev, struct device_attribute *attr,
			     char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int humid = 0;

	mutex_lock(&priv->buffer_mutex);
	if (priv->ring_buffer_count > 0) {
		int last_idx = (priv->ring_buffer_head - 1 + RECORD_COUNT) %
			       RECORD_COUNT;
		humid = priv->ring_buffer[last_idx].humidity;
	}
	mutex_unlock(&priv->buffer_mutex);
	return sysfs_emit(buf, "%d\n", humid);
}
static DEVICE_ATTR_RO(humidity);

static ssize_t lux_show(struct device *dev, struct device_attribute *attr,
			char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int lx = 0;

	mutex_lock(&priv->buffer_mutex);
	if (priv->ring_buffer_count > 0) {
		int last_idx = (priv->ring_buffer_head - 1 + RECORD_COUNT) %
			       RECORD_COUNT;
		lx = priv->ring_buffer[last_idx].lux;
	}
	mutex_unlock(&priv->buffer_mutex);
	return sysfs_emit(buf, "%d\n", lx);
}
static DEVICE_ATTR_RO(lux);

static ssize_t temp_alarm_limit_show(struct device *dev,
				     struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->temp_alarm_limit;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t temp_alarm_limit_store(struct device *dev,
				      struct device_attribute *attr,
				      const char *buf, size_t count)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val, ret;

	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&priv->state_lock);
	priv->temp_alarm_limit = val;
	spin_unlock(&priv->state_lock);
	return count;
}
static DEVICE_ATTR_RW(temp_alarm_limit);

static ssize_t humid_alarm_limit_show(struct device *dev,
				      struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->humid_alarm_limit;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t humid_alarm_limit_store(struct device *dev,
				       struct device_attribute *attr,
				       const char *buf, size_t count)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val, ret;

	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&priv->state_lock);
	priv->humid_alarm_limit = val;
	spin_unlock(&priv->state_lock);
	return count;
}
static DEVICE_ATTR_RW(humid_alarm_limit);

static ssize_t lux_alarm_limit_show(struct device *dev,
				    struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->lux_alarm_limit;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static ssize_t lux_alarm_limit_store(struct device *dev,
				     struct device_attribute *attr,
				     const char *buf, size_t count)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val, ret;

	ret = kstrtoint(buf, 10, &val);
	if (ret)
		return ret;
	spin_lock(&priv->state_lock);
	priv->lux_alarm_limit = val;
	spin_unlock(&priv->state_lock);
	return count;
}
static DEVICE_ATTR_RW(lux_alarm_limit);

static ssize_t alarm_state_show(struct device *dev,
				struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->alarm_state;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(alarm_state);

static ssize_t night_mode_show(struct device *dev,
			       struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->night_mode;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(night_mode);

static ssize_t sensor_status_show(struct device *dev,
				  struct device_attribute *attr, char *buf)
{
	struct optimal_env_priv *priv = dev_get_drvdata(dev);
	int val;

	spin_lock(&priv->state_lock);
	val = priv->sensor_status;
	spin_unlock(&priv->state_lock);
	return sysfs_emit(buf, "%d\n", val);
}
static DEVICE_ATTR_RO(sensor_status);

static struct attribute *optimal_attrs[] = {
	&dev_attr_temperature.attr,
	&dev_attr_humidity.attr,
	&dev_attr_lux.attr,
	&dev_attr_temp_alarm_limit.attr,
	&dev_attr_humid_alarm_limit.attr,
	&dev_attr_lux_alarm_limit.attr,
	&dev_attr_alarm_state.attr,
	&dev_attr_night_mode.attr,
	&dev_attr_sensor_status.attr,
	NULL,
};

static const struct attribute_group optimal_attr_group = {
	.attrs = optimal_attrs,
};

static umode_t optimal_hwmon_is_visible(const void *drvdata,
					enum hwmon_sensor_types type, u32 attr,
					int channel)
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
	struct optimal_env_priv *priv = dev_get_drvdata(dev);

	if (type == hwmon_temp && attr == hwmon_temp_input) {
		mutex_lock(&priv->buffer_mutex);
		if (priv->ring_buffer_count > 0) {
			int last_idx =
				(priv->ring_buffer_head - 1 + RECORD_COUNT) %
				RECORD_COUNT;
			*val = priv->ring_buffer[last_idx].temperature;
		} else {
			*val = 0;
		}
		mutex_unlock(&priv->buffer_mutex);
		return 0;
	}
	if (type == hwmon_humidity && attr == hwmon_humidity_input) {
		mutex_lock(&priv->buffer_mutex);
		if (priv->ring_buffer_count > 0) {
			int last_idx =
				(priv->ring_buffer_head - 1 + RECORD_COUNT) %
				RECORD_COUNT;
			*val = priv->ring_buffer[last_idx].humidity;
		} else {
			*val = 0;
		}
		mutex_unlock(&priv->buffer_mutex);
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
	HWMON_CHANNEL_INFO(humidity, HWMON_H_INPUT), NULL
};

const struct hwmon_chip_info optimal_hwmon_chip_info = {
	.ops = &optimal_hwmon_ops,
	.info = optimal_hwmon_info,
};

int optimal_env_sysfs_init(struct optimal_env_priv *priv)
{
	int ret;

	priv->optimal_class = class_create("optimal-env");
	if (IS_ERR(priv->optimal_class)) {
		return PTR_ERR(priv->optimal_class);
	}

	priv->optimal_device = device_create(priv->optimal_class, priv->dev,
					     priv->dev_num, priv,
					     "optimal_env");
	if (IS_ERR(priv->optimal_device)) {
		ret = PTR_ERR(priv->optimal_device);
		goto err_class_destroy;
	}

	ret = sysfs_create_group(&priv->optimal_device->kobj,
				 &optimal_attr_group);
	if (ret < 0) {
		goto err_device_destroy;
	}

	priv->hwmon_dev = devm_hwmon_device_register_with_info(
		priv->dev, "optimal_env", priv, &optimal_hwmon_chip_info, NULL);
	if (IS_ERR(priv->hwmon_dev)) {
		ret = PTR_ERR(priv->hwmon_dev);
		dev_err(priv->dev, "Failed to register hwmon device: %d\n",
			ret);
		goto err_sysfs_remove;
	}

	return 0;

err_sysfs_remove:
	sysfs_remove_group(&priv->optimal_device->kobj, &optimal_attr_group);
err_device_destroy:
	device_destroy(priv->optimal_class, priv->dev_num);
err_class_destroy:
	class_destroy(priv->optimal_class);
	return ret;
}

void optimal_env_sysfs_remove(struct optimal_env_priv *priv)
{
	if (priv->optimal_device && !IS_ERR(priv->optimal_device)) {
		sysfs_remove_group(&priv->optimal_device->kobj,
				   &optimal_attr_group);
		device_destroy(priv->optimal_class, priv->dev_num);
	}
	if (priv->optimal_class && !IS_ERR(priv->optimal_class)) {
		class_destroy(priv->optimal_class);
	}
}
