pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<string> results: []
    property bool searching: searchProc.running
    property int maxResults: 20
    property var searchTimer: Timer {
        interval: 200 // Debounce timer
        repeat: false
        onTriggered: {
            searchProc.running = false; // Kill previous search
            searchProc.buffer = []
            let command = ["fd", "--max-results", root.maxResults, "--absolute-path", "--hidden"];
            if (searchProc.caseSensitive) {
                command.push("-s");
            } else {
                command.push("-i");
            }
            command.push(searchProc.query);
            command.push(Directories.home);
            searchProc.command = command;
            searchProc.running = true
        }
    }

    function search(query) {
        // If query is empty, don't search
        if (!query || query.trim() === "") {
            if (root.results.length > 0) root.results = [];
            return;
        }

        let caseSensitive = false;
        let actualQuery = query;

        if (query.startsWith('"') && query.endsWith('"') && query.length > 1) {
            caseSensitive = true;
            actualQuery = query.substring(1, query.length - 1);
        }

        searchProc.query = actualQuery;
        searchProc.caseSensitive = caseSensitive;
        searchTimer.restart();
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        id: searchProc
        property list<string> buffer: []
        property string query: ""
        property bool caseSensitive: false

        stdout: SplitParser {
            onRead: (line) => {
                if (line) {
                    searchProc.buffer.push(line)
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            // A non-zero exit code can occur if the search is cancelled.
            // We still want to display any results found before cancellation.
            root.results = searchProc.buffer
        }
    }
}
