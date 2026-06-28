#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

struct ppm_image {
	int width;
	int height;
	unsigned char *pixels;
};

static int read_token(FILE *fp, char *buf, size_t size)
{
	int c;
	size_t len = 0;

	do {
		c = fgetc(fp);
		if (c == '#') {
			do {
				c = fgetc(fp);
			} while (c != EOF && c != '\n');
		}
	} while (c != EOF && (c == ' ' || c == '\t' || c == '\r' || c == '\n'));

	if (c == EOF)
		return -1;

	do {
		if (len + 1 >= size)
			return -1;
		buf[len++] = (char)c;
		c = fgetc(fp);
	} while (c != EOF && c != ' ' && c != '\t' && c != '\r' &&
		 c != '\n');

	buf[len] = '\0';
	return 0;
}

static int load_ppm(const char *path, struct ppm_image *image)
{
	FILE *fp;
	char token[32];
	long width, height, maxval;
	size_t pixels_len;

	memset(image, 0, sizeof(*image));

	fp = fopen(path, "rb");
	if (!fp)
		return -1;

	if (read_token(fp, token, sizeof(token)) < 0 || strcmp(token, "P6") != 0)
		goto fail;
	if (read_token(fp, token, sizeof(token)) < 0)
		goto fail;
	width = strtol(token, NULL, 10);
	if (read_token(fp, token, sizeof(token)) < 0)
		goto fail;
	height = strtol(token, NULL, 10);
	if (read_token(fp, token, sizeof(token)) < 0)
		goto fail;
	maxval = strtol(token, NULL, 10);

	if (width <= 0 || height <= 0 || maxval != 255)
		goto fail;

	pixels_len = (size_t)width * (size_t)height * 3u;
	image->pixels = malloc(pixels_len);
	if (!image->pixels)
		goto fail;

	if (fread(image->pixels, 1, pixels_len, fp) != pixels_len)
		goto fail;

	fclose(fp);
	image->width = (int)width;
	image->height = (int)height;
	return 0;

fail:
	fclose(fp);
	free(image->pixels);
	memset(image, 0, sizeof(*image));
	return -1;
}

static uint32_t scale_channel(unsigned char value, unsigned int length)
{
	uint32_t max_value;

	if (length == 0)
		return 0;

	max_value = (1u << length) - 1u;
	return (uint32_t)((value * max_value + 127u) / 255u);
}

static uint32_t pack_pixel(unsigned char r, unsigned char g, unsigned char b,
			   const struct fb_var_screeninfo *var)
{
	uint32_t pixel = 0;

	pixel |= scale_channel(r, var->red.length) << var->red.offset;
	pixel |= scale_channel(g, var->green.length) << var->green.offset;
	pixel |= scale_channel(b, var->blue.length) << var->blue.offset;

	if (var->transp.length)
		pixel |= ((1u << var->transp.length) - 1u) <<
			 var->transp.offset;

	return pixel;
}

static int draw_splash(const char *fb_path, const char *logo_path)
{
	struct fb_fix_screeninfo fix;
	struct fb_var_screeninfo var;
	struct ppm_image image;
	unsigned char *map;
	size_t map_len;
	int fb_fd;
	int bytes_per_pixel;
	int draw_w, draw_h;
	int x0, y0;
	int x, y, b;
	int ret = -1;

	fb_fd = open(fb_path, O_RDWR);
	if (fb_fd < 0)
		return -1;

	if (ioctl(fb_fd, FBIOGET_FSCREENINFO, &fix) < 0)
		goto out_close;
	if (ioctl(fb_fd, FBIOGET_VSCREENINFO, &var) < 0)
		goto out_close;
	if (load_ppm(logo_path, &image) < 0)
		goto out_close;

	bytes_per_pixel = (int)var.bits_per_pixel / 8;
	if (bytes_per_pixel <= 0)
		goto out_free_image;

	map_len = (size_t)fix.line_length * (size_t)var.yres;
	map = mmap(NULL, map_len, PROT_READ | PROT_WRITE, MAP_SHARED, fb_fd, 0);
	if (map == MAP_FAILED)
		goto out_free_image;

	memset(map, 0, map_len);

	draw_w = image.width < (int)var.xres ? image.width : (int)var.xres;
	draw_h = image.height < (int)var.yres ? image.height : (int)var.yres;
	x0 = ((int)var.xres - draw_w) / 2;
	y0 = ((int)var.yres - draw_h) / 2;

	for (y = 0; y < draw_h; y++) {
		unsigned char *dst_row =
			map + (size_t)(y0 + y) * (size_t)fix.line_length +
			(size_t)x0 * (size_t)bytes_per_pixel;
		const unsigned char *src_row =
			image.pixels + (size_t)y * (size_t)image.width * 3u;

		for (x = 0; x < draw_w; x++) {
			uint32_t pixel = pack_pixel(src_row[x * 3],
						    src_row[x * 3 + 1],
						    src_row[x * 3 + 2], &var);

			for (b = 0; b < bytes_per_pixel; b++)
				dst_row[x * bytes_per_pixel + b] =
					(unsigned char)((pixel >> (8 * b)) &
							0xffu);
		}
	}

	msync(map, map_len, MS_SYNC);
	munmap(map, map_len);
	ret = 0;

out_free_image:
	free(image.pixels);
out_close:
	close(fb_fd);
	return ret;
}

int main(void)
{
	if (draw_splash("/dev/fb0", "/usr/share/qt-splash/logo.ppm") < 0) {
		fprintf(stderr, "qt-splash: %s\n", strerror(errno));
		return 1;
	}

	return 0;
}
