qml_module(olvex-services
    URI Olvex.Services
    SOURCES
        service.hpp service.cpp
        serviceref.hpp serviceref.cpp
        beattracker.hpp beattracker.cpp
        audiocollector.hpp audiocollector.cpp
        audioprovider.hpp audioprovider.cpp
        cavaprovider.hpp cavaprovider.cpp
        usbwatcher.hpp usbwatcher.cpp
    LIBRARIES
        PkgConfig::Pipewire
        PkgConfig::Aubio
        PkgConfig::Cava
        PkgConfig::Udev
)
