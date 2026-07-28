# Clipboard Standalone Technical Report

Date: 2026-06-07

## Scope
- Standalone clipboard UI in `standalone/clipboard/ClipboardStandalone.qml`
- Backend in `standalone/clipboard/main.cpp`
- Source data from `cliphist list`

## Current Behavior
- Loads clipboard entries from `cliphist list` on startup and refresh.
- Renders text items as compact rows.
- Renders image items with decoded thumbnails from `/tmp/olvex-clip/<id>.png`.
- Preserves original `cliphist` index values from the first column.
- Supports keyboard navigation:
  - Up / Down: move selection
  - PageUp / PageDown: jump selection
  - Enter / Copy: copy selected item
  - Delete: remove selected item
  - Escape / Close: close app or clear search

## Recent UI Adjustments
- Removed duplicate raw text line under copied text rows.
- Removed thumbnail label overlay for image rows.
- Reduced text card thickness.
- Increased image row thumbnail size and image card thickness.
- Adjusted footer action badges to be more symmetric.
- Reduced search icon visual weight.
- Added gentler wheel scrolling.

## Data Notes
- The list is deduped by visible text content before rendering.
- Image entries are detected through the backend `entryIsImage()` check.
- Image decoding happens through backend `decodeImageTo()`.

## Verification
- Standalone target rebuilds cleanly with `cmake --build build --target olvex-clipboard -j4`.
- Runtime validation should be performed via the standalone launch path and an offscreen smoke test.
