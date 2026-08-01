#pragma once

#include "rootconfig.hpp"

#include <qqmlengine.h>

namespace olvex::config {

class AppearanceConfig;
class BackgroundConfig;
class BarConfig;
class BorderConfig;
class SettingsConfig;
class DashboardConfig;
class GeneralConfig;
class LauncherConfig;
class LockConfig;
class NotifsConfig;
class FlyoutsConfig;
class ServiceConfig;
class PowermenuConfig;
class NotificationcenterConfig;
class UserPaths;
class QspanelConfig;
class WInfoConfig;

class GlobalConfig : public RootConfig {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_MOC_INCLUDE("appearanceconfig.hpp")
    Q_MOC_INCLUDE("backgroundconfig.hpp")
    Q_MOC_INCLUDE("barconfig.hpp")
    Q_MOC_INCLUDE("borderconfig.hpp")
    Q_MOC_INCLUDE("settingsconfig.hpp")
    Q_MOC_INCLUDE("dashboardconfig.hpp")
    Q_MOC_INCLUDE("generalconfig.hpp")
    Q_MOC_INCLUDE("launcherconfig.hpp")
    Q_MOC_INCLUDE("lockconfig.hpp")
    Q_MOC_INCLUDE("notifsconfig.hpp")
    Q_MOC_INCLUDE("flyoutsconfig.hpp")
    Q_MOC_INCLUDE("serviceconfig.hpp")
    Q_MOC_INCLUDE("powermenuconfig.hpp")
    Q_MOC_INCLUDE("notificationcenterconfig.hpp")
    Q_MOC_INCLUDE("userpaths.hpp")
    Q_MOC_INCLUDE("qspanelconfig.hpp")
    Q_MOC_INCLUDE("winfoconfig.hpp")

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_SUBOBJECT(AppearanceConfig, appearance)
    CONFIG_SUBOBJECT(GeneralConfig, general)
    CONFIG_SUBOBJECT(BackgroundConfig, background)
    CONFIG_SUBOBJECT(BarConfig, bar)
    CONFIG_SUBOBJECT(BorderConfig, border)
    CONFIG_SUBOBJECT(DashboardConfig, dashboard)
    CONFIG_SUBOBJECT(SettingsConfig, settings)
    CONFIG_SUBOBJECT(LauncherConfig, launcher)
    CONFIG_SUBOBJECT(NotifsConfig, notifs)
    CONFIG_SUBOBJECT(FlyoutsConfig, flyouts)
    CONFIG_SUBOBJECT(PowermenuConfig, powermenu)
    CONFIG_SUBOBJECT(WInfoConfig, winfo)
    CONFIG_SUBOBJECT(LockConfig, lock)
    CONFIG_SUBOBJECT(QspanelConfig, qspanel)
    CONFIG_SUBOBJECT(NotificationcenterConfig, notificationcenter)
    CONFIG_SUBOBJECT(ServiceConfig, services)
    CONFIG_SUBOBJECT(UserPaths, paths)

public:
    static GlobalConfig* instance();
    [[nodiscard]] Q_INVOKABLE GlobalConfig* defaults();
    [[nodiscard]] Q_INVOKABLE static GlobalConfig* forScreen(const QString& screen);
    static GlobalConfig* create(QQmlEngine*, QJSEngine*);

    void bindAppearanceTokens();

private:
    friend class MonitorConfigManager;
    explicit GlobalConfig(QObject* parent = nullptr);
    explicit GlobalConfig(
        GlobalConfig* fallback, const QString& filePath, const QString& screen = {}, QObject* parent = nullptr);

    GlobalConfig* m_defaults = nullptr;
    bool m_tokensBound = false;
};

} // namespace olvex::config
