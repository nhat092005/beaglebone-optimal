#include <QtGui/qguiapplication.h>
#include <QtGui/qfont.h>
#include <QtGui/qfontdatabase.h>
#include <QtCore/qlogging.h>
#include <QtQml/qqmlapplicationengine.h>
#include <QtQml/qqmlcontext.h>
#include "SensorBackend.h"

int main(int argc, char *argv[])
{
	QGuiApplication app(argc, argv);

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

	SensorBackend sensorBackend;

	QQmlApplicationEngine engine;
	engine.rootContext()->setContextProperty(
		QStringLiteral("sensorBackend"), &sensorBackend);
	QObject::connect(
		&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
		[]() { QCoreApplication::exit(EXIT_FAILURE); },
		Qt::QueuedConnection);

	engine.load(QUrl(QStringLiteral("qrc:/QtDashboard/qml/Main.qml")));

	return QGuiApplication::exec();
}
