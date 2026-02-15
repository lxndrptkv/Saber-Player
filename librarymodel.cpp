#include "librarymodel.h"
#include <QStandardPaths>
#include <QDirIterator>
#include <QFileInfo>
#include <QDir>
#include <QtConcurrent>
#include <algorithm>

LibraryModel::LibraryModel(QObject *parent) : QAbstractListModel(parent) {
    connect(&m_watcher, &QFutureWatcher<QList<Track>>::finished, this, &LibraryModel::onScanFinished);
}

int LibraryModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_tracks.count();
}

QVariant LibraryModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_tracks.count()) return QVariant();
    const Track &track = m_tracks[index.row()];
    switch (role) {
    case NameRole: return track.name;
    case ArtistRole: return track.artist;
    case AlbumRole: return track.album;
    case FolderRole: return track.folder;
    case SizeRole: return track.size;
    case UrlRole: return track.url;
    case TrackNumRole: return track.trackNumber; // Expose track number to QML
    default: return QVariant();
    }
}

QHash<int, QByteArray> LibraryModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[NameRole] = "trackName";
    roles[ArtistRole] = "trackArtist";
    roles[AlbumRole] = "trackAlbum";
    roles[FolderRole] = "trackFolder";
    roles[SizeRole] = "trackSize";
    roles[UrlRole] = "trackUrl";
    roles[TrackNumRole] = "trackNumber"; // Map to QML property
    return roles;
}

void LibraryModel::scanLibrary() {
    if (m_isScanning) return;
    m_isScanning = true;
    emit isScanningChanged();
    m_watcher.setFuture(QtConcurrent::run(&LibraryModel::runScan));
}

void LibraryModel::onScanFinished() {
    m_allTracks = m_watcher.result();
    m_tracks = m_allTracks;
    m_isScanning = false;
    emit isScanningChanged();
    applySortAndFilter();
}

QList<Track> LibraryModel::runScan() {
    QList<Track> foundTracks;
    QStringList musicPaths = QStandardPaths::standardLocations(QStandardPaths::MusicLocation);
    QStringList filters = {"*.mp3", "*.flac", "*.wav", "*.ogg", "*.m4a", "*.wma", "*.ape"};

    for (const QString &path : musicPaths) {
        QDirIterator it(path, filters, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            QString filePath = it.next();
            QFileInfo fileInfo(filePath);

            QString folderName = fileInfo.dir().dirName();
            qint64 sizeBytes = fileInfo.size();
            QString sizeFormatted = QString::number(sizeBytes / (1024.0 * 1024.0), 'f', 1) + " MB";

            foundTracks.append({
                fileInfo.baseName(),
                "Unknown Artist",
                folderName,
                folderName,
                sizeFormatted,
                QUrl::fromLocalFile(filePath),
                0 // Initialize trackNumber
            });
        }
    }
    return foundTracks;
}

void LibraryModel::setSortColumn(const QString &column) {
    if (m_sortColumn != column) {
        m_sortColumn = column;
        emit sortColumnChanged();
        applySortAndFilter();
    }
}

void LibraryModel::setGroupByFolder(bool group) {
    if (m_groupByFolder != group) {
        m_groupByFolder = group;
        emit groupByFolderChanged();
        applySortAndFilter();
    }
}

void LibraryModel::sortBy(const QString &column) {
    setSortColumn(column);
}

void LibraryModel::filter(const QString &query) {
    m_tracks.clear();
    if (query.isEmpty()) {
        m_tracks = m_allTracks;
    } else {
        for (const auto& track : m_allTracks) {
            if (track.name.contains(query, Qt::CaseInsensitive) ||
                track.artist.contains(query, Qt::CaseInsensitive) ||
                track.album.contains(query, Qt::CaseInsensitive)) {
                m_tracks.append(track);
            }
        }
    }
    applySortAndFilter();
}

void LibraryModel::applySortAndFilter() {
    beginResetModel();
    std::sort(m_tracks.begin(), m_tracks.end(), [this](const Track &a, const Track &b) {
        if (m_groupByFolder) {
            int folderCmp = a.folder.compare(b.folder, Qt::CaseInsensitive);
            if (folderCmp != 0) return folderCmp < 0;
        }
        if (m_sortColumn == "artist") return a.artist.compare(b.artist, Qt::CaseInsensitive) < 0;
        if (m_sortColumn == "album") return a.album.compare(b.album, Qt::CaseInsensitive) < 0;
        if (m_sortColumn == "folder") return a.folder.compare(b.folder, Qt::CaseInsensitive) < 0;
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    // Calculates the # index so it restarts at 1 for every Album/Folder!
    QString currentSection = "";
    int currentTrackNum = 1;
    for (auto &track : m_tracks) {
        if (track.album != currentSection) {
            currentSection = track.album;
            currentTrackNum = 1;
        }
        track.trackNumber = currentTrackNum++;
    }

    endResetModel();
}
