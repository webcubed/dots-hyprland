import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
	// Time w/ seconds
	property string timeWithSeconds: Qt.locale().toString(new Date(), "hh:mm:ss")
    property string date: Qt.locale().toString(clock.date, Config.options?.time.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dd MMMM yyyy")
    property string uptime: "0y, 0m, 0d, 0s"

	Timer {
		interval: 10
		running: true
		repeat: true
		onTriggered: {
			timeWithSeconds = Qt.locale().toString(clock.date, "hh:mm:ss")

		}
	}
    Timer { // Uptime
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            fileUptime.reload()
            const textUptime = fileUptime.text()
            const uptimeSeconds = Number(textUptime.split(" ")[0] ?? 0)

            // Convert seconds to days, hours, and minutes
            const years = Math.floor(uptimeSeconds / 31536000)
            const months = Math.floor((uptimeSeconds % 31536000) / 2628000)
            const days = Math.floor((uptimeSeconds % 2628000) / 86400)
            const hours = Math.floor((uptimeSeconds % 86400) / 3600)
            const minutes = Math.floor((uptimeSeconds % 3600) / 60)
            const seconds = Math.floor(uptimeSeconds % 60)

            // Build the formatted uptime string
            let formatted = ""
            if (years > 0) formatted += `${years}y`
            if (months > 0) formatted += `${formatted ? ", " : ""}${months}m`
            if (days > 0) formatted += `${formatted ? ", " : ""}${days}d`
            if (hours > 0 || !formatted) formatted += `${formatted ? ", " : ""}${hours}h`
            if (minutes > 0 || !formatted) formatted += `${formatted ? ", " : ""}${minutes}m`
            if (seconds > 0 || !formatted) formatted += `${formatted ? ", " : ""}${seconds}s`
            uptime = formatted
            interval = 1000
        }
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
    }

}

