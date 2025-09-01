import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item { // Wrapper
    id: root
    readonly property string xdgConfigHome: Directories.config
    property string searchingText: ""
    property bool showResults: searchingText != ""
    property real searchBarHeight: searchBar.height + Appearance.sizes.elevationMargin * 2
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + Appearance.sizes.elevationMargin * 2

    property string mathResult: ""

    // Caches to avoid rebuilding models each evaluation (prevents flicker)
    property string _dictSuggestKey: ""
    property var _dictSuggestItems: []
    property string _dictDetailKey: ""
    property var _dictDetailItems: []
    property string _udSuggestKey: ""
    property var _udSuggestItems: []
    property string _udDetailKey: ""
    property var _udDetailItems: []
    property string _udPendingSearchTerm: ""
    property string _udPendingDetailWord: ""

    function wrapLines(text, width) {
        const out = [];
        if (!text) return out;
        let s = ("" + text).replace(/\s+/g, ' ').trim();
        while (s.length > width) {
            let br = s.lastIndexOf(' ', width);
            if (br <= 0) br = width;
            out.push(s.slice(0, br));
            s = s.slice(br).trim();
        }
        if (s.length) out.push(s);
        return out;
    }

    // Debounce UD suggestions to avoid calling search() during model evaluation
    Timer {
        id: udSuggestTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root._udPendingSearchTerm !== undefined)
                UrbanDictionary.search(root._udPendingSearchTerm);
        }
    }

    Timer {
        id: udDetailTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (root._udPendingDetailWord && root._udPendingDetailWord.length > 0)
                UrbanDictionary.getDetails(root._udPendingDetailWord);
        }
    }

    function disableExpandAnimation() {
        searchWidthBehavior.enabled = false;
    }

    function cancelSearch() {
        searchInput.selectAll();
        root.searchingText = "";
        searchWidthBehavior.enabled = true;
    }

    function setSearchingText(text) {
        searchInput.text = text;
        root.searchingText = text;
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args != '' ? [`${args}`] : [])]);
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random_konachan_wall.sh")]);
            }
        },
        {
            action: "light",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) { // Invalid if doesn't start with numbers
                    Quickshell.execDetached([
                        "notify-send", 
                        Translation.tr("Superpaste"), 
                        Translation.tr("Usage: <tt>%1superpaste NUM_OF_ENTRIES[i]</tt>\nSupply <tt>i</tt> when you want images\nExamples:\n<tt>%1superpaste 4i</tt> for the last 4 images\n<tt>%1superpaste 7</tt> for the last 7 entries").arg(Config.options.search.prefix.action),
                        "-a", "Shell"
                    ]);
                    return;
                }
                const syntaxMatch = /^(?:(\d+)(i)?)/.exec(args.trim());
                const count = syntaxMatch[1] ? parseInt(syntaxMatch[1]) : 1;
                const isImage = !!syntaxMatch[2];
                Cliphist.superpaste(count, isImage);
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args);
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                GlobalStates.wallpaperSelectorOpen = true;
            }
        },
    ]

    function focusFirstItem() {
        appResults.currentIndex = 0;
    }

    Timer {
        id: nonAppResultsTimer
        interval: Config.options.search.nonAppResultDelay
        onTriggered: {
            let expr = root.searchingText;
            if (expr.startsWith(Config.options.search.prefix.math)) {
                expr = expr.slice(Config.options.search.prefix.math.length);
            }
            mathProcess.calculateExpression(expr);
        }
    }

    Process {
        id: mathProcess
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression) {
            mathProcess.running = false;
            mathProcess.command = baseCommand.concat(expression);
            mathProcess.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data;
                root.focusFirstItem();
            }
        }
    }

    Keys.onPressed: event => {
        // Prevent Esc and Backspace from registering
        if (event.key === Qt.Key_Escape)
            return;

        // Handle Backspace: focus and delete character if not focused
        if (event.key === Qt.Key_Backspace) {
            if (!searchInput.activeFocus) {
                searchInput.forceActiveFocus();
                if (event.modifiers & Qt.ControlModifier) {
                    // Delete word before cursor
                    let text = searchInput.text;
                    let pos = searchInput.cursorPosition;
                    if (pos > 0) {
                        // Find the start of the previous word
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    // Delete character before cursor if any
                    if (searchInput.cursorPosition > 0) {
                        searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition - 1) + searchInput.text.slice(searchInput.cursorPosition);
                        searchInput.cursorPosition -= 1;
                    }
                }
                // Always move cursor to end after programmatic edit
                searchInput.cursorPosition = searchInput.text.length;
                event.accepted = true;
            }
            // If already focused, let TextField handle it
            return;
        }

        // Only handle visible printable characters (ignore control chars, arrows, etc.)
        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.text.charCodeAt(0) >= 0x20) // ignore control chars like Backspace, Tab, etc.
        {
            if (!searchInput.activeFocus) {
                searchInput.forceActiveFocus();
                // Insert the character at the cursor position
                searchInput.text = searchInput.text.slice(0, searchInput.cursorPosition) + event.text + searchInput.text.slice(searchInput.cursorPosition);
                searchInput.cursorPosition += 1;
                event.accepted = true;
            }
        }
    }

    StyledRectangularShadow {
        target: searchWidgetContent
    }
    Rectangle { // Background
        id: searchWidgetContent
        anchors.centerIn: parent
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: columnLayout
            anchors.centerIn: parent
            spacing: 0

            // clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: searchWidgetContent.width
                    height: searchWidgetContent.width
                    radius: searchWidgetContent.radius
                }
            }

            RowLayout {
                id: searchBar
                spacing: 5
                MaterialSymbol {
                    id: searchIcon
                    Layout.leftMargin: 15
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.m3colors.m3onSurface
                    text: root.searchingText.startsWith(Config.options.search.prefix.clipboard) ? 'content_paste_search'
                        : (root.searchingText.startsWith('d ') ? 'menu_book'
                        : (root.searchingText.startsWith('ud ') ? 'forum' : 'search'))
                }
                TextField { // Search box
                    id: searchInput

                    focus: GlobalStates.overviewOpen
                    Layout.rightMargin: 15
                    padding: 15
                    renderType: Text.NativeRendering
                    font {
                        family: Appearance?.font.family.main ?? "sans-serif"
                        pixelSize: Appearance?.font.pixelSize.small ?? 15
                        hintingPreference: Font.PreferFullHinting
                    }
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Search, calculate or run")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    implicitWidth: root.searchingText == "" ? Appearance.sizes.searchWidthCollapsed : Appearance.sizes.searchWidth

                    Behavior on implicitWidth {
                        id: searchWidthBehavior
                        enabled: false
                        NumberAnimation {
                            duration: 300
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }

                    onTextChanged: root.searchingText = text

                    onAccepted: {
                        if (appResults.count > 0) {
                            // Get the first visible delegate and trigger its click
                            let firstItem = appResults.itemAtIndex(0);
                            if (firstItem && firstItem.clicked) {
                                firstItem.clicked();
                            }
                        }
                    }

                    background: null

                    cursorDelegate: Rectangle {
                        width: 1
                        color: searchInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }
            }

            Rectangle {
                // Separator
                visible: root.showResults
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            ListView { // App results
                id: appResults
                visible: root.showResults
                Layout.fillWidth: true
                implicitHeight: Math.min(600, appResults.contentHeight + topMargin + bottomMargin)
                clip: true
                topMargin: 10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 0
                cacheBuffer: 2000
                reuseItems: true

                onFocusChanged: {
                    if (focus && appResults.count > 0)
                        appResults.currentIndex = 0;
                }

                Connections {
                    target: root
                    function onSearchingTextChanged() {
                        if (appResults.count > 0)
                            appResults.currentIndex = 0;
                    }
                }

                model: ScriptModel {
                    id: model
                    onValuesChanged: {
                        // Only refocus if currentIndex is invalid; avoid resetting highlight while hovering
                        if (appResults.currentIndex < 0 || appResults.currentIndex >= appResults.count) {
                            root.focusFirstItem();
                        }
                    }
                    values: {
                        // Search results are handled here
                        ////////////////// Skip? //////////////////
                        if (root.searchingText == "")
                            return [];

                        ///////////// Special cases ///////////////
                        if (root.searchingText.startsWith(Config.options.search.prefix.clipboard)) {
                            // Clipboard
                            const searchString = root.searchingText.slice(Config.options.search.prefix.clipboard.length);
                            return Cliphist.fuzzyQuery(searchString).map(entry => {
                                return {
                                    cliphistRawString: entry,
                                    name: StringUtils.cleanCliphistEntry(entry),
                                    clickActionName: "",
                                    type: `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`,
                                    execute: () => {
                                        Cliphist.copy(entry)
                                    },
                                    actions: [
                                        {
                                            name: "Copy",
                                            materialIcon: "content_copy",
                                            execute: () => {
                                                Cliphist.copy(entry);
                                            }
                                        },
                                        {
                                            name: "Delete",
                                            materialIcon: "delete",
                                            execute: () => {
                                                Cliphist.deleteEntry(entry);
                                            }
                                        }
                                    ]
                                };
                            }).filter(Boolean);
                        }
                        else if (root.searchingText.startsWith(Config.options.search.prefix.emojis)) {
                            // Clipboard
                            const searchString = root.searchingText.slice(Config.options.search.prefix.emojis.length);
                            return Emojis.fuzzyQuery(searchString).map(entry => {
                                return {
                                    cliphistRawString: entry,
                                    bigText: entry.match(/^\s*(\S+)/)?.[1] || "",
                                    name: entry.replace(/^\s*\S+\s+/, ""),
                                    clickActionName: "",
                                    type: "Emoji",
                                    execute: () => {
                                        Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1];
                                    }
                                };
                            }).filter(Boolean);
                        }
                        else if (root.searchingText.startsWith('d ')) {
                            // Dictionary via `dict`
                            const raw = root.searchingText.slice(2);
                            const exclIdx = raw.indexOf('!');
                            if (exclIdx === -1) {
                                // Suggestion mode: show words only
                                const searchString = raw.trim();
                                Dictionary.search(searchString);
                                const list = (Dictionary.results || []);
                                const key = `dict:suggest:${list.map(e => e.primary || e.word).join('|')}`;
                                if (key === root._dictSuggestKey) return root._dictSuggestItems;
                                const items = list.map(entry => ({
                                    name: `${entry.word}`,
                                    clickActionName: Translation.tr("Select"),
                                    type: Translation.tr("Dictionary"),
                                    materialSymbol: 'menu_book',
                                    keepOpen: true,
                                    actions: [
                                        { name: Translation.tr("Copy word"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = entry.word },
                                    ],
                                    execute: () => { const w = (entry.primary || entry.word).split(/\s+/)[0]; root.setSearchingText(`d ${w}!`); }
                                })).filter(Boolean);
                                root._dictSuggestKey = key;
                                root._dictSuggestItems = items;
                                return items;
                            } else {
                                // Details mode: d <word>!flags
                                const word = raw.slice(0, exclIdx).trim();
                                const flags = raw.slice(exclIdx + 1).trim();
                                if (word.length === 0) return [];
                                Dictionary.getDetails(word);
                                const det = Dictionary.details || { word: word, definition: "", pos: "", pronunciation: "", fullText: "" };
                                const dkey = `dict:detail:${word}!${flags}:${(det.definition||det.fullText||'').length}:${det.pos}:${det.pronunciation}`;
                                if (dkey === root._dictDetailKey) return root._dictDetailItems;
                                const actionsCommon = [
                                    { name: Translation.tr("Copy word"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.word },
                                    { name: Translation.tr("Copy definition"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.definition || det.fullText },
                                    { name: Translation.tr("Show full"), materialIcon: 'article', execute: () => Quickshell.execDetached(["notify-send", det.word || word, det.definition || det.fullText || Translation.tr("No definition"), "-a", "Shell"]) }
                                ];

                                if (flags.includes('d')) {
                                    // Definition-only view; single entry (no multi-line split)
                                    const text = det.definition || det.fullText || Translation.tr("No definition");
                                    const items = [{
                                        name: text,
                                        clickActionName: Translation.tr("Copy definition"),
                                        type: Translation.tr("Definition"),
                                        materialSymbol: 'menu_book',
                                        keepOpen: true,
                                        actions: actionsCommon,
                                        execute: () => { root.setSearchingText(`d ${word}!d`); }
                                    }];
                                    root._dictDetailKey = dkey;
                                    root._dictDetailItems = items;
                                    return items;
                                }

                                if (flags.includes('p')) {
                                    // Pronunciation-only view; single entry
                                    const text = det.pronunciation || Translation.tr("No pronunciation found");
                                    const items = [{
                                        name: text,
                                        clickActionName: Translation.tr("Copy pronunciation"),
                                        type: Translation.tr("Pronunciation"),
                                        materialSymbol: 'record_voice_over',
                                        keepOpen: true,
                                        actions: [ { name: Translation.tr("Copy"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.pronunciation } ],
                                        execute: () => { root.setSearchingText(`d ${word}!p`); }
                                    }];
                                    root._dictDetailKey = dkey;
                                    root._dictDetailItems = items;
                                    return items;
                                }

                                if (flags.includes('t')) {
                                    // Part-of-speech-only view; single entry
                                    const text = det.pos || Translation.tr("Unknown");
                                    const items = [{
                                        name: text,
                                        clickActionName: Translation.tr("Copy type"),
                                        type: Translation.tr("Part of speech"),
                                        materialSymbol: 'category',
                                        keepOpen: true,
                                        actions: [ { name: Translation.tr("Copy"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.pos } ],
                                        execute: () => { root.setSearchingText(`d ${word}!t`); }
                                    }];
                                    root._dictDetailKey = dkey;
                                    root._dictDetailItems = items;
                                    return items;
                                }

                                // General detail menu
                                const out = [];
                                out.push({
                                    name: det.word || word,
                                    clickActionName: Translation.tr("Copy word"),
                                    type: Translation.tr("Dictionary"),
                                    materialSymbol: 'menu_book',
                                    keepOpen: true,
                                    actions: actionsCommon,
                                    execute: () => { Quickshell.clipboardText = det.word || word; }
                                });
                                if (det.pronunciation) {
                                    out.push({
                                        name: Translation.tr("Pronunciation: %1").arg(det.pronunciation),
                                        clickActionName: Translation.tr("Show"),
                                        type: Translation.tr("Pronunciation"),
                                        materialSymbol: 'record_voice_over',
                                        keepOpen: true,
                                        actions: [ { name: Translation.tr("Copy"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.pronunciation } ],
                                        execute: () => { root.setSearchingText(`d ${word}!p`); }
                                    });
                                }
                                if (det.pos) {
                                    out.push({
                                        name: Translation.tr("Part of speech: %1").arg(det.pos),
                                        clickActionName: Translation.tr("Show"),
                                        type: Translation.tr("Part of speech"),
                                        materialSymbol: 'category',
                                        keepOpen: true,
                                        actions: [ { name: Translation.tr("Copy"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.pos } ],
                                        execute: () => { root.setSearchingText(`d ${word}!t`); }
                                    });
                                }
                                // Single definition entry (no multi-line split)
                                out.push({
                                    name: det.definition || det.fullText || Translation.tr("No definition"),
                                    clickActionName: Translation.tr("Show definition"),
                                    type: Translation.tr("Definition"),
                                    materialSymbol: 'menu_book',
                                    keepOpen: true,
                                    actions: actionsCommon,
                                    execute: () => { root.setSearchingText(`d ${word}!d`); }
                                });
                                const all = out;
                                root._dictDetailKey = dkey;
                                root._dictDetailItems = all;
                                return all;
                            }
                        }
                        else if (root.searchingText.startsWith('ud ')) {
                            // Urban Dictionary
                            const raw = root.searchingText.slice(3);
                            const exclIdx = raw.indexOf('!');
                            if (exclIdx === -1) {
                                // Suggestion mode: list of words only
                                const searchString = raw.trim();
                                // Debounced search to prevent model side-effects
                                root._udPendingSearchTerm = searchString;
                                udSuggestTimer.restart();
                                const list = (UrbanDictionary.results || []);
                                const key = `ud:suggest:${list.map(e => e.word).join('|')}`;
                                if (key === root._udSuggestKey) return root._udSuggestItems;
                                const items = list.map(entry => ({
                                    name: `${entry.word}`,
                                    clickActionName: Translation.tr("Select"),
                                    type: Translation.tr("Urban Dictionary"),
                                    materialSymbol: 'forum',
                                    keepOpen: true,
                                    actions: [
                                        { name: Translation.tr("Copy word"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = entry.word },
                                    ],
                                    execute: () => { root.setSearchingText(`ud ${entry.word}!`); }
                                }));
                                root._udSuggestKey = key;
                                root._udSuggestItems = items;
                                return items;
                            } else {
                                // Details mode: show definition across multiple rows
                                const word = raw.slice(0, exclIdx).trim();
                                const flags = raw.slice(exclIdx + 1).trim();
                                if (word.length === 0) return [];
                                // Debounce details fetch to prevent model re-eval flicker
                                if (root._udPendingDetailWord !== word) {
                                    root._udPendingDetailWord = word;
                                    udDetailTimer.restart();
                                }
                                const det = UrbanDictionary.details || { word: word, definition: "", definitions: [] };
                                const actionsCommon = [
                                    { name: Translation.tr("Copy word"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.word },
                                    { name: Translation.tr("Copy definition"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.definition },
                                    { name: Translation.tr("Show full"), materialIcon: 'article', execute: () => Quickshell.execDetached(["notify-send", det.word || word, det.definition || Translation.tr("No definition"), "-a", "Shell"]) }
                                ];
                                const dkey = `ud:detail:${word}!${flags}:${(det.definitions||[]).length}:${(det.definition||'').length}`;
                                if (dkey === root._udDetailKey) return root._udDetailItems;
                                // Build single entry per definition (no multi-line split)
                                const defs = (det.definitions && det.definitions.length) ? det.definitions : (det.definition ? [det.definition] : []);
                                const items = defs.map(def => ({
                                    name: def,
                                    clickActionName: Translation.tr("Show definition"),
                                    type: Translation.tr("Urban Dictionary"),
                                    materialSymbol: 'forum',
                                    keepOpen: true,
                                    actions: [
                                        { name: Translation.tr("Copy word"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = det.word },
                                        { name: Translation.tr("Copy definition"), materialIcon: 'content_copy', execute: () => Quickshell.clipboardText = def },
                                        { name: Translation.tr("Show full"), materialIcon: 'article', execute: () => Quickshell.execDetached(["notify-send", det.word || word, def || Translation.tr("No definition"), "-a", "Shell"]) }
                                    ],
                                    execute: () => { root.setSearchingText(`ud ${word}!d`); }
                                }));
                                if (items.length === 0) return [];
                                root._udDetailKey = dkey;
                                root._udDetailItems = items;
                                return items;
                            }
                        }

                        ////////////////// Init ///////////////////
                        nonAppResultsTimer.restart();
                        const mathResultObject = {
                            name: root.mathResult,
                            clickActionName: Translation.tr("Copy"),
                            type: Translation.tr("Math result"),
                            fontType: "monospace",
                            materialSymbol: 'calculate',
                            execute: () => {
                                Quickshell.clipboardText = root.mathResult;
                            }
                        };
                        const commandResultObject = {
                            name: searchingText.replace("file://", ""),
                            clickActionName: Translation.tr("Run"),
                            type: Translation.tr("Run command"),
                            fontType: "monospace",
                            materialSymbol: 'terminal',
                            execute: () => {
                                let cleanedCommand = root.searchingText.replace("file://", "");
                                if (cleanedCommand.startsWith(Config.options.search.prefix.shellCommand)) {
                                    cleanedCommand = cleanedCommand.slice(Config.options.search.prefix.shellCommand.length);
                                }
                                Quickshell.execDetached(["bash", "-c", searchingText.startsWith('sudo') ? `${Config.options.apps.terminal} fish -C '${cleanedCommand}'` : cleanedCommand]);
                            }
                        };
                        const webSearchResultObject = {
                            name: root.searchingText,
                            clickActionName: Translation.tr("Search"),
                            type: Translation.tr("Search the web"),
                            materialSymbol: 'travel_explore',
                            execute: () => {
                                let query = root.searchingText;
                                if (query.startsWith(Config.options.search.prefix.webSearch)) {
                                    query = query.slice(Config.options.search.prefix.webSearch.length);
                                }
                                let url = Config.options.search.engineBaseUrl + query;
                                for (let site of Config.options.search.excludedSites) {
                                    url += ` -site:${site}`;
                                }
                                Qt.openUrlExternally(url);
                            }
                        }
                        const launcherActionObjects = root.searchActions.map(action => {
                            const actionString = `${Config.options.search.prefix.action}${action.action}`;
                            if (actionString.startsWith(root.searchingText) || root.searchingText.startsWith(actionString)) {
                                return {
                                    name: root.searchingText.startsWith(actionString) ? root.searchingText : actionString,
                                    clickActionName: Translation.tr("Run"),
                                    type: Translation.tr("Action"),
                                    materialSymbol: 'settings_suggest',
                                    execute: () => {
                                        action.execute(root.searchingText.split(" ").slice(1).join(" "));
                                    }
                                };
                            }
                            return null;
                        }).filter(Boolean);

                        //////// Prioritized by prefix /////////
                        let result = [];
                        const startsWithNumber = /^\d/.test(root.searchingText);
                        const startsWithMathPrefix = root.searchingText.startsWith(Config.options.search.prefix.math);
                        const startsWithShellCommandPrefix = root.searchingText.startsWith(Config.options.search.prefix.shellCommand);
                        const startsWithWebSearchPrefix = root.searchingText.startsWith(Config.options.search.prefix.webSearch);
                        if (startsWithNumber || startsWithMathPrefix) {
                            result.push(mathResultObject);
                        } else if (startsWithShellCommandPrefix) {
                            result.push(commandResultObject);
                        } else if (startsWithWebSearchPrefix) {
                            result.push(webSearchResultObject);
                        }

                        //////////////// Apps //////////////////
                        result = result.concat(AppSearch.fuzzyQuery(root.searchingText).map(entry => {
                            entry.clickActionName = Translation.tr("Launch");
                            entry.type = Translation.tr("App");
                            return entry;
                        }));

                        ////////// Launcher actions ////////////
                        result = result.concat(launcherActionObjects);

                        /// Math result, command, web search ///
                        if (Config.options.search.prefix.showDefaultActionsWithoutPrefix) {
                            if (!startsWithShellCommandPrefix) result.push(commandResultObject);
                            if (!startsWithNumber && !startsWithMathPrefix) result.push(mathResultObject);
                            if (!startsWithWebSearchPrefix) result.push(webSearchResultObject);
                        }

                        return result;
                    }
                }

                delegate: SearchItem {
                    // The selectable item for each search result
                    required property var modelData
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    entry: modelData
                    query: {
                        let q = root.searchingText;
                        if (q.startsWith(Config.options.search.prefix.clipboard)) q = q.slice(Config.options.search.prefix.clipboard.length);
                        else if (q.startsWith(Config.options.search.prefix.emojis)) q = q.slice(Config.options.search.prefix.emojis.length);
                        else if (q.startsWith('d ')) {
                            q = q.slice(2);
                            const i = q.indexOf('!');
                            if (i !== -1) q = q.slice(0, i);
                        }
                        else if (q.startsWith('ud ')) {
                            q = q.slice(3);
                            const i = q.indexOf('!');
                            if (i !== -1) q = q.slice(0, i);
                        }
                        q
                    }
                }
            }
        }
    }
}