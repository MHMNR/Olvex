#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace olvex::config {

class LiveWallpaperConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, muted, true)

public:
    explicit LiveWallpaperConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class DesktopClockBackground : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
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

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom-right"))
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)

public:
    explicit DesktopClock(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_background(new DesktopClockBackground(this))
        , m_shadow(new DesktopClockShadow(this)) {}
};

class BackgroundVisualiser : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)

public:
    explicit BackgroundVisualiser(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class WallpaperTransitionConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(QString, type, QStringLiteral("random"))
    CONFIG_PROPERTY(int, duration, 1000)
    CONFIG_PROPERTY(qreal, edgeSmoothness, 0.1)

public:
    explicit WallpaperTransitionConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class WallpaperCyclingConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(int, intervalSeconds, 300)
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
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)

public:
    explicit BackgroundConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_liveWallpaper(new LiveWallpaperConfig(this))
        , m_desktopClock(new DesktopClock(this))
        , m_wallpaperTransition(new WallpaperTransitionConfig(this))
        , m_wallpaperCycling(new WallpaperCyclingConfig(this))
        , m_visualiser(new BackgroundVisualiser(this)) {}
};

} // namespace olvex::config
