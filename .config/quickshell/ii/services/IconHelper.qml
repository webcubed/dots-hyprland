import Quickshell
pragma Singleton

/**
 * Utility helper for normalizing icon names coming from various sources
 * (e.g. tray / SNI items passing query parameters or size suffixes).
 */
Singleton {
    id: root

    // Return a sanitized icon candidate (does not guarantee existence)
    function sanitize(name) {
        if (!name || name.length === 0)
            return name;

        let base = name.split('?')[0]; // strip query / path parts
        // Strip common platform/size suffixes added by some launchers
        base = base.replace(/-linux-\d+$/, "");
        base = base.replace(/-\d+$/, "");
        return base;
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length === 0)
            return false;

        const path = Quickshell.iconPath(iconName, true);
        return path.length > 0 && !iconName.includes("image-missing");
    }

    function extractQueryPath(name) {
        if (!name)
            return null;

        const qIndex = name.indexOf('?');
        if (qIndex === -1)
            return null;

        const query = name.substring(qIndex + 1);
        const params = query.split('&');
        for (let i = 0; i < params.length; i++) {
            const kv = params[i].split('=');
            if (kv.length === 2 && kv[0] === 'path')
                return decodeURIComponent(kv[1]);

        }
        return null;
    }

    function getSpotifyFileCandidates(name) {
        const basePath = extractQueryPath(name);
        if (!basePath)
            return [];

        // Derive size from original (e.g. spotify-linux-32) else try multiple sizes
        let size = null;
        const m = /spotify-linux-(\d+)/i.exec(name);
        if (m)
            size = m[1];

        const sizes = size ? [size] : ["512", "256", "128", "64", "48", "32", "24", "22", "16"];
        const exts = [".svg", ".png", ".ico"]; // search order
        const candidates = [];
        for (let i = 0; i < sizes.length; i++) {
            const s = sizes[i];
            const stem = "spotify-linux-" + s;
            for (let e = 0; e < exts.length; e++) {
                candidates.push(basePath + "/" + stem + exts[e]);
            }
        }
        // Generic non-sized file last
        for (let e = 0; e < exts.length; e++) {
            candidates.push(basePath + "/spotify" + exts[e]);
        }
        return candidates;
    }

    // Simplified resolution: normalize then test candidate themed names.
    function resolve(name) {
        if (!name)
            return name;

        const original = name;
        const sanitized = sanitize(original);
        const lower = sanitized ? sanitized.toLowerCase() : sanitized;
        // Spotify: map any spotify-* variant to stable themed names if available
        if (lower && lower.startsWith("spotify")) {
            const spotifyCandidates = ["spotify", "spotify-client", "com.spotify.Client"];
            for (let i = 0; i < spotifyCandidates.length; i++) {
                if (iconExists(spotifyCandidates[i])) {
                    console.log('[IconHelper] spotify resolved =>', spotifyCandidates[i]);
                    return spotifyCandidates[i];
                }
            }
            // Provide sentinel to signal consumer to try file candidates:
            return '__SPOTIFY_FILE_FALLBACK__';
        }
        const candidates = [];
        if (sanitized && sanitized !== original)
            candidates.push(sanitized);

        if (lower && lower !== sanitized)
            candidates.push(lower);

        for (let i = 0; i < candidates.length; i++) {
            if (iconExists(candidates[i]))
                return candidates[i];

        }
        return sanitized || original;
    }

}
