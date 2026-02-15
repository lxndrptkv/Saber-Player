#ifndef LIBRARYMODEL_H
#define LIBRARYMODEL_H

#include <QAbstractListModel>
#include <QList>
#include <QUrl>
#include <QFutureWatcher>
#include <QVariantList>
#include <QtQml/qqml.h>

struct Track {
    QString name;
    QString artist;
    QString album;
    QString folder;
    QString size;
    QUrl url;
    int trackNumber = 0;
};

class LibraryModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(QString sortColumn READ sortColumn WRITE setSortColumn NOTIFY sortColumnChanged)
    Q_PROPERTY(bool groupByFolder READ groupByFolder WRITE setGroupByFolder NOTIFY groupByFolderChanged)

public:
    enum TrackRoles {
        NameRole = Qt::UserRole + 1,
        ArtistRole,
        AlbumRole,
        FolderRole,
        SizeRole,
        UrlRole,
        TrackNumRole
    };

    explicit LibraryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isScanning() const { return m_isScanning; }
    QString sortColumn() const { return m_sortColumn; }
    bool groupByFolder() const { return m_groupByFolder; }

    Q_INVOKABLE void sortBy(const QString &column);
    Q_INVOKABLE void scanLibrary();
    Q_INVOKABLE void filter(const QString &query);

    Q_INVOKABLE QVariantList getTrackUrls() const;

public slots:
    void setSortColumn(const QString &column);
    void setGroupByFolder(bool group);

signals:
    void isScanningChanged();
    void sortColumnChanged();
    void groupByFolderChanged();

private slots:
    void onScanFinished();

private:
    QList<Track> m_allTracks;
    QList<Track> m_tracks;
    bool m_isScanning = false;
    QString m_sortColumn = "album";
    bool m_groupByFolder = false;
    QFutureWatcher<QList<Track>> m_watcher;

    static QList<Track> runScan();
    void applySortAndFilter();
};

#endif
