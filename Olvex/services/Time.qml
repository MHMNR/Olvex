pragma Singleton

import QtQuick
import Quickshell
import Olvex.Config

Singleton {
    id: root

    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    readonly property string timeStr: format(GlobalConfig.services.useTwelveHourClock ? "hh:mm:A" : "hh:mm")
    readonly property var timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents && timeComponents[0] !== undefined ? timeComponents[0] : ""
    readonly property string minuteStr: timeComponents && timeComponents[1] !== undefined ? timeComponents[1] : ""
    readonly property string amPmStr: timeComponents && timeComponents[2] !== undefined ? timeComponents[2] : ""

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    property int secondsRefCount: 0

    SystemClock {
        id: clock

        precision: root.secondsRefCount > 0 ? SystemClock.Seconds : SystemClock.Minutes
    }
}
