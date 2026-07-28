qml_module(olvex-internal
    URI Olvex.Internal
    SOURCES
        arcgauge.hpp arcgauge.cpp
        cachingimagemanager.hpp cachingimagemanager.cpp
        circularbuffer.hpp circularbuffer.cpp
        circularindicatormanager.hpp circularindicatormanager.cpp
        linearindicatormanager.hpp linearindicatormanager.cpp
        hyprdevices.hpp hyprdevices.cpp
        hyprextras.hpp hyprextras.cpp
        logindmanager.hpp logindmanager.cpp
        sparklineitem.hpp sparklineitem.cpp
        visualiserbars.hpp visualiserbars.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
        Qt::DBus
)
