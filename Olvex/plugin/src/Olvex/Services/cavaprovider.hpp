#pragma once

#include "audioprovider.hpp"
#include <cava/cavacore.h>
#include <atomic>
#include <qmutex.h>
#include <qqmlintegration.h>

namespace olvex::services {

class CavaProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit CavaProcessor(QObject* parent = nullptr);
    ~CavaProcessor();

    void setBars(int bars);
    void setFrameRate(int frameRate);

signals:
    void valuesChanged(QVector<double> values);

protected:
    void process() override;

private:
    struct cava_plan* m_plan;
    double* m_in;
    double* m_out;

    int m_bars;
    int m_frameRate;
    QVector<double> m_values;

    void reload();
    void initCava();
    void cleanup();
};

class CavaProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(int frameRate READ frameRate WRITE setFrameRate NOTIFY frameRateChanged)

    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)
    Q_PROPERTY(bool qmlValuePublishing READ qmlValuePublishing WRITE setQmlValuePublishing NOTIFY qmlValuePublishingChanged)

public:
    explicit CavaProvider(QObject* parent = nullptr);

    [[nodiscard]] int bars() const;
    void setBars(int bars);
    [[nodiscard]] int frameRate() const;
    void setFrameRate(int frameRate);

    [[nodiscard]] QVector<double> values() const;
    [[nodiscard]] bool qmlValuePublishing() const;
    void setQmlValuePublishing(bool publishing);

signals:
    void barsChanged();
    void frameRateChanged();
    void valuesChanged();
    void qmlValuePublishingChanged();

private:
    int m_bars;
    int m_frameRate;
    mutable QMutex m_valuesMutex;
    QVector<double> m_values;
    bool m_active;
    std::atomic_bool m_qmlValuePublishing;
    std::atomic_bool m_valuesNotifyPending;

    void updateValues(QVector<double> values);
    void scheduleValuesChanged();
    void start() override;
    void stop() override;
};

} // namespace olvex::services
