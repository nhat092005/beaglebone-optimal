#include "SensorBackend.h"

#include <QtCore/qdatetime.h>
#include <QtCore/qdir.h>
#include <QtCore/qfile.h>
#include <QtCore/qtextstream.h>
#include <QtCore/qlogging.h>

#include <fcntl.h>
#include <unistd.h>
#include <cstdlib>

struct EnvRecord {
	uint64_t timestamp_ms;
	int32_t temperature;
	int32_t humidity;
	int32_t lux;
} __attribute__((packed));

static const char *const kDayNames[] = { "MONDAY",   "TUESDAY", "WEDNESDAY",
					 "THURSDAY", "FRIDAY",	"SATURDAY",
					 "SUNDAY" };
static const char *const kMonthNames[] = { "JAN", "FEB", "MAR", "APR",
					   "MAY", "JUN", "JUL", "AUG",
					   "SEP", "OCT", "NOV", "DEC" };

SensorBackend::SensorBackend(QObject *parent)
	: QObject(parent)
{
	connect(&m_timeTimer, &QTimer::timeout, this,
		&SensorBackend::updateTime);
	connect(&m_sensorTimer, &QTimer::timeout, this,
		&SensorBackend::updateSensors);

	m_timeTimer.start(1000);
	m_sensorTimer.start(1000);

	updateTime();
	updateSensors();
}

void SensorBackend::updateTime()
{
	const QDateTime now = QDateTime::currentDateTime();
	const QDate d = now.date();
	const QTime t = now.time();

	const QString newTime = t.toString(QStringLiteral("hh:mm:ss"));
	const QString newDate = QString::fromLatin1("%1 \xc2\xb7 %2 %3 %4")
					.arg(kDayNames[d.dayOfWeek() - 1])
					.arg(d.day())
					.arg(kMonthNames[d.month() - 1])
					.arg(d.year());

	if (newTime != m_time) {
		m_time = newTime;
		emit timeChanged();
	}
	if (newDate != m_date) {
		m_date = newDate;
		emit dateChanged();
	}
}

void SensorBackend::updateSensors()
{
	const QString optRoot =
		QStringLiteral("/sys/class/optimal-env/optimal_env/");
	if (QDir(optRoot).exists()) {
		// Read values from custom sysfs class
		const QString tempStr =
			readSysfs(optRoot + QStringLiteral("temperature"));
		const QString humStr =
			readSysfs(optRoot + QStringLiteral("humidity"));
		const QString luxStr =
			readSysfs(optRoot + QStringLiteral("lux"));
		const QString nightStr =
			readSysfs(optRoot + QStringLiteral("night_mode"));

		const QString tLimitStr =
			readSysfs(optRoot + QStringLiteral("temp_alarm_limit"));
		const QString hLimitStr = readSysfs(
			optRoot + QStringLiteral("humid_alarm_limit"));
		const QString lLimitStr =
			readSysfs(optRoot + QStringLiteral("lux_alarm_limit"));

		bool ok = false;
		if (!tempStr.isEmpty()) {
			const int tempMilli = tempStr.toInt(&ok);
			if (ok) {
				const QString v =
					QString::number(tempMilli / 1000.0, 'f',
							1) +
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
					QString::number(humMilli / 1000.0, 'f',
							1) +
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
				const QString v = QString::number(luxVal) +
						  QStringLiteral(" lx");
				if (v != m_light) {
					m_light = v;
					emit lightChanged();
				}
			}
		}

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

		// Read history from /dev/optimal_env
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
	} else {
		// Fallback PC simulation
		static double t = 30.0;
		static double h = 60.0;
		static double l = 100.0;

		t += ((double)std::rand() / RAND_MAX - 0.5) * 1.5;
		h += ((double)std::rand() / RAND_MAX - 0.5) * 2.0;
		l += ((double)std::rand() / RAND_MAX - 0.5) * 10.0;
		if (l < 0)
			l = 0;

		m_temperature =
			QString::number(t, 'f', 1) + QStringLiteral(" °C");
		m_humidity = QString::number(h, 'f', 1) + QStringLiteral("%");
		m_light = QString::number(static_cast<int>(l)) +
			  QStringLiteral(" lx");

		emit temperatureChanged();
		emit humidityChanged();
		emit lightChanged();

		m_tempAlarmLimit = 45.0;
		m_humidAlarmLimit = 80.0;
		m_luxAlarmLimit = 20.0;

		emit tempAlarmLimitChanged();
		emit humidAlarmLimitChanged();
		emit luxAlarmLimitChanged();

		int nm = (l < m_luxAlarmLimit) ? 1 : 0;
		if (nm != m_nightMode) {
			m_nightMode = nm;
			emit nightModeChanged();
		}

		m_tempHistory.append(t);
		m_humidityHistory.append(h);
		m_lightHistory.append(l);

		if (m_tempHistory.size() > 10)
			m_tempHistory.removeFirst();
		if (m_humidityHistory.size() > 10)
			m_humidityHistory.removeFirst();
		if (m_lightHistory.size() > 10)
			m_lightHistory.removeFirst();

		emit historyChanged();
	}
}

QString SensorBackend::readSysfs(const QString &path)
{
	QFile f(path);
	if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
		return {};
	return QString::fromLatin1(f.readLine()).trimmed();
}
