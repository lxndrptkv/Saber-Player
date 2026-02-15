import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 90
    color: rootWindow.bgPanel

    property var player
    property var settings
    property var appFileDialog
    property bool isMiniPlayer: false

    signal toggleMiniPlayer()

    property bool isHovered: deckHover.hovered || trackMouse.pressed || volMouse.pressed

    HoverHandler {
        id: deckHover
    }

    Connections {
        target: player
        function onTrackEnded() {
            if (settings.autoPlay) {
                player.playNext()
            }
        }
    }

    Component.onCompleted: {
        player.changeVolume(settings.savedVolume)
    }

    // ==========================================
    // WINDOW DRAG HANDLER (For Mini Player)
    // ==========================================
    MouseArea {
        anchors.fill: parent
        enabled: root.isMiniPlayer
        onPressed: {
            rootWindow.startSystemMove()
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: rootWindow.borderCol
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 20

        RowLayout {
            Layout.preferredWidth: 250
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 48
                height: 48
                radius: 6
                color: rootWindow.borderCol
                Text {
                    anchors.centerIn: parent
                    text: "🎵"
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: player.currentSource || "SaberPlayer Ready"
                    color: rootWindow.textMain
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: player.isPlaying ? "Now Playing" : "Stopped"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    text: "🔀"
                    onClicked: {
                        player.shuffle = !player.shuffle
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: player.shuffle ? settings.accentColor : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "⏹"
                    onClicked: {
                        player.stop()
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "⏮"
                    onClicked: {
                        player.playPrevious()
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: player.isPlaying ? "⏸" : "▶"
                    onClicked: {
                        if (player.isPlaying) {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }
                    background: Rectangle {
                        implicitWidth: 42
                        implicitHeight: 42
                        radius: 21
                        color: parent.hovered ? Qt.lighter(settings.accentColor, 1.1) : settings.accentColor
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: (!player.isPlaying) ? 3 : 0
                    }
                }

                Button {
                    text: "⏭"
                    onClicked: {
                        player.playNext()
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "⏏"
                    onClicked: {
                        appFileDialog.open()
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: player.repeatMode === 2 ? "🔂" : "🔁"
                    onClicked: {
                        player.repeatMode = (player.repeatMode + 1) % 3
                    }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: player.repeatMode > 0 ? settings.accentColor : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: trackMouse.pressed ? player.formatTime(trackSlider.visualProgress * player.duration) : (player.formattedTime.split(" / ")[0] || "00:00")
                    color: rootWindow.textSub
                    font.family: "Consolas"
                    font.pixelSize: 11
                    Layout.preferredWidth: 40
                }

                Item {
                    id: trackSlider
                    Layout.fillWidth: true
                    height: 20

                    property real progress: (player.duration > 0) ? (player.position / player.duration) : 0
                    property real visualProgress: trackMouse.pressed ? Math.max(0, Math.min(1, trackMouse.mouseX / width)) : progress

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: rootWindow.borderCol
                        Rectangle {
                            width: trackSlider.visualProgress * parent.width
                            height: parent.height
                            color: settings.accentColor
                            radius: 2
                        }
                    }

                    Rectangle {
                        x: (trackSlider.visualProgress * parent.width) - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: trackMouse.pressed || trackMouse.containsMouse ? 12 : 0
                        height: width
                        radius: width / 2
                        color: settings.accentColor
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: trackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onReleased: {
                            if (player.duration > 0) {
                                player.seek(Math.floor(trackSlider.visualProgress * player.duration))
                            }
                        }
                    }
                }

                Text {
                    text: player.formattedTime.split(" / ")[1] || "00:00"
                    color: rootWindow.textSub
                    font.family: "Consolas"
                    font.pixelSize: 11
                    Layout.preferredWidth: 40
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: 250
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: player.volume === 0 ? "🔇" : "🔊"
                onClicked: {
                    let newVol = player.volume > 0 ? 0 : 50
                    player.changeVolume(newVol)
                    settings.savedVolume = newVol
                }
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                    font.pixelSize: 16
                }
            }

            Item {
                id: volSlider
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                height: 20
                visible: !root.isMiniPlayer

                property real visualVolume: player.volume / 100

                function updateVol(mouseXPos) {
                    let newVol = Math.max(0, Math.min(1, mouseXPos / width)) * 100
                    player.changeVolume(Math.floor(newVol))
                    settings.savedVolume = Math.floor(newVol)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: rootWindow.borderCol
                    Rectangle {
                        width: volSlider.visualVolume * parent.width
                        height: parent.height
                        color: rootWindow.textSub
                        radius: 2
                    }
                }

                Rectangle {
                    x: (volSlider.visualVolume * parent.width) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: volMouse.pressed || volMouse.containsMouse ? 12 : 0
                    height: width
                    radius: width / 2
                    color: rootWindow.textMain
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: { volSlider.updateVol(mouseX) }
                    onPositionChanged: { if (pressed) volSlider.updateVol(mouseX) }
                }
            }

            Button {
                text: root.isMiniPlayer ? "🗖" : "🗗"
                onClicked: {
                    root.toggleMiniPlayer()
                }
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                    font.pixelSize: 18
                }
            }
        }
    }
}
