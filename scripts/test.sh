#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
jimaku_python="${JIMAKU_TEST_PYTHON:-${XDG_DATA_HOME:-$HOME/.local/share}/jimaku/runtime/bin/python}"
"$jimaku_python" -m unittest discover -s tests -v
node tests/test_captions.cjs
for jimaku_script in setup.sh install.sh scripts/*.sh; do bash -n "$jimaku_script"; done
if command -v omarchy >/dev/null; then omarchy plugin validate "$PWD"; fi
