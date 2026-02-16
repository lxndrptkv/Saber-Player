import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "transparent"

    property var player
    property var settings
    property var libraryModel

    Component.onCompleted: {
        libraryModel.sortBy("album")
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: libraryModel.isScanning
        visible: running
        z: 10
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        opacity: libraryModel.isScanning ? 0.5 : 1.0

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "Music Library"
                color: rootWindow.textMain
                font.pixelSize: 18
                font.bold: true
                font.family: "Segoe UI"
            }

            Item {
                Layout.fillWidth: true
            }

            TextField {
                Layout.preferredWidth: 250
                placeholderText: "Search"
                color: rootWindow.textMain
                background: Rectangle {
                    radius: 4
                    color: rootWindow.bgPanel
                    border.color: rootWindow.borderCol
                    border.width: 1
                }
                onTextChanged: {
                    libraryModel.filter(text)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 200
                spacing: 15

                Text {
                    text: "#"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                    Layout.preferredWidth: 25
                }
                Text {
                    text: "Title"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                    Layout.preferredWidth: 280
                }
                Text {
                    text: "Length"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                    Layout.preferredWidth: 50
                }
                Text {
                    text: "Artist"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                    Layout.preferredWidth: 150
                }
                Text {
                    text: "Size"
                    color: rootWindow.textSub
                    font.pixelSize: 12
                    Layout.preferredWidth: 60
                }

                Item {
                    Layout.fillWidth: true
                }
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
                model: libraryModel
                clip: true
                spacing: 0

                section.property: "trackAlbum"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: ListView.view.width
                    height: 35

                    RowLayout {
                        anchors.fill: parent
                        anchors.topMargin: 10
                        spacing: 10

                        Text {
                            text: section
                            color: isDark ? "#4aa3df" : "#1a6bba"
                            font.pixelSize: 13
                            font.bold: true
                            Layout.leftMargin: 10
                            font.family: "Segoe UI"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: isDark ? "#4aa3df" : "#a0c0e0"
                            opacity: 0.6
                            Layout.rightMargin: 10
                        }
                    }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 24
                    color: ma.containsMouse ? (isDark ? "#1a3a5a" : "#e5f3fb") : "transparent"

                    property bool isFirstInSection: ListView.previousSection !== ListView.section

                    Item {
                        visible: isFirstInSection
                        width: 190
                        height: 120
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        z: 5

                        Rectangle {
                            id: artBox
                            width: 76
                            height: 76
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            color: rootWindow.bgSidebar
                            border.color: rootWindow.borderCol
                            border.width: 1

                            // FIXED: SWAPPED TEXT EMOJI FOR NATIVE LOGO
                            Image {
                                anchors.centerIn: parent
                                source: "logo.png"
                                width: 44
                                height: 44
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                opacity: 0.5
                            }
                        }

                        ColumnLayout {
                            anchors.top: artBox.top
                            anchors.left: artBox.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            spacing: 2

                            Text {
                                text: trackAlbum
                                font.bold: true
                                color: rootWindow.textMain
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                font.pixelSize: 12
                                font.family: "Segoe UI"
                            }
                            Text {
                                text: trackArtist
                                color: rootWindow.textMain
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                font.pixelSize: 12
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 200
                        spacing: 15

                        Text {
                            text: trackNumber
                            color: rootWindow.textMain
                            Layout.preferredWidth: 25
                            font.pixelSize: 12
                        }
                        Text {
                            text: trackName
                            color: rootWindow.textMain
                            elide: Text.ElideRight
                            Layout.preferredWidth: 280
                            font.pixelSize: 12
                            font.family: "Segoe UI"
                        }
                        Text {
                            text: "3:45"
                            color: rootWindow.textSub
                            Layout.preferredWidth: 50
                            font.pixelSize: 12
                        }
                        Text {
                            text: trackArtist
                            color: rootWindow.textSub
                            elide: Text.ElideRight
                            Layout.preferredWidth: 150
                            font.pixelSize: 12
                        }
                        Text {
                            text: trackSize
                            color: rootWindow.textSub
                            Layout.preferredWidth: 60
                            font.pixelSize: 12
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onDoubleClicked: {
                            player.playTrackList(libraryModel.getTrackUrls(), index)
                        }
                    }
                }
            }
        }
    }
}
