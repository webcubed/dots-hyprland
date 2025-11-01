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
    // Track if any provider explicitly says there are no lyrics (successful response, empty/no-lyrics)
    property bool _explicitNoLyrics: false

    // Build a cache key for current track (use title+artist only to avoid churn as length updates)
    function _trackKey() {
        const t = StringUtils.cleanMusicTitle(_player?.trackTitle) || ""
        const a = _player?.trackArtist || ""
        return `${t}::${a}`
    }

    // Optional debug notification using notify-send
    function _notifyProvider(title, message) {
        if (!Config.options?.lyrics?.debugNotify) return
        try {
            Quickshell.execDetached(["notify-send", "-a", "LyricsService", String(title || "Lyrics"), String(message || "")])
        } catch (e) {
            // ignore
        }
    }

    // Config helpers: allow users to toggle Musixmatch karaoke (richsync) vs regular (subtitles/plain)
    function _mxmEnableRich() {
        const mm = Config.options?.lyrics?.musixmatch || {}
        if (mm.enableRichsync !== undefined) return !!mm.enableRichsync
        if (mm.richsyncEnable !== undefined) return !!mm.richsyncEnable
        if (mm.enable !== undefined) return !!mm.enable // backwards compat
        return true
    }
    function _mxmEnableRegular() {
        const mm = Config.options?.lyrics?.musixmatch || {}
        if (mm.enableRegular !== undefined) return !!mm.enableRegular
        if (mm.enablePlain !== undefined) return !!mm.enablePlain
        if (mm.enable !== undefined) return !!mm.enable // backwards compat
        return true
    }

    // Query providers
    function _fetchLyrics() {
        // Read metadata first; do NOT clear existing lyrics if metadata incomplete
        const track = (MprisController.activePlayer?.trackTitle || "").trim()
        const artistCombined = (MprisController.activePlayer?.trackArtist || "").trim()
        const artistsArray = (MprisController.activePlayer?.trackArtists || [])
        const artist = (artistCombined || artistsArray.join(', ')).trim()
        if (!track || !artist) {
            // Not enough metadata; keep current display intact
            console.log("LyricsService: skip fetch due to missing metadata track=", track, "artist=", artist)
            return
        }
        // Now reset state for a new fetch
        available = false
        synced = false
        karaoke = false
        karaokeLines = []
        lines = []
        currentIndex = -1
        currentText = ""
        loading = true
        _explicitNoLyrics = false
        timeOffsetMs = 0
        _lastPosObservedMs = _posMs()
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
    // Bounded retry to recover when matcher.lyrics is empty but karaoke may exist via matcher.track
    property int _mxmRetryCount: 0
    // Track if Musixmatch has been attempted this cycle, to avoid repeated upgrade attempts
    property bool _musixmatchTried: false

    // Attempt providers in order (prioritize karaoke-capable):
    // 0 = NetEase Cloud Music (klyric + lrc), 1 = Musixmatch (synced LRC or plain or karaoke), 2 = LRCLib (synced only)
    function _tryNextProvider() {
        // Do not start another provider while a request is still in flight
        if (root._pendingRequest && root._pendingRequest.length > 0) {
            console.log("LyricsService: defer _tryNextProvider(); pending=", root._pendingRequest)
            return
        }
        // If we already have lyrics, do not advance to other providers
        if (root.available && root.lines && root.lines.length > 0) {
            const wantMxm = (_mxmEnableRich() || _mxmEnableRegular())
            // Allow an upgrade attempt to Musixmatch karaoke if we only have non-karaoke lyrics so far
            if (!root.karaoke && wantMxm && _mxmEnableRich() && !root._musixmatchTried) {
                root._musixmatchTried = true
                _providerIndex = 0
                _currentProvider = "musixmatch"
                _pendingRequest = ""
                console.log("LyricsService: upgrading to Musixmatch karaoke attempt")
                _fetchLyrics()
                return
            } else {
                root.loading = false
                return
            }
        }
        const wantLrclib = !!Config.options?.lyrics?.enableLrclib
        const wantNetease = !!Config.options?.lyrics?.netease?.enable
        const wantMxm = (_mxmEnableRich() || _mxmEnableRegular())
        const providers = []
        // Prefer karaoke-capable provider first
        if (wantMxm) providers.push("musixmatch")
        if (wantNetease) providers.push("netease")
        if (wantLrclib) providers.push("lrclib")
        if (providers.length === 0) {
            // No providers enabled; do not overwrite existing lyrics
            console.log("LyricsService: no providers enabled; keeping existing lyrics")
            loading = false
            available = (root.lines && root.lines.length > 0)
            return
        }
        if (_providerIndex >= providers.length) {
            // Providers exhausted. Only show explicit "No lyrics" if a provider definitively said so.
            loading = false
            if (root._explicitNoLyrics) {
                _setNoLyrics()
            } else {
                available = (root.lines && root.lines.length > 0)
            }
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
            const wantRich = _mxmEnableRich()
            const wantRegular = _mxmEnableRegular()
            // If neither mode is enabled, skip
            if (!wantRich && !wantRegular) { _tryNextProvider(); return }
            // Fetch karaoke richsync first when enabled, otherwise go straight to regular (subtitle/plain)
            const key = Config.options?.lyrics?.musixmatch?.apiKey || ""
            if (!key) { _tryNextProvider(); return }
            // reset per-track retry counter
            _mxmRetryCount = 0
            _musixmatchTrackId = 0
            const base = "https://apic-desktop.musixmatch.com/ws/1.1"
            const trackQ = encodeURIComponent(_qTrack)
            const artistQ = encodeURIComponent(_qArtist)
            if (wantRich) {
                // Karaoke path via macro to prefer richsync/subtitles in one request
                url = `${base}/macro.subtitles.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_track=${trackQ}&q_artist=${artistQ}&usertoken=${encodeURIComponent(key)}`
                _pendingRequest = "musixmatch_macro"
            } else {
                // Regular only: try direct subtitle first, then plain lyrics
                const _ua2 = Config.options?.networking?.userAgent || ""
                const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                const urlSub = `${base}/matcher.subtitle.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_artist=${artistQ}&q_track=${trackQ}&usertoken=${encodeURIComponent(key)}`
                _pendingRequest = "musixmatch_matcher_subtitle"
                console.log("LyricsService: Musixmatch regular-only; trying matcher.subtitle.get")
                fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader2} -w '\n%{http_code}\n' '${urlSub}'`]
                fetchProc.running = true
                return
            }
        }
        console.log("LyricsService: fetching provider=", _currentProvider, "url=", url)
        // Optional debug notification
        _notifyProvider("Lyrics Provider", `${_currentProvider} — ${_qArtist} - ${_qTrack}`)
        // Add HTTP code marker for all providers; include optional UA header
        const _ua = Config.options?.networking?.userAgent || "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.6998.178 Spotify/1.2.63.394 Safari/537.36"
        const _uaHeader = _ua ? `-H 'User-Agent: ${_ua.replace(/'/g, "'\\''")}'` : ""
        const _mxmHeadersInit = `${_uaHeader} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
        fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeadersInit} -w '\n%{http_code}\n' '${url}'`]
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
                // Handle common error/redirect statuses early by advancing provider chain
                if (httpStatus === 404 || httpStatus === 401 || httpStatus === 403 || httpStatus === 429 || httpStatus === 301 || httpStatus === 302 || httpStatus === 307 || httpStatus === 308) {
                    root._pendingRequest = ""
                    root._tryNextProvider()
                    return
                }
                if (raw.length === 0) {
                    // Try next provider on empty; clear pending to avoid deferral
                    root._pendingRequest = ""
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
                            root._explicitNoLyrics = true
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
                                root._explicitNoLyrics = true
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
                            // Try to get richsync_body from nested macro call first
                            let rich = macro?.macro_calls?.["track.richsync.get"]?.message?.body?.richsync?.richsync_body
                                || macro?.richsync?.richsync_body
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
                                    const _mxmHeaders = `${_uaHeader} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                    console.log("LyricsService: Musixmatch track.richsync.get commontrack_id=", commonId)
                                    fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${url2}'`]
                                    fetchProc.running = true
                                    return
                                }
                            }
                            // If we have richsync try to parse
                            if (rich) {
                                if (typeof rich === 'string') {
                                    try {
                                        const richObj = JSON.parse(rich)
                                        _applyMusixmatchRichsync(richObj)
                                        root._pendingRequest = ""
                                    } catch (_) {
                                        // continue to subtitle parsing
                                    }
                                } else {
                                    // Assume it's already a parsed object/array
                                    _applyMusixmatchRichsync(rich)
                                    root._pendingRequest = ""
                                }
                            }
                            if (root._pendingRequest === "musixmatch_macro") {
                                // No richsync parsed yet; try subtitles from macro
                                const subBody = macro?.macro_calls?.["track.subtitles.get"]?.message?.body?.subtitle_list?.[0]?.subtitle?.subtitle_body
                                    || macro?.subtitle_list?.[0]?.subtitle?.subtitle_body
                                if (subBody) {
                                    const arr = parseMusixmatchSubtitles(subBody)
                                    if (arr.length > 0) {
                                        root.lines = arr
                                        root.synced = true
                                        root.karaoke = false
                                        root.karaokeLines = []
                                        root.available = root.lines.length > 0
                                        root._pendingRequest = ""
                                        console.log("LyricsService: Musixmatch subtitles parsed lines=", root.lines.length)
                                    } else {
                                        // As last resort, try plain lyrics from macro
                                        let bodyTxt = macro?.macro_calls?.["track.lyrics.get"]?.message?.body?.lyrics?.lyrics_body || ""
                                        if (bodyTxt) {
                                            const cut = bodyTxt.indexOf("*******"); if (cut > 0) bodyTxt = bodyTxt.slice(0, cut)
                                            root.lines = plainToLines(bodyTxt)
                                            root.synced = false
                                            root.karaoke = false
                                            root.karaokeLines = []
                                            root.available = root.lines.length > 0
                                            root._pendingRequest = ""
                                            console.log("LyricsService: Musixmatch plain via macro lines=", root.lines.length)
                                        } else {
                                            // Nothing parsed from macro; try direct subtitles via matcher.subtitle.get
                                            const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                            const trackQ2 = encodeURIComponent(root._qTrack)
                                            const artistQ2 = encodeURIComponent(root._qArtist)
                                            const urlSub = `${base2}/matcher.subtitle.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                            root._pendingRequest = "musixmatch_matcher_subtitle"
                                            const _ua2 = Config.options?.networking?.userAgent || ""
                                            const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                            console.log("LyricsService: Musixmatch matcher.subtitle.get fallback url=", urlSub)
                                            fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader2} -w '\n%{http_code}\n' '${urlSub}'`]
                                            fetchProc.running = true
                                            return
                                        }
                                    }
                                } else {
                                    // Nothing useful from macro; try direct subtitles via matcher.subtitle.get
                                    // subtitle = line synced
                                    const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                    const trackQ2 = encodeURIComponent(root._qTrack)
                                    const artistQ2 = encodeURIComponent(root._qArtist)
                                    const urlSub = `${base2}/matcher.subtitle.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                    root._pendingRequest = "musixmatch_matcher_subtitle"
                                    const _ua2 = Config.options?.networking?.userAgent || ""
                                    const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                    const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                    console.log("LyricsService: Musixmatch matcher.subtitle.get (no macro content)")
                                    fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${urlSub}'`]
                                    fetchProc.running = true
                                    return
                                }
                            }
                        } else if (root._pendingRequest === "musixmatch_richsync") {
                            const rich = resp?.message?.body?.richsync?.richsync_body || ""
                            const rType = typeof rich
                            const rLen = rType === 'string' ? rich.length : (rich?.lines?.length || (Array.isArray(rich) ? rich.length : 0))
                            console.log("LyricsService: Musixmatch richsync_body type=", rType, "len=", rLen)
                            if (rich) {
                                if (typeof rich === 'string') {
                                    try {
                                        const preview = rich.slice(0, 240)
                                        console.log("LyricsService: richsync_body[0:240]=", preview)
                                        const parsed = JSON.parse(rich)
                                        _applyMusixmatchRichsync(parsed)
                                    } catch (e) {
                                        console.log("LyricsService: richsync JSON.parse error:", e && e.message)
                                        root._tryNextProvider(); return
                                    }
                                } else {
                                    const lineCount = (rich?.lines?.length || (Array.isArray(rich) ? rich.length : 0))
                                    console.log("LyricsService: richsync object lines=", lineCount)
                                    _applyMusixmatchRichsync(rich)
                                }
                                root._pendingRequest = ""
                            } else {
                                // As last resort, try plain lyrics in the same response body
                                const body = resp?.message?.body?.lyrics?.lyrics_body || ""
                                const hasPlain = typeof body === 'string' && body.length > 0
                                console.log("LyricsService: Musixmatch richsync missing; plain lyrics present=", hasPlain, "len=", hasPlain ? body.length : 0)
                                if (hasPlain) {
                                    let txt = body
                                    const cut = txt.indexOf("*******"); if (cut > 0) txt = txt.slice(0, cut)
                                    const parsedPlain = plainToLines(txt)
                                    root.lines = parsedPlain
                                    root.synced = false
                                    root.karaoke = false
                                    root.karaokeLines = []
                                    root.available = root.lines.length > 0
                                    root._pendingRequest = ""
                                    console.log("LyricsService: Musixmatch plain-from-richsync lines=", parsedPlain.length, parsedPlain.slice(0, 2))
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
                                // Nothing from matcher.lyrics.
                                // Allow a single bounded retry back to matcher.track.get (to recover transient misses),
                                // then advance to the next provider to avoid loops.
                                if (root._mxmRetryCount < 1) {
                                    root._mxmRetryCount++
                                    const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                    const trackQ2 = encodeURIComponent(root._qTrack)
                                    const artistQ2 = encodeURIComponent(root._qArtist)
                                    const url2 = `${base2}/matcher.track.get?format=json&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                    root._pendingRequest = "musixmatch_matcher"
                                    const _ua2 = Config.options?.networking?.userAgent || ""
                                    const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                    const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                    console.log("LyricsService: Musixmatch lyrics empty; retrying matcher.track.get once")
                                    fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${url2}'`]
                                    fetchProc.running = true
                                    return
                                } else {
                                    root._pendingRequest = ""
                                    // Explicitly empty from Musixmatch after successful responses => treat as no lyrics
                                    root._explicitNoLyrics = true
                                    console.log("LyricsService: Musixmatch lyrics empty after retry; advancing to next provider")
                                    root._tryNextProvider()
                                    return
                                }
                            }
                        } else if (root._pendingRequest === "musixmatch_matcher_subtitle") {
                            // Parse subtitles from matcher.subtitle.get
                            const subBody = resp?.message?.body?.subtitle?.subtitle_body || ""
                            if (subBody) {
                                const arr = parseMusixmatchSubtitles(subBody)
                                if (arr.length > 0) {
                                    root.lines = arr
                                    root.synced = true
                                    root.karaoke = false
                                    root.karaokeLines = []
                                    root.available = root.lines.length > 0
                                    root._pendingRequest = ""
                                    console.log("LyricsService: Musixmatch subtitles via matcher parsed lines=", root.lines.length)
                                    // Update UI
                                    
                                } else {
                                    // Try plain lyrics via matcher.lyrics.get next
                                    const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                    const trackQ2 = encodeURIComponent(root._qTrack)
                                    const artistQ2 = encodeURIComponent(root._qArtist)
                                    const url2 = `${base2}/matcher.lyrics.get?format=json&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                    root._pendingRequest = "musixmatch_lyrics"
                                    const _ua2 = Config.options?.networking?.userAgent || ""
                                    const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                    console.log("LyricsService: Musixmatch matcher.lyrics.get after empty matcher.subtitle")
                                    fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_uaHeader2} -w '\n%{http_code}\n' '${url2}'`]
                                    fetchProc.running = true
                                    return
                                }
                            } else {
                                // No subtitles field; try matcher.lyrics.get before resolving commontrack_id
                                const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                const trackQ2 = encodeURIComponent(root._qTrack)
                                const artistQ2 = encodeURIComponent(root._qArtist)
                                const url2 = `${base2}/matcher.lyrics.get?format=json&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                root._pendingRequest = "musixmatch_lyrics"
                                const _ua2 = Config.options?.networking?.userAgent || ""
                                const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                console.log("LyricsService: Musixmatch matcher.lyrics.get after missing matcher.subtitle")
                                const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${url2}'`]
                                fetchProc.running = true
                                return
                            }
                        } else if (root._pendingRequest === "musixmatch_matcher") {
                            // Resolve commontrack_id from matcher, then request richsync
                            const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                            const commonId = resp?.message?.body?.track?.commontrack_id || 0
                            if (commonId && Number(commonId) > 0) {
                                const trackQ2 = encodeURIComponent(root._qTrack)
                                const artistQ2 = encodeURIComponent(root._qArtist)
                                const url2 = `${base2}/track.richsync.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&usertoken=${encodeURIComponent(key)}&q_track=${trackQ2}&q_artist=${artistQ2}&commontrack_id=${commonId}`
                                root._pendingRequest = "musixmatch_richsync"
                                const _ua2 = Config.options?.networking?.userAgent || ""
                                const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                console.log("LyricsService: Musixmatch richsync via matcher commontrack_id=", commonId)
                                const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${url2}'`]
                                fetchProc.running = true
                                return
                            } else {
                                // No commontrack_id from matcher; try direct subtitles before giving up
                                const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                                const trackQ2 = encodeURIComponent(root._qTrack)
                                const artistQ2 = encodeURIComponent(root._qArtist)
                                const urlSub = `${base2}/matcher.subtitle.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&q_artist=${artistQ2}&q_track=${trackQ2}&usertoken=${encodeURIComponent(key)}`
                                root._pendingRequest = "musixmatch_matcher_subtitle"
                                const _ua2 = Config.options?.networking?.userAgent || ""
                                const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                console.log("LyricsService: Musixmatch matcher.track.get missing commontrack_id; trying matcher.subtitle.get")
                                fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${urlSub}'`]
                                fetchProc.running = true
                                return
                            }
                        } else if (root._pendingRequest === "musixmatch_search") {
                            const base2 = "https://apic-desktop.musixmatch.com/ws/1.1"
                            const list = resp?.message?.body?.track_list || []
                            const first = list?.[0]?.track
                            const commonId = first?.commontrack_id || 0
                            if (commonId && Number(commonId) > 0) {
                                const trackQ2 = encodeURIComponent(root._qTrack)
                                const artistQ2 = encodeURIComponent(root._qArtist)
                                const url2 = `${base2}/track.richsync.get?format=json&subtitle_format=mxm&app_id=web-desktop-app-v1.0&usertoken=${encodeURIComponent(key)}&q_track=${trackQ2}&q_artist=${artistQ2}&commontrack_id=${commonId}`
                                root._pendingRequest = "musixmatch_richsync"
                                const _ua2 = Config.options?.networking?.userAgent || ""
                                const _uaHeader2 = _ua2 ? `-H 'User-Agent: ${_ua2.replace(/'/g, "'\\''")}'` : ""
                                const _mxmHeaders = `${_uaHeader2} -H 'Accept: */*' -H 'Accept-Language: en' -H 'Content-Type: application/json' -H 'Origin: https://xpui.app.spotify.com' -H 'Referer: https://xpui.app.spotify.com/' -H 'Cookie: AWSELB=unknown'`
                                console.log("LyricsService: Musixmatch richsync via search commontrack_id=", commonId)
                                fetchProc.command = ["bash", "-c", `curl -sSL --max-time 5 ${_mxmHeaders} -w '\n%{http_code}\n' '${url2}'`]
                                fetchProc.running = true
                                return
                            } else {
                                // Give up on Musixmatch
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
            // Two possible shapes:
            // 1) { lines: [{ ts, te, x, l: [{ c, o }, ...] }, ...] }
            // 2) [{ ts, te, x, l: [...] }, ...]
            const lines = body?.lines || body || []
            const out = []
            for (let i = 0; i < lines.length; i++) {
                const L = lines[i] || {}
                const wordsArr = L.words || L.w || L.l || []
                const tsRaw = (typeof L.ts === 'number' ? L.ts : (typeof L.time === 'number' ? L.time : 0))
                const teRaw = (typeof L.te === 'number' ? L.te : tsRaw)
                // Heuristic: ts in seconds if small, otherwise milliseconds
                const tsMs = (tsRaw > 10000 ? Math.round(tsRaw) : Math.round(tsRaw * 1000))
                const teMs = (teRaw > 10000 ? Math.round(teRaw) : Math.round(teRaw * 1000))
                const words = []
                let text = typeof L.text === 'string' ? L.text : (typeof L.x === 'string' ? L.x : "")
                for (let j = 0; j < wordsArr.length; j++) {
                    const W = wordsArr[j] || {}
                    // W.o is offset seconds relative to line start (ts), W.c is the token text
                    const rel = (typeof W.o === 'number' ? W.o : (typeof W.t === 'number' ? W.t : 0))
                    const nextRel = (typeof (wordsArr[j+1]?.o) === 'number' ? wordsArr[j+1].o : (typeof (wordsArr[j+1]?.t) === 'number' ? wordsArr[j+1].t : ((teRaw || tsRaw) - tsRaw)))
                    // Provide word timings RELATIVE to the line start; KaraokeLine uses timesRelative=true
                    const startRel = rel
                    const dur = Math.max(0, (nextRel - rel))
                    const wtxt = (typeof W.text === 'string' ? W.text : (typeof W.c === 'string' ? W.c : ""))
                    words.push({ t: Math.round(startRel * 1000), d: Math.round(dur * 1000), text: wtxt })
                }
                if (!text && words.length > 0) {
                    // Build line text from word texts
                    text = words.map(w => w.text).join("").trim()
                }
                if (words.length > 0 || text) {
                    const lineStart = (tsMs > 0 ? tsMs : (words.length > 0 ? words[0].t : 0))
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

    // Parse Musixmatch "track.subtitles.get" style JSON (array of { text, time: { total } })
    function parseMusixmatchSubtitles(subBody) {
        try {
            const arr = Array.isArray(subBody) ? subBody : JSON.parse(subBody)
            const out = []
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i]
                const txt = (it?.text || "").trim()
                const total = Number(it?.time?.total) || 0
                // Skip empty text entries (e.g., trailing empty line in example response)
                if (txt.length > 0) {
                    out.push({ time: Math.round(total * 1000), text: txt })
                }
            }
            return out
        } catch (e) {
            return []
        }
    }

    // Apply Musixmatch richsync to service state
    function _applyMusixmatchRichsync(rich) {
        const structured = parseMusixmatchRichsync(rich)
        console.log("LyricsService: parseMusixmatchRichsync lines=", structured.length)
        if (structured.length > 0) {
            root.karaokeLines = structured
            root.lines = structured.map(l => ({ time: l.start, text: l.text }))
            root.synced = true
            root.karaoke = true
            root.available = root.lines.length > 0
            const first = structured[0] || {}
            const wordsPreview = (first.words || []).slice(0, 3)
            console.log("LyricsService: Musixmatch richsync parsed lines=", root.lines.length, "first.start=", first.start, "first.words=", (first.words||[]).length, "words[0:3]=", wordsPreview)
            // Ensure immediate render in UI
            try { root._updateIndex() } catch(e) {}
            console.log("LyricsService: state after richsync apply available=", root.available, "karaoke=", root.karaoke, "currentIndex=", root.currentIndex, "currentText.len=", (root.currentText||"").length)
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
