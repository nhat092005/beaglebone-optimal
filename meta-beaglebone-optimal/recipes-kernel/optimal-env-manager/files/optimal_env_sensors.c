#include "optimal_env_core.h"

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

static int sht3x_trigger(struct i2c_client *client)
{
	u8 cmd[2] = { 0x24, 0x00 };
	int ret = i2c_master_send(client, cmd, 2);

	if (ret < 0)
		return ret;
	return (ret != 2) ? -EIO : 0;
}

static int sht3x_read_result(struct i2c_client *client, int *temp, int *humid)
{
	u8 buf[6];
	int ret;
	u16 raw_temp, raw_humid;

	ret = i2c_master_recv(client, buf, 6);
	if (ret < 0)
		return ret;
	if (ret != 6)
		return -EIO;

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
	*temp = ((21875 * (int)raw_temp) >> 13) - 45000;
	*humid = (12500 * (u32)raw_humid) >> 13;
	return 0;
}

static int bh1750_trigger(struct i2c_client *client)
{
	/* One Time H-Resolution Mode: 1 lx resolution, ~120ms measurement */
	u8 cmd = 0x20;
	int ret = i2c_master_send(client, &cmd, 1);

	if (ret < 0)
		return ret;
	return (ret != 1) ? -EIO : 0;
}

static int bh1750_read_result(struct i2c_client *client, int *lux)
{
	u8 buf[2];
	int ret;

	ret = i2c_master_recv(client, buf, 2);
	if (ret < 0)
		return ret;
	if (ret != 2)
		return -EIO;

	/* H-Resolution mode: lux = raw * 10 / 12 (0.83 lx/count) */
	*lux = ((int)(buf[0] << 8) | buf[1]) * 10 / 12;
	return 0;
}

/*
 * Triggers both sensors, waits 180ms for both to complete (SHT3x needs ~15ms,
 * BH1750 needs up to 180ms (datasheet max)), then reads both results.
 * Returns fault bitmask: bit 0 = SHT3x fault, bit 1 = BH1750 fault.
 * Output values are 0 for any faulted sensor.
 */
int optimal_env_sensors_measure(struct optimal_env_priv *priv, int *temp,
				int *humid, int *lux)
{
	int fault = 0;
	int t = 0, h = 0, l = 0;
	int sht_ok = 0, bh_ok = 0;

	if (priv->sht3x_client && sht3x_trigger(priv->sht3x_client) == 0)
		sht_ok = 1;
	else
		fault |= 1;

	if (priv->bh1750_client && bh1750_trigger(priv->bh1750_client) == 0)
		bh_ok = 1;
	else
		fault |= 2;

	msleep(180);

	if (sht_ok && sht3x_read_result(priv->sht3x_client, &t, &h) < 0)
		fault |= 1;

	if (bh_ok && bh1750_read_result(priv->bh1750_client, &l) < 0)
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
