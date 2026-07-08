/* SPDX-License-Identifier: MIT */
/*
 * optimal_env_sensors.c - SHT3x/BH1750 sensor trigger and read helpers.
 *
 * Copyright (c) 2026 MinhNhat <minhnhat092005@gmail.com>
 */

#include "optimal_env_core.h"

/* SHT3x protocol constants (Sensirion SHT3x datasheet, Table 8 / Section 4.3) */
#define SHT3X_CMD_SINGLE_HIGH_MSB	0x24	/* Single Shot, High Repeatability */
#define SHT3X_CMD_SINGLE_HIGH_LSB	0x00
#define SHT3X_RESP_LEN			6	/* [T_MSB, T_LSB, T_CRC, H_MSB, H_LSB, H_CRC] */
#define SHT3X_HUMID_OFFSET		3	/* byte offset of humidity block in response */
#define SHT3X_CRC8_POLY			0x31	/* CRC-8/NRSC-5: x^8 + x^5 + x^4 + 1 */
#define SHT3X_CRC8_INIT			0xFF

/* BH1750 protocol constants (ROHM BH1750 datasheet, Table 4) */
#define BH1750_CMD_ONETIME_H_RES	0x20	/* One Time H-Resolution Mode */
#define BH1750_RESP_LEN			2

static u8 sht3x_crc8(const u8 *data, size_t len)
{
	u8 crc = SHT3X_CRC8_INIT;
	size_t i, j;

	for (i = 0; i < len; i++) {
		crc ^= data[i];
		for (j = 0; j < 8; j++) {
			if (crc & 0x80)
				crc = (crc << 1) ^ SHT3X_CRC8_POLY;
			else
				crc <<= 1;
		}
	}
	return crc;
}

static int sht3x_trigger(struct i2c_client *client)
{
	u8 cmd[2] = { SHT3X_CMD_SINGLE_HIGH_MSB, SHT3X_CMD_SINGLE_HIGH_LSB };
	struct i2c_msg msg = {
		.addr  = client->addr,
		.flags = client->flags & I2C_M_TEN,
		.len   = sizeof(cmd),
		.buf   = cmd,
	};
	int ret = i2c_transfer(client->adapter, &msg, 1);

	if (ret == -ETIMEDOUT) {
		dev_err(&client->dev, "SHT3x trigger timeout\n");
		ret = i2c_recover_bus(client->adapter);
		if (ret)
			dev_err(&client->dev, "I2C bus recovery failed (%d)\n", ret);
		return -ETIMEDOUT;
	}
	if (ret < 0)
		return ret;
	return (ret != 1) ? -EIO : 0;
}

static int sht3x_read_result(struct i2c_client *client, int *temp, int *humid)
{
	u8 buf[SHT3X_RESP_LEN];
	int ret;
	u16 raw_temp, raw_humid;
	struct i2c_msg msg = {
		.addr  = client->addr,
		.flags = (client->flags & I2C_M_TEN) | I2C_M_RD,
		.len   = sizeof(buf),
		.buf   = buf,
	};

	ret = i2c_transfer(client->adapter, &msg, 1);
	if (ret == -ETIMEDOUT) {
		dev_err(&client->dev, "SHT3x read timeout\n");
		ret = i2c_recover_bus(client->adapter);
		if (ret)
			dev_err(&client->dev, "I2C bus recovery failed (%d)\n", ret);
		return -ETIMEDOUT;
	}
	if (ret < 0)
		return ret;
	if (ret != 1)
		return -EIO;

	if (sht3x_crc8(buf, 2) != buf[2]) {
		dev_err(&client->dev, "SHT3x temp CRC mismatch\n");
		return -EBADMSG;
	}
	if (sht3x_crc8(buf + SHT3X_HUMID_OFFSET, 2) != buf[SHT3X_HUMID_OFFSET + 2]) {
		dev_err(&client->dev, "SHT3x humid CRC mismatch\n");
		return -EBADMSG;
	}

	raw_temp  = (buf[0] << 8) | buf[1];
	raw_humid = (buf[SHT3X_HUMID_OFFSET] << 8) | buf[SHT3X_HUMID_OFFSET + 1];
	/* T [mdegC] = -45000 + 175000 * raw / 65535 ~ (21875 * raw >> 13) - 45000 */
	*temp  = ((21875 * (int)raw_temp) >> 13) - 45000;
	/* RH [m%] = 100000 * raw / 65535 ~ (12500 * raw) >> 13 */
	*humid = (12500 * (u32)raw_humid) >> 13;
	return 0;
}

static int bh1750_trigger(struct i2c_client *client)
{
	u8 cmd = BH1750_CMD_ONETIME_H_RES;
	struct i2c_msg msg = {
		.addr  = client->addr,
		.flags = client->flags & I2C_M_TEN,
		.len   = 1,
		.buf   = &cmd,
	};
	int ret = i2c_transfer(client->adapter, &msg, 1);

	if (ret == -ETIMEDOUT) {
		dev_err(&client->dev, "BH1750 trigger timeout\n");
		ret = i2c_recover_bus(client->adapter);
		if (ret)
			dev_err(&client->dev, "I2C bus recovery failed (%d)\n", ret);
		return -ETIMEDOUT;
	}
	if (ret < 0)
		return ret;
	return (ret != 1) ? -EIO : 0;
}

static int bh1750_read_result(struct i2c_client *client, int *lux)
{
	u8 buf[BH1750_RESP_LEN];
	int ret;
	struct i2c_msg msg = {
		.addr  = client->addr,
		.flags = (client->flags & I2C_M_TEN) | I2C_M_RD,
		.len   = sizeof(buf),
		.buf   = buf,
	};

	ret = i2c_transfer(client->adapter, &msg, 1);
	if (ret == -ETIMEDOUT) {
		dev_err(&client->dev, "BH1750 read timeout\n");
		ret = i2c_recover_bus(client->adapter);
		if (ret)
			dev_err(&client->dev, "I2C bus recovery failed (%d)\n", ret);
		return -ETIMEDOUT;
	}
	if (ret < 0)
		return ret;
	if (ret != 1)
		return -EIO;

	/* H-Resolution mode: lux = raw * 10 / 12 (0.83 lx/count) */
	*lux = ((int)(buf[0] << 8) | buf[1]) * 10 / 12;
	return 0;
}

int optimal_env_sensors_trigger(struct optimal_env_priv *priv)
{
	int fault = 0;

	if (priv->sht3x_client && sht3x_trigger(priv->sht3x_client) != 0)
		fault |= 1;

	if (priv->bh1750_client && bh1750_trigger(priv->bh1750_client) != 0)
		fault |= 2;

	return fault;
}

int optimal_env_sensors_read(struct optimal_env_priv *priv, int trigger_fault,
			     int *temp, int *humid, int *lux)
{
	int fault = trigger_fault;
	int t = 0, h = 0, l = 0;

	if (!(fault & 1) && sht3x_read_result(priv->sht3x_client, &t, &h) < 0)
		fault |= 1;

	if (!(fault & 2) && bh1750_read_result(priv->bh1750_client, &l) < 0)
		fault |= 2;

	*temp = t;
	*humid = h;
	*lux = l;
	return fault;
}

int optimal_env_sensors_init(struct optimal_env_priv *priv)
{
	struct device *dev = priv->dev;
	struct device_node *sensor_node;
	struct device *sensor_dev;

	sensor_node = of_parse_phandle(dev->of_node, "hwmon-sensor", 0);
	if (!sensor_node) {
		dev_err(dev, "Missing 'hwmon-sensor' phandle in device tree\n");
		return -EINVAL;
	}
	sensor_dev = bus_find_device_by_of_node(&i2c_bus_type, sensor_node);
	of_node_put(sensor_node);
	if (!sensor_dev) {
		dev_warn(dev, "Failed to find SHT3x I2C client, deferring probe\n");
		return -EPROBE_DEFER;
	}
	priv->sht3x_client = to_i2c_client(sensor_dev);

	sensor_node = of_parse_phandle(dev->of_node, "light-sensor", 0);
	if (!sensor_node) {
		dev_err(dev, "Missing 'light-sensor' phandle in device tree\n");
		put_device(&priv->sht3x_client->dev);
		priv->sht3x_client = NULL;
		return -EINVAL;
	}
	sensor_dev = bus_find_device_by_of_node(&i2c_bus_type, sensor_node);
	of_node_put(sensor_node);
	if (!sensor_dev) {
		dev_warn(dev, "Failed to find BH1750 I2C client, deferring probe\n");
		put_device(&priv->sht3x_client->dev);
		priv->sht3x_client = NULL;
		return -EPROBE_DEFER;
	}
	priv->bh1750_client = to_i2c_client(sensor_dev);

	return 0;
}

void optimal_env_sensors_cleanup(struct optimal_env_priv *priv)
{
	if (priv->sht3x_client) {
		put_device(&priv->sht3x_client->dev);
		priv->sht3x_client = NULL;
	}
	if (priv->bh1750_client) {
		put_device(&priv->bh1750_client->dev);
		priv->bh1750_client = NULL;
	}
}
