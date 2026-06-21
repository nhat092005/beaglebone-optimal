SUMMARY = "Sync system clock from RTC at boot"
DESCRIPTION = "Reads /dev/rtc0 via ioctl and sets the system clock using \
syscall(SYS_settimeofday) directly, bypassing musl's settimeofday() wrapper \
which routes through clock_settime() requiring CONFIG_POSIX_TIMERS."

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=7ae2be7fb1637141840314b51970a9f7"

SRC_URI = " \
    file://rtcsync.c \
    file://LICENSE \
"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o rtcsync rtcsync.c
}

do_install() {
    install -d ${D}${base_sbindir}
    install -m 0755 rtcsync ${D}${base_sbindir}/rtcsync
}

FILES:${PN} = "${base_sbindir}/rtcsync"
