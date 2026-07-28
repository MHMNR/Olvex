#pragma once

#include "configobject.hpp"

namespace olvex::config {

class LockConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, style, QStringLiteral("card"))
    CONFIG_GLOBAL_PROPERTY(bool, showOnStartup, false)
    CONFIG_PROPERTY(bool, recolourLogo, false)
    CONFIG_GLOBAL_PROPERTY(bool, enableFprint, true)
    CONFIG_GLOBAL_PROPERTY(int, maxFprintTries, 3)
    CONFIG_PROPERTY(bool, hideNotifs, false)
    CONFIG_GLOBAL_PROPERTY(double, minimalOpacity, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, blurBackground, true)
    CONFIG_GLOBAL_PROPERTY(bool, dimWallpaper, false)

public:
    explicit LockConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace olvex::config
