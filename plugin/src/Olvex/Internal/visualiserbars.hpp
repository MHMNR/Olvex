#pragma once

#include <qcolor.h>
#include <qelapsedtimer.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qquickitem.h>
#include <qtimer.h>
#include <qvector.h>

namespace olvex::internal {

class VisualiserBars : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVector<double> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(QColor primaryColor READ primaryColor WRITE setPrimaryColor NOTIFY primaryColorChanged)
    Q_PROPERTY(QColor secondaryColor READ secondaryColor WRITE setSecondaryColor NOTIFY secondaryColorChanged)
    Q_PROPERTY(qreal rounding READ rounding WRITE setRounding NOTIFY roundingChanged)
    Q_PROPERTY(qreal spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(int animationDuration READ animationDuration WRITE setAnimationDuration NOTIFY animationDurationChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int frameInterval READ frameInterval WRITE setFrameInterval NOTIFY frameIntervalChanged)
    Q_PROPERTY(bool paintingActive READ paintingActive NOTIFY paintingActiveChanged)
    Q_PROPERTY(bool settled READ settled NOTIFY settledChanged)

public:
    explicit VisualiserBars(QQuickItem* parent = nullptr);

    Q_INVOKABLE void advance(qreal dt);

    [[nodiscard]] QVector<double> values() const;
    void setValues(const QVector<double>& values);

    [[nodiscard]] QColor primaryColor() const;
    void setPrimaryColor(const QColor& color);

    [[nodiscard]] QColor secondaryColor() const;
    void setSecondaryColor(const QColor& color);

    [[nodiscard]] qreal rounding() const;
    void setRounding(qreal rounding);

    [[nodiscard]] qreal spacing() const;
    void setSpacing(qreal spacing);

    [[nodiscard]] int animationDuration() const;
    void setAnimationDuration(int duration);

    [[nodiscard]] bool active() const;
    void setActive(bool active);

    [[nodiscard]] int frameInterval() const;
    void setFrameInterval(int interval);

    [[nodiscard]] bool paintingActive() const;

    [[nodiscard]] bool settled() const;

signals:
    void valuesChanged();
    void primaryColorChanged();
    void secondaryColorChanged();
    void roundingChanged();
    void spacingChanged();
    void animationDurationChanged();
    void activeChanged();
    void frameIntervalChanged();
    void paintingActiveChanged();
    void settledChanged();

private:
    void syncTimer();
    void setSettled(bool settled);
    void tick();
    void step(qreal dtMs);
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;

    QVector<double> m_targetValues;
    QVector<double> m_displayValues;
    QColor m_primaryColor;
    QColor m_secondaryColor;
    qreal m_rounding = 0.0;
    qreal m_spacing = 0.0;
    int m_animationDuration = 200;
    bool m_active = true;
    int m_frameInterval = 33;
    QTimer m_timer;
    QElapsedTimer m_elapsedTimer;
    bool m_settled = true;
    bool m_lastPaintingActive = false;
};

} // namespace olvex::internal
