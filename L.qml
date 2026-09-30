import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import InsUI 1.0

Item {
    id: contentRoot
    property var viewModel

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    property var lutFiles: []
    property var lutLabels: []
    property int activeIndex: 0
    property bool isSwitching: false

    function refreshLutList() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8999/list", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    contentRoot.lutFiles = data.files
                    contentRoot.lutLabels = data.labels
                    contentRoot.activeIndex = data.active_index
                    lutCombo.model = data.labels
                    if (data.active_index >= 0 && data.active_index < data.labels.length) {
                        lutCombo.currentIndex = data.active_index
                    }
                } catch(e) {}
            }
        }
        xhr.send()
    }

    function applyLutByIndex(index) {
        if (contentRoot.isSwitching) return
        contentRoot.isSwitching = true
        contentRoot.activeIndex = index

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8999/switch?index=" + index, true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                contentRoot.isSwitching = false
                if (xhr.status === 200 && contentRoot.viewModel) {
                    contentRoot.viewModel.modifyLutEnable(false)
                    contentRoot.viewModel.modifyLutEnable(true)
                }
            }
        }
        xhr.send()
    }

    Component.onCompleted: {
        refreshLutList()
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        spacing: 10

        // Quick Preset Cards (Styled like AquaVision)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { name: "Rec.709", idx: 0, color: "#4a90e2" },
                    { name: "Kodak",   idx: 1, color: "#d4a373" },
                    { name: "CineStill", idx: 2, color: "#e76f51" },
                    { name: "Night",   idx: 3, color: "#2a9d8f" }
                ]

                delegate: Item {
                    width: 52
                    height: 56

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Rectangle {
                            width: 48
                            height: 34
                            radius: 6
                            color: modelData.color

                            // Active Yellow Highlight Border (AquaVision style)
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.color: InsUI.colorBrand
                                border.width: 2
                                visible: contentRoot.activeIndex === modelData.idx
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lutCombo.currentIndex = modelData.idx
                                    contentRoot.applyLutByIndex(modelData.idx)
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            color: contentRoot.activeIndex === modelData.idx ? InsUI.colorBrand : InsUI.colorStandardSubtext
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // Full Look Dropdown Selector
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            Text {
                Layout.preferredWidth: 42
                text: "Look"
                color: InsUI.colorStandardSubtext
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            ComboBox {
                id: lutCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                model: ["Stock Rec.709"]

                background: Rectangle {
                    color: "#242426"
                    radius: 4
                    border.color: lutCombo.activeFocus ? InsUI.colorBrand : "#3a3a3c"
                    border.width: 1
                }

                contentItem: Text {
                    leftPadding: 8
                    rightPadding: lutCombo.indicator.width + 10
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
                    height: 26

                    contentItem: Text {
                        text: modelData
                        color: highlighted ? InsUI.colorBrand : "#e0e0e0"
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
                    contentRoot.applyLutByIndex(index)
                }
            }
        }
    }
}
