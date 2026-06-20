#include "SensorBackend.h"

#include <QtCore/qdatetime.h>
#include <QtCore/qdir.h>
#include <QtCore/qfile.h>
#include <QtCore/qtextstream.h>
#include <QtCore/qlogging.h>

static const char *const kDayNames[] = {
    "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY",
    "FRIDAY", "SATURDAY", "SUNDAY"
};
static const char *const kMonthNames[] = {
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
};

SensorBackend::SensorBackend(QObject *parent)
    : QObject(parent)
{
    m_hwmonPath = findHwmon(QStringLiteral("sht3x"));
    m_iioPath   = findIioDevice(QStringLiteral("bh1750"));

    if (m_hwmonPath.isEmpty())
        qWarning() << "SensorBackend: sht3x hwmon device not found";
    if (m_iioPath.isEmpty())
        qWarning() << "SensorBackend: bh1750 iio device not found";

    connect(&m_timeTimer,   &QTimer::timeout, this, &SensorBackend::updateTime);
    connect(&m_sensorTimer, &QTimer::timeout, this, &SensorBackend::updateSensors);

    m_timeTimer.start(1000);
    m_sensorTimer.start(5000);

    updateTime();
    updateSensors();
}

void SensorBackend::updateTime()
{
    const QDateTime now = QDateTime::currentDateTime();
    const QDate     d   = now.date();
    const QTime     t   = now.time();

    const QString newTime = t.toString(QStringLiteral("hh:mm:ss"));
    const QString newDate = QString::fromLatin1("%1 \xc2\xb7 %2 %3 %4")
        .arg(kDayNames[d.dayOfWeek() - 1])
        .arg(d.day())
        .arg(kMonthNames[d.month() - 1])
        .arg(d.year());

    if (newTime != m_time) { m_time = newTime; emit timeChanged(); }
    if (newDate != m_date) { m_date = newDate; emit dateChanged(); }
}

void SensorBackend::updateSensors()
{
    if (!m_hwmonPath.isEmpty()) {
        const QString rawTemp = readSysfs(m_hwmonPath + QLatin1String("/temp1_input"));
        const QString rawHum  = readSysfs(m_hwmonPath + QLatin1String("/humidity1_input"));

        bool ok = false;
        const int tempMilli = rawTemp.toInt(&ok);
        if (ok) {
            const QString v = QString::number(tempMilli / 1000.0, 'f', 1)
                              + QString::fromUtf8("\xc2\xb0""C");
            if (v != m_temperature) { m_temperature = v; emit temperatureChanged(); }
        }

        ok = false;
        const int humMilli = rawHum.toInt(&ok);
        if (ok) {
            const QString v = QString::number(humMilli / 1000.0, 'f', 1) + QLatin1String("%");
            if (v != m_humidity) { m_humidity = v; emit humidityChanged(); }
        }
    }

    if (!m_iioPath.isEmpty()) {
        const QString rawStr   = readSysfs(m_iioPath + QLatin1String("/in_illuminance_raw"));
        const QString scaleStr = readSysfs(m_iioPath + QLatin1String("/in_illuminance_scale"));
        bool okR = false, okS = false;
        const double raw   = rawStr.toDouble(&okR);
        const double scale = scaleStr.toDouble(&okS);
        if (okR && okS) {
            const QString v = QString::number(static_cast<int>(raw * scale)) + QLatin1String(" lx");
            if (v != m_light) { m_light = v; emit lightChanged(); }
        }
    }
}

QString SensorBackend::findHwmon(const QString &driverName)
{
    const QDir hwmonRoot(QStringLiteral("/sys/class/hwmon"));
    const auto entries = hwmonRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        const QString base = hwmonRoot.absoluteFilePath(entry);
        if (readSysfs(base + QLatin1String("/name")).trimmed() == driverName)
            return base;
    }
    return {};
}

QString SensorBackend::findIioDevice(const QString &driverName)
{
    const QDir iioRoot(QStringLiteral("/sys/bus/iio/devices"));
    const auto entries = iioRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        const QString base = iioRoot.absoluteFilePath(entry);
        if (readSysfs(base + QLatin1String("/name")).trimmed() == driverName)
            return base;
    }
    return {};
}

QString SensorBackend::readSysfs(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromLatin1(f.readLine()).trimmed();
}
