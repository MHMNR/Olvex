#pragma once

#include "service.hpp"
#include <qqmlintegration.h>
#include <qtimer.h>

namespace olvex::services {

class AudioProcessor : public QObject {
    Q_OBJECT

public:
    explicit AudioProcessor(QObject* parent = nullptr);
    ~AudioProcessor();

    void init();

public slots:
    void start();
    void stop();
    void setInterval(int intervalMs);

protected:
    virtual void process() = 0;
    int interval() const;

private:
    QTimer* m_timer = nullptr;
    int m_interval = 33;
};

class AudioProvider : public Service {
    Q_OBJECT

public:
    explicit AudioProvider(QObject* parent = nullptr);
    ~AudioProvider();

protected:
    AudioProcessor* m_processor;

    void init();

    void start() override;
    void stop() override;

private:
    QThread* m_thread;
};

} // namespace olvex::services
