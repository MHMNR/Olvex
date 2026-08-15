#!/usr/bin/env bash

# Collect visible window boxes for slurp hover selection
get_window_boxes() {
    local focused_mon
    focused_mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused)')
    
    local special_id
    special_id=$(echo "$focused_mon" | jq -r '.specialWorkspace.id // 0')
    
    local ws_id
    if [ "$special_id" != "0" ] && [ -n "$special_id" ]; then
        ws_id="$special_id"
    else
        ws_id=$(echo "$focused_mon" | jq -r '.activeWorkspace.id')
    fi

    # Output window coordinates and dimensions for slurp candidate boxes
    hyprctl clients -j | jq -r --argjson ws "$ws_id" \
        '.[] | select(.workspace.id == $ws and .mapped and (.hidden | not)) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.title // .class)"'
}

# Run slurp with candidates:
# - Hovering a window highlights/snaps to it (click to select)
# - Clicking and dragging anywhere creates a custom rectangular selection
GEOMETRY=$(get_window_boxes | slurp -d -b 00000066 -c a2cde2ff -s 00000000 -B 00000033 -w 2)

if [ -n "$GEOMETRY" ]; then
    grim -g "$GEOMETRY" - | swappy -f -
fi
