#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class SensorBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString time       READ time       NOTIFY timeChanged)
    Q_PROPERTY(QString date       READ date       NOTIFY dateChanged)
    Q_PROPERTY(QString temperature READ temperature NOTIFY temperatureChanged)
    Q_PROPERTY(QString humidity   READ humidity   NOTIFY humidityChanged)
    Q_PROPERTY(QString light      READ light      NOTIFY lightChanged)

public:
    explicit SensorBackend(QObject *parent = nullptr);

    QString time()        const { return m_time; }
    QString date()        const { return m_date; }
    QString temperature() const { return m_temperature; }
    QString humidity()    const { return m_humidity; }
    QString light()       const { return m_light; }

signals:
    void timeChanged();
    void dateChanged();
    void temperatureChanged();
    void humidityChanged();
    void lightChanged();

private slots:
    void updateTime();
    void updateSensors();

private:
    static QString findHwmon(const QString &driverName);
    static QString findIioDevice(const QString &driverName);
    static QString readSysfs(const QString &path);

    QString m_time        { QStringLiteral("--:--:--") };
    QString m_date        { QStringLiteral("--") };
    QString m_temperature { QStringLiteral("--") };
    QString m_humidity    { QStringLiteral("--") };
    QString m_light       { QStringLiteral("--") };

    QString m_hwmonPath;
    QString m_iioPath;

    QTimer m_timeTimer;
    QTimer m_sensorTimer;
};
