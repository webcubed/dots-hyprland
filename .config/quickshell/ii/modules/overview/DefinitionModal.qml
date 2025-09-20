import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

FocusScope {
    id: overlay

    // API
    property bool open: false
    property bool closeOnBackgroundClick: true
    property bool persist: false
    // External positioning API
    property real windowX: -1
    property real windowY: -1
    property string word: ""
    property string pronunciation: ""
    property string pos: ""
    property string definition: ""
    property bool canPronounce: pronunciation && pronunciation.length > 0
    property var onCopyWord: function() {
    }
    property var onCopyDefinition: function() {
    }
    property var onPronounce: function() {
    }
    property var onClose: function() {
    }
    // Try to focus immediately and for a few frames after opening, to beat any focus races
    property int _focusAttempts: 0

    function setPosition(x, y) {
        overlay.windowX = x;
        overlay.windowY = y;
    }

    function closeModal() {
        if (!overlay.open)
            return ;

        overlay.open = false;
        try {
            overlay.onClose();
        } catch (_) {
        }
    }

    function focusLater() {
        _focusAttempts = 0;
        focusTimer.restart();
        focusGuaranteeTimer.restart();
    }

    anchors.fill: parent
    focus: open
    visible: open
    z: 9999
    onVisibleChanged: {
        if (visible)
            focusLater();

    }
    // Keyboard shortcuts
    Keys.enabled: overlay.open
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) {
            overlay.closeModal();
            e.accepted = true;
            return ;
        }
        if (!e.text || e.modifiers !== Qt.NoModifier)
            return ;

        const ch = e.text.toLowerCase();
        switch (ch) {
        case 'x':
            overlay.closeModal();
            e.accepted = true;
            break;
        case 'w':
            overlay.onCopyWord();
            e.accepted = true;
            break;
        case 'd':
            overlay.onCopyDefinition();
            e.accepted = true;
            break;
        case 's':
            overlay.onPronounce();
            e.accepted = true;
            break;
        case 'p':
            overlay.persist = !overlay.persist;
            if (overlay.persist) {
                try {
                    GlobalStates.overviewOpen = false;
                } catch (_) {
                }
            }
            e.accepted = true;
            break;
        }
    }

    // Defer focus to avoid losing it to other components updating in the same frame
    Timer {
        id: focusTimer

        interval: 1
        repeat: false
        running: false
        onTriggered: overlay.forceActiveFocus()
    }

    // Keep nudging focus to the overlay a few times after open to avoid losing it
    Timer {
        id: focusGuaranteeTimer

        interval: 40
        repeat: true
        running: false
        onTriggered: {
            if (!overlay.open) {
                focusGuaranteeTimer.stop();
                return ;
            }
            if (overlay.activeFocus) {
                focusGuaranteeTimer.stop();
                return ;
            }
            overlay.forceActiveFocus();
            overlay._focusAttempts += 1;
            if (overlay._focusAttempts >= 6)
                focusGuaranteeTimer.stop();

        }
    }

    // Global shortcuts so actions work even if some other control still has focus
    Shortcut {
        sequence: "x"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.closeModal()
    }

    Shortcut {
        sequence: "X"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.closeModal()
    }

    Shortcut {
        sequence: "w"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onCopyWord()
    }

    Shortcut {
        sequence: "W"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onCopyWord()
    }

    Shortcut {
        sequence: "d"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onCopyDefinition()
    }

    Shortcut {
        sequence: "D"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onCopyDefinition()
    }

    Shortcut {
        sequence: "s"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onPronounce()
    }

    Shortcut {
        sequence: "S"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: overlay.onPronounce()
    }

    Shortcut {
        sequence: "p"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: {
            overlay.persist = !overlay.persist;
            if (overlay.persist) {
                try {
                    GlobalStates.overviewOpen = false;
                } catch (_) {
                }
            }
        }
    }

    Shortcut {
        sequence: "P"
        context: Qt.ApplicationShortcut
        enabled: overlay.open
        onActivated: {
            overlay.persist = !overlay.persist;
            if (overlay.persist) {
                try {
                    GlobalStates.overviewOpen = false;
                } catch (_) {
                }
            }
        }
    }

    // Dim background (click-through disabled outside window)
    Rectangle {
        anchors.fill: parent
        // Catppuccin Macchiato backdrop tint instead of pitch black
        color: "#24273a"
        opacity: 0.4

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (overlay.closeOnBackgroundClick)
                    overlay.closeModal();

            }
        }

    }

    // Window
    Rectangle {
        id: window

        width: Math.max(Math.min(parent.width * 0.66, 900), 420)
        height: Math.max(Math.min(parent.height * 0.66, 650), 260)
        radius: Appearance.rounding.large
        // Catppuccin Macchiato: base = #24273a, surface0 = #363a4f
        color: "#24273a"
        border.width: 1
        border.color: "#363a4f"
        x: overlay.windowX >= 0 ? Math.max(0, Math.min(overlay.windowX, overlay.width - width)) : (overlay.width - width) / 2
        y: overlay.windowY >= 0 ? Math.max(0, Math.min(overlay.windowY, overlay.height - height)) : (overlay.height - height) / 2
        layer.enabled: true
        layer.samples: 8
        layer.smooth: true
        focus: true

        // Shadow
        StyledRectangularShadow {
            target: window
        }

        // Drag region
        MouseArea {
            anchors.fill: titleBar
            cursorShape: Qt.DragMoveCursor
            drag.target: window
            drag.axis: Drag.XAndYAxis
            acceptedButtons: Qt.LeftButton
            onPressed: overlay.forceActiveFocus()
            onPositionChanged: {
                // Constrain within overlay
                window.x = Math.max(0, Math.min(window.x, overlay.width - window.width));
                window.y = Math.max(0, Math.min(window.y, overlay.height - window.height));
                overlay.windowX = window.x;
                overlay.windowY = window.y;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            focus: true

            // Title bar
            RowLayout {
                id: titleBar

                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: overlay.word
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3onSurface
                    Layout.fillWidth: true
                }
                // Close button

                RippleButton {
                    implicitHeight: 34
                    implicitWidth: 34
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    onClicked: overlay.closeModal()

                    contentItem: Item {
                        readonly property bool usePlumpy: true

                        anchors.centerIn: parent
                        implicitWidth: Appearance.font.pixelSize.hugeass
                        implicitHeight: Appearance.font.pixelSize.hugeass

                        PlumpyIcon {
                            id: defClosePlumpy

                            anchors.centerIn: parent
                            visible: parent.usePlumpy
                            iconSize: parent.implicitWidth
                            name: 'x'
                            primaryColor: Appearance.m3colors.m3onSurface
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !parent.usePlumpy || !defClosePlumpy.available
                            text: 'close'
                            font.pixelSize: parent.implicitWidth
                            color: Appearance.m3colors.m3onSurface
                            font.hintingPreference: Font.PreferFullHinting
                        }

                    }

                }

            }

            // Meta row
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: (overlay.pronunciation && overlay.pronunciation.length) || (overlay.pos && overlay.pos.length)

                Loader {
                    active: overlay.pronunciation && overlay.pronunciation.length

                    sourceComponent: Item {
                        id: pronWrap

                        implicitWidth: row.implicitWidth
                        implicitHeight: row.implicitHeight

                        RowLayout {
                            id: row

                            spacing: 6

                            MaterialSymbol {
                                text: "record_voice_over"
                                color: Appearance.m3colors.m3onSurface
                                iconSize: 18
                                font.hintingPreference: Font.PreferFullHinting
                            }

                            StyledText {
                                text: overlay.pronunciation
                                color: Appearance.colors.colSubtext
                            }

                        }

                        MouseArea {
                            anchors.fill: row
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overlay.onPronounce()
                        }

                    }

                }

                Loader {
                    active: overlay.pos && overlay.pos.length

                    sourceComponent: RowLayout {
                        spacing: 6

                        MaterialSymbol {
                            text: "category"
                            color: Appearance.m3colors.m3onSurface
                            iconSize: 18
                            font.hintingPreference: Font.PreferFullHinting
                        }

                        StyledText {
                            text: overlay.pos
                            color: Appearance.colors.colSubtext
                        }

                    }

                }

            }

            // Definition area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.normal
                // Catppuccin Macchiato: mantle = #1e2030
                color: "#1e2030"
                border.width: 1
                border.color: "#363a4f"

                TextArea {
                    anchors.fill: parent
                    readOnly: true
                    wrapMode: Text.WordWrap
                    textFormat: TextEdit.PlainText
                    text: overlay.definition
                    renderType: Text.NativeRendering
                    color: Appearance.m3colors.m3onSurface
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    background: null
                    // Don’t capture focus for shortcuts; let overlay keep it
                    focus: false
                    onActiveFocusChanged: {
                        if (!activeFocus && overlay.open)
                            overlay.forceActiveFocus();

                    }
                }

            }

            // Actions
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 44
                    onClicked: overlay.onCopyWord()

                    StyledToolTip {
                        text: Translation.tr("Copy word")
                    }

                    contentItem: MaterialSymbol {
                        text: "content_copy"
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.m3colors.m3onSurface
                        font.hintingPreference: Font.PreferFullHinting
                    }

                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 44
                    onClicked: overlay.onCopyDefinition()

                    StyledToolTip {
                        text: Translation.tr("Copy definition")
                    }

                    contentItem: MaterialSymbol {
                        text: "description"
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.m3colors.m3onSurface
                        font.hintingPreference: Font.PreferFullHinting
                    }

                }

                RippleButton {
                    visible: overlay.canPronounce
                    implicitHeight: 36
                    implicitWidth: 44
                    onClicked: overlay.onPronounce()

                    StyledToolTip {
                        text: Translation.tr("Pronounce")
                    }

                    contentItem: MaterialSymbol {
                        text: "volume_up"
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.m3colors.m3onSurface
                        font.hintingPreference: Font.PreferFullHinting
                    }

                }

            }

        }

    }

}
