#include "playercontroller.h"
#include <cmath>

PlayerController::PlayerController(QObject *parent)
    : QObject(parent), m_isPlaying(false), m_position(0), m_duration(0), m_volume(50)
{
    m_vlcInstance = libvlc_new(0, nullptr);
    m_vlcPlayer = libvlc_media_player_new(m_vlcInstance);

    m_ticker = new QTimer(this);
    connect(m_ticker, &QTimer::timeout, this, &PlayerController::updateInterface);

    // Set up the high-speed 30fps visualizer timer
    m_visTicker = new QTimer(this);
    connect(m_visTicker, &QTimer::timeout, this, &PlayerController::updateVisualizer);

    // Initialize flat visualizer array
    for(int i = 0; i < 25; i++) {
        m_spectrum.append(10.0);
    }
}

PlayerController::~PlayerController()
{
    if (m_vlcPlayer) {
        libvlc_media_player_stop(m_vlcPlayer);
        libvlc_media_player_release(m_vlcPlayer);
    }
    if (m_vlcInstance) libvlc_release(m_vlcInstance);
}

bool PlayerController::isPlaying() const { return m_isPlaying; }
QString PlayerController::currentSource() const { return m_currentSource; }
qint64 PlayerController::position() const { return m_position; }
qint64 PlayerController::duration() const { return m_duration; }
int PlayerController::volume() const { return m_volume; }
QVariantList PlayerController::spectrum() const { return m_spectrum; }

QString PlayerController::formattedTime() const {
    return formatMilliseconds(m_position) + " / " + formatMilliseconds(m_duration);
}

QString PlayerController::formatTime(qint64 ms) const {
    return formatMilliseconds(ms);
}

QString PlayerController::formatMilliseconds(qint64 ms) const {
    if (ms < 0) return "00:00";
    qint64 totalSeconds = ms / 1000;
    qint64 minutes = totalSeconds / 60;
    qint64 seconds = totalSeconds % 60;
    return QString("%1:%2").arg(minutes, 2, 10, QChar('0')).arg(seconds, 2, 10, QChar('0'));
}

void PlayerController::play() {
    if (m_vlcPlayer) {
        libvlc_media_player_play(m_vlcPlayer);
        m_isPlaying = true;
        m_ticker->start(250);
        m_visTicker->start(33); // Start 30fps visualizer loop
        emit isPlayingChanged();
    }
}

void PlayerController::pause() {
    if (m_vlcPlayer) {
        libvlc_media_player_pause(m_vlcPlayer);
        m_isPlaying = false;
        m_ticker->stop();
        m_visTicker->stop(); // Freeze visualizer immediately
        emit isPlayingChanged();
    }
}

void PlayerController::stop() {
    if (m_vlcPlayer) {
        libvlc_media_player_stop(m_vlcPlayer);
        m_isPlaying = false;
        m_ticker->stop();
        m_visTicker->stop();
        m_position = 0;

        // Reset spectrum to flat lines
        QVariantList empty;
        for(int i = 0; i < 25; i++) empty.append(10.0);
        m_spectrum = empty;
        emit spectrumChanged();

        emit isPlayingChanged();
        emit positionChanged();
        emit timeTextChanged();
    }
}

void PlayerController::seek(qint64 ms) {
    if (m_vlcPlayer) {
        libvlc_media_player_set_time(m_vlcPlayer, ms);
        m_position = ms;
        emit positionChanged();
        // Immediately update visualizer so it skips visually too
        updateVisualizer();
    }
}

void PlayerController::changeVolume(int vol) {
    m_volume = vol;
    if (m_vlcPlayer) {
        libvlc_audio_set_volume(m_vlcPlayer, vol);
    }
    emit volumeChanged();
}

void PlayerController::loadFile(const QUrl &fileUrl) {
    QByteArray urlBytes = fileUrl.toString().toUtf8();
    libvlc_media_t *media = libvlc_media_new_location(m_vlcInstance, urlBytes.constData());
    if (media) {
        libvlc_media_player_set_media(m_vlcPlayer, media);
        libvlc_media_release(media);
        m_currentSource = fileUrl.fileName();
        emit currentSourceChanged();
        play();
    }
}

void PlayerController::updateInterface() {
    if (m_vlcPlayer) {
        qint64 currentPos = libvlc_media_player_get_time(m_vlcPlayer);
        if (currentPos >= 0 && currentPos != m_position) {
            m_position = currentPos;
            emit positionChanged();
        }

        qint64 currentDur = libvlc_media_player_get_length(m_vlcPlayer);
        if (currentDur >= 0 && currentDur != m_duration) {
            m_duration = currentDur;
            emit durationChanged();
        }

        if (libvlc_audio_get_volume(m_vlcPlayer) != m_volume) {
            libvlc_audio_set_volume(m_vlcPlayer, m_volume);
        }

        emit timeTextChanged();
    }
}

// C++ Mathematical Audio Visualizer Engine
void PlayerController::updateVisualizer() {
    if (!m_isPlaying || !m_vlcPlayer) return;

    qint64 pos = libvlc_media_player_get_time(m_vlcPlayer);
    if (pos < 0) return;

    double t = (double)pos / 1000.0;
    QVariantList newSpectrum;

    for (int i = 0; i < 25; ++i) {
        // Create deterministic frequencies and phases
        double freq = 2.0 + (i * 0.3);
        double phase = i * 0.4;

        // Combine multiple sine waves for a complex, realistic look
        double wave1 = std::sin(t * freq + phase);
        double wave2 = std::cos(t * freq * 1.5 + phase * 2.0);
        double wave3 = std::sin(t * freq * 0.5 - phase);

        double val = (wave1 + wave2 + wave3) / 3.0;
        val = std::abs(val);

        // Bell curve shape: center bands are taller
        double distFromCenter = std::abs(i - 12) / 12.0;
        double heightMultiplier = 1.0 - (distFromCenter * 0.7);

        // Inject a simulated rhythmic 120BPM "beat" into the center bass bands
        if (distFromCenter < 0.3) {
            double beat = std::pow(std::sin(t * 3.14159265358979323846 * 2.0), 4.0);
            val = val * 0.5 + beat * 0.5;
        }

        // Calculate final pixel height (max ~170px)
        double finalHeight = 10.0 + (val * 160.0 * heightMultiplier);
        newSpectrum.append(finalHeight);
    }

    m_spectrum = newSpectrum;
    emit spectrumChanged();
}
