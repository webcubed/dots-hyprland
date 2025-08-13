pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    // Public state
    property bool available: false
    property bool synced: false
    property var lines: []           // [{ time: ms (number|null), text: string }]
    property int currentIndex: -1
    property string currentText: ""
    property bool loading: false
    // Adaptive offset to re-synchronize lyrics with player position (ms)
    property int timeOffsetMs: 0
    // Last observed raw position to detect large seeks (ms)
    property int _lastPosObservedMs: 0

    // Internal
    property string _lastKey: ""
    readonly property MprisPlayer _player: MprisController.activePlayer

    // Build a cache key for current track
    function _trackKey() {
        const t = StringUtils.cleanMusicTitle(_player?.trackTitle) || ""
        const a = _player?.trackArtist || ""
        const d = Math.floor(_player?.length || 0)
        return `${t}::${a}::${d}`
    }

    // Query LRCLIB: prefer synced, fallback to plain
    function _fetchLyrics() {
        available = false
        synced = false
        lines = []
        currentIndex = -1
        currentText = ""
        loading = true
        timeOffsetMs = 0
        _lastPosObservedMs = _posMs()

        const track = StringUtils.cleanMusicTitle(_player?.trackTitle) || ""
        const artist = _player?.trackArtist || ""
        const lengthSec = Math.round((_player?.length || 0) / 1000)
        if (!track || !artist) return

        const qTrack = encodeURIComponent(track).replace(/%20/g, "+")
        const qArtist = encodeURIComponent(artist).replace(/%20/g, "+")
        const url = `https://lrclib.net/api/get?track_name=${qTrack}&artist_name=${qArtist}`

        // Use curl via Process (consistent with other services like Weather)
        fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 '${url}'`]
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: ["bash", "-c", "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const raw = text || ""
                if (raw.length === 0) {
                    root.available = false
                    return
                }
                try {
                    const resp = JSON.parse(raw)
                    const syncedText = resp?.syncedLyrics || ""
                    const plainText = resp?.plainLyrics || ""
                    if (syncedText && syncedText.length > 0) {
                        root.lines = parseSynced(syncedText)
                        root.synced = true
                        root.available = root.lines.length > 0
                    } else if (plainText && plainText.length > 0) {
                        root.lines = plainToLines(plainText)
                        root.synced = false
                        root.available = root.lines.length > 0
                    } else {
                        root.available = false
                    }
                } catch (e) {
                    // Fallback: sometimes the endpoint may return raw LRC/plain on errors
                    const isLikelyLrc = /\n?\s*\[\d{1,2}:\d{1,2}(?:[\.:]\d{1,2})?\]/.test(raw)
                    if (isLikelyLrc) {
                        try {
                            root.lines = parseSynced(raw)
                            root.synced = true
                            root.available = root.lines.length > 0
                        } catch (_) {
                            root.available = false
                        }
                    } else if (raw.trim().length > 0 && raw.indexOf('{') === -1) {
                        // Treat as plain text lyrics if it doesn't look like JSON
                        root.lines = plainToLines(raw)
                        root.synced = false
                        root.available = root.lines.length > 0
                    } else {
                        console.error("[LyricsService] Parse error:", e.message)
                        root.available = false
                    }
                }
                // Update the currently displayed line immediately
                root._updateIndex()
            }
        }
    }

    // Parse LRC format
    function parseSynced(lrc) {
        const out = []
        const re = /^\s*\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,2}))?\]\s*(.*)$/
        const lines = lrc.split(/\r?\n/)
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re)
            if (m) {
                const min = parseInt(m[1]) || 0
                const sec = parseInt(m[2]) || 0
                const cs = parseInt(m[3] || "0") || 0
                const ms = min * 60000 + sec * 1000 + (cs * 10)
                const txt = (m[4] || "").trim()
                if (txt.length > 0) {
                    out.push({ time: ms, text: txt })
                }
            } else if (lines[i].trim().length > 0) {
                // Fallback unsynced line
                out.push({ time: null, text: lines[i] })
            }
        }
        // sort by time, keep nulls at end
        out.sort((a, b) => (a.time === null) - (b.time === null) || (a.time - b.time))
        return out
    }

    function plainToLines(txt) {
        return txt.split(/\r?\n/).filter(l => l.trim().length > 0).map(l => ({ time: null, text: l }))
    }

    // Update currentIndex based on player position
    function _unitFactorToMs() {
        // Infer units from raw track length
        const L = _player?.length || 0
        if (L <= 0) return 1 // default assume ms
        // If very large, it's likely microseconds
        if (L > 1e7) return 1/1000
        // If very small, it's likely seconds
        if (L < 10000) return 1000
        // Otherwise assume milliseconds
        return 1
    }

    function _posMs() {
        const f = _unitFactorToMs()
        const pRaw = _player?.position || 0
        return Math.floor(pRaw * f)
    }

    // Position adjusted by adaptive offset
    function _effectivePosMs() {
        return _posMs() + (timeOffsetMs || 0)
    }

    function _lenMs() {
        const f = _unitFactorToMs()
        const L = _player?.length || 0
        return Math.floor(L * f)
    }

    function _maxLyricMs() {
        let maxv = 0
        for (let i = 0; i < root.lines.length; i++) {
            const t = root.lines[i].time
            if (typeof t === 'number' && t > maxv) maxv = t
        }
        return maxv
    }

    function _updateIndex() {
        if (!root.available || root.lines.length === 0) {
            root.currentIndex = -1
            root.currentText = ""
            return
        }
        const pos = _posMs()
        if (!root.synced) {
            // For plain lyrics, choose a heuristic: advance roughly every 3s based on text index vs total duration
            const total = _lenMs()
            if (total <= 0) {
                root.currentIndex = Math.min(root.lines.length - 1, Math.floor((pos / 3000)))
            } else {
                const frac = pos / total
                root.currentIndex = Math.min(root.lines.length - 1, Math.floor(frac * root.lines.length))
            }
        } else {
            // Find last line whose time <= pos
            let idx = -1
            const epos = _effectivePosMs()
            for (let i = 0; i < root.lines.length; i++) {
                const t = root.lines[i].time
                if (t === null) continue
                if (t <= epos) idx = i; else break
            }
            // If we're before the first timestamp, show the first line instead of empty
            root.currentIndex = (idx === -1 && root.lines.length > 0) ? 0 : idx
        }
        root.currentText = (root.currentIndex >= 0) ? root.lines[root.currentIndex].text : ""
    }

    // Watch player changes
    Connections {
        target: _player
        function onTrackTitleChanged() { maybeFetch() }
        function onTrackArtistChanged() { maybeFetch() }
        function onPlaybackStatusChanged() { /* no-op */ }
        function onPositionChanged() {
            const now = root._posMs()
            // Detect large seeks and reset offset to avoid wrong alignment
            if (Math.abs(now - root._lastPosObservedMs) > 5000) {
                root.timeOffsetMs = 0
            }
            root._lastPosObservedMs = now
            root._updateIndex()
        }
    }

    function maybeFetch() {
        const key = _trackKey()
        if (key && key !== _lastKey) {
            _lastKey = key
            _fetchLyrics()
        }
    }

    // Timer to poll position if backend doesn't emit often
    Timer {
        running: true
        repeat: true
        interval: 120
        onTriggered: root._updateIndex()
    }

    // Periodic re-synchronization timer: gently adjust timeOffsetMs to align with nearest lyric timestamp
    Timer {
        running: true
        repeat: true
        interval: 2000 // every 2s
        onTriggered: {
            if (!root.available || !root.synced || root.lines.length === 0) return
            const pos = root._posMs()
            // Find the nearest timed line to current raw position
            let bestIdx = -1
            let bestErr = 1e12
            for (let i = 0; i < root.lines.length; i++) {
                const t = root.lines[i].time
                if (t === null) continue
                const e = Math.abs(t - pos)
                if (e < bestErr) {
                    bestErr = e
                    bestIdx = i
                }
                if (t > pos && bestErr < 300) break // early exit if already close
            }
            if (bestIdx === -1) return
            const targetOffset = root.lines[bestIdx].time - pos
            // Smoothly move offset toward target; be a bit more aggressive on large error
            const errDelta = targetOffset - root.timeOffsetMs
            const alpha = Math.abs(errDelta) > 1500 ? 0.3 : 0.12
            const newOffset = Math.round(root.timeOffsetMs + alpha * errDelta)
            // Clamp to reasonable bounds to avoid wild jumps
            root.timeOffsetMs = Math.max(-5000, Math.min(5000, newOffset))
            // Also refresh current index if offset meaningfully changed
            if (Math.abs(errDelta) > 50) root._updateIndex()
        }
    }

    Component.onCompleted: maybeFetch()
}
