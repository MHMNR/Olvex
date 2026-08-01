#pragma once

#include "configobject.hpp"

namespace olvex::config {

// SettingsConfig has no serialized properties (serializer returns {})
// All properties are in AdvancedConfig.controlCenter
class SettingsConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

public:
    explicit SettingsConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace olvex::config
