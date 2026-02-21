#ifndef LIBRARYMODEL_H
#define LIBRARYMODEL_H

#include <QAbstractListModel>
#include <QVariantList>
#include <QVariantMap>
#include <QUrl>
#include <QStringList>
#include <QtQml/qqml.h>
#include "coverfetcher.h"

class LibraryModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(bool isFetchingArt READ isFetchingArt NOTIFY isFetchingArtChanged)

public:
    enum TrackRoles {
        TrackNameRole = Qt::UserRole + 1,
        TrackAlbumRole,
        TrackArtistRole,
        TrackNumberRole,
        TrackSizeRole,
        TrackUrlRole,
        TrackDurationRole,
        TrackArtRole
    };

    explicit LibraryModel(QObject *parent = nullptr);
    ~LibraryModel();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isScanning() const;
    bool isFetchingArt() const;

    Q_INVOKABLE void addDirectory(const QUrl &dirUrl);
    Q_INVOKABLE void scanLibrary();
    Q_INVOKABLE void filter(const QString &query);
    Q_INVOKABLE void sortBy(const QString &field);
    Q_INVOKABLE QVariantList getTrackUrls() const;

    // UI Helpers for the Queue System
    Q_INVOKABLE QVariantMap getTrack(int index) const;
    Q_INVOKABLE QVariantList getAlbumTracks(const QString &album) const;

    Q_INVOKABLE void refetchMissingArt();
    Q_INVOKABLE void resetLibraryMetadata();

signals:
    void isScanningChanged();
    void isFetchingArtChanged();

private:
    struct Track {
        QString name;
        QString album;
        QString artist;
        int number;
        QString size;
        QString url;
        QString duration;
        QString artUrl;
    };

    QList<Track> m_allTracks;
    QList<Track> m_displayTracks;
    bool m_isScanning;
    bool m_isFetchingArt;
    QString m_currentFilter;
    QStringList m_libraryPaths;

    CoverFetcher m_coverFetcher;

    QString formatDuration(qint64 ms) const;
};

#endif
