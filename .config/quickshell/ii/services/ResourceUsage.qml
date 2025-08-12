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

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            fileCpuTemp0.reload(); fileCpuTemp1.reload();
            // reload fan candidates
            fanH0F1.reload(); fanH0F2.reload(); fanH0F3.reload();
            fanH1F1.reload(); fanH1F2.reload(); fanH1F3.reload();
            fanH2F1.reload(); fanH2F2.reload(); fanH2F3.reload();
            thinkpadFan.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
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
            const t0 = parseTemp(fileCpuTemp0.text())
            const t1 = parseTemp(fileCpuTemp1.text())
            cpuTempC = isFinite(t0) ? t0 : (isFinite(t1) ? t1 : NaN)

            // Parse CPU fan rpm (first valid > 0)
            const parseRpm = (txt) => {
                const n = Number(txt.trim())
                return isFinite(n) && n > 0 ? n : NaN
            }
            const candidates = [
                parseRpm(fanH0F1.text()), parseRpm(fanH0F2.text()), parseRpm(fanH0F3.text()),
                parseRpm(fanH1F1.text()), parseRpm(fanH1F2.text()), parseRpm(fanH1F3.text()),
                parseRpm(fanH2F1.text()), parseRpm(fanH2F2.text()), parseRpm(fanH2F3.text()),
                // ThinkPad ACPI exports as a key-value text; extract digits
                (() => {
                    const t = thinkpadFan.text().trim()
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
    // thermal_zone0 is commonly CPU package temp; hwmon0 may map to k10temp/coretemp
    FileView { id: fileCpuTemp0; path: "/sys/class/thermal/thermal_zone0/temp" }
    FileView { id: fileCpuTemp1; path: "/sys/class/hwmon/hwmon0/temp1_input" }
    // Fan sensors (if present) — check multiple hwmon indices and channels
    FileView { id: fanH0F1; path: "/sys/class/hwmon/hwmon0/fan1_input" }
    FileView { id: fanH0F2; path: "/sys/class/hwmon/hwmon0/fan2_input" }
    FileView { id: fanH0F3; path: "/sys/class/hwmon/hwmon0/fan3_input" }
    FileView { id: fanH1F1; path: "/sys/class/hwmon/hwmon1/fan1_input" }
    FileView { id: fanH1F2; path: "/sys/class/hwmon/hwmon1/fan2_input" }
    FileView { id: fanH1F3; path: "/sys/class/hwmon/hwmon1/fan3_input" }
    FileView { id: fanH2F1; path: "/sys/class/hwmon/hwmon2/fan1_input" }
    FileView { id: fanH2F2; path: "/sys/class/hwmon/hwmon2/fan2_input" }
    FileView { id: fanH2F3; path: "/sys/class/hwmon/hwmon2/fan3_input" }
    // ThinkPad ACPI fallback
    FileView { id: thinkpadFan; path: "/proc/acpi/ibm/fan" }
}
