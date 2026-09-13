#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="${1:-0.1.0}"
app_dir="$project_dir/dist/Reset Radar.app"
archive="$project_dir/dist/Reset-Radar-$version-arm64.zip"

"$project_dir/scripts/build.sh" release

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app_dir"
fi

rm -f "$archive" "$archive.sha256"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
(cd "$project_dir/dist" && shasum -a 256 "${archive:t}") > "$archive.sha256"
codesign --verify --deep --strict "$app_dir"
printf '%s\n%s\n' "$archive" "$archive.sha256"
