#include "settingsmanager.h"
#include <QCoreApplication>
#include <QStringList>

SettingsManager::SettingsManager(QObject *parent) : QObject(parent), m_settings("SaberTeam", "SaberPlayer") {
    m_accentColor = m_settings.value("theme/accentColor", "#0055FF").toString();
    m_savedVolume = m_settings.value("audio/volume", 50).toInt();
    m_themeMode = m_settings.value("theme/mode", "Dark").toString();
    m_visualizerStyle = m_settings.value("ui/visualizerStyle", "Mirrored").toString();
    m_autoPlay = m_settings.value("app/autoPlay", true).toBool();
    m_minimizeToTray = m_settings.value("app/minimizeToTray", false).toBool();
    m_contextMenuEnabled = m_settings.value("app/contextMenuEnabled", false).toBool();
}

QString SettingsManager::accentColor() const { return m_accentColor; }
void SettingsManager::setAccentColor(const QString &c) {
    if (m_accentColor != c) {
        m_accentColor = c;
        m_settings.setValue("theme/accentColor", c);
        emit accentColorChanged();
    }
}

int SettingsManager::savedVolume() const { return m_savedVolume; }
void SettingsManager::setSavedVolume(int v) {
    if (m_savedVolume != v) {
        m_savedVolume = v;
        m_settings.setValue("audio/volume", v);
        emit savedVolumeChanged();
    }
}

QString SettingsManager::themeMode() const { return m_themeMode; }
void SettingsManager::setThemeMode(const QString &mode) {
    if (m_themeMode != mode) {
        m_themeMode = mode;
        m_settings.setValue("theme/mode", mode);
        emit themeModeChanged();
    }
}

QString SettingsManager::visualizerStyle() const { return m_visualizerStyle; }
void SettingsManager::setVisualizerStyle(const QString &style) {
    if (m_visualizerStyle != style) {
        m_visualizerStyle = style;
        m_settings.setValue("ui/visualizerStyle", style);
        emit visualizerStyleChanged();
    }
}

bool SettingsManager::autoPlay() const { return m_autoPlay; }
void SettingsManager::setAutoPlay(bool play) {
    if (m_autoPlay != play) {
        m_autoPlay = play;
        m_settings.setValue("app/autoPlay", play);
        emit autoPlayChanged();
    }
}

bool SettingsManager::minimizeToTray() const { return m_minimizeToTray; }
void SettingsManager::setMinimizeToTray(bool min) {
    if (m_minimizeToTray != min) {
        m_minimizeToTray = min;
        m_settings.setValue("app/minimizeToTray", min);
        emit minimizeToTrayChanged();
    }
}

// ==========================================
// WINDOWS REGISTRY INTEGRATION (BRUTE FORCE)
// ==========================================
bool SettingsManager::contextMenuEnabled() const { return m_contextMenuEnabled; }
void SettingsManager::setContextMenuEnabled(bool enabled) {
    if (m_contextMenuEnabled != enabled) {
        m_contextMenuEnabled = enabled;
        m_settings.setValue("app/contextMenuEnabled", enabled);

        QString exePath = QCoreApplication::applicationFilePath().replace("/", "\\");

        // We will target the generic audio class, PLUS every major audio extension!
        QStringList registryTargets = {
            "SystemFileAssociations\\audio",
            "SystemFileAssociations\\.mp3",
            "SystemFileAssociations\\.flac",
            "SystemFileAssociations\\.wav",
            "SystemFileAssociations\\.ogg",
            "SystemFileAssociations\\.m4a"
        };

        for (const QString &target : registryTargets) {
            QString regPath = QString("HKEY_CURRENT_USER\\Software\\Classes\\%1\\shell\\SaberPlayer").arg(target);
            QSettings reg(regPath, QSettings::NativeFormat);

            if (enabled) {
                // Set the exact text that appears in the right-click menu
                reg.setValue(".", "Play with SaberPlayer");
                reg.setValue("Icon", exePath);

                // Write the command Windows will execute
                QSettings regCmd(regPath + "\\command", QSettings::NativeFormat);
                regCmd.setValue(".", QString("\"%1\" \"%2\" --mini").arg(exePath).arg("%1"));
            } else {
                // If the user turns the setting off, wipe all traces from the registry!
                reg.remove("");
            }
        }

        emit contextMenuEnabledChanged();
    }
}
