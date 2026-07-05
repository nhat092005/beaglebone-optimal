#include <QtGui/qguiapplication.h>
#include <QtGui/qfont.h>
#include <QtGui/qfontdatabase.h>
#include <QtCore/qlogging.h>
#include <QtQml/qqmlapplicationengine.h>
#include <QtQml/qqmlcontext.h>
#include <QtQuick/qquickwindow.h>
#include "SensorBackend.h"

#include <cstdio>
#include <fcntl.h>
#include <unistd.h>

namespace {

// qt-dashboard's stdio is redirected to /dev/null (see inittab), so this
// writes to /dev/kmsg instead -- it lands on the same serial console that
// boot-capture reads. Priority 3 (KERN_ERR) because the kernel cmdline sets
// console_loglevel=4 via "quiet", and only priority < console_loglevel is
// printed.
void logToKmsg(const char *msg)
{
	int fd = open("/dev/kmsg", O_WRONLY);
	if (fd < 0)
		return;
	dprintf(fd, "<3>%s\n", msg);
	close(fd);
}

} // namespace

int main(int argc, char *argv[])
{
	logToKmsg("qt-dashboard: process start");

	QGuiApplication app(argc, argv);
	logToKmsg("qt-dashboard: QGuiApplication ready");

	const int boldFontId =
		QFontDatabase::addApplicationFont(":/fonts/DejaVuSans-Bold.ttf");
	if (boldFontId == -1) {
		qWarning() << "Failed to load embedded bold font";
	} else {
		const QStringList families =
			QFontDatabase::applicationFontFamilies(boldFontId);
		if (!families.isEmpty())
			app.setFont(QFont(families.constFirst()));
	}
	logToKmsg("qt-dashboard: font loaded");

	SensorBackend sensorBackend;
	logToKmsg("qt-dashboard: sensor backend ready");

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty(
		QStringLiteral("sensorBackend"), &sensorBackend);
	QObject::connect(
		&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
		[]() { QCoreApplication::exit(EXIT_FAILURE); },
		Qt::QueuedConnection);

	engine.load(QUrl(QStringLiteral("qrc:/QtDashboard/qml/Main.qml")));
	logToKmsg("qt-dashboard: qml engine loaded");

	if (!engine.rootObjects().isEmpty()) {
		if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
			QObject::connect(window, &QQuickWindow::frameSwapped, window, []() {
				static bool logged = false;
				if (logged)
					return;
				logged = true;
				logToKmsg("qt-dashboard: first frame rendered");
			});
		} else {
			logToKmsg("qt-dashboard: root object is not a QQuickWindow");
		}
	} else {
		logToKmsg("qt-dashboard: no root object created");
	}

	return QGuiApplication::exec();
}
