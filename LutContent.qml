import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import InsTS 1.0
import InsUI 1.0
import Common.ViewModel 1.0

import "qrc:/qml/ins_control/common/text"
import "qrc:/qml/ins_control/common/input"

Item {
    id: contentRoot
    property MediaProcessViewModel viewModel

    implicitWidth: mainCol.implicitWidth
    implicitHeight: mainCol.implicitHeight

    property var lutFiles: []
    property bool isSwitching: false

    function refreshLutList() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://127.0.0.1:8999/list", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    contentRoot.lutFiles = data.files
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
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 8

            InsLabel {
                Layout.preferredWidth: 60
                Layout.fillHeight: true
                colorNormal: InsUI.colorStandardSubtext
                text: "Look"
            }

            InsComboBox {
                id: lutCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                popupWidth: 160
                popupAlignRight: true
                radius: InsUI.radiusSmall
                arrowType: InsComboBox.ArrowType.DoubleArrow
                arrowSize: 16
                arrowColor: Qt.rgba(190 / 255, 190 / 255, 192 / 255)
                model: ["Stock Rec.709"]

                onActivated: function(index) {
                    contentRoot.applyLutByIndex(index)
                }
            }
        }
    }
}
