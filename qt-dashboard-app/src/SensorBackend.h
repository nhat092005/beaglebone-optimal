#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class SensorBackend : public QObject {
	Q_OBJECT
	Q_PROPERTY(
		QString temperature READ temperature NOTIFY temperatureChanged)
	Q_PROPERTY(QString humidity READ humidity NOTIFY humidityChanged)
	Q_PROPERTY(QString light READ light NOTIFY lightChanged)

	Q_PROPERTY(double tempAlarmLimit READ tempAlarmLimit NOTIFY
			   tempAlarmLimitChanged)
	Q_PROPERTY(double humidAlarmLimit READ humidAlarmLimit NOTIFY
			   humidAlarmLimitChanged)
	Q_PROPERTY(double luxAlarmLimit READ luxAlarmLimit NOTIFY
			   luxAlarmLimitChanged)
	Q_PROPERTY(int nightMode READ nightMode NOTIFY nightModeChanged)
	Q_PROPERTY(int alarmState READ alarmState NOTIFY alarmStateChanged)
	Q_PROPERTY(int sensorStatus READ sensorStatus NOTIFY sensorStatusChanged)
	Q_PROPERTY(bool rtcFault READ rtcFault CONSTANT)

	Q_PROPERTY(
		QVariantList tempHistory READ tempHistory NOTIFY historyChanged)
	Q_PROPERTY(QVariantList humidityHistory READ humidityHistory NOTIFY
			   historyChanged)
	Q_PROPERTY(QVariantList lightHistory READ lightHistory NOTIFY
			   historyChanged)

    public:
	explicit SensorBackend(QObject *parent = nullptr);

	QString temperature() const
	{
		return m_temperature;
	}
	QString humidity() const
	{
		return m_humidity;
	}
	QString light() const
	{
		return m_light;
	}

	double tempAlarmLimit() const
	{
		return m_tempAlarmLimit;
	}
	double humidAlarmLimit() const
	{
		return m_humidAlarmLimit;
	}
	double luxAlarmLimit() const
	{
		return m_luxAlarmLimit;
	}
	int nightMode() const
	{
		return m_nightMode;
	}
	int alarmState() const
	{
		return m_alarmState;
	}
	int sensorStatus() const
	{
		return m_sensorStatus;
	}
	bool rtcFault() const
	{
		return m_rtcFault;
	}

	QVariantList tempHistory() const
	{
		return m_tempHistory;
	}
	QVariantList humidityHistory() const
	{
		return m_humidityHistory;
	}
	QVariantList lightHistory() const
	{
		return m_lightHistory;
	}

    signals:
	void temperatureChanged();
	void humidityChanged();
	void lightChanged();

	void tempAlarmLimitChanged();
	void humidAlarmLimitChanged();
	void luxAlarmLimitChanged();
	void nightModeChanged();
	void alarmStateChanged();
	void sensorStatusChanged();
	void historyChanged();

    private slots:
	void updateSensors();

    private:
	static QString readSysfs(const QString &path);

	QString m_temperature{ QStringLiteral("--") };
	QString m_humidity{ QStringLiteral("--") };
	QString m_light{ QStringLiteral("--") };

	double m_tempAlarmLimit{ 45.0 };
	double m_humidAlarmLimit{ 80.0 };
	double m_luxAlarmLimit{ 20.0 };
	int m_nightMode{ 0 };
	int m_alarmState{ 0 };
	int m_sensorStatus{ 0 };
	bool m_rtcFault{ false };

	QVariantList m_tempHistory;
	QVariantList m_humidityHistory;
	QVariantList m_lightHistory;

	QTimer m_sensorTimer;
};
