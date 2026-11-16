#include "wallpaperengine.hpp"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QThreadPool>
#include <QtConcurrent/QtConcurrent>
#include <fcntl.h>
#include <unistd.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wsign-conversion"
#include "cpp/cam/hct.h"
#include "cpp/scheme/scheme_tonal_spot.h"
#include "cpp/scheme/scheme_vibrant.h"
#include "cpp/scheme/scheme_expressive.h"
#include "cpp/scheme/scheme_fruit_salad.h"
#include "cpp/scheme/scheme_content.h"
#include "cpp/scheme/scheme_rainbow.h"
#include "cpp/scheme/scheme_neutral.h"
#include "cpp/scheme/scheme_monochrome.h"
#include "cpp/scheme/scheme_fidelity.h"
#include "cpp/quantize/celebi.h"
#include "cpp/score/score.h"
#include "cpp/dislike/dislike.h"
#include "cpp/dynamiccolor/material_dynamic_colors.h"
#include "cpp/blend/blend.h"
#include "cpp/utils/utils.h"
#pragma GCC diagnostic pop

Q_LOGGING_CATEGORY(lcWallpaperEngine, "olvex.wallpaperengine", QtInfoMsg)

using namespace material_color_utilities;

namespace olvex {

namespace {

QString toHex(Argb argb) {
    return QStringLiteral("%1").arg(argb & 0x00FFFFFF, 6, 16, QLatin1Char('0')).toLower();
}

Hct hexToHct(const QString& hex) {
    bool ok = false;
    uint32_t val = hex.toUInt(&ok, 16);
    return Hct(0xFF000000 | val);
}

Hct harmonizeHct(const Hct& fromHct, const Hct& toHct, double toneBoost) {
    double diffDeg = DiffDegrees(fromHct.get_hue(), toHct.get_hue());
    double rotDeg = std::min(diffDeg * 0.8, 100.0);
    double outHue = SanitizeDegreesDouble(fromHct.get_hue() + rotDeg * RotationDirection(fromHct.get_hue(), toHct.get_hue()));
    return Hct(outHue, fromHct.get_chroma(), fromHct.get_tone() * (1.0 + toneBoost));
}

Hct mixHct(const Hct& a, const Hct& b, double w) {
    return Hct(BlendCam16Ucs(a.ToInt(), b.ToInt(), w));
}

[[maybe_unused]] Hct lightenHct(const Hct& c, double amount) {
    double diff = (100.0 - c.get_tone()) * amount;
    return Hct(c.get_hue(), c.get_chroma() + diff / 5.0, c.get_tone() + diff);
}

Hct darkenHct(const Hct& c, double amount) {
    double diff = c.get_tone() * amount;
    return Hct(c.get_hue(), c.get_chroma() - diff / 5.0, c.get_tone() - diff);
}

struct SeedCacheEntry {
    qint64 size = -1;
    qint64 mtimeMs = -1;
    Argb seed = 0xFF6750A4;
    double avgTone = 0.0;
};

QMutex& seedCacheMutex() {
    static QMutex mutex;
    return mutex;
}

QHash<QString, SeedCacheEntry>& seedCacheMap() {
    static QHash<QString, SeedCacheEntry> map;
    return map;
}

bool tryExtractSeed(const QString& imagePath, Argb& outSeed, double& outAvgTone, bool populateIfMissing) {
    QFileInfo imgFi(imagePath);
    if (!imgFi.exists() || !imgFi.isFile()) {
        return false;
    }

    const qint64 fSize = imgFi.size();
    const qint64 fMtime = imgFi.lastModified().toMSecsSinceEpoch();

    {
        QMutexLocker lock(&seedCacheMutex());
        const auto it = seedCacheMap().constFind(imagePath);
        if (it != seedCacheMap().constEnd() && it->size == fSize && it->mtimeMs == fMtime) {
            outSeed = it->seed;
            outAvgTone = it->avgTone;
            return true;
        }
    }

    if (!populateIfMissing) {
        return false;
    }

    QImageReader reader(imagePath);
    reader.setAutoTransform(true);
    reader.setScaledSize(QSize(128, 128));
    QImage thumb = reader.read().convertToFormat(QImage::Format_ARGB32);
    if (thumb.isNull()) {
        return false;
    }

    std::vector<Argb> pixels;
    pixels.reserve(static_cast<size_t>(thumb.width()) * static_cast<size_t>(thumb.height()));
    double totalTone = 0.0;

    for (int y = 0; y < thumb.height(); ++y) {
        const auto* line = reinterpret_cast<const uint32_t*>(thumb.constScanLine(y));
        for (int x = 0; x < thumb.width(); ++x) {
            uint32_t p = line[x];
            pixels.push_back(p);
            double r = (p >> 16) & 0xFF;
            double g = (p >> 8) & 0xFF;
            double b = p & 0xFF;
            totalTone += (0.299 * r + 0.587 * g + 0.114 * b) * (100.0 / 255.0);
        }
    }

    if (pixels.empty()) {
        return false;
    }

    outAvgTone = totalTone / static_cast<double>(pixels.size());
    auto quantizeResult = QuantizeCelebi(pixels, 128);
    auto ranked = RankedSuggestions(quantizeResult.color_to_count);
    outSeed = ranked.empty() ? 0xFF6750A4 : ranked[0];

    {
        QMutexLocker lock(&seedCacheMutex());
        auto& map = seedCacheMap();
        if (map.size() >= 64) {
            map.clear();
        }
        SeedCacheEntry entry;
        entry.size = fSize;
        entry.mtimeMs = fMtime;
        entry.seed = outSeed;
        entry.avgTone = outAvgTone;
        map.insert(imagePath, entry);
    }

    return true;
}

bool writeTextAtomic(const QString& path, const QString& content) {
    const QByteArray bytes = content.toUtf8();
    QFile existing(path);
    if (existing.exists() && existing.size() == bytes.size() && existing.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (existing.readAll() == bytes) {
            return true;
        }
    }

    QFileInfo fi(path);
    QDir().mkpath(fi.absolutePath());
    QString tmpPath = path + QStringLiteral(".tmp.%1").arg(QDateTime::currentMSecsSinceEpoch());
    QFile file(tmpPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }
    file.write(bytes);
    file.close();
    QFile::remove(path);
    return file.rename(path);
}

bool updateSymlink(const QString& linkPath, const QString& target) {
    QFileInfo fi(linkPath);
    QDir().mkpath(fi.absolutePath());
    QFileInfo currentLink(linkPath);
    if (currentLink.isSymLink() && currentLink.symLinkTarget() == target) {
        return true;
    }
    QFile::remove(linkPath);
    return QFile::link(target, linkPath);
}

} // namespace

WallpaperEngine::WallpaperEngine(QObject* parent)
    : QObject(parent) {
    connect(&m_watcher, &QFutureWatcher<WallpaperResult>::finished,
            this, &WallpaperEngine::onProcessingFinished);

    m_persistTimer.setSingleShot(true);
    m_persistTimer.setInterval(350);
    connect(&m_persistTimer, &QTimer::timeout,
            this, &WallpaperEngine::flushDeferredPersist);

    m_currentWallpaper = currentWallpaperSync();
}

QString WallpaperEngine::computeHash(const QString& path) {
    return QString::fromUtf8(QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Sha256).toHex());
}

QString WallpaperEngine::sanitizePath(const QString& path) {
    QString clean = path.trimmed();
    if (clean.startsWith(QLatin1String("file://")))
        clean = clean.mid(7);
    if (clean.startsWith(QLatin1String("~/")))
        clean = QDir::homePath() + clean.mid(1);
    return clean;
}

QString WallpaperEngine::currentWallpaperSync() const {
    QString statePath = QDir::homePath() + QStringLiteral("/.local/state/olvex/wallpaper/path.txt");
    QFile file(statePath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString::fromUtf8(file.readAll()).trimmed();
    }
    return QString();
}

QString WallpaperEngine::getThumbnailPath(const QString& path) {
    const QString clean = sanitizePath(path);
    if (clean.isEmpty()) return QString();
    const QString hash = computeHash(clean);
    return QDir::homePath() + QStringLiteral("/.cache/olvex/wallpapers/%1/thumbnail.jpg").arg(hash);
}

void WallpaperEngine::setWallpaper(const QString& path, const QString& variant, bool noSmart, const QString& forceMode) {
    startProcessing(path, variant, noSmart, forceMode, false);
}

void WallpaperEngine::previewWallpaper(const QString& path, const QString& variant, bool noSmart, const QString& forceMode) {
    startProcessing(path, variant, noSmart, forceMode, true);
}

QString WallpaperEngine::generatePaletteSync(const QString& path, const QString& variant, bool noSmart, const QString& forceMode) {
    QString mode, var;
    QJsonObject obj = generateScheme(path, variant, noSmart, forceMode, mode, var);
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QString WallpaperEngine::switchModeFast(const QString& path, const QString& variant, bool noSmart, const QString& forceMode) {
    const QString clean = sanitizePath(path);
    if (clean.isEmpty()) {
        return QString();
    }

    const QString hash = computeHash(clean);
    const QString thumbPath = QDir::homePath() + QStringLiteral("/.cache/olvex/wallpapers/%1/thumbnail.jpg").arg(hash);
    const QString schemeImgPath = QFile::exists(thumbPath) ? thumbPath : clean;

    Argb cachedSeed = 0;
    double cachedTone = 0.0;
    if (!tryExtractSeed(schemeImgPath, cachedSeed, cachedTone, false)) {
        return QString();
    }

    QString mode;
    QString actualVariant;
    QJsonObject schemeObj = generateScheme(schemeImgPath, variant, noSmart, forceMode, mode, actualVariant);
    if (schemeObj.isEmpty()) {
        return QString();
    }

    QJsonObject root;
    root[QStringLiteral("name")] = QStringLiteral("dynamic");
    root[QStringLiteral("flavour")] = QStringLiteral("default");
    root[QStringLiteral("mode")] = mode;
    root[QStringLiteral("variant")] = actualVariant;
    root[QStringLiteral("colours")] = schemeObj;

    const QString compactJson = QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
    const QString indentedJson = QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Indented));

    m_deferredPersist.cleanPath = clean;
    m_deferredPersist.thumbPath = thumbPath;
    m_deferredPersist.indentedJson = indentedJson;
    m_deferredPersist.schemeObj = schemeObj;
    m_deferredPersist.active = true;
    m_persistTimer.start();

    if (m_currentWallpaper != clean) {
        m_currentWallpaper = clean;
        emit currentWallpaperChanged(m_currentWallpaper);
    }

    return compactJson;
}

void WallpaperEngine::warmSeedCache(const QString& path) {
    const QString clean = sanitizePath(path);
    if (clean.isEmpty()) {
        return;
    }
    QFileInfo fi(clean);
    if (!fi.exists() || !fi.isFile()) {
        return;
    }

    const QString hash = computeHash(clean);
    const QString thumbDir = QDir::homePath() + QStringLiteral("/.cache/olvex/wallpapers/%1").arg(hash);
    const QString thumbPath = thumbDir + QStringLiteral("/thumbnail.jpg");
    const QString schemeImgPath = QFile::exists(thumbPath) ? thumbPath : clean;

    Argb seed = 0;
    double avgTone = 0.0;
    if (tryExtractSeed(schemeImgPath, seed, avgTone, false)) {
        return;
    }

    QThreadPool::globalInstance()->start([clean, thumbDir, thumbPath]() {
        QFileInfo thumbFi(thumbPath);
        if (!thumbFi.exists() || thumbFi.size() == 0) {
            QDir().mkpath(thumbDir);
            QImageReader reader(clean);
            reader.setAutoTransform(true);
            reader.setScaledSize(QSize(128, 128));
            QImage thumb = reader.read();
            if (!thumb.isNull()) {
                thumb.save(thumbPath, "JPEG", 85);
            }
        }
        const QString imgPath = QFile::exists(thumbPath) ? thumbPath : clean;
        Argb bgSeed = 0;
        double bgTone = 0.0;
        tryExtractSeed(imgPath, bgSeed, bgTone, true);
    });
}

void WallpaperEngine::flushDeferredPersist() {
    if (!m_deferredPersist.active) {
        return;
    }
    const DeferredPersist p = m_deferredPersist;
    m_deferredPersist.active = false;

    QThreadPool::globalInstance()->start([p]() {
        updateSymlinksAndFiles(p.cleanPath, p.thumbPath, p.indentedJson);
        applyHyprlandScheme(p.schemeObj);
        applyTerminalSequences(p.schemeObj);
    });
}

void WallpaperEngine::startProcessing(const QString& path, const QString& variant, bool noSmart, const QString& forceMode, bool isPreview) {
    if (!isPreview) {
        m_persistTimer.stop();
        m_deferredPersist.active = false;
    }
    if (m_isBusy) {
        m_pendingPath = path;
        m_pendingVariant = variant;
        m_pendingNoSmart = noSmart;
        m_pendingForceMode = forceMode;
        m_pendingIsPreview = isPreview;
        m_hasPending = true;
        return;
    }

    m_isBusy = true;
    emit isBusyChanged();

    auto future = QtConcurrent::run(&WallpaperEngine::processWallpaper, path, variant, noSmart, forceMode, isPreview);
    m_watcher.setFuture(future);
}

void WallpaperEngine::onProcessingFinished() {
    WallpaperResult res = m_watcher.result();
    m_isBusy = false;
    emit isBusyChanged();

    if (res.success) {
        if (!res.isPreview) {
            m_currentWallpaper = res.wallpaperPath;
            emit currentWallpaperChanged(m_currentWallpaper);
            emit wallpaperApplied(m_currentWallpaper);
        }
        emit paletteReady(res.schemeJson, res.isPreview);
    } else {
        qCWarning(lcWallpaperEngine) << "processWallpaper error:" << res.error;
        emit errorOccurred(res.error);
    }

    if (m_hasPending) {
        m_hasPending = false;
        startProcessing(m_pendingPath, m_pendingVariant, m_pendingNoSmart, m_pendingForceMode, m_pendingIsPreview);
    }
}

WallpaperResult WallpaperEngine::processWallpaper(const QString& path, const QString& variant, bool noSmart, const QString& forceMode, bool isPreview) {
    WallpaperResult res;
    res.isPreview = isPreview;
    const QString clean = sanitizePath(path);
    if (clean.isEmpty()) {
        res.error = QStringLiteral("Empty wallpaper path");
        return res;
    }

    QFileInfo fi(clean);
    if (!fi.exists() || !fi.isFile()) {
        res.error = QStringLiteral("File not found: %1").arg(clean);
        return res;
    }

    const QString hash = computeHash(clean);
    const QString thumbDir = QDir::homePath() + QStringLiteral("/.cache/olvex/wallpapers/%1").arg(hash);
    const QString thumbPath = thumbDir + QStringLiteral("/thumbnail.jpg");

    // Generate downscaled thumbnail if needed
    QFileInfo thumbFi(thumbPath);
    if (!thumbFi.exists() || thumbFi.size() == 0) {
        QDir().mkpath(thumbDir);
        QImageReader reader(clean);
        reader.setAutoTransform(true);
        reader.setScaledSize(QSize(128, 128));
        QImage thumb = reader.read();
        if (!thumb.isNull()) {
            thumb.save(thumbPath, "JPEG", 85);
        }
    }

    QString mode, actualVariant;
    QJsonObject schemeObj = generateScheme(thumbPath.isEmpty() || !QFile::exists(thumbPath) ? clean : thumbPath,
                                          variant, noSmart, forceMode, mode, actualVariant);

    if (schemeObj.isEmpty()) {
        res.error = QStringLiteral("Failed to generate scheme for %1").arg(clean);
        return res;
    }

    QJsonObject root;
    root[QStringLiteral("name")] = QStringLiteral("dynamic");
    root[QStringLiteral("flavour")] = QStringLiteral("default");
    root[QStringLiteral("mode")] = mode;
    root[QStringLiteral("variant")] = actualVariant;
    root[QStringLiteral("colours")] = schemeObj;

    const QString schemeJson = QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));

    if (!isPreview) {
        updateSymlinksAndFiles(clean, thumbPath, QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Indented)));
        applyHyprlandScheme(schemeObj);
        applyTerminalSequences(schemeObj);
    }

    res.success = true;
    res.wallpaperPath = clean;
    res.thumbnailPath = thumbPath;
    res.schemeJson = schemeJson;
    res.mode = mode;
    res.variant = actualVariant;
    return res;
}

QJsonObject WallpaperEngine::generateScheme(const QString& imagePath, const QString& variant, bool noSmart, const QString& forceMode, QString& outMode, QString& outVariant) {
    Argb seed = 0xFF6750A4;
    double avgTone = 0.0;
    if (!tryExtractSeed(imagePath, seed, avgTone, true)) {
        return QJsonObject();
    }

    bool isDark = true;
    if (forceMode == QLatin1String("light")) {
        isDark = false;
    } else if (forceMode == QLatin1String("dark")) {
        isDark = true;
    } else if (!noSmart) {
        isDark = (avgTone <= 60.0);
    }
    outMode = isDark ? QStringLiteral("dark") : QStringLiteral("light");

    Hct seedHct(seed);
    seedHct = FixIfDisliked(seedHct);

    const QString varNorm = variant.toLower().trimmed();
    outVariant = varNorm.isEmpty() ? QStringLiteral("tonalspot") : varNorm;

    std::unique_ptr<DynamicScheme> s;
    if (outVariant == QLatin1String("vibrant"))
        s = std::make_unique<SchemeVibrant>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("expressive"))
        s = std::make_unique<SchemeExpressive>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("fruitsalad"))
        s = std::make_unique<SchemeFruitSalad>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("content"))
        s = std::make_unique<SchemeContent>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("rainbow"))
        s = std::make_unique<SchemeRainbow>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("neutral"))
        s = std::make_unique<SchemeNeutral>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("monochrome"))
        s = std::make_unique<SchemeMonochrome>(seedHct, isDark, 0.0);
    else if (outVariant == QLatin1String("fidelity"))
        s = std::make_unique<SchemeFidelity>(seedHct, isDark, 0.0);
    else
        s = std::make_unique<SchemeTonalSpot>(seedHct, isDark, 0.0);

    QJsonObject colours;

    colours[QStringLiteral("primary")] = toHex(MaterialDynamicColors::Primary().GetArgb(*s));
    colours[QStringLiteral("onPrimary")] = toHex(MaterialDynamicColors::OnPrimary().GetArgb(*s));
    colours[QStringLiteral("primaryContainer")] = toHex(MaterialDynamicColors::PrimaryContainer().GetArgb(*s));
    colours[QStringLiteral("onPrimaryContainer")] = toHex(MaterialDynamicColors::OnPrimaryContainer().GetArgb(*s));
    colours[QStringLiteral("inversePrimary")] = toHex(MaterialDynamicColors::InversePrimary().GetArgb(*s));
    colours[QStringLiteral("primaryFixed")] = toHex(MaterialDynamicColors::PrimaryFixed().GetArgb(*s));
    colours[QStringLiteral("primaryFixedDim")] = toHex(MaterialDynamicColors::PrimaryFixedDim().GetArgb(*s));
    colours[QStringLiteral("onPrimaryFixed")] = toHex(MaterialDynamicColors::OnPrimaryFixed().GetArgb(*s));
    colours[QStringLiteral("onPrimaryFixedVariant")] = toHex(MaterialDynamicColors::OnPrimaryFixedVariant().GetArgb(*s));

    colours[QStringLiteral("secondary")] = toHex(MaterialDynamicColors::Secondary().GetArgb(*s));
    colours[QStringLiteral("onSecondary")] = toHex(MaterialDynamicColors::OnSecondary().GetArgb(*s));
    colours[QStringLiteral("secondaryContainer")] = toHex(MaterialDynamicColors::SecondaryContainer().GetArgb(*s));
    colours[QStringLiteral("onSecondaryContainer")] = toHex(MaterialDynamicColors::OnSecondaryContainer().GetArgb(*s));
    colours[QStringLiteral("secondaryFixed")] = toHex(MaterialDynamicColors::SecondaryFixed().GetArgb(*s));
    colours[QStringLiteral("secondaryFixedDim")] = toHex(MaterialDynamicColors::SecondaryFixedDim().GetArgb(*s));
    colours[QStringLiteral("onSecondaryFixed")] = toHex(MaterialDynamicColors::OnSecondaryFixed().GetArgb(*s));
    colours[QStringLiteral("onSecondaryFixedVariant")] = toHex(MaterialDynamicColors::OnSecondaryFixedVariant().GetArgb(*s));

    colours[QStringLiteral("tertiary")] = toHex(MaterialDynamicColors::Tertiary().GetArgb(*s));
    colours[QStringLiteral("onTertiary")] = toHex(MaterialDynamicColors::OnTertiary().GetArgb(*s));
    colours[QStringLiteral("tertiaryContainer")] = toHex(MaterialDynamicColors::TertiaryContainer().GetArgb(*s));
    colours[QStringLiteral("onTertiaryContainer")] = toHex(MaterialDynamicColors::OnTertiaryContainer().GetArgb(*s));
    colours[QStringLiteral("tertiaryFixed")] = toHex(MaterialDynamicColors::TertiaryFixed().GetArgb(*s));
    colours[QStringLiteral("tertiaryFixedDim")] = toHex(MaterialDynamicColors::TertiaryFixedDim().GetArgb(*s));
    colours[QStringLiteral("onTertiaryFixed")] = toHex(MaterialDynamicColors::OnTertiaryFixed().GetArgb(*s));
    colours[QStringLiteral("onTertiaryFixedVariant")] = toHex(MaterialDynamicColors::OnTertiaryFixedVariant().GetArgb(*s));

    colours[QStringLiteral("error")] = toHex(MaterialDynamicColors::Error().GetArgb(*s));
    colours[QStringLiteral("onError")] = toHex(MaterialDynamicColors::OnError().GetArgb(*s));
    colours[QStringLiteral("errorContainer")] = toHex(MaterialDynamicColors::ErrorContainer().GetArgb(*s));
    colours[QStringLiteral("onErrorContainer")] = toHex(MaterialDynamicColors::OnErrorContainer().GetArgb(*s));

    colours[QStringLiteral("surface")] = toHex(MaterialDynamicColors::Surface().GetArgb(*s));
    colours[QStringLiteral("surfaceDim")] = toHex(MaterialDynamicColors::SurfaceDim().GetArgb(*s));
    colours[QStringLiteral("surfaceBright")] = toHex(MaterialDynamicColors::SurfaceBright().GetArgb(*s));
    colours[QStringLiteral("surfaceContainerLowest")] = toHex(MaterialDynamicColors::SurfaceContainerLowest().GetArgb(*s));
    colours[QStringLiteral("surfaceContainerLow")] = toHex(MaterialDynamicColors::SurfaceContainerLow().GetArgb(*s));
    colours[QStringLiteral("surfaceContainer")] = toHex(MaterialDynamicColors::SurfaceContainer().GetArgb(*s));
    colours[QStringLiteral("surfaceContainerHigh")] = toHex(MaterialDynamicColors::SurfaceContainerHigh().GetArgb(*s));
    colours[QStringLiteral("surfaceContainerHighest")] = toHex(MaterialDynamicColors::SurfaceContainerHighest().GetArgb(*s));
    colours[QStringLiteral("onSurface")] = toHex(MaterialDynamicColors::OnSurface().GetArgb(*s));
    colours[QStringLiteral("surfaceVariant")] = toHex(MaterialDynamicColors::SurfaceVariant().GetArgb(*s));
    colours[QStringLiteral("onSurfaceVariant")] = toHex(MaterialDynamicColors::OnSurfaceVariant().GetArgb(*s));
    colours[QStringLiteral("outline")] = toHex(MaterialDynamicColors::Outline().GetArgb(*s));
    colours[QStringLiteral("outlineVariant")] = toHex(MaterialDynamicColors::OutlineVariant().GetArgb(*s));
    colours[QStringLiteral("shadow")] = toHex(MaterialDynamicColors::Shadow().GetArgb(*s));
    colours[QStringLiteral("scrim")] = toHex(MaterialDynamicColors::Scrim().GetArgb(*s));
    colours[QStringLiteral("inverseSurface")] = toHex(MaterialDynamicColors::InverseSurface().GetArgb(*s));
    colours[QStringLiteral("inverseOnSurface")] = toHex(MaterialDynamicColors::InverseOnSurface().GetArgb(*s));
    colours[QStringLiteral("surfaceTint")] = toHex(MaterialDynamicColors::SurfaceTint().GetArgb(*s));

    const QString surfaceHex = colours.value(QStringLiteral("surface")).toString();
    const QString onSurfaceHex = colours.value(QStringLiteral("onSurface")).toString();
    colours[QStringLiteral("background")] = surfaceHex;
    colours[QStringLiteral("onBackground")] = onSurfaceHex;

    // Key palette colors
    QString pKey = toHex(MaterialDynamicColors::PrimaryPaletteKeyColor().GetArgb(*s));
    colours[QStringLiteral("primaryPaletteKeyColor")] = pKey;
    colours[QStringLiteral("primary_paletteKeyColor")] = pKey;

    QString sKey = toHex(MaterialDynamicColors::SecondaryPaletteKeyColor().GetArgb(*s));
    colours[QStringLiteral("secondaryPaletteKeyColor")] = sKey;
    colours[QStringLiteral("secondary_paletteKeyColor")] = sKey;

    QString tKey = toHex(MaterialDynamicColors::TertiaryPaletteKeyColor().GetArgb(*s));
    colours[QStringLiteral("tertiaryPaletteKeyColor")] = tKey;
    colours[QStringLiteral("tertiary_paletteKeyColor")] = tKey;

    QString nKey = toHex(MaterialDynamicColors::NeutralPaletteKeyColor().GetArgb(*s));
    colours[QStringLiteral("neutralPaletteKeyColor")] = nKey;
    colours[QStringLiteral("neutral_paletteKeyColor")] = nKey;

    QString nvKey = toHex(MaterialDynamicColors::NeutralVariantPaletteKeyColor().GetArgb(*s));
    colours[QStringLiteral("neutralVariantPaletteKeyColor")] = nvKey;
    colours[QStringLiteral("neutral_variant_paletteKeyColor")] = nvKey;

    colours[QStringLiteral("errorPaletteKeyColor")] = toHex(MaterialDynamicColors::Error().GetArgb(*s));

    // Gruvbox ANSI Harmonization
    static const char* const darkGruvbox[16] = {
        "282828", "CC241D", "98971A", "D79921", "458588", "B16286", "689D6A", "A89984",
        "928374", "FB4934", "B8BB26", "FABD2F", "83A598", "D3869B", "8EC07C", "EBDBB2"
    };
    static const char* const lightGruvbox[16] = {
        "FDF9F3", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034",
        "121212", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034"
    };

    Hct pKeyHct = hexToHct(pKey);
    for (int i = 0; i < 16; ++i) {
        Hct baseHct = hexToHct(QLatin1String(isDark ? darkGruvbox[i] : lightGruvbox[i]));
        double boost = (i < 8 ? 0.35 : 0.2) * (isDark ? 1.0 : -1.0);
        Hct harm = harmonizeHct(baseHct, pKeyHct, boost);
        colours[QStringLiteral("term%1").arg(i)] = toHex(harm.ToInt());
    }

    // Catppuccin Harmonization
    static const char* const darkCatppuccin[14] = {
        "f5e0dc", "f2cdcd", "f5c2e7", "cba6f7", "f38ba8", "eba0ac", "fab387", "f9e2af",
        "a6e3a1", "94e2d5", "89dceb", "74c7ec", "1e66f5", "7287fd"
    };
    static const char* const lightCatppuccin[14] = {
        "dc8a78", "dd7878", "ea76cb", "8839ef", "d20f39", "e64553", "fe640b", "df8e1d",
        "40a02b", "179299", "04a5e5", "209fb5", "1e66f5", "7287fd"
    };
    static const char* const catNames[14] = {
        "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow",
        "green", "teal", "sky", "sapphire", "blue", "lavender"
    };

    for (int i = 0; i < 14; ++i) {
        Hct baseHct = hexToHct(QLatin1String(isDark ? darkCatppuccin[i] : lightCatppuccin[i]));
        Hct harm = harmonizeHct(baseHct, pKeyHct, isDark ? 0.05 : -0.2);
        colours[QLatin1String(catNames[i])] = toHex(harm.ToInt());
    }

    // KDE Tokens
    Hct primaryHct = hexToHct(colours[QStringLiteral("primary")].toString());
    Hct onPrimaryVarHct = hexToHct(colours[QStringLiteral("onPrimaryFixedVariant")].toString());
    static const struct { const char* name; const char* hex; } kTokens[] = {
        {"klink", "2980b9"}, {"kvisited", "7f8c8d"}, {"knegative", "da4453"},
        {"kneutral", "f67400"}, {"kpositive", "27ae60"}
    };
    for (const auto& kt : kTokens) {
        Hct h = hexToHct(QLatin1String(kt.hex));
        colours[QLatin1String(kt.name)] = toHex(harmonizeHct(h, primaryHct, 0.1).ToInt());
        colours[QStringLiteral("%1Selection").arg(QLatin1String(kt.name))] = toHex(harmonizeHct(h, onPrimaryVarHct, 0.1).ToInt());
    }

    // Derived Catppuccin / Legacy tokens
    const QString onBgHex = colours.value(QStringLiteral("onBackground")).toString();
    const QString onSurfVarHex = colours.value(QStringLiteral("onSurfaceVariant")).toString();
    const QString outlineHex = colours.value(QStringLiteral("outline")).toString();
    colours[QStringLiteral("text")] = onBgHex;
    colours[QStringLiteral("subtext1")] = onSurfVarHex;
    colours[QStringLiteral("subtext0")] = outlineHex;

    Hct surfHct = hexToHct(colours.value(QStringLiteral("surface")).toString());
    Hct outHct = hexToHct(outlineHex);

    colours[QStringLiteral("overlay2")] = toHex(mixHct(surfHct, outHct, 0.86).ToInt());
    colours[QStringLiteral("overlay1")] = toHex(mixHct(surfHct, outHct, 0.71).ToInt());
    colours[QStringLiteral("overlay0")] = toHex(mixHct(surfHct, outHct, 0.57).ToInt());
    colours[QStringLiteral("surface2")] = toHex(mixHct(surfHct, outHct, 0.43).ToInt());
    colours[QStringLiteral("surface1")] = toHex(mixHct(surfHct, outHct, 0.29).ToInt());
    colours[QStringLiteral("surface0")] = toHex(mixHct(surfHct, outHct, 0.14).ToInt());
    const QString baseHex = colours.value(QStringLiteral("surface")).toString();
    colours[QStringLiteral("base")] = baseHex;
    colours[QStringLiteral("mantle")] = toHex(darkenHct(surfHct, 0.03).ToInt());
    colours[QStringLiteral("crust")] = toHex(darkenHct(surfHct, 0.05).ToInt());

    // Success Tokens
    if (!isDark) {
        colours[QStringLiteral("success")] = QStringLiteral("4f6354");
        colours[QStringLiteral("onSuccess")] = QStringLiteral("ffffff");
        colours[QStringLiteral("successContainer")] = QStringLiteral("d1e8d5");
        colours[QStringLiteral("onSuccessContainer")] = QStringLiteral("0c1f13");
    } else {
        colours[QStringLiteral("success")] = QStringLiteral("b5ccba");
        colours[QStringLiteral("onSuccess")] = QStringLiteral("213528");
        colours[QStringLiteral("successContainer")] = QStringLiteral("374b3e");
        colours[QStringLiteral("onSuccessContainer")] = QStringLiteral("d1e9d6");
    }

    return colours;
}

void WallpaperEngine::updateSymlinksAndFiles(const QString& wallPath, const QString& thumbPath, const QString& schemeJson) {
    const QString stateDir = QDir::homePath() + QStringLiteral("/.local/state/olvex");
    const bool isLiveThumb = wallPath.startsWith(stateDir + QStringLiteral("/wallpaper/live-thumbnails/"));
    if (!isLiveThumb) {
        writeTextAtomic(stateDir + QStringLiteral("/wallpaper/path.txt"), wallPath);
        updateSymlink(stateDir + QStringLiteral("/wallpaper/wallpaper"), wallPath);
    }
    if (!thumbPath.isEmpty() && QFile::exists(thumbPath)) {
        updateSymlink(stateDir + QStringLiteral("/wallpaper/thumbnail.jpg"), thumbPath);
    }
    writeTextAtomic(stateDir + QStringLiteral("/scheme.json"), schemeJson);
}

void WallpaperEngine::applyHyprlandScheme(const QJsonObject& colours) {
    QString lua = QStringLiteral("return {\n");
    for (auto it = colours.constBegin(); it != colours.constEnd(); ++it) {
        lua += QStringLiteral("  %1 = \"%2\",\n").arg(it.key(), it.value().toString());
    }
    lua += QStringLiteral("}\n");

    const QString userPath = QDir::homePath() + QStringLiteral("/.config/hypr/scheme/current.lua");
    writeTextAtomic(userPath, lua);
}

void WallpaperEngine::applyTerminalSequences(const QJsonObject& colours) {
    QString seq;
    for (int i = 0; i < 16; ++i) {
        QString hex = colours.value(QStringLiteral("term%1").arg(i)).toString();
        if (!hex.isEmpty()) {
            seq += QStringLiteral("\033]4;%1;#%2\033\\").arg(i).arg(hex);
        }
    }
    QString bg = colours.value(QStringLiteral("background")).toString();
    QString fg = colours.value(QStringLiteral("onBackground")).toString();
    if (!bg.isEmpty()) seq += QStringLiteral("\033]11;#%1\033\\").arg(bg);
    if (!fg.isEmpty()) seq += QStringLiteral("\033]10;#%1\033\\").arg(fg);

    QDir pts(QStringLiteral("/dev/pts"));
    const auto entries = pts.entryList(QDir::System | QDir::Files);
    QByteArray bytes = seq.toUtf8();

    for (const QString& entry : entries) {
        bool ok = false;
        entry.toInt(&ok);
        if (!ok) continue;

        QString dev = QStringLiteral("/dev/pts/") + entry;
        int fd = ::open(dev.toLocal8Bit().constData(), O_WRONLY | O_NONBLOCK | O_NOCTTY);
        if (fd >= 0) {
            ::write(fd, bytes.constData(), static_cast<size_t>(bytes.size()));
            ::close(fd);
        }
    }
}

} // namespace olvex
