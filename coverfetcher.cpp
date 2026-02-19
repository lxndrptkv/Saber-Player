#include "coverfetcher.h"
#include <QStandardPaths>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QFile>
#include <QRegularExpression>

CoverFetcher::CoverFetcher(QObject *parent) : QObject(parent) {
    m_manager = new QNetworkAccessManager(this);

    m_cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/SaberCovers";
    QDir().mkpath(m_cacheDir);

    m_queueTimer = new QTimer(this);
    m_queueTimer->setInterval(350);
    connect(m_queueTimer, &QTimer::timeout, this, &CoverFetcher::processNextInQueue);
}

QString CoverFetcher::sanitizeFilename(const QString &name) {
    QString safe = name;
    safe.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    return safe;
}

void CoverFetcher::queueCoverFetch(const QString &artist, const QString &album, const QString &title) {
    QString cleanArtist = artist.toLower().contains("unknown") ? "" : artist;
    QString cleanAlbum = album.toLower().contains("unknown") ? "" : album;
    QString cleanTitle = title;

    // CD DETECTION FIX: Ignore raw CD titles so we force a search by Artist/Album instead
    if (cleanTitle.contains("Audio CD")) cleanTitle = "";

    // EXTREME REGEX CLEANUP: Strip out garbage that confuses APIs
    auto cleanUp = [](QString str) {
        str.replace(QRegularExpression("\\(.*?\\)"), "");
        str.replace(QRegularExpression("\\[.*?\\]"), "");
        str.replace(QRegularExpression("(?i)\\b(ft\\.|feat\\.|live|remastered|acoustic|bonus|explicit|version|deluxe|edition)\\b.*"), "");
        str.replace(QRegularExpression("^\\d+\\s*[-.]*\\s*"), ""); // Removes leading track numbers like "01 - "
        return str.trimmed();
    };

    cleanArtist = cleanUp(cleanArtist);
    cleanAlbum = cleanUp(cleanAlbum);
    cleanTitle = cleanUp(cleanTitle);

    if (cleanArtist.isEmpty() && cleanAlbum.isEmpty() && cleanTitle.isEmpty()) return;

    QString searchTerm = cleanArtist + " " + cleanAlbum;
    if (cleanAlbum.isEmpty()) searchTerm = cleanArtist + " " + cleanTitle;
    if (searchTerm.trimmed().isEmpty()) searchTerm = cleanTitle;

    QString filename = sanitizeFilename(artist + "_" + album + "_" + title) + ".jpg";
    QString cachePath = m_cacheDir + "/" + filename;

    if (QFile::exists(cachePath)) {
        emit coverFound(artist, album, QUrl::fromLocalFile(cachePath).toString());
        return;
    }

    m_requestQueue.enqueue({artist, album, title, searchTerm});

    if (!m_queueTimer->isActive()) {
        m_queueTimer->start();
        emit activeChanged(true);
    }
}

void CoverFetcher::processNextInQueue() {
    if (m_requestQueue.isEmpty()) {
        m_queueTimer->stop();
        emit activeChanged(false);
        return;
    }

    CoverRequest req = m_requestQueue.dequeue();

    QUrl url("https://itunes.apple.com/search");
    QUrlQuery query;
    query.addQueryItem("term", req.searchTerm);
    query.addQueryItem("entity", "song"); // 'song' provides access to trackName and collectionName for cross-referencing!
    query.addQueryItem("limit", "15");    // Pull 15 results to evaluate
    url.setQuery(query);

    QNetworkRequest request(url);
    QNetworkReply *reply = m_manager->get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, req]() {
        onSearchReply(reply, req.artist, req.album, req.title);
    });
}

// THE CROSS-REFERENCE SCORING ALGORITHM
void CoverFetcher::onSearchReply(QNetworkReply *reply, const QString &artist, const QString &album, const QString &title) {
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) return;

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject root = doc.object();
    QJsonArray results = root["results"].toArray();

    if (results.isEmpty()) return;

    QString bestImgUrl = "";
    int bestScore = -1;

    QString cTitle = title.toLower().trimmed();
    QString cAlbum = album.toLower().trimmed();
    QString cArtist = artist.toLower().trimmed();

    // Iterate through all 15 results and find the MOST accurate one mathematically
    for (int i = 0; i < results.size(); ++i) {
        QJsonObject res = results[i].toObject();
        QString resTrack = res["trackName"].toString().toLower();
        QString resAlbum = res["collectionName"].toString().toLower();
        QString resArtist = res["artistName"].toString().toLower();
        QString url = res["artworkUrl100"].toString();

        int score = 0;

        if (!cArtist.isEmpty() && (resArtist.contains(cArtist) || cArtist.contains(resArtist))) score += 10;
        if (!cAlbum.isEmpty() && (resAlbum.contains(cAlbum) || cAlbum.contains(resAlbum))) score += 20;
        if (!cTitle.isEmpty() && !cTitle.contains("audio cd") && (resTrack.contains(cTitle) || cTitle.contains(resTrack))) score += 30;

        // Failsafe for loose matches
        if (score == 0 && i == 0) score = 1;

        if (score > bestScore && !url.isEmpty()) {
            bestScore = score;
            bestImgUrl = url;
        }
    }

    if (bestImgUrl.isEmpty()) return;

    // Grab the HD 600x600 version
    bestImgUrl.replace("100x100bb", "600x600bb");

    QString filename = sanitizeFilename(artist + "_" + album + "_" + title) + ".jpg";
    QString cachePath = m_cacheDir + "/" + filename;

    QNetworkRequest request((QUrl(bestImgUrl)));
    QNetworkReply *imgReply = m_manager->get(request);

    connect(imgReply, &QNetworkReply::finished, this, [this, imgReply, artist, album, cachePath]() {
        onImageReply(imgReply, artist, album, cachePath);
    });
}

void CoverFetcher::onImageReply(QNetworkReply *reply, const QString &artist, const QString &album, const QString &cachePath) {
    reply->deleteLater();
    if (reply->error() == QNetworkReply::NoError) {
        QFile file(cachePath);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(reply->readAll());
            file.close();
            emit coverFound(artist, album, QUrl::fromLocalFile(cachePath).toString());
        }
    }
}
