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
    // Karaoke (per-word timing) state
    property bool karaoke: false
    // [{ start: number, text: string, words: [{ t: number, d: number, text: string }] }]
    property var karaokeLines: []
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
        karaoke = false
        karaokeLines = []
        lines = []
        currentIndex = -1
        currentText = ""
        loading = true
        timeOffsetMs = 0
        _lastPosObservedMs = _posMs()
        const track = (MprisController.activePlayer?.trackTitle || "").trim()
        // Prefer combined artist string if available; fallback to joined array
        const artistCombined = (MprisController.activePlayer?.trackArtist || "").trim()
        const artistsArray = (MprisController.activePlayer?.trackArtists || [])
        const artist = (artistCombined || artistsArray.join(', ')).trim()
        if (!track || !artist) {
            // Not enough metadata
            loading = false
            _setNoLyrics()
            return
        }
        _providerIndex = 0
        _currentProvider = ""
        // Store raw strings; encoding is done when constructing provider URLs
        _qTrack = track
        _qArtist = artist
        _pendingRequest = ""
        _neteaseSongId = 0
        _tryNextProvider()
    }

    // Helper: set fallback to a single "No lyrics" line
    function _setNoLyrics() {
        root.lines = [ { time: null, text: "No lyrics" } ]
        root.synced = false
        root.available = true
        root.currentIndex = 0
        root.currentText = "No lyrics"
    }

    // Provider state
    property int _providerIndex: 0
    property string _currentProvider: ""
    property string _qTrack: ""
    property string _qArtist: ""
    // NetEase flow state
    property string _pendingRequest: "" // "netease_search" | "netease_lyric" | ""
    property int _neteaseSongId: 0
    // Musixmatch flow state
    // "musixmatch_macro" | "musixmatch_richsync" | "musixmatch_fallback_lrc" | "musixmatch_lyrics"
    property int _musixmatchTrackId: 0

    // Attempt providers in order (prioritize karaoke-capable):
    // 0 = NetEase Cloud Music (klyric + lrc), 1 = Musixmatch (synced LRC or plain), 2 = LRCLib (synced only)
    function _tryNextProvider() {
        const wantLrclib = !!Config.options?.lyrics?.enableLrclib
        const wantNetease = !!Config.options?.lyrics?.enableNetease
        const wantMxm = !!Config.options?.lyrics?.musixmatch?.enable
        const providers = []
        // Prefer karaoke-capable provider first
        if (wantNetease) providers.push("netease")
        if (wantMxm) providers.push("musixmatch")
        if (wantLrclib) providers.push("lrclib")
        if (providers.length === 0) {
            loading = false
            _setNoLyrics()
            return
        }
        if (_providerIndex >= providers.length) {
            loading = false
            _setNoLyrics()
            return
        }
        _currentProvider = providers[_providerIndex]
        _providerIndex += 1

        let url = ""
        if (_currentProvider === "lrclib") {
            // Docs: https://lrclib.net/docs (GET /api/get?track_name&artist_name)
            const trackQ = encodeURIComponent(_qTrack).replace(/%20/g, '+')
            const artistQ = encodeURIComponent(_qArtist).replace(/%20/g, '+')
            console.log("LyricsService: LRCLIB query raw track=", _qTrack, "artist=", _qArtist, "encoded trackQ=", trackQ, "artistQ=", artistQ)
            url = `https://lrclib.net/api/get?track_name=${trackQ}&artist_name=${artistQ}`
        } else if (_currentProvider === "netease") {
            // Docs: https://binaryify.github.io/NeteaseCloudMusicApi/#/?id=lyric
            // Step 1: search by keywords to get song id
            const base = Config.options?.lyrics?.neteaseBaseUrl || ""
            if (!base) {
                // No base URL configured, skip this provider
                _tryNextProvider()
                return
            }
            const keywords = encodeURIComponent(`${_qArtist} ${_qTrack}`).replace(/%20/g, '+')
            console.log("LyricsService: NetEase search raw artist=", _qArtist, "track=", _qTrack, "keywords=", keywords)
            url = `${base.replace(/\/$/, "")}/search?limit=1&type=1&keywords=${keywords}`
            _pendingRequest = "netease_search"
        } else if (_currentProvider === "musixmatch") {
            // Prefer desktop API with macro to retrieve richsync (karaoke) if available
            // Example: https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get?format=json&namespace=lyrics_richsynched&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_album=...&q_artist=...&q_track=...&q_duration=240&f_subtitle_length=240&usertoken=TOKEN
            const key = Config.options?.lyrics?.musixmatch?.apiKey || ""
            if (!key) { _tryNextProvider(); return }
            _musixmatchTrackId = 0
            const base = "https://apic-desktop.musixmatch.com/ws/1.1"
            const trackQ = encodeURIComponent(_qTrack)
            const artistQ = encodeURIComponent(_qArtist)
            const durSec = Math.max(0, Math.round((_lenMs() || 0) / 1000))
            const lenParam = durSec > 0 ? `&q_duration=${durSec}&f_subtitle_length=${durSec}` : ""
            url = `${base}/macro.subtitles.get?format=json&namespace=lyrics_richsynched&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_artist=${artistQ}&q_track=${trackQ}${lenParam}&usertoken=${encodeURIComponent(key)}`
            _pendingRequest = "musixmatch_macro"
        }
        console.log("LyricsService: fetching provider=", _currentProvider, "url=", url)
        // Add HTTP code marker for all providers; include optional UA header
        const _ua = Config.options?.networking?.userAgent || ""
        const _uaHeader = _ua ? `-H 'User-Agent: ${_ua.replace(/'/g, "'\\''")}'` : ""
        fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader} -w '\n%{http_code}\n' '${url}'`]
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: ["bash", "-c", "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const all = text || ""
                // Try to split out trailing HTTP status code added by curl -w
                let httpStatus = 0
                let raw = all
                const m = all.match(/\n(\d{3})\s*$/)
                if (m) {
                    httpStatus = parseInt(m[1])
                    raw = all.slice(0, all.length - m[0].length)
                }
                console.log("LyricsService: response provider=", root._currentProvider, "pending=", root._pendingRequest, "status=", httpStatus, "bytes=", raw.length)
                if (httpStatus === 404) {
                    // Try next provider on 404
                    root._tryNextProvider()
                    return
                }
                if (raw.length === 0) {
                    // Try next provider on empty
                    root._tryNextProvider()
                    return
                }
                if (root._currentProvider === "lrclib") {
                    try {
                        const resp = JSON.parse(raw)
                        const syncedText = resp?.syncedLyrics || ""
                        if (syncedText && syncedText.length > 0) {
                            root.lines = parseSynced(syncedText)
                            root.synced = true
                            root.available = root.lines.length > 0
                            root.karaoke = false
                            root.karaokeLines = []
                            console.log("LyricsService: LRCLIB parsed lines=", root.lines.length)
                        } else {
                            // Nothing useful, try next
                            root._tryNextProvider()
                            return
                        }
                    } catch (e) {
                        // Fallback: sometimes the endpoint may return raw LRC/plain on errors
                        const isLikelyLrc = /\n?\s*\[\d{1,2}:\d{1,2}(?:[\.:]\d{1,2})?\]/.test(raw)
                        if (isLikelyLrc) {
                            try {
                                root.lines = parseSynced(raw)
                                root.synced = true
                                root.available = root.lines.length > 0
                                root.karaoke = false
                                root.karaokeLines = []
                                console.log("LyricsService: LRCLIB fallback LRC lines=", root.lines.length)
                            } catch (_) {
                                root._tryNextProvider()
                                return
                            }
                        } else {
                            root._tryNextProvider()
                            return
                        }
                    }
                } else if (root._currentProvider === "netease") {
                    const base = Config.options?.lyrics?.neteaseBaseUrl || ""
                    if (!base) { root._tryNextProvider(); return }
                    if (root._pendingRequest === "netease_search") {
                        try {
                            const resp = JSON.parse(raw)
                            const song = resp?.result?.songs?.[0]
                            const id = song?.id
                            console.log("LyricsService: NetEase search songs=", resp?.result?.songs?.length || 0, "id=", id)
                            if (!id) { root._tryNextProvider(); return }
                            root._neteaseSongId = id
                            const url2 = `${base.replace(/\/$/, "")}/lyric?id=${id}`
                            root._pendingRequest = "netease_lyric"
                            console.log("LyricsService: fetching NetEase lyric url=", url2)
                            const _ua = Config.options?.networking?.userAgent || ""
                            const _uaHeader = _ua ? `-H 'User-Agent: ${_ua.replace(/'/g, "'\\''")}'` : ""
                            fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader} -w '\n%{http_code}\n' '${url2}'`]
                            fetchProc.running = true
                            return
                        } catch (e) {
                            root._tryNextProvider();
                            return
                        }
                    } else if (root._pendingRequest === "netease_lyric") {
                        try {
                            const resp = JSON.parse(raw)
                            const klyric = resp?.klyric?.lyric || ""
                            const lrc = resp?.lrc?.lyric || ""
                            if (resp?.nolyric === true || resp?.uncollected === true) {
                                console.log("LyricsService: NetEase reports no lyrics (nolyric/uncollected)")
                                root._tryNextProvider();
                                return
                            }
                            console.log("LyricsService: NetEase lyric lengths k=", (klyric||"").length, "lrc=", (lrc||"").length)
                            if (klyric && klyric.length > 0) {
                                const structured = parseKLyricStructured(klyric)
                                if (structured.length > 0) {
                                    root.karaokeLines = structured
                                    // Derive line-synced entries from first word of each line
                                    root.lines = structured
                                        .filter(l => l.words && l.words.length > 0)
                                        .map(l => ({ time: l.start, text: l.text }))
                                    root.synced = true
                                    root.karaoke = true
                                    root.available = root.lines.length > 0
                                    console.log("LyricsService: NetEase klyric parsed lines=", root.lines.length)
                                } else if (lrc && /\[\d{1,2}:\d{1,2}/.test(lrc)) {
                                    root.lines = parseSynced(lrc)
                                    root.synced = true
                                    root.karaoke = false
                                    root.karaokeLines = []
                                    root.available = root.lines.length > 0
                                    console.log("LyricsService: NetEase LRC parsed lines=", root.lines.length)
                                } else {
                                    root._tryNextProvider();
                                    return
                                }
                            } else if (lrc && /\[\d{1,2}:\d{1,2}/.test(lrc)) {
                                root.lines = parseSynced(lrc)
                                root.synced = true
                                root.karaoke = false
                                root.karaokeLines = []
                                root.available = root.lines.length > 0
                                console.log("LyricsService: NetEase LRC parsed lines=", root.lines.length)
                            } else {
                                root._tryNextProvider();
                                return
                            }
                        } catch (e) {
                            root._tryNextProvider();
                            return
                        } finally {
                            root._pendingRequest = ""
                        }
                    } else {
                        root._tryNextProvider();
                        return
                    }
                } else if (root._currentProvider === "musixmatch") {
                    const key = Config.options?.lyrics?.musixmatch?.apiKey || ""
                    const base = "https://apic-desktop.musixmatch.com/ws/1.1"
                    if (!key) { root._tryNextProvider(); return }
                    try {
                        const resp = JSON.parse(raw)
                        if (root._pendingRequest === "musixmatch_macro") {
                            // Macro response may already include richsync
                            const macro = resp?.message?.body
                            let rich = macro?.macro_calls?.["track.richsync.get"]?.message?.body?.richsync
                                || macro?.richsync
                                || macro?.subtitle_list?.[0]?.subtitle?.subtitle_body
                                || ""
                            // If richsync isn't directly present, try getting commontrack_id for explicit call
                            if (!rich) {
                                const commonId = macro?.macro_calls?.["matcher.track.get"]?.message?.body?.track?.commontrack_id
                                    || macro?.track_list?.[0]?.track?.commontrack_id
                                if (commonId) {
                                    const url2 = `${base}/track.richsync.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&commontrack_id=${commonId}&usertoken=${encodeURIComponent(key)}`
                                    root._pendingRequest = "musixmatch_richsync"
                                    const _ua = Config.options?.networking?.userAgent || ""
                                    const _uaHeader = _ua ? `-H 'User-Agent: ${_ua.replace(/'/g, "'\\''")}'` : ""
                                    console.log("LyricsService: Musixmatch track.richsync.get commontrack_id=", commonId)
                                    fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader} -w '\n%{http_code}\n' '${url2}'`]
                                    fetchProc.running = true
                                    return
                                }
                            }
                            // If we have richsync or subtitle body, try to parse
                            if (rich) {
                                if (typeof rich === 'string') {
                                    // Could be LRC or JSON mxm string
                                    const looksLrc = /\[\d{1,2}:\d{1,2}/.test(rich)
                                    if (looksLrc) {
                                        root.lines = parseSynced(rich)
                                        root.synced = true
                                        root.karaoke = false
                                        root.karaokeLines = []
                                        root.available = root.lines.length > 0
                                        root._pendingRequest = ""
                                        console.log("LyricsService: Musixmatch LRC via macro parsed lines=", root.lines.length)
                                    } else {
                                        // Try mxm JSON
                                        try {
                                            const richObj = JSON.parse(rich)
                                            _applyMusixmatchRichsync(richObj)
                                            root._pendingRequest = ""
                                        } catch (_) {
                                            root._tryNextProvider(); return
                                        }
                                    }
                                } else {
                                    // Assume it's already a parsed object/array
                                    _applyMusixmatchRichsync(rich)
                                    root._pendingRequest = ""
                                }
                            } else {
                                // Nothing useful
                                root._tryNextProvider(); return
                            }
                        } else if (root._pendingRequest === "musixmatch_richsync") {
                            const rich = resp?.message?.body?.richsync || ""
                            if (rich) {
                                if (typeof rich === 'string') {
                                    try { _applyMusixmatchRichsync(JSON.parse(rich)) } catch (e) { root._tryNextProvider(); return }
                                } else {
                                    _applyMusixmatchRichsync(rich)
                                }
                                root._pendingRequest = ""
                            } else {
                                // As last resort try lyrics body (plain)
                                const body = resp?.message?.body?.lyrics?.lyrics_body || ""
                                if (body) {
                                    let txt = body
                                    const cut = txt.indexOf("*******"); if (cut > 0) txt = txt.slice(0, cut)
                                    root.lines = plainToLines(txt)
                                    root.synced = false
                                    root.karaoke = false
                                    root.karaokeLines = []
                                    root.available = root.lines.length > 0
                                    root._pendingRequest = ""
                                } else {
                                    root._tryNextProvider(); return
                                }
                            }
                        } else if (root._pendingRequest === "musixmatch_lyrics") {
                            let body = resp?.message?.body?.lyrics?.lyrics_body || ""
                            if (body) {
                                const cut = body.indexOf("*******"); if (cut > 0) body = body.slice(0, cut)
                                root.lines = plainToLines(body)
                                root.synced = false
                                root.karaoke = false
                                root.karaokeLines = []
                                root.available = root.lines.length > 0
                                root._pendingRequest = ""
                                console.log("LyricsService: Musixmatch plain lyrics lines=", root.lines.length)
                            } else {
                                root._pendingRequest = ""
                                root._tryNextProvider(); return
                            }
                        } else {
                            // Unexpected state; try next
                            root._pendingRequest = ""
                            root._tryNextProvider(); return
                        }
                    } catch (e) {
                        // Parsing or structure error; try next provider
                        root._pendingRequest = ""
                        root._tryNextProvider(); return
                    }
                }
                // Update the currently displayed line immediately
                root._updateIndex()
            }
        }
    }

    // Parse NetEase klyric into structured karaoke lines
    // Example segments inside a line: [mm:ss.xx]<start,dur,0>word<start2,dur2,0>next ...
    function parseKLyricStructured(ktext) {
        const out = []
        const lines = ktext.split(/\r?\n/)
        for (let line of lines) {
            if (!line || !line.trim()) continue
            let idx = 0
            // Extract line timestamp [mm:ss.xx]
            let startMs = 0
            const m = line.match(/^\[(\d{1,2}):(\d{1,2})(?:[\.:](\d{1,3}))?]/)
            if (m) {
                const mm = parseInt(m[1])||0
                const ss = parseInt(m[2])||0
                const cs = m[3] ? parseInt(String(m[3]).slice(0,2)) : 0
                startMs = mm*60000 + ss*1000 + cs*10
                idx = m[0].length
            }
            const words = []
            let plainText = ""
            // Iterate tags like <start,dur,flag>text
            const re = /<([\d]+),([\d]+),[\d]+>([^<]+)/g
            let wm
            while ((wm = re.exec(line.slice(idx))) !== null) {
                const t = parseInt(wm[1])||0
                const d = parseInt(wm[2])||0
                const txt = (wm[3]||"")
                words.push({ t: startMs + t, d: d, text: txt })
                plainText += txt
            }
            if (words.length > 0) {
                out.push({ start: words[0].t, text: plainText.trim(), words: words })
            } else if (startMs > 0) {
                // Fallback to line-level timing only
                const rest = line.slice(idx).replace(/<[^>]*>/g, "").trim()
                if (rest.length > 0) out.push({ start: startMs, text: rest, words: [] })
            }
        }
        return out
    }

    // Parse Musixmatch richsync JSON into our karaoke structure
    // Accepts variants where:
    // - lines array is under rich.lines or rich['lines'] or richsync.lines
    // - line start is under 'time' or 'ts'
    // - word array is under 'words' or 'w'
    // - word keys: time 't' or 'time', duration 'd' or 'duration', text 'text' or 'c'
    function parseMusixmatchRichsync(rich) {
        try {
            const body = (rich && rich.richsync) ? rich.richsync : rich
            const lines = body?.lines || body?.richsync?.lines || []
            const out = []
            for (let i = 0; i < lines.length; i++) {
                const L = lines[i] || {}
                const wordsArr = L.words || L.w || []
                const start = (typeof L.time === 'number' ? L.time : (typeof L.ts === 'number' ? L.ts : 0))
                const words = []
                let text = typeof L.text === 'string' ? L.text : (typeof L.l === 'string' ? L.l : "")
                for (let j = 0; j < wordsArr.length; j++) {
                    const W = wordsArr[j] || {}
                    const t = (typeof W.t === 'number' ? W.t : (typeof W.time === 'number' ? W.time : 0))
                    const d = (typeof W.d === 'number' ? W.d : (typeof W.duration === 'number' ? W.duration : 0))
                    const wtxt = (typeof W.text === 'string' ? W.text : (typeof W.c === 'string' ? W.c : ""))
                    words.push({ t: t, d: d, text: wtxt })
                }
                if (!text && words.length > 0) {
                    // Build line text from word texts
                    text = words.map(w => w.text).join("").trim()
                }
                if (words.length > 0 || text) {
                    const lineStart = words.length > 0 ? words[0].t : start
                    out.push({ start: lineStart, text: text, words: words })
                }
            }
            // Sort by start time
            out.sort((a, b) => (a.start - b.start))
            return out
        } catch (e) {
            return []
        }
    }

    // Apply Musixmatch richsync to service state
    function _applyMusixmatchRichsync(rich) {
        const structured = parseMusixmatchRichsync(rich)
        if (structured.length > 0) {
            root.karaokeLines = structured
            root.lines = structured.map(l => ({ time: l.start, text: l.text }))
            root.synced = true
            root.karaoke = true
            root.available = root.lines.length > 0
            console.log("LyricsService: Musixmatch richsync parsed lines=", root.lines.length)
        } else {
            // No richsync; try to fallback if caller wishes
            console.log("LyricsService: Musixmatch richsync empty or invalid")
        }
    }

    // Parse LRC format
    function parseSynced(lrc) {
        const out = []
        // Accept mm:ss.xx or mm:ss.xxx with . : or , as separators for subsecond
        const re = /^\s*\[(\d{1,2}):(\d{1,2})(?:[\.:,](\d{1,3}))?\]\s*(.*)$/
        const lines = lrc.split(/\r?\n/)
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re)
            if (m) {
                const min = parseInt(m[1]) || 0
                const sec = parseInt(m[2]) || 0
                const fracStr = m[3] || "0"
                const fracNum = parseInt(fracStr) || 0
                // If 3 digits, treat as milliseconds; if 1-2 digits, treat as centiseconds
                const subMs = (fracStr.length === 3) ? fracNum : (fracNum * 10)
                const ms = min * 60000 + sec * 1000 + subMs
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

    // Public: expose effective position for UI (karaoke highlighting)
    function effectivePosMs() { return _effectivePosMs() }

    // Helper to get karaoke segments for current line
    function karaokeSegmentsFor(index) {
        const i = (typeof index === 'number') ? index : currentIndex
        if (i < 0 || i >= karaokeLines.length) return []
        return karaokeLines[i]?.words || []
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
        interval: 1000 // every 1s for tighter tracking
        onTriggered: {
            if (!_player?.isPlaying) return
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
            const alpha = Math.abs(errDelta) > 1500 ? 0.3 : 0.15
            const newOffset = Math.round(root.timeOffsetMs + alpha * errDelta)
            // Clamp to reasonable bounds to avoid wild jumps
            root.timeOffsetMs = Math.max(-5000, Math.min(5000, newOffset))
            // Also refresh current index if offset meaningfully changed
            if (Math.abs(errDelta) > 50) root._updateIndex()
        }
    }

    Component.onCompleted: maybeFetch()
}
