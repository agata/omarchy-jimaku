#!/usr/bin/env bash
# Isolated, offline Qt tests. No user keys, preferences or history are read.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
jimaku_runtime="${XDG_DATA_HOME:-$HOME/.local/share}/jimaku/runtime"
[[ -x "$jimaku_runtime/bin/python" ]] || { echo 'Run setup.sh first.' >&2; exit 1; }
jimaku_tmp=$(mktemp -d)
trap 'rm -rf -- "$jimaku_tmp"' EXIT
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_CONTROLS_STYLE=Basic
export LC_ALL=ja_JP.UTF-8 LANGUAGE=ja OPENAI_API_KEY=sk-test-only
for jimaku_test in Setup Continuity Discovery FontSize Language Modes Timing Toolbar Ui Behavior; do
  jimaku_case="$jimaku_tmp/$jimaku_test"
  mkdir -p "$jimaku_case/config/jimaku" "$jimaku_case/data/jimaku" "$jimaku_case/runtime"
  chmod 700 "$jimaku_case/runtime"
  if [[ "$jimaku_test" != Setup ]]; then ln -s "$jimaku_runtime" "$jimaku_case/data/jimaku/runtime"; fi
  if [[ "$jimaku_test" == Behavior || "$jimaku_test" == Ui ]]; then
    printf '%s\n' '{"display_mode":"readable"}' > "$jimaku_case/config/jimaku/settings.json"
  fi
  echo "Testing ${jimaku_test}Test.qml"
  if ! XDG_CONFIG_HOME="$jimaku_case/config" XDG_DATA_HOME="$jimaku_case/data" XDG_RUNTIME_DIR="$jimaku_case/runtime" \
    JIMAKU_TEST_SCREENSHOT="$jimaku_case/preview.png" \
    timeout 20 qs -p "${jimaku_test}Test.qml" --no-color > "$jimaku_case/output.log" 2>&1; then
    cat "$jimaku_case/output.log"
    exit 1
  fi
  rg 'PASSED' "$jimaku_case/output.log"
done
