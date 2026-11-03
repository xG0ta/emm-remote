#!/bin/bash
# Compila el lanzador y arma "Emm Remote.app" en apps/mac/build/.
# Uso: [LOGO=1|2|3] bash apps/mac/construir.sh [--instalar]   (--instalar lo copia a /Applications)
# LOGO elige el diseño del ícono (ver apps/mac/logos/); por omisión, 1.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/EmmRemote"

APP="build/Emm Remote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/EmmRemote"

# Ícono: se dibuja con el script icono.swift y se convierte a .icns
TMP="$(mktemp -d)"
swift icono.swift "$TMP/icono.png" "${LOGO:-1}"
ICONSET="$TMP/EmmRemote.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icono.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icono.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/EmmRemote.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Emm Remote</string>
  <key>CFBundleDisplayName</key><string>Emm Remote</string>
  <key>CFBundleIdentifier</key><string>mx.gota.emmremote</string>
  <key>CFBundleExecutable</key><string>EmmRemote</string>
  <key>CFBundleIconFile</key><string>EmmRemote</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.4.0</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSLocalNetworkUsageDescription</key><string>Emm Remote revisa si tus equipos están en línea y envía la señal para encenderlos (Wake-on-LAN).</string>
</dict></plist>
PLIST

# Firma local (ad hoc): basta para correr en esta Mac
codesign --force --deep --sign - "$APP"
echo "Listo: apps/mac/$APP"

if [ "${1:-}" = "--instalar" ]; then
  rm -rf "/Applications/Emm Remote.app"
  cp -R "$APP" /Applications/
  echo "Instalado en /Applications/Emm Remote.app"
fi
