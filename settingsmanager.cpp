#include "settingsmanager.h"

SettingsManager::SettingsManager(QObject *parent) : QObject(parent), m_settings("SaberTeam", "SaberPlayer") {
    m_accentColor = m_settings.value("theme/accentColor", "#0055FF").toString();
    m_savedVolume = m_settings.value("audio/volume", 50).toInt();
    m_themeMode = m_settings.value("theme/mode", "Dark").toString();

    // Load new settings with smart defaults
    m_visualizerStyle = m_settings.value("ui/visualizerStyle", "Mirrored").toString();
    m_autoPlay = m_settings.value("app/autoPlay", true).toBool();
    m_minimizeToTray = m_settings.value("app/minimizeToTray", false).toBool();
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
