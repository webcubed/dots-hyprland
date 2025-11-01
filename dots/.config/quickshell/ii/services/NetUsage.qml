pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * NetUsage: estimates network throughput for the primary interface.
 * - Determines primary interface via `ip route` default route
 * - Reads /sys/class/net/<iface>/statistics/{rx_bytes,tx_bytes}
 * - Exposes up/down bytes per second and a normalized load 0..1
 */
Singleton {
    id: root

    // Primary interface name (e.g., "wlan0", "eth0"). Empty if not found.
    property string iface: ""

    // Bytes per second
    property double downBps: 0
    property double upBps: 0

    // Normalized combined load in [0,1]
    // Default max = 100 Mbps (12_500_000 B/s). Can be overridden via Config.
    property double maxBps: (Config.options?.resources?.netMaxBps ?? 12500000)
    property double load: Math.min(1.0, Math.max(0.0, (downBps + upBps) / Math.max(1, maxBps)))

    // Internal previous counters
    property double _prevRx: NaN
    property double _prevTx: NaN
    property double _prevTs: NaN

    function _determineIface() {
        // Prefer default route device
        getDefaultIface.running = true
    }

    // Polling timer
    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            // Refresh iface occasionally if empty
            if (!root.iface || root.iface === "lo") {
                root._determineIface()
            } else {
                readStats.running = true
            }
        }
    }

    // Determine default interface using ip route
    Process {
        id: getDefaultIface
        command: ["sh", "-c", "ip -o route show default | awk '{print $5; exit}'"]
        stdout: SplitParser {
            onRead: data => {
                const name = (data || "").trim()
                if (name.length > 0) root.iface = name
            }
        }
    }

    // Read rx/tx bytes for the current iface
    Process {
        id: readStats
        command: ["sh", "-c", `RX=$(cat /sys/class/net/${root.iface}/statistics/rx_bytes 2>/dev/null || echo 0); TX=$(cat /sys/class/net/${root.iface}/statistics/tx_bytes 2>/dev/null || echo 0); echo "$RX $TX"`]
        stdout: SplitParser {
            onRead: data => {
                const parts = (data || "").trim().split(/\s+/)
                const rx = Number(parts[0] || 0)
                const tx = Number(parts[1] || 0)
                const now = Date.now() / 1000.0
                if (isFinite(root._prevRx) && isFinite(root._prevTx) && isFinite(root._prevTs)) {
                    const dt = Math.max(0.001, now - root._prevTs)
                    root.downBps = Math.max(0, (rx - root._prevRx) / dt)
                    root.upBps   = Math.max(0, (tx - root._prevTx) / dt)
                }
                root._prevRx = rx
                root._prevTx = tx
                root._prevTs = now
            }
        }
        
    }
}
