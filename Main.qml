import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import SaberPlayer 1.0

ApplicationWindow {
    id: rootWindow

    // SMOOTH WINDOW RESIZING
    width: isMiniPlayer ? 650 : 1200
    height: isMiniPlayer ? 120 : 800
    minimumWidth: isMiniPlayer ? 650 : 800
    minimumHeight: isMiniPlayer ? 120 : 600

    // Cinematic morphing animations for the physical window!
    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
    Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
    Behavior on minimumWidth { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }
    Behavior on minimumHeight { NumberAnimation { duration: 450; easing.type: Easing.InOutQuint } }

    visible: true
    title: qsTr("SaberPlayer")
    color: bgMain

    flags: isMiniPlayer ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint) : Qt.Window

    property int activeScreen: 0
    property bool isMiniPlayer: cmdStartMini

    property bool isDark: settingsManager.themeMode === "Dark"
    property color bgMain: isDark ? "#0a0a0a" : "#f0f2f5"
    property color bgPanel: isDark ? "#151515" : "#ffffff"
    property color bgSidebar: isDark ? "#111111" : "#e4e8ec"
    property color borderCol: isDark ? "#2a2a2a" : "#d1d9e0"
    property color textMain: isDark ? "#ffffff" : "#111111"
    property color textSub: isDark ? "#888888" : "#666666"

    PlayerController { id: playerController }
    SettingsManager { id: settingsManager }
    LibraryModel { id: libModel }
    CdManager { id: cdManager }

    Component.onCompleted: {
        if (cmdStartFile !== "") {
            playerController.loadFile(cmdStartFile)
        }
    }

    Item {
        anchors.fill: parent

        SideBar {
            id: sideBar
            visible: !rootWindow.isMiniPlayer
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            z: 10

            settings: settingsManager
            currentTab: rootWindow.activeScreen

            onTabClicked: function(index) {
                if (index === 1 && libModel.rowCount() === 0) {
                    libModel.scanLibrary()
                }
                rootWindow.activeScreen = index
            }
            onOpenSettings: {
                settingsPopup.open()
            }
        }

        Item {
            id: contentArea
            visible: !rootWindow.isMiniPlayer
            anchors.top: parent.top
            anchors.bottom: controlDeck.top
            anchors.left: sideBar.right
            anchors.right: parent.right

            StackLayout {
                anchors.fill: parent
                currentIndex: rootWindow.activeScreen

                CentralDisplay { player: playerController; settings: settingsManager }
                LibraryView { player: playerController; settings: settingsManager; libraryModel: libModel }
                Rectangle { color: "transparent"; Text { anchors.centerIn: parent; text: "Playlists\n(Coming Soon)"; color: textSub; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter } }
                CdView { player: playerController; settings: settingsManager; cdManager: cdManager }
            }
        }

        Item {
            id: bottomTriggerArea
            visible: !rootWindow.isMiniPlayer
            anchors.bottom: parent.bottom
            anchors.left: sideBar.right
            anchors.right: parent.right
            height: 140
            HoverHandler {
                id: bottomHover
            }
        }

        ControlDeck {
            id: controlDeck
            anchors.left: rootWindow.isMiniPlayer ? parent.left : sideBar.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            height: rootWindow.isMiniPlayer ? rootWindow.height : 90
            z: 5

            property bool hideDeck: !rootWindow.isMiniPlayer && (rootWindow.activeScreen === 0) && !bottomHover.hovered && !isHovered

            anchors.bottomMargin: hideDeck ? -90 : 0
            opacity: hideDeck ? 0.0 : 1.0

            Behavior on anchors.bottomMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
            Behavior on opacity { NumberAnimation { duration: 300 } }

            player: playerController
            settings: settingsManager
            appFileDialog: fileDialog

            isMiniPlayer: rootWindow.isMiniPlayer

            onToggleMiniPlayer: {
                if (rootWindow.isMiniPlayer) {
                    rootWindow.flags = Qt.Window
                    rootWindow.isMiniPlayer = false
                } else {
                    rootWindow.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
                    rootWindow.isMiniPlayer = true
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        onAccepted: {
            playerController.loadFile(selectedFile)
        }
    }

    Popup {
        id: settingsPopup
        anchors.centerIn: parent
        width: 380
        height: 520
        modal: true
        background: Rectangle {
            color: bgPanel
            radius: 12
            border.width: 1
            border.color: settingsManager.accentColor
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 20

            Text { text: "Settings"; color: textMain; font.pixelSize: 22; font.bold: true }

            RowLayout {
                spacing: 15
                Text { text: "App Theme:"; color: textMain; font.pixelSize: 14; Layout.preferredWidth: 120 }
                ComboBox {
                    Layout.fillWidth: true
                    model: ["Dark", "Light"]
                    currentIndex: settingsManager.themeMode === "Dark" ? 0 : 1
                    onActivated: { settingsManager.themeMode = currentText }
                }
            }

            RowLayout {
                spacing: 15
                Text { text: "Visualizer Style:"; color: textMain; font.pixelSize: 14; Layout.preferredWidth: 120 }
                ComboBox {
                    Layout.fillWidth: true
                    model: ["Mirrored", "Bottom Bars", "Floating Dots"]
                    currentIndex: model.indexOf(settingsManager.visualizerStyle)
                    onActivated: { settingsManager.visualizerStyle = currentText }
                }
            }

            Text { text: "Accent Color:"; color: textMain; font.pixelSize: 14; Layout.topMargin: 10 }
            RowLayout {
                spacing: 10
                Repeater {
                    model: ["#0055FF", "#FF2255", "#00CC66", "#FF9900", "#9933FF"]
                    delegate: Rectangle {
                        width: 35; height: 35; radius: 17.5; color: modelData
                        border.width: settingsManager.accentColor === modelData ? 3 : 0
                        border.color: textMain
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { settingsManager.accentColor = modelData }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 1; color: borderCol
                Layout.topMargin: 10; Layout.bottomMargin: 5
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Auto-Play Next File"; color: textMain; font.pixelSize: 14; Layout.fillWidth: true }
                Switch { checked: settingsManager.autoPlay; onCheckedChanged: { settingsManager.autoPlay = checked } }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Show in Windows Right-Click Menu"; color: textMain; font.pixelSize: 14; Layout.fillWidth: true }
                Switch { checked: settingsManager.contextMenuEnabled; onCheckedChanged: { settingsManager.contextMenuEnabled = checked } }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Minimize to System Tray"; color: textMain; font.pixelSize: 14; Layout.fillWidth: true }
                Switch { checked: settingsManager.minimizeToTray; onCheckedChanged: { settingsManager.minimizeToTray = checked } }
            }

            Item { Layout.fillHeight: true }

            Button {
                text: "Refresh Library"
                Layout.fillWidth: true
                onClicked: { libModel.scanLibrary() }
                background: Rectangle {
                    radius: 6; color: parent.hovered ? settingsManager.accentColor : borderCol
                }
                contentItem: Text {
                    text: parent.text; color: isDark ? "white" : (parent.parent.hovered ? "white" : "black")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true
                }
            }
        }
    }
}
