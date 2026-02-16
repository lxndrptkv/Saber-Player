#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QtQml/qqml.h>

class SettingsManager : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(int savedVolume READ savedVolume WRITE setSavedVolume NOTIFY savedVolumeChanged)
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(QString visualizerStyle READ visualizerStyle WRITE setVisualizerStyle NOTIFY visualizerStyleChanged)
    Q_PROPERTY(bool autoPlay READ autoPlay WRITE setAutoPlay NOTIFY autoPlayChanged)
    Q_PROPERTY(bool minimizeToTray READ minimizeToTray WRITE setMinimizeToTray NOTIFY minimizeToTrayChanged)

    // NEW: Windows Context Menu Toggle
    Q_PROPERTY(bool contextMenuEnabled READ contextMenuEnabled WRITE setContextMenuEnabled NOTIFY contextMenuEnabledChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString accentColor() const;
    void setAccentColor(const QString &c);

    int savedVolume() const;
    void setSavedVolume(int v);

    QString themeMode() const;
    void setThemeMode(const QString &mode);

    QString visualizerStyle() const;
    void setVisualizerStyle(const QString &style);

    bool autoPlay() const;
    void setAutoPlay(bool play);

    bool minimizeToTray() const;
    void setMinimizeToTray(bool min);

    bool contextMenuEnabled() const;
    void setContextMenuEnabled(bool enabled);

signals:
    void accentColorChanged();
    void savedVolumeChanged();
    void themeModeChanged();
    void visualizerStyleChanged();
    void autoPlayChanged();
    void minimizeToTrayChanged();
    void contextMenuEnabledChanged();

private:
    QSettings m_settings;
    QString m_accentColor;
    int m_savedVolume;
    QString m_themeMode;
    QString m_visualizerStyle;
    bool m_autoPlay;
    bool m_minimizeToTray;
    bool m_contextMenuEnabled;
};

#endif
