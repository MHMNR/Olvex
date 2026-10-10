add_executable(olvex-emoji
    main.cpp
    emoji.qrc
)

set_target_properties(olvex-emoji PROPERTIES
    AUTOMOC ON
    AUTORCC ON
)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickEffects)

target_link_libraries(olvex-emoji PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickEffects)

# Install the binary to system bin (so `command -v olvex-emoji` works)
install(TARGETS olvex-emoji
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

# Install standalone QML alongside the binary in the standalone subtree.
install(FILES
    EmojiStandalone.qml
    emojis.js
    update_emojis.py
    DESTINATION "${INSTALL_QSCONFDIR}/standalone/emoji"
)
