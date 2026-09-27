#!/usr/bin/env bash
# Render real QML components using synthetic data, without backend or API access.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
jimaku_tmp=$(mktemp -d)
trap 'rm -rf -- "$jimaku_tmp"' EXIT
mkdir -p "$jimaku_tmp/runtime" "$jimaku_tmp/config" "$jimaku_tmp/data" docs
chmod 700 "$jimaku_tmp/runtime"
export XDG_RUNTIME_DIR="$jimaku_tmp/runtime" XDG_CONFIG_HOME="$jimaku_tmp/config" XDG_DATA_HOME="$jimaku_tmp/data"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_CONTROLS_STYLE=Basic
export LC_ALL=C.UTF-8 LANGUAGE=en
unset OPENAI_API_KEY
for jimaku_scene in captions toolbar start settings; do
  JIMAKU_PREVIEW_SCENE="$jimaku_scene" JIMAKU_TEST_SCREENSHOT="$PWD/docs/$jimaku_scene.png" \
    timeout 10 qs -p GalleryPreview.qml --no-color > "$jimaku_tmp/$jimaku_scene.log" 2>&1 || {
      cat "$jimaku_tmp/$jimaku_scene.log"; exit 1;
    }
  rg 'GALLERY_PREVIEW_PASSED' "$jimaku_tmp/$jimaku_scene.log"
done
