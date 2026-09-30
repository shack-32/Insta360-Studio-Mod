import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    property var viewModel

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    property var lutFiles: []
    property var lutLabels: []
    property int activeIndex: 0
    property bool isSwitching: false

    // Color gradient palette for thumbnail swatches
    readonly property var colorPalette: [
        ["#2b5876", "#4e4376"], // Rec.709
        ["#e65c00", "#F9D423"], // Kodak
        ["#00b09b", "#96c93d"], // CineStill
        ["#0f2027", "#2c5364"], // Night
        ["#8A2387", "#E94057"], // Art
        ["#141E30", "#243B55"], // Dark
        ["#ED4264", "#FFEDBC"], // Warm
        ["#1f4037", "#99f2c8"], // Forest
        ["#4b6cb7", "#182848"], // Deep Blue
        ["#f857a6", "#ff5858"], // Sunset
        ["#232526", "#414345"], // Monochrome
        ["#4568DC", "#B06AB3"], // Purple
        ["#1D976C", "#93F9B9"], // Emerald
        ["#EB5757", "#000000"], // Contrast
        ["#FF512F", "#DD2476"], // Vivid
        ["#000428", "#004e92"], // Midnight
        ["#40E0D0", "#FF8C00"], // Teal Orange
        ["#3E5151", "#DECBA4"], // Vintage
        ["#5614B0", "#DBD65C"], // Cyber
        ["#000000", "#434343"], // Film Noir
        ["#59C173", "#a17fe0"], // Pastel
        ["#30E8CA", "#FF007F"], // Synthwave
        ["#0575E6", "#00F260"], // Oceanic
        ["#780206", "#061161"], // Dramatic
        ["#F3904F", "#3B4371"]  // Dusk
    ]

    function getGradientColors(idx) {
        var p = colorPalette[idx % colorPalette.length]
        return { c1: p[0], c2: p[1] }
    }

    function refreshLutList() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8999/list", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    root.lutFiles = data.files
                    root.lutLabels = data.labels
                    root.activeIndex = data.active_index
                    lutCombo.model = data.labels
                    if (data.active_index >= 0 && data.active_index < data.labels.length) {
                        lutCombo.currentIndex = data.active_index
                    }
                } catch(e) {}
            }
        }
        xhr.send()
    }

    function applyLut(index) {
        if (root.isSwitching) return
        root.isSwitching = true
        root.activeIndex = index

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8999/switch?index=" + index, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                root.isSwitching = false
                if (root.viewModel) {
                    root.viewModel.modifyLutEnable(false)
                    root.viewModel.modifyLutEnable(true)
                }
            }
        }
        xhr.send()
    }

    // Auto-retry polling if list not loaded yet
    Timer {
        id: retryTimer
        interval: 1200
        repeat: true
        running: root.lutFiles.length === 0
        onTriggered: {
            root.refreshLutList()
        }
    }

    Component.onCompleted: {
        refreshLutList()
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        spacing: 8

        // Scrollable Grid of 4 cards per row
        Flickable {
            id: gridFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight > 165 ? 165 : contentHeight
            contentWidth: width
            contentHeight: cardFlow.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: gridFlickable.contentHeight > gridFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                width: 4
            }

            Flow {
                id: cardFlow
                width: gridFlickable.width
                spacing: 6

                Repeater {
                    model: root.lutLabels.length > 0 ? root.lutLabels : [
                        "Stock Rec.709", "Kodak 2383", "CineStill 800T", "Night Vision",
                        "Art LUTs", "Blue Phantom", "Day For Night", "Teal Orange"
                    ]

                    delegate: Item {
                        width: Math.floor((cardFlow.width - 18) / 4)
                        height: 54

                        property var grad: root.getGradientColors(index)
                        property string displayName: {
                            var n = modelData
                            if (n.indexOf(" ") > 0) {
                                var parts = n.split(" ")
                                return parts[0].length <= 7 ? parts[0] : parts[0].substring(0, 6) + ".."
                            }
                            return n.length <= 8 ? n : n.substring(0, 7) + ".."
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3

                            Rectangle {
                                width: parent.parent.width
                                height: 34
                                radius: 6
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: grad.c1 }
                                    GradientStop { position: 1.0; color: grad.c2 }
                                }

                                // Active Yellow Border (AquaVision style)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: "transparent"
                                    border.color: "#ffcc00"
                                    border.width: 2
                                    visible: root.activeIndex === index
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lutCombo.currentIndex = index
                                        root.applyLut(index)
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: displayName
                                color: root.activeIndex === index ? "#ffcc00" : "#8e8e93"
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.parent.width
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }

        // Full Look Dropdown Selector
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            Text {
                Layout.preferredWidth: 36
                text: "Look"
                color: "#8e8e93"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            ComboBox {
                id: lutCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                model: root.lutLabels.length > 0 ? root.lutLabels : ["Stock Rec.709"]

                background: Rectangle {
                    color: "#242426"
                    radius: 4
                    border.color: lutCombo.activeFocus ? "#ffcc00" : "#3a3a3c"
                    border.width: 1
                }

                contentItem: Text {
                    leftPadding: 8
                    rightPadding: 24
                    text: lutCombo.displayText
                    color: "#ffffff"
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                popup: Popup {
                    y: lutCombo.height + 2
                    width: lutCombo.width
                    implicitHeight: contentItem.implicitHeight > 220 ? 220 : contentItem.implicitHeight
                    padding: 4

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: lutCombo.popup.visible ? lutCombo.delegateModel : null
                        currentIndex: lutCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }

                    background: Rectangle {
                        color: "#1c1c1e"
                        radius: 6
                        border.color: "#3a3a3c"
                        border.width: 1
                    }
                }

                delegate: ItemDelegate {
                    width: lutCombo.width - 8
                    height: 24

                    contentItem: Text {
                        text: modelData
                        color: highlighted ? "#ffcc00" : "#e0e0e0"
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: highlighted ? "#2c2c2e" : "transparent"
                        radius: 4
                    }

                    highlighted: lutCombo.highlightedIndex === index
                }

                onActivated: function(index) {
                    root.applyLut(index)
                }
            }
        }
    }
}
