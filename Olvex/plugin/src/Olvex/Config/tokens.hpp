#pragma once

#include "rootconfig.hpp"

#include <qlist.h>
#include <qqmlengine.h>

namespace olvex::config {

class AnimCurves : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QList<qreal>, emphasized)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, emphasizedAccel)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, emphasizedDecel)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, standard)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, standardAccel)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, standardDecel)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveFastSpatial)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveDefaultSpatial)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveSlowSpatial)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveFastEffects)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveDefaultEffects)
    CONFIG_GLOBAL_PROPERTY(QList<qreal>, expressiveSlowEffects)

public:
    explicit AnimCurves(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_emphasized({ 0.2, 0.0, 0.0, 1.0, 1.0, 1.0 })
        , m_emphasizedAccel({ 0.3, 0.0, 0.8, 0.15, 1.0, 1.0 })
        , m_emphasizedDecel({ 0.05, 0.7, 0.1, 1.0, 1.0, 1.0 })
        , m_standard({ 0.2, 0.0, 0.0, 1.0, 1.0, 1.0 })
        , m_standardAccel({ 0.3, 0.0, 1.0, 1.0, 1.0, 1.0 })
        , m_standardDecel({ 0.0, 0.0, 0.2, 1.0, 1.0, 1.0 })
        , m_expressiveFastSpatial({ 0.42, 1.4, 0.21, 0.98, 1.0, 1.0 })
        , m_expressiveDefaultSpatial({ 0.38, 1.2, 0.22, 1.0, 1.0, 1.0 })
        , m_expressiveSlowSpatial({ 0.39, 1.15, 0.35, 1.0, 1.0, 1.0 })
        , m_expressiveFastEffects({ 0.2, 0.0, 0.0, 1.0, 1.0, 1.0 })
        , m_expressiveDefaultEffects({ 0.2, 0.0, 0.0, 1.0, 1.0, 1.0 })
        , m_expressiveSlowEffects({ 0.2, 0.0, 0.0, 1.0, 1.0, 1.0 }) {}
};

class RoundingTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, extraSmall, 4)
    CONFIG_PROPERTY(int, small, 12)
    CONFIG_PROPERTY(int, normal, 17)
    CONFIG_PROPERTY(int, large, 25)
    CONFIG_PROPERTY(int, full, 1000)

public:
    explicit RoundingTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class SpacingTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, extraSmall, 4)
    CONFIG_PROPERTY(int, small, 7)
    CONFIG_PROPERTY(int, smaller, 10)
    CONFIG_PROPERTY(int, normal, 12)
    CONFIG_PROPERTY(int, larger, 15)
    CONFIG_PROPERTY(int, large, 20)

public:
    explicit SpacingTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class PaddingTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, small, 5)
    CONFIG_PROPERTY(int, smaller, 7)
    CONFIG_PROPERTY(int, normal, 10)
    CONFIG_PROPERTY(int, larger, 12)
    CONFIG_PROPERTY(int, large, 15)

public:
    explicit PaddingTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class FontSizeTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, small, 11)
    CONFIG_PROPERTY(int, smaller, 12)
    CONFIG_PROPERTY(int, normal, 13)
    CONFIG_PROPERTY(int, larger, 15)
    CONFIG_PROPERTY(int, large, 18)
    CONFIG_PROPERTY(int, extraLarge, 28)

public:
    explicit FontSizeTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class AnimDurationTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(int, small, 200)
    CONFIG_GLOBAL_PROPERTY(int, normal, 400)
    CONFIG_GLOBAL_PROPERTY(int, large, 600)
    CONFIG_GLOBAL_PROPERTY(int, extraLarge, 1000)
    CONFIG_GLOBAL_PROPERTY(int, expressiveFastSpatial, 350)
    CONFIG_GLOBAL_PROPERTY(int, expressiveDefaultSpatial, 500)
    CONFIG_GLOBAL_PROPERTY(int, expressiveSlowSpatial, 650)
    CONFIG_GLOBAL_PROPERTY(int, expressiveFastEffects, 150)
    CONFIG_GLOBAL_PROPERTY(int, expressiveDefaultEffects, 200)
    CONFIG_GLOBAL_PROPERTY(int, expressiveSlowEffects, 300)

public:
    explicit AnimDurationTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class AppearanceTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_SUBOBJECT(AnimCurves, curves)
    CONFIG_SUBOBJECT(RoundingTokens, rounding)
    CONFIG_SUBOBJECT(SpacingTokens, spacing)
    CONFIG_SUBOBJECT(PaddingTokens, padding)
    CONFIG_SUBOBJECT(FontSizeTokens, fontSize)
    CONFIG_SUBOBJECT(AnimDurationTokens, animDurations)

public:
    explicit AppearanceTokens(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_curves(new AnimCurves(this))
        , m_rounding(new RoundingTokens(this))
        , m_spacing(new SpacingTokens(this))
        , m_padding(new PaddingTokens(this))
        , m_fontSize(new FontSizeTokens(this))
        , m_animDurations(new AnimDurationTokens(this)) {}
};

class BarTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, innerWidth, 40)
    CONFIG_PROPERTY(int, windowPreviewSize, 400)
    CONFIG_PROPERTY(int, trayMenuWidth, 300)
    CONFIG_PROPERTY(int, batteryWidth, 250)
    CONFIG_PROPERTY(int, networkWidth, 320)
    CONFIG_PROPERTY(int, kbLayoutWidth, 320)

public:
    explicit BarTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DashboardTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, tabIndicatorHeight, 3)
    CONFIG_PROPERTY(int, tabIndicatorSpacing, 5)
    CONFIG_PROPERTY(int, infoWidth, 200)
    CONFIG_PROPERTY(int, infoIconSize, 25)
    CONFIG_PROPERTY(int, dateTimeWidth, 110)
    CONFIG_PROPERTY(int, mediaWidth, 200)
    CONFIG_PROPERTY(int, mediaProgressSweep, 180)
    CONFIG_PROPERTY(int, mediaProgressThickness, 8)
    CONFIG_PROPERTY(int, resourceProgressThickness, 10)
    CONFIG_PROPERTY(int, weatherWidth, 250)
    CONFIG_PROPERTY(int, mediaCoverArtSize, 150)
    CONFIG_PROPERTY(int, mediaVisualiserSize, 80)
    CONFIG_PROPERTY(int, resourceSize, 200)

public:
    explicit DashboardTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class LauncherTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, itemWidth, 600)
    CONFIG_PROPERTY(int, itemHeight, 57)
    CONFIG_PROPERTY(int, wallpaperWidth, 280)
    CONFIG_PROPERTY(int, wallpaperHeight, 200)

public:
    explicit LauncherTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class NotifsTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, width, 400)
    CONFIG_GLOBAL_PROPERTY(int, image, 41)
    CONFIG_PROPERTY(int, badge, 20)

public:
    explicit NotifsTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class FlyoutsTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, sliderWidth, 30)
    CONFIG_PROPERTY(int, sliderHeight, 150)

public:
    explicit FlyoutsTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class PowermenuTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, button, 80)

public:
    explicit PowermenuTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class NotificationcenterTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, width, 430)

public:
    explicit NotificationcenterTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class QspanelTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, width, 430)
    CONFIG_PROPERTY(int, toastWidth, 430)

public:
    explicit QspanelTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class LockTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, heightMult, 0.7)
    CONFIG_PROPERTY(qreal, ratio, 16.0 / 9.0)
    CONFIG_PROPERTY(int, centerWidth, 600)

public:
    explicit LockTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class WInfoTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, heightMult, 0.7)
    CONFIG_PROPERTY(qreal, detailsWidth, 500)

public:
    explicit WInfoTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class SettingsTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, heightMult, 0.7)
    CONFIG_PROPERTY(qreal, ratio, 16.0 / 9.0)

public:
    explicit SettingsTokens(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class SizeTokens : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_SUBOBJECT(BarTokens, bar)
    CONFIG_SUBOBJECT(DashboardTokens, dashboard)
    CONFIG_SUBOBJECT(LauncherTokens, launcher)
    CONFIG_SUBOBJECT(NotifsTokens, notifs)
    CONFIG_SUBOBJECT(FlyoutsTokens, flyouts)
    CONFIG_SUBOBJECT(PowermenuTokens, powermenu)
    CONFIG_SUBOBJECT(NotificationcenterTokens, notificationcenter)
    CONFIG_SUBOBJECT(QspanelTokens, qspanel)
    CONFIG_SUBOBJECT(LockTokens, lock)
    CONFIG_SUBOBJECT(WInfoTokens, winfo)
    CONFIG_SUBOBJECT(SettingsTokens, settings)

public:
    explicit SizeTokens(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_bar(new BarTokens(this))
        , m_dashboard(new DashboardTokens(this))
        , m_launcher(new LauncherTokens(this))
        , m_notifs(new NotifsTokens(this))
        , m_flyouts(new FlyoutsTokens(this))
        , m_powermenu(new PowermenuTokens(this))
        , m_notificationcenter(new NotificationcenterTokens(this))
        , m_qspanel(new QspanelTokens(this))
        , m_lock(new LockTokens(this))
        , m_winfo(new WInfoTokens(this))
        , m_settings(new SettingsTokens(this)) {}
};

class TokenConfig : public RootConfig {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    CONFIG_SUBOBJECT(AppearanceTokens, appearance)
    CONFIG_SUBOBJECT(SizeTokens, sizes)

public:
    static TokenConfig* instance();
    [[nodiscard]] Q_INVOKABLE TokenConfig* defaults();
    [[nodiscard]] Q_INVOKABLE static TokenConfig* forScreen(const QString& screen);
    static TokenConfig* create(QQmlEngine*, QJSEngine*);

private:
    friend class MonitorConfigManager;
    explicit TokenConfig(QObject* parent = nullptr);
    explicit TokenConfig(
        TokenConfig* fallback, const QString& filePath, const QString& screen = {}, QObject* parent = nullptr);

    TokenConfig* m_defaults = nullptr;
};

} // namespace olvex::config
