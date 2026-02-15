import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    property var player
    property var settings

    property var cdDrives: []
    property var cdTracks: []
    property string currentCdPath: ""

    Component.onCompleted: {
        refreshCds()
    }

    function refreshCds() {
        cdDrives = player.detectCdDrives()
        if (cdDrives.length > 0) {
            currentCdPath = cdDrives[0].path
            cdTracks = player.getCdTracks(currentCdPath)
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
                text: "Scan for CD"
                onClicked: {
                    refreshCds()
                }
                background: Rectangle {
                    radius: 4
                    color: parent.hovered ? settings.accentColor : rootWindow.bgPanel
                    border.color: rootWindow.borderCol
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.parent.hovered ? "white" : rootWindow.textMain
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
                Text { text: "Title"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 280 }
                Text { text: "Artist"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 150 }
                Text { text: "Format"; color: rootWindow.textSub; font.pixelSize: 12; Layout.preferredWidth: 60 }
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
                        Text { text: modelData.trackName; color: rootWindow.textMain; elide: Text.ElideRight; Layout.preferredWidth: 280; font.pixelSize: 13; font.family: "Segoe UI" }
                        Text { text: modelData.trackArtist; color: rootWindow.textSub; elide: Text.ElideRight; Layout.preferredWidth: 150; font.pixelSize: 13 }
                        Text { text: modelData.trackSize; color: rootWindow.textSub; Layout.preferredWidth: 60; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onDoubleClicked: {
                            // Extract the track URLs to build the playlist array
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
