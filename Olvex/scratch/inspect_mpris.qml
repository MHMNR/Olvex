import QtQuick
import Quickshell
import Quickshell.Services.Mpris

ShellRoot {
    Timer {
        interval: 2000
        running: true
        onTriggered: {
            const players = Mpris.players.values;
            console.log("PLAYERS_COUNT: " + players.length);
            for (let i = 0; i < players.length; i++) {
                const p = players[i];
                console.log("PLAYER_" + i + "_IDENTITY: " + p.identity);
                console.log("PLAYER_" + i + "_DESKTOP: " + p.desktopEntry);
            }
            Qt.quit();
        }
    }
}
