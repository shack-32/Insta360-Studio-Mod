import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    property var viewModel: null

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    property var lutFiles: []
    property var lutLabels: []
    property int activeIndex: 0
    property bool isSwitching: false

    function getVm() {
        if (root.viewModel) return root.viewModel
        var p = root.parent
        while (p) {
            if (p.viewModel !== undefined && p.viewModel !== null) {
                return p.viewModel
            }
            p = p.parent
        }
        return null
    }

    // Color gradient palette for thumbnail swatches
    readonly property var colorPalette: [
        ["#2b5876", "#4e4376"], // 0: Rec.709
        ["#141E30", "#243B55"], // 1: Dark Night
        ["#8A2387", "#E94057"], // 2: Art
        ["#1f4037", "#99f2c8"], // 3: Walk In Park
        ["#0f2027", "#2c5364"], // 4: Blue Horror
        ["#4b6cb7", "#182848"], // 5: Blue Phantom
        ["#40E0D0", "#FF8C00"], // 6: Canon Cool Look
        ["#f857a6", "#ff5858"], // 7: Choi Hung Estate
        ["#00b09b", "#96c93d"], // 8: CineStill 800T
        ["#59C173", "#a17fe0"], // 9: Cool Natural Breeze
        ["#30E8CA", "#FF007F"], // 10: Day For Night
        ["#000428", "#004e92"], // 11: Night Vision IR
        ["#3E5151", "#DECBA4"], // 12: Exterior Daylight
        ["#5614B0", "#DBD65C"], // 13: Fuji Eterna 250D 3510
        ["#e65c00", "#F9D423"], // 14: Fuji Eterna 250D 2395
        ["#ED4264", "#FFEDBC"], // 15: Fuji F125 2393
        ["#FF512F", "#DD2476"], // 16: Fuji F125 2395
        ["#232526", "#414345"], // 17: Fuji Reala 500D 2393
        ["#4568DC", "#B06AB3"], // 18: HDR Punch
        ["#F3904F", "#3B4371"], // 19: Hyperlapse Vivid
        ["#1D976C", "#93F9B9"], // 20: Interior Ambient
        ["#EB5757", "#000000"], // 21: Interview Cool
        ["#0575E6", "#00F260"], // 22: Johnny Isaya Tone
        ["#780206", "#061161"], // 23: Kodak 5205 3510
        ["#CC95C0", "#DBD4B4"], // 24: Kodak 5218 2383
        ["#74ebd5", "#ACB6E5"], // 25: Kodak 5218 2395
        ["#FFE000", "#799F0C"], // 26: Kodak 2383 Film
        ["#ffe259", "#ffa751"], // 27: Warm Amber Glow
        ["#00c6ff", "#0072ff"], // 28: Lucky Punch
        ["#B993D6", "#8CA6DB"], // 29: Cinema G2 Look
        ["#f12711", "#f5af19"], // 30: Merry Men Rich
        ["#11998e", "#38ef7d"], // 31: Night City Lights
        ["#FC5C7D", "#6A82FB"], // 32: Cinematic Golden Hour
        ["#108dc7", "#ef8e38"], // 33: SMD Film Color
        ["#c21500", "#ffc500"], // 34: TDH Rich Contrast
        ["#614385", "#516395"], // 35: Gamma Correct Film
        ["#02AAB0", "#00CDAC"], // 36: Vivid Daylight
        ["#e9d362", "#333333"]  // 37: X5 Official I-Log
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

    Timer {
        id: reloadTimer
        interval: 80
        repeat: false
        property var targetVm: null
        onTriggered: {
            if (targetVm) {
                targetVm.modifyLutEnable(true)
            }
        }
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
                var vm = root.getVm()
                if (vm) {
                    vm.modifyLutEnable(false)
                    reloadTimer.targetVm = vm
                    reloadTimer.restart()
                }
            }
        }
        xhr.send()
    }

    // Auto-refresh timer to dynamically rescan directory
    Timer {
        id: autoRefreshTimer
        interval: 3500
        repeat: true
        running: true
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

        // Scrollable Grid: exactly 4 cards per row
        Flickable {
            id: gridFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(cardGrid.height, 175)
            contentWidth: width
            contentHeight: cardGrid.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: gridScrollBar
                policy: gridFlickable.contentHeight > gridFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                width: 4
            }

            Grid {
                id: cardGrid
                width: gridFlickable.width - (gridScrollBar.visible ? gridScrollBar.width + 4 : 0)
                columns: 4
                rowSpacing: 8
                columnSpacing: 6

                Repeater {
                    model: root.lutLabels.length > 0 ? root.lutLabels : [
                        "Stock Rec.709", "Dark Night", "Art LUTs", "A Walk",
                        "Blue Horror", "Blue Phantom", "Canon Cool", "Choi Hung"
                    ]

                    delegate: Item {
                        width: Math.floor((cardGrid.width - (3 * cardGrid.columnSpacing)) / 4)
                        height: 52

                        property var grad: root.getGradientColors(index)
                        property string cardLabel: {
                            var n = modelData || ""
                            if (n.indexOf(" ") > 0) {
                                var parts = n.split(" ")
                                return parts[0].length <= 7 ? parts[0] : parts[0].substring(0, 6) + ".."
                            }
                            return n.length <= 8 ? n : n.substring(0, 7) + ".."
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 3

                            Rectangle {
                                width: parent.width
                                height: 34
                                radius: 6
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: grad.c1 }
                                    GradientStop { position: 1.0; color: grad.c2 }
                                }

                                // Hover brightness
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: "#ffffff"
                                    opacity: cardMouseArea.containsMouse && root.activeIndex !== index ? 0.15 : 0.0
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
                                    id: cardMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        lutCombo.currentIndex = index
                                        root.applyLut(index)
                                    }
                                }
                            }

                            Text {
                                text: cardLabel
                                color: root.activeIndex === index ? "#ffcc00" : "#8e8e93"
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.width
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
                    implicitHeight: Math.min(contentItem.implicitHeight, 240)
                    padding: 4
                    onAboutToShow: root.refreshLutList()

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
                    id: itemDlg
                    width: lutCombo.width - 8
                    height: 26
                    text: modelData || ""

                    contentItem: Text {
                        text: itemDlg.text
                        color: itemDlg.highlighted ? "#ffcc00" : "#e0e0e0"
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        leftPadding: 6
                    }

                    background: Rectangle {
                        color: itemDlg.highlighted ? "#2c2c2e" : "transparent"
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
