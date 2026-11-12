#pragma once

#include <QFutureWatcher>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <qqmlintegration.h>

namespace olvex {

struct WallpaperResult {
    bool success = false;
    QString wallpaperPath;
    QString thumbnailPath;
    QString schemeJson;
    QString mode;
    QString variant;
    QString error;
    bool isPreview = false;
};

class WallpaperEngine : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool isBusy READ isBusy NOTIFY isBusyChanged)
    Q_PROPERTY(QString currentWallpaper READ currentWallpaper NOTIFY currentWallpaperChanged)

public:
    explicit WallpaperEngine(QObject* parent = nullptr);
    ~WallpaperEngine() override = default;

    bool isBusy() const { return m_isBusy; }
    QString currentWallpaper() const { return m_currentWallpaper; }

    Q_INVOKABLE void setWallpaper(const QString& path, const QString& variant = QStringLiteral("tonalspot"),
                                 bool noSmart = false, const QString& forceMode = QString());
    Q_INVOKABLE void previewWallpaper(const QString& path, const QString& variant = QStringLiteral("tonalspot"),
                                     bool noSmart = false, const QString& forceMode = QString());
    Q_INVOKABLE QString generatePaletteSync(const QString& path, const QString& variant = QStringLiteral("tonalspot"),
                                           bool noSmart = false, const QString& forceMode = QString());
    Q_INVOKABLE QString getThumbnailPath(const QString& path);
    Q_INVOKABLE QString currentWallpaperSync() const;

signals:
    void isBusyChanged();
    void currentWallpaperChanged(const QString& path);
    void paletteReady(const QString& jsonPayload, bool isPreview);
    void wallpaperApplied(const QString& path);
    void errorOccurred(const QString& message);

private slots:
    void onProcessingFinished();

private:
    void startProcessing(const QString& path, const QString& variant, bool noSmart, const QString& forceMode, bool isPreview);
    static WallpaperResult processWallpaper(const QString& path, const QString& variant, bool noSmart, const QString& forceMode, bool isPreview);
    static QJsonObject generateScheme(const QString& imagePath, const QString& variant, bool noSmart, const QString& forceMode, QString& outMode, QString& outVariant);
    static void applyHyprlandScheme(const QJsonObject& colours);
    static void applyTerminalSequences(const QJsonObject& colours);
    static void updateSymlinksAndFiles(const QString& wallPath, const QString& thumbPath, const QString& schemeJson);
    static QString computeHash(const QString& path);
    static QString sanitizePath(const QString& path);

    bool m_isBusy = false;
    QString m_currentWallpaper;
    QString m_pendingPath;
    QString m_pendingVariant;
    bool m_pendingNoSmart = false;
    QString m_pendingForceMode;
    bool m_pendingIsPreview = false;
    bool m_hasPending = false;

    QFutureWatcher<WallpaperResult> m_watcher;
};

} // namespace olvex

