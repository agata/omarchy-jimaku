#!/usr/bin/env bash
# Local checkout convenience installer. No sudo, overwrites, or desktop config edits.
set -euo pipefail
jimaku_source=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
jimaku_target="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.agata.jimaku"
for jimaku_command in omarchy omarchy-shell jq; do
  command -v "$jimaku_command" >/dev/null || { echo "Missing command: $jimaku_command" >&2; exit 1; }
done
if [[ -e "$jimaku_target" || -L "$jimaku_target" ]]; then
  if [[ "$(readlink -f -- "$jimaku_target")" != "$jimaku_source" ]]; then
    echo "Refusing to replace an existing plugin: $jimaku_target" >&2
    exit 1
  fi
fi
omarchy plugin validate "$jimaku_source"
bash "$jimaku_source/setup.sh"
mkdir -p -- "$(dirname -- "$jimaku_target")"
if [[ ! -e "$jimaku_target" ]]; then ln -s -- "$jimaku_source" "$jimaku_target"; fi
omarchy-shell shell rescanPlugins
jimaku_found=false
for ((jimaku_attempt=0; jimaku_attempt<50; jimaku_attempt++)); do
  if omarchy-shell shell listPlugins | jq -e 'any(.[]; .id == "io.github.agata.jimaku")' >/dev/null; then
    jimaku_found=true
    break
  fi
  sleep 0.1
done
if [[ "$jimaku_found" != true ]]; then
  echo 'Plugin discovery timed out. Check that Omarchy Shell is running, then run install.sh again.' >&2
  exit 1
fi
omarchy plugin enable io.github.agata.jimaku
echo 'Jimaku enabled. Open the captions icon in the bar. See README.md for the floating-window rule.'
