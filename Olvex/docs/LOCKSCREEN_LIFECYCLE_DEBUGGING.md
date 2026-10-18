# Wayland Session Lock & Window Lifecycle Guide

## 1. Overview & Problem Statement
In Quickshell under Wayland (Hyprland), unlocking the lockscreen (`WlSessionLock`) can crash with `SIGSEGV` in `QQuickItemPrivate::dirty()` / `QQuickWindowPrivate::syncSceneGraph()` preceded by:
```
WARN: QQuickItem: Cannot use same item on different windows at the same time.
```

This document details the root cause, crash mechanics, and rules to prevent this issue.

---

## 2. Crash Mechanics & Root Cause

### A. Wayland Layer-Shell vs Session-Lock Lifecycles
- `WlSessionLock` implements Wayland `ext_session_lock_v1`.
- Per Wayland specification, when `ext_session_lock_v1` is active, the compositor **exclusively obscures and blocks input to all desktop layer-shell surfaces** (Background, Bottom, Top, Overlay).
- Therefore, shell windows (`ContentWindow`, `Background`) **do not need to be unmapped or hidden**.

### B. The Unmap/Map Pitfall (`visible: !LockState.locked`)
- Setting `visible: false` on a Quickshell `PanelWindow` or `StyledWindow` forces Quickshell to **destroy the Wayland `zwlr_layer_surface_v1`**.
- Setting `visible: true` forces Quickshell to **create a new `zwlr_layer_surface_v1`**.
- If `ContentWindow` is unmapped on lock and re-mapped on unlock, items inside it (such as `MouseArea`, `CustomMouseArea`, overlays) get re-associated while `WlSessionLockSurface` is simultaneously being destroyed.

### C. Dangling Window Pointer in `dirty()`
1. In Qt Quick, `QQuickItemPrivate::refWindow(QQuickWindow *c)` throws `WARN: QQuickItem: Cannot use same item on different windows at the same time.` if `window != null && window != c` and **aborts without updating `this->window`**.
2. Items in `ContentWindow` keep their internal `window` pointer pointing to the lock window (`WlSessionLockSurface`).
3. On unlock, compositor destroys `WlSessionLockSurface` and frees its memory.
4. `ContentWindow.syncSceneGraph()` triggers `dirtyAll()` on all items in the window tree.
5. In `QQuickItemPrivate::dirty()`, Qt executes:
   ```cpp
   if (window)
       window->d_func()->dirtyItem(q_ptr);
   ```
   Because `window` points to the destroyed lock window's freed memory, dereferencing `window->d_func()` causes an immediate `SIGSEGV` (Segmentation fault).

### D. Global `Overlay.overlay` Trap
- In `Tooltip.qml` or popups, using `parent: Overlay.overlay` attaches the popup to whichever window currently owns the global overlay (frequently the lock window if launched locked).
- When a tooltip is instantiated inside another window (`ContentWindow`), cross-window parenting fails and corrupts the dirty item list.

---

## 3. Mandatory Development Rules

### Rule 1: Never Unmap Layer-Shell Windows on Lock
- **DO NOT** bind `visible: !LockState.locked` on root windows (`ContentWindow.qml`, `Background.qml`).
- **DO** keep windows continuously mapped. Use container opacity (e.g. `revealContainer.opacity: isVisible ? 1 : 0`) to handle smooth visual fade transitions.

```qml
// BAD - Unmaps and destroys Wayland surface on lock
PanelWindow {
    visible: !LockState.locked
}

// GOOD - Window stays mapped; visual contents fade cleanly
PanelWindow {
    Item {
        id: container
        opacity: !LockState.locked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
}
```

### Rule 2: Never Unload Desktop Background on Lock
- **DO NOT** add `&& !LockState.locked` to `Loader.active` in `Background.qml`.
- Keeping wallpaper and clock resident preserves GPU texture caches and eliminates shader re-compilation / texture reload overhead upon unlocking.

```qml
// BAD
Loader {
    active: Config.background.wallpaperEnabled && !LockState.locked
}

// GOOD
Loader {
    active: Config.background.wallpaperEnabled
}
```

### Rule 3: Always Use Window-Local Parent for Popups & Tooltips
- **DO NOT** use `parent: Overlay.overlay` in custom components or controls.
- **DO** resolve `parent` to the target item's window `contentItem` or `interactionWrapper`:

```qml
// Tooltip / Popup overlay parent resolution
readonly property Item overlayParent: {
    let win = root.target ? root.target.Window.window : root.Window.window;
    if (win) {
        if (win.interactionWrapper)
            return win.interactionWrapper;
        if (win.contentItem)
            return win.contentItem;
        return win;
    }
    let p = root.target || root;
    while (p && p.parent)
        p = p.parent;
    return p;
}

parent: overlayParent
```

### Rule 4: Clean Unlock Order in `LockSurface`
- Always notify the compositor to unlock (`root.lock.locked = false`) before clearing shell state (`LockState.locked = false`).

```qml
ScriptAction {
    script: {
        root.lock.locked = false;
        LockState.locked = false;
        LockState.unlocking = false;
    }
}
```
