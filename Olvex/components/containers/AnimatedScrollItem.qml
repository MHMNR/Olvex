
import QtQuick
import qs.components

// AnimatedList AnimatedItem shell (React Bits / motion useInView port).
// Wrap list-row content; fade+scale when ≥ 50% of the row is in the viewport.
Item {
    id: root

    // Usually the ListView / Flickable that owns this row
    property Flickable view: {
        let p = parent;
        while (p) {
            if (p instanceof Flickable)
                return p;
            p = p.parent;
        }
        return null;
    }

    // useInView({ amount: 0.5 })
    property real visibleAmount: 0.5
    property int animDuration: 200
    property real hiddenScale: 0.7

    // Optional: force always-visible (e.g. empty state host)
    property bool forceVisible: false

    readonly property bool inView: {
        if (forceVisible)
            return true;
        const v = root.view;
        if (!v)
            return true;
        // Depend on scroll / size
        const _y = v.contentY;
        const _h = v.height;
        // Map row into content coordinates
        const row = parent;
        if (!row)
            return true;
        const top = row.y;
        const bottom = top + (row.height > 0 ? row.height : root.height);
        const vTop = v.contentY;
        const vBot = v.contentY + v.height;
        const overlap = Math.min(bottom, vBot) - Math.max(top, vTop);
        const h = Math.max(1, bottom - top);
        return overlap >= h * root.visibleAmount;
    }

    // Default size follows content
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    default property alias contentData: content.data

    opacity: inView ? 1 : 0
    scale: inView ? 1 : hiddenScale
    transformOrigin: Item.Center

    Behavior on opacity {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: content
        anchors.fill: parent
    }
}
