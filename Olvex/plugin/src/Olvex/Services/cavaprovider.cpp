#include "cavaprovider.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"
#include <cava/cavacore.h>
#include <cstddef>
#include <qloggingcategory.h>
#include <algorithm>

Q_LOGGING_CATEGORY(lcCava, "olvex.services.cava", QtInfoMsg)
Q_LOGGING_CATEGORY(lcCavaProcessor, "olvex.services.cava.processor", QtInfoMsg)

namespace olvex::services {

CavaProcessor::CavaProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_plan(nullptr)
    , m_in(new double[ac::CHUNK_SIZE])
    , m_out(nullptr)
    , m_bars(0)
    , m_frameRate(30) {};

CavaProcessor::~CavaProcessor() {
    cleanup();
    delete[] m_in;
}

void CavaProcessor::process() {
    if (!m_plan || m_bars == 0 || !m_out) {
        return;
    }

    const int count = static_cast<int>(AudioCollector::instance().readChunk(m_in));
    for (int i = 0; i < count; ++i) {
        m_in[i] *= 10.0; // Boost gain
    }

    // Process in data via cava
    cava_execute(m_in, count, m_out, m_plan);
    // qCDebug(lcCavaProcessor) << "CavaProcessor: processed" << count << "samples, max m_out:" << *std::max_element(m_out, m_out + m_bars);

    // Apply monstercat filter
    QVector<double> values(m_bars);

    // Left to right pass
    const double inv = 1.0 / 1.5;
    double carry = 0.0;
    for (int i = 0; i < m_bars; ++i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = carry;
    }

    // Right to left pass and combine
    carry = 0.0;
    for (int i = m_bars - 1; i >= 0; --i) {
        carry = std::max(m_out[i], carry * inv);
        values[i] = std::max(values[i], carry);
    }

    // Update values
    bool changed = values.size() != m_values.size();
    if (!changed) {
        for (qsizetype i = 0; i < values.size(); ++i) {
            if (std::abs(values[i] - m_values[i]) > 0.003) {
                changed = true;
                break;
            }
        }
    }

    if (changed) {
        m_values = std::move(values);
        emit valuesChanged(m_values);
    }
}

void CavaProcessor::setBars(int bars) {
    if (bars < 0) {
        qCWarning(lcCavaProcessor) << "setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars != bars) {
        m_bars = bars;
        reload();
    }
}

void CavaProcessor::setFrameRate(int frameRate) {
    m_frameRate = std::clamp(frameRate, 1, 60);
    setInterval(std::max(16, 1000 / m_frameRate));
}

void CavaProcessor::reload() {
    cleanup();
    initCava();
}

void CavaProcessor::cleanup() {
    if (m_plan) {
        cava_destroy(m_plan);
        m_plan = nullptr;
    }

    if (m_out) {
        delete[] m_out;
        m_out = nullptr;
    }
}

void CavaProcessor::initCava() {
    if (m_plan || m_bars == 0) {
        return;
    }

    m_plan = cava_init(m_bars, ac::SAMPLE_RATE, 1, 1, 0.1, 1, 10000); // More sensitive
    m_out = new double[static_cast<size_t>(m_bars)];
}

CavaProvider::CavaProvider(QObject* parent)
    : AudioProvider(parent)
    , m_bars(0)
    , m_frameRate(30)
    , m_values(m_bars, 0.0)
    , m_active(false) {
    m_processor = new CavaProcessor();
    init();

    connect(static_cast<CavaProcessor*>(m_processor), &CavaProcessor::valuesChanged, this, &CavaProvider::updateValues);
}

int CavaProvider::bars() const {
    return m_bars;
}

int CavaProvider::frameRate() const {
    return m_frameRate;
}

void CavaProvider::setFrameRate(int frameRate) {
    frameRate = std::clamp(frameRate, 1, 60);
    if (m_frameRate == frameRate) {
        return;
    }

    m_frameRate = frameRate;
    emit frameRateChanged();

    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setFrameRate, Qt::QueuedConnection, frameRate);
}

void CavaProvider::setBars(int bars) {
    if (bars < 0) {
        qCWarning(lcCava) << "setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars == bars) {
        return;
    }

    m_values.resize(bars, 0.0);
    m_bars = bars;
    emit barsChanged();
    emit valuesChanged();

    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setBars, Qt::QueuedConnection, bars);
}

QVector<double> CavaProvider::values() const {
    return m_values;
}

void CavaProvider::updateValues(QVector<double> values) {
    if (values != m_values) {
        m_values = values;
        // qCDebug(lcCava) << "CavaProvider: values updated, first bar:" << (m_values.isEmpty() ? 0 : m_values[0]);
        emit valuesChanged();
    }
}

void CavaProvider::start() {
    m_active = true;
    auto* processor = static_cast<CavaProcessor*>(m_processor);
    QMetaObject::invokeMethod(processor, &CavaProcessor::setFrameRate, Qt::QueuedConnection, m_frameRate);
    QMetaObject::invokeMethod(processor, &CavaProcessor::setBars, Qt::QueuedConnection, m_bars);
    AudioProvider::start();
}

void CavaProvider::stop() {
    AudioProvider::stop();
    m_active = false;
}

} // namespace olvex::services
