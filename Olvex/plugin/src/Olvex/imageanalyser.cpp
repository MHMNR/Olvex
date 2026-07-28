#include "imageanalyser.hpp"

#include <QtConcurrent/qtconcurrentrun.h>
#include <QtQuick/qquickitemgrabresult.h>
#include <qfuturewatcher.h>
#include <qimage.h>
#include <qloggingcategory.h>
#include <qquickwindow.h>

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

    double score = std::log(colourCount + 1.0);

    const double satNorm = s / 255.0;
    const double lNorm = l / 255.0;

    // Saturation-first — album covers often have bold accent colours on dark backgrounds.
    score *= (1.0 + satNorm * satNorm * 90.0);

    const double lDist = std::abs(lNorm - 0.50);
    const double lScore = std::max(0.0, 1.0 - lDist * 1.8);
    score *= (0.35 + lScore * 0.85);

    if (l < 20) {
        score *= 0.08;
    } else if (l < 45) {
        score *= 0.35;
    } else if (l > 235 && s < 100) {
        score *= 0.12;
    }

    if (s < 30) {
        score *= 0.15;
    } else if (s < 70) {
        score *= 0.45;
    }

    return score;
}

} // namespace

ImageAnalyser::ImageAnalyser(QObject* parent)
    : QObject(parent)
    , m_futureWatcher(new QFutureWatcher<AnalyseResult>(this))
    , m_source("")
    , m_sourceItem(nullptr)
    , m_rescaleSize(128)
    , m_profile(QStringLiteral("wallpaper"))
    , m_dominantColour(0, 0, 0)
    , m_luminance(0) {
    QObject::connect(m_futureWatcher, &QFutureWatcher<AnalyseResult>::finished, this, [this]() {
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
    });
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

qreal ImageAnalyser::luminance() const {
    return m_luminance;
}

void ImageAnalyser::requestUpdate() {
    if (m_source.isEmpty() && !m_sourceItem) {
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
        m_futureWatcher->setFuture(QtConcurrent::run([=, this](QPromise<AnalyseResult>& promise) {
            const QImage image(m_source);
            analyse(promise, image, rescaleSize, profile);
        }));
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

} // namespace olvex