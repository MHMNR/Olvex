import QtQuick
import QtQuick.Layouts
import Quickshell
import Olvex
import Olvex.Config
import qs.components
import qs.services

Item {
    id: root

    required property var list
    required property int index
    property var visibilities: null
    readonly property bool isCurrent: list ? list.currentIndex === index : false
    readonly property string math: {
        const text = (list && list.search && list.search.text) ? list.search.text.trim() : "";
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (prefix && text.startsWith(`${prefix}calc `))
            return text.slice(`${prefix}calc `.length).trim();
        if (text.startsWith("calc "))
            return text.slice(5).trim();
        if (text.startsWith("="))
            return text.slice(1).trim();
        return text;
    }

    function closeLauncher() {
        if (visibilities)
            visibilities.launcher = false;
        else if (list && list.visibilities)
            list.visibilities.launcher = false;
    }

    function onClicked() {
        if (Qalculator.rawResult)
            Quickshell.execDetached(["wl-copy", Qalculator.rawResult]);
        else if (Qalculator.result)
            Quickshell.execDetached(["wl-copy", Qalculator.result]);
        closeLauncher();
    }

    onMathChanged: {
        if (math.length > 0)
            Qalculator.evalAsync(math);
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent ? parent.left : undefined
    anchors.right: parent ? parent.right : undefined

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: root.onClicked()
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.larger

        spacing: Tokens.spacing.normal

        MaterialIcon {
            text: "function"
            Layout.alignment: Qt.AlignVCenter
            color: isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            id: result

            color: {
                if (text.includes("error: ") || text.includes("warning: "))
                    return Colours.palette.m3error;
                if (!root.math)
                    return isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant;
                return isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface;
            }

            text: root.math.length > 0 ? (Qalculator.result || qsTr("Calculating...")) : qsTr("Type an expression to calculate")
            elide: Text.ElideLeft
            font.weight: isCurrent ? Font.DemiBold : Font.Normal

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledRect {
            color: Colours.palette.m3tertiary
            radius: Tokens.rounding.normal
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Tokens.padding.normal * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Tokens.padding.small * 2

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                id: stateLayer

                onClicked: {
                    Quickshell.execDetached(["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, "qalc", "-i", root.math]);
                    root.closeLauncher();
                }

                color: Colours.palette.m3onTertiary
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Tokens.spacing.small

                text: qsTr("Open in calculator")
                color: Colours.palette.m3onTertiary
                textPointSize: Tokens.font.size.normal

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.normal

                text: "open_in_new"
                color: Colours.palette.m3onTertiary
                iconPointSize: Tokens.font.size.large
            }

            Behavior on implicitWidth {
                Anim {
                    type: Anim.Emphasized
                }
            }
        }
    }
}
