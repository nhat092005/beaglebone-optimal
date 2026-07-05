/*
 * rtcsync — set system clock from RTC at boot.
 */
#include <fcntl.h>
#include <linux/rtc.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* /dev/rtc0 may not be ready yet if I2C probe is deferred past sysinit;
 * retry for up to 5s before giving up. */
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

	/* DS3231 with a dead/absent backup battery reports an invalid year after
	 * power loss (OSF). The kernel ds1307 driver normally returns -EINVAL on
	 * RTC_RD_TIME above; guard explicitly so a bogus-but-parseable value never
	 * sets a wrong system clock. */
	if (rt.tm_year + 1900 < 2024) {
		fprintf(stderr, "rtcsync: RTC year %d invalid, not setting clock\n",
			rt.tm_year + 1900);
		return 1;
	}

	/* RTC stores UTC; timegm converts UTC struct tm → time_t without TZ */
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
