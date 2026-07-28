#include "audioprovider.hpp"

#include "audiocollector.hpp"
#include "service.hpp"
#include <algorithm>
#include <qloggingcategory.h>
#include <qthread.h>

Q_LOGGING_CATEGORY(lcAp, "olvex.services.ap", QtInfoMsg)
Q_LOGGING_CATEGORY(lcApProcessor, "olvex.services.ap.processor", QtInfoMsg)

namespace olvex::services {

AudioProcessor::AudioProcessor(QObject* parent)
    : QObject(parent) {}

AudioProcessor::~AudioProcessor() {
    stop();
}

void AudioProcessor::init() {
    m_timer = new QTimer(this);
    m_timer->setInterval(m_interval);
    connect(m_timer, &QTimer::timeout, this, &AudioProcessor::process);
}

void AudioProcessor::start() {
    QMetaObject::invokeMethod(&AudioCollector::instance(), &AudioCollector::ref, Qt::QueuedConnection, this);
    if (m_timer) {
        m_timer->start();
    }
}

void AudioProcessor::stop() {
    if (m_timer) {
        m_timer->stop();
    }
    QMetaObject::invokeMethod(&AudioCollector::instance(), &AudioCollector::unref, Qt::QueuedConnection, this);
}

void AudioProcessor::setInterval(int intervalMs) {
    m_interval = std::clamp(intervalMs, 16, 1000);
    if (m_timer) {
        m_timer->setInterval(m_interval);
    }
}

int AudioProcessor::interval() const {
    return m_interval;
}

AudioProvider::AudioProvider(QObject* parent)
    : Service(parent)
    , m_processor(nullptr)
    , m_thread(nullptr) {}

AudioProvider::~AudioProvider() {
    if (m_thread) {
        m_thread->quit();
        m_thread->wait();
    }
}

void AudioProvider::init() {
    if (!m_processor) {
        qCWarning(lcAp) << "init: attempted to init with no processor set";
        return;
    }

    m_thread = new QThread(this);
    m_processor->moveToThread(m_thread);

    connect(m_thread, &QThread::started, m_processor, &AudioProcessor::init);
    connect(m_thread, &QThread::finished, m_processor, &AudioProcessor::deleteLater);
    connect(m_thread, &QThread::finished, m_thread, &QThread::deleteLater);

    m_thread->start();
}

void AudioProvider::start() {
    qCDebug(lcAp) << "AudioProvider::start: starting processor";
    if (m_processor) {
        AudioCollector::instance(); // Create instance on main thread
        QMetaObject::invokeMethod(m_processor, &AudioProcessor::start);
    }
}

void AudioProvider::stop() {
    if (m_processor) {
        QMetaObject::invokeMethod(m_processor, &AudioProcessor::stop);
    }
}

} // namespace olvex::services
