import QtQuick
import Olvex.Config
import qs.components
import qs.utils

MaterialIcon {
    id: root

    property string iconName

    readonly property string packLigature: Icons.getPackLigature(iconName, GlobalConfig.appearance.iconPack)
    readonly property string activePack: GlobalConfig.appearance.iconPack

    text: (packLigature && activePack !== "None") ? packLigature : iconName
    font.family: (packLigature && activePack !== "None") ? "StatusbarIcons " + activePack : Tokens.font.family.material
}
