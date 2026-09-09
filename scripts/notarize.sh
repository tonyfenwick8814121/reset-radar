#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 || -z "${APPLE_KEYCHAIN_PROFILE:-}" ]]; then
  echo "Usage: APPLE_KEYCHAIN_PROFILE=<profile> $0 <signed-archive.zip>" >&2
  exit 2
fi

archive="$1"
xcrun notarytool submit "$archive" --keychain-profile "$APPLE_KEYCHAIN_PROFILE" --wait
