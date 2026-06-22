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

int sht3x_read_temp_humid(struct i2c_client *client, int *temp, int *humid)
{
	u8 cmd[2] = { 0x24, 0x00 };
	u8 buf[6];
	int ret;
	u16 raw_temp, raw_humid;

	ret = i2c_master_send(client, cmd, 2);
	if (ret < 0) {
		dev_err(&client->dev, "SHT3x send command failed: %d\n", ret);
		return ret;
	} else if (ret != 2) {
		dev_err(&client->dev, "SHT3x send command short write: %d\n",
			ret);
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

	*temp = ((21875 * (int)raw_temp) >> 13) - 45000;
	*humid = (12500 * (u32)raw_humid) >> 13;

	return 0;
}

int optimal_env_sensors_init(struct optimal_env_priv *priv)
{
	struct device *dev = priv->dev;
	struct device_node *sensor_node;

	priv->lux_chan = devm_iio_channel_get(dev, "lux");
	if (IS_ERR(priv->lux_chan)) {
		if (PTR_ERR(priv->lux_chan) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		dev_warn(dev, "Failed to get IIO channel 'lux': %ld\n",
			 PTR_ERR(priv->lux_chan));
		priv->lux_chan = NULL;
	}

	sensor_node = of_parse_phandle(dev->of_node, "hwmon-sensor", 0);
	if (sensor_node) {
		struct device *sensor_dev =
			bus_find_device_by_of_node(&i2c_bus_type, sensor_node);
		of_node_put(sensor_node);
		if (sensor_dev) {
			priv->sht3x_client = to_i2c_client(sensor_dev);
		} else {
			dev_warn(
				dev,
				"Failed to find SHT3x I2C client device, deferring probe\n");
			return -EPROBE_DEFER;
		}
	} else {
		dev_err(dev, "Missing 'hwmon-sensor' phandle in device tree\n");
		return -EINVAL;
	}

	return 0;
}

void optimal_env_sensors_cleanup(struct optimal_env_priv *priv)
{
	if (priv->sht3x_client) {
		put_device(&priv->sht3x_client->dev);
		priv->sht3x_client = NULL;
	}
}
