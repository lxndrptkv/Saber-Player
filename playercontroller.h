#ifndef PLAYERCONTROLLER_H
#define PLAYERCONTROLLER_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>
#include <vlc/vlc.h>
#include <QAudioSink>
#include <QMediaDevices>
#include <QAudioFormat>
#include <QIODevice>
#include <QThread>
#include <QMutex>
#include "coverfetcher.h"

class PlayerController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(QString currentSource READ currentSource NOTIFY currentSourceChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString formattedTime READ formattedTime NOTIFY timeTextChanged)
    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY positionChanged)

    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)

    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY metaDataChanged)
    Q_PROPERTY(QString currentArtist READ currentArtist NOTIFY metaDataChanged)
    Q_PROPERTY(QString currentAlbum READ currentAlbum NOTIFY metaDataChanged)
    Q_PROPERTY(QString currentArt READ currentArt NOTIFY metaDataChanged)

    // ==========================================
    // QUEUE SYSTEM PROPERTIES
    // ==========================================
    Q_PROPERTY(QVariantList currentQueue READ currentQueue NOTIFY queueChanged)
    Q_PROPERTY(bool isQueueOpen READ isQueueOpen WRITE setIsQueueOpen NOTIFY isQueueOpenChanged)

public:
    explicit PlayerController(QObject *parent = nullptr);
    ~PlayerController();

    bool isPlaying() const;
    QString currentSource() const;
    qint64 position() const;
    qint64 duration() const;
    qreal progress() const;
    QString formattedTime() const;
    int volume() const;
    QVariantList spectrum() const;

    bool shuffle() const;
    void setShuffle(bool s);

    int repeatMode() const;
    void setRepeatMode(int r);

    QString currentTitle() const;
    QString currentArtist() const;
    QString currentAlbum() const { return m_currentAlbum; }
    QString currentArt() const;

    QVariantList currentQueue() const { return m_queue; }
    bool isQueueOpen() const { return m_isQueueOpen; }
    void setIsQueueOpen(bool open) { if (m_isQueueOpen != open) { m_isQueueOpen = open; emit isQueueOpenChanged(); } }

    Q_INVOKABLE void seek(qreal ms);
    Q_INVOKABLE void changeVolume(qreal vol);
    Q_INVOKABLE QString formatTime(qreal ms) const;

    Q_INVOKABLE void playNext();
    Q_INVOKABLE void autoPlayNext();
    Q_INVOKABLE void playPrevious();
    Q_INVOKABLE void playTrackList(const QVariantList &trackUrls, int startIndex);

    // Queue Controls
    Q_INVOKABLE void enqueueTrack(const QString &url, const QString &title, const QString &artist, const QString &album, const QString &artUrl);
    Q_INVOKABLE void removeQueueTrack(int index);
    Q_INVOKABLE void clearQueue();

    void processAudio(const void* samples, unsigned count);

public slots:
    void play();
    void pause();
    void stop();
    void loadFile(const QUrl &fileUrl);

signals:
    void isPlayingChanged();
    void currentSourceChanged();
    void positionChanged();
    void durationChanged();
    void timeTextChanged();
    void volumeChanged();
    void spectrumChanged();
    void shuffleChanged();
    void repeatModeChanged();
    void trackEnded();
    void metaDataChanged();
    void queueChanged();
    void isQueueOpenChanged();

private slots:
    void updateInterface();
    void updateVisualizer();

private:
    libvlc_instance_t *m_vlcInstance;
    libvlc_media_player_t *m_vlcPlayer;
    QString m_currentSource;
    bool m_isPlaying;

    QString m_currentTitle;
    QString m_currentArtist;
    QString m_currentAlbum;
    QString m_currentArt;
    bool m_artPending;

    CoverFetcher m_coverFetcher;

    QTimer *m_ticker;
    QTimer *m_visTicker;

    qint64 m_position;
    qint64 m_duration;
    int m_volume;
    QVariantList m_spectrum;

    bool m_shuffle;
    int m_repeatMode;

    QVariantList m_playlist;
    int m_currentIndex;

    QVariantList m_queue;
    bool m_isQueueOpen = false;

    QAudioSink *m_audioSink = nullptr;
    QIODevice *m_audioOutput = nullptr;

    QMutex m_audioMutex;
    std::vector<int16_t> m_fftBuffer;
    std::vector<double> m_smoothedSpectrum;

    QString formatMilliseconds(qint64 ms) const;
};

#endif
