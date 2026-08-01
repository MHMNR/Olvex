#include "config.hpp"
#include "appearanceconfig.hpp"
#include "backgroundconfig.hpp"
#include "barconfig.hpp"
#include "borderconfig.hpp"
#include "settingsconfig.hpp"
#include "dashboardconfig.hpp"
#include "generalconfig.hpp"
#include "launcherconfig.hpp"
#include "lockconfig.hpp"
#include "monitorconfigmanager.hpp"
#include "notifsconfig.hpp"
#include "flyoutsconfig.hpp"
#include "serviceconfig.hpp"
#include "powermenuconfig.hpp"
#include "notificationcenterconfig.hpp"
#include "tokens.hpp"
#include "userpaths.hpp"
#include "qspanelconfig.hpp"
#include "winfoconfig.hpp"

#include <qqmlengine.h>
#include <qstandardpaths.h>

namespace olvex::config {

namespace {

QString configDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/olvex/");
}

} // namespace

GlobalConfig::GlobalConfig(QObject* parent)
    : RootConfig(parent)
    , m_appearance(new AppearanceConfig(this))
    , m_general(new GeneralConfig(this))
    , m_background(new BackgroundConfig(this))
    , m_bar(new BarConfig(this))
    , m_border(new BorderConfig(this))
    , m_dashboard(new DashboardConfig(this))
    , m_settings(new SettingsConfig(this))
    , m_launcher(new LauncherConfig(this))
    , m_notifs(new NotifsConfig(this))
    , m_flyouts(new FlyoutsConfig(this))
    , m_powermenu(new PowermenuConfig(this))
    , m_winfo(new WInfoConfig(this))
    , m_lock(new LockConfig(this))
    , m_qspanel(new QspanelConfig(this))
    , m_notificationcenter(new NotificationcenterConfig(this))
    , m_services(new ServiceConfig(this))
    , m_paths(new UserPaths(this)) {
    setupFileBackend(configDir() + QStringLiteral("shell.json"));
}

GlobalConfig::GlobalConfig(GlobalConfig* fallback, const QString& filePath, const QString& screen, QObject* parent)
    : RootConfig(parent)
    , m_appearance(new AppearanceConfig(this))
    , m_general(new GeneralConfig(this))
    , m_background(new BackgroundConfig(this))
    , m_bar(new BarConfig(this))
    , m_border(new BorderConfig(this))
    , m_dashboard(new DashboardConfig(this))
    , m_settings(new SettingsConfig(this))
    , m_launcher(new LauncherConfig(this))
    , m_notifs(new NotifsConfig(this))
    , m_flyouts(new FlyoutsConfig(this))
    , m_powermenu(new PowermenuConfig(this))
    , m_winfo(new WInfoConfig(this))
    , m_lock(new LockConfig(this))
    , m_qspanel(new QspanelConfig(this))
    , m_notificationcenter(new NotificationcenterConfig(this))
    , m_services(new ServiceConfig(this))
    , m_paths(new UserPaths(this)) {
    if (!filePath.isEmpty())
        setupFileBackend(filePath, screen);
    if (fallback)
        syncFromGlobal(fallback);

    // Bind appearance computed properties to token base values
    bindAppearanceTokens();
}

GlobalConfig* GlobalConfig::instance() {
    static GlobalConfig instance;
    instance.bindAppearanceTokens();
    return &instance;
}

GlobalConfig* GlobalConfig::defaults() {
    if (!m_defaults)
        m_defaults = new GlobalConfig(nullptr, QString(), QString(), this);
    return m_defaults;
}

void GlobalConfig::bindAppearanceTokens() {
    if (m_tokensBound)
        return;

    qCDebug(lcConfig) << "GlobalConfig::bindAppearanceTokens: binding appearance to token values";
    auto* const tokenAppearance = TokenConfig::instance()->appearance();
    m_appearance->rounding()->bindTokens(tokenAppearance->rounding());
    m_appearance->spacing()->bindTokens(tokenAppearance->spacing());
    m_appearance->padding()->bindTokens(tokenAppearance->padding());
    m_appearance->font()->size()->bindTokens(tokenAppearance->fontSize());
    m_appearance->anim()->durations()->bindTokens(tokenAppearance->animDurations());
    m_tokensBound = true;
}

GlobalConfig* GlobalConfig::forScreen(const QString& screen) {
    return MonitorConfigManager::instance()->configForScreen(screen);
}

GlobalConfig* GlobalConfig::create(QQmlEngine*, QJSEngine*) {
    QQmlEngine::setObjectOwnership(instance(), QQmlEngine::CppOwnership);
    return instance();
}

} // namespace olvex::config
