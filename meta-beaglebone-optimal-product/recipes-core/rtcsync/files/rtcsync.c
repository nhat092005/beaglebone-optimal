/*
 * rtcsync — set system clock from RTC at boot, bypassing musl's settimeofday()
 * wrapper which routes through clock_settime() requiring CONFIG_POSIX_TIMERS.
 * This calls sys_settimeofday directly via syscall(2), which the kernel exposes
 * unconditionally on ARM32 (syscall #78, kernel/time/time.c).
 */
#include <asm/unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/rtc.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

/* musl does not expose SYS_settimeofday; use the kernel ABI name instead */
#ifndef SYS_settimeofday
#define SYS_settimeofday __NR_settimeofday
#endif

int main(void)
{
	int fd = open("/dev/rtc0", O_RDONLY);
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
	long ret = syscall(SYS_settimeofday, &tv, NULL);
	if (ret < 0) {
		errno = -ret;
		perror("rtcsync: settimeofday");
		return 1;
	}
	return 0;
}
