#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace olvex::config {

class LiveWallpaperConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, muted, true)

public:
    explicit LiveWallpaperConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.1)
    CONFIG_PROPERTY(bool, blur, true)

public:
    explicit DesktopClockBackground(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockShadow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)

public:
    explicit DesktopClockShadow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(QString, style, QStringLiteral("olvex-signature"))
    CONFIG_PROPERTY(int, styleVariant, 0)
    CONFIG_PROPERTY(qreal, scale, 1.5097524282094594)
    CONFIG_PROPERTY(QString, placementStrategy, QStringLiteral("leastBusy")) // "fixed", "leastBusy", "mostBusy"
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-right"))
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_PROPERTY(bool, adaptiveTextColor, true)
    CONFIG_PROPERTY(qreal, autoX, 1348.0)
    CONFIG_PROPERTY(qreal, autoY, 740.0)
    CONFIG_PROPERTY(bool, dominantIsDark, true)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)

public:
    explicit DesktopClock(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopClockBackground(this))
        , m_shadow(new DesktopClockShadow(this)) {}
};

class WallpaperTransitionConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, type, QStringLiteral("random"))
    CONFIG_PROPERTY(int, duration, 1000)
    CONFIG_PROPERTY(qreal, edgeSmoothness, 0.3)

public:
    explicit WallpaperTransitionConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class WallpaperCyclingConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(int, intervalSeconds, 60)
    CONFIG_PROPERTY(bool, shuffle, false)
    CONFIG_PROPERTY(bool, pauseOnFullscreen, true)
    CONFIG_PROPERTY(bool, pauseOnLock, true)

public:
    explicit WallpaperCyclingConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BackgroundConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_PROPERTY(bool, perMonitorWallpaper, false)
    CONFIG_SUBOBJECT(LiveWallpaperConfig, liveWallpaper)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(WallpaperTransitionConfig, wallpaperTransition)
    CONFIG_SUBOBJECT(WallpaperCyclingConfig, wallpaperCycling)

public:
    explicit BackgroundConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_liveWallpaper(new LiveWallpaperConfig(this))
        , m_desktopClock(new DesktopClock(this))
        , m_wallpaperTransition(new WallpaperTransitionConfig(this))
        , m_wallpaperCycling(new WallpaperCyclingConfig(this)) {}
};

} // namespace olvex::config
