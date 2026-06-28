#include "optimal_env_core.h"

static int optimal_env_open(struct inode *inode, struct file *file)
{
	struct optimal_env_priv *priv = container_of(
		inode->i_cdev, struct optimal_env_priv, optimal_cdev);
	file->private_data = priv;
	return 0;
}

static ssize_t optimal_env_read(struct file *file, char __user *buf,
				size_t count, loff_t *ppos)
{
	struct optimal_env_priv *priv = file->private_data;
	struct env_record temp_buf[RECORD_COUNT];
	size_t total_size;
	int i, idx;

	mutex_lock(&priv->buffer_mutex);
	if (priv->ring_buffer_count == 0) {
		mutex_unlock(&priv->buffer_mutex);
		return 0;
	}

	idx = (priv->ring_buffer_head - priv->ring_buffer_count +
	       RECORD_COUNT) %
	      RECORD_COUNT;
	for (i = 0; i < priv->ring_buffer_count; i++) {
		temp_buf[i] = priv->ring_buffer[idx];
		idx = (idx + 1) % RECORD_COUNT;
	}
	total_size = priv->ring_buffer_count * sizeof(struct env_record);
	mutex_unlock(&priv->buffer_mutex);

	if (*ppos >= total_size)
		return 0;

	if (count > total_size - *ppos)
		count = total_size - *ppos;

	if (copy_to_user(buf, (char *)temp_buf + *ppos, count))
		return -EFAULT;

	*ppos += count;
	return count;
}

static long optimal_env_ioctl(struct file *file, unsigned int cmd,
			      unsigned long arg)
{
	struct optimal_env_priv *priv = file->private_data;

	if (!capable(CAP_SYS_ADMIN))
		return -EPERM;

	switch (cmd) {
	case OP_ENV_IOCTL_CLEAR_HISTORY:
		mutex_lock(&priv->buffer_mutex);
		priv->ring_buffer_head = 0;
		priv->ring_buffer_count = 0;
		memset(priv->ring_buffer, 0, sizeof(priv->ring_buffer));
		mutex_unlock(&priv->buffer_mutex);
		break;

	case OP_ENV_IOCTL_TRIGGER_MEASURE:
		WRITE_ONCE(priv->trigger_measure, true);
		wake_up_interruptible(&priv->measure_wait);
		break;

	default:
		return -ENOTTY;
	}
	return 0;
}

static const struct file_operations optimal_env_fops = {
	.owner = THIS_MODULE,
	.open = optimal_env_open,
	.read = optimal_env_read,
	.unlocked_ioctl = optimal_env_ioctl,
};

int optimal_env_chardev_init(struct optimal_env_priv *priv)
{
	int ret;

	ret = alloc_chrdev_region(&priv->dev_num, 0, 1, "optimal_env");
	if (ret < 0) {
		dev_err(priv->dev, "Failed to allocate chrdev region\n");
		return ret;
	}

	cdev_init(&priv->optimal_cdev, &optimal_env_fops);
	priv->optimal_cdev.owner = THIS_MODULE;

	ret = cdev_add(&priv->optimal_cdev, priv->dev_num, 1);
	if (ret < 0) {
		dev_err(priv->dev, "Failed to add cdev\n");
		unregister_chrdev_region(priv->dev_num, 1);
		return ret;
	}

	return 0;
}

void optimal_env_chardev_remove(struct optimal_env_priv *priv)
{
	cdev_del(&priv->optimal_cdev);
	unregister_chrdev_region(priv->dev_num, 1);
}
