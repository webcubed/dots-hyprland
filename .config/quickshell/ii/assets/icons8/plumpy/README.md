# Icons8 Plumpy icons (duotone)

Put downloaded SVGs here. Use the exact filenames below so QML can load them directly.

Provided icons (detected in this repo):

-   airplane.svg, apps.svg, bell.svg, bell-ringing.svg
-   bluetooth.svg, bluetooth-connected.svg
-   calendar.svg
-   chevron-down.svg, chevron-up.svg, chevron-left.svg, chevron-right.svg
-   coffee.svg
-   cpu.svg, memory-slot.svg
-   gamepad.svg
-   math.svg
-   mic.svg, mic-mute.svg
-   night-light.svg
-   pause.svg, play.svg, previous.svg, skip.svg, snooze.svg
-   power.svg, restart.svg
-   rain.svg, wind.svg, sun.svg, sunrise.svg, sunset.svg
-   search.svg, searchbar.svg, settings.svg
-   speaker-mute.svg
-   terminal.svg, todo.svg, toolbox.svg, translation.svg, tune.svg, visibility.svg
-   wifi.svg, wifi-off.svg, wifi-0.svg, wifi-1.svg, wifi-2.svg, wifi-3.svg, wifi-4.svg
-   lan.svg, lock.svg, check.svg
-   moon.svg, x.svg, clipboard-approve.svg

We use these names directly in QML. If you add more, keep the same lowercase-dashed naming.

---

Missing icons to download (for what’s already wired):

Required for full coverage of current UI swaps

-   pin.svg — Dock pin toggle icon
    -   Used in: modules/dock/Dock.qml (pin button)

Highly recommended (right sidebar parity and navigation)

None (these are already included: chevron-left.svg, chevron-right.svg, lock.svg, check.svg, lan.svg)

Optional (nice-to-have parity in info/popups/overlays)

-   bluetooth-disabled.svg — Explicit Bluetooth disabled variant
    -   We currently reuse bluetooth.svg when disabled
-   music-note.svg — Media info header glyph
-   person.svg — Artist glyph in media popup
-   album.svg — Album glyph in media popup
-   speed.svg — Bitrate/quality glyph in media popup
-   tune.svg — Format/codec or settings glyph in media popup
-   schedule.svg — Duration/position glyph in media popup
    -   Used in: modules/bar/MediaInfoPopup.qml
-   inventory.svg — Dynamic Island drop success glyph
    -   Used in: modules/bar/DynamicIsland.qml (drop overlay)
-   bedtime.svg — Night Light manual (if you want a distinct manual icon)
-   night-sight-auto.svg — Night Light auto (if you want a distinct auto icon)
-   equalizer.svg or instant-mix.svg — EasyEffects icon (replace placeholder)
-   chat.svg — Overview: used when mapping forum label; falls back to Material if missing

Notes

-   If you prefer different Plumpy names for the optional set, keep the same lowercase-dashed convention and tell me the mapping; I’ll wire them.

---

Quick reference – Network/Wi‑Fi mapping already wired:

Network/Wi‑Fi (Iconify-like strength mapping):

-   wifi-0.svg → Signal 0 (off/very weak) [Icons8: “Signal Low” or base Wi‑Fi with 0 bars]
-   wifi-1.svg → Signal 1 bar
-   wifi-2.svg → Signal 2 bars
-   wifi-3.svg → Signal 3 bars
-   wifi-4.svg → Signal 4 bars (full)
-   wifi-off.svg → Wi‑Fi disabled (slash or crossed)
-   lan.svg → Ethernet (cable/lan)
-   airplane.svg → Airplane mode (optional)

Bluetooth:

-   bluetooth.svg → On
-   bluetooth-connected.svg → Connected (optional)
-   bluetooth-disabled.svg → Disabled (optional)

Other quick toggles (single glyphs):

-   night-sight-auto.svg → Auto Night Light (optional)
-   bedtime.svg → Night Light manual (optional)
-   gamepad.svg → Game mode
-   coffee.svg → Idle inhibitor
-   equalizer.svg or instant-mix.svg → EasyEffects (optional)

Header buttons (top of right sidebar):

-   restart.svg
-   settings.svg
-   power.svg

Dimensions:

-   Canvas: 24x24 px (viewBox="0 0 24 24").
-   Stroke/fill scalable; keep centered. Duotone layers should be separate path elements for primary/secondary.

Coloring:

-   We recolor in QML with the shell palette. In quick toggles: on=tinted with Appearance.m3colors.m3onPrimary; off=tinted with Appearance.colors.colOnLayer1. In headers/buttons we use Appearance.colors.colOnLayer0. Set fills to currentColor or leave as black/gray.

Notes:

-   Keep names lowercase with dashes as above.
-   If an exact Plumpy asset doesn’t exist, pick the closest Plumpy duotone.

Night Light naming

-   Auto mode uses: night-light.svg (moon + stars)
-   Manual mode uses: moon.svg

Fetching Wi‑Fi strengths automatically:

-   Use the helper script to pull Plumpy Wi‑Fi strength drawables from the Iconify repo and convert them to SVGs:
    -   scripts/icons/fetch_iconify_wifi.sh
-   This writes wifi-1.svg .. wifi-4.svg and derives wifi-0.svg.

Enable in UI:

-   Settings → Interface → Sidebars → “Use Icons8 Plumpy icons for quick toggles”.
