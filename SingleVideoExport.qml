import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import Common.Enums 1.0
import InsTS 1.0
import InsUI 1.0

import "../../ins_control/common/button"
import "../../ins_control/common/check_box"
import "../../ins_control/common/container"
import "../../ins_control/common/text"
import "../../ins_control/common/slider"
import "../../ins_control/common/popup"
import "../../ins_control/common/tip"
import "../../ins_control/custom/"
import "../../media_tab/export/modules"

Item {
    id: root

    property var model: VideoExportViewModel
    property int itemHeight: 46
    readonly property int curEncodeFormat: root.model.encodeFormatList ? root.model.encodeFormatList.currentId : -1
    readonly property bool needScrollBar: mainGrid.implicitHeight > scrollView.height
    property string pendingDeletePresetName: ""
    property int mediaTypeCount: 1

    readonly property int footerDurationFrames: model.exportFrames
    readonly property string footerEstimateFileSize: model.estimateFileSizeStr
    readonly property bool showVideoExportOptions: !model.exportTrimSource
    readonly property bool showCustomResolution: root.showVideoExportOptions && root.model.resolutionTypeList
        && root.resolveResolutionTypeId(root.model.resolutionTypeList.currentId) === 0
    readonly property bool showHighResolutionWarning: model.exportPano
        && Math.max(model.outputWidth, model.outputHeight) >= 8000
        && Math.max(model.outputWidth, model.outputHeight) <= 16000

    function onDialogClosing() {
        model.saveCustomPreset()
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.rightMargin: 0
        clip: false
        Component.onCompleted: scrollView.contentItem.clip = true
        contentWidth: root.needScrollBar ? (availableWidth - 10) : availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: InsScrollBar {
            policy: root.needScrollBar ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width : 10
            height: scrollView.height
            x: scrollView.width - 10
            y: 0
        }

        TapHandler {
            onTapped: {
                // 点击无焦点消费的组件时，文本框输入完成，失去焦点
                root.forceActiveFocus()
            }
        }

        GridLayout {
            id: mainGrid
            // 左右各内缩 50px
            x: 50
            width: scrollView.contentWidth - 100
            height: root.needScrollBar ? implicitHeight : scrollView.height
            implicitHeight: childrenRect.height

            columns: 2
            columnSpacing: 8
            rowSpacing: 0

            // Row 0: 导出为
            InsLabel {
                Layout.row: 0
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: model.isPanoSource
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export_panel.export_as.title") + ":"
            }

            RowLayout {
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: itemHeight
                visible: model.isPanoSource

                InsRadioButton {
                    id: planRadio
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    buttonText: TS.insTr("export_panel.export_as.plane")
                    checked: !model.exportPano
                    onSelected: {
                        console.log("planeRadio selected")
                        model.modifyExportPano(false)
                    }
                }

                InsRadioButton {
                    id: panoRadio
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    buttonText: TS.insTr("export_panel.export_as.pano")
                    checked: model.exportPano
                    onSelected: {
                        console.log("panoRadio selected")
                        model.modifyExportPano(true)
                    }
                }
            }

            // Row 1: 文件名
            InsLabel {
                Layout.row: 1
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export.setting.info.file_name") + ":"
            }

            InsTextField {
                id: fileNameInput
                Layout.row: 1
                Layout.column: 1
                Layout.fillWidth: true
                backgroundColor: "#08090A"
                text: model.fileName
                restoreDefaultWhenEmpty: true
                validator: RegularExpressionValidator {
                    regularExpression: /^[^\\\*\/?<>|":]+$/
                }
            }

            // Row 2: 路径
            InsLabel {
                Layout.row: 2
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export.setting.info.file_path") + ":"
            }

            RowLayout {
                Layout.row: 2
                Layout.column: 1
                spacing: 8

                InsElidePathField {
                    id: filePathInput
                    Layout.fillWidth: true
                    text: model.filePath
                }

                InsButton {
                    id: pathBtn
                    text: TS.insTr("export.setting.info.modify")
                }
            }

            // Row 3: 发布至
            InsLabel {
                Layout.row: 3
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: root.model.showThirdPartyUpload
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export.setting.info.upload") + ":"
            }

            CustomUploadCombox {
                id: uploadCombox
                Layout.row: 3
                Layout.column: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: root.model.showThirdPartyUpload

                textRole: "key"
                valueRole: "value"

                function textByIndex(index) {
                    if (index === 0) return TS.insTr("export.setting.info.none")
                    if (index === 1) return TS.insTr("export.setting.info.douyin")
                    return ""
                }

                model: ListModel {
                    ListElement { key: "export.setting.info.none";   value: "";       platformIcon: "" }
                    ListElement { key: "export.setting.info.douyin"; value: "douyin"; platformIcon: "qrc:/image/account/douyin.png" }
                }
            }

            // Row 4: 分隔线
            Item {
                Layout.row: 4
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: root.showVideoExportOptions

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: "#1F2022"
                }
            }

            // Row 5: 预设
            InsLabel {
                Layout.row: 5
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: root.showVideoExportOptions
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export.setting.info.preset") + ":"
            }

            RowLayout {
                Layout.row: 5
                Layout.column: 1
                spacing: 8
                visible: root.showVideoExportOptions

                PresetComboBox {
                    id: presetCombox
                    Layout.fillWidth: true

                    textRole: "name"

                    function textByIndex(index) {
                        if (!model || index < 0) return ""
                        let v = model.data(model.index(index, 0), 0x101)
                        let builtIn = model.data(model.index(index, 0), 0x102)
                        if (builtIn === true) v = TS.insTr(v)
                        return v ? v : ""
                    }

                    model: root.model.presetList
                    enabled: count !== 1
                }

                InsButton {
                    id: presetBtn
                    text: TS.insTr("Save")
                    enabled: model.saveBtnEnabled
                    colorBtn: "#292D32"
                    colorBtnHover: "#292D32"
                    colorBtnPress: "#292D32"
                    colorBtnDisable: "#7E7E7F"
                    colorDuration: 0
                }
            }

            // Row 6-12: 视频参数区（带底色背景）
            Item {
                Layout.row: 6
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                implicitHeight: videoParamsGrid.implicitHeight
                visible: root.showVideoExportOptions

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height
                    color: "#101113"
                    radius: 4
                }

                GridLayout {
                    id: videoParamsGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 0

                    // Row 0 (原 Row 6): 分辨率下拉
                    InsLabel {
                        Layout.row: 0
                        Layout.column: 0
                        Layout.preferredWidth: 80
                        Layout.maximumWidth: 80
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredHeight: itemHeight
                        horizontalAlignment: Text.AlignLeft
                        color: InsUI.colorStandardSubtext
                        text: TS.insTr("export.setting.info.resolution") + ":"
                    }

                    InsComboBox {
                        id: resolutionCombox
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        textRole: "name"

                        function textByIndex(index) {
                            if (!model || index < 0) return ""
                            let v = model.data(model.index(index, 0), 0x101)
                            return v ? v : ""
                        }

                        model: root.model.resolutionTypeList
                    }

                    // Row 1 (原 Row 7): 宽 x 高输入框
                    Item {
                        id: resolutionInputRow
                        Layout.row: 1
                        Layout.column: 0
                        Layout.preferredWidth: 80
                        Layout.maximumWidth: 80
                        Layout.preferredHeight: itemHeight
                        visible: root.showCustomResolution
                    }

                    RowLayout {
                        Layout.row: 1
                        Layout.column: 1
                        spacing: 8
                        visible: root.showCustomResolution

                        InsTextField {
                            id: widthInput
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            visible: root.showCustomResolution
                            text: model.outputWidth
                            horizontalAlignment: Text.AlignHCenter
                            maximumLength: 5
                            validator: RegularExpressionValidator {
                                regularExpression: /[0-9]*/
                            }
                        }

                        InsLabel {
                            id: resolution_x
                            visible: root.showCustomResolution
                            text: "X"
                            color: InsUI.colorStandardSubtext
                        }

                        InsTextField {
                            id: heightInput
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            visible: root.showCustomResolution
                            text: model.outputHeight
                            horizontalAlignment: Text.AlignHCenter
                            maximumLength: 5
                            validator: RegularExpressionValidator {
                                regularExpression: /[0-9]*/
                            }
                        }
                    }

                    // Row 2: 16K高分辨率导出警告
                    InsLabel {
                        Layout.row: 2
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.preferredHeight: Math.max(25, implicitHeight)
                        visible: root.showHighResolutionWarning
                        color: "#F64F4E"
                        elide: Text.ElideNone
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignLeft
                        text: TS.insTr("export.setting.resolution_warning")
                    }

                    // Row 3: 帧率
                    InsLabel {
                        Layout.row: 3
                        Layout.column: 0
                        Layout.preferredWidth: 80
                        Layout.maximumWidth: 80
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredHeight: itemHeight
                        horizontalAlignment: Text.AlignLeft
                        color: InsUI.colorStandardSubtext
                        text: TS.insTr("export.setting.info.fps") + ":"
                    }

                    InsComboBox {
                        id: fpsCombox
                        Layout.row: 3
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        textRole: "name"

                        function textByIndex(index) {
                            if (!model || index < 0) return ""
                            let v = model.data(model.index(index, 0), 0x101)
                            return v ? v : ""
                        }

                        model: root.model.frameRateList
                    }

                    // Row 4: 码率(Mbps)
                    InsLabel {
                        Layout.row: 4
                        Layout.column: 0
                        Layout.preferredWidth: 80
                        Layout.maximumWidth: 80
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredHeight: itemHeight
                        horizontalAlignment: Text.AlignLeft
                        visible: root.model.showBitrateControl
                        color: InsUI.colorStandardSubtext
                        text: TS.insTr("export.setting.info.bitrate") + "(Mbps):"
                    }

                    InsComboBox {
                        id: bitrateTypeCombox
                            Layout.row: 4
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        visible: root.model.showBitrateControl

                        textRole: "name"

                        function textByIndex(index) {
                            if (!model || index < 0) return ""
                            let v = model.data(model.index(index, 0), 0x101)
                            return v ? v : ""
                        }

                        model: root.model.bitrateTypeList
                    }

                    // Row 5: 码率滑块 + 数值输入框
                    Item {
                        Layout.row: 5
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 25
                        visible: root.model.showBitrateControl

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            InsSlider {
                                id: bitrateSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 25
                                Layout.leftMargin: 8
                                from: 0
                                to: 200
                                value: root.model.bitrate
                                stepSize: 1
                                handleSize: 10

                                Image {
                                    id: recommendStarMarker
                                    visible: root.model.showRecommendStar && root.model.recommendBitrate >= 0 && root.model.recommendBitrate <= 200
                                    width: 10
                                    height: 10
                                    source: starHoverArea.containsPress || starHoverArea.containsMouse
                                            ? "qrc:/image/other/export_bitrate_star_hover_or_press.svg"
                                            : "qrc:/image/other/export_bitrate_star_normal.svg"
                                    x: (root.model.recommendBitrate - bitrateSlider.from) / (bitrateSlider.to - bitrateSlider.from) * (bitrateSlider.width - 10)
                                    y: bitrateSlider.height / 2 - 5

                                    MouseArea {
                                        id: starHoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        propagateComposedEvents: true

                                        readonly property bool handleOverlaps: Math.round(bitrateSlider.value) === root.model.recommendBitrate

                                        onClicked: function(mouse) {
                                            if (handleOverlaps) { mouse.accepted = false; return }
                                            root.model.modifyBitrate(root.model.recommendBitrate)
                                            mouse.accepted = true
                                        }
                                        onPressed: function(mouse) {
                                            mouse.accepted = !handleOverlaps
                                        }
                                    }
                                }

                                onMoved: {
                                    var v = Math.round(value)
                                    if (v < 1) v = 1
                                    root.model.modifyBitrate(v)
                                }
                            }

                            InsTextField {
                                id: bitrateInput
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 25
                                horizontalAlignment: Text.AlignHCenter
                                text: Math.round(root.model.bitrate)
                                maximumLength: 3
                                validator: RegularExpressionValidator {
                                    regularExpression: /^[0-9]{0,3}$/
                                }

                                onTextEdited: {
                                    if (text === "") return
                                    var v = parseInt(text) || 0
                                    if (v > 200) {
                                        v = 200
                                    }else if(v === 0){
                                        v = 1
                                    }
                                    text = String(v)
                                    root.model.modifyBitrate(v)
                                }

                                onActiveFocusChanged: {
                                    if (!activeFocus && text !== String(Math.round(root.model.bitrate))) {
                                        var v = parseInt(text) || 0
                                        if (v < 0) v = 0
                                        if (v > 200) v = 200
                                        text = String(v)
                                        root.model.modifyBitrate(v)
                                    }
                                }

                                onAccepted: {
                                    var v = parseInt(text) || 0
                                    if (v < 0) v = 0
                                    if (v > 200) v = 200
                                    text = String(v)
                                    root.model.modifyBitrate(v)
                                }
                            }
                        }
                    }

                    // Row 6: 码率警告
                    InsLabel {
                        Layout.row: 6
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        Layout.preferredHeight: Math.max(25, implicitHeight)
                        visible: root.model.showBitrateControl && root.model.bitrate > root.model.srcBitrate && root.model.srcBitrate > 0
                        color: "#F64F4E"
                        elide: Text.ElideNone
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignLeft
                        text: TS.insTr("export.setting.bitrate_warning")
                    }

                    // Row 7: 编码格式（支持预设，在深色矩形内）
                    InsLabel {
                        Layout.row: 7
                        Layout.column: 0
                        Layout.preferredWidth: 80
                        Layout.maximumWidth: 80
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredHeight: itemHeight
                        horizontalAlignment: Text.AlignLeft
                        color: InsUI.colorStandardSubtext
                        text: TS.insTr("export.setting.info.encoding_format") + ":"
                    }

                    InsComboBox {
                        id: encodeFormatCombox
                        Layout.row: 7
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30

                        textRole: "name"
                        valueRole: "ListRoleID"

                        function textByIndex(index) {
                            if (!model || index < 0) return ""
                            let v = model.data(model.index(index, 0), 0x101)
                            return v ? v : ""
                        }

                        model: root.model.encodeFormatList
                        // 避免重建encodeFormatList后控件显示空白
                        onCountChanged: Qt.callLater(syncEncodeFormatIndex)
                    }
                }
            }

            // Row 7: 色彩空间（在深色矩形外，不随预设保存）
            InsLabel {
                id: colorSettingLabel
                Layout.row: 7
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: colorSettingCombox.visible
                color: InsUI.colorStandardSubtext
                text: TS.insTr("export.setting.colorspace") + ":"
            }

            InsComboBox {
                id: colorSettingCombox
                Layout.row: 7
                Layout.column: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: root.showVideoExportOptions && root.model.colorSettingList && root.model.colorSettingList.rowCount() > 1

                textRole: "name"
                valueRole: "ListRoleID"

                function textByIndex(index) {
                    if (!model || index < 0) return ""
                    let v = model.data(model.index(index, 0), 0x101)
                    return v ? v : ""
                }

                model: root.model.colorSettingList
            }

            // Row 13: 媒体类型
            InsLabel {
                Layout.row: 13
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: root.mediaTypeCount > 1
                color: InsUI.colorStandardSubtext
                text: TS.insTr("Export Type:")
            }

            InsComboBox {
                id: mediaTypeCombox
                Layout.row: 13
                Layout.column: 1
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: root.mediaTypeCount > 1
                textRole: "name"
                function textByIndex(index) {
                    if (!model || index < 0) return ""
                    let v = TS.insTr(model.data(model.index(index, 0), 0x101))
                    return v ? v : ""
                }
                model: root.model.exportMediaTypeList
            }

            // Row 14: AI处理
            InsLabel {
                Layout.row: 14
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                Layout.topMargin: 12
                horizontalAlignment: Text.AlignLeft
                color: InsUI.colorStandardSubtext
                visible: (root.showVideoExportOptions && (model.deflickerVisible || model.dolbyVisionVisible)) || model.apmpVisible
                text: TS.insTr("export.setting.ai_effect")
            }

            ColumnLayout {
                Layout.row: 14
                Layout.column: 1
                Layout.topMargin: 6
                spacing: 4
                visible: (root.showVideoExportOptions && (model.deflickerVisible || model.dolbyVisionVisible)) || model.apmpVisible

                // 去频闪
                RowLayout {
                    spacing: 2
                    visible: root.showVideoExportOptions && model.deflickerVisible

                    InsMultiCheckBox {
                        id: deflickerCheckBox
                        checked: model.enableDeflicker
                        horizontalAlignment: Text.AlignLeft
                        text: TS.insTr("deflicker")
                    }

                    InsQuestionTip {
                        toolTipText: TS.insTr("deflicker_hover")
                    }
                }

                InsMultiCheckBox {
                    id: dolbyVisionCheckBox
                    checked: model.enableDolbyVision
                    horizontalAlignment: Text.AlignLeft
                    visible: root.showVideoExportOptions && model.dolbyVisionVisible
                    text: TS.insTr("export.setting.ai_effect.dolby")
                }

                InsMultiCheckBox {
                    id: apmpCheckBox
                    checked: model.enableApmp
                    horizontalAlignment: Text.AlignLeft
                    visible: model.apmpVisible
                    text: "APMP"
                }
            }

            // Row 15: GPS Apply
            InsLabel {
                Layout.row: 15
                Layout.column: 0
                Layout.preferredWidth: 80
                Layout.maximumWidth: 80
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredHeight: itemHeight
                horizontalAlignment: Text.AlignLeft
                visible: root.showVideoExportOptions && model.hasGpsData
                color: InsUI.colorStandardSubtext
                text: TS.insTr("Apply:")
            }

            InsMultiCheckBox {
                id: exportGpsCheckBox
                Layout.row: 15
                Layout.column: 1
                Layout.preferredHeight: itemHeight
                visible: root.showVideoExportOptions && model.hasGpsData
                checked: model.exportGps
                text: TS.insTr("Export .gpx file")
            }

            Item {
                Layout.row: 16
                Layout.column: 0
                Layout.fillHeight: true
            }
        }
    }

    PresetEditDialog {
        id: presetEditDialog
        anchors.centerIn: parent
        visible: false
        isNew: true
    }

    InsMessageBox {
        id: deleteConfirmDialog
        anchors.centerIn: Overlay.overlay
        visible: false
        stateType: InsMessageBox.StateType.WarningDialog
        titleText: TS.insTr("Delete Preset")
        contentText: TS.insTr("export.preset.delete_confirm")
        confirmText: TS.insTr("Delete")
        cancelText: TS.insTr("Cancel")
    }

    InsMessageBox {
        id: resolutionWarningDialog
        anchors.centerIn: Overlay.overlay
        visible: false
        stateType: InsMessageBox.StateType.WarningTips
        confirmText: TS.insTr("Got it")
    }

    // --- Connections ---

    Connections {
        target: fileNameInput

        property int maximumLength: 100

        function onTextEdited() {
            var fileName = fileNameInput.text
            if (fileName.length > maximumLength) {
                fileNameInput.text = fileName.substring(0, maximumLength)
            }
        }

        function onActiveFocusChanged() {
            if (!fileNameInput.activeFocus) {
                if (fileNameInput.restoreDefaultText()) {
                    fileNameInput.text = model.fileName
                    return
                }
                var fileName = fileNameInput.text.trim()
                if (fileName !== "") {
                    model.modifyDestSaveName(fileName)
                }
                model.finishEditDestSaveName()
            }
        }
    }

    Connections {
        target: pathBtn

        function onClicked() {
            var file_path = QmlHelper.openFolder(filePathInput.text)
            if (!file_path.length) return
            model.modifyDestSavePath(file_path)
        }
    }

    Connections {
        target: uploadCombox

        function onItemClicked(itemIndex) {
            var value = uploadCombox.valueAt(itemIndex)
            model.modifyUploadPlatform(value)
        }

        function onVisibleChanged() {
            if (uploadCombox.visible) {
                uploadCombox.currentIndex = uploadCombox.indexOfValue(model.uploadPlatform)
            }
        }
    }

    Connections {
        target: presetCombox

        function onItemClicked(itemIndex) {
            var name = root.model.presetList.data(root.model.presetList.index(itemIndex, 0), 0x101)
            model.modifyCurrentPresetName(name)
        }

        function onDeleteItemClicked(itemIndex) {
            var name = root.model.presetList.data(root.model.presetList.index(itemIndex, 0), 0x101)
            root.pendingDeletePresetName = name
            deleteConfirmDialog.visible = true
        }
    }

    Connections {
        target: root.model.presetList

        function onCurrentIdChanged() {
            var id = root.model.presetList.currentId
            console.log("onCurrentIdChanged", id)
            for (var i = 0; i < presetCombox.count; i++) {
                var rowId = root.model.presetList.data(root.model.presetList.index(i, 0), 0x100)
                if (rowId === id) {
                    console.log("find the match index", i)
                    presetCombox.currentIndex = i
                    break
                }
            }
        }
    }

    Connections {
        target: presetBtn

        function onClicked() {
            presetEditDialog.visible = true
            presetEditDialog.isNew = true
            presetEditDialog.repeaterName = false
            presetEditDialog.nullName = false
            presetEditDialog.presetName = root.model.getDefaultPresetName()
        }
    }

    Connections {
        target: presetEditDialog

        function onCancelButtonClicked() {
            presetEditDialog.repeaterName = false
            presetEditDialog.nullName = false
            presetEditDialog.visible = false
        }

        function onSaveButtonClicked() {
            if (model.userPresetExists(presetEditDialog.presetName)) {
                presetEditDialog.repeaterName = true
                presetEditDialog.nullName = false
                return
            }
            model.saveAsUserPreset(presetEditDialog.presetName)
            presetEditDialog.repeaterName = false
            presetEditDialog.nullName = false
            presetEditDialog.visible = false
        }

        function onDeleteButtonClicked() {
            presetEditDialog.repeaterName = false
            presetEditDialog.nullName = false
            presetEditDialog.visible = false
        }
    }

    Connections {
        target: deleteConfirmDialog

        function onAccepted() {
            model.removeUserPreset(root.pendingDeletePresetName)
            root.pendingDeletePresetName = ""
        }

        function onRejected() {
            root.pendingDeletePresetName = ""
        }
    }

    Connections {
        target: resolutionCombox

        function onItemClicked(itemIndex) {
            var id = root.model.resolutionTypeList.data(root.model.resolutionTypeList.index(itemIndex, 0), 0x100)
            model.modifyResolutionType(id)
        }
    }

    Connections {
        target: root.model.resolutionTypeList

        function onCurrentIdChanged() {
            syncResolutionComboxIndex()
        }

        function onModelReset() {
            Qt.callLater(syncResolutionComboxIndex)
        }
    }

    function syncResolutionComboxIndex() {
        if (!root.model.resolutionTypeList || !resolutionCombox)
            return
        var id = root.model.resolutionTypeList.currentId
        for (var i = 0; i < resolutionCombox.count; i++) {
            var rowId = root.model.resolutionTypeList.data(root.model.resolutionTypeList.index(i, 0), 0x100)
            if (rowId === id) {
                resolutionCombox.currentIndex = i
                return
            }
        }
    }

    // 与 VideoExportViewModel::ResolveResolutionType 一致，列表项 id 为 "scene/type"
    function resolveResolutionTypeId(resolutionTypeId) {
        if (resolutionTypeId === undefined || resolutionTypeId === null || resolutionTypeId === "")
            return -1
        var parts = resolutionTypeId.toString().split("/")
        return parseInt(parts[parts.length - 1], 10)
    }

    // 修正分辨率对齐（偶数 / ProRes 宽 16 对齐），若发生修正则弹窗提示
    // 返回值对应 VideoExportViewModel::ResolutionAlignType: 0=None, 3=Even, 4=WinProRes16
    function correctResolutionAlignment() {
        var alignType = model.correctResolutionAlignment()
        if (alignType === 0) return
        if (alignType === 3) {
            resolutionWarningDialog.contentText = TS.insTr("Width and height should be divisible by 2!")
        } else if (alignType === 4) {
            resolutionWarningDialog.contentText = TS.insTr("ProRes requires width divisible by 16.")
        }
        resolutionWarningDialog.visible = true
    }

    // 检查单个像素值是否越限，越限时弹窗并返回修正值
    function checkResolutionRange(v) {
        if (v < 100) {
            resolutionWarningDialog.contentText = TS.insTr("export.resolution.min %1").arg(100)
            resolutionWarningDialog.visible = true
            return 100
        }
        if (v > 16000) {
            resolutionWarningDialog.contentText = TS.insTr("The longest side of the video resolution cannot exceed %1!").arg(16000)
            resolutionWarningDialog.visible = true
            return 16000
        }
        return v
    }

    Connections {
        target: widthInput

        function onTextEdited() {
            if (widthInput.text) model.modifyOutputWidth(parseInt(widthInput.text))
        }

        function onActiveFocusChanged() {
            if (!widthInput.activeFocus) {
                if (widthInput.text === "") {
                    widthInput.text = model.outputWidth
                } else {
                    var v = root.checkResolutionRange(parseInt(widthInput.text) || 0)
                    model.modifyOutputWidth(v)
                    root.correctResolutionAlignment()
                    widthInput.text = model.outputWidth
                    // 联动后检查高度是否越限
                    var h = root.checkResolutionRange(model.outputHeight)
                    if (h !== model.outputHeight) {
                        model.modifyOutputHeight(h)
                        root.correctResolutionAlignment()
                    }
                    heightInput.text = model.outputHeight
                }
            }
        }
    }

    Connections {
        target: heightInput

        function onTextEdited() {
            if (heightInput.text) model.modifyOutputHeight(parseInt(heightInput.text))
        }

        function onActiveFocusChanged() {
            if (!heightInput.activeFocus) {
                if (heightInput.text === "") {
                    heightInput.text = model.outputHeight
                } else {
                    var v = root.checkResolutionRange(parseInt(heightInput.text) || 0)
                    model.modifyOutputHeight(v)
                    root.correctResolutionAlignment()
                    heightInput.text = model.outputHeight
                    // 联动后检查宽度是否越限
                    var w = root.checkResolutionRange(model.outputWidth)
                    if (w !== model.outputWidth) {
                        model.modifyOutputWidth(w)
                        root.correctResolutionAlignment()
                    }
                    widthInput.text = model.outputWidth
                }
            }
        }
    }

    Connections {
        target: fpsCombox

        function onItemClicked(itemIndex) {
            var id = root.model.frameRateList.data(root.model.frameRateList.index(itemIndex, 0), 0x100)
            model.modifyFpsType(id)
        }
    }

    Connections {
        target: root.model.frameRateList

        function onCurrentIdChanged() {
            var id = root.model.frameRateList.currentId
            for (var i = 0; i < fpsCombox.count; i++) {
                var rowId = root.model.frameRateList.data(root.model.frameRateList.index(i, 0), 0x100)
                if (rowId === id) {
                    fpsCombox.currentIndex = i
                    break
                }
            }
        }
    }

    Connections {
        target: encodeFormatCombox

        function onItemClicked(itemIndex) {
            var id = root.model.encodeFormatList.data(root.model.encodeFormatList.index(itemIndex, 0), 0x100)
            model.modifyEncodeFormat(id)
        }
    }

    Connections {
        target: root.model.encodeFormatList

        function onCurrentIdChanged() {
            syncEncodeFormatIndex()
        }
    }

    function syncEncodeFormatIndex() {
        var list = root.model.encodeFormatList
        if (!list) return
        var id = list.currentId
        for (var i = 0; i < encodeFormatCombox.count; i++) {
            var rowId = list.data(list.index(i, 0), 0x100)
            if (rowId === id) {
                encodeFormatCombox.currentIndex = i
                break
            }
        }
    }

    Connections {
        target: colorSettingCombox

        function onItemClicked(itemIndex) {
            var id = root.model.colorSettingList.data(root.model.colorSettingList.index(itemIndex, 0), 0x100)
            model.modifyColorSetting(id)
        }
    }

    Connections {
        target: root.model.colorSettingList

        function onCurrentIdChanged() {
            var id = root.model.colorSettingList.currentId
            for (var i = 0; i < colorSettingCombox.count; i++) {
                var rowId = root.model.colorSettingList.data(root.model.colorSettingList.index(i, 0), 0x100)
                if (rowId === id) {
                    colorSettingCombox.currentIndex = i
                    break
                }
            }
        }
    }

    Connections {
        target: bitrateTypeCombox
        function onItemClicked(itemIndex) {
            var id = root.model.bitrateTypeList.data(root.model.bitrateTypeList.index(itemIndex, 0), 0x100)
            root.model.modifyBitrateType(id)
        }
    }
    Connections {
        target: root.model.bitrateTypeList
        function onCurrentIdChanged() {
            var id = root.model.bitrateTypeList.currentId;
            for (var i = 0; i < bitrateTypeCombox.count; i++) {
                var rowId = root.model.bitrateTypeList.data(root.model.bitrateTypeList.index(i, 0), 0x100);
                if (rowId === id) {
                    bitrateTypeCombox.currentIndex = i;
                    break;
                }
            }
        }
    }

    Connections {
        target: mediaTypeCombox
        function onItemClicked(itemIndex) {
            console.log("mediaTypeCombox, onItemClicked ")
            var id = root.model.exportMediaTypeList.data(root.model.exportMediaTypeList.index(itemIndex, 0), 0x100);
            if (id === CommonEnums.ExportSourceClip) {
                console.log("mediaTypeCombox, onItemClicked source clip");
                root.model.modifyExportTrimSource(true);
            } else {
                console.log("mediaTypeCombox, onItemClicked video");
                root.model.modifyExportTrimSource(false);
            }
        }
    }
    Connections {
        target: root.model.exportMediaTypeList
        function onRowsInserted() { root.mediaTypeCount = root.model.exportMediaTypeList.rowCount() }
        function onRowsRemoved()  { root.mediaTypeCount = root.model.exportMediaTypeList.rowCount() }
        function onCurrentIdChanged() {
            var id = root.model.exportMediaTypeList.currentId;
            for (var i = 0; i < mediaTypeCombox.count; i++) {
                var rowId = root.model.exportMediaTypeList.data(root.model.exportMediaTypeList.index(i, 0), 0x100);
                if (rowId === id) {
                    mediaTypeCombox.currentIndex = i;
                    break;
                }
            }
        }
    }

    Connections {
        target: root.model

        function onFileNameChanged() {
            if (fileNameInput.text !== model.fileName) {
                fileNameInput.text = model.fileName
            }
        }

        function onFilePathChanged() {
            if (filePathInput.text !== model.filePath) {
                filePathInput.text = model.filePath
            }
        }

        function onOutputWidthChanged() {
            if (!widthInput.activeFocus) {
                widthInput.text = model.outputWidth
            }
        }

        function onOutputHeightChanged() {
            if (!heightInput.activeFocus) {
                heightInput.text = model.outputHeight
            }
        }

        function onBitrateChanged() {
            if (!bitrateSlider.pressed) {
                bitrateSlider.value = Math.round(model.bitrate)
            }
            if (!bitrateInput.activeFocus) {
                bitrateInput.text = String(Math.round(model.bitrate))
            }
        }

        function onUploadPlatformChanged() {
            uploadCombox.currentIndex = uploadCombox.indexOfValue(model.uploadPlatform)
        }

        function onExportGpsChanged() {
            if (exportGpsCheckBox.checked !== model.exportGps) {
                exportGpsCheckBox.checked = model.exportGps
            }
        }
    }

    Connections {
        target: deflickerCheckBox
        function onToggled() { model.modifyEnableDeflicker(deflickerCheckBox.checked) }
    }

    Connections {
        target: dolbyVisionCheckBox
        function onToggled() { model.modifyEnableDolbyVision(dolbyVisionCheckBox.checked) }
    }

    Connections {
        target: apmpCheckBox
        function onToggled() { model.modifyEnableApmp(apmpCheckBox.checked) }
    }

    Connections {
        target: exportGpsCheckBox
        function onToggled() { model.modifyExportGps(exportGpsCheckBox.checked) }
    }

    function syncAllComboBoxes() {
        var lists = [
            { list: root.model.encodeFormatList, combo: encodeFormatCombox },
            { list: root.model.frameRateList,    combo: fpsCombox },
            { list: root.model.resolutionTypeList, combo: resolutionCombox },
            { list: root.model.bitrateTypeList,  combo: bitrateTypeCombox },
            { list: root.model.exportMediaTypeList, combo: mediaTypeCombox },
            {list: root.model.presetList, combo: presetCombox},
            { list: root.model.colorSettingList, combo: colorSettingCombox },
        ]
        for (var i = 0; i < lists.length; ++i) {
            var list  = lists[i].list
            var combo = lists[i].combo
            if (!list || !combo) continue
            var id = list.currentId
            for (var j = 0; j < combo.count; ++j) {
                var rowId = list.data(list.index(j, 0), 0x100)
                if (rowId === id) {
                    combo.currentIndex = j
                    break
                }
            }
        }
    }

    Component.onCompleted: {
        if (scrollView.contentItem && scrollView.contentItem.hasOwnProperty("interactive")) {
            scrollView.contentItem.interactive = root.needScrollBar
        }
        // 关闭 Flickable 裁剪，让视频参数区底色能向两侧各溢出 10px 到外层 margin 空间
        if (scrollView.contentItem && scrollView.contentItem.hasOwnProperty("clip")) {
            scrollView.contentItem.clip = false
        }
        if (root.model.exportMediaTypeList) {
            root.mediaTypeCount = root.model.exportMediaTypeList.rowCount()
        }
        Qt.callLater(syncAllComboBoxes)
    }

    onNeedScrollBarChanged: {
        if (scrollView.contentItem && scrollView.contentItem.hasOwnProperty("interactive")) {
            scrollView.contentItem.interactive = root.needScrollBar
        }
    }
}
