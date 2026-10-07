#!/usr/bin/env bash
# Compila y arma build/Focus.app. Con --install la copia a /Applications y la abre.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh

swift build -c release
bin=$(swift build -c release --show-bin-path)

app=build/Focus.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Focus" "$app/Contents/MacOS/Focus"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app" >/dev/null
echo "App lista: $app"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Focus 2>/dev/null || true
  rm -rf /Applications/Focus.app
  cp -R "$app" /Applications/Focus.app
  open /Applications/Focus.app
  echo "Instalada en /Applications/Focus.app"
fi
