pragma Singleton

import QtQuick
import Quickshell
import Olvex.Config
import Olvex.Services

Singleton {
    id: root

    // Lock states: local property for zero-lag OSK visual feedback.
    // Initialized from system, synced bidirectionally:
    //   OSK press  → flip locally + send ydotool → Hyprland confirms (same value, no fight)
    //   Physical KB → onCapsLockChanged syncs local to system truth
    property bool capsMode: false
    property bool numMode: false
    property bool autoCapitalizeEnabled: props.autoCapitalizeEnabled
    property string activeLayout: "Default"

    PersistentProperties {
        id: props
        property bool autoCapitalizeEnabled: true
        reloadableId: "ydotool"
    }

    Component.onCompleted: {
        capsMode = Hypr.capsLock;
        numMode  = Hypr.numLock;
    }

    // Physical keyboard changed lock state → sync local to system truth
    Connections {
        target: Hypr
        function onCapsLockChanged() { root.capsMode = Hypr.capsLock; }
        function onNumLockChanged()  { root.numMode  = Hypr.numLock;  }
    }

    // Delayed refresh: ydotool virtual keys don't trigger Hyprland keybinds,
    // so refreshDevices() is never called for OSK-initiated toggles.
    // This timer bridges that gap — 150ms lets ydotool finish before we query.
    Timer {
        id: lockSyncTimer
        interval: 150
        onTriggered: Hypr.extras.refreshDevices()
    }
    
    property bool _ydotoolAvailable: true
    property var _pressTimes: ({})
    
    property bool _anyKeyUsedWithMod: false 
    property var _modsSentDown: [] 

    // 3-state modifier system
    property var latchedModifiers: []
    property var lockedModifiers: []
    property var activePhysicalMods: []
    
    readonly property bool isShiftActive: _isModActive(42) || _isModActive(54)
    readonly property bool isCtrlActive:  _isModActive(29) || _isModActive(97)
    readonly property bool isAltActive:   _isModActive(56) || _isModActive(100)
    readonly property bool isSuperActive: _isModActive(125) || _isModActive(126)

    function _isModActive(kc) {
        return isLatched(kc) || 
               isLocked(kc) || 
               activePhysicalMods.indexOf(kc) !== -1;
    }

    function isLatched(kc) { return latchedModifiers.indexOf(kc) !== -1; }
    function isLocked(kc) { return lockedModifiers.indexOf(kc) !== -1; }

    function _unique(values) {
        const unique = [];
        for (let i = 0; i < values.length; i++) {
            if (unique.indexOf(values[i]) === -1)
                unique.push(values[i]);
        }
        return unique;
    }

    function _getPair(keycode) {
        switch(keycode) {
            case 42: return 54; case 54: return 42;
            case 29: return 97; case 97: return 29;
            case 56: return 100; case 100: return 56;
            case 125: return 126; case 126: return 125;
            default: return 0;
        }
    }

    function _ydotoolKey(parts) {
        if (!root._ydotoolAvailable || parts.length === 0) return;
        console.log(`[Ydotool] exec: ydotool key ${parts.join(" ")}`);
        Quickshell.execDetached(["ydotool", "key"].concat(parts));
    }

    function isModKey(kc) {
        return [42, 54, 29, 97, 56, 100, 125, 126].indexOf(kc) !== -1;
    }

    function isSuperKey(kc) { return kc === 125 || kc === 126; }
    function isCapsKey(kc) { return kc === 58; }
    function isNumKey(kc) { return kc === 69; }

    function keycodeToMod(kc) {
        if (kc === 42 || kc === 54) return "shift";
        if (kc === 29 || kc === 97) return "ctrl";
        if (kc === 56 || kc === 100) return "alt";
        if (kc === 125 || kc === 126) return "win";
        return null;
    }

    function press(keycode) {
        _pressTimes[keycode] = Date.now();

        if (isCapsKey(keycode)) {
            root.capsMode = !root.capsMode;  // Instant visual flip
            _ydotoolKey(["58:1", "58:0"]);
            lockSyncTimer.restart();          // Delayed system sync
            return;
        }

        if (isNumKey(keycode)) {
            root.numMode = !root.numMode;     // Instant visual flip
            _ydotoolKey(["69:1", "69:0"]);
            lockSyncTimer.restart();          // Delayed system sync
            return;
        }

        if (isModKey(keycode)) {
            if (activePhysicalMods.indexOf(keycode) === -1) {
                let m = activePhysicalMods.slice(); m.push(keycode);
                activePhysicalMods = m;
                _anyKeyUsedWithMod = false; 
            }
            return;
        }

        // Letter Press
        if (root._ydotoolAvailable) {
            const allActiveMods = _unique(latchedModifiers.concat(lockedModifiers).concat(activePhysicalMods));
            const sequence = [];
            const typesSeen = [];
            
            for (let i = 0; i < allActiveMods.length; i++) {
                const type = keycodeToMod(allActiveMods[i]);
                if (type && typesSeen.indexOf(type) === -1) {
                    typesSeen.push(type);
                    sequence.push(`${allActiveMods[i]}:1`);
                    if (_modsSentDown.indexOf(allActiveMods[i]) === -1) {
                        let sd = _modsSentDown.slice(); sd.push(allActiveMods[i]);
                        _modsSentDown = sd;
                    }
                    _anyKeyUsedWithMod = true;
                }
            }
            
            sequence.push(`${keycode}:1`);
            _ydotoolKey(sequence);
        }
    }

    function release(keycode) {
        const duration = Date.now() - (_pressTimes[keycode] || 0);
        const isLongPress = duration > 350;
        
        let physIdx = activePhysicalMods.indexOf(keycode);
        if (physIdx !== -1) {
            let m = activePhysicalMods.slice(); m.splice(physIdx, 1);
            activePhysicalMods = m;
        }

        if (isModKey(keycode)) {
            let latchedIdx = latchedModifiers.indexOf(keycode);
            let lockedIdx = lockedModifiers.indexOf(keycode);

            if (lockedIdx !== -1) {
                let l = lockedModifiers.slice(); 
                l.splice(l.indexOf(keycode), 1);
                let pair = _getPair(keycode);
                if (pair > 0 && l.indexOf(pair) !== -1) l.splice(l.indexOf(pair), 1);
                lockedModifiers = l;
                _ydotoolKey([`${keycode}:0`]);
                let sd = _modsSentDown.slice();
                if (sd.indexOf(keycode) !== -1) sd.splice(sd.indexOf(keycode), 1);
                _modsSentDown = sd;
                return;
            }

            if (!_anyKeyUsedWithMod) {
                if (isLongPress) {
                    if (isSuperKey(keycode)) {
                        // Super Long Press: LATCH (Sticky for 1 keypress)
                        let m = latchedModifiers.slice(); 
                        if (m.indexOf(keycode) === -1) m.push(keycode);
                        let pair = _getPair(keycode);
                        if (pair > 0 && m.indexOf(pair) === -1) m.push(pair);
                        latchedModifiers = m;
                    } else {
                        // Other Mod Long Press: LOCK (Persistent)
                        let l = lockedModifiers.slice(); 
                        if (l.indexOf(keycode) === -1) l.push(keycode);
                        let pair = _getPair(keycode);
                        if (pair > 0 && l.indexOf(pair) === -1) l.push(pair);
                        lockedModifiers = l;
                    }
                } else if (latchedIdx === -1 && lockedIdx === -1) {
                    if (isSuperKey(keycode)) {
                        // Super Short Tap: PHYSICAL TAP (Single press, triggers menu)
                        _ydotoolKey([`${keycode}:1`, `${keycode}:0`]);
                    } else {
                        // Other Mod Short Tap: LATCH (Sticky for 1 keypress)
                        let m = latchedModifiers.slice(); 
                        if (m.indexOf(keycode) === -1) m.push(keycode);
                        let pair = _getPair(keycode);
                        if (pair > 0 && m.indexOf(pair) === -1) m.push(pair);
                        latchedModifiers = m;
                    }
                } else {
                    // Second tap: UNLOCK/UNLATCH
                    if (lockedIdx !== -1) {
                        let l = lockedModifiers.slice(); 
                        l.splice(l.indexOf(keycode), 1);
                        let pair = _getPair(keycode);
                        if (pair > 0 && l.indexOf(pair) !== -1) l.splice(l.indexOf(pair), 1);
                        lockedModifiers = l;
                    }
                    if (latchedIdx !== -1) {
                        let m = latchedModifiers.slice(); 
                        m.splice(m.indexOf(keycode), 1);
                        let pair = _getPair(keycode);
                        if (pair > 0 && m.indexOf(pair) !== -1) m.splice(m.indexOf(pair), 1);
                        latchedModifiers = m;
                    }
                    _ydotoolKey([`${keycode}:0`]);
                    let sd = _modsSentDown.slice();
                    if (sd.indexOf(keycode) !== -1) sd.splice(sd.indexOf(keycode), 1);
                    _modsSentDown = sd;
                }
            } else {
                if (_modsSentDown.indexOf(keycode) !== -1) {
                    _ydotoolKey([`${keycode}:0`]);
                    let sd = _modsSentDown.slice();
                    sd.splice(sd.indexOf(keycode), 1);
                    _modsSentDown = sd;
                }
            }
            return;
        }

        // Letter Release (NON-MODIFIER)
        if (root._ydotoolAvailable) {
            const sequence = [];
            
            // ATOMIC COMBO BREAKING:
            // Release modifiers BEFORE the letter. 
            // This is the physical "Key Roll-over" order that is most 
            // likely to be interpreted as a combo by the compositor.
            if (latchedModifiers.length > 0) {
                for (let i = 0; i < latchedModifiers.length; i++) {
                    if (_modsSentDown.indexOf(latchedModifiers[i]) !== -1) {
                        // WAYLAND SHIFT-BREAK: Inject a tiny Shift tap during modifier release 
                        // to prevent standalone-tap triggers (like the launcher).
                        if (isSuperKey(latchedModifiers[i])) {
                            _ydotoolKey(["42:1", "42:0"]);
                        }
                        sequence.push(`${latchedModifiers[i]}:0`);
                        let sd = _modsSentDown.slice();
                        sd.splice(sd.indexOf(latchedModifiers[i]), 1);
                        _modsSentDown = sd;
                    }
                }
                latchedModifiers = [];
            }
            
            sequence.push(`${keycode}:0`);
            _ydotoolKey(sequence);
        }
    }

    function consumeLatches() {
        if (latchedModifiers.length > 0) {
            const sequence = [];
            for (let i = 0; i < latchedModifiers.length; i++) {
                if (_modsSentDown.indexOf(latchedModifiers[i]) !== -1) {
                    sequence.push(`${latchedModifiers[i]}:0`);
                    let sd = _modsSentDown.slice();
                    sd.splice(sd.indexOf(latchedModifiers[i]), 1);
                    _modsSentDown = sd;
                }
            }
            if (sequence.length > 0) _ydotoolKey(sequence);
            latchedModifiers = [];
        }
    }

    function resetModifiers() {
        const sequence = [];
        for (let i = 0; i < _modsSentDown.length; i++) {
            sequence.push(`${_modsSentDown[i]}:0`);
        }
        if (sequence.length > 0) _ydotoolKey(sequence);
        
        latchedModifiers = [];
        lockedModifiers = [];
        activePhysicalMods = [];
        _modsSentDown = [];
        _anyKeyUsedWithMod = false;
    }

    function typeString(text) {
        if (!text || text.length === 0) return;
        Quickshell.execDetached(["wtype", text]);
        consumeLatches();
    }
}
