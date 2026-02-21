import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: libraryRoot
    color: "transparent"

    property var player
    property var settings
    property var libraryModel

    property bool isGridView: false
    property real uiScale: 1.0
    property real gridScale: 1.0
    property bool showArtist: true
    property bool showSize: true
    property bool showLength: true

    property bool isDarkTheme: (rootWindow.bgPanel.r + rootWindow.bgPanel.g + rootWindow.bgPanel.b) / 3 < 0.6
    property color hoverOverlay: isDarkTheme ? "#22ffffff" : "#11000000"

    Component.onCompleted: {
        if(libraryModel) {
            libraryModel.scanLibrary()
            libraryModel.sortBy("album")
        }
    }

    Menu {
        id: trackContextMenu
        property int trackIndex: -1
        background: Rectangle {
            color: rootWindow.bgPanel
            border.color: rootWindow.borderCol
            border.width: 1
            radius: 8
        }
        MenuItem {
            text: "➕ Add to Queue"
            onTriggered: {
                if (trackContextMenu.trackIndex >= 0) {
                    var t = libraryModel.getTrack(trackContextMenu.trackIndex);
                    player.enqueueTrack(t.url, t.title, t.artist, t.album, t.artUrl);
                }
            }
            contentItem: Text {
                text: parent.text;
                color: rootWindow.textMain;
                font.pixelSize: 14;
                font.bold: true;
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
            }
            background: Rectangle {
                implicitWidth: 180
                implicitHeight: 40
                color: parent.highlighted ? libraryRoot.hoverOverlay : "transparent";
                radius: 6
            }
        }
    }

    Rectangle {
        id: notificationToast
        width: Math.max(280, toastText.width + 60)
        height: 40
        radius: 20
        color: settings && settings.accentColor ? settings.accentColor : "#0078D7"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter

        opacity: (libraryModel && libraryModel.isFetchingArt) || (libraryModel && libraryModel.isScanning) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        z: 100

        RowLayout {
            anchors.centerIn: parent
            spacing: 15
            BusyIndicator {
                running: notificationToast.opacity > 0
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }
            Text {
                id: toastText
                text: libraryModel && libraryModel.isScanning ? "Scanning Local Files..." : "Searching Internet for Artwork..."
                color: "white"
                font.bold: true
                font.pixelSize: 14
            }
        }
    }

    Text {
        visible: libraryModel && libraryModel.rowCount() === 0 && !libraryModel.isScanning
        text: "Your Library is Empty.\nClick 'Add Folder' to select your music directory!"
        color: rootWindow.textSub
        font.pixelSize: 18 * libraryRoot.uiScale
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        z: 5
    }

    FolderDialog {
        id: addFolderDialog
        title: "Select Music Folder"
        onAccepted: { libraryModel.addDirectory(selectedFolder) }
    }

    Popup {
        id: viewSettingsPopup
        property real safeX: libraryRoot.width - width - 20
        x: isNaN(safeX) ? 0 : safeX
        y: 60
        width: 250
        height: 480
        modal: false
        focus: true
        background: Rectangle {
            color: rootWindow.bgPanel
            radius: 8
            border.color: rootWindow.borderCol
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 12

            Text { text: "Library Customization"; color: rootWindow.textMain; font.bold: true; font.pixelSize: 14 }

            RowLayout {
                Text { text: "View Mode:"; color: rootWindow.textSub; Layout.fillWidth: true }
                Button {
                    text: libraryRoot.isGridView ? "Grid" : "List"
                    onClicked: libraryRoot.isGridView = !libraryRoot.isGridView
                    background: Rectangle { radius: 4; color: parent.hovered ? libraryRoot.hoverOverlay : "transparent"; border.color: rootWindow.borderCol; border.width: 1 }
                    contentItem: Text { text: parent.text; color: rootWindow.textMain; horizontalAlignment: Text.AlignHCenter }
                }
            }

            Text { text: "Toggle Columns:"; color: rootWindow.textSub; font.pixelSize: 11 }

            CheckBox {
                text: "Artist"; checked: libraryRoot.showArtist; onCheckedChanged: libraryRoot.showArtist = checked
                contentItem: Text { text: parent.text; color: rootWindow.textMain; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; leftPadding: parent.indicator.width + parent.spacing }
            }
            CheckBox {
                text: "Length"; checked: libraryRoot.showLength; onCheckedChanged: libraryRoot.showLength = checked
                contentItem: Text { text: parent.text; color: rootWindow.textMain; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; leftPadding: parent.indicator.width + parent.spacing }
            }
            CheckBox {
                text: "Size"; checked: libraryRoot.showSize; onCheckedChanged: libraryRoot.showSize = checked
                contentItem: Text { text: parent.text; color: rootWindow.textMain; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; leftPadding: parent.indicator.width + parent.spacing }
            }

            Text { text: "UI Text Scale: " + (libraryRoot.uiScale * 100).toFixed(0) + "%"; color: rootWindow.textSub; font.pixelSize: 11 }
            Slider {
                from: 0.8; to: 1.4; value: libraryRoot.uiScale
                onMoved: libraryRoot.uiScale = value
                Layout.fillWidth: true
            }

            Text { text: "Grid Cover Size: " + (libraryRoot.gridScale * 100).toFixed(0) + "%"; color: rootWindow.textSub; font.pixelSize: 11; visible: libraryRoot.isGridView }
            Slider {
                from: 0.8; to: 1.8; value: libraryRoot.gridScale
                onMoved: libraryRoot.gridScale = value
                Layout.fillWidth: true
                visible: libraryRoot.isGridView
            }

            Button {
                text: "⚠️ Reset All Album Details"
                Layout.fillWidth: true
                onClicked: {
                    libraryModel.resetLibraryMetadata()
                    viewSettingsPopup.close()
                }
                background: Rectangle { radius: 4; color: parent.hovered ? "#ff4444" : "transparent"; border.color: "#ff4444"; border.width: 1 }
                contentItem: Text { text: parent.text; color: parent.hovered ? "white" : "#ff4444"; horizontalAlignment: Text.AlignHCenter; font.bold: true }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        opacity: libraryModel && libraryModel.isScanning ? 0.5 : 1.0

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: "Music Library"
                color: rootWindow.textMain
                font.pixelSize: 22 * libraryRoot.uiScale
                font.bold: true
                font.family: "Segoe UI"
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: searchBar
                Layout.preferredWidth: 200 * libraryRoot.uiScale
                placeholderText: "Search library..."
                color: rootWindow.textMain
                onTextChanged: libraryModel.filter(text)
                background: Rectangle { radius: 4; color: rootWindow.bgPanel; border.color: rootWindow.borderCol; border.width: 1 }
            }

            Button {
                text: "➕ Add Folder"
                onClicked: addFolderDialog.open()
                background: Rectangle { radius: 4; color: parent.hovered ? libraryRoot.hoverOverlay : "transparent"; border.color: rootWindow.borderCol; border.width: 1 }
                contentItem: Text { text: parent.text; color: rootWindow.textMain; horizontalAlignment: Text.AlignHCenter; font.bold: true }
            }

            Button {
                text: "🔍 Find Missing Art"
                onClicked: libraryModel.refetchMissingArt()
                background: Rectangle { radius: 4; color: parent.hovered ? libraryRoot.hoverOverlay : "transparent"; border.color: rootWindow.borderCol; border.width: 1 }
                contentItem: Text { text: parent.text; color: rootWindow.textMain; horizontalAlignment: Text.AlignHCenter; font.bold: true }
            }

            Button {
                text: "⚙️ Layout"
                onClicked: viewSettingsPopup.open()
                background: Rectangle { radius: 4; color: parent.hovered ? libraryRoot.hoverOverlay : "transparent"; border.color: rootWindow.borderCol; border.width: 1 }
                contentItem: Text { text: parent.text; color: rootWindow.textMain; horizontalAlignment: Text.AlignHCenter; font.bold: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "transparent"
            visible: !libraryRoot.isGridView

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 20
                spacing: 15

                Item { Layout.preferredWidth: 48 * libraryRoot.uiScale }
                Text { text: "#"; color: rootWindow.textSub; Layout.preferredWidth: 30 * libraryRoot.uiScale; font.pixelSize: 12; font.bold: true }
                Text { text: "Title"; color: rootWindow.textSub; Layout.fillWidth: true; font.pixelSize: 12; font.bold: true }
                Text { text: "Length"; color: rootWindow.textSub; Layout.preferredWidth: 60 * libraryRoot.uiScale; font.pixelSize: 12; visible: libraryRoot.showLength; font.bold: true }
                Text { text: "Artist"; color: rootWindow.textSub; Layout.preferredWidth: 150 * libraryRoot.uiScale; font.pixelSize: 12; visible: libraryRoot.showArtist; font.bold: true }
                Text { text: "Size"; color: rootWindow.textSub; Layout.preferredWidth: 60 * libraryRoot.uiScale; font.pixelSize: 12; visible: libraryRoot.showSize; font.bold: true }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: rootWindow.borderCol }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: libraryRoot.isGridView ? 1 : 0

            ListView {
                model: libraryModel
                clip: true
                spacing: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                section.property: "trackAlbum"
                section.delegate: Rectangle {
                    property real safeW: ListView.view && ListView.view.width ? ListView.view.width : 0
                    width: isNaN(safeW) ? 0 : safeW
                    height: 40 * libraryRoot.uiScale; color: "transparent"
                    Text {
                        text: section
                        color: settings && settings.accentColor ? settings.accentColor : rootWindow.textMain
                        font.bold: true
                        font.pixelSize: 13 * libraryRoot.uiScale
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                    }
                }

                delegate: Rectangle {
                    property real safeW: ListView.view && ListView.view.width ? ListView.view.width : 0
                    width: isNaN(safeW) ? 0 : safeW
                    height: 60 * libraryRoot.uiScale
                    color: ma.containsMouse ? libraryRoot.hoverOverlay : "transparent"

                    property bool isFirstInSection: ListView.previousSection !== ListView.section

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 20
                        spacing: 15

                        Item {
                            Layout.preferredWidth: 48 * libraryRoot.uiScale
                            Layout.preferredHeight: 48 * libraryRoot.uiScale
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                visible: isFirstInSection
                                radius: 6
                                color: rootWindow.bgSidebar
                                border.color: rootWindow.borderCol
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.centerIn: parent
                                    source: trackArt && !trackArt.startsWith("attachment://") ? trackArt : "logo.png"
                                    width: trackArt && !trackArt.startsWith("attachment://") ? parent.width : (28 * libraryRoot.uiScale)
                                    height: trackArt && !trackArt.startsWith("attachment://") ? parent.height : (28 * libraryRoot.uiScale)
                                    fillMode: trackArt && !trackArt.startsWith("attachment://") ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                    mipmap: true
                                }
                            }
                        }

                        Text { text: trackNumber; color: rootWindow.textMain; Layout.preferredWidth: 30 * libraryRoot.uiScale; font.pixelSize: 13 * libraryRoot.uiScale; clip: true }

                        // =========================================================
                        // NEW: PATH, FILETYPE, AND FILENAME DETAILS
                        // =========================================================
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: trackName;
                                color: rootWindow.textMain;
                                Layout.fillWidth: true;
                                elide: Text.ElideRight;
                                font.pixelSize: 13 * libraryRoot.uiScale;
                                font.family: "Segoe UI";
                                clip: true
                            }

                            Text {
                                text: {
                                    if (trackUrl.startsWith("cdda://")) return "CD AUDIO  •  " + trackUrl;
                                    // Decodes URL spaces (%20) and strips "file:///"
                                    var path = decodeURIComponent(trackUrl.replace(/^(file:\/{2,3})/, ""));
                                    var ext = path.substring(path.lastIndexOf('.') + 1).toUpperCase();
                                    return ext + "  •  " + path;
                                }
                                color: rootWindow.textSub
                                opacity: 0.6
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle // Truncates the middle so you always see Drive Letter and Filename
                                font.pixelSize: 10 * libraryRoot.uiScale
                                clip: true
                            }
                        }

                        Text { text: trackDuration; color: rootWindow.textSub; Layout.preferredWidth: 60 * libraryRoot.uiScale; visible: libraryRoot.showLength; font.pixelSize: 12 * libraryRoot.uiScale; font.family: "Consolas"; clip: true }
                        Text { text: trackArtist; color: rootWindow.textSub; Layout.preferredWidth: 150 * libraryRoot.uiScale; visible: libraryRoot.showArtist; elide: Text.ElideRight; font.pixelSize: 12 * libraryRoot.uiScale; clip: true }
                        Text { text: trackSize; color: rootWindow.textSub; Layout.preferredWidth: 60 * libraryRoot.uiScale; visible: libraryRoot.showSize; font.pixelSize: 12 * libraryRoot.uiScale; clip: true }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                trackContextMenu.trackIndex = index;
                                var pos = ma.mapToItem(libraryRoot, mouse.x, mouse.y);
                                trackContextMenu.x = pos.x;
                                trackContextMenu.y = pos.y;
                                trackContextMenu.open();
                            }
                        }
                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                player.playTrackList(libraryModel.getTrackUrls(), index);
                            }
                        }
                    }
                }
            }

            GridView {
                model: libraryModel
                clip: true
                cellWidth: (180 * libraryRoot.uiScale) * libraryRoot.gridScale
                cellHeight: (240 * libraryRoot.uiScale) * libraryRoot.gridScale

                Layout.fillWidth: true
                Layout.fillHeight: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 8
                        color: gridMa.containsMouse ? libraryRoot.hoverOverlay : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: width
                                radius: 8
                                color: rootWindow.bgSidebar
                                border.color: rootWindow.borderCol
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.centerIn: parent
                                    source: trackArt && !trackArt.startsWith("attachment://") ? trackArt : "logo.png"
                                    width: trackArt && !trackArt.startsWith("attachment://") ? parent.width : (parent.width * 0.5)
                                    height: trackArt && !trackArt.startsWith("attachment://") ? parent.height : (parent.height * 0.5)
                                    opacity: trackArt && !trackArt.startsWith("attachment://") ? 1.0 : 0.25
                                    fillMode: trackArt && !trackArt.startsWith("attachment://") ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                    mipmap: true
                                }
                            }
                            Text {
                                text: trackName; color: rootWindow.textMain; font.bold: true;
                                Layout.fillWidth: true; elide: Text.ElideRight;
                                font.pixelSize: 13 * libraryRoot.uiScale;
                                font.family: "Segoe UI"; horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                text: trackArtist; color: rootWindow.textSub; font.pixelSize: 11 * libraryRoot.uiScale;
                                Layout.fillWidth: true; visible: libraryRoot.showArtist;
                                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    MouseArea {
                        id: gridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                trackContextMenu.trackIndex = index;
                                var pos = gridMa.mapToItem(libraryRoot, mouse.x, mouse.y);
                                trackContextMenu.x = pos.x;
                                trackContextMenu.y = pos.y;
                                trackContextMenu.open();
                            }
                        }
                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                player.playTrackList(libraryModel.getTrackUrls(), index);
                            }
                        }
                    }
                }
            }
        }
    }
}
