#ifndef COVERFETCHER_H
#define COVERFETCHER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>
#include <QQueue>
#include <QTimer>

class CoverFetcher : public QObject {
    Q_OBJECT
public:
    explicit CoverFetcher(QObject *parent = nullptr);

    void queueCoverFetch(const QString &artist, const QString &album, const QString &title);

signals:
    void coverFound(const QString &artist, const QString &album, const QString &localFilePath);
    void activeChanged(bool isActive);

private slots:
    void processNextInQueue();
    void onSearchReply(QNetworkReply *reply, const QString &artist, const QString &album, const QString &title);
    void onImageReply(QNetworkReply *reply, const QString &artist, const QString &album, const QString &cachePath);

private:
    struct CoverRequest {
        QString artist;
        QString album;
        QString title;
        QString searchTerm;
    };

    QNetworkAccessManager *m_manager;
    QQueue<CoverRequest> m_requestQueue;
    QTimer *m_queueTimer;
    QString m_cacheDir;

    QString sanitizeFilename(const QString &name);
};

#endif
