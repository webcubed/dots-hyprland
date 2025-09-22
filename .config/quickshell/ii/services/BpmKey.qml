pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// BpmKey: provides derived audio features like BPM and musical key for the current track.
// Provider: ReccoBeats (no auth). We fetch the Spotify track ID via MPRIS (playerctl),
// resolve to a ReccoBeats track ID using /v1/track?ids=, then call /v1/track/:id/audio-features.
Singleton {
    id: root

    // Public properties
    // bpm: integer BPM if known (0 when unknown)
    // key: musical key string like "C#m" or "Am" (empty string when unknown)
    property int bpm: 0
    property string key: ""
    property bool loading: false
    property string error: ""

    // Internal state
    property string _pending: "" // "mpris" | "get-tracks" | "features" | ""
    property string _spotifyId: ""
    property string _reccobeatsId: ""
    property string _qArtist: ""
    property string _qTitle: ""
    property string _qAlbum: ""
    property bool _triedOnce: false

    // Escape single quotes for safe inclusion inside single-quoted shell strings
    function _shEscapeSingle(s) {
        // Replace each ' with '\'' sequence
        return String(s).replace(/'/g, "'\\'" + "'")
    }

    // Fetch derived features for a track using ReccoBeats.
    function fetch(artist, title, album) {
        console.log("BpmKey: fetch(...) called", { artist: String(artist||""), title: String(title||""), album: String(album||"") })
        root.error = ""
        root.loading = true
        root.bpm = 0
        root.key = ""
        _qArtist = String(artist || "")
        _qTitle = String(title || "")
        _qAlbum = String(album || "")
        _spotifyId = ""
        _reccobeatsId = ""
        _triedOnce = false
        _resolveSpotifyId()
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

    // Try to resolve Spotify track ID via MPRIS/playerctl.
    function _resolveSpotifyId() {
        _pending = "mpris"
        const cmd = [
            "bash", "-lc",
            // Try mpris:trackid first, then xesam:url; print first non-empty
            "(playerctl metadata mpris:trackid 2>/dev/null || true) | head -n1; " +
            "(playerctl metadata xesam:url 2>/dev/null || true) | head -n1"
        ]
        console.log("BpmKey: resolving Spotify ID via MPRIS")
        proc.command = cmd
        proc.running = true
    }

    function _getReccoTrack() {
        if (!_spotifyId) { root.error = "Spotify track ID not found"; root.loading = false; return }
        _pending = "get-tracks"
    const url = `https://api.reccobeats.com/v1/track?ids=${encodeURIComponent(_spotifyId)}`
        console.log("BpmKey: get-tracks Spotify ID=", _spotifyId)
        console.log("BpmKey: get-tracks URL=", url)
        const cmd = [
            "bash", "-lc",
            `curl -sS --max-time 8 -H 'Accept: application/json' '${url}' -w "\nHTTP_STATUS:%{http_code}"`
        ]
        console.log("BpmKey: mapping Spotify->ReccoBeats", _spotifyId)
        proc.command = cmd
        proc.running = true
    }

    function _fetchFeatures() {
        if (!_reccobeatsId) { root.loading = false; return }
        _pending = "features"
    const url = `https://api.reccobeats.com/v1/track/${_reccobeatsId}/audio-features`
        const cmd = [
            "bash", "-lc",
            `curl -sS --max-time 8 -H 'Accept: application/json' '${url}' -w "\nHTTP_STATUS:%{http_code}"`
        ]
        console.log("BpmKey: fetching features for", _reccobeatsId)
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
                    let data = null
                    if (_pending !== "mpris") {
                        const sep = "\nHTTP_STATUS:"
                        const idx = textAll.lastIndexOf(sep)
                        if (idx !== -1) {
                            body = textAll.slice(0, idx)
                            status = Number(textAll.slice(idx + sep.length)) || 0
                        }
                        if (_pending)
                            console.log("BpmKey: stage=", _pending, "status=", status, "bytes=", body.length)
                        if (status >= 400) {
                            console.error("BpmKey: HTTP error", status, "stage=", _pending, "body=", body.slice(0, 200))
                            throw new Error(`HTTP ${status}`)
                        }
                        if (body && body.trim().length > 0) {
                            try {
                                data = JSON.parse(body)
                            } catch (je) {
                                console.error("BpmKey: JSON parse error at stage=", _pending, "body=", body.slice(0, 200))
                                throw je
                            }
                        } else {
                            data = {}
                        }
                    }
                    if (_pending === "mpris") {
                        const lines = textAll.split(/\r?\n/).map(s => s.trim()).filter(s => s.length > 0)
                        console.log("BpmKey: MPRIS lines=", lines)
                        const joined = lines.join("\n")
                        let sid = ""
                        // Try spotify:track:<id>
                        let m = joined.match(/spotify:track:([A-Za-z0-9]+)/)
                        if (m && m[1]) sid = m[1]
                        if (!sid) {
                            // Try https URL
                            m = joined.match(/open\.spotify\.com\/track\/([A-Za-z0-9]+)/)
                            if (m && m[1]) sid = m[1]
                        }
                        if (!sid) {
                            // Try dbus path style: /com/spotify/track/<id>
                            m = joined.match(/\/com\/spotify\/track\/([A-Za-z0-9]+)/)
                            if (m && m[1]) sid = m[1]
                        }
                        if (!sid) {
                            throw new Error("Spotify track ID not found via MPRIS")
                        }
                        console.log("BpmKey: extracted Spotify ID=", sid)
                        _spotifyId = sid
                        _getReccoTrack()
                        return
                    } else if (_pending === "get-tracks") {
                        // Response may be an array or object with array; pick first track id
                        let rid = ""
                        let shape = "unknown"
                        if (Array.isArray(data) && data.length > 0) {
                            rid = data[0]?.id || ""
                            shape = "array[0].id"
                        } else if (data && Array.isArray(data?.tracks) && data.tracks.length > 0) {
                            rid = data.tracks[0]?.id || ""
                            shape = "tracks[0].id"
                        } else if (data && Array.isArray(data?.items) && data.items.length > 0) {
                            rid = data.items[0]?.id || ""
                            shape = "items[0].id"
                        } else if (data && Array.isArray(data?.content) && data.content.length > 0) {
                            rid = data.content[0]?.id || ""
                            shape = "content[0].id"
                        } else if (data && typeof data?.id === 'string') {
                            rid = data.id
                            shape = "object.id"
                        } else if (data && typeof data?.data === 'object' && typeof data.data?.id === 'string') {
                            rid = data.data.id
                            shape = "data.id"
                        }
                        if (!rid) {
                            console.error("BpmKey: could not find ReccoBeats id; keys=", Object.keys(data||{}))
                            throw new Error("ReccoBeats track ID not found")
                        }
                        console.log("BpmKey: get-tracks parsed id=", rid, " shape=", shape)
                        _reccobeatsId = rid
                        _fetchFeatures()
                        return
                    } else if (_pending === "features") {
                        if (body.length < 200)
                            console.log("BpmKey: features raw=", body)
                        // ReccoBeats typically returns: tempo (number), key (e.g., "C#"), mode ("major"|"minor")
                        const tempoNum = (typeof data?.tempo === 'number') ? data.tempo : Number(data?.tempo)
                        const tempo = Math.round(tempoNum)
                        const keyName = (typeof data?.key === 'string') ? data.key : ""
                        const modeStr = (typeof data?.mode === 'string') ? data.mode : ""
                        let keyOut = ""
                        if (keyName) keyOut = (modeStr === 'minor') ? (keyName + 'm') : keyName
                        // Fallback if numeric format appears
                        if (!keyOut && Number.isInteger(data?.key) && Number.isInteger(data?.mode)) {
                            console.log("BpmKey: using numeric key fallback", { key: data.key, mode: data.mode })
                            keyOut = root.keyFromNumeric(Number(data.key), Number(data.mode))
                        }
                        console.log("BpmKey: computed features", { tempo: tempo, key: keyOut, mode: modeStr })
                        const newBpm = (isFinite(tempo) && tempo > 0) ? tempo : 0
                        const newKey = keyOut
                        const changed = (root.bpm !== newBpm) || (root.key !== newKey)
                        root.bpm = newBpm
                        root.key = newKey
                        root.loading = false
                        root.error = ""
                        _pending = ""
                        if (changed) {
                            console.log("BpmKey: updated bpm=", root.bpm, " key=", root.key)
                        } else {
                            console.log("BpmKey: no change bpm=", root.bpm, " key=", root.key)
                        }
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

    // Property change logs to trace propagation to UI
    onBpmChanged: console.log("BpmKey: property bpm changed ->", bpm)
    onKeyChanged: console.log("BpmKey: property key changed ->", key)
    onLoadingChanged: console.log("BpmKey: property loading ->", loading)
    onErrorChanged: if (error && error.length) console.error("BpmKey: property error ->", error)
}
