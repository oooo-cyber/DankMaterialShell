import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410

    property var wallpaperList: []
    property string wallpaperDir: ""
    property int currentPage: 0
    property int itemsPerPage: 16
    property int totalPages: Math.max(1, Math.ceil(wallpaperList.length / itemsPerPage))
    property bool active: false
    property Item focusTarget: wallpaperGrid
    property Item tabBarItem: null

    onVisibleChanged: {
        if (visible && active) {
            Qt.callLater(() => setInitialSelection())
        }
    }

    Component.onCompleted: {
        loadWallpapers()
        if (visible && active) {
            Qt.callLater(() => setInitialSelection())
        }
    }

    onActiveChanged: {
        if (active && visible) {
            Qt.callLater(() => setInitialSelection())
        } else {
            wallpaperGrid.focus = false
        }
    }

    function requestFocus() {
        if (!root.active || !root.visible) return
        wallpaperGrid.focus = true
        Qt.callLater(() => wallpaperGrid.forceActiveFocus())
    }

    function setInitialSelection() {
        if (!SessionData.wallpaperPath) return

        const startIndex = currentPage * itemsPerPage
        const endIndex = Math.min(startIndex + itemsPerPage, wallpaperList.length)
        const pageWallpapers = wallpaperList.slice(startIndex, endIndex)

        for (let i = 0; i < pageWallpapers.length; i++) {
            if (pageWallpapers[i] === SessionData.wallpaperPath) {
                wallpaperGrid.currentIndex = i
                return
            }
        }
    }

    onWallpaperListChanged: {
        if (visible && active) {
            Qt.callLater(() => setInitialSelection())
        }
    }

    function loadWallpapers() {
        const currentWallpaper = SessionData.wallpaperPath
        if (!currentWallpaper || currentWallpaper.startsWith("#") || currentWallpaper.startsWith("we:")) {
            wallpaperDir = ""
            wallpaperList = []
            return
        }

        wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
        wallpaperProcess.running = true
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            loadWallpapers()
        }
    }

    Process {
        id: wallpaperProcess
        command: wallpaperDir ? ["sh", "-c", `ls -1 "${wallpaperDir}"/*.jpg "${wallpaperDir}"/*.jpeg "${wallpaperDir}"/*.png "${wallpaperDir}"/*.bmp "${wallpaperDir}"/*.gif "${wallpaperDir}"/*.webp 2>/dev/null | sort`] : []
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim()) {
                    const files = text.trim().split('\n').filter(file => file.length > 0)
                    wallpaperList = files

                    const currentPath = SessionData.wallpaperPath
                    const selectedIndex = currentPath ? wallpaperList.indexOf(currentPath) : -1

                    if (selectedIndex >= 0) {
                        currentPage = Math.floor(selectedIndex / itemsPerPage)
                    } else {
                        const maxPage = Math.max(0, Math.ceil(files.length / itemsPerPage) - 1)
                        currentPage = Math.min(Math.max(0, currentPage), maxPage)
                    }
                } else {
                    wallpaperList = []
                    currentPage = 0
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        Item {
            width: parent.width
            height: parent.height - 50

            GridView {
                id: wallpaperGrid
                anchors.centerIn: parent
                width: parent.width - Theme.spacingS
                height: parent.height - Theme.spacingS
                cellWidth: width / 4
                cellHeight: height / 4
                clip: true
                enabled: root.active
                interactive: root.active
                boundsBehavior: Flickable.StopAtBounds
                focus: root.active
                keyNavigationEnabled: root.active
                keyNavigationWraps: true
                highlightFollowsCurrentItem: true
                currentIndex: 0
                KeyNavigation.backtab: root.tabBarItem
                KeyNavigation.up: root.tabBarItem

                highlight: Rectangle {
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.primary
                    radius: Theme.cornerRadius

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        const item = wallpaperGrid.currentItem
                        if (item && item.wallpaperPath) {
                            SessionData.setWallpaper(item.wallpaperPath)
                        }
                    }
                }

                Keys.onPressed: (event) => {
                    const columns = 4

                    if (event.key === Qt.Key_PageUp) {
                        if (currentPage > 0) {
                            currentPage--
                            wallpaperGrid.currentIndex = 0
                            event.accepted = true
                        }
                    } else if (event.key === Qt.Key_PageDown) {
                        if (currentPage < totalPages - 1) {
                            currentPage++
                            wallpaperGrid.currentIndex = 0
                            event.accepted = true
                        }
                    } else if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) {
                        currentPage = 0
                        wallpaperGrid.currentIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) {
                        currentPage = totalPages - 1
                        wallpaperGrid.currentIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up && root.tabBarItem && (currentIndex < columns || currentIndex === -1)) {
                        wallpaperGrid.focus = false
                        root.tabBarItem.forceActiveFocus()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier) && root.tabBarItem) {
                        wallpaperGrid.focus = false
                        root.tabBarItem.forceActiveFocus()
                        event.accepted = true
                    }
                }

                model: {
                    const startIndex = currentPage * itemsPerPage
                    const endIndex = Math.min(startIndex + itemsPerPage, wallpaperList.length)
                    return wallpaperList.slice(startIndex, endIndex)
                }

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    property string wallpaperPath: modelData || ""
                    property bool isSelected: SessionData.wallpaperPath === modelData

                    Rectangle {
                        id: wallpaperCard
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        color: Theme.surfaceContainerHighest
                        radius: Theme.cornerRadius
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                            radius: parent.radius

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Image {
                            id: thumbnailImage
                            anchors.fill: parent
                            source: modelData ? `file://${modelData}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: thumbnailImage.width
                                        height: thumbnailImage.height
                                        radius: Theme.cornerRadius
                                    }
                                }
                            }
                        }

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: thumbnailImage.status === Image.Loading
                            visible: running
                        }

                        StateLayer {
                            anchors.fill: parent
                            cornerRadius: parent.radius
                            stateColor: Theme.primary
                        }

                        MouseArea {
                            id: wallpaperMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                wallpaperGrid.currentIndex = index
                                root.requestFocus()
                                if (modelData) {
                                    SessionData.setWallpaper(modelData)
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: wallpaperList.length === 0
                text: "No wallpapers found\n\nSet a wallpaper path first"
                font.pixelSize: 14
                color: Theme.outline
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            width: parent.width
            height: 50
            spacing: Theme.spacingS

            Item {
                width: (parent.width - controlsRow.width) / 2
                height: parent.height
            }

            Row {
                id: controlsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "skip_previous"
                    iconSize: 20
                    buttonSize: 32
                    enabled: currentPage > 0
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (currentPage > 0) {
                            currentPage--
                        }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wallpaperList.length > 0 ? `${wallpaperList.length} wallpapers  •  ${currentPage + 1} / ${totalPages}` : "No wallpapers"
                    font.pixelSize: 14
                    color: Theme.surfaceText
                    opacity: 0.7
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "skip_next"
                    iconSize: 20
                    buttonSize: 32
                    enabled: currentPage < totalPages - 1
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (currentPage < totalPages - 1) {
                            currentPage++
                        }
                    }
                }
            }
        }
    }
}