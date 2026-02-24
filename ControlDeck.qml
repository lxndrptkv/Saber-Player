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

    Popup {
        id: queuePopup
        parent: Overlay.overlay

        x: Math.max(0, rootWindow.width - width - 20)
        y: Math.max(0, rootWindow.height - root.height - height - 10)

        width: 340
        height: Math.min(500, rootWindow.height * 0.7)

        visible: player && player.isQueueOpen
        onClosed: if(player) player.isQueueOpen = false
        padding: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250 }
            NumberAnimation { property: "y"; from: queuePopup.y + 40; to: queuePopup.y; duration: 250; easing.type: Easing.OutQuint }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
            NumberAnimation { property: "y"; from: queuePopup.y; to: queuePopup.y + 20; duration: 200; easing.type: Easing.InQuad }
        }

        background: Rectangle {
            color: rootWindow.bgPanel
            border.color: rootWindow.borderCol
            border.width: 1
            radius: 12
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            Text {
                text: "Up Next"
                color: rootWindow.textMain
                font.bold: true
                font.pixelSize: 18
                font.family: "Segoe UI"
            }

            ListView {
                id: queueList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, parent.height * 0.45)
                Layout.maximumHeight: parent.height * 0.45
                clip: true
                spacing: 8
                model: player ? player.currentQueue : []

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 50
                    color: queueHover.hovered ? (isDarkTheme ? "#22ffffff" : "#11000000") : "transparent"
                    radius: 6

                    property bool isDarkTheme: (rootWindow.bgPanel.r + rootWindow.bgPanel.g + rootWindow.bgPanel.b) / 3 < 0.6

                    HoverHandler { id: queueHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 4
                            color: rootWindow.bgSidebar
                            clip: true
                            Image {
                                anchors.centerIn: parent
                                source: modelData.artUrl && !modelData.artUrl.startsWith("attachment://") ? modelData.artUrl : "logo.png"
                                width: parent.width; height: parent.height
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: modelData.title; color: rootWindow.textMain; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 13 }
                            Text { text: modelData.artist; color: settings.accentColor; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 11 }
                        }

                        Button {
                            z: 10
                            text: "✕"
                            background: Rectangle { color: "transparent" }
                            contentItem: Text { text: parent.text; color: parent.hovered ? "#ff4444" : rootWindow.textSub; font.pixelSize: 16 }
                            onClicked: player.removeQueueTrack(index)
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: rootWindow.borderCol; visible: player && player.currentQueue.length > 0 }

            Text {
                text: "More from " + (player && player.currentAlbum ? player.currentAlbum : "this artist")
                color: rootWindow.textMain
                font.bold: true
                font.pixelSize: 14
                visible: suggestionsList.count > 0
            }

            ListView {
                id: suggestionsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: libraryModel && player ? libraryModel.getAlbumTracks(player.currentAlbum) : []

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 50
                    color: sugHover.hovered ? (isDarkTheme ? "#22ffffff" : "#11000000") : "transparent"
                    radius: 6

                    property bool isDarkTheme: (rootWindow.bgPanel.r + rootWindow.bgPanel.g + rootWindow.bgPanel.b) / 3 < 0.6

                    HoverHandler { id: sugHover; cursorShape: Qt.PointingHandCursor }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: player.enqueueTrack(modelData.url, modelData.title, modelData.artist, modelData.album, modelData.artUrl)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 4
                            color: rootWindow.bgSidebar
                            clip: true
                            Image {
                                anchors.centerIn: parent
                                source: modelData.artUrl && !modelData.artUrl.startsWith("attachment://") ? modelData.artUrl : "logo.png"
                                width: parent.width; height: parent.height
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: modelData.title; color: rootWindow.textMain; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 13 }
                            Text { text: modelData.artist; color: rootWindow.textSub; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 11 }
                        }

                        Text {
                            text: "➕"
                            color: sugHover.hovered ? settings.accentColor : rootWindow.textSub
                            font.pixelSize: 16
                            font.bold: true
                            Layout.rightMargin: 10
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true; visible: suggestionsList.count === 0 }
        }
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

        // ========================================================
        // SPOTIFY-STYLE CENTER CONTROLS
        // ========================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.isMiniPlayer ? 10 : 25 // Wider spacing to match Spotify layout

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
                        opacity: player.shuffle ? 1.0 : 0.6
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

                // FIXED: Animated Inverted Play Circle (Spotify Style)
                Button {
                    id: playBtn
                    text: player.isPlaying ? "⏸" : "▶"
                    onClicked: {
                        if (player.isPlaying) player.pause()
                        else player.play()
                    }
                    background: Rectangle {
                        implicitWidth: root.isMiniPlayer ? 32 : 40
                        implicitHeight: root.isMiniPlayer ? 32 : 40
                        radius: width / 2

                        // Solid inversion color matching Spotify's circle
                        color: rootWindow.textMain

                        // "Pop" fluid physics on hover and click!
                        scale: playBtn.pressed ? 0.94 : (playBtn.hovered ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on implicitWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                        Behavior on implicitHeight { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
                    }
                    contentItem: Text {
                        text: parent.text

                        // Icon takes the background color, creating a perfect punched-out look
                        color: rootWindow.bgPanel
                        font.pixelSize: root.isMiniPlayer ? 14 : 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        // Slight padding offset to visually balance the Play triangle
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
                    text: player.repeatMode === 2 ? "🔂" : "🔁"
                    onClicked: { player.repeatMode = (player.repeatMode + 1) % 3 }
                    background: Rectangle { color: "transparent" }
                    contentItem: Text {
                        text: parent.text
                        color: player.repeatMode > 0 && settings ? settings.accentColor : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                        font.pixelSize: root.isMiniPlayer ? 14 : 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: player.repeatMode > 0 ? 1.0 : 0.6
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

                            // Change track color to accent on hover to match Spotify mechanics
                            color: trackMouse.containsMouse && settings ? settings.accentColor : rootWindow.textMain
                            radius: 2
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Rectangle {
                        property real safeX: (trackSlider.visualProgress * parent.width) - width / 2
                        x: Number.isNaN(safeX) ? 0 : safeX

                        anchors.verticalCenter: parent.verticalCenter
                        width: trackMouse.pressed || trackMouse.containsMouse ? 12 : 0
                        height: width
                        radius: width / 2
                        color: rootWindow.textMain
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
            Layout.preferredWidth: root.isMiniPlayer ? 180 : 280
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 8

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

            Item { Layout.fillWidth: true }

            // MOVED: Eject button safely relocated to the secondary control group
            Button {
                text: "⏏"
                onClicked: { appFileDialog.open() }
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? rootWindow.textMain : rootWindow.textSub
                    font.pixelSize: root.isMiniPlayer ? 14 : 16
                }
            }

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
                        color: volMouse.containsMouse && settings ? settings.accentColor : rootWindow.textSub
                        radius: 2
                        Behavior on color { ColorAnimation { duration: 150 } }
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
                text: "📜"
                onClicked: { player.isQueueOpen = !player.isQueueOpen }
                background: Rectangle { radius: 4; color: player && player.isQueueOpen && settings ? settings.accentColor : "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: player && player.isQueueOpen ? "white" : (parent.hovered ? rootWindow.textMain : rootWindow.textSub)
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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
