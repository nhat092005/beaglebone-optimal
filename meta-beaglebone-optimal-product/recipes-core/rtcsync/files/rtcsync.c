/* SPDX-License-Identifier: MIT */
/*
 * rtcsync.c - Set the system clock from /dev/rtc0 at boot.
 *
 * Copyright (c) 2026 MinhNhat <minhnhat092005@gmail.com>
 *
 * This utility never writes to the RTC.
 */
#include <fcntl.h>
#include <linux/rtc.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* Retry /dev/rtc0 for up to 5s if I2C probe lands after sysinit. */
#define RTC_OPEN_RETRIES 50
#define RTC_OPEN_RETRY_INTERVAL_NS (100L * 1000 * 1000)

int main(void)
{
	int fd = -1;

	for (int i = 0; i < RTC_OPEN_RETRIES; i++) {
		fd = open("/dev/rtc0", O_RDONLY);
		if (fd >= 0)
			break;
		struct timespec wait = { 0, RTC_OPEN_RETRY_INTERVAL_NS };
		nanosleep(&wait, NULL);
	}
	if (fd < 0) {
		perror("rtcsync: open /dev/rtc0");
		return 1;
	}

	struct rtc_time rt;
	if (ioctl(fd, RTC_RD_TIME, &rt) < 0) {
		perror("rtcsync: RTC_RD_TIME");
		close(fd);
		return 1;
	}
	close(fd);

	/* Guard against bogus RTC values after battery-backed time loss. */
	if (rt.tm_year + 1900 < 2024) {
		fprintf(stderr, "rtcsync: RTC year %d invalid, not setting clock\n",
			rt.tm_year + 1900);
		return 1;
	}

	/* RTC stores UTC; timegm converts UTC struct tm -> time_t without TZ. */
	struct tm tm = {
		.tm_sec = rt.tm_sec,
		.tm_min = rt.tm_min,
		.tm_hour = rt.tm_hour,
		.tm_mday = rt.tm_mday,
		.tm_mon = rt.tm_mon,
		.tm_year = rt.tm_year,
		.tm_isdst = 0,
	};
	time_t t = timegm(&tm);
	if (t == (time_t)-1) {
		fprintf(stderr, "rtcsync: timegm failed\n");
		return 1;
	}

	struct timeval tv = { t, 0 };
	if (settimeofday(&tv, NULL) < 0) {
		perror("rtcsync: settimeofday");
		return 1;
	}
	return 0;
}
