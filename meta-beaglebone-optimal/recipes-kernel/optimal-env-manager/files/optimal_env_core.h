#ifndef OPTIMAL_ENV_CORE_H
#define OPTIMAL_ENV_CORE_H

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
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

#define OP_ENV_IOC_MAGIC 'O'
#define OP_ENV_IOCTL_TEST_ALARM_ON _IO(OP_ENV_IOC_MAGIC, 1)
#define OP_ENV_IOCTL_TEST_ALARM_OFF _IO(OP_ENV_IOC_MAGIC, 2)
#define OP_ENV_IOCTL_CLEAR_HISTORY _IO(OP_ENV_IOC_MAGIC, 3)
#define OP_ENV_IOCTL_TRIGGER_MEASURE _IO(OP_ENV_IOC_MAGIC, 4)

#define RECORD_COUNT 10
#define MAX_LEDS 3

struct env_record {
	u64 timestamp_ms;
	s32 temperature;
	s32 humidity;
	s32 lux;
} __packed;

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
	int lux_dark_limit;
	int lux_light_limit;

	/* Test Alarm Mode */
	bool test_alarm_mode;
	unsigned long test_mode_expires;

	/* GPIO LEDs */
	struct gpio_desc *leds[MAX_LEDS];
	int led_count;

	/* Devices / Resources */
	struct i2c_client *sht3x_client;
	struct device *hwmon_dev;
	struct iio_channel *lux_chan;
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

/* Core helper functions */
void push_record(struct optimal_env_priv *priv, u64 time_ms, s32 temp, s32 humid,
		 s32 lux);

/* Core sub-system init & remove declarations */
int optimal_env_sysfs_init(struct optimal_env_priv *priv);
void optimal_env_sysfs_remove(struct optimal_env_priv *priv);

int optimal_env_chardev_init(struct optimal_env_priv *priv);
void optimal_env_chardev_remove(struct optimal_env_priv *priv);

int optimal_env_sensors_init(struct optimal_env_priv *priv);
void optimal_env_sensors_cleanup(struct optimal_env_priv *priv);
int sht3x_read_temp_humid(struct i2c_client *client, int *temp, int *humid);

extern const struct hwmon_chip_info optimal_hwmon_chip_info;

#endif /* OPTIMAL_ENV_CORE_H */
