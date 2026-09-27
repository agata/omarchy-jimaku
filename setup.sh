#!/usr/bin/env bash
# Explicit, user-invoked setup; Omarchy never executes install hooks.
set -euo pipefail
jimaku_source=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jimaku_runtime="${XDG_DATA_HOME:-$HOME/.local/share}/jimaku/runtime"
for jimaku_command in uv python3 pactl parec; do
  command -v "$jimaku_command" >/dev/null || { echo "Missing command: $jimaku_command" >&2; exit 1; }
done
python3 -c 'import sys; assert sys.version_info >= (3, 11), "Python 3.11+ required"'
if [[ ! -x "$jimaku_runtime/bin/python" ]]; then
  uv venv --python "$(command -v python3)" "$jimaku_runtime"
fi
uv pip install --python "$jimaku_runtime/bin/python" -r "$jimaku_source/requirements.txt"
"$jimaku_runtime/bin/python" -c 'import websockets; assert websockets.__version__ == "15.0.1"'
echo 'Jimaku is ready. Close and reopen the caption window.'
