/* SPDX-License-Identifier: MIT */
/* SensorBackend.cpp - Read environment-manager data for the Qt dashboard.
 *
 * Copyright (c) 2026 MinhNhat <minhnhat092005@gmail.com>
 */

#include "SensorBackend.h"

#include <QtCore/qdir.h>
#include <QtCore/qfile.h>
#include <QtCore/qtextstream.h>
#include <QtCore/qlogging.h>

#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/rtc.h>
#include <cstdlib>

struct EnvRecord {
	uint64_t timestamp_ms;
	int32_t temperature;
	int32_t humidity;
	int32_t lux;
} __attribute__((packed));

SensorBackend::SensorBackend(QObject *parent)
	: QObject(parent)
{
	connect(&m_sensorTimer, &QTimer::timeout, this,
		&SensorBackend::updateSensors);

	m_sensorTimer.start(1000);

	/* RTC health is sampled once; rtcsync owns boot-time clock setup. */
	{
		int fd = ::open("/dev/rtc0", O_RDONLY);
		if (fd < 0) {
			m_rtcFault = true;
		} else {
			struct rtc_time rt;
			if (::ioctl(fd, RTC_RD_TIME, &rt) < 0)
				m_rtcFault = true;
			else if (rt.tm_year + 1900 < 2024)
				m_rtcFault = true;
			::close(fd);
		}
	}

	updateSensors();
}

void SensorBackend::updateSensors()
{
	const QString optRoot =
		QStringLiteral("/sys/class/optimal-env/optimal_env/");
	if (QDir(optRoot).exists()) {
		bool ok = false;

		const QString alarmStr =
			readSysfs(optRoot + QStringLiteral("alarm_state"));
		if (!alarmStr.isEmpty()) {
			const int alarm = alarmStr.toInt(&ok);
			if (ok && alarm != m_alarmState) {
				m_alarmState = alarm;
				emit alarmStateChanged();
			}
		}

		const QString statusStr =
			readSysfs(optRoot + QStringLiteral("sensor_status"));
		if (!statusStr.isEmpty()) {
			const int status = statusStr.toInt(&ok);
			if (ok && status != m_sensorStatus) {
				m_sensorStatus = status;
				emit sensorStatusChanged();
			}
		}

		if (m_sensorStatus != 0) {
			/* Do not display stale measurements while a sensor is faulty. */
			static const QString kDash = QStringLiteral("--");
			if (m_temperature != kDash) {
				m_temperature = kDash;
				emit temperatureChanged();
			}
			if (m_humidity != kDash) {
				m_humidity = kDash;
				emit humidityChanged();
			}
			if (m_light != kDash) {
				m_light = kDash;
				emit lightChanged();
			}
			if (!m_tempHistory.isEmpty() ||
			    !m_humidityHistory.isEmpty() ||
			    !m_lightHistory.isEmpty()) {
				m_tempHistory.clear();
				m_humidityHistory.clear();
				m_lightHistory.clear();
				emit historyChanged();
			}
		} else {
			const QString tempStr =
				readSysfs(optRoot + QStringLiteral("temperature"));
			const QString humStr =
				readSysfs(optRoot + QStringLiteral("humidity"));
			const QString luxStr =
				readSysfs(optRoot + QStringLiteral("lux"));

			if (!tempStr.isEmpty()) {
				const int tempMilli = tempStr.toInt(&ok);
				if (ok) {
					const QString v =
						QString::number(tempMilli / 1000.0,
								'f', 1) +
						QStringLiteral(" °C");
					if (v != m_temperature) {
						m_temperature = v;
						emit temperatureChanged();
					}
				}
			}

			ok = false;
			if (!humStr.isEmpty()) {
				const int humMilli = humStr.toInt(&ok);
				if (ok) {
					const QString v =
						QString::number(humMilli / 1000.0,
								'f', 1) +
						QStringLiteral("%");
					if (v != m_humidity) {
						m_humidity = v;
						emit humidityChanged();
					}
				}
			}

			ok = false;
			if (!luxStr.isEmpty()) {
				const int luxVal = luxStr.toInt(&ok);
				if (ok) {
					const QString v =
						QString::number(luxVal) +
						QStringLiteral(" lx");
					if (v != m_light) {
						m_light = v;
						emit lightChanged();
					}
				}
			}

			/* History uses the packed kernel character-device ABI. */
			int fd = ::open("/dev/optimal_env", O_RDONLY);
			if (fd >= 0) {
				EnvRecord buf[10];
				int bytes = ::read(fd, buf, sizeof(buf));
				::close(fd);
				if (bytes > 0) {
					int count = bytes / sizeof(EnvRecord);
					QVariantList tempHist, humidHist, luxHist;
					for (int i = 0; i < count; ++i) {
						tempHist.append(buf[i].temperature /
								1000.0);
						humidHist.append(buf[i].humidity /
								 1000.0);
						luxHist.append(static_cast<double>(
							buf[i].lux));
					}
					m_tempHistory = tempHist;
					m_humidityHistory = humidHist;
					m_lightHistory = luxHist;
					emit historyChanged();
				}
			}
		}

		/* These remain valid when current sensor measurements fail. */
		const QString nightStr =
			readSysfs(optRoot + QStringLiteral("night_mode"));
		const QString tLimitStr =
			readSysfs(optRoot + QStringLiteral("temp_alarm_limit"));
		const QString hLimitStr =
			readSysfs(optRoot + QStringLiteral("humid_alarm_limit"));
		const QString lLimitStr =
			readSysfs(optRoot + QStringLiteral("lux_alarm_limit"));

		if (!nightStr.isEmpty()) {
			const int nm = nightStr.toInt(&ok);
			if (ok && nm != m_nightMode) {
				m_nightMode = nm;
				emit nightModeChanged();
			}
		}

		if (!tLimitStr.isEmpty()) {
			const int val = tLimitStr.toInt(&ok);
			if (ok && val != m_tempAlarmLimit) {
				m_tempAlarmLimit = val;
				emit tempAlarmLimitChanged();
			}
		}

		if (!hLimitStr.isEmpty()) {
			const int val = hLimitStr.toInt(&ok);
			if (ok && val != m_humidAlarmLimit) {
				m_humidAlarmLimit = val;
				emit humidAlarmLimitChanged();
			}
		}

		if (!lLimitStr.isEmpty()) {
			const int val = lLimitStr.toInt(&ok);
			if (ok && val != m_luxAlarmLimit) {
				m_luxAlarmLimit = val;
				emit luxAlarmLimitChanged();
			}
		}
	}
}

QString SensorBackend::readSysfs(const QString &path)
{
	QFile f(path);
	if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
		return {};
	return QString::fromLatin1(f.readLine()).trimmed();
}
