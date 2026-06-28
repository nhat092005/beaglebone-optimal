#!/bin/sh

awk '{printf "[timing] TSHELL uptime=%.3fs\n", $1}' /proc/uptime > /dev/ttyS0
exec /usr/bin/env HOME=/home/root /bin/sh -l
