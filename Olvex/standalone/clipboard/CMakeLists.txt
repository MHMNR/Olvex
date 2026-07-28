add_executable(olvex-clipboard
    main.cpp
    clipboard.qrc
)

set_target_properties(olvex-clipboard PROPERTIES
    AUTOMOC ON
    AUTORCC ON
)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

target_link_libraries(olvex-clipboard PRIVATE Qt6::Core Qt6::Qml Qt6::Quick)

# Install the binary to system bin (so `command -v olvex-clipboard` works)
install(TARGETS olvex-clipboard
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

# Install standalone QML alongside the binary in the standalone subtree.
install(FILES
    ClipboardStandalone.qml
    DESTINATION "${INSTALL_QSCONFDIR}/standalone/clipboard"
)