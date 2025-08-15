import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    // Center this component within its parent container
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    property string text: ""
    // segments: accepts flexible shapes; we'll normalize to [{ text, t(ms), d(ms) }]
    property var segments: []
    // internal normalized copy used for timing/highlight
    property var _normSegments: []
    property int currentMs: 0
    // Removed leading-gap window (dots disabled)
    property int leadingGapAbsStartMs: -1
    property int leadingGapAbsEndMs: -1
    // If segments' t are relative to the line start, set timesRelative=true and provide baseStartMs
    property bool timesRelative: false
    property int baseStartMs: 0
    // Next line start (for gap spanning when no tokens exist)
    property int nextStartMs: 0
    property color baseColor: Appearance.colors.colOnLayer1
    property color highlightColor: "#8AADF4"
    property int pixelSize: Appearance.font.pixelSize.small
    // Tunables for visibility
    property real baseOpacity: 0.35
    property real overlayOpacity: 1.0
    // Active token index (raw from time) and the nearest non-space token to highlight
    property int activeIdx: -1
    property int activeWordIdx: -1
    // 0..1 progress through the active segment time window
    property real activeProgress: 0.0
    // No visual delay or adaptive bias; follow player time strictly
    // Removed all gap/dots state (dots disabled)
    // Monotonic time within a line to avoid jitter/back jumps
    property int _lastMs: -1

    onSegmentsChanged: { _normalizeSegments(); _lastMs = -1 }
    onCurrentMsChanged: root._recalcActive()
    onBaseStartMsChanged: { _normalizeSegments(); _lastMs = -1 }
    onTimesRelativeChanged: { _lastMs = -1; root._recalcActive() }
    onTextChanged: { _lastMs = -1 }

    // Let containers query our implicit size like a normal Text
    implicitWidth: (
        (_normSegments && _normSegments.length > 0) ? lineRow.implicitWidth :
        (fallbackText.visible ? fallbackText.implicitWidth : Math.max(pixelSize, 1))
    )
    implicitHeight: (
        (_normSegments && _normSegments.length > 0) ? lineRow.implicitHeight :
        (fallbackText.visible ? fallbackText.implicitHeight : Math.max(pixelSize, 1))
    )
    width: parent ? parent.width : implicitWidth
    height: Math.max(implicitHeight, 1)

    function _isSpace(idx) {
        const t = String(_normSegments?.[idx]?.text || "")
        return t.trim().length === 0
    }
    function _pick(obj, keys, defVal) {
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            if (obj && obj[k] !== undefined && obj[k] !== null) return obj[k]
        }
        return defVal
    }
    function _normalizeSegments() {
        const src = Array.isArray(segments) ? segments : []
        // Robust unit detection: if any value >= 1000, treat as milliseconds; else if at least two fractional values < 60, treat as seconds
        let secsHeuristic = false
        let anyMsScale = false
        let fractCount = 0
        for (let i = 0; i < Math.min(src.length, 10); i++) {
            const s = src[i] || {}
            const tt = Number(_pick(s, ["t","time","ts","start","o"], 0))
            const dd = Number(_pick(s, ["d","dur","duration","len"], 0))
            if (tt >= 1000 || dd >= 1000) anyMsScale = true
            if ((tt > 0 && tt < 60 && String(tt).includes(".")) || (dd > 0 && dd < 60 && String(dd).includes("."))) fractCount++
        }
        secsHeuristic = (!anyMsScale && fractCount >= 2)
        const out = []
        for (let i = 0; i < src.length; i++) {
            const s = src[i] || {}
            const text = String(_pick(s, ["text","c","w","word"], ""))
            let t = Number(_pick(s, ["t","time","ts","start","o"], 0))
            let d = Number(_pick(s, ["d","dur","duration","len"], 0))
            let e = Number(_pick(s, ["e","end"], NaN))
            if (!isNaN(e) && (isNaN(d) || d === 0)) d = Math.max(0, e - t)
            if (secsHeuristic) { t = Math.round(t * 1000); d = Math.round(d * 1000) }
            out.push({ i: i, text: text, t: Math.max(0, t|0), d: Math.max(0, d|0) })
        }
        // Sort by start time
        out.sort(function(a,b){ return (a.t - b.t) })
        // Backfill zero durations using next.t - t; default to 300ms for last if still zero
        for (let j = 0; j < out.length; j++) {
            if (!out[j]) continue
            if (!out[j].d || out[j].d <= 0) {
                const next = out[j+1]
                out[j].d = Math.max(80, (next ? (next.t - out[j].t) : 300)) // ensure a visible window
            }
        }
        // Renumber indices to match sorted order so delegate 'i' aligns with activeWordIdx
        for (let j = 0; j < out.length; j++) {
            out[j].i = j
        }
        _normSegments = out
        if (out.length > 0) {
            try { console.log("KaraokeLine: norm seg[0]=", JSON.stringify(out[0])) } catch(e) {}
        }
    }
    function _recalcActive() {
        if (!_normSegments || _normSegments.length === 0) { activeIdx = -1; activeWordIdx = -1; activeProgress = 0; return }
        // If using relative timings, and baseStartMs not set yet while clock already advanced, avoid a last-word jump
        if (timesRelative && baseStartMs <= 0 && currentMs > 150) { activeIdx = -1; activeWordIdx = -1; activeProgress = 0; return }
        const msRaw = timesRelative ? Math.max(0, currentMs - baseStartMs) : currentMs
        // Enforce monotonic ms within a line to avoid back-jumps causing jitter
        let ms = msRaw
        if (_lastMs >= 0 && ms < _lastMs) ms = _lastMs
        _lastMs = ms
        // Clamp within [lineStart, lineEnd]
        const lineStart = timesRelative ? 0 : baseStartMs
        const lineEnd = (nextStartMs > 0) ? (timesRelative ? Math.max(0, nextStartMs - baseStartMs) : nextStartMs) : Number.MAX_SAFE_INTEGER
        ms = Math.min(Math.max(lineStart, ms), lineEnd)
        const N = _normSegments.length
        // Build list of indices for non-space tokens
        const words = []
        for (let i = 0; i < N; i++) { if (!_isSpace(i)) words.push(i) }
        if (words.length === 0) { activeIdx = -1; activeWordIdx = -1; activeProgress = 0; return }
        // Find current word window: t in [t_i, next_t) or within its duration
        let chosen = words[0]
        let chosenK = 0
        for (let k = 0; k < words.length; k++) {
            const i = words[k]
            const s = _normSegments[i]
            const relT0 = s.t || 0
            const d0 = Math.max(1, s.d || 1)
            const next = (k + 1 < words.length) ? _normSegments[words[k+1]] : null
            const relNextT = next ? (next.t || (relT0 + d0)) : (relT0 + d0)
            // Compare in the same domain as ms
            const t0 = timesRelative ? relT0 : (baseStartMs + relT0)
            const nextT = timesRelative ? relNextT : (baseStartMs + relNextT)
            if (ms < t0) { chosen = (k > 0 ? words[k-1] : words[0]); chosenK = Math.max(0, k - 1); break }
            if (ms >= t0 && ms < nextT) { chosen = i; chosenK = k; break }
            chosen = i; chosenK = k
        }
        // Prevent skipping multiple tokens in one UI tick unless this was a large jump (seek)
        const last = _lastMs
        const moderateStep = (last >= 0) ? (ms - last) <= 400 : false
        if (moderateStep && activeWordIdx >= 0) {
            // Clamp to at most +1 word from previous
            let prevK = 0
            for (let k = 0; k < words.length; k++) { if (words[k] === activeWordIdx) { prevK = k; break } }
            if (chosenK > prevK + 1) { chosenK = prevK + 1; chosen = words[chosenK] }
        }
        const cs = _normSegments[chosen]
        const relCt0 = cs ? (cs.t || 0) : 0
        const cd = Math.max(1, cs ? (cs.d || 1) : 1)
        const ct0 = timesRelative ? relCt0 : (baseStartMs + relCt0)
        const nextWord = (chosenK + 1 < words.length) ? _normSegments[words[chosenK + 1]] : null
        const relNextStart = nextWord ? (nextWord.t || (relCt0 + cd)) : (relCt0 + cd)
        const nextStart = timesRelative ? relNextStart : (baseStartMs + relNextStart)
        // No gap handling
        // Not in gap: highlight chosen word
        activeIdx = chosen
        activeWordIdx = chosen
        activeProgress = Math.min(1, Math.max(0, (ms - ct0) / cd))
    }
    onActiveIdxChanged: {
        // Map to nearest non-space token so highlight is always on a word
        if (activeIdx < 0) { activeWordIdx = -1; return }
        const N = _normSegments ? _normSegments.length : 0
        let idx = activeIdx
        if (!_isSpace(idx)) { activeWordIdx = idx; return }
        // search backward then forward
        for (let j = idx - 1; j >= 0; j--) { if (!_isSpace(j)) { activeWordIdx = j; return } }
        for (let j = idx + 1; j < N; j++) { if (!_isSpace(j)) { activeWordIdx = j; return } }
        activeWordIdx = -1
    }
    // Centered tokenized line: base tokens dimmed; active token floats and bright
    Row {
        id: lineRow
        visible: (_normSegments && _normSegments.length > 0)
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 0
        Repeater {
            model: (_normSegments && _normSegments.length > 0) ? _normSegments : []
            Item {
                required property var modelData
                readonly property bool isActive: (modelData && modelData.i === root.activeWordIdx)
                implicitWidth: token.implicitWidth
                implicitHeight: token.implicitHeight
                // Glow removed: rely on pure white overlay for highlight

                // Base token (full opacity; overlay emphasizes active)
                StyledText {
                    id: token
                    text: String(modelData?.text || "")
                    font.pixelSize: root.pixelSize
                    color: isActive ? root.highlightColor : root.baseColor
                    opacity: root.overlayOpacity
                    font.bold: false
                    horizontalAlignment: Text.AlignLeft
                    z: 1
                }

                // Overlay removed: highlight by changing token color to white
            }
        }
    }
} 
