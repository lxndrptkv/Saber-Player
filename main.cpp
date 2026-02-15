#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Force Fusion style to support custom dark theme backgrounds
    QQuickStyle::setStyle("Fusion");

    QQmlApplicationEngine engine;
    const QUrl url(u"qrc:/qt/qml/SaberPlayer/Main.qml"_qs);  // Fixed: Added /qt/qml/ prefix as required by Qt 6 standard setup
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
