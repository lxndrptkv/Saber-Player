import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    color: "transparent"

    property var player
    property var settings
    property var cdManager

    property var cdDrives: []
    property var cdTracks: []
    property string currentCdPath: ""

    // Ripping States
    property bool isRipping: false

    Connections {
        target: cdManager
        function onRipProgressUpdated(current, total, name) {
            isRipping = true
            ripOverlayText.text = "Ripping Track " + current + " of " + total + "\n" + name
        }
        function onRipFinished() {
            isRipping = false
            ripOverlayText.text = "Rip Complete!"
        }
    }

    Component.onCompleted: {
        refreshCds()
    }

    function refreshCds() {
        cdDrives = cdManager.detectCdDrives()
        if (cdDrives.length > 0) {
            currentCdPath = cdDrives[0].path
            cdTracks = cdManager.getCdTracks(currentCdPath)
        } else {
            currentCdPath = ""
            cdTracks = []
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: cdDrives.length > 0 ? ("💿 " + cdDrives[0].name + " (" + cdTracks.length + " Tracks)") : "💿 No Audio CD Detected"
                color: rootWindow.textMain
                font.pixelSize: 18
                font.bold: true
                font.family: "Segoe UI"
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Rip CD"
                enabled: cdTracks.length > 0 && !isRipping
                onClicked: {
                    ripPopup.open()
                }
                background: Rectangle {
                    radius: 4
                    color: parent.enabled ? (parent.hovered ? settings.accentColor : rootWindow.bgPanel) : rootWindow.borderCol
                    border.color: rootWindow.borderCol
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? (parent.parent.hovered ? "white" : rootWindow.textMain) : rootWindow.textSub
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "Scan for CD"
                enabled: !isRipping
                onClicked: {
                    refreshCds()
                }
                background: Rectangle {
                    radius: 4
                    color: parent.enabled ? (parent.hovered ? settings.accentColor : rootWindow.bgPanel) : rootWindow.borderCol
                    border.color: rootWindow.borderCol
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? (parent.parent.hovered ? "white" : rootWindow.textMain) : rootWindow.textSub
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                spacing: 15

                Text { text: "#"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 25 }
                Text { text: "Title"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 200 }
                Text { text: "Duration"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 60 }
                Text { text: "Album"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 150 }
                Text { text: "Artist"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 150 }
                Item { Layout.fillWidth: true }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: rootWindow.borderCol
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ListView {
                id: listView
                model: cdTracks
                clip: true
                spacing: 0

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 35
                    color: ma.containsMouse ? (isDark ? "#1a3a5a" : "#e5f3fb") : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        spacing: 15

                        Text { text: modelData.trackNumber; color: rootWindow.textMain; Layout.preferredWidth: 25; font.pixelSize: 13 }
                        Text { text: modelData.trackName; color: rootWindow.textMain; elide: Text.ElideRight; Layout.preferredWidth: 200; font.pixelSize: 13; font.family: "Segoe UI" }
                        Text { text: modelData.trackDuration; color: rootWindow.textSub; Layout.preferredWidth: 60; font.pixelSize: 13; font.family: "Consolas" }
                        Text { text: modelData.trackAlbum; color: rootWindow.textSub; elide: Text.ElideRight; Layout.preferredWidth: 150; font.pixelSize: 13 }
                        Text { text: modelData.trackArtist; color: rootWindow.textSub; elide: Text.ElideRight; Layout.preferredWidth: 150; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onDoubleClicked: {
                            if (!isRipping) {
                                let urls = []
                                for(let i = 0; i < cdTracks.length; i++) {
                                    urls.push(cdTracks[i].trackUrl)
                                }
                                player.playTrackList(urls, index)
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // RIP PROGRESS OVERLAY
    // ==========================================
    Rectangle {
        visible: isRipping || ripOverlayText.text === "Rip Complete!"
        anchors.fill: parent
        color: rootWindow.bgMain
        opacity: 0.95
        z: 20

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            Text {
                id: ripOverlayText
                text: "Initializing Rip..."
                color: rootWindow.textMain
                font.pixelSize: 22
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            BusyIndicator {
                running: isRipping
                visible: isRipping
                Layout.alignment: Qt.AlignHCenter
            }

            Button {
                visible: !isRipping && ripOverlayText.text === "Rip Complete!"
                text: "Dismiss"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    ripOverlayText.text = ""
                }
            }
        }
    }

    // ==========================================
    // RIP CONFIGURATION POPUP
    // ==========================================
    FolderDialog {
        id: outFolderDialog
        title: "Select Rip Destination"
        onAccepted: {
            // Converts file:///D:/Music to D:/Music
            outPathInput.text = selectedFolder.toString().replace(/^(file:\/{2,3})/, "")
            ripPopup.outUrl = selectedFolder
        }
    }

    Popup {
        id: ripPopup
        anchors.centerIn: parent
        width: 400
        height: 350
        modal: true

        property var outUrl: ""

        background: Rectangle {
            color: rootWindow.bgPanel
            radius: 12
            border.width: 1
            border.color: settings.accentColor
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 20

            Text {
                text: "Rip Audio CD"
                color: rootWindow.textMain
                font.pixelSize: 22
                font.bold: true
            }

            // Folder Selection
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                TextField {
                    id: outPathInput
                    Layout.fillWidth: true
                    placeholderText: "Select output folder..."
                    readOnly: true
                    color: rootWindow.textMain
                }
                Button {
                    text: "Browse"
                    onClicked: {
                        outFolderDialog.open()
                    }
                }
            }

            // Format Selection
            RowLayout {
                spacing: 15
                Text { text: "Format:"; color: rootWindow.textMain; font.pixelSize: 14; Layout.preferredWidth: 80 }
                ComboBox {
                    id: formatCombo
                    Layout.fillWidth: true
                    model: ["MP3", "FLAC", "WAV", "OGG"]
                }
            }

            // Bitrate Selection
            RowLayout {
                spacing: 15
                // Disable bitrate options if using lossless formats!
                opacity: (formatCombo.currentText === "FLAC" || formatCombo.currentText === "WAV") ? 0.4 : 1.0

                Text { text: "Bitrate:"; color: rootWindow.textMain; font.pixelSize: 14; Layout.preferredWidth: 80 }
                ComboBox {
                    id: bitrateCombo
                    Layout.fillWidth: true
                    enabled: formatCombo.currentText === "MP3" || formatCombo.currentText === "OGG"
                    model: ["320", "256", "192", "128"]
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: ripPopup.close()
                }
                Button {
                    text: "Start Ripping"
                    Layout.fillWidth: true
                    enabled: outPathInput.text !== ""
                    background: Rectangle {
                        radius: 4
                        color: parent.enabled ? settings.accentColor : rootWindow.borderCol
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        cdManager.ripCd(cdTracks, ripPopup.outUrl, formatCombo.currentText, parseInt(bitrateCombo.currentText))
                        ripPopup.close()
                    }
                }
            }
        }
    }
}
