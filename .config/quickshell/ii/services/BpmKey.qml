pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// BpmKey: provides derived audio features like BPM and musical key for the current track.
// Provider: Spotify (client credentials). Configure in Config.options.bpmkey.spotify.
Singleton {
    id: root

    // Public properties
    // bpm: integer BPM if known (0 when unknown)
    // key: musical key string like "C#m" or "Am" (empty string when unknown)
    property int bpm: 0
    property string key: ""
    property bool loading: false
    property string error: ""

    // Internal Spotify auth cache
    property string _token: ""
    property int _tokenExpiryMs: 0 // epoch ms
    property string _pending: "" // "token" | "search" | "features" | ""
    property string _trackId: ""
    property string _qArtist: ""
    property string _qTitle: ""
    property string _qAlbum: ""
    property bool _triedNoAlbum: false
    property string _cid: ""
    property string _csec: ""
    property bool _reauthed: false

    // Escape single quotes for safe inclusion inside single-quoted shell strings
    function _shEscapeSingle(s) {
        // Replace each ' with '\'' sequence
        return String(s).replace(/'/g, "'\\'" + "'")
    }

    // Fetch derived features for a track. Use any provider you configure.
    function fetch(artist, title, album) {
        const cid = (Config.options?.bpmkey?.spotify?.clientId || "").trim()
        const csec = (Config.options?.bpmkey?.spotify?.clientSecret || "").trim()
        const bearer = (Config.options?.bpmkey?.spotify?.bearerToken || "").trim()
        root.error = ""
        root.loading = true
        root.bpm = 0
        root.key = ""
        _qArtist = String(artist || "")
        _qTitle = String(title || "")
        _qAlbum = String(album || "")
        _triedNoAlbum = false
        _reauthed = false
        _cid = cid
        _csec = csec
        if (!_qArtist || !_qTitle) { root.loading = false; return }
        // Ensure token (prefer explicit bearer if provided)
        if (bearer) {
            _token = bearer
            _tokenExpiryMs = Date.now() + 3600 * 1000 // assume 1h validity; will work while session is alive
        } else if (!_hasValidToken()) {
            if (!cid || !csec) {
                root.error = "Spotify auth missing: set bpmkey.spotify clientId/clientSecret or bearerToken"
                root.loading = false
                return
            }
            _requestToken(cid, csec)
            return
        }
        _searchTrack()
    }

    // Utility to convert numeric key/mode from providers to notation string
    function keyFromNumeric(n, mode) {
        // n: 0..11, mode: 0 minor, 1 major (Spotify convention)
        const names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        if (!Number.isInteger(n) || n < 0 || n > 11) return ""
        const tonic = names[n]
        const isMinor = (mode === 0)
        return (tonic ? tonic : "") + (isMinor ? "m" : (tonic ? "" : ""))
    }

    function _hasValidToken() {
        const now = Date.now()
        return (_token && _tokenExpiryMs > (now + 30 * 1000))
    }

    function _requestToken(cid, csec) {
        _pending = "token"
        const auth = Qt.btoa(`${cid}:${csec}`)
        const cmd = [
            "bash", "-lc",
            // Use curl to get token; print JSON and status code
            `curl -sS --max-time 5 -H 'Authorization: Basic ${auth}' -H 'Accept: application/json' -d grant_type=client_credentials https://accounts.spotify.com/api/token -w "\\nHTTP_STATUS:%{http_code}"`
        ]
        console.log("BpmKey: requesting token")
        proc.command = cmd
        proc.running = true
    }

    function _searchTrack() {
        _pending = "search"
        const ua = Config.options?.bpmkey?.spotify?.userAgent || ""
        const uaHeader = ua ? `-H 'User-Agent: ${_shEscapeSingle(ua)}'` : ""
        const usingOverride = !!(Config.options?.bpmkey?.spotify?.bearerToken || "").trim()
        const qTitle = encodeURIComponent(_qTitle)
        const qArtist = encodeURIComponent(_qArtist)
        const qAlbum = _qAlbum ? `+album:${encodeURIComponent(_qAlbum)}` : ""
        const marketParam = usingOverride ? "&market=from_token" : ""
        const url = `https://api.spotify.com/v1/search?q=track:${qTitle}+artist:${qArtist}${qAlbum}&type=track${marketParam}&limit=1`
        const cmd = [
            "bash", "-lc",
            `curl -sS --max-time 6 -H 'Authorization: Bearer ${_token}' -H 'Accept: application/json' ${uaHeader} '${url}' -w "\\nHTTP_STATUS:%{http_code}"`
        ]
        console.log("BpmKey: searching track", decodeURIComponent(url))
        proc.command = cmd
        proc.running = true
    }

    function _fetchFeatures() {
        if (!_trackId) { root.loading = false; return }
        _pending = "features"
        const url = `https://api.spotify.com/v1/audio-features/${_trackId}`
        const cmd = [
            "bash", "-lc",
            `curl -sS --max-time 6 -H 'Authorization: Bearer ${_token}' -H 'Accept: application/json' '${url}' -w "\\nHTTP_STATUS:%{http_code}"`
        ]
        console.log("BpmKey: fetching features for", _trackId)
        proc.command = cmd
        proc.running = true
    }

    Process {
        id: proc
        command: ["bash", "-lc", "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const textAll = text || ""
                    let body = textAll
                    let status = 0
                    const sep = "\nHTTP_STATUS:"
                    const idx = textAll.lastIndexOf(sep)
                    if (idx !== -1) {
                        body = textAll.slice(0, idx)
                        status = Number(textAll.slice(idx + sep.length)) || 0
                    }
                    if (_pending)
                        console.log("BpmKey: stage=", _pending, "status=", status, "bytes=", body.length)
                    const data = body ? JSON.parse(body) : {};
                    if (status >= 400) {
                        console.error("BpmKey: HTTP error", status, "stage=", _pending, "body=", body.slice(0, 200))
                        // Determine if a bearer override is in effect
                        const usingOverride = !!(Config.options?.bpmkey?.spotify?.bearerToken || "").trim()
                        // Auto re-auth once on 401/403
                        if ((status === 401 || status === 403) && !_reauthed && _cid && _csec) {
                            _reauthed = true
                            _token = ""
                            _tokenExpiryMs = 0
                            _pending = ""
                            // If override was used, fall back to client credentials
                            console.log("BpmKey: auth error", status, usingOverride ? "(override)" : "(client)", "-> requesting new client token")
                            _requestToken(_cid, _csec)
                            return
                        }
                        // If search 403 with market=from_token, retry without market once
                        if (_pending === "search" && status === 403 && usingOverride && !_triedNoAlbum) {
                            console.log("BpmKey: 403 with market=from_token; retrying search without market")
                            _triedNoAlbum = true // reuse flag to avoid infinite loop
                            const savedAlbum = _qAlbum
                            const savedTriedAlbum = _triedNoAlbum
                            // Temporarily issue search without market by clearing bearer override usage in this call
                            const qTitle = encodeURIComponent(_qTitle)
                            const qArtist = encodeURIComponent(_qArtist)
                            const qAlbum = _qAlbum ? `+album:${encodeURIComponent(_qAlbum)}` : ""
                            const url2 = `https://api.spotify.com/v1/search?q=track:${qTitle}+artist:${qArtist}${qAlbum}&type=track&limit=1`
                            const ua = Config.options?.bpmkey?.spotify?.userAgent || ""
                            const uaHeader = ua ? `-H 'User-Agent: ${_shEscapeSingle(ua)}'` : ""
                            const cmd2 = [
                                "bash", "-lc",
                                `curl -sS --max-time 6 -H 'Authorization: Bearer ${_token}' -H 'Accept: application/json' ${uaHeader} '${url2}' -w "\\nHTTP_STATUS:%{http_code}"`
                            ]
                            console.log("BpmKey: searching track (no market)", decodeURIComponent(url2))
                            proc.command = cmd2
                            _pending = "search"
                            proc.captureStdout = true
                            proc.start()
                            return
                        }
                        throw new Error(`HTTP ${status}`)
                    }
                    if (_pending === "token") {
                        const tk = data.access_token || ""
                        const secs = Number(data.expires_in || 0)
                        if (!tk || !secs) throw new Error("Token missing")
                        _token = tk
                        _tokenExpiryMs = Date.now() + Math.max(0, secs - 30) * 1000 // safety margin
                        _searchTrack()
                        return
                    } else if (_pending === "search") {
                        if (body.length < 200)
                            console.log("BpmKey: search raw=", body)
                        const items = data?.tracks?.items || []
                        _trackId = (items.length > 0 ? (items[0]?.id || "") : "")
                        if (!_trackId) {
                            // Fallback once without album constraint
                            if (_qAlbum && !_triedNoAlbum) {
                                console.log("BpmKey: no results with album, retrying without album")
                                _triedNoAlbum = true
                                const savedAlbum = _qAlbum
                                _qAlbum = ""
                                _searchTrack()
                                _qAlbum = savedAlbum
                                return
                            }
                            throw new Error("No search results")
                        }
                        _fetchFeatures()
                        return
                    } else if (_pending === "features") {
                        if (body.length < 200)
                            console.log("BpmKey: features raw=", body)
                        const tempoNum = (typeof data?.tempo === 'number') ? data.tempo : Number(data?.tempo)
                        const tempo = Math.round(tempoNum)
                        const keyNum = (typeof data?.key === 'number') ? data.key : Number(data?.key)
                        const modeNum = (typeof data?.mode === 'number') ? data.mode : Number(data?.mode)
                        const hasKey = Number.isInteger(keyNum)
                        const hasMode = Number.isInteger(modeNum)
                        root.bpm = (isFinite(tempo) && tempo > 0) ? tempo : 0
                        root.key = (hasKey && hasMode) ? root.keyFromNumeric(keyNum, modeNum) : ""
                        root.loading = false
                        root.error = ""
                        _pending = ""
                        return
                    }
                } catch (e) {
                    console.error("BpmKey error:", e, " at stage:", _pending)
                    root.error = String(e)
                    root.loading = false
                    _pending = ""
                }
            }
        }

    }
}
