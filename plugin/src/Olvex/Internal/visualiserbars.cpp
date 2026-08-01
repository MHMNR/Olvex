#include "visualiserbars.hpp"

#include <algorithm>
#include <cmath>
#include <qsggeometry.h>
#include <qsgnode.h>
#include <qsgvertexcolormaterial.h>

namespace olvex::internal {

namespace {
    uchar colorChannel(qreal value, qreal alphaScale = 1.0) {
        return static_cast<uchar>(std::clamp(std::round(value * alphaScale * 255.0), 0.0, 255.0));
    }

    void setVertex(QSGGeometry::ColoredPoint2D& vertex, qreal x, qreal y, const QColor& color) {
        vertex.set(static_cast<float>(x), static_cast<float>(y), colorChannel(color.redF()),
            colorChannel(color.greenF()), colorChannel(color.blueF()), colorChannel(color.alphaF()));
    }
} // namespace

VisualiserBars::VisualiserBars(QQuickItem* parent)
    : QQuickItem(parent) {
    setFlag(ItemHasContents);
    m_timer.setTimerType(Qt::CoarseTimer);
    m_timer.setInterval(m_frameInterval);
    connect(&m_timer, &QTimer::timeout, this, &VisualiserBars::tick);
    connect(this, &QQuickItem::visibleChanged, this, &VisualiserBars::syncTimer);
    connect(this, &QQuickItem::opacityChanged, this, &VisualiserBars::syncTimer);
    connect(this, &QQuickItem::widthChanged, this, &VisualiserBars::syncTimer);
    connect(this, &QQuickItem::heightChanged, this, &VisualiserBars::syncTimer);
}

void VisualiserBars::advance(qreal dt) {
    if (m_displayValues.isEmpty() || m_settled || !paintingActive())
        return;

    step(std::clamp<qreal>(dt * 1000.0, 1.0, 100.0));
}

void VisualiserBars::tick() {
    const qint64 elapsedMs = m_elapsedTimer.isValid() ? m_elapsedTimer.restart() : m_frameInterval;
    step(std::clamp<qreal>(static_cast<qreal>(elapsedMs), 1.0, 100.0));
}

void VisualiserBars::step(qreal dtMs) {
    if (m_displayValues.isEmpty() || m_settled || !paintingActive()) {
        syncTimer();
        return;
    }

    const qreal tau = m_animationDuration / 3.0;
    const qreal alpha = 1.0 - std::exp(-dtMs / tau);

    bool allSettled = true;

    for (qsizetype i = 0; i < m_displayValues.size(); ++i) {
        const double diff = m_targetValues[i] - m_displayValues[i];

        if (std::abs(diff) > 0.001) {
            m_displayValues[i] += diff * alpha;
            allSettled = false;
        } else {
            m_displayValues[i] = m_targetValues[i];
        }
    }

    update();

    setSettled(allSettled);
    syncTimer();
}

QVector<double> VisualiserBars::values() const {
    return m_targetValues;
}

void VisualiserBars::setValues(const QVector<double>& values) {
    if (m_targetValues.size() == values.size()) {
        bool changed = false;
        for (qsizetype i = 0; i < values.size(); ++i) {
            if (std::abs(m_targetValues[i] - values[i]) > 0.015) {
                changed = true;
                break;
            }
        }
        if (!changed)
            return;
    }

    m_targetValues = values;

    if (m_displayValues.size() != values.size()) {
        m_displayValues.resize(values.size(), 0.0);
    }

    setSettled(false);
    syncTimer();

    emit valuesChanged();
}

bool VisualiserBars::settled() const {
    return m_settled;
}

QColor VisualiserBars::primaryColor() const {
    return m_primaryColor;
}

void VisualiserBars::setPrimaryColor(const QColor& color) {
    if (m_primaryColor == color)
        return;
    m_primaryColor = color;
    emit primaryColorChanged();
    if (isVisible())
        update();
}

QColor VisualiserBars::secondaryColor() const {
    return m_secondaryColor;
}

void VisualiserBars::setSecondaryColor(const QColor& color) {
    if (m_secondaryColor == color)
        return;
    m_secondaryColor = color;
    emit secondaryColorChanged();
    if (isVisible())
        update();
}

qreal VisualiserBars::rounding() const {
    return m_rounding;
}

void VisualiserBars::setRounding(qreal rounding) {
    if (qFuzzyCompare(m_rounding, rounding))
        return;
    m_rounding = rounding;
    emit roundingChanged();
    if (isVisible())
        update();
}

qreal VisualiserBars::spacing() const {
    return m_spacing;
}

void VisualiserBars::setSpacing(qreal spacing) {
    if (qFuzzyCompare(m_spacing, spacing))
        return;
    m_spacing = spacing;
    emit spacingChanged();
    if (isVisible())
        update();
}

int VisualiserBars::animationDuration() const {
    return m_animationDuration;
}

void VisualiserBars::setAnimationDuration(int duration) {
    if (m_animationDuration == duration)
        return;
    m_animationDuration = duration;
    emit animationDurationChanged();
}

bool VisualiserBars::active() const {
    return m_active;
}

void VisualiserBars::setActive(bool active) {
    if (m_active == active)
        return;
    m_active = active;
    syncTimer();
    emit activeChanged();
}

int VisualiserBars::frameInterval() const {
    return m_frameInterval;
}

void VisualiserBars::setFrameInterval(int interval) {
    interval = std::max(16, interval);
    if (m_frameInterval == interval)
        return;
    m_frameInterval = interval;
    m_timer.setInterval(m_frameInterval);
    emit frameIntervalChanged();
}

bool VisualiserBars::paintingActive() const {
    return m_active && !m_settled && isVisible() && opacity() > 0.001 && width() > 0 && height() > 0;
}

void VisualiserBars::syncTimer() {
    const bool nowPaintingActive = paintingActive();
    if (m_lastPaintingActive != nowPaintingActive) {
        m_lastPaintingActive = nowPaintingActive;
        emit paintingActiveChanged();
    }

    if (nowPaintingActive) {
        if (!m_timer.isActive()) {
            m_elapsedTimer.restart();
            m_timer.start();
        }
    } else {
        m_timer.stop();
        m_elapsedTimer.invalidate();
    }
}

void VisualiserBars::setSettled(bool settled) {
    if (m_settled == settled)
        return;
    m_settled = settled;
    emit settledChanged();
}

QSGNode* VisualiserBars::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
    const qsizetype count = m_displayValues.size();
    if (count <= 0 || width() <= 0 || height() <= 0) {
        delete oldNode;
        return nullptr;
    }

    const qreal w = width();
    const qreal h = height();
    const qreal sideWidth = w * 0.4;
    const qreal slotWidth = sideWidth / static_cast<qreal>(count);
    const qreal barWidth = std::max<qreal>(1.0, slotWidth - m_spacing);
    const qreal maxBarHeight = h * 0.4;

    qsizetype visibleBars = 0;
    for (const double rawValue : m_displayValues) {
        if (std::clamp(rawValue, 0.0, 1.0) * maxBarHeight >= 1.0)
            ++visibleBars;
    }

    const int vertexCount = static_cast<int>(visibleBars * 2 * 6);
    if (vertexCount == 0) {
        delete oldNode;
        return nullptr;
    }

    auto* node = static_cast<QSGGeometryNode*>(oldNode);
    if (!node) {
        node = new QSGGeometryNode;
        auto* geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), vertexCount);
        geometry->setDrawingMode(QSGGeometry::DrawTriangles);
        node->setGeometry(geometry);
        node->setFlag(QSGNode::OwnsGeometry);

        auto* material = new QSGVertexColorMaterial;
        material->setFlag(QSGMaterial::Blending);
        node->setMaterial(material);
        node->setFlag(QSGNode::OwnsMaterial);
    } else if (node->geometry()->vertexCount() != vertexCount) {
        node->geometry()->allocate(vertexCount);
    }

    auto* vertices = node->geometry()->vertexDataAsColoredPoint2D();
    int v = 0;
    auto addBar = [&](qreal x, qreal y, qreal bw, qreal bh) {
        const qreal x2 = x + bw;
        const qreal y2 = y + bh;
        setVertex(vertices[v++], x, y, m_primaryColor);
        setVertex(vertices[v++], x, y2, m_secondaryColor);
        setVertex(vertices[v++], x2, y2, m_secondaryColor);
        setVertex(vertices[v++], x, y, m_primaryColor);
        setVertex(vertices[v++], x2, y2, m_secondaryColor);
        setVertex(vertices[v++], x2, y, m_primaryColor);
    };

    auto drawSide = [&](bool rightSide) {
        const qreal sideOffset = rightSide ? w * 0.6 : 0.0;
        for (qsizetype i = 0; i < count; ++i) {
            const qsizetype valueIndex = rightSide ? i : (count - i - 1);
            const qreal value = std::clamp(m_displayValues[valueIndex], 0.0, 1.0);
            const qreal barHeight = value * maxBarHeight;
            if (barHeight < 1.0)
                continue;

            const qreal x = sideOffset + static_cast<qreal>(i) * slotWidth;
            addBar(x, h - barHeight, barWidth, barHeight);
        }
    };

    drawSide(false);
    drawSide(true);

    node->markDirty(QSGNode::DirtyGeometry);
    return node;
}

} // namespace olvex::internal
