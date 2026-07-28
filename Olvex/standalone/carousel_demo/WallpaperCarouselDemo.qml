import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: window
    width: 1024
    height: 720
    visible: true
    title: "Material 3 Expressive Carousel - Wallpaper Selector Demo"
    color: "#141218" // M3 Dark Neutral Background

    // Mock/Real Wallpaper Dataset
    property var wallpapers: [
        { name: "Beach Sunset", path: "/home/abm/Pictures/Wallpapers/Beach-Dark.png", category: "Nature" },
        { name: "City Skyline", path: "/home/abm/Pictures/Wallpapers/City_dark.png", category: "Urban" },
        { name: "Desert Dunes", path: "/home/abm/Pictures/Wallpapers/Dessert-Dark.png", category: "Abstract" },
        { name: "Forest Mist", path: "/home/abm/Pictures/Wallpapers/Forest-Dark.png", category: "Nature" },
        { name: "Mount Fuji", path: "/home/abm/Pictures/Wallpapers/Fuji-Dark.png", category: "Landscape" },
        { name: "Botanical Garden", path: "/home/abm/Pictures/Wallpapers/Garden-Dark.png", category: "Flora" },
        { name: "Night Lady", path: "/home/abm/Pictures/Wallpapers/Lady-Dark.png", category: "Minimal" },
        { name: "Mountain Peak", path: "/home/abm/Pictures/Wallpapers/Mountain_dark.png", category: "Landscape" },
        { name: "Riverside Night", path: "/home/abm/Pictures/Wallpapers/Riverside-Dark.png", category: "Nature" },
        { name: "Summer Scene", path: "/home/abm/Pictures/Wallpapers/Summer-Scene-Dark.png", category: "Art" },
        { name: "Japan Street", path: "/home/abm/Pictures/Wallpapers/japan-street-Dark.png", category: "Urban" }
    ]

    property var selectedWallpaper: wallpapers[0]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // ---- Header Title & Subtitle ----
        ColumnLayout {
            spacing: 4
            Text {
                text: "Material 3 Carousel - Wallpaper Selector"
                font.pixelSize: 28
                font.bold: true
                color: "#E6E0E9"
            }
            Text {
                text: "Keyline continuous sizing algorithm with parallax decay & M3 Expressive motion"
                font.pixelSize: 14
                color: "#CAC4D0"
            }
        }

        // ---- Layout Selector Tabs ----
        Row {
            spacing: 12

            function setMode(mode) {
                carousel.layout = mode
            }

            Button {
                text: "Multi-Browse"
                highlighted: carousel.layout === "multiBrowse"
                onClicked: parent.setMode("multiBrowse")
            }
            Button {
                text: "Hero (Start)"
                highlighted: carousel.layout === "heroStart"
                onClicked: parent.setMode("heroStart")
            }
            Button {
                text: "Hero (Center)"
                highlighted: carousel.layout === "heroCenter"
                onClicked: parent.setMode("heroCenter")
            }
            Button {
                text: "Uncontained"
                highlighted: carousel.layout === "uncontained"
                onClicked: parent.setMode("uncontained")
            }
        }

        // ---- M3 Keyline Carousel Component ----
        M3Carousel {
            id: carousel
            Layout.fillWidth: true
            itemHeight: 260
            largeSize: 320
            mediumSize: 180
            smallSize: 64
            model: window.wallpapers
            layout: "heroCenter"

            onItemClicked: function(index, itemData) {
                window.selectedWallpaper = itemData
            }

            delegate: Item {
                id: delegateRoot
                property var modelData
                property int index
                property real parallaxOffset: 0
                property bool isCurrent: false

                Image {
                    id: img
                    anchors.fill: parent
                    anchors.margins: -parallaxOffset * 0.4
                    source: delegateRoot.modelData ? ("file://" + delegateRoot.modelData.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    // Fallback gradient if file missing
                    Rectangle {
                        anchors.fill: parent
                        visible: img.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#4A4458" }
                            GradientStop { position: 1.0; color: "#1D1B20" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: delegateRoot.modelData ? delegateRoot.modelData.name : ""
                            color: "#E6E0E9"
                            font.bold: true
                        }
                    }
                }

                // Overlay Text Label on Focal Card
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 50
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: "#D0000000" }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.centerYIn: parent
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        text: delegateRoot.modelData ? delegateRoot.modelData.name : ""
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ---- Selected Wallpaper Details Preview Card ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 20
            color: "#211F26"
            border.color: "#49454F"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 20

                // Preview Thumbnail
                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    radius: 12
                    color: "#1D1B20"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: window.selectedWallpaper ? ("file://" + window.selectedWallpaper.path) : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                // Details Text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "ACTIVE WALLPAPER PREVIEW"
                        font.pixelSize: 11
                        font.bold: true
                        color: "#D0BCFF"
                    }

                    Text {
                        text: window.selectedWallpaper ? window.selectedWallpaper.name : "None Selected"
                        font.pixelSize: 22
                        font.bold: true
                        color: "#E6E0E9"
                    }

                    Text {
                        text: window.selectedWallpaper ? window.selectedWallpaper.path : ""
                        font.pixelSize: 12
                        color: "#938F99"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    Button {
                        text: "Apply Wallpaper"
                        onClicked: console.log("Applied wallpaper: " + window.selectedWallpaper.path)
                    }
                }
            }
        }
    }
}
