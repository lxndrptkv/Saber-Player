#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QFileInfo>
#include <QIcon> // NEW: Required to handle Windows Icons!

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // PERFECT FIX: Set the global application icon for the Taskbar and Titlebar right at startup!
    app.setWindowIcon(QIcon(":/qt/qml/SaberPlayer/logo.png"));

    // Default startup states
    QString startFile = "";
    bool startMini = false;

    // Parse command line arguments passed by Windows Explorer
    for (int i = 1; i < argc; ++i) {
        QString arg = argv[i];
        if (arg == "--mini") {
            startMini = true;
        } else if (QFileInfo::exists(arg)) {
            // Converts the Windows path into a URL the VLC engine can read safely
            startFile = QUrl::fromLocalFile(arg).toString();
        }
    }

    QQmlApplicationEngine engine;

    // Inject the intercepted commands directly into the QML Root Context
    engine.rootContext()->setContextProperty("cmdStartFile", startFile);
    engine.rootContext()->setContextProperty("cmdStartMini", startMini);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.loadFromModule("SaberPlayer", "Main");

    return app.exec();
}
