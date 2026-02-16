#include "playercontroller.h"
#include <cmath>
#include <complex>
#include <QRandomGenerator>
#include <QMutexLocker>

namespace {
const double PI = 3.14159265358979323846;
typedef std::complex<double> Complex;

void fft(std::vector<Complex>& a) {
    int n = a.size();
    if (n <= 1) return;
    std::vector<Complex> a0(n / 2), a1(n / 2);
    for (int i = 0; i * 2 < n; i++) {
        a0[i] = a[i * 2];
        a1[i] = a[i * 2 + 1];
    }
    fft(a0);
    fft(a1);
    for (int i = 0; i < n / 2; i++) {
        Complex t = std::polar(1.0, -2 * PI * i / n) * a1[i];
        a[i] = a0[i] + t;
        a[i + n / 2] = a0[i] - t;
    }
}

int cb_audio_setup(void **data, char *format, unsigned *rate, unsigned *channels) {
    *rate = 44100;
    *channels = 2;
    memcpy(format, "S16N", 4);
    return 0;
}

void cb_audio_play(void *data, const void *samples, unsigned count, int64_t pts) {
    PlayerController* pc = static_cast<PlayerController*>(data);
    if (pc) pc->processAudio(samples, count);
}
}

PlayerController::PlayerController(QObject *parent)
    : QObject(parent), m_isPlaying(false), m_position(0), m_duration(0), m_volume(50), m_shuffle(false), m_repeatMode(0), m_currentIndex(-1)
{
    m_vlcInstance = libvlc_new(0, nullptr);
    m_vlcPlayer = libvlc_media_player_new(m_vlcInstance);

    m_ticker = new QTimer(this);
    connect(m_ticker, &QTimer::timeout, this, &PlayerController::updateInterface);

    m_visTicker = new QTimer(this);
    connect(m_visTicker, &QTimer::timeout, this, &PlayerController::updateVisualizer);

    for(int i = 0; i < 25; i++) {
        m_spectrum.append(10.0);
        m_smoothedSpectrum.push_back(10.0);
    }

    QAudioFormat format;
    format.setSampleRate(44100);
    format.setChannelCount(2);
    format.setSampleFormat(QAudioFormat::Int16);

    QAudioDevice info = QMediaDevices::defaultAudioOutput();
    m_audioSink = new QAudioSink(info, format, this);
    m_audioSink->setBufferSize(88200);
    m_audioOutput = m_audioSink->start();

    libvlc_audio_set_format_callbacks(m_vlcPlayer, cb_audio_setup, nullptr);
    libvlc_audio_set_callbacks(m_vlcPlayer, cb_audio_play, nullptr, nullptr, nullptr, nullptr, this);
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

bool PlayerController::shuffle() const { return m_shuffle; }
void PlayerController::setShuffle(bool s) {
    if (m_shuffle != s) {
        m_shuffle = s;
        emit shuffleChanged();
    }
}

int PlayerController::repeatMode() const { return m_repeatMode; }
void PlayerController::setRepeatMode(int r) {
    if (m_repeatMode != r) {
        m_repeatMode = r;
        emit repeatModeChanged();
    }
}

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

void PlayerController::playTrackList(const QVariantList &trackUrls, int startIndex) {
    m_playlist = trackUrls;
    m_currentIndex = startIndex;
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size()) {
        loadFile(m_playlist[m_currentIndex].toUrl());
    }
}

void PlayerController::autoPlayNext() {
    if (m_playlist.isEmpty()) return;
    if (m_repeatMode == 2) {
        seek(0);
        play();
        return;
    }
    playNext();
}

void PlayerController::playNext() {
    if (m_playlist.isEmpty()) return;
    if (m_shuffle) {
        if (m_playlist.size() > 1) {
            int nextIdx = m_currentIndex;
            while (nextIdx == m_currentIndex) {
                nextIdx = QRandomGenerator::global()->bounded(m_playlist.size());
            }
            m_currentIndex = nextIdx;
        }
    } else {
        m_currentIndex++;
        if (m_currentIndex >= m_playlist.size()) {
            if (m_repeatMode == 1) m_currentIndex = 0;
            else { m_currentIndex = m_playlist.size() - 1; stop(); return; }
        }
    }
    loadFile(m_playlist[m_currentIndex].toUrl());
}

void PlayerController::playPrevious() {
    if (m_playlist.isEmpty()) { seek(0); return; }
    if (m_position > 3000) { seek(0); return; }

    if (m_shuffle && m_playlist.size() > 1) {
        int nextIdx = m_currentIndex;
        while (nextIdx == m_currentIndex) {
            nextIdx = QRandomGenerator::global()->bounded(m_playlist.size());
        }
        m_currentIndex = nextIdx;
    } else {
        m_currentIndex--;
        if (m_currentIndex < 0) {
            if (m_repeatMode == 1) m_currentIndex = m_playlist.size() - 1;
            else m_currentIndex = 0;
        }
    }
    loadFile(m_playlist[m_currentIndex].toUrl());
}

void PlayerController::play() {
    if (m_vlcPlayer) {
        if (m_audioSink && m_audioSink->state() == QAudio::SuspendedState) m_audioSink->resume();
        libvlc_media_player_play(m_vlcPlayer);
        m_isPlaying = true;
        m_ticker->start(250);
        m_visTicker->start(16);
        emit isPlayingChanged();
    }
}

void PlayerController::pause() {
    if (m_vlcPlayer) {
        if (m_audioSink) m_audioSink->suspend();
        libvlc_media_player_pause(m_vlcPlayer);
        m_isPlaying = false;
        m_ticker->stop();
        m_visTicker->stop();
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
        QVariantList empty;
        for(int i = 0; i < 25; i++) { empty.append(10.0); m_smoothedSpectrum[i] = 10.0; }
        m_spectrum = empty;
        emit spectrumChanged();
        if (m_audioSink) m_audioSink->stop();
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
    }
}

void PlayerController::changeVolume(int vol) {
    m_volume = vol;
    if (m_audioSink) m_audioSink->setVolume(vol / 100.0f);
    emit volumeChanged();
}

void PlayerController::loadFile(const QUrl &fileUrl) {
    if (m_isPlaying) {
        m_isPlaying = false;
        if (m_vlcPlayer) libvlc_media_player_stop(m_vlcPlayer);
        m_ticker->stop();
        m_visTicker->stop();
    }
    libvlc_media_t *media = nullptr;
    if (fileUrl.scheme() == "cdda") {
        QString drive = fileUrl.path();
        QString mrl = "cdda://" + drive;
        media = libvlc_media_new_location(m_vlcInstance, mrl.toUtf8().constData());
        if (media) {
            QString query = fileUrl.query();
            if (query.startsWith("track=")) {
                QString opt = ":cdda-track=" + query.mid(6);
                libvlc_media_add_option(media, opt.toUtf8().constData());
            }
        }
        m_currentSource = "Audio CD - Track " + fileUrl.query().mid(6);
    } else {
        QByteArray urlBytes = fileUrl.toString().toUtf8();
        media = libvlc_media_new_location(m_vlcInstance, urlBytes.constData());
        m_currentSource = fileUrl.fileName();
    }
    if (media) {
        libvlc_media_player_set_media(m_vlcPlayer, media);
        libvlc_media_release(media);
        if (m_audioSink) {
            m_audioSink->stop();
            m_audioSink->setBufferSize(88200);
            m_audioOutput = m_audioSink->start();
            m_audioSink->setVolume(m_volume / 100.0f);
        }
        emit currentSourceChanged();
        play();
    }
}

void PlayerController::updateInterface() {
    if (m_vlcPlayer) {
        libvlc_state_t state = libvlc_media_player_get_state(m_vlcPlayer);
        if (state == libvlc_Ended) {
            if (m_isPlaying) {
                m_isPlaying = false;
                m_ticker->stop();
                m_visTicker->stop();
                emit isPlayingChanged();
                emit trackEnded();
            }
            return;
        }
        qint64 currentPos = libvlc_media_player_get_time(m_vlcPlayer);
        if (currentPos >= 0 && currentPos != m_position) { m_position = currentPos; emit positionChanged(); }
        qint64 currentDur = libvlc_media_player_get_length(m_vlcPlayer);
        if (currentDur >= 0 && currentDur != m_duration) { m_duration = currentDur; emit durationChanged(); }
        emit timeTextChanged();
    }
}

void PlayerController::processAudio(const void* samples, unsigned count) {
    if (!m_isPlaying) return;
    qint64 bytesToWrite = count * 4;
    if (m_audioSink && m_audioOutput) {
        qint64 bytesWritten = 0;
        const char* ptr = static_cast<const char*>(samples);
        while (bytesWritten < bytesToWrite && m_isPlaying) {
            qint64 freeSpace = m_audioSink->bytesFree();
            if (freeSpace > 0) {
                qint64 chunk = std::min(freeSpace, bytesToWrite - bytesWritten);
                m_audioOutput->write(ptr + bytesWritten, chunk);
                bytesWritten += chunk;
            } else QThread::msleep(1);
        }
    }
    const int16_t* pcm = static_cast<const int16_t*>(samples);
    QMutexLocker locker(&m_audioMutex);
    for (unsigned i = 0; i < count; ++i) {
        int16_t mono = (pcm[i * 2] + pcm[i * 2 + 1]) / 2;
        m_fftBuffer.push_back(mono);
    }
    if (m_fftBuffer.size() > 4096) m_fftBuffer.erase(m_fftBuffer.begin(), m_fftBuffer.begin() + (m_fftBuffer.size() - 4096));
}

// ===============================================
// HIGH SENSITIVITY LOGARITHMIC VISUALIZER
// ===============================================
void PlayerController::updateVisualizer() {
    if (!m_isPlaying) return;
    std::vector<int16_t> localBuffer;
    {
        QMutexLocker locker(&m_audioMutex);
        if (m_fftBuffer.size() < 1024) return;
        localBuffer.assign(m_fftBuffer.end() - 1024, m_fftBuffer.end());
    }
    std::vector<Complex> data(1024);
    for (int i = 0; i < 1024; ++i) {
        double window = 0.54 - 0.46 * std::cos(2 * PI * i / 1023.0);
        data[i] = Complex(localBuffer[i] * window, 0);
    }
    fft(data);

    QVariantList newSpectrum;
    double logMinFreq = std::log10(40.0);
    double logMaxFreq = std::log10(16000.0);

    for (int i = 0; i < 25; i++) {
        // Calculate frequency bounds for this bar
        double lowFreq = std::pow(10.0, logMinFreq + (logMaxFreq - logMinFreq) * i / 25.0);
        double highFreq = std::pow(10.0, logMinFreq + (logMaxFreq - logMinFreq) * (i + 1) / 25.0);

        int lowBin = std::max(1, (int)(lowFreq / (44100.0 / 1024.0)));
        int highBin = std::min(511, (int)(highFreq / (44100.0 / 1024.0)));
        if (highBin <= lowBin) highBin = lowBin + 1;

        double peakMag = 0.0;
        for (int b = lowBin; b < highBin; b++) {
            double mag = std::abs(data[b]);
            if (mag > peakMag) peakMag = mag;
        }

        double db = 0.0;
        if (peakMag > 0.0) {
            // Reference level for 16-bit audio
            db = 20.0 * std::log10(peakMag / 32768.0);
        }

        // --- NEW NONLINEAR SCALING LOGIC ---
        // Floor at -50dB for high sensitivity to quiet details
        double minDb = -50.0;
        double normalized = (db - minDb) / (-minDb); // 0.0 to 1.0 range
        if (normalized < 0.0) normalized = 0.0;

        // Power scaling (0.6): This makes the bars "jump" more for low signals
        // but slows down their approach to the top.
        double powerScaled = std::pow(normalized, 0.6);
        if (powerScaled > 1.0) powerScaled = 1.0;

        double targetHeight = 10.0 + (powerScaled * 180.0);

        // GRAVITY TUNE: Snappy rise, natural fall
        if (targetHeight > m_smoothedSpectrum[i]) {
            m_smoothedSpectrum[i] += 0.75 * (targetHeight - m_smoothedSpectrum[i]);
        } else {
            m_smoothedSpectrum[i] += 0.20 * (targetHeight - m_smoothedSpectrum[i]);
        }
        newSpectrum.append(m_smoothedSpectrum[i]);
    }
    m_spectrum = newSpectrum;
    emit spectrumChanged();
}
