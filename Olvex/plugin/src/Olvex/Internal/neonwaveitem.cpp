#include "neonwaveitem.hpp"
#include "neonwavematerial.hpp"

#include <algorithm>
#include <cmath>
#include <qmetaobject.h>
#include <qsggeometry.h>
#include <qsgnode.h>
#include <qvariant.h>

namespace olvex::internal {

namespace {
    constexpr double kIdleValue = 0.01;
    constexpr qreal kEdgeFeather = 0.75;

    QColor lighterColor(const QColor &color, qreal factor)
    {
        QColor boosted = color;
        return boosted.lighter(static_cast<int>(std::round(factor * 100.0)));
    }

} // namespace

NeonWaveItem::NeonWaveItem(QQuickItem *parent)
    : QQuickItem(parent)
    , m_accentColor(0, 0, 0)
{
    setFlag(ItemHasContents);
    m_timer.setTimerType(Qt::CoarseTimer);
    m_timer.setInterval(m_frameInterval);
    connect(&m_timer, &QTimer::timeout, this, &NeonWaveItem::tick);
    connect(this, &QQuickItem::visibleChanged, this, &NeonWaveItem::syncTimer);
    connect(this, &QQuickItem::opacityChanged, this, &NeonWaveItem::syncTimer);
    connect(this, &QQuickItem::widthChanged, this, [this]() {
        if (paintingActive())
            update();
        syncTimer();
    });
    connect(this, &QQuickItem::heightChanged, this, [this]() {
        if (paintingActive())
            update();
        syncTimer();
    });
    ensureBandCount();
}

QSGNode *NeonWaveItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    const qsizetype count = m_smoothValues.size();
    if (count < 2 || width() <= 0 || height() <= 0) {
        delete oldNode;
        m_geometryWidth = -1.0f;
        m_geometryHeight = -1.0f;
        return nullptr;
    }

    const bool newNode = oldNode == nullptr;
    auto *rootNode = oldNode;
    if (!rootNode) {
        auto *node = new QSGGeometryNode;
        auto *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        geometry->setDrawingMode(QSGGeometry::DrawTriangleStrip);
        node->setGeometry(geometry);
        node->setFlag(QSGNode::OwnsGeometry);

        auto *material = new NeonWaveMaterial;
        material->setFlag(QSGMaterial::Blending);
        node->setMaterial(material);
        node->setFlag(QSGNode::OwnsMaterial);
        rootNode = node;
    }

    auto *node = static_cast<QSGGeometryNode *>(rootNode);
    auto *geometry = node->geometry();
    auto *vertices = geometry->vertexDataAsTexturedPoint2D();
    const float w = static_cast<float>(width());
    const float h = static_cast<float>(height());

    if (newNode || !qFuzzyCompare(m_geometryWidth, w) || !qFuzzyCompare(m_geometryHeight, h)) {
        vertices[0].set(0.0f, 0.0f, 0.0f, 0.0f);
        vertices[1].set(w, 0.0f, 1.0f, 0.0f);
        vertices[2].set(0.0f, h, 0.0f, 1.0f);
        vertices[3].set(w, h, 1.0f, 1.0f);
        m_geometryWidth = w;
        m_geometryHeight = h;
        node->markDirty(QSGNode::DirtyGeometry);
    }

    auto *material = static_cast<NeonWaveMaterial *>(node->material());
    material->m_width = w;
    material->m_height = h;
    material->m_maxHeightRatio = static_cast<float>(m_maxHeightRatio);
    material->m_edgeFeather = static_cast<float>(kEdgeFeather);
    material->m_topFadeRatio = static_cast<float>(m_topFadeRatio);
    material->m_bandCount = std::clamp(m_numBands, 2, 32);
    material->m_accentColor = m_accentColor;
    material->m_boostedColor = lighterColor(m_accentColor, 1.3);
    material->m_values.fill(static_cast<float>(kIdleValue));
    const int copyCount = std::min<int>(material->m_bandCount, static_cast<int>(m_smoothValues.size()));
    for (int i = 0; i < copyCount; ++i)
        material->m_values[static_cast<size_t>(i)] = static_cast<float>(std::clamp(m_smoothValues[i], 0.0, 1.0));
    node->markDirty(QSGNode::DirtyMaterial);

    return rootNode;
}

QColor NeonWaveItem::accentColor() const { return m_accentColor; }

void NeonWaveItem::setAccentColor(const QColor &color)
{
    if (m_accentColor == color)
        return;
    m_accentColor = color;
    emit accentColorChanged();
    if (isVisible())
        update();
}

int NeonWaveItem::numBands() const { return m_numBands; }

void NeonWaveItem::setNumBands(int bands)
{
    bands = std::max(2, bands);
    if (m_numBands == bands)
        return;
    m_numBands = bands;
    ensureBandCount();
    emit numBandsChanged();
    if (paintingActive())
        update();
}

qreal NeonWaveItem::maxHeightRatio() const { return m_maxHeightRatio; }

void NeonWaveItem::setMaxHeightRatio(qreal ratio)
{
    ratio = std::clamp(ratio, 0.0, 1.0);
    if (qFuzzyCompare(m_maxHeightRatio, ratio))
        return;
    m_maxHeightRatio = ratio;
    emit maxHeightRatioChanged();
    if (isVisible())
        update();
}

qreal NeonWaveItem::topFadeRatio() const { return m_topFadeRatio; }

void NeonWaveItem::setTopFadeRatio(qreal ratio)
{
    ratio = std::clamp(ratio, 0.0, 0.9);
    if (qFuzzyCompare(m_topFadeRatio, ratio))
        return;
    m_topFadeRatio = ratio;
    emit topFadeRatioChanged();
    if (isVisible())
        update();
}

qreal NeonWaveItem::valueMultiplier() const { return m_valueMultiplier; }

void NeonWaveItem::setValueMultiplier(qreal multiplier)
{
    multiplier = std::max<qreal>(0.0, multiplier);
    if (qFuzzyCompare(m_valueMultiplier, multiplier))
        return;
    m_valueMultiplier = multiplier;
    emit valueMultiplierChanged();
}

bool NeonWaveItem::active() const { return m_active; }

void NeonWaveItem::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    if (!m_active && m_decayWhenInactive && !m_settled)
        syncTimer();
    else
        syncTimer();
    emit activeChanged();
}

int NeonWaveItem::frameInterval() const { return m_frameInterval; }

void NeonWaveItem::setFrameInterval(int interval)
{
    interval = std::max(1, interval);
    if (m_frameInterval == interval)
        return;
    m_frameInterval = interval;
    m_timer.setTimerType(m_frameInterval <= 17 ? Qt::PreciseTimer : Qt::CoarseTimer);
    m_timer.setInterval(m_frameInterval);
    emit frameIntervalChanged();
}

bool NeonWaveItem::decayWhenInactive() const { return m_decayWhenInactive; }

void NeonWaveItem::setDecayWhenInactive(bool decay)
{
    if (m_decayWhenInactive == decay)
        return;
    m_decayWhenInactive = decay;
    syncTimer();
    emit decayWhenInactiveChanged();
}

bool NeonWaveItem::externallyDriven() const { return m_externallyDriven; }

void NeonWaveItem::setExternallyDriven(bool driven)
{
    if (m_externallyDriven == driven)
        return;
    m_externallyDriven = driven;
    syncTimer();
    emit externallyDrivenChanged();
}

QObject *NeonWaveItem::valueSource() const { return m_valueSource.data(); }

void NeonWaveItem::setValueSource(QObject *source)
{
    if (m_valueSource == source)
        return;

    if (m_valueSourceConnection)
        QObject::disconnect(m_valueSourceConnection);
    if (m_valueSourceDestroyedConnection)
        QObject::disconnect(m_valueSourceDestroyedConnection);

    m_valueSource = source;
    m_valueSourceConnection = {};
    m_valueSourceDestroyedConnection = {};

    if (m_valueSource) {
        m_valueSourceDestroyedConnection = QObject::connect(m_valueSource, &QObject::destroyed, this, [this]() {
            m_valueSource = nullptr;
            m_valueSourceConnection = {};
            m_valueSourceDestroyedConnection = {};
            setValues({});
            emit valueSourceChanged();
        });
        pullValuesFromSource();
    } else {
        setValues({});
    }

    emit valueSourceChanged();
}

QVector<double> NeonWaveItem::values() const { return m_values; }

void NeonWaveItem::setValues(const QVector<double> &values)
{
    setValuesInternal(values, true);
}

void NeonWaveItem::setValuesInternal(const QVector<double> &values, bool notify)
{
    if (m_values == values)
        return;
    m_values = values;
    if (notify)
        emit valuesChanged();
    if (m_active) {
        syncTimer();
        if (!m_externallyDriven && paintingActive() && !m_timer.isActive()) {
            m_elapsedTimer.restart();
            m_timer.start();
        }
    }
}

bool NeonWaveItem::settled() const { return m_settled; }

void NeonWaveItem::resetValues()
{
    std::fill(m_smoothValues.begin(), m_smoothValues.end(), kIdleValue);
    setSettled(maxSmoothValue() <= 0.012);
    if (isVisible())
        update();
    syncTimer();
}

bool NeonWaveItem::paintingActive() const
{
    return (m_active || (m_decayWhenInactive && !m_settled)) && isVisible() && opacity() > 0.001 && width() > 0
        && height() > 0;
}

qreal NeonWaveItem::maxSmoothValue() const
{
    qreal maxValue = 0.0;
    for (const double value : m_smoothValues)
        maxValue = std::max(maxValue, static_cast<qreal>(value));
    return maxValue;
}

void NeonWaveItem::syncTimer()
{
    const bool nowPaintingActive = paintingActive();
    if (m_lastPaintingActive != nowPaintingActive) {
        m_lastPaintingActive = nowPaintingActive;
        emit paintingActiveChanged();
    }

    if (m_externallyDriven) {
        m_timer.stop();
        m_elapsedTimer.invalidate();
        return;
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

void NeonWaveItem::ensureBandCount()
{
    if (m_smoothValues.size() == m_numBands)
        return;

    QVector<double> next(m_numBands, kIdleValue);
    const qsizetype copyCount = std::min(m_smoothValues.size(), next.size());
    for (qsizetype i = 0; i < copyCount; ++i)
        next[i] = m_smoothValues[i];
    m_smoothValues = std::move(next);
    setSettled(maxSmoothValue() <= 0.012);
}

void NeonWaveItem::setSettled(bool settled)
{
    if (m_settled == settled)
        return;
    m_settled = settled;
    emit settledChanged();
}

void NeonWaveItem::pullValuesFromSource()
{
    if (!m_valueSource) {
        setValues({});
        return;
    }

    const QVariant rawValues = m_valueSource->property("values");
    if (!rawValues.isValid()) {
        setValues({});
        return;
    }

    setValuesInternal(rawValues.value<QVector<double>>(), false);
}

void NeonWaveItem::tick()
{
    const qint64 elapsedMs = m_elapsedTimer.isValid() ? m_elapsedTimer.restart() : m_frameInterval;
    const double dtMs = std::clamp<double>(static_cast<double>(elapsedMs), 1.0, 100.0);
    step(dtMs);
}

void NeonWaveItem::advance(qreal dt)
{
    if (!m_externallyDriven || !paintingActive()) {
        syncTimer();
        return;
    }

    const double dtMs = std::clamp<double>(static_cast<double>(dt) * 1000.0, 1.0, 100.0);
    step(dtMs);
}

void NeonWaveItem::step(double dtMs)
{
    ensureBandCount();
    if (m_valueSource && m_active)
        pullValuesFromSource();

    const auto approach = [dtMs](double tauMs) { return 1.0 - std::exp(-dtMs / std::max(1.0, tauMs)); };

    bool changed = false;
    for (int i = 0; i < m_numBands; ++i) {
        const double current = (i < m_smoothValues.size()) ? m_smoothValues[i] : kIdleValue;
        const bool hasInput = m_active && i < m_values.size();
        const double source = hasInput ? m_values[i] : 0.0;
        const double target = hasInput ? std::max(kIdleValue, std::min(1.0, source * m_valueMultiplier)) : kIdleValue;
        const double diff = target - current;
        constexpr double threshold = 0.001;

        if (std::abs(diff) > threshold) {
            const double catchupTau = std::abs(diff) > 0.25 ? 18.0 : 28.0;
            const double releaseTau = std::abs(diff) > 0.25 ? 32.0 : 58.0;
            constexpr double decayTau = 170.0;
            const double alpha
                = hasInput ? (diff > 0 ? approach(catchupTau) : approach(releaseTau)) : approach(decayTau);
            m_smoothValues[i] = current + diff * alpha;
            changed = true;
        } else {
            m_smoothValues[i] = target;
        }
    }

    const bool nowSettled = maxSmoothValue() <= 0.012;
    setSettled(nowSettled);

    if (!changed && nowSettled) {
        syncTimer();
        return;
    }

    if (changed) {
        update();
    }

    syncTimer();
}

} // namespace olvex::internal
