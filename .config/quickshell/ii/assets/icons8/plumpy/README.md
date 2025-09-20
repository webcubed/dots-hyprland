# Icons8 Plumpy icons (duotone)

Put downloaded SVGs here. Use the exact filenames below so QML can load them directly.

## Provided icons (present in this repo)

-   airplane.svg, apps.svg
-   arrow-right.svg, chevron-down.svg, chevron-up.svg, chevron-left.svg, chevron-right.svg, next-page.svg, rightarrow-duotone.svg
-   battery.svg, bolt.svg, power.svg, restart.svg
-   bell.svg, bell-ringing.svg
-   bluetooth.svg, bluetooth-connected.svg
-   calendar.svg
-   chat.svg, speech.svg
-   chemistry.svg, circle-check.svg, check.svg, x.svg
-   clipboard-approve.svg, copy.svg
-   coffee.svg
-   cpu.svg, memory-slot.svg, piechart.svg
-   gamepad.svg, headphones.svg, image.svg, phone.svg, plus.svg
-   keyboard.svg, lan.svg, lock.svg
-   math.svg, terminal.svg, todo.svg, toolbox.svg, translation.svg
-   mic.svg, mic-mute.svg
-   moon.svg, night-light.svg, sun.svg, sunrise.svg, sunset.svg
-   pause.svg, play.svg, previous.svg, skip.svg, snooze.svg
-   rain.svg, wind.svg, thermometer.svg, flake.svg, snow-1flake.svg, snow-many.svg, cloud.svg, cloudy.svg, fog.svg, night-fog.svg, sun-fog.svg
-   search.svg, searchbar.svg, settings.svg, tune.svg, tune-vertical.svg, visibility.svg, clock.svg
-   wifi.svg, wifi-off.svg, wifi-0.svg, wifi-1.svg, wifi-2.svg, wifi-3.svg, wifi-4.svg
-   album.svg, pin.svg, icons8-music-note.svg, user.svg, speed-circle.svg, speed-science.svg

We use these names directly in QML. If you add more, keep the same lowercase-dashed naming.

---

## Coverage map

Implemented (Plumpy used with Material fallback):

-   Bar indicators: speaker-mute.svg (volume), mic-mute.svg (mic), wifi-0..4.svg/wifi-off.svg/lan.svg (network), bolt.svg (battery), cpu.svg and memory-slot.svg (resources)
-   Dynamic Island: icons8-music-note.svg (lyrics toggle), copy.svg (clipboard), clipboard-approve.svg (drop success)
-   Media: previous.svg, play.svg, pause.svg, skip.svg; album.svg, icons8-music-note.svg; tune.svg and speed-science.svg in info popup; vertical media uses play/pause and icons8-music-note
-   Weather: sun.svg, cloud.svg (cloud), cloudy.svg (partly cloudy), fog.svg (fog), rain.svg; location.svg in popup header; cards use sun.svg (UV), wind.svg (Wind), rain.svg (Precip), thermometer.svg (Humidity approx), visibility.svg, sunrise.svg, moon.svg; snow variants wired (flake.svg, snow-1flake.svg, snow-many.svg)
-   Battery popup: battery.svg, bolt.svg; clock.svg for time-to-full/empty
-   Scroll hints: chevron-up.svg, chevron-down.svg; light_mode → sun.svg
-   Util buttons: image.svg (snip), toolbox.svg (picker), keyboard.svg, mic.svg/mic-mute.svg, sun.svg/moon.svg, bolt/settings/leaf
-   Dock: apps.svg; x.svg for preview close; pin toggle falls back (pin.svg missing)
-   Right sidebar: quick toggles (wifi\*, bluetooth, auto night light = night-light.svg, manual night light = moon.svg, gamepad, coffee, tune), Wi‑Fi list (lock.svg, check.svg), tabs (chemistry.svg, keyboard.svg, bell for Notifications), bottom group rail (calendar.svg, check.svg, clock.svg)
-   Lock screen: check.svg, moon.svg, power.svg
-   Overview (Search): math.svg, terminal.svg, tune.svg/translation.svg, check.svg, clipboard-approve.svg
-   Notifications (default app glyph): calendar, chat, terminal, bell, bell-ringing, phone, headphones, image, mic/mic-off

Still using Material (needs assets or mapping):

-   Settings navigation icons: instant_mix, browse, toast, bottom_app_bar (no Plumpy equivalents yet)

---

## Missing icons to download (to complete current wiring)

Required for full coverage

None (current mappings use user.svg for Artist and speed-science.svg for Speed)

Nice-to-have / explicit variants

-   equalizer.svg (or instant-mix.svg) — EasyEffects

Notes

-   If you prefer different Plumpy names, keep the same lowercase-dashed convention and share the mapping.

---

## Quick references

Network/Wi‑Fi (strength mapping):

-   wifi-0.svg → very weak/off
-   wifi-1.svg → 1 bar
-   wifi-2.svg → 2 bars
-   wifi-3.svg → 3 bars
-   wifi-4.svg → 4 bars (full)
-   wifi-off.svg → Wi‑Fi disabled
-   lan.svg → Ethernet
-   airplane.svg → Airplane mode (optional)

Bluetooth:

-   bluetooth.svg → On
-   bluetooth-connected.svg → Connected (optional)
-   bluetooth-disabled.svg → Disabled (optional)

Other quick toggles:

-   night-sight-auto.svg → Auto night light (optional)
-   bedtime.svg → Manual night light (optional)
-   gamepad.svg → Game mode
-   coffee.svg → Idle inhibitor
-   equalizer.svg / instant-mix.svg → EasyEffects (optional)

Header buttons (top of right sidebar):

-   restart.svg
-   settings.svg
-   power.svg

Dimensions

-   Canvas: 24x24 (viewBox="0 0 24 24"). Keep centered; separate duotone layers.

Coloring

-   We tint in QML using the shell palette. Fills can be black/gray or currentColor.

Night Light naming

-   Auto: night-light.svg (moon + stars)
-   Manual: moon.svg

Fetching Wi‑Fi strengths automatically

-   Use the helper script to pull Plumpy Wi‑Fi strength drawables:
-   scripts/icons/fetch_iconify_wifi.sh (writes wifi-1..4.svg and derives wifi-0.svg)

Enable in UI

-   Settings → Interface → Sidebars → "Use Icons8 Plumpy icons for quick toggles".

## How to add a missing icon

1. Save the SVG named exactly as listed above into this folder (24×24 viewBox).
2. Prefer simple paths; colors can be black/gray (we tint in QML).
3. The UI loads new icons automatically; PlumpyIcon falls back to Material until the asset exists.
