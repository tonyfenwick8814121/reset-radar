#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
build_dir="$project_dir/.build/$configuration"
app_dir="$project_dir/dist/Reset Radar.app"

cd "$project_dir"
swift build -c "$configuration"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/ResetRadar" "$app_dir/Contents/MacOS/ResetRadar"
cp "$project_dir/ResetRadar/Resources/Info.plist" "$app_dir/Contents/Info.plist"
if [[ -f "$project_dir/ResetRadar/Resources/ResetRadar.icns" ]]; then
  cp "$project_dir/ResetRadar/Resources/ResetRadar.icns" "$app_dir/Contents/Resources/ResetRadar.icns"
fi
if [[ -d "$build_dir/ResetRadar_ResetRadar.bundle" ]]; then
  cp -R "$build_dir/ResetRadar_ResetRadar.bundle" "$app_dir/Contents/Resources/"
fi
codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
