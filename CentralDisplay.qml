import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"

    property var player
    property var settings

    property bool compactMode: false

    Timer {
        id: modeTimer
        interval: 3000
        running: player.isPlaying && !root.compactMode
        onTriggered: {
            root.compactMode = true
        }
    }

    Connections {
        target: player
        function onIsPlayingChanged() {
            if (!player.isPlaying) {
                root.compactMode = false
            } else {
                modeTimer.restart()
            }
        }
    }

    // ==========================================
    // C++ DRIVEN AUDIO VISUALIZER
    // ==========================================
    Item {
        id: visualizerContainer
        anchors.centerIn: parent
        width: 590
        height: 200
        opacity: root.compactMode ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 1000
                easing.type: Easing.InOutQuad
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: player.spectrum

                Item {
                    width: 14
                    height: 200 // Maximum visualizer height

                    // STYLE 1: Mirrored (Expands up and down from the center)
                    Rectangle {
                        visible: settings.visualizerStyle === "Mirrored"
                        anchors.centerIn: parent
                        width: 14
                        height: modelData !== undefined ? modelData : 10
                        radius: 7
                        color: settings.accentColor
                        Behavior on height {
                            NumberAnimation {
                                duration: 35
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    // STYLE 2: Bottom Bars (Classic equalizer anchored to the floor)
                    Rectangle {
                        visible: settings.visualizerStyle === "Bottom Bars"
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 14
                        height: modelData !== undefined ? modelData : 10
                        radius: 7
                        color: settings.accentColor
                        Behavior on height {
                            NumberAnimation {
                                duration: 35
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    // STYLE 3: Floating Dots (Little glowing orbs bouncing to the math)
                    Rectangle {
                        visible: settings.visualizerStyle === "Floating Dots"
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 14
                        height: 14
                        radius: 7
                        color: settings.accentColor

                        // Dynamically pushes the Y coordinate up based on the C++ value
                        y: parent.height - (modelData !== undefined ? modelData : 10) - 14

                        Behavior on y {
                            NumberAnimation {
                                duration: 35
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // MOVING ALBUM ART RECTANGLE
    // ==========================================
    property real pulseScale: 1.0

    SequentialAnimation on pulseScale {
        running: player.isPlaying && !root.compactMode
        loops: Animation.Infinite
        NumberAnimation {
            from: 1.0
            to: 1.05
            duration: 1000
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            from: 1.05
            to: 1.0
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        id: artRect

        width: root.compactMode ? 120 : 300
        height: root.compactMode ? 120 : 300
        radius: root.compactMode ? 16 : 20

        x: root.compactMode ? root.width - width - 30 : (root.width - width) / 2
        y: root.compactMode ? 30 : (root.height - height) / 2 - 40
        scale: root.compactMode ? 1.0 : root.pulseScale

        color: rootWindow.bgPanel
        border.color: player.isPlaying ? settings.accentColor : rootWindow.borderCol
        border.width: 3

        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.InOutExpo } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.InOutExpo } }
        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.InOutExpo } }
        Behavior on height { NumberAnimation { duration: 800; easing.type: Easing.InOutExpo } }
        Behavior on radius { NumberAnimation { duration: 800; easing.type: Easing.InOutExpo } }

        Rectangle {
            visible: player.isPlaying
            anchors.fill: parent
            anchors.margins: -5
            radius: parent.radius + 5
            color: settings.accentColor
            opacity: root.compactMode ? 0.0 : 0.3
            Behavior on opacity {
                NumberAnimation {
                    duration: 800
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "♪"
            color: parent.border.color
            font.pixelSize: artRect.width * 0.4
            font.family: "Segoe UI Emoji"
        }
    }

    // ==========================================
    // SONG TITLE & PROGRESS
    // ==========================================
    ColumnLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 15

        Text {
            text: player.currentSource || "SaberPlayer"
            color: rootWindow.textMain
            font.bold: true
            font.pixelSize: 28
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            visible: player.duration > 0
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: player.formattedTime.split(" / ")[0] || "00:00"
                color: rootWindow.textSub
                font.family: "Consolas"
                font.pixelSize: 14
            }

            Rectangle {
                width: 300
                height: 4
                radius: 2
                color: rootWindow.borderCol
                Rectangle {
                    width: player.duration > 0 ? (parent.width * (player.position / player.duration)) : 0
                    height: parent.height
                    color: settings.accentColor
                    radius: 2
                }
            }

            Text {
                text: player.formattedTime.split(" / ")[1] || "00:00"
                color: rootWindow.textSub
                font.family: "Consolas"
                font.pixelSize: 14
            }
        }
    }
}
