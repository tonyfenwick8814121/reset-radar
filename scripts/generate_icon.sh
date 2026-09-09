#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
icon_source="$project_dir/design/app-icon-1024.png"
iconset="$project_dir/.build/ResetRadar.iconset"

swift "$project_dir/scripts/generate_icon.swift" "$icon_source"
rm -rf "$iconset"
mkdir -p "$iconset"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  pixels="${spec%% *}"
  name="${spec#* }"
  sips -z "$pixels" "$pixels" "$icon_source" --out "$iconset/$name" >/dev/null
done
iconutil -c icns "$iconset" -o "$project_dir/ResetRadar/Resources/ResetRadar.icns"
