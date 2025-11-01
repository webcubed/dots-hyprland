pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Urban Dictionary service using the public API.
 * - Endpoint: https://api.urbandictionary.com/v0/define?term=WORD
 */
Singleton {
    id: root

    property list<var> results: [] // [{ word }]
    property int maxResults: 8
    property string currentTerm: ""
    property var details: ({ word: "", definition: "", definitions: [] })
    property string _lastSearch: ""
    property string _lastDetailWord: ""

    function search(term) {
        const q = (term || "").trim();
    if (q === root._lastSearch && fetcher.running === false && root.results.length > 0) { root.currentTerm = q; return; }
    root.currentTerm = q;
    if (q.length === 0) { root.results = []; root._lastSearch = q; return; }
        // Bash script:
        // 1) get autocomplete suggestions (strings)
        // 2) build a unique list with the original query first
        const Q = StringUtils.shellSingleQuoteEscape(q);
        const script = `
            set -euo pipefail
            TERM='${Q}'
            MAX=${root.maxResults}
            # suggestions (simple array of strings)
            mapfile -t SUG < <(curl -s 'https://api.urbandictionary.com/v0/autocomplete?term='"${'$'}TERM" | jq -r '.[]' 2>/dev/null | head -n "${'$'}MAX")
            # ensure original term is included first
            LIST=("${'$'}TERM")
            for s in "${'$'}{SUG[@]}"; do
                if [[ " ${'$'}{LIST[*]} " != *" ${'$'}s "* ]]; then LIST+=("${'$'}s"); fi
            done
            # cap results
            LIST=("${'$'}{LIST[@]:0:${root.maxResults}}")
            printf '%s\n' "${'$'}{LIST[@]}"
        `;
        fetcher.command = ["bash", "-lc", script];
        fetcher.running = true;
        root._lastSearch = q;
    }

    function getDetails(word) {
        const w = (word || "").trim();
        if (!w) { root.details = ({ word: "", definition: "" }); return; }
        if (w === root._lastDetailWord && (detailsFetcher.running || root.details.word === w)) return;
        root._lastDetailWord = w;
        const url = `https://api.urbandictionary.com/v0/define?term=${encodeURIComponent(w)}`;
        detailsFetcher.command = ["bash", "-lc", `curl -s ${StringUtils.shellSingleQuoteEscape(url)}`];
        detailsFetcher.running = true;
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text || "";
                if (!s) { root.results = []; return; }
                let words = s.split(/\r?\n/).map(x => x.trim()).filter(x => x.length > 0);
                const term = (root.currentTerm || '').toLowerCase();
                if (typeof Levendist !== 'undefined') {
                    words = words.map(w => ({ w, _score: Levendist.computeTextMatchScore(w.toLowerCase(), term) }))
                        .sort((a, b) => b._score - a._score)
                        .map(x => ({ word: x.w }));
                } else {
                    words = words.map(w => ({ word: w }));
                }
                root.results = words.slice(0, root.maxResults);
            }
        }
    }

    Process {
        id: detailsFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text || "";
                try {
                    const obj = JSON.parse(s);
                    let list = obj?.list || [];
                    if (list.length === 0) { root.details = ({ word: root.currentTerm, definition: "", definitions: [] }); return; }
                    list.sort((a, b) => (b?.thumbs_up || 0) - (a?.thumbs_up || 0));
                    const defs = list.map(d => (d?.definition || '').replace(/\r?\n/g, '\n').trim()).filter(Boolean);
                    const word = (list[0]?.word || '').trim() || root.currentTerm;
                    root.details = ({ word, definition: (defs[0] || ''), definitions: defs });
                } catch (e) {
                    root.details = ({ word: root.currentTerm, definition: "", definitions: [] });
                }
            }
        }
    }
}
