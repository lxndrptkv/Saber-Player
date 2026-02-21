#include "playercontroller.h"
#include <cmath>
#include <complex>
#include <QRandomGenerator>
#include <QMutexLocker>
#include <QThread>
#include <QFileInfo>
#include <QDir>
#include <utility>

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
    : QObject(parent), m_isPlaying(false), m_position(0), m_duration(0), m_volume(50), m_shuffle(false), m_repeatMode(0), m_currentIndex(-1), m_artPending(false)
{
    const char * const vlc_args[] = {
        "--intf=dummy",
        "--ignore-config",
        "--quiet",
        "--no-video",
        "--no-sub-autodetect-file"
    };
    m_vlcInstance = libvlc_new(sizeof(vlc_args) / sizeof(vlc_args[0]), vlc_args);
    m_vlcPlayer = libvlc_media_player_new(m_vlcInstance);

    m_ticker = new QTimer(this);
    connect(m_ticker, &QTimer::timeout, this, &PlayerController::updateInterface);

    m_visTicker = new QTimer(this);
    connect(m_visTicker, &QTimer::timeout, this, &PlayerController::updateVisualizer);

    connect(&m_coverFetcher, &CoverFetcher::coverFound, this, [this](const QString &artist, const QString &album, const QString &path) {
        if (m_currentArtist == artist && m_currentAlbum == album) {
            m_currentArt = path;
            emit metaDataChanged();
        }
    });

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

PlayerController::~PlayerController() {
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
int PlayerController::repeatMode() const { return m_repeatMode; }
QString PlayerController::currentTitle() const { return m_currentTitle; }
QString PlayerController::currentArtist() const { return m_currentArtist; }
QString PlayerController::currentArt() const { return m_currentArt; }

qreal PlayerController::progress() const {
    if (m_duration <= 0) return 0.0;
    qreal p = static_cast<qreal>(m_position) / static_cast<qreal>(m_duration);
    if (std::isnan(p) || std::isinf(p)) return 0.0;
    return p;
}

void PlayerController::setShuffle(bool s) { if (m_shuffle != s) { m_shuffle = s; emit shuffleChanged(); } }
void PlayerController::setRepeatMode(int r) { if (m_repeatMode != r) { m_repeatMode = r; emit repeatModeChanged(); } }

QString PlayerController::formattedTime() const { return formatMilliseconds(m_position) + " / " + formatMilliseconds(m_duration); }

QString PlayerController::formatTime(qreal ms) const {
    if (std::isnan(ms) || std::isinf(ms)) return "00:00";
    return formatMilliseconds(static_cast<qint64>(ms));
}

QString PlayerController::formatMilliseconds(qint64 ms) const {
    if (ms < 0) return "00:00";
    qint64 totalSeconds = ms / 1000;
    qint64 minutes = totalSeconds / 60;
    qint64 seconds = totalSeconds % 60;
    return QString("%1:%2").arg(minutes, 2, 10, QChar('0')).arg(seconds, 2, 10, QChar('0'));
}

// ==========================================
// QUEUE LOGIC
// ==========================================
void PlayerController::enqueueTrack(const QString &url, const QString &title, const QString &artist, const QString &album, const QString &artUrl) {
    QVariantMap track;
    track["url"] = url;
    track["title"] = title;
    track["artist"] = artist;
    track["album"] = album;
    track["artUrl"] = artUrl;
    m_queue.append(track);
    emit queueChanged();
}

void PlayerController::removeQueueTrack(int index) {
    if (index >= 0 && index < m_queue.size()) {
        m_queue.removeAt(index);
        emit queueChanged();
    }
}

void PlayerController::clearQueue() {
    m_queue.clear();
    emit queueChanged();
}

void PlayerController::playTrackList(const QVariantList &trackUrls, int startIndex) {
    m_playlist = trackUrls;
    m_currentIndex = startIndex;
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size()) loadFile(m_playlist[m_currentIndex].toUrl());
}

void PlayerController::autoPlayNext() {
    if (m_repeatMode == 2) { seek(0); play(); return; }
    // If queue has tracks, intercept the playlist automatically!
    if (!m_queue.isEmpty() || !m_playlist.isEmpty()) {
        playNext();
    }
}

void PlayerController::playNext() {
    // INTERCEPT: If the queue has a song, play it immediately and ignore the main playlist
    if (!m_queue.isEmpty()) {
        QVariantMap nextTrack = m_queue.takeFirst().toMap();
        emit queueChanged();
        loadFile(QUrl(nextTrack["url"].toString()));
        return;
    }

    if (m_playlist.isEmpty()) return;
    if (m_shuffle) {
        if (m_playlist.size() > 1) {
            int nextIdx = m_currentIndex;
            while (nextIdx == m_currentIndex) nextIdx = QRandomGenerator::global()->bounded(m_playlist.size());
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
        while (nextIdx == m_currentIndex) nextIdx = QRandomGenerator::global()->bounded(m_playlist.size());
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
        m_ticker->stop(); m_visTicker->stop();
        emit isPlayingChanged();
    }
}

void PlayerController::stop() {
    if (m_vlcPlayer) {
        libvlc_media_player_stop(m_vlcPlayer);
        m_isPlaying = false;
        m_ticker->stop(); m_visTicker->stop();
        m_position = 0;
        QVariantList empty;
        for(int i = 0; i < 25; i++) { empty.append(10.0); m_smoothedSpectrum[i] = 10.0; }
        m_spectrum = empty;
        emit spectrumChanged();
        if (m_audioSink) m_audioSink->stop();
        emit isPlayingChanged(); emit positionChanged(); emit timeTextChanged();
    }
}

void PlayerController::seek(qreal ms) {
    if (std::isnan(ms) || std::isinf(ms)) return;
    if (m_vlcPlayer) {
        libvlc_media_player_set_time(m_vlcPlayer, static_cast<qint64>(ms));
        m_position = static_cast<qint64>(ms);
        emit positionChanged();
    }
}

void PlayerController::changeVolume(qreal vol) {
    if (std::isnan(vol) || std::isinf(vol)) return;
    m_volume = static_cast<int>(vol);
    if (m_audioSink) m_audioSink->setVolume(m_volume / 100.0f);
    emit volumeChanged();
}

void PlayerController::loadFile(const QUrl &fileUrl) {
    if (m_isPlaying) {
        m_isPlaying = false;
        if (m_vlcPlayer) libvlc_media_player_stop(m_vlcPlayer);
        m_ticker->stop(); m_visTicker->stop();
    }

    m_currentTitle = fileUrl.fileName();
    m_currentArtist = "Unknown Artist";
    m_currentAlbum = "Unknown Album";
    m_currentArt = "";
    m_artPending = false;
    emit metaDataChanged();

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
        libvlc_media_parse_flag_t parseFlags = (libvlc_media_parse_flag_t)(libvlc_media_parse_local | libvlc_media_fetch_local);
        libvlc_media_parse_with_options(media, parseFlags, -1);

        int timeout = 0;
        while (timeout < 25) {
            libvlc_media_parsed_status_t status = libvlc_media_get_parsed_status(media);
            if (status == libvlc_media_parsed_status_done || status == libvlc_media_parsed_status_failed) break;
            QThread::msleep(20);
            timeout++;
        }

        char* title = libvlc_media_get_meta(media, libvlc_meta_Title);
        char* artist = libvlc_media_get_meta(media, libvlc_meta_Artist);
        char* album = libvlc_media_get_meta(media, libvlc_meta_Album);
        char* art = libvlc_media_get_meta(media, libvlc_meta_ArtworkURL);

        if (title) { m_currentTitle = QString::fromUtf8(title); libvlc_free(title); }
        if (artist) { m_currentArtist = QString::fromUtf8(artist); libvlc_free(artist); }
        if (album) { m_currentAlbum = QString::fromUtf8(album); libvlc_free(album); }
        if (art) {
            m_currentArt = QString::fromUtf8(art);
            if (m_currentArt.startsWith("attachment://")) m_artPending = true;
            libvlc_free(art);
        }

        bool hasAttachment = m_currentArt.startsWith("attachment://");

        if (m_currentArt.isEmpty() || hasAttachment) {
            if (fileUrl.isLocalFile()) {
                QFileInfo fi(fileUrl.toLocalFile());
                QDir dir = fi.absoluteDir();
                QString foundArt = "";

                QStringList commonNames = {"cover.jpg", "cover.png", "folder.jpg", "folder.png", "front.jpg", "front.png", "album.jpg"};
                for (const QString &c : std::as_const(commonNames)) {
                    if (dir.exists(c)) { foundArt = QUrl::fromLocalFile(dir.absoluteFilePath(c)).toString(); break; }
                }

                if (foundArt.isEmpty()) {
                    QStringList allImages = dir.entryList({"*.jpg", "*.jpeg", "*.png"}, QDir::Files);
                    for (const QString &img : std::as_const(allImages)) {
                        QString lowerImg = img.toLower();
                        if (lowerImg.contains("cover") || lowerImg.contains("folder") || lowerImg.contains("front") || lowerImg.contains("art")) {
                            foundArt = QUrl::fromLocalFile(dir.absoluteFilePath(img)).toString(); break;
                        }
                    }
                    if (foundArt.isEmpty() && !allImages.isEmpty()) {
                        foundArt = QUrl::fromLocalFile(dir.absoluteFilePath(allImages.first())).toString();
                    }
                }

                if (!foundArt.isEmpty()) {
                    m_currentArt = foundArt;
                    m_artPending = false;
                }
            }
        }

        if (m_currentArt.isEmpty() || m_currentArt.startsWith("attachment://")) {
            m_coverFetcher.queueCoverFetch(m_currentArtist, m_currentAlbum, m_currentTitle);
        }

        emit metaDataChanged();

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
        if (m_artPending && m_isPlaying) {
            libvlc_media_t *media = libvlc_media_player_get_media(m_vlcPlayer);
            if (media) {
                char* art = libvlc_media_get_meta(media, libvlc_meta_ArtworkURL);
                if (art) {
                    QString newArt = QString::fromUtf8(art);
                    if (newArt.startsWith("file://")) {
                        m_currentArt = newArt;
                        m_artPending = false;
                        emit metaDataChanged();
                    }
                    libvlc_free(art);
                }
                libvlc_media_release(media);
            }
        }

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

        double db = -100.0;
        if (peakMag > 0.0001) {
            db = 20.0 * std::log10(peakMag / 32768.0);
        }

        double minDb = -35.0;
        double normalized = (db - minDb) / (-minDb);
        if (std::isnan(normalized) || std::isinf(normalized) || normalized < 0.0) normalized = 0.0;

        double powerScaled = std::pow(normalized, 1.2);
        if (std::isnan(powerScaled) || std::isinf(powerScaled)) powerScaled = 0.0;
        if (powerScaled > 1.0) powerScaled = 1.0;

        double targetHeight = 10.0 + (powerScaled * 180.0);
        if (std::isnan(targetHeight) || std::isinf(targetHeight)) targetHeight = 10.0;

        if (targetHeight > m_smoothedSpectrum[i]) {
            m_smoothedSpectrum[i] += 0.35 * (targetHeight - m_smoothedSpectrum[i]);
        } else {
            m_smoothedSpectrum[i] += 0.15 * (targetHeight - m_smoothedSpectrum[i]);
        }

        if (std::isnan(m_smoothedSpectrum[i]) || std::isinf(m_smoothedSpectrum[i])) m_smoothedSpectrum[i] = 10.0;
        newSpectrum.append(m_smoothedSpectrum[i]);
    }
    m_spectrum = newSpectrum;
    emit spectrumChanged();
}
