pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
	id: root
	property double memoryTotal: 1
	property double memoryFree: 1
	property double memoryUsed: memoryTotal - memoryFree
    property double memoryUsedPercentage: memoryUsed / memoryTotal
    property double swapTotal: 1
	property double swapFree: 1
	property double swapUsed: swapTotal - swapFree
    property double swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property double cpuUsage: 0
    property var previousCpuStats
    // Best-effort CPU telemetry; may be NaN/0 if not available on this system
    property double cpuTempC: NaN
    property double cpuFanRpm: NaN

    // Safely reload a FileView-like object; ignore errors for missing files
    function safeReload(obj) {
        try { obj && obj.reload && obj.reload() } catch (e) {}
    }

    // Safely read text from a FileView-like object
    function safeText(obj) {
        try { return obj && obj.text ? obj.text() : "" } catch (e) { return "" }
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
			safeReload(fileMeminfo)
			safeReload(fileStat)
			safeReload(fileCpuTemp0)
            safeReload(thinkpadFan)

            // Parse memory and swap usage
            const textMeminfo = safeText(fileMeminfo)
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = safeText(fileStat)
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse CPU temperature (prefer thermal_zone0, then hwmon0)
            const parseTemp = (txt) => {
                const n = Number(txt.trim())
                if (!isFinite(n) || n <= 0) return NaN
                return n > 200 ? n / 1000.0 : n // handle millidegree vs degree
            }
            const t0 = parseTemp(safeText(fileCpuTemp0))
            cpuTempC = isFinite(t0) ? t0 : NaN

            // Parse CPU fan rpm (first valid > 0)
            const parseRpm = (txt) => {
                const n = Number(txt.trim())
                return isFinite(n) && n > 0 ? n : NaN
            }
            const candidates = [
                // ThinkPad ACPI exports as a key-value text; extract digits
                (() => {
                    const t = safeText(thinkpadFan).trim()
                    const m = t.match(/(speed|level).*?(\d+)/i) || t.match(/(\d{3,5})/)
                    return m ? parseRpm(m[m.length - 1]) : NaN
                })(),
            ]
            cpuFanRpm = candidates.find((v) => isFinite(v)) ?? NaN

            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    // Common sysfs candidates; not all systems expose the same nodes
    // thermal_zone0 is commonly CPU package temp
    FileView { id: fileCpuTemp0; path: "/sys/class/thermal/thermal_zone0/temp" }
    // ThinkPad ACPI fallback
    FileView { id: thinkpadFan; path: "/proc/acpi/ibm/fan" }
}
