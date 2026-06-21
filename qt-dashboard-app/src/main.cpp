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

	const int regularFontId =
		QFontDatabase::addApplicationFont(":/fonts/DejaVuSans.ttf");
	const int boldFontId = QFontDatabase::addApplicationFont(
		":/fonts/DejaVuSans-Bold.ttf");

	if (regularFontId == -1 || boldFontId == -1) {
		qWarning() << "Failed to load embedded dashboard fonts"
			   << regularFontId << boldFontId;
	} else {
		const QStringList families =
			QFontDatabase::applicationFontFamilies(regularFontId);
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
	engine.loadFromModule("QtDashboard", "Main");

	return QGuiApplication::exec();
}
