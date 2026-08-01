#pragma once

#include "configobject.hpp"

namespace olvex::config {

class FlyoutsConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, hideDelay, 2000)
    CONFIG_PROPERTY(bool, enableBrightness, true)
    CONFIG_PROPERTY(bool, enableMicrophone, false)

public:
    explicit FlyoutsConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace olvex::config
