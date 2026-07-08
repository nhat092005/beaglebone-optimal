/* SPDX-License-Identifier: MIT */
/*
 * optimal_env_core.h - Shared declarations for optimal_env_manager.
 *
 * Copyright (c) 2026 MinhNhat <minhnhat092005@gmail.com>
 */

#ifndef OPTIMAL_ENV_CORE_H
#define OPTIMAL_ENV_CORE_H

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/hwmon.h>
#include <linux/leds.h>
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

#define OP_ENV_IOC_MAGIC 'O'
#define OP_ENV_IOCTL_CLEAR_HISTORY _IO(OP_ENV_IOC_MAGIC, 1)
#define OP_ENV_IOCTL_TRIGGER_MEASURE _IO(OP_ENV_IOC_MAGIC, 2)

#define RECORD_COUNT 10
#define MAX_LEDS 2

/* BH1750 H-Resolution measurement time (datasheet max: 180ms) */
#define BH1750_MEAS_TIME_MS 180

/**
 * struct env_record - Environmental history record
 *
 * @timestamp_ms: Timestamp in milliseconds.
 * @temperature: Temperature in milli-degrees Celsius.
 * @humidity: Humidity in milli-percent.
 * @lux: Light level in lux.
 */
struct env_record {
	u64 timestamp_ms;
	s32 temperature;
	s32 humidity;
	s32 lux;
} __packed;

/**
 * struct optimal_env_priv - Driver state
 *
 * @dev: Parent device
 * @state_lock: Protects alarm, night-mode, sensor, and threshold state
 * @buffer_mutex: Protects history records
 * @ring_buffer: Environmental history
 * @ring_buffer_head: Next record index
 * @ring_buffer_count: Number of valid records
 * @alarm_state: Temperature and humidity alarm bitmask
 * @night_mode: Whether measured light is below the configured threshold
 * @sensor_status: Sensor fault bitmask; bit 0 SHT3x, bit 1 BH1750
 * @temp_alarm_limit: Temperature threshold in degrees Celsius
 * @humid_alarm_limit: Humidity threshold in percent
 * @lux_alarm_limit: Light threshold in lux
 * @alarm_leds: Temperature and humidity alarm LEDs
 * @sht3x_client: SHT3x I2C client
 * @bh1750_client: BH1750 I2C client
 * @hwmon_dev: Registered hwmon device
 * @bd: Virtual backlight device
 * @monitor_task: Sensor monitoring thread
 * @measure_wait: Measurement trigger wait queue
 * @trigger_measure: Immediate measurement request
 * @dev_num: Character device number
 * @optimal_cdev: Character device
 * @optimal_class: Character device class
 * @optimal_device: Character device node
 */
struct optimal_env_priv {
	struct device *dev;

	/* State Protection */
	spinlock_t state_lock;
	struct mutex buffer_mutex;

	/* Ring Buffer (History) */
	struct env_record ring_buffer[RECORD_COUNT];
	int ring_buffer_head;
	int ring_buffer_count;

	/* State Variables */
	int alarm_state;
	int night_mode;
	int sensor_status;

	/* Limits / Thresholds */
	int temp_alarm_limit;
	int humid_alarm_limit;
	int lux_alarm_limit;

	/* LED class devices (alarm indicators) */
	struct led_classdev *alarm_leds[MAX_LEDS];

	/* Devices / Resources */
	struct i2c_client *sht3x_client;
	struct i2c_client *bh1750_client;
	struct device *hwmon_dev;
	struct backlight_device *bd;

	/* Kthread Monitoring */
	struct task_struct *monitor_task;
	wait_queue_head_t measure_wait;
	bool trigger_measure;

	/* Character Device */
	dev_t dev_num;
	struct cdev optimal_cdev;
	struct class *optimal_class;
	struct device *optimal_device;
};

/**
 * push_record - Append an environmental history record
 *
 * @priv: Driver state
 * @time_ms: Timestamp in milliseconds.
 * @temp: Temperature in milli-degrees Celsius.
 * @humid: Humidity in milli-percent.
 * @lux: Light level in lux.
 */
void push_record(struct optimal_env_priv *priv, u64 time_ms, s32 temp,
		 s32 humid, s32 lux);

/**
 * optimal_env_sysfs_init - Register sysfs and hwmon interfaces
 *
 * @priv: Driver state
 * Return: 0 on success or a negative error code
 */
int optimal_env_sysfs_init(struct optimal_env_priv *priv);

/**
 * optimal_env_sysfs_remove - Remove sysfs and hwmon interfaces
 *
 * @priv: Driver state
 */
void optimal_env_sysfs_remove(struct optimal_env_priv *priv);

/**
 * optimal_env_chardev_init - Initialize the character device.
 *
 * @priv: Driver state
 * Return: 0 on success or a negative error code
 */
int optimal_env_chardev_init(struct optimal_env_priv *priv);

/**
 * optimal_env_chardev_remove - Remove the character device.
 *
 * @priv: Driver state
 */
void optimal_env_chardev_remove(struct optimal_env_priv *priv);

/**
 * optimal_env_sensors_init - Acquire SHT3x and BH1750 devices
 *
 * @priv: Driver state
 * Return: 0 on success or a negative error code
 */
int optimal_env_sensors_init(struct optimal_env_priv *priv);

/**
 * optimal_env_sensors_cleanup - Release sensor device references
 *
 * @priv: Driver state
 */
void optimal_env_sensors_cleanup(struct optimal_env_priv *priv);

/**
 * optimal_env_sensors_trigger - Start both sensor measurements
 *
 * @priv: Driver state
 * Return: Sensor fault bitmask; bit 0 SHT3x, bit 1 BH1750
 *
 * Wait at least BH1750_MEAS_TIME_MS before reading the results.
 */
int optimal_env_sensors_trigger(struct optimal_env_priv *priv);

/**
 * optimal_env_sensors_read - Read triggered sensor measurements
 *
 * @priv: Driver state
 * @trigger_fault: Fault bitmask returned by optimal_env_sensors_trigger()
 * @temp: Temperature in milli-degrees Celsius
 * @humid: Relative humidity in milli-percent
 * @lux: Light level in lux
 * Return: Combined trigger and read fault bitmask
 */
int optimal_env_sensors_read(struct optimal_env_priv *priv, int trigger_fault,
			     int *temp, int *humid, int *lux);

extern const struct hwmon_chip_info optimal_hwmon_chip_info;

#endif /* OPTIMAL_ENV_CORE_H */
