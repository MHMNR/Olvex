#include "imageanalyser.hpp"

#include <QtConcurrent/qtconcurrentrun.h>
#include <QtQuick/qquickitemgrabresult.h>
#include <qfuturewatcher.h>
#include <qimage.h>
#include <QImageReader>
#include <qloggingcategory.h>
#include <qquickwindow.h>
#include <QUrl>

Q_LOGGING_CATEGORY(lcImageAnalyser, "olvex.imageanalyser", QtInfoMsg)

namespace olvex {

namespace {

bool isAlbumArtProfile(const QString& profile) {
    return profile.compare(QLatin1String("albumArt"), Qt::CaseInsensitive) == 0;
}

double scoreWallpaperPixel(int h, int s, int l, double colourCount) {
    double score = std::log(colourCount + 1.0);

    const double satNorm = s / 255.0;
    const double lNorm = l / 255.0;

    const double lDist = std::abs(lNorm - 0.55);
    const double lScore = std::max(0.0, 1.0 - (lDist * 1.5));
    score *= (1.0 + (satNorm * satNorm * lScore * 100.0));

    if (h != -1 && (h < 170 || h > 260)) {
        score *= 5.0;
    }

    if (h >= 190 && h <= 250) {
        score *= 0.05;
    }

    if (l < 40) {
        score *= 0.0001;
    }
    if (l > 220 && s < 150) {
        score *= 0.0001;
    }
    if (s < 50) {
        score *= 0.0001;
    }

    return score;
}

double scoreAlbumArtPixel(int h, int s, int l, double colourCount) {
    Q_UNUSED(h);

    if (l < 20 || l > 240 || s < 20) {
        return std::sqrt(colourCount) * 0.05;
    }

    double score = std::sqrt(colourCount);

    const double satNorm = s / 255.0;
    const double lNorm = l / 255.0;

    score *= (1.0 + satNorm * 3.0);

    const double lDist = std::abs(lNorm - 0.50);
    const double lScore = std::max(0.0, 1.0 - lDist * 2.0);
    score *= (1.0 + lScore * 1.5);

    return score;
}

bool isValidSeed(const QColor& seed) {
    return seed.isValid() && seed.alphaF() > 0.0f && seed.lightnessF() > 0.02f;
}

double relativeLuminance(const QColor& c) {
    if (!isValidSeed(c)) {
        return 0.0;
    }
    auto channel = [](double v) {
        return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4);
    };
    return channel(static_cast<double>(c.redF())) * 0.2126 +
           channel(static_cast<double>(c.greenF())) * 0.7152 +
           channel(static_cast<double>(c.blueF())) * 0.0722;
}

} // namespace

QColor ImageAnalyser::vibrantAccent(const QColor& seed) const {
    if (!isValidSeed(seed)) {
        return QColor();
    }
    const float hue = seed.hslHueF();
    float sat = std::min(0.96f, std::max(0.58f, seed.hslSaturationF() * 1.45f + 0.22f));
    float lit = std::min(0.80f, std::max(0.44f, seed.lightnessF() * 1.25f + 0.20f));

    if (seed.hslSaturationF() < 0.14f) {
        sat = 0.64f;
        lit = 0.54f;
    }

    return QColor::fromHslF(hue < 0.0f ? 0.0f : hue, sat, lit, 1.0f);
}

QColor ImageAnalyser::surfaceColor(const QColor& seed, bool isLight) const {
    if (!isValidSeed(seed)) {
        return QColor();
    }
    const float hue = seed.hslHueF();
    const float sat = std::min(0.20f, seed.hslSaturationF() * 0.4f);
    const float lit = isLight ? 0.94f : 0.12f;

    return QColor::fromHslF(hue < 0.0f ? 0.0f : hue, sat, lit, 1.0f);
}

QColor ImageAnalyser::onSurfaceColor(bool isLight) const {
    return isLight ? QColor::fromRgbF(0.0f, 0.0f, 0.0f, 0.90f) : QColor::fromRgbF(1.0f, 1.0f, 1.0f, 0.90f);
}

QColor ImageAnalyser::playButtonFill(const QColor& primary, bool isLight) const {
    if (!isValidSeed(primary)) {
        return QColor();
    }
    const float sat = std::min(1.0f, primary.hslSaturationF() * 1.22f + 0.08f);
    const float lit = isLight ? std::min(0.35f, primary.lightnessF()) : std::max(0.82f, primary.lightnessF());
    const float hue = primary.hslHueF();
    return QColor::fromHslF(hue < 0.0f ? 0.0f : hue, sat, lit, primary.alphaF());
}

QColor ImageAnalyser::playIconOnFill(bool isLight, const QColor& fill) const {
    if (isValidSeed(fill)) {
        return relativeLuminance(fill) > 0.48 ? QColor::fromRgbF(0.0f, 0.0f, 0.0f, 0.92f) : QColor::fromRgbF(1.0f, 1.0f, 1.0f, 0.94f);
    }
    return isLight ? QColor::fromRgbF(1.0f, 1.0f, 1.0f, 0.92f) : QColor::fromRgbF(0.0f, 0.0f, 0.0f, 0.92f);
}

ImageAnalyser::ImageAnalyser(QObject* parent)
    : QObject(parent)
    , m_futureWatcher(new QFutureWatcher<AnalyseResult>(this))
    , m_netManager(nullptr)
    , m_netReply(nullptr)
    , m_source("")
    , m_sourceItem(nullptr)
    , m_rescaleSize(128)
    , m_profile(QStringLiteral("wallpaper"))
    , m_dominantColour(0, 0, 0)
    , m_luminance(0) {
    QObject::connect(m_futureWatcher, &QFutureWatcher<AnalyseResult>::finished, this, [this]() {
        emit runningChanged();
        if (!m_futureWatcher->future().isResultReadyAt(0)) {
            return;
        }

        const auto result = m_futureWatcher->result();
        if (m_dominantColour != result.first) {
            m_dominantColour = result.first;
            emit dominantColourChanged();
        }
        if (!qFuzzyCompare(m_luminance + 1.0, result.second + 1.0)) {
            m_luminance = result.second;
            emit luminanceChanged();
        }
        emit finished(result.first, result.second);
    });
}

ImageAnalyser::~ImageAnalyser() {
    auto* reply = m_netReply.data();
    if (reply) {
        reply->abort();
        reply->deleteLater();
        m_netReply = nullptr;
    }
    if (m_futureWatcher->isRunning()) {
        m_futureWatcher->cancel();
    }
}

QString ImageAnalyser::source() const {
    return m_source;
}

void ImageAnalyser::setSource(const QString& source) {
    if (m_source == source) {
        return;
    }

    m_source = source;
    emit sourceChanged();

    if (m_sourceItem) {
        m_sourceItem = nullptr;
        emit sourceItemChanged();
    }

    // If clearing source, cancel any in-flight analysis immediately
    if (m_source.isEmpty() && !m_sourceItem) {
        cancel();
        return;
    }

    requestUpdate();
}

QQuickItem* ImageAnalyser::sourceItem() const {
    return m_sourceItem;
}

void ImageAnalyser::setSourceItem(QQuickItem* sourceItem) {
    if (m_sourceItem == sourceItem) {
        return;
    }

    m_sourceItem = sourceItem;
    emit sourceItemChanged();

    if (!m_source.isEmpty()) {
        m_source = "";
        emit sourceChanged();
    }

    // If clearing sourceItem with no fallback source, cancel in-flight analysis
    if (!m_sourceItem && m_source.isEmpty()) {
        cancel();
        return;
    }

    requestUpdate();
}

int ImageAnalyser::rescaleSize() const {
    return m_rescaleSize;
}

void ImageAnalyser::setRescaleSize(int rescaleSize) {
    if (m_rescaleSize == rescaleSize) {
        return;
    }

    m_rescaleSize = rescaleSize;
    emit rescaleSizeChanged();

    requestUpdate();
}

QString ImageAnalyser::profile() const {
    return m_profile;
}

void ImageAnalyser::setProfile(const QString& profile) {
    const QString next = profile.isEmpty() ? QStringLiteral("wallpaper") : profile;
    if (m_profile == next) {
        return;
    }

    m_profile = next;
    emit profileChanged();

    requestUpdate();
}

QColor ImageAnalyser::dominantColour() const {
    return m_dominantColour;
}

[[nodiscard]] qreal ImageAnalyser::luminance() const {
    return m_luminance;
}

bool ImageAnalyser::isRunning() const {
    return (m_netReply && m_netReply->isRunning()) || m_futureWatcher->isRunning();
}

void ImageAnalyser::cancel() {
    auto* reply = m_netReply.data();
    if (reply) {
        reply->abort();
        reply->deleteLater();
        m_netReply = nullptr;
    }
    if (m_futureWatcher->isRunning()) {
        m_futureWatcher->cancel();
        emit runningChanged();
    }
}

void ImageAnalyser::requestUpdate() {
    if (m_source.isEmpty() && !m_sourceItem) {
        cancel();
        return;
    }

    if (!m_sourceItem || (m_sourceItem->window() && m_sourceItem->window()->isVisible() && m_sourceItem->width() > 0 &&
                             m_sourceItem->height() > 0)) {
        update();
    } else if (m_sourceItem) {
        if (!m_sourceItem->window()) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        } else if (!m_sourceItem->window()->isVisible()) {
            QObject::connect(m_sourceItem->window(), &QQuickWindow::visibleChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        }
        if (m_sourceItem->width() <= 0) {
            QObject::connect(
                m_sourceItem, &QQuickItem::widthChanged, this, &ImageAnalyser::requestUpdate, Qt::SingleShotConnection);
        }
        if (m_sourceItem->height() <= 0) {
            QObject::connect(m_sourceItem, &QQuickItem::heightChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
        }
    }
}

void ImageAnalyser::update() {
    if (m_source.isEmpty() && !m_sourceItem) {
        return;
    }

    if (m_futureWatcher->isRunning()) {
        m_futureWatcher->cancel();
    }
    auto* prevReply = m_netReply.data();
    if (prevReply) {
        prevReply->abort();
        prevReply->deleteLater();
        m_netReply = nullptr;
    }

    const QString profile = m_profile;
    const int rescaleSize = m_rescaleSize;

    if (m_sourceItem) {
        const QSharedPointer<const QQuickItemGrabResult> grabResult = m_sourceItem->grabToImage();
        if (!grabResult) {
            QObject::connect(m_sourceItem, &QQuickItem::windowChanged, this, &ImageAnalyser::requestUpdate,
                Qt::SingleShotConnection);
            return;
        }
        QObject::connect(grabResult.data(), &QQuickItemGrabResult::ready, this, [grabResult, profile, rescaleSize, this]() {
            m_futureWatcher->setFuture(
                QtConcurrent::run(&ImageAnalyser::analyse, grabResult->image(), rescaleSize, profile));
        });
    } else {
        QString raw = m_source;
        if (raw.contains(QLatin1Char('#'))) {
            raw = raw.section(QLatin1Char('#'), 0, 0);
        }

        if (raw.startsWith(QLatin1String("http://"), Qt::CaseInsensitive) ||
            raw.startsWith(QLatin1String("https://"), Qt::CaseInsensitive)) {
            if (!m_netManager) {
                m_netManager = new QNetworkAccessManager(this);
            }
            QNetworkRequest req{QUrl(raw)};
            req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
            req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (X11; Linux x86_64)"));

            QNetworkReply* reply = m_netManager->get(req);
            m_netReply = reply;
            emit runningChanged();

            QObject::connect(reply, &QNetworkReply::finished, this, [reply, profile, rescaleSize, this]() {
                if (m_netReply != reply) {
                    reply->deleteLater();
                    return;
                }
                m_netReply = nullptr;

                QByteArray data;
                if (reply->error() == QNetworkReply::NoError) {
                    data = reply->readAll();
                }
                reply->deleteLater();

                if (!data.isEmpty()) {
                    m_futureWatcher->setFuture(QtConcurrent::run([data, rescaleSize, profile](QPromise<AnalyseResult>& promise) {
                        QImage image;
                        image.loadFromData(data);
                        analyse(promise, image, rescaleSize, profile);
                    }));
                } else {
                    emit runningChanged();
                }
            });
        } else if (raw.startsWith(QLatin1String("data:image/"), Qt::CaseInsensitive)) {
            const qsizetype comma = raw.indexOf(QLatin1Char(','));
            const QByteArray b64 = (comma >= 0 ? raw.sliced(comma + 1) : raw).toLatin1();
            const QByteArray data = QByteArray::fromBase64(b64);
            m_futureWatcher->setFuture(QtConcurrent::run([data, rescaleSize, profile](QPromise<AnalyseResult>& promise) {
                QImage image;
                image.loadFromData(data);
                analyse(promise, image, rescaleSize, profile);
            }));
        } else {
            QString path = raw;
            if (path.startsWith(QLatin1String("file://"), Qt::CaseInsensitive)) {
                path = QUrl(path).toLocalFile();
            }
            m_futureWatcher->setFuture(QtConcurrent::run([path, rescaleSize, profile](QPromise<AnalyseResult>& promise) {
                const QImage image(path);
                analyse(promise, image, rescaleSize, profile);
            }));
        }
    }
}

void ImageAnalyser::analyse(QPromise<AnalyseResult>& promise, const QImage& image, int rescaleSize, const QString& profile) {
    if (image.isNull()) {
        qCWarning(lcImageAnalyser) << "analyse: image is null";
        return;
    }

    QImage img = image;

    if (rescaleSize > 0 && (img.width() > rescaleSize || img.height() > rescaleSize)) {
        img = img.scaled(rescaleSize, rescaleSize, Qt::KeepAspectRatio, Qt::FastTransformation);
    }

    if (promise.isCanceled()) {
        return;
    }

    if (img.format() != QImage::Format_ARGB32) {
        img = img.convertToFormat(QImage::Format_ARGB32);
    }

    if (promise.isCanceled()) {
        return;
    }

    const uchar* data = img.bits();
    const int width = img.width();
    const int height = img.height();
    const qsizetype bytesPerLine = img.bytesPerLine();

    std::unordered_map<quint32, int> colours;
    qreal totalLuminance = 0.0;
    int count = 0;

    for (int y = 0; y < height; ++y) {
        const uchar* line = data + y * bytesPerLine;
        for (int x = 0; x < width; ++x) {
            if (promise.isCanceled()) {
                return;
            }

            const uchar* pixel = line + x * 4;

            if (pixel[3] == 0) {
                continue;
            }

            const quint32 mr = static_cast<quint32>(pixel[2] & 0xF8);
            const quint32 mg = static_cast<quint32>(pixel[1] & 0xF8);
            const quint32 mb = static_cast<quint32>(pixel[0] & 0xF8);
            ++colours[(mr << 16) | (mg << 8) | mb];

            const qreal r = pixel[2] / 255.0;
            const qreal g = pixel[1] / 255.0;
            const qreal b = pixel[0] / 255.0;
            totalLuminance += std::sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b);
            ++count;
        }
    }

    const bool albumArt = isAlbumArtProfile(profile);

    quint32 dominantColour = 0;
    double maxScore = -1.0;
    quint32 fallbackColour = 0;
    double fallbackScore = -1.0;

    for (const auto& [colour, colourCount] : colours) {
        if (promise.isCanceled()) {
            return;
        }

        QColor qcol((0xFFu << 24) | colour);
        int h = 0;
        int s = 0;
        int l = 0;
        qcol.getHsl(&h, &s, &l);

        const double score = albumArt ? scoreAlbumArtPixel(h, s, l, static_cast<double>(colourCount))
                                      : scoreWallpaperPixel(h, s, l, static_cast<double>(colourCount));

        if (albumArt && s >= 70 && l >= 35 && l <= 210) {
            const double satBoost = (s / 255.0) * (1.0 - std::abs((l / 255.0) - 0.50));
            if (satBoost > fallbackScore) {
                fallbackColour = colour;
                fallbackScore = satBoost;
            }
        }

        if (score > maxScore) {
            dominantColour = colour;
            maxScore = score;
        }
    }

    if (dominantColour == 0 && fallbackColour != 0) {
        dominantColour = fallbackColour;
    }

    if (dominantColour == 0 && !colours.empty()) {
        int bestCount = 0;
        for (const auto& [colour, colourCount] : colours) {
            if (colourCount > bestCount) {
                dominantColour = colour;
                bestCount = colourCount;
            }
        }
    }

    promise.addResult(qMakePair(QColor((0xFFu << 24) | dominantColour), count == 0 ? 0.0 : totalLuminance / count));
}

struct RegionResult {
    int x = 0;
    int y = 0;
    int centerX = 0;
    int centerY = 0;
    QColor color;
    qreal luminance = 0.0;
    bool isDark = true;
};

void ImageAnalyser::findRegion(const QString& imagePath, int screenWidth, int screenHeight,
                               int regionWidth, int regionHeight,
                               int leftPadding, int topPadding,
                               int rightPadding, int bottomPadding,
                               bool busiest) {
    QString path = imagePath;
    if (path.startsWith(QLatin1String("file://"), Qt::CaseInsensitive)) {
        path = QUrl(path).toLocalFile();
    }

    if (path.isEmpty() || !QFile::exists(path)) {
        return;
    }

    const int targetScreenWidth = screenWidth > 0 ? screenWidth : 1920;
    const int targetScreenHeight = screenHeight > 0 ? screenHeight : 1080;
    const int targetRegionWidth = regionWidth > 0 ? regionWidth : 320;
    const int targetRegionHeight = regionHeight > 0 ? regionHeight : 180;
    const int padL = leftPadding >= 0 ? leftPadding : 80;
    const int padT = topPadding >= 0 ? topPadding : 80;
    const int padR = rightPadding >= 0 ? rightPadding : 80;
    const int padB = bottomPadding >= 0 ? bottomPadding : 80;

    auto* watcher = new QFutureWatcher<RegionResult>(this);
    connect(watcher, &QFutureWatcher<RegionResult>::finished, this, [this, watcher]() {
        const RegionResult res = watcher->result();
        emit regionFound(res.x, res.y, res.centerX, res.centerY, res.color, res.luminance, res.isDark);
        watcher->deleteLater();
    });

    QFuture<RegionResult> future = QtConcurrent::run([path, targetScreenWidth, targetScreenHeight,
                                                      targetRegionWidth, targetRegionHeight,
                                                      padL, padT, padR, padB, busiest]() -> RegionResult {
        RegionResult result;
        QImageReader reader(path);
        if (!reader.canRead()) {
            return result;
        }

        const QSize origSize = reader.size();
        if (origSize.isEmpty()) {
            return result;
        }

        // Analysis downscale factor for speed (factor 6: 1080p -> 320x180, ultra-fast & cache-friendly)
        constexpr int factor = 6;
        const int aw = std::max(10, targetScreenWidth / factor);
        const int ah = std::max(10, targetScreenHeight / factor);

        const double scale = std::max(static_cast<double>(aw) / origSize.width(),
                                      static_cast<double>(ah) / origSize.height());
        const int nw = std::max(aw, static_cast<int>(origSize.width() * scale));
        const int nh = std::max(ah, static_cast<int>(origSize.height() * scale));

        reader.setScaledSize(QSize(nw, nh));
        QImage img = reader.read();
        if (img.isNull()) {
            return result;
        }

        // Center crop to aspect ratio
        const int cropX = (nw - aw) / 2;
        const int cropY = (nh - ah) / 2;
        img = img.copy(cropX, cropY, aw, ah);
        if (img.format() != QImage::Format_ARGB32) {
            img = img.convertToFormat(QImage::Format_ARGB32);
        }

        const int sh = img.height();
        const int sw = img.width();
        const int rw = std::max(2, targetRegionWidth / factor);
        const int rh = std::max(2, targetRegionHeight / factor);
        const int pLeft = std::clamp(padL / factor, 0, std::max(0, (sw - rw) / 2));
        const int pTop = std::clamp(padT / factor, 0, std::max(0, (sh - rh) / 2));
        const int pRight = std::clamp(padR / factor, 0, std::max(0, (sw - rw) / 2));
        const int pBottom = std::clamp(padB / factor, 0, std::max(0, (sh - rh) / 2));

        // 1. Grayscale map + Sobel Gradient Magnitude (High frequency edge detail)
        std::vector<double> gray(static_cast<size_t>(sw * sh), 0.0);
        std::vector<double> edge(static_cast<size_t>(sw * sh), 0.0);

        const qsizetype bytesPerLine = img.bytesPerLine();
        const uchar* bits = img.bits();

        for (int y = 0; y < sh; ++y) {
            const uchar* line = bits + y * bytesPerLine;
            for (int x = 0; x < sw; ++x) {
                const uchar* pixel = line + x * 4;
                // Standard perceptual luminance: 0.299*R + 0.587*G + 0.114*B
                const double lum = 0.299 * pixel[2] + 0.587 * pixel[1] + 0.114 * pixel[0];
                gray[static_cast<size_t>(y * sw + x)] = lum;
            }
        }

        // Fast Sobel Edge Magnitude
        for (int y = 1; y < sh - 1; ++y) {
            const size_t rowPrev = static_cast<size_t>((y - 1) * sw);
            const size_t rowCurr = static_cast<size_t>(y * sw);
            const size_t rowNext = static_cast<size_t>((y + 1) * sw);

            for (int x = 1; x < sw - 1; ++x) {
                const size_t ux = static_cast<size_t>(x);
                // Sobel kernels
                const double gx = (gray[rowPrev + ux + 1] + 2.0 * gray[rowCurr + ux + 1] + gray[rowNext + ux + 1]) -
                                  (gray[rowPrev + ux - 1] + 2.0 * gray[rowCurr + ux - 1] + gray[rowNext + ux - 1]);
                const double gy = (gray[rowNext + ux - 1] + 2.0 * gray[rowNext + ux] + gray[rowNext + ux + 1]) -
                                  (gray[rowPrev + ux - 1] + 2.0 * gray[rowPrev + ux] + gray[rowPrev + ux + 1]);

                edge[rowCurr + ux] = std::sqrt(gx * gx + gy * gy) / 4.0;
            }
        }

        // 2. 2D Integral Images: gray_ii, gray_sq_ii, and edge_ii
        const size_t iiW = static_cast<size_t>(sw + 1);
        const size_t iiH = static_cast<size_t>(sh + 1);
        std::vector<double> ii_gray(iiW * iiH, 0.0);
        std::vector<double> ii_gray_sq(iiW * iiH, 0.0);
        std::vector<double> ii_edge(iiW * iiH, 0.0);

        for (int y = 0; y < sh; ++y) {
            double rowGray = 0.0;
            double rowGraySq = 0.0;
            double rowEdge = 0.0;
            const size_t prevRowIdx = static_cast<size_t>(y) * iiW;
            const size_t currRowIdx = static_cast<size_t>(y + 1) * iiW;
            const size_t rowOffset = static_cast<size_t>(y * sw);

            for (int x = 0; x < sw; ++x) {
                const size_t ux = static_cast<size_t>(x);
                const double gVal = gray[rowOffset + ux];
                const double eVal = edge[rowOffset + ux];

                rowGray += gVal;
                rowGraySq += (gVal * gVal);
                rowEdge += eVal;

                const size_t colIdx = static_cast<size_t>(x + 1);
                ii_gray[currRowIdx + colIdx] = ii_gray[prevRowIdx + colIdx] + rowGray;
                ii_gray_sq[currRowIdx + colIdx] = ii_gray_sq[prevRowIdx + colIdx] + rowGraySq;
                ii_edge[currRowIdx + colIdx] = ii_edge[prevRowIdx + colIdx] + rowEdge;
            }
        }

        const int x1 = pLeft;
        const int x2 = std::max(x1 + 1, sw - pRight - rw);
        const int y1 = pTop;
        const int y2 = std::max(y1 + 1, sh - pBottom - rh);

        const double totalArea = static_cast<double>(rw * rh);
        double targetScore = busiest ? -1.0 : std::numeric_limits<double>::infinity();
        int bestXSmall = x1;
        int bestYSmall = y1;

        for (int y = y1; y <= y2; ++y) {
            for (int x = x1; x <= x2; ++x) {
                const size_t ux = static_cast<size_t>(x);
                const size_t uy = static_cast<size_t>(y);
                const size_t rx = static_cast<size_t>(x + rw);
                const size_t by = static_cast<size_t>(y + rh);

                // Window sums from integral images
                const double sumGray = ii_gray[by * iiW + rx] - ii_gray[uy * iiW + rx] - ii_gray[by * iiW + ux] + ii_gray[uy * iiW + ux];
                const double sumGraySq = ii_gray_sq[by * iiW + rx] - ii_gray_sq[uy * iiW + rx] - ii_gray_sq[by * iiW + ux] + ii_gray_sq[uy * iiW + ux];
                const double sumEdge = ii_edge[by * iiW + rx] - ii_edge[uy * iiW + rx] - ii_edge[by * iiW + ux] + ii_edge[uy * iiW + ux];

                const double meanGray = sumGray / totalArea;
                const double varGray = std::max(0.0, (sumGraySq / totalArea) - (meanGray * meanGray));
                const double stdDev = std::sqrt(varGray);
                const double edgeDensity = sumEdge / totalArea;

                // Human visual busyness score:
                // High frequency edges (objects, text, faces) + standard deviation
                const double busyScore = stdDev + 2.5 * edgeDensity;

                if (busiest) {
                    if (busyScore > targetScore) {
                        targetScore = busyScore;
                        bestXSmall = x;
                        bestYSmall = y;
                    }
                } else {
                    if (busyScore < targetScore) {
                        targetScore = busyScore;
                        bestXSmall = x;
                        bestYSmall = y;
                    }
                }
            }
        }

        result.x = bestXSmall * factor;
        result.y = bestYSmall * factor;
        result.centerX = result.x + (targetRegionWidth / 2);
        result.centerY = result.y + (targetRegionHeight / 2);

        // Sample dominant color & luminance directly from the selected region in the cropped image
        const int sampleBoxX = std::clamp(bestXSmall, 0, sw - 1);
        const int sampleBoxY = std::clamp(bestYSmall, 0, sh - 1);
        const int sampleBoxW = std::clamp(rw, 1, sw - sampleBoxX);
        const int sampleBoxH = std::clamp(rh, 1, sh - sampleBoxY);

        double lumSum = 0.0;
        int pixelCount = 0;
        for (int sy = sampleBoxY; sy < sampleBoxY + sampleBoxH; ++sy) {
            for (int sx = sampleBoxX; sx < sampleBoxX + sampleBoxW; ++sx) {
                lumSum += gray[static_cast<size_t>(sy * sw + sx)];
                pixelCount++;
            }
        }

        const double avgGray = pixelCount > 0 ? (lumSum / pixelCount) : 128.0;
        result.luminance = avgGray / 255.0;
        result.isDark = (result.luminance < 0.5);
        const float fLum = static_cast<float>(result.luminance);
        result.color = QColor::fromRgbF(fLum, fLum, fLum);

        return result;
    });

    watcher->setFuture(future);
}

} // namespace olvex