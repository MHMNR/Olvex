.pragma library

// Keycodes from /usr/include/linux/input-event-codes.h
const defaultLayout = "Default";
const byName = {
    "Default": {
        name_short: "Default",
        description: "Standard 75% Mechanical Layout",
        keys: [
            [
                { keytype: "normal", label: "Esc", shape: "fn", keycode: 1 },
                { keytype: "normal", label: "F1", shape: "fn", keycode: 59 },
                { keytype: "normal", label: "F2", shape: "fn", keycode: 60 },
                { keytype: "normal", label: "F3", shape: "fn", keycode: 61 },
                { keytype: "normal", label: "F4", shape: "fn", keycode: 62 },
                { keytype: "normal", label: "F5", shape: "fn", keycode: 63 },
                { keytype: "normal", label: "F6", shape: "fn", keycode: 64 },
                { keytype: "normal", label: "F7", shape: "fn", keycode: 65 },
                { keytype: "normal", label: "F8", shape: "fn", keycode: 66 },
                { keytype: "normal", label: "F9", shape: "fn", keycode: 67 },
                { keytype: "normal", label: "F10", shape: "fn", keycode: 68 },
                { keytype: "normal", label: "F11", shape: "fn", keycode: 87 },
                { keytype: "normal", label: "F12", shape: "fn", keycode: 88 },
                { keytype: "normal", label: "PrtSc", shape: "fn", keycode: 99 },
                { keytype: "normal", label: "delete", shape: "fn", keycode: 111, isIcon: true }
            ],
            [
                { keytype: "normal", label: "`", labelShift: "~", shape: "normal", keycode: 41 },
                { keytype: "normal", label: "1", labelShift: "!", shape: "normal", keycode: 2 },
                { keytype: "normal", label: "2", labelShift: "@", shape: "normal", keycode: 3 },
                { keytype: "normal", label: "3", labelShift: "#", shape: "normal", keycode: 4 },
                { keytype: "normal", label: "4", labelShift: "$", shape: "normal", keycode: 5 },
                { keytype: "normal", label: "5", labelShift: "%", shape: "normal", keycode: 6 },
                { keytype: "normal", label: "6", labelShift: "^", shape: "normal", keycode: 7 },
                { keytype: "normal", label: "7", labelShift: "&", shape: "normal", keycode: 8 },
                { keytype: "normal", label: "8", labelShift: "*", shape: "normal", keycode: 9 },
                { keytype: "normal", label: "9", labelShift: "(", shape: "normal", keycode: 10 },
                { keytype: "normal", label: "0", labelShift: ")", shape: "normal", keycode: 11 },
                { keytype: "normal", label: "-", labelShift: "_", shape: "normal", keycode: 12 },
                { keytype: "normal", label: "=", labelShift: "+", shape: "normal", keycode: 13 },
                { keytype: "normal", label: "backspace", shape: "expand", keycode: 14, isIcon: true }
            ],
            [
                { keytype: "normal", label: "keyboard_tab", shape: "tab", keycode: 15, isIcon: true },
                { keytype: "normal", label: "q", labelShift: "Q", shape: "normal", keycode: 16 },
                { keytype: "normal", label: "w", labelShift: "W", shape: "normal", keycode: 17 },
                { keytype: "normal", label: "e", labelShift: "E", shape: "normal", keycode: 18 },
                { keytype: "normal", label: "r", labelShift: "R", shape: "normal", keycode: 19 },
                { keytype: "normal", label: "t", labelShift: "T", shape: "normal", keycode: 20 },
                { keytype: "normal", label: "y", labelShift: "Y", shape: "normal", keycode: 21 },
                { keytype: "normal", label: "u", labelShift: "U", shape: "normal", keycode: 22 },
                { keytype: "normal", label: "i", labelShift: "I", shape: "normal", keycode: 23 },
                { keytype: "normal", label: "o", labelShift: "O", shape: "normal", keycode: 24 },
                { keytype: "normal", label: "p", labelShift: "P", shape: "normal", keycode: 25 },
                { keytype: "normal", label: "[", labelShift: "{", shape: "normal", keycode: 26 },
                { keytype: "normal", label: "]", labelShift: "}", shape: "normal", keycode: 27 },
                { keytype: "normal", label: "\\", labelShift: "|", shape: "normal", keycode: 43 }
            ],
            [
                { keytype: "modkey", label: "keyboard_capslock", shape: "caps", keycode: 58, isIcon: true },
                { keytype: "normal", label: "a", labelShift: "A", shape: "normal", keycode: 30 },
                { keytype: "normal", label: "s", labelShift: "S", shape: "normal", keycode: 31 },
                { keytype: "normal", label: "d", labelShift: "D", shape: "normal", keycode: 32 },
                { keytype: "normal", label: "f", labelShift: "F", shape: "normal", keycode: 33 },
                { keytype: "normal", label: "g", labelShift: "G", shape: "normal", keycode: 34 },
                { keytype: "normal", label: "h", labelShift: "H", shape: "normal", keycode: 35 },
                { keytype: "normal", label: "j", labelShift: "J", shape: "normal", keycode: 36 },
                { keytype: "normal", label: "k", labelShift: "K", shape: "normal", keycode: 37 },
                { keytype: "normal", label: "l", labelShift: "L", shape: "normal", keycode: 38 },
                { keytype: "normal", label: ";", labelShift: ":", shape: "normal", keycode: 39 },
                { keytype: "normal", label: "'", labelShift: "\"", shape: "normal", keycode: 40 },
                { keytype: "normal", label: "keyboard_return", shape: "expand", keycode: 28, isIcon: true }
            ],
            [
                { keytype: "modkey", label: "keyboard_arrow_up", shape: "shift", keycode: 42, isIcon: true },
                { keytype: "normal", label: "z", labelShift: "Z", shape: "normal", keycode: 44 },
                { keytype: "normal", label: "x", labelShift: "X", shape: "normal", keycode: 45 },
                { keytype: "normal", label: "c", labelShift: "C", shape: "normal", keycode: 46 },
                { keytype: "normal", label: "v", labelShift: "V", shape: "normal", keycode: 47 },
                { keytype: "normal", label: "b", labelShift: "B", shape: "normal", keycode: 48 },
                { keytype: "normal", label: "n", labelShift: "N", shape: "normal", keycode: 49 },
                { keytype: "normal", label: "m", labelShift: "M", shape: "normal", keycode: 50 },
                { keytype: "normal", label: ",", labelShift: "<", shape: "normal", keycode: 51 },
                { keytype: "normal", label: ".", labelShift: ">", shape: "normal", keycode: 52 },
                { keytype: "normal", label: "/", labelShift: "?", shape: "normal", keycode: 53 },
                { keytype: "modkey", label: "keyboard_arrow_up", shape: "shift", keycode: 54, isIcon: true }
            ],
            [
                { keytype: "modkey", label: "Ctrl", shape: "control", keycode: 29 },
                { keytype: "modkey", label: "Win", shape: "normal", keycode: 125 },
                { keytype: "modkey", label: "Alt", shape: "normal", keycode: 56 },
                { keytype: "normal", label: "Space", shape: "space", keycode: 57 },
                { keytype: "modkey", label: "Alt", shape: "normal", keycode: 100 },
                { keytype: "modkey", label: "menu", shape: "normal", keycode: 127, isIcon: true },
                { keytype: "modkey", label: "Ctrl", shape: "control", keycode: 97 }
            ]
        ]
    },
    "Phone": {
        name_short: "Phone",
        description: "Smartphone-style Layout (GBoard)",
        keys: [
            [
                { keytype: "normal", label: "1", shape: "normal", keycode: 2 },
                { keytype: "normal", label: "2", shape: "normal", keycode: 3 },
                { keytype: "normal", label: "3", shape: "normal", keycode: 4 },
                { keytype: "normal", label: "4", shape: "normal", keycode: 5 },
                { keytype: "normal", label: "5", shape: "normal", keycode: 6 },
                { keytype: "normal", label: "6", shape: "normal", keycode: 7 },
                { keytype: "normal", label: "7", shape: "normal", keycode: 8 },
                { keytype: "normal", label: "8", shape: "normal", keycode: 9 },
                { keytype: "normal", label: "9", shape: "normal", keycode: 10 },
                { keytype: "normal", label: "0", shape: "normal", keycode: 11 }
            ],
            [
                { keytype: "normal", label: "q", labelShift: "Q", shape: "normal", keycode: 16 },
                { keytype: "normal", label: "w", labelShift: "W", shape: "normal", keycode: 17 },
                { keytype: "normal", label: "e", labelShift: "E", shape: "normal", keycode: 18 },
                { keytype: "normal", label: "r", labelShift: "R", shape: "normal", keycode: 19 },
                { keytype: "normal", label: "t", labelShift: "T", shape: "normal", keycode: 20 },
                { keytype: "normal", label: "y", labelShift: "Y", shape: "normal", keycode: 21 },
                { keytype: "normal", label: "u", labelShift: "U", shape: "normal", keycode: 22 },
                { keytype: "normal", label: "i", labelShift: "I", shape: "normal", keycode: 23 },
                { keytype: "normal", label: "o", labelShift: "O", shape: "normal", keycode: 24 },
                { keytype: "normal", label: "p", labelShift: "P", shape: "normal", keycode: 25 }
            ],
            [
                { keytype: "spacer", width: 0.5 },
                { keytype: "normal", label: "a", labelShift: "A", shape: "normal", keycode: 30 },
                { keytype: "normal", label: "s", labelShift: "S", shape: "normal", keycode: 31 },
                { keytype: "normal", label: "d", labelShift: "D", shape: "normal", keycode: 32 },
                { keytype: "normal", label: "f", labelShift: "F", shape: "normal", keycode: 33 },
                { keytype: "normal", label: "g", labelShift: "G", shape: "normal", keycode: 34 },
                { keytype: "normal", label: "h", labelShift: "H", shape: "normal", keycode: 35 },
                { keytype: "normal", label: "j", labelShift: "J", shape: "normal", keycode: 36 },
                { keytype: "normal", label: "k", labelShift: "K", shape: "normal", keycode: 37 },
                { keytype: "normal", label: "l", labelShift: "L", shape: "normal", keycode: 38 },
                { keytype: "spacer", width: 0.5 }
            ],
            [
                { keytype: "modkey", label: "keyboard_arrow_up", shape: "shift", keycode: 42, isIcon: true, width: 1.5 },
                { keytype: "normal", label: "z", labelShift: "Z", shape: "normal", keycode: 44 },
                { keytype: "normal", label: "x", labelShift: "X", shape: "normal", keycode: 45 },
                { keytype: "normal", label: "c", labelShift: "C", shape: "normal", keycode: 46 },
                { keytype: "normal", label: "v", labelShift: "V", shape: "normal", keycode: 47 },
                { keytype: "normal", label: "b", labelShift: "B", shape: "normal", keycode: 48 },
                { keytype: "normal", label: "n", labelShift: "N", shape: "normal", keycode: 49 },
                { keytype: "normal", label: "m", labelShift: "M", shape: "normal", keycode: 50 },
                { keytype: "normal", label: "backspace", shape: "normal", keycode: 14, isIcon: true, width: 1.5 }
            ],
            [
                { keytype: "normal", label: "?123", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_Symbols", width: 1.5 },
                { keytype: "normal", label: ",", shape: "normal", keycode: 51, width: 1.0 },
                { keytype: "normal", label: "sentiment_satisfied", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_Emoji", isIcon: true, width: 1.0 },
                { keytype: "normal", label: "Space", shape: "space", keycode: 57, width: 4.0 },
                { keytype: "normal", label: ".", shape: "normal", keycode: 52, width: 1.0 },
                { keytype: "normal", label: "keyboard_return", shape: "normal", keycode: 28, isIcon: true, width: 1.5 }
            ]
        ]
    },
    "Phone_Symbols": {
        name_short: "?123",
        description: "Phone Symbols Layout",
        keys: [
            [
                { keytype: "normal", label: "1", shape: "normal", keycode: 2 },
                { keytype: "normal", label: "2", shape: "normal", keycode: 3 },
                { keytype: "normal", label: "3", shape: "normal", keycode: 4 },
                { keytype: "normal", label: "4", shape: "normal", keycode: 5 },
                { keytype: "normal", label: "5", shape: "normal", keycode: 6 },
                { keytype: "normal", label: "6", shape: "normal", keycode: 7 },
                { keytype: "normal", label: "7", shape: "normal", keycode: 8 },
                { keytype: "normal", label: "8", shape: "normal", keycode: 9 },
                { keytype: "normal", label: "9", shape: "normal", keycode: 10 },
                { keytype: "normal", label: "0", shape: "normal", keycode: 11 }
            ],
            [
                { keytype: "normal", label: "@", shape: "normal", keycode: 3, isShiftedKey: true },
                { keytype: "normal", label: "#", shape: "normal", keycode: 4, isShiftedKey: true },
                { keytype: "normal", label: "$", shape: "normal", keycode: 5, isShiftedKey: true },
                { keytype: "normal", label: "_", shape: "normal", keycode: 12, isShiftedKey: true },
                { keytype: "normal", label: "&", shape: "normal", keycode: 7, isShiftedKey: true },
                { keytype: "normal", label: "-", shape: "normal", keycode: 12 },
                { keytype: "normal", label: "+", shape: "normal", keycode: 13, isShiftedKey: true },
                { keytype: "normal", label: "(", shape: "normal", keycode: 10, isShiftedKey: true },
                { keytype: "normal", label: ")", shape: "normal", keycode: 11, isShiftedKey: true },
                { keytype: "normal", label: "/", shape: "normal", keycode: 53 }
            ],
            [
                { keytype: "normal", label: "=\\<", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_MoreSymbols", width: 1.5 },
                { keytype: "normal", label: "*", shape: "normal", keycode: 9, isShiftedKey: true },
                { keytype: "normal", label: "\"", shape: "normal", keycode: 40, isShiftedKey: true },
                { keytype: "normal", label: "'", shape: "normal", keycode: 40 },
                { keytype: "normal", label: ":", shape: "normal", keycode: 39, isShiftedKey: true },
                { keytype: "normal", label: ";", shape: "normal", keycode: 39 },
                { keytype: "normal", label: "!", shape: "normal", keycode: 2, isShiftedKey: true },
                { keytype: "normal", label: "?", shape: "normal", keycode: 53, isShiftedKey: true },
                { keytype: "normal", label: "backspace", shape: "normal", keycode: 14, isIcon: true, width: 1.5 }
            ],
            [
                { keytype: "normal", label: "ABC", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone", width: 1.5 },
                { keytype: "normal", label: ",", shape: "normal", keycode: 51, width: 1.0 },
                { keytype: "normal", label: "dialpad", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_Num", isIcon: true, width: 1.0 },
                { keytype: "normal", label: "Space", shape: "space", keycode: 57, width: 4.0 },
                { keytype: "normal", label: ".", shape: "normal", keycode: 52, width: 1.0 },
                { keytype: "normal", label: "keyboard_return", shape: "normal", keycode: 28, isIcon: true, width: 1.5 }
            ]
        ]
    },
    "Phone_MoreSymbols": {
        name_short: "~[<",
        description: "Phone More Symbols",
        keys: [
            [
                { keytype: "normal", label: "~", shape: "normal", keycode: 41, isShiftedKey: true },
                { keytype: "normal", label: "`", shape: "normal", keycode: 41 },
                { keytype: "normal", label: "|", shape: "normal", keycode: 43, isShiftedKey: true },
                { keytype: "normal", label: "•", shape: "normal", keycode: 0, isRawChar: true, rawChar: "•" },
                { keytype: "normal", label: "√", shape: "normal", keycode: 0, isRawChar: true, rawChar: "√" },
                { keytype: "normal", label: "π", shape: "normal", keycode: 0, isRawChar: true, rawChar: "π" },
                { keytype: "normal", label: "÷", shape: "normal", keycode: 0, isRawChar: true, rawChar: "÷" },
                { keytype: "normal", label: "×", shape: "normal", keycode: 0, isRawChar: true, rawChar: "×" },
                { keytype: "normal", label: "§", shape: "normal", keycode: 0, isRawChar: true, rawChar: "§" },
                { keytype: "normal", label: "Δ", shape: "normal", keycode: 0, isRawChar: true, rawChar: "Δ" }
            ],
            [
                { keytype: "normal", label: "£", shape: "normal", keycode: 0, isRawChar: true, rawChar: "£" },
                { keytype: "normal", label: "¢", shape: "normal", keycode: 0, isRawChar: true, rawChar: "¢" },
                { keytype: "normal", label: "€", shape: "normal", keycode: 0, isRawChar: true, rawChar: "€" },
                { keytype: "normal", label: "¥", shape: "normal", keycode: 0, isRawChar: true, rawChar: "¥" },
                { keytype: "normal", label: "^", shape: "normal", keycode: 7, isShiftedKey: true },
                { keytype: "normal", label: "°", shape: "normal", keycode: 0, isRawChar: true, rawChar: "°" },
                { keytype: "normal", label: "=", shape: "normal", keycode: 13 },
                { keytype: "normal", label: "{", shape: "normal", keycode: 26, isShiftedKey: true },
                { keytype: "normal", label: "}", shape: "normal", keycode: 27, isShiftedKey: true },
                { keytype: "normal", label: "\\", shape: "normal", keycode: 43 }
            ],
            [
                { keytype: "normal", label: "?123", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_Symbols", width: 1.5 },
                { keytype: "normal", label: "%", shape: "normal", keycode: 6, isShiftedKey: true },
                { keytype: "normal", label: "©", shape: "normal", keycode: 0, isRawChar: true, rawChar: "©" },
                { keytype: "normal", label: "®", shape: "normal", keycode: 0, isRawChar: true, rawChar: "®" },
                { keytype: "normal", label: "™", shape: "normal", keycode: 0, isRawChar: true, rawChar: "™" },
                { keytype: "normal", label: "✓", shape: "normal", keycode: 0, isRawChar: true, rawChar: "✓" },
                { keytype: "normal", label: "[", shape: "normal", keycode: 26 },
                { keytype: "normal", label: "]", shape: "normal", keycode: 27 },
                { keytype: "normal", label: "backspace", shape: "normal", keycode: 14, isIcon: true, width: 1.5 }
            ],
            [
                { keytype: "normal", label: "ABC", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone", width: 1.5 },
                { keytype: "normal", label: "<", shape: "normal", keycode: 51, isShiftedKey: true, width: 1.0 },
                { keytype: "normal", label: "dialpad", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone_Num", isIcon: true, width: 1.0 },
                { keytype: "normal", label: "Space", shape: "space", keycode: 57, width: 4.0 },
                { keytype: "normal", label: ">", shape: "normal", keycode: 52, isShiftedKey: true, width: 1.0 },
                { keytype: "normal", label: "keyboard_return", shape: "normal", keycode: 28, isIcon: true, width: 1.5 }
            ]
        ]
    },
    "Phone_Num": {
        name_short: "123",
        description: "Phone Number Pad",
        keys: [
            [
                { keytype: "normal", label: "1", shape: "normal", keycode: 2, width: 2.5 },
                { keytype: "normal", label: "2", shape: "normal", keycode: 3, width: 2.5 },
                { keytype: "normal", label: "3", shape: "normal", keycode: 4, width: 2.5 },
                { keytype: "normal", label: "-", shape: "normal", keycode: 12, width: 2.5 }
            ],
            [
                { keytype: "normal", label: "4", shape: "normal", keycode: 5, width: 2.5 },
                { keytype: "normal", label: "5", shape: "normal", keycode: 6, width: 2.5 },
                { keytype: "normal", label: "6", shape: "normal", keycode: 7, width: 2.5 },
                { keytype: "normal", label: "Space", shape: "space", keycode: 57, width: 2.5 }
            ],
            [
                { keytype: "normal", label: "7", shape: "normal", keycode: 8, width: 2.5 },
                { keytype: "normal", label: "8", shape: "normal", keycode: 9, width: 2.5 },
                { keytype: "normal", label: "9", shape: "normal", keycode: 10, width: 2.5 },
                { keytype: "normal", label: "backspace", shape: "normal", keycode: 14, isIcon: true, width: 2.5 }
            ],
            [
                { keytype: "normal", label: "ABC", shape: "normal", keycode: 0, isLayoutSwitch: true, switchTarget: "Phone", width: 2.5 },
                { keytype: "normal", label: ",", shape: "normal", keycode: 51, width: 2.5 },
                { keytype: "normal", label: "0", shape: "normal", keycode: 11, width: 2.5 },
                { keytype: "normal", label: "keyboard_return", shape: "normal", keycode: 28, isIcon: true, width: 2.5 }
            ]
        ]
    },
    "Phone_Emoji": {
        name_short: "Emoji",
        description: "Phone Emoji Picker",
        isCustom: true,
        customComponent: "OskEmojiPicker.qml",
        keys: [] // Ignored when isCustom is true
    },
    "Traditional": {
        name_short: "Traditional",
        description: "Full 104-Key Layout",
        isBlockBased: true,
        blocks: [
            {
                id: "main",
                width: 15,
                rows: [
                    [
                        { keytype: "normal", label: "Esc", shape: "normal", keycode: 1 },
                        { keytype: "spacer", width: 1.0 },
                        { keytype: "normal", label: "F1", shape: "normal", keycode: 59 }, { keytype: "normal", label: "F2", shape: "normal", keycode: 60 },
                        { keytype: "normal", label: "F3", shape: "normal", keycode: 61 }, { keytype: "normal", label: "F4", shape: "normal", keycode: 62 },
                        { keytype: "spacer", width: 0.5 },
                        { keytype: "normal", label: "F5", shape: "normal", keycode: 63 }, { keytype: "normal", label: "F6", shape: "normal", keycode: 64 },
                        { keytype: "normal", label: "F7", shape: "normal", keycode: 65 }, { keytype: "normal", label: "F8", shape: "normal", keycode: 66 },
                        { keytype: "spacer", width: 0.5 },
                        { keytype: "normal", label: "F9", shape: "normal", keycode: 67 }, { keytype: "normal", label: "F10", shape: "normal", keycode: 68 },
                        { keytype: "normal", label: "F11", shape: "normal", keycode: 87 }, { keytype: "normal", label: "F12", shape: "normal", keycode: 88 }
                    ],
                    [
                        { keytype: "normal", label: "`", labelShift: "~", shape: "normal", keycode: 41 },
                        { keytype: "normal", label: "1", labelShift: "!", keycode: 2 }, { keytype: "normal", label: "2", labelShift: "@", keycode: 3 },
                        { keytype: "normal", label: "3", labelShift: "#", keycode: 4 }, { keytype: "normal", label: "4", labelShift: "$", keycode: 5 },
                        { keytype: "normal", label: "5", labelShift: "%", keycode: 6 }, { keytype: "normal", label: "6", labelShift: "^", keycode: 7 },
                        { keytype: "normal", label: "7", labelShift: "&", keycode: 8 }, { keytype: "normal", label: "8", labelShift: "*", keycode: 9 },
                        { keytype: "normal", label: "9", labelShift: "(", keycode: 10 }, { keytype: "normal", label: "0", labelShift: ")", keycode: 11 },
                        { keytype: "normal", label: "-", labelShift: "_", keycode: 12 }, { keytype: "normal", label: "=", labelShift: "+", keycode: 13 },
                        { keytype: "normal", label: "backspace", width: 2, keycode: 14, isIcon: true }
                    ],
                    [
                        { keytype: "normal", label: "keyboard_tab", width: 1.5, keycode: 15, isIcon: true },
                        { keytype: "normal", label: "q", labelShift: "Q", keycode: 16 }, { keytype: "normal", label: "w", labelShift: "W", keycode: 17 },
                        { keytype: "normal", label: "e", labelShift: "E", keycode: 18 }, { keytype: "normal", label: "r", labelShift: "R", keycode: 19 },
                        { keytype: "normal", label: "t", labelShift: "T", keycode: 20 }, { keytype: "normal", label: "y", labelShift: "Y", keycode: 21 },
                        { keytype: "normal", label: "u", labelShift: "U", keycode: 22 }, { keytype: "normal", label: "i", labelShift: "I", keycode: 23 },
                        { keytype: "normal", label: "o", labelShift: "O", keycode: 24 }, { keytype: "normal", label: "p", labelShift: "P", keycode: 25 },
                        { keytype: "normal", label: "[", labelShift: "{", keycode: 26 }, { keytype: "normal", label: "]", labelShift: "}", keycode: 27 },
                        { keytype: "normal", label: "\\", labelShift: "|", width: 1.5, keycode: 43 }
                    ],
                    [
                        { keytype: "modkey", label: "keyboard_capslock", width: 1.75, keycode: 58, isIcon: true },
                        { keytype: "normal", label: "a", labelShift: "A", keycode: 30 }, { keytype: "normal", label: "s", labelShift: "S", keycode: 31 },
                        { keytype: "normal", label: "d", labelShift: "D", keycode: 32 }, { keytype: "normal", label: "f", labelShift: "F", keycode: 33 },
                        { keytype: "normal", label: "g", labelShift: "G", keycode: 34 }, { keytype: "normal", label: "h", labelShift: "H", keycode: 35 },
                        { keytype: "normal", label: "j", labelShift: "J", keycode: 36 }, { keytype: "normal", label: "k", labelShift: "K", keycode: 37 },
                        { keytype: "normal", label: "l", labelShift: "L", keycode: 38 }, { keytype: "normal", label: ";", labelShift: ":", keycode: 39 },
                        { keytype: "normal", label: "'", labelShift: "\"", keycode: 40 },
                        { keytype: "normal", label: "keyboard_return", width: 2.25, keycode: 28, isIcon: true }
                    ],
                    [
                        { keytype: "modkey", label: "keyboard_arrow_up", width: 2.25, keycode: 42, isIcon: true },
                        { keytype: "normal", label: "z", labelShift: "Z", keycode: 44 }, { keytype: "normal", label: "x", labelShift: "X", keycode: 45 },
                        { keytype: "normal", label: "c", labelShift: "C", keycode: 46 }, { keytype: "normal", label: "v", labelShift: "V", keycode: 47 },
                        { keytype: "normal", label: "b", labelShift: "B", keycode: 48 }, { keytype: "normal", label: "n", labelShift: "N", keycode: 49 },
                        { keytype: "normal", label: "m", labelShift: "M", keycode: 50 }, { keytype: "normal", label: ",", labelShift: "<", keycode: 51 },
                        { keytype: "normal", label: ".", labelShift: ">", keycode: 52 }, { keytype: "normal", label: "/", labelShift: "?", keycode: 53 },
                        { keytype: "modkey", label: "keyboard_arrow_up", width: 2.75, keycode: 54, isIcon: true }
                    ],
                    [
                        { keytype: "modkey", label: "Ctrl", width: 1.25, keycode: 29 },
                        { keytype: "modkey", label: "Super", width: 1.25, keycode: 125 },
                        { keytype: "modkey", label: "Alt", width: 1.25, keycode: 56 },
                        { keytype: "normal", label: "Space", width: 6.25, keycode: 57 },
                        { keytype: "modkey", label: "Alt", width: 1.25, keycode: 100 },
                        { keytype: "modkey", label: "Super", width: 1.25, keycode: 126 },
                        { keytype: "modkey", label: "menu", width: 1.25, keycode: 127, isIcon: true },
                        { keytype: "modkey", label: "Ctrl", width: 1.25, keycode: 97 }
                    ]
                ]
            },
            {
                id: "nav",
                width: 3,
                rows: [
                    [
                        { keytype: "normal", label: "PrtSc", keycode: 99 }, { keytype: "normal", label: "ScrLk", keycode: 70 }, { keytype: "normal", label: "Pause", keycode: 119 }
                    ],
                    [
                        { keytype: "normal", label: "Ins", keycode: 110 }, { keytype: "normal", label: "Home", keycode: 102 }, { keytype: "normal", label: "PgUp", keycode: 104 }
                    ],
                    [
                        { keytype: "normal", label: "Del", keycode: 111 }, { keytype: "normal", label: "End", keycode: 107 }, { keytype: "normal", label: "PgDn", keycode: 109 }
                    ],
                    [ { keytype: "spacer", height: 1 } ],
                    [
                        { keytype: "spacer", width: 1 }, { keytype: "normal", label: "\ue316", keycode: 103, isIcon: true }, { keytype: "spacer", width: 1 }
                    ],
                    [
                        { keytype: "normal", label: "\ue314", keycode: 105, isIcon: true }, { keytype: "normal", label: "\ue313", keycode: 108, isIcon: true }, { keytype: "normal", label: "\ue315", keycode: 106, isIcon: true }
                    ]
                ]
            },
            {
                id: "num",
                width: 4,
                isGrid: true,
                keys: [
                    { label: "NumLk", keycode: 69, x: 0, y: 1 }, { label: "/", keycode: 98, x: 1, y: 1 }, { label: "*", keycode: 55, x: 2, y: 1 }, { label: "-", keycode: 74, x: 3, y: 1 },
                    { label: "7", keycode: 71, x: 0, y: 2 }, { label: "8", keycode: 72, x: 1, y: 2 }, { label: "9", keycode: 73, x: 2, y: 2 }, { label: "+", keycode: 78, x: 3, y: 2, height: 2 },
                    { label: "4", keycode: 75, x: 0, y: 3 }, { label: "5", keycode: 76, x: 1, y: 3 }, { label: "6", keycode: 77, x: 2, y: 3 },
                    { label: "1", keycode: 79, x: 0, y: 4 }, { label: "2", keycode: 80, x: 1, y: 4 }, { label: "3", keycode: 81, x: 2, y: 4 }, { label: "keyboard_return", keycode: 96, x: 3, y: 4, height: 2, isIcon: true },
                    { label: "0", keycode: 82, x: 0, y: 5, width: 2 }, { label: ".", keycode: 83, x: 2, y: 5 }
                ]
            }
        ]
    }
};
