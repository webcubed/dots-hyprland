#!/usr/bin/env bash
set -euo pipefail

# Fetch Plumpy Wi‑Fi strength Android Vector Drawables from Iconify repo and convert to SVGs
# Output: ~/.config/quickshell/ii/assets/icons8/plumpy/wifi-{1..4}.svg and wifi-0.svg (derived from 1)

ROOT_DIR=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
ASSETS_DIR="$ROOT_DIR/assets/icons8/plumpy"
TMP_DIR="${TMPDIR:-/tmp}/iconify_plumpy_wifi"
REPO_RAW_BASE="https://raw.githubusercontent.com/Mahmud0808/Iconify/beta/app/src/main/res/drawable-v24"

mkdir -p "$ASSETS_DIR" "$TMP_DIR"

# Files to fetch (Plumpy pack uses these names)
files=(
  preview_plumpy_ic_wifi_signal_1.xml
  preview_plumpy_ic_wifi_signal_2.xml
  preview_plumpy_ic_wifi_signal_3.xml
  preview_plumpy_ic_wifi_signal_4.xml
)

# Robust Android VectorDrawable XML -> SVG converter using Python's ElementTree
convert_avd_to_svg() {
  local xml_file="$1" svg_file="$2"
  python3 - "$xml_file" "$svg_file" <<'PY'
import sys, xml.etree.ElementTree as ET
xml_file, out_file = sys.argv[1], sys.argv[2]
NS_ANDROID = 'http://schemas.android.com/apk/res/android'
def a(name):
    return f'{{{NS_ANDROID}}}{name}'

tree = ET.parse(xml_file)
root = tree.getroot()

paths = []
for el in root.iter():
    if el.tag.endswith('path'):
        d = el.attrib.get(a('pathData')) or el.attrib.get('pathData')
        if not d:
            continue
        fill = el.attrib.get(a('fillColor')) or el.attrib.get('fillColor') or 'currentColor'
        paths.append((d, fill))

with open(out_file, 'w', encoding='utf-8') as f:
    f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">\n')
    for d, fill in paths:
        # Normalize android color formats like #AARRGGBB to rgba if needed
        if isinstance(fill, str) and len(fill) == 9 and fill.startswith('#'):
            aa = int(fill[1:3], 16) / 255.0
            rr = fill[3:5]
            gg = fill[5:7]
            bb = fill[7:9]
            fill = f'rgba({int(rr,16)},{int(gg,16)},{int(bb,16)},{aa:.3f})'
        f.write(f'  <path d="{d}" fill="{fill}"/>\n')
    f.write('</svg>\n')
PY
}

for f in "${files[@]}"; do
  curl -fsSL "$REPO_RAW_BASE/$f" -o "$TMP_DIR/$f"
  # Map 1..4
  idx=$(echo "$f" | sed -n 's/.*_\([1-4]\)\.xml/\1/p')
  [[ -n "$idx" ]] || continue
  convert_avd_to_svg "$TMP_DIR/$f" "$ASSETS_DIR/wifi-$idx.svg"
  echo "Wrote $ASSETS_DIR/wifi-$idx.svg"

done

# Derive wifi-0.svg from wifi-1.svg by reducing opacity (visually similar to no bars)
if [[ -f "$ASSETS_DIR/wifi-1.svg" ]]; then
  awk 'BEGIN{print "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"24\" height=\"24\">"} \
       /<path/{sub(/fill=\"[^\"]*\"/, "fill=\"currentColor\" opacity=\"0.25\""); print} \
       END{print "</svg>"}' "$ASSETS_DIR/wifi-1.svg" > "$ASSETS_DIR/wifi-0.svg"
  echo "Wrote $ASSETS_DIR/wifi-0.svg"
fi

echo "Done."
