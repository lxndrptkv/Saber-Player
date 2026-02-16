#include "cdmanager.h"
#include <QStorageInfo>
#include <QDir>
#include <QFile>
#include <QByteArray>
#include <QThread>
#include <QtConcurrent>
#include <QRegularExpression>
#include <QUrl>

CdManager::CdManager(QObject *parent) : QObject(parent) {
    const char * const vlc_args[] = {
        "--no-video",
        "--no-audio",
        "--metadata-network-access"
    };
    m_vlcScanner = libvlc_new(sizeof(vlc_args) / sizeof(vlc_args[0]), vlc_args);
}

CdManager::~CdManager() {
    if (m_vlcScanner) {
        libvlc_release(m_vlcScanner);
    }
}

QVariantList CdManager::detectCdDrives() {
    QVariantList drives;
    for (const QStorageInfo &storage : QStorageInfo::mountedVolumes()) {
        if (storage.isValid() && storage.isReady()) {
            QDir dir(storage.rootPath());
            QStringList cdaFiles = dir.entryList({"*.cda"}, QDir::Files);
            if (!cdaFiles.isEmpty()) {
                QVariantMap driveInfo;
                driveInfo["path"] = storage.rootPath();

                QString volName = storage.name().trimmed();
                if (volName.isEmpty() || volName == "Audio CD") {
                    volName = "Unknown Album";
                }

                driveInfo["name"] = volName;
                driveInfo["trackCount"] = cdaFiles.size();
                drives.append(driveInfo);
            }
        }
    }
    return drives;
}

QVariantList CdManager::getCdTracks(const QString &drivePath) {
    QVariantList tracks;
    QDir dir(drivePath);
    QStringList cdaFiles = dir.entryList({"*.cda"}, QDir::Files);
    QString driveLetter = drivePath.left(2);

    QStorageInfo storage(drivePath);
    QString albumName = storage.name().trimmed();
    if (albumName.isEmpty() || albumName == "Audio CD") albumName = "Unknown CD";
    QString albumArtist = "Unknown Artist";

    bool usedSubitems = false;

    if (m_vlcScanner) {
        QString mrl = "cdda:///" + driveLetter + "/";
        libvlc_media_t *disc = libvlc_media_new_location(m_vlcScanner, mrl.toUtf8().constData());

        if (disc) {
            libvlc_media_parse_flag_t parseFlags = (libvlc_media_parse_flag_t)(
                libvlc_media_parse_local |
                libvlc_media_parse_network |
                libvlc_media_fetch_network
                );
            libvlc_media_parse_with_options(disc, parseFlags, -1);

            int timeout = 0;
            while (libvlc_media_get_parsed_status(disc) != libvlc_media_parsed_status_done &&
                   libvlc_media_get_parsed_status(disc) != libvlc_media_parsed_status_failed &&
                   timeout < 200) {
                QThread::msleep(50);
                timeout++;
            }

            char* metaAlbum = libvlc_media_get_meta(disc, libvlc_meta_Album);
            char* metaArtist = libvlc_media_get_meta(disc, libvlc_meta_Artist);
            if (metaAlbum) {
                QString a = QString::fromUtf8(metaAlbum).trimmed();
                if (!a.isEmpty()) albumName = a;
                libvlc_free(metaAlbum);
            }
            if (metaArtist) {
                QString a = QString::fromUtf8(metaArtist).trimmed();
                if (!a.isEmpty()) albumArtist = a;
                libvlc_free(metaArtist);
            }

            libvlc_media_list_t *subitems = libvlc_media_subitems(disc);
            if (subitems) {
                libvlc_media_list_lock(subitems);
                int count = libvlc_media_list_count(subitems);

                if (count > 0) {
                    usedSubitems = true;
                    for (int i = 0; i < count; i++) {
                        libvlc_media_t *trackMedia = libvlc_media_list_item_at_index(subitems, i);
                        if (trackMedia) {
                            QVariantMap track;
                            int trackNum = i + 1;

                            char* tTitle = libvlc_media_get_meta(trackMedia, libvlc_meta_Title);
                            char* tArtist = libvlc_media_get_meta(trackMedia, libvlc_meta_Artist);

                            QString trackName = tTitle ? QString::fromUtf8(tTitle) : "Track " + QString::number(trackNum);
                            QString tArtistStr = tArtist ? QString::fromUtf8(tArtist) : albumArtist;

                            if (tTitle) libvlc_free(tTitle);
                            if (tArtist) libvlc_free(tArtist);

                            if (trackName.startsWith("cdda://", Qt::CaseInsensitive)) {
                                trackName = "Track " + QString::number(trackNum);
                            }

                            libvlc_time_t dur = libvlc_media_get_duration(trackMedia);
                            QString durationStr = "00:00";

                            if (dur > 0) {
                                int totalSeconds = dur / 1000;
                                durationStr = QString("%1:%2").arg(totalSeconds / 60).arg(totalSeconds % 60, 2, 10, QChar('0'));
                            } else {
                                if (i < cdaFiles.size()) {
                                    QFile file(dir.absoluteFilePath(cdaFiles[i]));
                                    if (file.open(QIODevice::ReadOnly)) {
                                        QByteArray data = file.read(44);
                                        if (data.size() >= 36) {
                                            int frames = *reinterpret_cast<const int*>(data.constData() + 32);
                                            int ts = frames / 75;
                                            durationStr = QString("%1:%2").arg(ts / 60).arg(ts % 60, 2, 10, QChar('0'));
                                        }
                                        file.close();
                                    }
                                }
                            }

                            track["trackName"] = trackName;
                            track["trackNumber"] = trackNum;
                            track["trackArtist"] = tArtistStr;
                            track["trackAlbum"] = albumName;
                            track["trackSize"] = "CDDA";

                            char* trackMrl = libvlc_media_get_mrl(trackMedia);
                            if (trackMrl) {
                                track["trackUrl"] = QString::fromUtf8(trackMrl);
                                libvlc_free(trackMrl);
                            } else {
                                track["trackUrl"] = "cdda:///" + driveLetter + "/?track=" + QString::number(trackNum);
                            }

                            track["trackDuration"] = durationStr;
                            tracks.append(track);
                            libvlc_media_release(trackMedia);
                        }
                    }
                }
                libvlc_media_list_unlock(subitems);
                libvlc_media_list_release(subitems);
            }
            libvlc_media_release(disc);
        }
    }

    if (!usedSubitems) {
        int trackNum = 1;
        for (const QString &fileName : cdaFiles) {
            QVariantMap track;
            track["trackName"] = "Track " + QString::number(trackNum);
            track["trackNumber"] = trackNum;
            track["trackArtist"] = albumArtist;
            track["trackAlbum"] = albumName;
            track["trackSize"] = "CDDA";

            int totalSeconds = 0;
            QFile file(dir.absoluteFilePath(fileName));
            if (file.open(QIODevice::ReadOnly)) {
                QByteArray data = file.read(44);
                if (data.size() >= 36) {
                    int frames = *reinterpret_cast<const int*>(data.constData() + 32);
                    totalSeconds = frames / 75;
                }
                file.close();
            }

            track["trackDuration"] = QString("%1:%2").arg(totalSeconds / 60).arg(totalSeconds % 60, 2, 10, QChar('0'));
            track["trackUrl"] = "cdda:///" + driveLetter + "/?track=" + QString::number(trackNum);

            tracks.append(track);
            trackNum++;
        }
    }

    return tracks;
}

// ===============================================
// THE ASYNC CD RIPPER ENGINE
// ===============================================
void CdManager::ripCd(const QVariantList &tracks, const QUrl &outputDir, const QString &format, int bitrate) {
    QString outPath = outputDir.toLocalFile();
    QtConcurrent::run([this, tracks, outPath, format, bitrate]() {
        performRip(tracks, outPath, format, bitrate);
    });
}

void CdManager::performRip(QVariantList tracks, QString outputDirPath, QString format, int bitrate) {
    // Spin up a silent, headless instance of VLC strictly for ripping
    const char * const vlc_args[] = { "--no-video", "--no-audio" };
    libvlc_instance_t *vlc = libvlc_new(sizeof(vlc_args) / sizeof(vlc_args[0]), vlc_args);

    // Sanitize the directory path for VLC (Requires forward slashes!)
    QString cleanDir = outputDirPath;
    cleanDir.replace("\\", "/");

    QDir().mkpath(cleanDir); // Ensure the folder actually exists

    for (int i = 0; i < tracks.size(); ++i) {
        QVariantMap track = tracks[i].toMap();
        QString rawUrl = track["trackUrl"].toString();
        QString name = track["trackName"].toString();
        QString num = QString::number(track["trackNumber"].toInt()).rightJustified(2, '0');

        // Clean out invalid Windows filename characters
        QString safeName = name;
        safeName.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");

        QString ext = format.toLower();
        QString outFile = cleanDir + "/" + num + " - " + safeName + "." + ext;

        emit ripProgressUpdated(i + 1, tracks.size(), name);

        // PERFECT URL PARSING: Extract the Drive MRL and the Hardware Track Number
        QUrl urlObj(rawUrl);
        QString drive = urlObj.path();
        QString mrl = "cdda://" + drive;

        libvlc_media_t *media = libvlc_media_new_location(vlc, mrl.toUtf8().constData());

        if (urlObj.hasQuery()) {
            QString query = urlObj.query();
            if (query.startsWith("track=")) {
                QString opt = ":cdda-track=" + query.mid(6);
                libvlc_media_add_option(media, opt.toUtf8().constData());
            }
        }

        // VLC SOUT Transcoding Chains (Wraps the file path in escaped quotes to prevent space-bar crashes)
        QString sout;
        if (format == "MP3") {
            sout = QString(":sout=#transcode{vcodec=none,acodec=mp3,ab=%1,channels=2,samplerate=44100}:std{access=file,mux=raw,dst=\"%2\"}").arg(bitrate).arg(outFile);
        } else if (format == "FLAC") {
            sout = QString(":sout=#transcode{vcodec=none,acodec=flac,channels=2,samplerate=44100}:std{access=file,mux=raw,dst=\"%2\"}").arg(outFile);
        } else if (format == "WAV") {
            sout = QString(":sout=#transcode{vcodec=none,acodec=s16l,channels=2,samplerate=44100}:std{access=file,mux=wav,dst=\"%2\"}").arg(outFile);
        } else if (format == "OGG") {
            sout = QString(":sout=#transcode{vcodec=none,acodec=vorb,ab=%1,channels=2,samplerate=44100}:std{access=file,mux=ogg,dst=\"%2\"}").arg(bitrate).arg(outFile);
        }

        libvlc_media_add_option(media, sout.toUtf8().constData());
        libvlc_media_add_option(media, ":sout-keep");

        libvlc_media_player_t *mp = libvlc_media_player_new_from_media(media);
        libvlc_media_release(media);

        libvlc_media_player_play(mp);

        QThread::msleep(500);

        // Block this loop until the hardware laser finishes extracting the track
        while (true) {
            libvlc_state_t state = libvlc_media_player_get_state(mp);
            if (state == libvlc_Ended || state == libvlc_Error || state == libvlc_Stopped) {
                break;
            }
            QThread::msleep(100);
        }

        libvlc_media_player_release(mp);
    }

    libvlc_release(vlc);
    emit ripFinished();
}
