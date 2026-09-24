#pragma once

#include "configobject.hpp"

#include <algorithm>

namespace olvex::config {

class BorderConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, thickness, 0)
    CONFIG_PROPERTY(int, rounding, 25)
    CONFIG_PROPERTY(int, smoothing, 32)
    CONFIG_PROPERTY(bool, floating, true)
    CONFIG_PROPERTY(int, gap, 6)

    Q_PROPERTY(int minThickness READ minThickness CONSTANT)
    Q_PROPERTY(int clampedThickness READ clampedThickness NOTIFY thicknessChanged)
    Q_PROPERTY(int drawerRounding READ drawerRounding NOTIFY drawerRoundingChanged)

public:
    explicit BorderConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {
        connect(this, &BorderConfig::roundingChanged, this, &BorderConfig::drawerRoundingChanged);
        connect(this, &BorderConfig::gapChanged, this, &BorderConfig::drawerRoundingChanged);
        connect(this, &BorderConfig::floatingChanged, this, &BorderConfig::drawerRoundingChanged);
    }

    [[nodiscard]] static int minThickness() { return 0; }

    [[nodiscard]] int clampedThickness() const { return std::max(minThickness(), m_thickness); }

    [[nodiscard]] int drawerRounding() const {
        return m_floating ? std::max(0, m_rounding - m_gap) : m_rounding;
    }

signals:
    void drawerRoundingChanged();
};

} // namespace olvex::config
