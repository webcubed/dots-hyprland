import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell

ContentPage {
    forceWidth: true

    ContentSection {
        title: Translation.tr("Audio")

        ConfigSwitch {
            text: Translation.tr("Earbang protection")
            checked: Config.options.audio.protection.enable
            onCheckedChanged: {
                Config.options.audio.protection.enable = checked;
            }
            StyledToolTip {
                content: Translation.tr("Prevents abrupt increments and restricts volume limit")
            }
        }
        ConfigRow {
            // uniform: true
            ConfigSpinBox {
                text: Translation.tr("Max allowed increase")
                value: Config.options.audio.protection.maxAllowedIncrease
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowedIncrease = value;
                }
            }
            ConfigSpinBox {
                text: Translation.tr("Volume limit")
                value: Config.options.audio.protection.maxAllowed
                from: 0
                to: 154 // pavucontrol allows up to 153%
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowed = value;
                }
            }
        }
    }
    ContentSection {
        title: Translation.tr("AI")
        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }

    ContentSection {
        title: Translation.tr("Battery")

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                text: Translation.tr("Low warning")
                value: Config.options.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.low = value;
                }
            }
            ConfigSpinBox {
                text: Translation.tr("Critical warning")
                value: Config.options.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.critical = value;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: Translation.tr("Automatic suspend")
                checked: Config.options.battery.automaticSuspend
                onCheckedChanged: {
                    Config.options.battery.automaticSuspend = checked;
                }
                StyledToolTip {
                    content: Translation.tr("Automatically suspends the system when battery is low")
                }
            }
            ConfigSpinBox {
                text: Translation.tr("Suspend at")
                value: Config.options.battery.suspend
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.suspend = value;
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Networking")
        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    // BPM / Key derived audio features
    ContentSection {
        title: Translation.tr("BPM / Key")
        ContentSubsection {
            title: Translation.tr("Spotify Audio Features")
            ConfigRow {
                uniform: true
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Client ID")
                    text: Config.options?.bpmkey?.spotify?.clientId ?? ""
                    onTextChanged: Config.options.bpmkey.spotify.clientId = text
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Client Secret")
                    text: Config.options?.bpmkey?.spotify?.clientSecret ?? ""
                    onTextChanged: Config.options.bpmkey.spotify.clientSecret = text
                }
            }
            ConfigRow {
                uniform: true
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Optional: Bearer token (overrides client credentials if set)")
                    text: Config.options?.bpmkey?.spotify?.bearerToken ?? ""
                    onTextChanged: Config.options.bpmkey.spotify.bearerToken = text
                    wrapMode: TextEdit.Wrap
                }
            }
        }
    }

    // Synced/Karaoke lyrics providers
    ContentSection {
        title: Translation.tr("Lyrics")

        ConfigSwitch {
            text: Translation.tr("Use LRCLib (synced)")
            checked: Config.options.lyrics.enableLrclib
            onCheckedChanged: Config.options.lyrics.enableLrclib = checked
            StyledToolTip { content: Translation.tr("Public LRCLib API for synced lyrics (LRC). No key needed.") }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                text: Translation.tr("Use NetEase Cloud Music API (synced)")
                checked: Config.options.lyrics.enableNetease
                onCheckedChanged: Config.options.lyrics.enableNetease = checked
                StyledToolTip { content: Translation.tr("Requires a self-hosted API (binaryify/NeteaseCloudMusicApi). Used only for synced LRC lyrics.") }
            }
        }
        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("NetEase API base URL (e.g. http://localhost:3000)")
            text: Config.options.lyrics.neteaseBaseUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.lyrics.neteaseBaseUrl = text
        }

        // Optional provider requiring API key (not enabled by default)
        ContentSubsection {
            title: Translation.tr("Musixmatch")
            tooltip: Translation.tr("Musixmatch supports karaoke (richsync) and regular (subtitles/plain). Requires API access.")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: Translation.tr("Enable Musixmatch provider")
                    checked: Config.options.lyrics.musixmatch.enable
                    onCheckedChanged: Config.options.lyrics.musixmatch.enable = checked
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Musixmatch API key")
                    text: Config.options.lyrics.musixmatch.apiKey
                    onTextChanged: Config.options.lyrics.musixmatch.apiKey = text
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    text: Translation.tr("Enable karaoke (richsync)")
                    checked: Config.options.lyrics.musixmatch.enableRichsync
                    onCheckedChanged: Config.options.lyrics.musixmatch.enableRichsync = checked
                }
                ConfigSwitch {
                    text: Translation.tr("Enable regular (subtitles/plain)")
                    checked: Config.options.lyrics.musixmatch.enableRegular
                    onCheckedChanged: Config.options.lyrics.musixmatch.enableRegular = checked
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Advanced")
            ConfigSwitch {
                text: Translation.tr("Show lyrics provider notifications (debug)")
                checked: Config.options.lyrics.debugNotify
                onCheckedChanged: Config.options.lyrics.debugNotify = checked
            }
        }
    }

    ContentSection {
        title: Translation.tr("Resources")
        ConfigSpinBox {
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
    }

    ContentSection {
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                content: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Time")

        ContentSubsection {
            title: Translation.tr("Format")
            tooltip: ""

            ConfigSelectionArray {
                currentValue: Config.options.time.format
                configOptionName: "time.format"
                onSelected: newValue => {
                    if (newValue === "hh:mm") {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    } else {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    }

                    Config.options.time.format = newValue;
                    
                }
                options: [
                    {
                        displayName: Translation.tr("24h"),
                        value: "hh:mm"
                    },
                    {
                        displayName: Translation.tr("12h am/pm"),
                        value: "h:mm ap"
                    },
                    {
                        displayName: Translation.tr("12h AM/PM"),
                        value: "h:mm AP"
                    },
                ]
            }
        }
    }
}
