#ifndef PLAYERCONTROLLER_H
#define PLAYERCONTROLLER_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>
#include <vlc/vlc.h>
#include <QAudioSink>
#include <QMediaDevices>
#include <QAudioFormat>
#include <QIODevice>
#include <QThread>

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

    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY shuffleChanged)
    Q_PROPERTY(int repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)

public:
    explicit PlayerController(QObject *parent = nullptr);
    ~PlayerController();

    bool isPlaying() const;
    QString currentSource() const;
    qint64 position() const;
    qint64 duration() const;
    QString formattedTime() const;
    int volume() const;
    QVariantList spectrum() const;

    bool shuffle() const;
    void setShuffle(bool s);

    int repeatMode() const;
    void setRepeatMode(int r);

    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE void changeVolume(int vol);
    Q_INVOKABLE QString formatTime(qint64 ms) const;

    Q_INVOKABLE void playNext();
    Q_INVOKABLE void playPrevious();
    Q_INVOKABLE void playTrackList(const QVariantList &trackUrls, int startIndex);

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

private slots:
    void updateInterface();

private:
    libvlc_instance_t *m_vlcInstance;
    libvlc_media_player_t *m_vlcPlayer;
    QString m_currentSource;
    bool m_isPlaying;

    QTimer *m_ticker;

    qint64 m_position;
    qint64 m_duration;
    int m_volume;
    QVariantList m_spectrum;

    bool m_shuffle;
    int m_repeatMode;

    QVariantList m_playlist;
    int m_currentIndex;

    QAudioSink *m_audioSink = nullptr;
    QIODevice *m_audioOutput = nullptr;
    std::vector<int16_t> m_fftBuffer;

    QString formatMilliseconds(qint64 ms) const;
};

#endif
