#include "librarymodel.h"
#include <QStandardPaths>
#include <QDirIterator>
#include <QFileInfo>
#include <QThreadPool>
#include <QThread>
#include <QSettings>
#include <QDir>
#include <utility>
#include <vlc/vlc.h>

LibraryModel::LibraryModel(QObject *parent) : QAbstractListModel(parent), m_isScanning(false), m_isFetchingArt(false) {
    QSettings settings("SaberTeam", "SaberPlayer");
    m_libraryPaths = settings.value("library/paths").toStringList();

    connect(&m_coverFetcher, &CoverFetcher::coverFound, this, [this](const QString &artist, const QString &album, const QString &path) {
        for (int i = 0; i < m_displayTracks.size(); ++i) {
            if (m_displayTracks[i].artist == artist && m_displayTracks[i].album == album) {
                m_displayTracks[i].artUrl = path;
                QModelIndex idx = createIndex(i, 0);
                emit dataChanged(idx, idx, {TrackArtRole});
            }
        }
    });

    connect(&m_coverFetcher, &CoverFetcher::activeChanged, this, [this](bool active) {
        if (m_isFetchingArt != active) {
            m_isFetchingArt = active;
            emit isFetchingArtChanged();
        }
    });
}

LibraryModel::~LibraryModel() {}

int LibraryModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_displayTracks.size();
}

QVariant LibraryModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_displayTracks.size()) return QVariant();
    const Track &t = m_displayTracks[index.row()];

    switch (role) {
    case TrackNameRole: return t.name;
    case TrackAlbumRole: return t.album;
    case TrackArtistRole: return t.artist;
    case TrackNumberRole: return t.number;
    case TrackSizeRole: return t.size;
    case TrackUrlRole: return t.url;
    case TrackDurationRole: return t.duration;
    case TrackArtRole: return t.artUrl;
    default: return QVariant();
    }
}

QHash<int, QByteArray> LibraryModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TrackNameRole] = "trackName";
    roles[TrackAlbumRole] = "trackAlbum";
    roles[TrackArtistRole] = "trackArtist";
    roles[TrackNumberRole] = "trackNumber";
    roles[TrackSizeRole] = "trackSize";
    roles[TrackUrlRole] = "trackUrl";
    roles[TrackDurationRole] = "trackDuration";
    roles[TrackArtRole] = "trackArt";
    return roles;
}

bool LibraryModel::isScanning() const { return m_isScanning; }
bool LibraryModel::isFetchingArt() const { return m_isFetchingArt; }

QVariantList LibraryModel::getTrackUrls() const {
    QVariantList urls;
    for (const Track &t : std::as_const(m_displayTracks)) urls.append(t.url);
    return urls;
}

// ==========================================
// QML MAP EXTRACTORS FOR THE QUEUE SYSTEM
// ==========================================
QVariantMap LibraryModel::getTrack(int index) const {
    QVariantMap map;
    if (index >= 0 && index < m_displayTracks.size()) {
        const Track &t = m_displayTracks[index];
        map["url"] = t.url;
        map["title"] = t.name;
        map["artist"] = t.artist;
        map["album"] = t.album;
        map["artUrl"] = t.artUrl;
    }
    return map;
}

QVariantList LibraryModel::getAlbumTracks(const QString &album) const {
    QVariantList list;
    if (album.isEmpty() || album == "Unknown Album") return list;
    for (const Track &t : std::as_const(m_allTracks)) {
        if (t.album == album) {
            QVariantMap map;
            map["title"] = t.name;
            map["artist"] = t.artist;
            map["album"] = t.album;
            map["url"] = t.url;
            map["artUrl"] = t.artUrl;
            list.append(map);
        }
    }
    return list;
}

void LibraryModel::filter(const QString &query) {
    m_currentFilter = query.toLower();
    beginResetModel();
    m_displayTracks.clear();
    for (const Track &t : std::as_const(m_allTracks)) {
        if (m_currentFilter.isEmpty() || t.name.toLower().contains(m_currentFilter) ||
            t.artist.toLower().contains(m_currentFilter) || t.album.toLower().contains(m_currentFilter)) {
            m_displayTracks.append(t);
        }
    }
    endResetModel();
}

void LibraryModel::sortBy(const QString &field) {
    beginResetModel();
    if (field == "album") {
        std::sort(m_displayTracks.begin(), m_displayTracks.end(), [](const Track &a, const Track &b) {
            if (a.album == b.album) return a.number < b.number;
            return a.album < b.album;
        });
    }
    endResetModel();
}

QString LibraryModel::formatDuration(qint64 ms) const {
    if (ms <= 0) return "00:00";
    qint64 totalSeconds = ms / 1000;
    qint64 minutes = totalSeconds / 60;
    qint64 seconds = totalSeconds % 60;
    return QString("%1:%2").arg(minutes).arg(seconds, 2, 10, QChar('0'));
}

void LibraryModel::addDirectory(const QUrl &dirUrl) {
    QString path = dirUrl.toLocalFile();
    if (!m_libraryPaths.contains(path)) {
        m_libraryPaths.append(path);
        QSettings settings("SaberTeam", "SaberPlayer");
        settings.setValue("library/paths", m_libraryPaths);
        scanLibrary();
    }
}

void LibraryModel::refetchMissingArt() {
    for (const Track &t : std::as_const(m_displayTracks)) {
        if (t.artUrl.isEmpty() || t.artUrl.startsWith("attachment://")) {
            m_coverFetcher.queueCoverFetch(t.artist, t.album, t.name);
        }
    }
}

void LibraryModel::resetLibraryMetadata() {
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/SaberCovers";
    QDir dir(cacheDir);
    if (dir.exists()) {
        QStringList files = dir.entryList(QDir::Files);
        for(const QString &file : files) {
            dir.remove(file);
        }
    }

    beginResetModel();
    m_allTracks.clear();
    m_displayTracks.clear();
    endResetModel();

    scanLibrary();
}

void LibraryModel::scanLibrary() {
    if (m_isScanning) return;
    if (m_libraryPaths.isEmpty()) return;

    m_isScanning = true;
    emit isScanningChanged();

    QStringList pathsToScan = m_libraryPaths;

    QThreadPool::globalInstance()->start([this, pathsToScan]() {
        QList<Track> initialTracks;

        for (const QString &loc : std::as_const(pathsToScan)) {
            QDirIterator it(loc, {"*.mp3", "*.flac", "*.wav", "*.ogg", "*.m4a"}, QDir::Files, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                QString filePath = it.next();
                QFileInfo fileInfo(filePath);

                Track t;
                t.url = QUrl::fromLocalFile(filePath).toString();
                double mb = fileInfo.size() / (1024.0 * 1024.0);
                t.size = QString::number(mb, 'f', 1) + " MB";
                t.name = fileInfo.completeBaseName();
                t.album = "Loading...";
                t.artist = "Loading...";
                t.number = 0;
                t.duration = "00:00";
                t.artUrl = "";

                initialTracks.append(t);
            }
        }

        QMetaObject::invokeMethod(this, [this, initialTracks]() {
            beginResetModel();
            m_allTracks = initialTracks;
            m_displayTracks = m_allTracks;
            endResetModel();
        });

        const char * const vlc_args[] = {
            "--intf=dummy",
            "--ignore-config",
            "--quiet",
            "--no-video",
            "--no-audio",
            "--no-sub-autodetect-file"
        };
        libvlc_instance_t *vlc = libvlc_new(sizeof(vlc_args) / sizeof(vlc_args[0]), vlc_args);

        for (int i = 0; i < initialTracks.size(); ++i) {
            QString filePath = QUrl(initialTracks[i].url).toLocalFile();
            QString nativePath = QDir::toNativeSeparators(filePath);

            if (vlc) {
                libvlc_media_t *media = libvlc_media_new_path(vlc, nativePath.toUtf8().constData());
                if (media) {
                    libvlc_media_parse_flag_t parseFlags = (libvlc_media_parse_flag_t)(libvlc_media_parse_local | libvlc_media_fetch_local);
                    libvlc_media_parse_with_options(media, parseFlags, -1);

                    int timeout = 0;
                    while (timeout < 50) {
                        libvlc_media_parsed_status_t status = libvlc_media_get_parsed_status(media);
                        if (status == libvlc_media_parsed_status_done || status == libvlc_media_parsed_status_failed) break;
                        QThread::msleep(10);
                        timeout++;
                    }

                    char* title = libvlc_media_get_meta(media, libvlc_meta_Title);
                    char* artist = libvlc_media_get_meta(media, libvlc_meta_Artist);
                    char* album = libvlc_media_get_meta(media, libvlc_meta_Album);
                    char* trackNum = libvlc_media_get_meta(media, libvlc_meta_TrackNumber);
                    char* art = libvlc_media_get_meta(media, libvlc_meta_ArtworkURL);

                    QString newName = title ? QString::fromUtf8(title) : initialTracks[i].name;
                    QString newArtist = artist ? QString::fromUtf8(artist) : "Unknown Artist";
                    QString newAlbum = album ? QString::fromUtf8(album) : "Unknown Album";
                    QString newArt = art ? QString::fromUtf8(art) : "";
                    int newNum = trackNum ? QString::fromUtf8(trackNum).toInt() : 0;

                    libvlc_time_t dur = libvlc_media_get_duration(media);
                    QString newDur = dur > 0 ? formatDuration(dur) : "00:00";

                    if (title) libvlc_free(title);
                    if (artist) libvlc_free(artist);
                    if (album) libvlc_free(album);
                    if (trackNum) libvlc_free(trackNum);
                    if (art) libvlc_free(art);

                    libvlc_media_release(media);

                    bool hasAttachment = newArt.startsWith("attachment://");
                    if (newArt.isEmpty() || hasAttachment) {
                        QFileInfo fi(filePath);
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

                        if (!foundArt.isEmpty()) newArt = foundArt;
                        else if (hasAttachment) newArt = "";
                    }

                    QMetaObject::invokeMethod(this, [this, i, newName, newArtist, newAlbum, newArt, newNum, newDur]() {
                        if (i < m_allTracks.size()) {
                            m_allTracks[i].name = newName;
                            m_allTracks[i].artist = newArtist;
                            m_allTracks[i].album = newAlbum;
                            m_allTracks[i].artUrl = newArt;
                            m_allTracks[i].number = newNum;
                            m_allTracks[i].duration = newDur;

                            if (m_currentFilter.isEmpty()) {
                                m_displayTracks[i] = m_allTracks[i];
                                QModelIndex idx = createIndex(i, 0);
                                emit dataChanged(idx, idx);
                            }

                            if (newArt.isEmpty()) {
                                m_coverFetcher.queueCoverFetch(newArtist, newAlbum, newName);
                            }
                        }
                    });
                }
            }
        }

        if (vlc) libvlc_release(vlc);

        QMetaObject::invokeMethod(this, [this]() {
            if (m_currentFilter.isEmpty()) {
                beginResetModel();
                std::sort(m_displayTracks.begin(), m_displayTracks.end(), [](const Track &a, const Track &b) {
                    if (a.album == b.album) return a.number < b.number;
                    return a.album < b.album;
                });
                endResetModel();
            }
            m_isScanning = false;
            emit isScanningChanged();
        });
    });
}
