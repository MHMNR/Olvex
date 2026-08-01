#pragma once

#include "configobject.hpp"

namespace olvex::config {

class NotificationcenterConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 80)

public:
    explicit NotificationcenterConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace olvex::config
