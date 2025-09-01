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
    property var details: ({ word: "", pos: "", definition: "", pronunciation: "", fullText: "" })
    property string _lastDetailWord: ""

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
        // Try to find a /.../ phonetic pattern or a Pronunciation: ... line
        const m1 = raw.match(/\/(?:[^\/]|\\\/)+\//);
        if (m1) return m1[0];
        const m2 = raw.match(/Pronunciation\s*[:=]\s*([^\n]+)/i);
        if (m2) return m2[1].trim();
        return "";
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
                    out.push({ word, definition: parsed.definition, pos: parsed.pos });
                }
                root.results = out;
            }
        }
    }

    Process {
        id: detailsFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text || "";
                const parsed = root.parseOne(raw);
                const pron = root.parsePronunciation(raw);
                root.details = ({
                    word: root._lastDetailWord,
                    pos: parsed.pos,
                    definition: parsed.definition,
                    pronunciation: pron,
                    fullText: raw
                });
            }
        }
    }
}
