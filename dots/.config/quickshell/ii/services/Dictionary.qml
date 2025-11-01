pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Dictionary service using the `dict` CLI.
 * - Provides typo-tolerant suggestions (prefix + Levenshtein)
 * - Returns a small list of matches with the first definition and a guessed POS
 */
Singleton {
    id: root

    // Public API
    property list<var> results: [] // [{ word, definition, pos }]
    property int maxResults: 8
    property string defaultDb: "wn" // Prefer WordNet for concise defs
    property string _lastTerm: ""
    // Details for a selected word
    property var details: ({ word: "", pos: "", definition: "", pronunciation: "", audioUrl: "", fullText: "" })
    property string _lastDetailWord: ""
    property bool enableApiPronunciationFallback: true

    function search(term) {
        const q = (term || "").trim();
        if (q.length === 0) {
            root.results = [];
            return;
        }
        if (q === root._lastTerm && fetcher.running === true) return; // already fetching
        if (q === root._lastTerm && fetcher.running === false && root.results.length > 0) return; // cached
        root._lastTerm = q;
        // Build a bash script that:
        // 1) collects prefix + lev matches (unique, capped)
        // 2) for each word prints markers and the raw `dict` output from wn
        const quoted = StringUtils.shellSingleQuoteEscape(q);
        const script = `
            TERM='${quoted}';
            IFS=$'\n';
            mapfile -t WORDS < <( (
                dict -m -s prefix -- "$TERM" 2>/dev/null;
                dict -m -s lev -- "$TERM" 2>/dev/null
            ) | awk -F': ' '{print $NF}' | awk '!seen[$0]++' | head -n ${root.maxResults});
            for w in "${'$'}{WORDS[@]}"; do
                echo '<<<QSWORD>>>'"${'$'}w";
                dict -d ${root.defaultDb} -- "${'$'}w" 2>/dev/null || true;
                echo '<<<QSEND>>>';
            done
        `;
    fetcher.running = false;
    fetcher.command = ["bash", "-lc", script];
    fetcher.running = true;
    }

    // Heuristics to grab first definition and part of speech from dict output
    function parseOne(raw) {
        // raw is the output of a single `dict -d wn word`
        // Strategy:
        // - POS: look for a line starting with n|v|adj|adv followed by number and ':'
        // - DEF: take the part after the first ':' on that line; if not found, take the first non-empty content line
        let lines = raw.split(/\r?\n/);
        let pos = "";
        let def = "";
        const posRegex = /^\s*(n|v|adj|adv)\b\s*\d*[:.]\s*(.+)$/i;
        for (let i = 0; i < lines.length; i++) {
            const m = posRegex.exec(lines[i]);
            if (m) {
                const tag = m[1].toLowerCase();
                if (tag === 'n') pos = 'noun';
                else if (tag === 'v') pos = 'verb';
                else if (tag === 'adj') pos = 'adjective';
                else if (tag === 'adv') pos = 'adverb';
                def = m[2].trim();
                break;
            }
        }
        if (!def) {
            // Fallback: first non-empty, non-heading content line
            for (let i = 0; i < lines.length; i++) {
                const L = lines[i].trim();
                if (!L) continue;
                if (/^From\s+/i.test(L)) continue;
                if (/^\d+\s+definitions?\s+found/i.test(L)) continue;
                if (/^[\[({]/.test(L)) continue; // likely headers
                // Try to split on ':' or '. ' after a leading tag
                const alt = /^\s*(?:\w+\.?\s*)?(?:\d+[:.]\s*)?(.+)$/.exec(lines[i]);
                def = (alt && alt[1] ? alt[1] : L).trim();
                break;
            }
        }
        // Cleanup
        def = def.replace(/\s+/g, ' ').trim();
        return { pos, definition: def };
    }

    function parsePronunciation(raw) {
        if (!raw) return "";
        // 1) Explicit "Pronunciation:" line
        let m = /(^|\n)\s*Pronunciation\s*[:=]\s*([^\n]+)/i.exec(raw);
        if (m) {
            let s = m[2].trim();
            s = s.replace(/^"|"$/g, "");
            s = s.replace(/\\"/g, '"');
            s = s.replace(/\s+/g, ' ').trim();
            if (s && !/^\[[A-Za-z]{1,5}\]$/.test(s)) return s;
        }
        // 2) IPA between slashes
        m = /\/(?!\s)([^\/]{2,})\//.exec(raw);
        if (m) {
            const ipa = `/${m[1].trim()}/`;
            if (ipa.length > 3) return ipa;
        }
        // 3) Bracketed candidate with IPA-like chars (avoid [wn], [gcide], etc.)
        const bracketRe = /\[([^\]\r\n]{2,})\]/g;
        let bm;
        while ((bm = bracketRe.exec(raw)) !== null) {
            const inside = bm[1].trim();
            // Skip short plain alpha like [wn], [GCIDE]
            if (/^[A-Za-z]{1,6}$/.test(inside)) continue;
            // Heuristic: contains some IPA/phonetic markers
            if (/[ˈˌɪʊəɛɜɔæðθʃʒɒɑŋɡː]/.test(inside)) return `[${inside}]`;
        }
        return "";
    }

    function primaryWord(word) {
        if (!word) return "";
        // Use first token to avoid multi-form entries like "define defined"
        return word.trim().split(/\s+/)[0];
    }

    function getDetails(word) {
        const w = (word || "").trim();
        if (!w) { root.details = ({ word: "", pos: "", definition: "", pronunciation: "", fullText: "" }); return; }
        // Skip if we're already fetching or we've already fetched details for this word
        if (w === root._lastDetailWord && (detailsFetcher.running || root.details.word === w)) return;
        root._lastDetailWord = w;
        const W = StringUtils.shellSingleQuoteEscape(w);
        const script = `dict -d ${root.defaultDb} -- '${W}' 2>/dev/null || true`;
        detailsFetcher.running = false;
        detailsFetcher.command = ["bash", "-lc", script];
    detailsFetcher.running = true;
        // Also fetch pronunciation from GCIDE (if available)
        pronFetcher.running = false;
        pronFetcher.command = ["bash", "-lc", `dict -d gcide -- '${W}' 2>/dev/null || true`];
        pronFetcher.running = true;
        // Kick off API fallback; it will only apply if nothing found locally
        if (root.enableApiPronunciationFallback) {
            apiPronFetcher.running = false;
            const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(w)}`;
            apiPronFetcher.command = ["bash", "-lc", `curl -s ${StringUtils.shellSingleQuoteEscape(url)}`];
            apiPronFetcher.running = true;
        }
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text || "";
                if (!s) { root.results = []; return; }

                // Split results by markers
                const chunks = s.split('<<<QSWORD>>>').filter(s => s.trim().length > 0);
                const out = [];
                for (let chunk of chunks) {
                    const endIdx = chunk.indexOf('<<<QSEND>>>');
                    if (endIdx === -1) continue;
                    const body = chunk.slice(0, endIdx);
                    const nl = body.indexOf('\n');
                    if (nl === -1) continue;
                    const word = body.slice(0, nl).trim();
                    const raw = body.slice(nl + 1);
                    const parsed = root.parseOne(raw);
                    out.push({ word, primary: root.primaryWord(word), definition: parsed.definition, pos: parsed.pos });
                }
                // Rank by fuzzy similarity to the current term (if available)
                const term = (root._lastTerm || '').toLowerCase();
                if (typeof Levendist !== 'undefined') {
                    out.forEach(it => it._score = Levendist.computeTextMatchScore((it.primary || it.word || '').toLowerCase(), term));
                    out.sort((a, b) => (b._score || 0) - (a._score || 0));
                }
                // Dedupe by primary token to avoid entries like "define defined"
                const seen = {};
                const deduped = [];
                for (let i = 0; i < out.length; i++) {
                    const p = out[i].primary || out[i].word;
                    if (seen[p]) continue;
                    seen[p] = true;
                    deduped.push(out[i]);
                }
                root.results = deduped;
            }
        }
    }

    Process {
        id: detailsFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text || "";
                const parsed = root.parseOne(raw);
                const prevPron = root.details.word === root._lastDetailWord ? (root.details.pronunciation || "") : "";
                root.details = ({
                    word: root._lastDetailWord,
                    pos: parsed.pos,
                    definition: parsed.definition,
                    pronunciation: prevPron || root.parsePronunciation(raw),
                    audioUrl: root.details.word === root._lastDetailWord ? (root.details.audioUrl || "") : "",
                    fullText: raw
                });
            }
        }
    }

    Process {
        id: pronFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text || "";
                const pron = root.parsePronunciation(raw);
                if (!pron) return;
                if (root.details.word !== root._lastDetailWord) return; // stale
                root.details = ({
                    word: root.details.word,
                    pos: root.details.pos,
                    definition: root.details.definition,
                    pronunciation: pron,
                    audioUrl: root.details.audioUrl,
                    fullText: root.details.fullText
                });
            }
        }
    }

    Process {
        id: apiPronFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = text || "";
                    if (!s) return;
                    const arr = JSON.parse(s);
                    if (!Array.isArray(arr) || arr.length === 0) return;
                    // Find first phonetic text
                    let phon = "";
                    let audio = "";
                    for (let i = 0; i < arr.length && !phon; i++) {
                        const e = arr[i];
                        const ps = e?.phonetics || [];
                        for (let j = 0; j < ps.length; j++) {
                            const t = (ps[j]?.text || '').trim();
                            const a = (ps[j]?.audio || '').trim();
                            if (t && !phon) phon = t;
                            if (a && !audio) audio = a;
                            if (phon && audio) break;
                        }
                    }
                    if (!phon) return;
                    if (root.details.word !== root._lastDetailWord) return; // stale
                    // Only apply if we still don't have a pronunciation
                    if (!root.details.pronunciation || !root.details.audioUrl) {
                        root.details = ({
                            word: root.details.word,
                            pos: root.details.pos,
                            definition: root.details.definition,
                            pronunciation: root.details.pronunciation || phon,
                            audioUrl: root.details.audioUrl || audio,
                            fullText: root.details.fullText
                        });
                    }
                } catch (e) {
                    // ignore
                }
            }
        }
    }

    function playAudio(url) {
        if (!url || url.trim().length === 0) return;
        const u = StringUtils.shellSingleQuoteEscape(url);
        const cmd = `((command -v mpv >/dev/null 2>&1 && mpv --no-video --really-quiet ${u}) || \
                     (command -v ffplay >/dev/null 2>&1 && ffplay -nodisp -autoexit -loglevel error ${u}) || \
                     (tmp=$(mktemp --suffix=.mp3); curl -sL ${u} -o "$tmp" && \
                        ((command -v mpv >/dev/null 2>&1 && mpv --no-video --really-quiet "$tmp") || \
                         (command -v ffplay >/dev/null 2>&1 && ffplay -nodisp -autoexit -loglevel error "$tmp") || \
                         (command -v paplay >/dev/null 2>&1 && paplay "$tmp")); rm -f "$tmp")) >/dev/null 2>&1 &`;
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    function playPronunciation() {
        if (root.details?.audioUrl && root.details.audioUrl.length > 0) {
            playAudio(root.details.audioUrl);
        } else {
            // No URL; try API fetch for current detail word again as a best effort
            if (root.enableApiPronunciationFallback && root._lastDetailWord) {
                const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(root._lastDetailWord)}`;
                Quickshell.execDetached(["bash", "-lc", `curl -s ${StringUtils.shellSingleQuoteEscape(url)} | jq -r '.[0].phonetics[]?.audio // empty' | head -n1`]);
            }
        }
    }
}
