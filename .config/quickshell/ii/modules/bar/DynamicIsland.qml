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

	// State properties
	property bool mediaActive: MprisController.activePlayer?.isPlaying || MprisController.activePlayer?.playbackState === MprisPlaybackState.Paused
	property bool timerActive: TimerService.pomodoroRunning || TimerService.stopwatchRunning
	property bool showActiveWindow: !mediaActive && !timerActive

	// Dynamic width properties
	property real baseWidth: 280  // Slightly wider to accommodate controls
	property real maxWidth: 500   // Upper cap
	property real minWidth: 260   // Ensure controls never overflow
	property real targetWidth: baseWidth
	
	// Force recalculation when content changes
	onMediaActiveChanged: {
		console.log("Media active changed:", mediaActive)
		updateWidth()
	}
	
	onShowActiveWindowChanged: {
		console.log("Show active window changed:", showActiveWindow)
		updateWidth()
	}
	
	// Function to update width using targetWidth property
	function updateWidth() {
		var newWidth = calculateContentWidth()
		console.log("DYNAMIC ISLAND: Updating width from", targetWidth, "to:", newWidth)
		console.log("DYNAMIC ISLAND: Media active:", mediaActive, "Show active window:", showActiveWindow)
		targetWidth = newWidth
	}
	
	// Initialize width on component creation
	Component.onCompleted: {
		console.log("DYNAMIC ISLAND: Component completed, initializing width")
		updateWidth()
	}
	
	// Watch for media title/artist changes
	Connections {
		target: MprisController.activePlayer
		function onTrackTitleChanged() {
			console.log("MPRIS TITLE CHANGED:", MprisController.activePlayer?.trackTitle)
			if (mediaActive) {
				updateWidth()
			}
		}
		function onTrackArtistChanged() {
			console.log("MPRIS ARTIST CHANGED:", MprisController.activePlayer?.trackArtist)
			if (mediaActive) {
				updateWidth()
			}
		}
	}
	
	// Watch for window title changes
	Connections {
		target: root.activeWindow
		function onTitleChanged() {
			console.log("WINDOW TITLE CHANGED:", root.activeWindow?.title)
			if (showActiveWindow) {
				updateWidth()
			}
		}
	}

	// Watch for active window switches
	Connections {
		target: ToplevelManager
		function onActiveToplevelChanged() {
			console.log("ACTIVE TOPLEVEL CHANGED")
			if (showActiveWindow) {
				updateWidth()
			}
		}
	}

	// Calculate required width based on content
	function calculateContentWidth() {
		console.log("=== CALCULATING WIDTH ===")
		console.log("mediaActive:", mediaActive, "showActiveWindow:", showActiveWindow)

		// Base paddings/margins and spacings used in the layout
		const outerPadding = 16 // left+right combined approximation
		const rowSpacing = 4    // spacing inside RowLayout
		const controlButtons = 18 * 3 + rowSpacing * 2 // three 18px buttons with gaps
		const progressPreferred = titleContainer?.titleHovered ? 80 : 120

		if (mediaActive) {
			// Measure the media title's actual implicit width if available
			let titleWidth = mediaTitle?.implicitWidth || 0
			// Fallback if not yet resolved
			if (titleWidth <= 0) {
				let titleText = MprisController.activePlayer?.trackTitle || ""
				let artistText = MprisController.activePlayer?.trackArtist || ""
				let combinedText = titleText + (artistText ? " - " + artistText : "")
				titleWidth = combinedText.length * 7.5 // more conservative per-char estimate
			}

			let desired = outerPadding + titleWidth + rowSpacing + progressPreferred + rowSpacing + controlButtons
			let clamped = Math.max(minWidth, Math.min(maxWidth, desired))
			console.log("Media desired width:", desired, "clamped:", clamped, "title implicit:", titleWidth)
			return clamped
		} else if (showActiveWindow) {
			// Prefer actual rendered title width if available
			let measured = activeWindowTitle?.implicitWidth || 0
			let fallbackText = root.activeWindow?.title || ""
			let windowWidth = Math.max(60, measured > 0 ? measured : fallbackText.length * 7.5)
			let desired = outerPadding + windowWidth
			let clamped = Math.max(minWidth, Math.min(maxWidth, desired))
			console.log("Window desired width:", desired, "clamped:", clamped)
			return clamped
		}
		console.log("Using base width:", baseWidth)
		return baseWidth
	}

	// Visualizer data properties - connected to global state
	property list<real> visualizerPoints: GlobalStates.visualizerPoints || []
	property real maxVisualizerValue: 1000
	property int visualizerSmoothing: 2

	// Debug visualizer data connection
	onVisualizerPointsChanged: {
		if (visualizerPoints && visualizerPoints.length > 0) {
			console.log("DynamicIsland: visualizerPoints updated, length:", visualizerPoints.length)
		}
	}

	// Layout properties
	// Let parent layouts position/size us; also set explicit width to drive animations reliably
	implicitWidth: targetWidth
	Layout.preferredWidth: targetWidth
	Layout.minimumWidth: minWidth
	Layout.maximumWidth: maxWidth
	width: targetWidth
	height: 32
	clip: true // keep children inside the island bounds
	property bool hovered: false

	// Smooth width animation (works for both explicit width and layouts)
	Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
	Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
	// Also animate the driving property itself so bindings propagate smoothly
	Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

	// Background with visualizer overlay - must be first to render behind content
	Rectangle {
		id: dynamicIslandBackground
		anchors.fill: parent
		color: "transparent" // Match the bar's transparent background approach
		radius: Appearance.rounding.full
		
		// Visualizer bars - extend entire width, align to bottom
		Row {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			anchors.leftMargin: 4
			anchors.rightMargin: 4
			spacing: Math.max(1, (parent.width - 8) / 50) // Dynamic spacing to fill width
			opacity: MprisController.activePlayer?.isPlaying ? 0.15 : 0
			visible: opacity > 0
			
			Behavior on opacity { 
				NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
			}
			
			Repeater {
				model: 30 // Fewer bars but wider for better visibility
				Rectangle {
					width: Math.max(2, (parent.width - parent.spacing * 29) / 30) // Wider bars
					height: Math.max(2, Math.min(12, (dynamicIsland.visualizerPoints[index] || Math.random() * 100) * 0.12))
					color: Appearance.colors.colPrimary
					radius: 1
					opacity: 0.4
					
					// Align bars to bottom (they grow upward from bottom)
					anchors.bottom: parent.bottom
					
					Behavior on height { 
						NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
					}
					
					// Add some random animation for testing
					Timer {
						interval: 80 + (index * 15)
						running: MprisController.activePlayer?.isPlaying
						repeat: true
						onTriggered: {
							parent.height = Math.max(2, Math.min(12, Math.random() * 12))
						}
					}
				}
			}
		}
	}

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
			// Let RowLayout manage sizing
			Layout.fillWidth: true
			Layout.fillHeight: true
			RowLayout {
				anchors.fill: parent
				spacing: 4
				// Info container (title/artist or timer)
				Item {
					id: titleContainer
					Layout.fillWidth: true
					Layout.maximumWidth: titleHovered ? (dynamicIsland.width - 120) : (dynamicIsland.width - 160) // Dynamic based on island width, leaving space for controls
					Layout.fillHeight: true
					Layout.alignment: Qt.AlignVCenter
					Layout.leftMargin: 8
					
					property bool titleHovered: false
					property bool titleTruncated: mediaTitle.implicitWidth > titleScrollContainer.width
					property bool shouldAnimateTitle: titleTruncated && titleHovered
					
					// Recalculate island width when hover/truncation state changes
					onTitleHoveredChanged: if (dynamicIsland.mediaActive) dynamicIsland.updateWidth()
					onTitleTruncatedChanged: if (dynamicIsland.mediaActive) dynamicIsland.updateWidth()
					
					Behavior on Layout.maximumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}

					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						onEntered: {
							if (titleContainer.titleTruncated) {
								titleContainer.titleHovered = true
							}
						}
						onExited: titleContainer.titleHovered = false
						onClicked: {
							// Propagate click to parent to open media controls
							GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
						}
					}

					// Title/artist info with scrolling container
					Item {
						id: titleScrollContainer
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: parent.height
						clip: true
						
						StyledText {
							id: mediaTitle
							anchors.verticalCenter: parent.verticalCenter
							width: titleContainer.titleHovered ? implicitWidth : Math.min(implicitWidth, titleScrollContainer.width)
							text: !dynamicIsland.timerActive ? 
								  // Full title and artist when no timer
								  `${StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")}${MprisController.activePlayer?.trackArtist ? " - " + MprisController.activePlayer.trackArtist : ""}` :
								  ""
							font.pixelSize: Appearance.font.pixelSize.small
							color: Appearance.colors.colOnLayer1
							opacity: text ? 1 : 0
							visible: opacity > 0
							elide: titleContainer.titleHovered ? Text.ElideNone : Text.ElideRight
							
							Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
							Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
							
							// Check if text is truncated
							onTextChanged: {
								titleContainer.titleTruncated = implicitWidth > titleScrollContainer.width
								if (dynamicIsland.mediaActive) dynamicIsland.updateWidth()
							}
							onImplicitWidthChanged: {
								titleContainer.titleTruncated = implicitWidth > titleScrollContainer.width
								if (dynamicIsland.mediaActive) dynamicIsland.updateWidth()
							}
							
							// Horizontal scrolling animation when hovered and still truncated
							SequentialAnimation {
								id: scrollAnimation
								running: titleContainer.shouldAnimateTitle
								loops: Animation.Infinite
								
								// Wait before starting scroll
								PauseAnimation { duration: 1000 }
								
								// Scroll to show the end
								NumberAnimation {
									target: mediaTitle
									property: "x"
									to: titleScrollContainer.width - mediaTitle.implicitWidth - 20
									duration: Math.max(2000, (mediaTitle.implicitWidth - titleScrollContainer.width) * 15)
									easing.type: Easing.InOutQuad
								}
								
								// Wait at the end
								PauseAnimation { duration: 1000 }
								
								// Scroll back to beginning
								NumberAnimation {
									target: mediaTitle
									property: "x"
									to: 0
									duration: Math.max(2000, (mediaTitle.implicitWidth - titleScrollContainer.width) * 15)
									easing.type: Easing.InOutQuad
								}
								
								// Stop animation and reset when hover ends
								onRunningChanged: {
									if (!running) {
										mediaTitle.x = 0
									}
								}
							}
							
							// Reset position when not hovering with smooth animation
							Behavior on x {
								enabled: !scrollAnimation.running && !titleContainer.titleHovered
								NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
							}
							
							// Watch for hover state changes to reset position
							Connections {
								target: titleContainer
								function onTitleHoveredChanged() {
									if (!titleContainer.titleHovered) {
										scrollAnimation.stop()
										mediaTitle.x = 0
									}
								}
							}
						}
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
					Layout.minimumWidth: titleContainer.titleHovered ? 60 : 80
                    Layout.preferredWidth: titleContainer.titleHovered ? 80 : 120
                    Layout.maximumWidth: titleContainer.titleHovered ? 100 : 160
					Layout.preferredHeight: 8
					Layout.leftMargin: 4
					Layout.rightMargin: 4
					
					Behavior on Layout.minimumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
					Behavior on Layout.preferredWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
					Behavior on Layout.maximumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
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
					buttonRadius: MprisController.activePlayer?.isPlaying ? Appearance.rounding.normal : 9
					colBackground: Appearance.colors.colPrimary
					colBackgroundHover: Appearance.colors.colPrimaryHover
					colRipple: Appearance.colors.colPrimaryActive
					
					Behavior on buttonRadius { 
						NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } 
					}
					
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
			id: root
			readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
			readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

			property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
			property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
			property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)
			visible: dynamicIsland.showActiveWindow
			width: parent.width
			height: parent.height
			onVisibleChanged: if (visible) dynamicIsland.updateWidth()


			// When derived window state changes, recalc width
			onFocusingThisMonitorChanged: if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()
			onBiggestWindowChanged: if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()

			Connections {
				target: root.activeWindow
				function onActivatedChanged() {
					if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()
				}
			}
			
			StyledText {
				id: activeWindowTitle
				anchors.centerIn: parent
				text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ? 
					root.activeWindow?.title :
					(root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${root.monitor?.activeWorkspace?.id ?? 1}`
				font.pixelSize: Appearance.font.pixelSize.small
				color: Appearance.colors.colOnLayer1
				elide: Text.ElideRight
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				clip: true
				width: parent.width - 16
				function fitToAvailable() {
					// One-shot font fit: reset to baseline, then shrink if needed to fit available width.
					Qt.callLater(function() {
						var baseline = Appearance.font.pixelSize.small
						var minSize = 8
						// reset to baseline to measure true width
						activeWindowTitle.font.pixelSize = baseline
						var available = activeWindowTitle.width
						var iw = activeWindowTitle.implicitWidth
						if (iw > 0 && available > 0 && iw > available) {
							var scale = available / iw
							var newSize = Math.max(minSize, Math.floor(baseline * scale))
							activeWindowTitle.font.pixelSize = newSize
						} else {
							activeWindowTitle.font.pixelSize = baseline
						}
					})
				}
				onWidthChanged: if (dynamicIsland.showActiveWindow) activeWindowTitle.fitToAvailable()
				onTextChanged: if (dynamicIsland.showActiveWindow) activeWindowTitle.fitToAvailable()
			}
		}
	}
}
