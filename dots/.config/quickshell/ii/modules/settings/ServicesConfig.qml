import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

        MaterialTextArea {
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
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
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
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
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
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
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
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }
}
