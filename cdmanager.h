#ifndef CDMANAGER_H
#define CDMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QUrl>
#include <QtQml/qqml.h>
#include <vlc/vlc.h>

class CdManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit CdManager(QObject *parent = nullptr);
    ~CdManager();

    Q_INVOKABLE QVariantList detectCdDrives();
    Q_INVOKABLE QVariantList getCdTracks(const QString &drivePath);

    // NEW: CD Ripping Engine
    Q_INVOKABLE void ripCd(const QVariantList &tracks, const QUrl &outputDir, const QString &format, int bitrate);

signals:
    // UI Triggers for the Progress Bar
    void ripProgressUpdated(int currentTrack, int totalTracks, QString trackName);
    void ripFinished();

private:
    libvlc_instance_t *m_vlcScanner;

    // Background worker to prevent UI freezing
    void performRip(QVariantList tracks, QString outputDirPath, QString format, int bitrate);
};

#endif
