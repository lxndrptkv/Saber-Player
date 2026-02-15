import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // Smooth dynamic resizing
    width: isExpanded ? 240 : 64
    color: rootWindow.bgSidebar
    clip: true // Prevents text from spilling out during the animation

    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

    property var settings
    property int currentTab: 0
    property bool isExpanded: hoverHandler.hovered

    signal tabClicked(int index)
    signal openSettings()

    // Detects mouse hover over the entire sidebar
    HoverHandler { id: hoverHandler }

    Rectangle {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        width: 1; color: rootWindow.borderCol
    }

    ListModel {
        id: navModel
        ListElement { name: "Now Playing"; iconText: "🎵" }
        ListElement { name: "Music Library"; iconText: "📁" }
        ListElement { name: "Playlists"; iconText: "📋" }
        ListElement { name: "Audio CD"; iconText: "💿" }
    }

    // Logo Area
    Item {
        id: logoArea
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width; height: 70

        Text {
            x: 22; anchors.verticalCenter: parent.verticalCenter
            text: "⚔️"; font.pixelSize: 20
        }
        Text {
            x: 55; anchors.verticalCenter: parent.verticalCenter
            text: "SaberPlayer"; color: settings.accentColor; font.pixelSize: 18; font.bold: true
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // Navigation Links
    Column {
        anchors.top: logoArea.bottom; anchors.left: parent.left; anchors.right: parent.right
        spacing: 8

        Repeater {
            model: navModel
            delegate: Button {
                width: root.width - 20
                x: 10 // Centers the button in the 64px collapsed state
                height: 44

                background: Rectangle {
                    radius: 6
                    color: root.currentTab === index ? settings.accentColor : (parent.hovered ? rootWindow.borderCol : "transparent")
                    opacity: root.currentTab === index ? 1.0 : 0.8
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                contentItem: Item {
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: iconText; color: root.currentTab === index ? "white" : rootWindow.textMain; font.pixelSize: 16
                    }
                    Text {
                        x: 45; anchors.verticalCenter: parent.verticalCenter
                        text: name; color: root.currentTab === index ? "white" : rootWindow.textMain; font.pixelSize: 14; font.bold: root.currentTab === index
                        opacity: root.isExpanded ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                onClicked: root.tabClicked(index)
            }
        }
    }

    // Settings Button (Pinned to bottom)
    Button {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 15
        width: root.width - 20
        x: 10
        height: 44
        background: Rectangle {
            radius: 6; color: parent.hovered ? rootWindow.borderCol : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Item {
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "⚙️"; color: rootWindow.textMain; font.pixelSize: 16 }
            Text {
                x: 45; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; color: rootWindow.textMain; font.pixelSize: 14
                opacity: root.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
        onClicked: root.openSettings()
    }
}
