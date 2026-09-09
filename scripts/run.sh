#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
"$project_dir/scripts/build.sh" debug
open "$project_dir/dist/Reset Radar.app"
