import QtQuick
import qs.components
import qs.services

// Progress dots: active dot stretches into a pill.
Row {
    id: root

    property int count: 0
    property int current: 0

    spacing: 6

    Repeater {
        model: root.count

        delegate: StyledRect {
            required property int index
            readonly property bool active: index === root.current

            height: 8
            width: active ? 24 : 8
            radius: 4
            color: {
                if (active)
                    return Colours.light ? Colours.palette.m3primary : Colours.palette.m3onSurface;
                if (index < root.current)
                    return Qt.alpha(Colours.palette.m3onSurface, Colours.light ? 0.55 : 0.65);
                return Qt.alpha(Colours.palette.m3onSurface, Colours.light ? 0.28 : 0.35);
            }

            Behavior on color {
                CAnim {}
            }

            Behavior on width {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }
}

