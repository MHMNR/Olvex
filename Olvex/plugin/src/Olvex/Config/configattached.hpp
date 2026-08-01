#pragma once

#include "config.hpp"

#include <qquickattachedpropertypropagator.h>

namespace olvex::config {

class Config : public QQuickAttachedPropertyPropagator, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_ELEMENT
    QML_UNCREATABLE("")
    QML_ATTACHED(Config)
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

    Q_PROPERTY(QString screen READ screen WRITE inheritScreen NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::AppearanceConfig* appearance READ appearance NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::GeneralConfig* general READ general NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::BackgroundConfig* background READ background NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::BarConfig* bar READ bar NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::BorderConfig* border READ border NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::DashboardConfig* dashboard READ dashboard NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::SettingsConfig* settings READ settings NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::LauncherConfig* launcher READ launcher NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::NotifsConfig* notifs READ notifs NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::FlyoutsConfig* flyouts READ flyouts NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::PowermenuConfig* powermenu READ powermenu NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::WInfoConfig* winfo READ winfo NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::LockConfig* lock READ lock NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::QspanelConfig* qspanel READ qspanel NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::NotificationcenterConfig* notificationcenter READ notificationcenter NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::ServiceConfig* services READ services NOTIFY sourceChanged)
    Q_PROPERTY(const olvex::config::UserPaths* paths READ paths NOTIFY sourceChanged)

public:
    explicit Config(QObject* parent = nullptr);

    [[nodiscard]] QString screen() const;
    void inheritScreen(const QString& screen);

    [[nodiscard]] const AppearanceConfig* appearance() const;
    [[nodiscard]] const GeneralConfig* general() const;
    [[nodiscard]] const BackgroundConfig* background() const;
    [[nodiscard]] const BarConfig* bar() const;
    [[nodiscard]] const BorderConfig* border() const;
    [[nodiscard]] const DashboardConfig* dashboard() const;
    [[nodiscard]] const SettingsConfig* settings() const;
    [[nodiscard]] const LauncherConfig* launcher() const;
    [[nodiscard]] const NotifsConfig* notifs() const;
    [[nodiscard]] const FlyoutsConfig* flyouts() const;
    [[nodiscard]] const PowermenuConfig* powermenu() const;
    [[nodiscard]] const WInfoConfig* winfo() const;
    [[nodiscard]] const LockConfig* lock() const;
    [[nodiscard]] const QspanelConfig* qspanel() const;
    [[nodiscard]] const NotificationcenterConfig* notificationcenter() const;
    [[nodiscard]] const ServiceConfig* services() const;
    [[nodiscard]] const UserPaths* paths() const;

    [[nodiscard]] Q_INVOKABLE static GlobalConfig* forScreen(const QString& screen);

    static Config* qmlAttachedProperties(QObject* object);

signals:
    void sourceChanged();

protected:
    void attachedParentChange(
        QQuickAttachedPropertyPropagator* newParent, QQuickAttachedPropertyPropagator* oldParent) override;

private:
    void classBegin() override;
    void componentComplete() override;

    void propagateScreen();

    bool m_complete = false;
    QString m_screen;
    GlobalConfig* m_config = nullptr;
};

} // namespace olvex::config
