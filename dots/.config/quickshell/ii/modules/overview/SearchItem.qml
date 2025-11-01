// pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

RippleButton {
    id: root
    property var entry
    // Allow caller to keep overview open when clicking this item
    property bool keepOpen: entry?.keepOpen ?? false
    property string query
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.type ?? Translation.tr("App")
    property string itemName: entry?.name ?? ""
    property string itemIcon: entry?.icon ?? ""
    property var itemExecute: entry?.execute
    property string fontType: entry?.fontType ?? "main"
    property string itemClickActionName: entry?.clickActionName ?? "Open"
    property string bigText: entry?.bigText ?? ""
    property string materialSymbol: entry?.materialSymbol ?? ""
    property string cliphistRawString: entry?.cliphistRawString ?? ""
    property bool blurImage: entry?.blurImage ?? false
    property string blurImageText: entry?.blurImageText ?? "Image hidden"
    // Reuse the global flag for now (controls Plumpy usage elsewhere too)
    readonly property bool usePlumpy: true
    // Map a handful of common Material icon names to Plumpy filenames
    function plumpyFromMaterial(name) {
        switch (name) {
        case 'calculate': return 'math';
        case 'terminal': return 'terminal';
        case 'settings_suggest': return 'tune';
        case 'video_settings': return 'tune';
    case 'travel_explore': return 'searchbar';
        case 'menu_book': return 'translation';
        case 'check': return 'check';
        case 'content_copy': return 'clipboard-approve';
        default: return '';
        }
    }
    
    visible: root.entryShown
    property int horizontalMargin: 10
    property int buttonHorizontalPadding: 10
    property int buttonVerticalPadding: 6
    property bool keyboardDown: false

    implicitHeight: rowLayout.implicitHeight + root.buttonVerticalPadding * 2
    implicitWidth: rowLayout.implicitWidth + root.buttonHorizontalPadding * 2
    buttonRadius: Appearance.rounding.normal
    colBackground: (root.down || root.keyboardDown) ? Appearance.colors.colPrimaryContainerActive : 
        ((root.hovered || root.focus) ? Appearance.colors.colPrimaryContainer : 
        ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 1))
    colBackgroundHover: Appearance.colors.colPrimaryContainer
    colRipple: Appearance.colors.colPrimaryContainerActive

    property string highlightPrefix: `<u><font color="${Appearance.colors.colPrimary}">`
    property string highlightSuffix: `</font></u>`
    function highlightContent(content, query) {
        if (!query || query.length === 0 || content == query || fontType === "monospace")
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = query.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < query.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                // Add non-highlighted part (escaped)
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                // Add highlighted character (escaped)
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        // Add the rest of the string (escaped)
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }
    property string displayContent: highlightContent(root.itemName, root.query)

    property list<string> urls: {
        if (!root.itemName) return [];
        // Regular expression to match URLs
        const urlRegex = /https?:\/\/[^\s<>"{}|\\^`[\]]+/gi;
        const matches = root.itemName?.match(urlRegex)
            ?.filter(url => !url.includes("…")) // Elided = invalid
        return matches ? matches : [];
    }
    
    // Keep pointer consistent over the entire clickable row
    PointingHandInteraction {
        cursorShape: Qt.PointingHandCursor
        enabled: true
    }

    background {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        if (!root.keepOpen) {
            GlobalStates.overviewOpen = false
        }
        root.itemExecute()
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier) {
            const deleteAction = root.entry.actions.find(action => action.name == "Delete");

            if (deleteAction) {
                deleteAction.execute()
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = true
            root.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = false
            event.accepted = true;
        }
    }

    RowLayout {
        id: rowLayout
        spacing: iconLoader.sourceComponent === null ? 0 : 10
        anchors.fill: parent
        anchors.leftMargin: root.horizontalMargin + root.buttonHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.buttonHorizontalPadding

        // Icon
        Loader {
            id: iconLoader
            active: true
            sourceComponent: root.materialSymbol !== "" ? materialSymbolComponent :
                root.bigText ? bigTextComponent :
                root.itemIcon !== "" ? iconImageComponent : 
                null
        }

        Component {
            id: iconImageComponent
            IconImage {
                source: Quickshell.iconPath(root.itemIcon, "image-missing")
                width: 35
                height: 35
            }
        }

        Component {
            id: materialSymbolComponent
            Item {
                implicitWidth: 30
                implicitHeight: 30
                // Prefer Plumpy when a mapping exists, else use Material
                PlumpyIcon {
                    id: plumpyMs
                    anchors.centerIn: parent
                    visible: root.usePlumpy && name !== ''
                    iconSize: 30
                    name: root.plumpyFromMaterial(root.materialSymbol)
                    primaryColor: Appearance.m3colors.m3onSurface
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !plumpyMs.visible || !plumpyMs.available
                    text: root.materialSymbol
                    iconSize: 30
                    color: Appearance.m3colors.m3onSurface
                }
            }
        }

        Component {
            id: bigTextComponent
            StyledText {
                text: root.bigText
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurface
            }
        }

        // Main text
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                visible: root.itemType && root.itemType != Translation.tr("App")
                text: root.itemType
            }
            RowLayout {
                Loader { // Checkmark for copied clipboard entry
                    visible: itemName == Quickshell.clipboardText && root.cliphistRawString
                    active: itemName == Quickshell.clipboardText && root.cliphistRawString
                    sourceComponent: Rectangle {
                        readonly property int glyphSize: Appearance.font.pixelSize.normal
                        implicitWidth: glyphSize
                        implicitHeight: glyphSize
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        PlumpyIcon {
                            id: copiedCheckPlumpy
                            anchors.centerIn: parent
                            visible: root.usePlumpy
                            iconSize: parent.glyphSize
                            name: 'check'
                            primaryColor: Appearance.m3colors.m3onPrimary
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !root.usePlumpy || !copiedCheckPlumpy.available
                            text: 'check'
                            font.pixelSize: parent.glyphSize
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }
                Repeater { // Favicons for links
                    model: root.query == root.itemName ? [] : root.urls
                    Favicon {
                        required property var modelData
                        size: parent.height
                        url: modelData
                    }
                }
                StyledText { // Item name/content
                    Layout.fillWidth: true
                    id: nameText
                    textFormat: Text.StyledText // RichText also works, but StyledText ensures elide work
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family[root.fontType]
                    color: Appearance.m3colors.m3onSurface
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: `${root.displayContent}`
                }
            }
            Loader { // Clipboard image preview
                active: root.cliphistRawString && Cliphist.entryIsImage(root.cliphistRawString)
                sourceComponent: CliphistImage {
                    Layout.fillWidth: true
                    entry: root.cliphistRawString
                    maxWidth: contentColumn.width
                    maxHeight: 140
                    blur: root.blurImage
                    blurText: root.blurImageText
                }
            }
        }

        // Action text (reserve width always, fade in on hover)
        StyledText {
            id: clickAction
            Layout.fillWidth: false
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnPrimaryContainer
            horizontalAlignment: Text.AlignRight
            text: root.itemClickActionName
            opacity: (root.hovered || root.focus) ? 1 : 0
            // Reserve space even when hidden to avoid layout thrash
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: implicitWidth
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.buttonVerticalPadding
            Layout.bottomMargin: -root.buttonVerticalPadding // Why is this necessary? Good question.
            spacing: 4
            Repeater {
                model: (root.entry.actions ?? []).slice(0, 4)
                delegate: RippleButton {
                    id: actionButton
                    required property var modelData
                    property string iconName: modelData.icon ?? ""
                    property string materialIconName: modelData.materialIcon ?? ""
                    implicitHeight: 34
                    implicitWidth: 34

                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive

                    // Explicit pointer for small buttons to avoid
                    // inheriting any text cursor from children
                    PointingHandInteraction { cursorShape: Qt.PointingHandCursor }
                    contentItem: Item {
                        id: actionContentItem
                        anchors.centerIn: parent
                        Loader {
                            anchors.centerIn: parent
                            active: !(actionButton.iconName !== "") || actionButton.materialIconName
                            sourceComponent: Item {
                                implicitWidth: Appearance.font.pixelSize.hugeass
                                implicitHeight: Appearance.font.pixelSize.hugeass
                                PlumpyIcon {
                                    id: actionPlumpy
                                    anchors.centerIn: parent
                                    visible: root.usePlumpy && name !== ''
                                    iconSize: Appearance.font.pixelSize.hugeass
                                    name: root.plumpyFromMaterial(actionButton.materialIconName || 'video_settings')
                                    primaryColor: Appearance.m3colors.m3onSurface
                                }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !actionPlumpy.visible || !actionPlumpy.available
                                    text: actionButton.materialIconName || 'video_settings'
                                    font.pixelSize: Appearance.font.pixelSize.hugeass
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                        }
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.materialIconName.length == 0 && actionButton.iconName && actionButton.iconName !== ""
                            sourceComponent: IconImage {
                                source: Quickshell.iconPath(actionButton.iconName)
                                implicitSize: 20
                            }
                        }
                    }

                    onClicked: modelData.execute()

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }
        }

    }
}
