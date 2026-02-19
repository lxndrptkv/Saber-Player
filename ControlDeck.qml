import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 90
    color: rootWindow.bgPanel
    clip: true

    property var player
    property var settings
    property var appFileDialog
    property bool isMiniPlayer: false

    // Mathematical Luminance Detector: Checks if your accent color is too bright
    property bool isAccentLight: settings && settings.accentColor ? ((settings.accentColor.r * 0.299 + settings.accentColor.g * 0.587 + settings.accentColor.b * 0.114) > 0.6) : false

    signal toggleMiniPlayer()

    property bool isHovered: deckHover.hovered || trackMouse.pressed || volMouse.pressed

    HoverHandler { id: deckHover }

    Connections {
        target: player
        function onTrackEnded() {
            if (settings && settings.autoPlay) player.autoPlayNext()
        }
    }

    Component.onCompleted: {
        if (settings && settings.savedVolume !== undefined) {
            player.changeVolume(settings.savedVolume)
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isMiniPlayer
        onPressed: { rootWindow.startSystemMove() }
    }

    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 1; color: rootWindow.borderCol
    }

    RowLayout {
        anchors.fill: parent

        anchors.margins: root.isMiniPlayer ? 12 : 10
        anchors.leftMargin: root.isMiniPlayer ? 15 : 20
        anchors.rightMargin: root.isMiniPlayer ? 15 : 20
        spacing: root.isMiniPlayer ? 10 : 20

        Behavior on spacing { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
        Behavior on anchors.margins { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

        RowLayout {
            Layout.preferredWidth: root.isMiniPlayer ? 190 : 250
            Layout.fillWidth: true
            spacing: root.isMiniPlayer ? 8 : 12

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
            Behavior on spacing { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

            Rectangle {
                width: root.isMiniPlayer ? 40 : 48
                height: root.isMiniPlayer ? 40 : 48
                radius: 6
                color: rootWindow.bgSidebar
                border.color: rootWindow.borderCol
                border.width: 1
                clip: true

                Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

                Image {
                    anchors.centerIn: parent
                    source: player.currentArt && !player.currentArt.startsWith("attachment://") ? player.currentArt : "logo.png"
                    width: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? parent.width : (root.isMiniPlayer ? 24 : 32)
                    height: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? parent.height : (root.isMiniPlayer ? 24 : 32)
                    fillMode: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    mipmap: true

                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                    Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: player.currentTitle || "SaberPlayer Ready"
                    color: rootWindow.textMain
                    font.bold: true
                    font.pixelSize: root.isMiniPlayer ? 12 : 14
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    clip: true
                }
                Text {
                    text: player.currentArtist || "Stopped"
                    color: rootWindow.textSub
                    font.pixelSize: root.isMiniPlayer ? 10 : 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    clip: true
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
                spacing: root.isMiniPlayer ? 6 : 12

                Behavior on spacing { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

                Button {
                    text: "🔀"
                    onClicked: { player.shuffle = !player.shuffle }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: player.shuffle && settings ? settings.accentColor : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                        font.pixelSize: root.isMiniPlayer ? 14 : 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: player.shuffle ? 1.0 : 0.4
                    }
                }

                Button {
                    text: "⏹"
                    onClicked: { player.stop() }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: root.isMiniPlayer ? 14 : 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "⏮"
                    onClicked: { player.playPrevious() }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: root.isMiniPlayer ? 16 : 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: player.isPlaying ? "⏸" : "▶"
                    onClicked: {
                        if (player.isPlaying) player.pause()
                        else player.play()
                    }
                    background: Rectangle {
                        implicitWidth: root.isMiniPlayer ? 36 : 42
                        implicitHeight: root.isMiniPlayer ? 36 : 42
                        radius: width / 2
                        color: parent.hovered && settings ? Qt.lighter(settings.accentColor, 1.1) : (settings ? settings.accentColor : "grey")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on implicitWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                        Behavior on implicitHeight { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                    }
                    contentItem: Text {
                        text: parent.text
                        // FIXED: Dynamic Contrast text based on the Accent Color luminance!
                        color: root.isAccentLight ? "black" : "white"
                        font.pixelSize: root.isMiniPlayer ? 14 : 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: (!player.isPlaying) ? 3 : 0
                    }
                }

                Button {
                    text: "⏭"
                    onClicked: { player.playNext() }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: root.isMiniPlayer ? 16 : 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "⏏"
                    onClicked: { appFileDialog.open() }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                        font.pixelSize: root.isMiniPlayer ? 14 : 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: player.repeatMode === 2 ? "🔂" : "🔁"
                    onClicked: { player.repeatMode = (player.repeatMode + 1) % 3 }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: player.repeatMode > 0 && settings ? settings.accentColor : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                        font.pixelSize: root.isMiniPlayer ? 14 : 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: player.repeatMode > 0 ? 1.0 : 0.4
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: {
                        if (trackMouse.pressed) {
                            var t = trackSlider.visualProgress * (player.duration || 0);
                            return player.formatTime(Number.isNaN(t) ? 0 : t);
                        }
                        return player.formattedTime ? (player.formattedTime.split(" / ")[0] || "00:00") : "00:00";
                    }
                    color: rootWindow.textSub
                    font.family: "Consolas"
                    font.pixelSize: 11
                    Layout.preferredWidth: 40
                }

                Item {
                    id: trackSlider
                    Layout.fillWidth: true
                    height: 20

                    property real progress: (player && player.progress !== undefined) ? player.progress : 0.0
                    property real visualProgress: trackMouse.pressed ? Math.max(0, Math.min(1, width > 0 ? trackMouse.mouseX / width : 0.0)) : progress

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: rootWindow.borderCol
                        Rectangle {
                            property real safeWidth: trackSlider.visualProgress * parent.width
                            width: Number.isNaN(safeWidth) ? 0 : safeWidth
                            height: parent.height
                            color: settings && settings.accentColor ? settings.accentColor : "white"
                            radius: 2
                        }
                    }

                    Rectangle {
                        property real safeX: (trackSlider.visualProgress * parent.width) - width / 2
                        x: Number.isNaN(safeX) ? 0 : safeX

                        anchors.verticalCenter: parent.verticalCenter
                        width: trackMouse.pressed || trackMouse.containsMouse ? 12 : 0
                        height: width
                        radius: width / 2
                        color: settings && settings.accentColor ? settings.accentColor : "white"
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: trackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onReleased: {
                            if (player.duration > 0) {
                                var target = trackSlider.visualProgress * player.duration;
                                player.seek(Number.isNaN(target) ? 0 : target);
                            }
                        }
                    }
                }

                Text {
                    text: player.formattedTime ? (player.formattedTime.split(" / ")[1] || "00:00") : "00:00"
                    color: rootWindow.textSub
                    font.family: "Consolas"
                    font.pixelSize: 11
                    Layout.preferredWidth: 40
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: root.isMiniPlayer ? 140 : 250
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

            Item { Layout.fillWidth: true }

            Button {
                text: player.volume === 0 ? "🔇" : "🔊"
                onClicked: {
                    let newVol = player.volume > 0 ? 0 : 50
                    player.changeVolume(newVol)
                    if(settings) settings.savedVolume = newVol
                }
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                    font.pixelSize: root.isMiniPlayer ? 14 : 16
                }
            }

            Item {
                id: volSlider
                Layout.preferredWidth: root.isMiniPlayer ? 50 : 80
                Layout.maximumWidth: root.isMiniPlayer ? 50 : 80
                height: 20

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                Behavior on Layout.maximumWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

                property real visualVolume: (player && player.volume !== undefined) ? player.volume / 100.0 : 0.5

                function updateVol(mouseXPos) {
                    let newVol = Math.max(0, Math.min(1, width > 0 ? mouseXPos / width : 0.0)) * 100
                    player.changeVolume(Number.isNaN(newVol) ? 0 : Math.floor(newVol))
                    if(settings) settings.savedVolume = Math.floor(newVol)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: rootWindow.borderCol
                    Rectangle {
                        property real safeWidth: volSlider.visualVolume * parent.width
                        width: Number.isNaN(safeWidth) ? 0 : safeWidth
                        height: parent.height
                        color: rootWindow.textSub
                        radius: 2
                    }
                }

                Rectangle {
                    property real safeX: (volSlider.visualVolume * parent.width) - width / 2
                    x: Number.isNaN(safeX) ? 0 : safeX
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
                onClicked: { root.toggleMiniPlayer() }
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
