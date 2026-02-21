import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: centralRoot
    color: "transparent"
    clip: true

    property var player
    property var settings
    property string visAnchor: "Center"

    property bool isDarkTheme: (rootWindow.bgPanel.r + rootWindow.bgPanel.g + rootWindow.bgPanel.b) / 3 < 0.6

    // ==========================================
    // FIXED: AUTO-OPEN QUEUE LOGIC
    // ==========================================
    property int lastQueueLength: 0

    Connections {
        target: player
        function onQueueChanged() {
            // Only auto-open if we are on this screen and a song was ADDED (length increased)
            if (centralRoot.visible && player.currentQueue.length > lastQueueLength && player.currentQueue.length > 0) {
                player.isQueueOpen = true;
            }
            lastQueueLength = player.currentQueue.length;
        }
    }

    Item {
        anchors.fill: parent
        opacity: player && player.isPlaying ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }

        Image {
            id: bgArtSource
            source: player && player.currentArt && !player.currentArt.startsWith("attachment://") ? player.currentArt : ""
            width: 256
            height: 256
            visible: false
            mipmap: true
        }

        MultiEffect {
            source: bgArtSource
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 2
            height: Math.max(parent.width, parent.height) * 2

            blurEnabled: true
            blurMax: 80
            blur: 1.0
            saturation: 1.6
            contrast: 0.2
            brightness: 0.1
            opacity: 0.65

            NumberAnimation on rotation {
                from: 0; to: 360
                duration: 120000
                loops: Animation.Infinite
                running: player && player.isPlaying
            }
        }

        Canvas {
            id: waveCanvas
            anchors.fill: parent
            property real t: 0

            NumberAnimation on t {
                from: 0; to: Math.PI * 2
                duration: 12000
                loops: Animation.Infinite
                running: player && player.isPlaying
            }

            onPaint: {
                if (!settings || !settings.accentColor) return;
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var rgbStr = centralRoot.isDarkTheme ? "255, 255, 255" : "0, 0, 0";

                ctx.beginPath();
                ctx.moveTo(0, height);
                for (var x = 0; x <= width; x += 20) {
                    var y1 = height * 0.5 + Math.sin(x * 0.002 + t) * 150 + Math.cos(x * 0.001 - t) * 60;
                    ctx.lineTo(x, y1);
                }
                ctx.lineTo(width, height);
                var grad1 = ctx.createLinearGradient(0, 0, width, height);
                grad1.addColorStop(0, "rgba(" + rgbStr + ", 0.02)");
                grad1.addColorStop(1, "rgba(" + rgbStr + ", 0.06)");
                ctx.fillStyle = grad1;
                ctx.fill();

                ctx.beginPath();
                ctx.moveTo(0, height);
                for (var x = 0; x <= width; x += 20) {
                    var y2 = height * 0.6 + Math.sin(x * 0.003 - t * 1.2) * 100 + Math.cos(x * 0.002 + t) * 80;
                    ctx.lineTo(x, y2);
                }
                ctx.lineTo(width, height);
                var grad2 = ctx.createLinearGradient(width, 0, 0, height);
                grad2.addColorStop(0, "rgba(" + rgbStr + ", 0.03)");
                grad2.addColorStop(1, "rgba(" + rgbStr + ", 0.08)");
                ctx.fillStyle = grad2;
                ctx.fill();

                ctx.beginPath();
                for (var x = 0; x <= width; x += 20) {
                    var y3 = height * 0.55 + Math.sin(x * 0.0025 + t * 1.5) * 120 + Math.cos(x * 0.0015 - t) * 70;
                    if (x === 0) ctx.moveTo(x, y3);
                    else ctx.lineTo(x, y3);
                }
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = "rgba(" + rgbStr + ", 0.15)";
                ctx.stroke();
            }
            onTChanged: requestPaint()
        }
    }

    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        z: 20
        spacing: 10

        Text { text: "Visualizer:"; color: rootWindow.textSub; font.pixelSize: 12 }

        ComboBox {
            id: visCombo
            model: ["Center", "Top", "Bottom"]
            currentIndex: 0
            onCurrentTextChanged: visAnchor = currentText

            background: Rectangle { color: rootWindow.bgPanel; radius: 4; border.color: rootWindow.borderCol }
            contentItem: Text { text: visCombo.displayText; color: rootWindow.textMain; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13 }
        }
    }

    Item {
        id: infoGroup
        width: 320
        property real safeHeightCalc: 300 + 30 + (metaPill.height || 0)
        height: isNaN(safeHeightCalc) ? 400 : safeHeightCalc

        property real targetX: player && player.isPlaying ? (centralRoot.width - width - 40) : (centralRoot.width - width) / 2
        property real targetY: player && player.isPlaying ? 60 : (centralRoot.height - height) / 2

        x: isNaN(targetX) ? 0 : targetX
        y: isNaN(targetY) ? 0 : targetY

        Behavior on x { NumberAnimation { duration: 900; easing.type: Easing.InOutQuint } }
        Behavior on y { NumberAnimation { duration: 900; easing.type: Easing.InOutQuint } }

        Item {
            id: coverWrapper
            width: 300
            height: 300
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property real animScale: player && player.isPlaying ? 1.05 : 1.0
            Behavior on animScale { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

            Rectangle {
                anchors.centerIn: parent
                property real sw: parent.width * parent.animScale
                property real sh: parent.height * parent.animScale
                width: isNaN(sw) ? 300 : sw
                height: isNaN(sh) ? 300 : sh

                radius: 12
                color: rootWindow.bgSidebar
                border.color: rootWindow.borderCol
                border.width: 1
                clip: true

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: player && player.isPlaying
                    NumberAnimation { from: 0; to: -8; duration: 2500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -8; to: 0; duration: 2500; easing.type: Easing.InOutSine }
                }

                Image {
                    anchors.centerIn: parent
                    source: player.currentArt && !player.currentArt.startsWith("attachment://") ? player.currentArt : "logo.png"
                    width: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? parent.width : 120
                    height: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? parent.height : 120
                    fillMode: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    mipmap: true
                    opacity: (player.currentArt && !player.currentArt.startsWith("attachment://")) ? 1.0 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 500 } }
                }
            }
        }

        Rectangle {
            id: metaPill
            anchors.top: coverWrapper.bottom
            anchors.topMargin: 25
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width + 20
            height: metaText.height + 20
            radius: 16

            color: centralRoot.isDarkTheme ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(255, 255, 255, 0.5)
            border.color: centralRoot.isDarkTheme ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(0, 0, 0, 0.1)
            border.width: 1

            ColumnLayout {
                id: metaText
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 5

                Text {
                    text: player.currentTitle || "SaberPlayer"
                    color: rootWindow.textMain
                    font.pixelSize: 24
                    font.bold: true
                    font.family: "Segoe UI"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Text {
                    text: player.currentArtist || "Ready to Play"
                    color: settings && settings.accentColor ? settings.accentColor : rootWindow.textMain
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }

    Item {
        id: visualizerContainer
        width: centralRoot.width
        height: 120
        x: 0

        property real targetY: {
            if (visAnchor === "Top") return 60;
            if (visAnchor === "Bottom") return centralRoot.height - 120 - 60;
            return (centralRoot.height - 120) / 2; // Center
        }

        y: isNaN(targetY) ? 0 : targetY
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }

        opacity: player && player.isPlaying ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }

        Row {
            anchors.centerIn: parent
            spacing: settings && settings.visualizerStyle === "Floating Dots" ? 8 : 4
            height: parent.height

            Repeater {
                model: player && player.spectrum ? player.spectrum : []

                Item {
                    width: settings && settings.visualizerStyle === "Floating Dots" ? 8 : 12
                    height: parent.height

                    Rectangle {
                        visible: settings && settings.visualizerStyle !== "Floating Dots"
                        width: parent.width

                        property real safeRectHeight: Math.max(4, modelData)
                        height: isNaN(safeRectHeight) ? 4 : safeRectHeight

                        color: settings && settings.accentColor ? settings.accentColor : "white"
                        radius: width / 2

                        anchors.verticalCenter: settings && settings.visualizerStyle === "Mirrored" ? parent.verticalCenter : undefined
                        anchors.bottom: settings && settings.visualizerStyle === "Bottom Bars" ? parent.bottom : undefined

                        opacity: 0.85
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Rectangle {
                        visible: settings && settings.visualizerStyle === "Floating Dots"
                        width: parent.width
                        height: width
                        radius: width / 2
                        color: settings && settings.accentColor ? settings.accentColor : "white"

                        anchors.bottom: parent.bottom
                        property real safeBottomMargin: Math.max(0, modelData - height)
                        anchors.bottomMargin: isNaN(safeBottomMargin) ? 0 : safeBottomMargin

                        opacity: 0.9
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }
    }
}
