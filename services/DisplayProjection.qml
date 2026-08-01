pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex.Config

Singleton {
    id: root

    property string activeProjection: props.activeProjection || "expand"

    Process {
        id: cmdProc
    }

    function applyProjection(mode) {
        activeProjection = mode;
        props.activeProjection = mode;
        
        const script = `
primary=$(hyprctl monitors all -j | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -n1)
if [ -z "$primary" ]; then
    primary=$(hyprctl monitors all -j | jq -r '.[0].name')
fi
secondary=$(hyprctl monitors all -j | jq -r --arg prim "$primary" '.[] | select(.name != $prim) | .name' | head -n1)

if [ "${mode}" = "primary" ]; then
    hyprctl keyword monitor "$primary",preferred,auto,1
    if [ -n "$secondary" ]; then
        hyprctl keyword monitor "$secondary",disable
    fi
elif [ "${mode}" = "secondary" ]; then
    if [ -n "$secondary" ]; then
        hyprctl keyword monitor "$secondary",preferred,auto,1
        hyprctl keyword monitor "$primary",disable
    else
        hyprctl keyword monitor "$primary",preferred,auto,1
    fi
elif [ "${mode}" = "expand" ]; then
    hyprctl keyword monitor "$primary",preferred,auto,1
    if [ -n "$secondary" ]; then
        hyprctl keyword monitor "$secondary",preferred,auto-right,1
    fi
elif [ "${mode}" = "mirror" ]; then
    hyprctl keyword monitor "$primary",preferred,auto,1
    if [ -n "$secondary" ]; then
        hyprctl keyword monitor "$secondary",preferred,auto,1,mirror,"$primary"
    fi
fi
`;
        cmdProc.command = ["bash", "-c", script];
        cmdProc.running = true;
    }

    PersistentProperties {
        id: props
        property string activeProjection
        reloadableId: "displayProjection"
    }
}
