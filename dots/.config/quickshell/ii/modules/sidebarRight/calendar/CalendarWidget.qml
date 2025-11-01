import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)

    // Layout.topMargin: 10
    anchors.topMargin: 10
    width: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2
    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown)
                monthShift++;
            else if (event.key === Qt.Key_PageUp)
                monthShift--;
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                monthShift--;
            else if (event.angleDelta.y < 0)
                monthShift++;
        }
    }

    ColumnLayout {
        id: calendarColumn

        anchors.centerIn: parent
        spacing: 5

        // Calendar header
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            CalendarHeaderButton {
                clip: true
                buttonText: `${monthShift != 0 ? "• " : ""}${viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                tooltipText: (monthShift === 0) ? "" : Translation.tr("Jump to current month")
                downAction: () => {
                    monthShift = 0;
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift--;
                }


                contentItem: Item {
                    anchors.centerIn: parent
                    width: Appearance.font.pixelSize.larger
                    height: width

                    PlumpyIcon {
                        id: calPrevPlumpy

                        anchors.centerIn: parent
                        iconSize: parent.width
                        name: 'chevron-left'
                        primaryColor: Appearance.colors.colOnLayer1
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !calPrevPlumpy.available
                        text: "chevron_left"
                        iconSize: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: Appearance.colors.colOnLayer1
                    }

                }

            }

            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift++;
                }


                contentItem: Item {
                    anchors.centerIn: parent
                    width: Appearance.font.pixelSize.larger
                    height: width

                    PlumpyIcon {
                        id: calNextPlumpy

                        anchors.centerIn: parent
                        iconSize: parent.width
                        name: 'chevron-right'
                        primaryColor: Appearance.colors.colOnLayer1
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !calNextPlumpy.available
                        text: "chevron_right"
                        iconSize: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: Appearance.colors.colOnLayer1
                    }

                }

            }

        }

        // Week days row
        RowLayout {
            id: weekDaysRow

            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            spacing: 5

            Repeater {
                model: CalendarLayout.weekDays

                delegate: CalendarDayButton {
                    day: Translation.tr(modelData.day)
                    isToday: modelData.today
                    bold: true
                    enabled: false
                    taskList: []
                }

            }

        }

        // Real week rows
        Repeater {
            id: calendarRows

            // model: calendarLayout
            model: 6

            delegate: RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                spacing: 5

                Repeater {
                    model: Array(7).fill(modelData)

                    delegate: CalendarDayButton {
                        day: calendarLayout[modelData][index].day
                        isToday: calendarLayout[modelData][index].today
                        taskList: [
                          ...Todo.getTasksByDate(new Date(calendarLayout[modelData][index].year, calendarLayout[modelData][index].month, calendarLayout[modelData][index].day)),
                          ...CalendarService.getTasksByDate(new Date(calendarLayout[modelData][index].year, calendarLayout[modelData][index].month, calendarLayout[modelData][index].day))
                      ]
                    }

                }

            }

        }

    }

}
