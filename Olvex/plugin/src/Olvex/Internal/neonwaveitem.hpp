#pragma once

#include <qcolor.h>
#include <qelapsedtimer.h>
#include <qobject.h>
#include <qpointer.h>
#include <qqmlintegration.h>
#include <qquickitem.h>
#include <qtimer.h>
#include <qvector.h>

namespace olvex::internal {

class NeonWaveItem : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(int numBands READ numBands WRITE setNumBands NOTIFY numBandsChanged)
    Q_PROPERTY(qreal maxHeightRatio READ maxHeightRatio WRITE setMaxHeightRatio NOTIFY maxHeightRatioChanged)
    Q_PROPERTY(qreal topFadeRatio READ topFadeRatio WRITE setTopFadeRatio NOTIFY topFadeRatioChanged)
    Q_PROPERTY(qreal valueMultiplier READ valueMultiplier WRITE setValueMultiplier NOTIFY valueMultiplierChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int frameInterval READ frameInterval WRITE setFrameInterval NOTIFY frameIntervalChanged)
    Q_PROPERTY(bool decayWhenInactive READ decayWhenInactive WRITE setDecayWhenInactive NOTIFY decayWhenInactiveChanged)
    Q_PROPERTY(bool externallyDriven READ externallyDriven WRITE setExternallyDriven NOTIFY externallyDrivenChanged)
    Q_PROPERTY(bool paintingActive READ paintingActive NOTIFY paintingActiveChanged)
    Q_PROPERTY(QObject *valueSource READ valueSource WRITE setValueSource NOTIFY valueSourceChanged)
    Q_PROPERTY(QVector<double> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(bool settled READ settled NOTIFY settledChanged)

public:
    explicit NeonWaveItem(QQuickItem *parent = nullptr);

    [[nodiscard]] QColor accentColor() const;
    void setAccentColor(const QColor &color);

    [[nodiscard]] int numBands() const;
    void setNumBands(int bands);

    [[nodiscard]] qreal maxHeightRatio() const;
    void setMaxHeightRatio(qreal ratio);

    [[nodiscard]] qreal topFadeRatio() const;
    void setTopFadeRatio(qreal ratio);

    [[nodiscard]] qreal valueMultiplier() const;
    void setValueMultiplier(qreal multiplier);

    [[nodiscard]] bool active() const;
    void setActive(bool active);

    [[nodiscard]] int frameInterval() const;
    void setFrameInterval(int interval);

    [[nodiscard]] bool decayWhenInactive() const;
    void setDecayWhenInactive(bool decay);

    [[nodiscard]] bool externallyDriven() const;
    void setExternallyDriven(bool driven);

    [[nodiscard]] bool paintingActive() const;

    [[nodiscard]] QObject *valueSource() const;
    void setValueSource(QObject *source);

    [[nodiscard]] QVector<double> values() const;
    void setValues(const QVector<double> &values);

    [[nodiscard]] bool settled() const;

    Q_INVOKABLE void resetValues();
    Q_INVOKABLE void advance(qreal dt);

signals:
    void accentColorChanged();
    void numBandsChanged();
    void maxHeightRatioChanged();
    void topFadeRatioChanged();
    void valueMultiplierChanged();
    void activeChanged();
    void frameIntervalChanged();
    void decayWhenInactiveChanged();
    void externallyDrivenChanged();
    void paintingActiveChanged();
    void valueSourceChanged();
    void valuesChanged();
    void settledChanged();

private slots:
    void tick();
    void pullValuesFromSource();

private:
    [[nodiscard]] qreal maxSmoothValue() const;
    void syncTimer();
    void ensureBandCount();
    void setSettled(bool settled);
    void setValuesInternal(const QVector<double> &values, bool notify);
    void step(double dtMs);
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

    QColor m_accentColor;
    int m_numBands = 32;
    qreal m_maxHeightRatio = 0.85;
    qreal m_topFadeRatio = 0.0;
    qreal m_valueMultiplier = 1.5;
    bool m_active = true;
    int m_frameInterval = 16;
    bool m_decayWhenInactive = true;
    bool m_externallyDriven = false;
    QPointer<QObject> m_valueSource;
    QMetaObject::Connection m_valueSourceConnection;
    QMetaObject::Connection m_valueSourceDestroyedConnection;
    QVector<double> m_values;
    QVector<double> m_smoothValues;
    QTimer m_timer;
    QElapsedTimer m_elapsedTimer;
    float m_geometryWidth = -1.0f;
    float m_geometryHeight = -1.0f;
    bool m_settled = false;
    bool m_lastPaintingActive = false;
};

} // namespace olvex::internal
