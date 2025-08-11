import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions


Item {
	id: dynamicIsland

	// Helper function to format seconds into HH:MM:SS
	function formatSeconds(seconds) {
		var hours = Math.floor(seconds / 3600);
		var minutes = Math.floor((seconds % 3600) / 60);
		var secs = Math.floor(seconds % 60);
		
		if (hours > 0) {
			return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
		}
		return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
	}
	anchors.centerIn: parent
	width: 400
	height: 48
	property bool hovered: false
	property bool mediaActive: MprisController.activePlayer?.isPlaying || MprisController.activePlayer?.playbackState === MprisPlaybackState.Paused
	property bool timerActive: TimerService.pomodoroRunning || TimerService.stopwatchRunning
	property bool showActiveWindow: !mediaActive && !timerActive

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onEntered: dynamicIsland.hovered = true
		onExited: dynamicIsland.hovered = false
		onClicked: {
			GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
		}
	}

	// Main layout
	RowLayout {
		anchors.fill: parent
		spacing: 8

		// Media section
		Item {
			visible: dynamicIsland.mediaActive
			width: parent.width
			height: parent.height
			RowLayout {
				anchors.fill: parent
				spacing: 4
				// Info container (title/artist or timer)
				Item {
					Layout.fillWidth: true
					Layout.maximumWidth: 250
					Layout.fillHeight: true
					Layout.alignment: Qt.AlignVCenter

					// Title/artist info
					StyledText {
						id: mediaTitle
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						text: !dynamicIsland.timerActive ? 
							  // Full title and artist when no timer
							  `${StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")}${MprisController.activePlayer?.trackArtist ? " - " + MprisController.activePlayer.trackArtist : ""}` :

							  ""
						font.pixelSize: Appearance.font.pixelSize.smaller
						color: Appearance.colors.colOnLayer1
						elide: Text.ElideRight
						opacity: text ? 1 : 0
						visible: opacity > 0
						Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
					}

					// Timer info
					Row {
						id: timerInfo
						anchors.centerIn: parent
						spacing: TimerService.pomodoroRunning && TimerService.stopwatchRunning ? 12 : 4
						opacity: dynamicIsland.timerActive ? 1 : 0
						visible: opacity > 0
						Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

						// Pomodoro with Resource.qml style
						Item {
							visible: TimerService.pomodoroRunning
							width: 26
							height: 26
							anchors.verticalCenter: parent.verticalCenter

							CircularProgress {
								anchors.centerIn: parent
								implicitSize: 26
								lineWidth: 2
								value: {
                return TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration;
            }
								colSecondary: Appearance.colors.colSecondaryContainer
								colPrimary: Appearance.m3colors.m3onSecondaryContainer
								enableAnimation: true
								
								MaterialSymbol {
									anchors.centerIn: parent
									fill: 1
									text: "timer"
									iconSize: Appearance.font.pixelSize.normal
									color: Appearance.m3colors.m3onSecondaryContainer
								}
							}
						}

						StyledText {
							visible: TimerService.pomodoroRunning
							anchors.verticalCenter: parent.verticalCenter
							text: formatSeconds(TimerService.pomodoroSecondsLeft)
							font.pixelSize: Appearance.font.pixelSize.normal
							color: Appearance.colors.colOnLayer1
						}

						// Stopwatch with minimal style
						MaterialSymbol {
							visible: TimerService.stopwatchRunning
							anchors.verticalCenter: parent.verticalCenter
							text: "timer"
							iconSize: Appearance.font.pixelSize.normal
							color: Appearance.m3colors.m3onSecondaryContainer
						}

						StyledText {
							visible: TimerService.stopwatchRunning
							anchors.verticalCenter: parent.verticalCenter
							text: formatSeconds(Math.floor(TimerService.stopwatchTime * 0.01))
							font.pixelSize: Appearance.font.pixelSize.normal
							color: Appearance.colors.colOnLayer1
						}
					}
				}

				// Progress bar
				Item {
					Layout.fillWidth: true
					Layout.minimumWidth: (TimerService.pomodoroRunning && !TimerService.stopwatchRunning) || (TimerService.stopwatchRunning && !TimerService.pomodoroRunning) ? 75 : 50
                    Layout.preferredWidth: (TimerService.pomodoroRunning && !TimerService.stopwatchRunning) || (TimerService.stopwatchRunning && !TimerService.pomodoroRunning) ? 125 : 100
                    Layout.maximumWidth: (TimerService.pomodoroRunning && !TimerService.stopwatchRunning) || (TimerService.stopwatchRunning && !TimerService.pomodoroRunning) ? 200 : 150
					Layout.preferredHeight: 10
					StyledProgressBar {
						id: dynamicIslandProgressBar
						anchors.fill: parent
						highlightColor: Appearance.colors.colPrimary
						trackColor: Appearance.colors.colLayer1
						value: (MprisController.activePlayer?.length > 0 && MprisController.activePlayer?.position >= 0) ? MprisController.activePlayer.position / MprisController.activePlayer.length : 0
						sperm: MprisController.activePlayer?.isPlaying ? true : false
						spermAmplitudeMultiplier: MprisController.activePlayer?.isPlaying ? 0.2 : 0.0
						valueBarHeight: 3
						valueBarWidth: parent.width
						valueBarGap: 10
					}
				}
				RippleButton {
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.previous()
					colBackground: Appearance.colors.colSecondaryContainer
					colBackgroundHover: Appearance.colors.colSecondaryContainerHover
					colRipple: Appearance.colors.colSecondaryContainerActive
					contentItem: MaterialSymbol {
						anchors.centerIn: parent
						iconSize: 13
						fill: 1
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
						color: Appearance.colors.colOnSecondaryContainer
						text: "skip_previous"
					}
				}
				RippleButton {
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.togglePlaying()
					colBackground: Appearance.colors.colPrimary
					colBackgroundHover: Appearance.colors.colPrimaryHover
					colRipple: Appearance.colors.colPrimaryActive
					contentItem: MaterialSymbol {
						anchors.centerIn: parent
						iconSize: 13
						fill: 1
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
						color: Appearance.colors.colOnPrimary
						text: MprisController.activePlayer?.isPlaying ? "pause" : "play_arrow"
					}
				}
				RippleButton {
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.next()
					colBackground: Appearance.colors.colSecondaryContainer
					colBackgroundHover: Appearance.colors.colSecondaryContainerHover
					colRipple: Appearance.colors.colSecondaryContainerActive
					contentItem: MaterialSymbol {
						anchors.centerIn: parent
						iconSize: 13
						fill: 1
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
						color: Appearance.colors.colOnSecondaryContainer
						text: "skip_next"
					}
				}
			}
		}



		// Active window section
		Item {
            visible: dynamicIsland.showActiveWindow
            width: parent.width
            height: Appearance.sizes.barHeight
            anchors.horizontalCenter: parent.horizontalCenter
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                StyledText {
                    id: activeWindowTitle
                    text: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ToplevelManager.activeToplevel === null ? Translation.tr("Desktop") : ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: "#cad3f5"
                    elide: Text.ElideRight
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    clip: true
                    onTextChanged: {
                        if (activeWindowTitle.width > parent.width) {
                            while (activeWindowTitle.width > parent.width && activeWindowTitle.font.pixelSize > 6) {
                                activeWindowTitle.font.pixelSize -= 1;
                            }
                        } else {
                            while (activeWindowTitle.width < parent.width && activeWindowTitle.font.pixelSize < Appearance.font.pixelSize.small) {
                                activeWindowTitle.font.pixelSize += 1;
                            }
                        }
                    }
                }
            }
        }
	}
}
