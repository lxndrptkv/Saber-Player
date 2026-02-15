#ifndef PLAYERCONTROLLER_H
#define PLAYERCONTROLLER_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>
#include <vlc/vlc.h>

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

    // NEW: C++ driven Audio Spectrum
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)

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

    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE void changeVolume(int vol);
    Q_INVOKABLE QString formatTime(qint64 ms) const;

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
    void spectrumChanged(); // NEW

private slots:
    void updateInterface();
    void updateVisualizer(); // NEW

private:
    libvlc_instance_t *m_vlcInstance;
    libvlc_media_player_t *m_vlcPlayer;
    QString m_currentSource;
    bool m_isPlaying;

    QTimer *m_ticker;       // UI Updates (250ms)
    QTimer *m_visTicker;    // Visualizer Updates (33ms / 30fps)

    qint64 m_position;
    qint64 m_duration;
    int m_volume;
    QVariantList m_spectrum; // Stores the 25 bar heights

    QString formatMilliseconds(qint64 ms) const;
};

#endif
