#!/bin/bash
# Emm Remote — preparación en Mac (Intel o Apple Silicon).
# Instala RustDesk oficial (si falta), abre la descarga de Tailscale y aplica
# las opciones seguras: conexión directa por IP y lista blanca (solo Tailscale
# y red de casa). No guarda ni pide contraseñas: la contraseña permanente
# (acceso desatendido) la pones tú en RustDesk, en este mismo equipo.
set -euo pipefail

RUSTDESK_VERSION="${RUSTDESK_VERSION:-1.5.1}"
APP="/Applications/RustDesk.app"
BIN="$APP/Contents/MacOS/RustDesk"
# Tailscale IPv4 e IPv6, más la red local típica de un módem Infinitum.
WHITELIST="100.64.0.0/10,fd7a:115c:a1e0::/48,192.168.0.0/16"

echo "== Emm Remote: preparación en Mac =="

# 1) RustDesk
if [ -d "$APP" ]; then
  echo "RustDesk ya está instalado."
else
  case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    arm64)  ARCH="aarch64" ;;
    *) echo "Arquitectura no reconocida: $(uname -m)"; exit 1 ;;
  esac
  URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/rustdesk-${RUSTDESK_VERSION}-${ARCH}.dmg"
  TMP="$(mktemp -d)"
  echo "Descargando RustDesk ${RUSTDESK_VERSION} (${ARCH}) desde GitHub oficial…"
  curl -fL --progress-bar -o "$TMP/rustdesk.dmg" "$URL"
  MNT="$(hdiutil attach -nobrowse -readonly "$TMP/rustdesk.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"
  echo "Verificando la firma de Apple de la app…"
  codesign --verify --deep --strict "$MNT/RustDesk.app"
  spctl --assess --type execute "$MNT/RustDesk.app" && echo "Firma y notarización correctas."
  cp -R "$MNT/RustDesk.app" /Applications/
  hdiutil detach "$MNT" -quiet
  rm -rf "$TMP"
  echo "RustDesk instalado en /Applications."
fi

# 2) Tailscale (para conectarte fuera de casa)
if [ -d "/Applications/Tailscale.app" ]; then
  echo "Tailscale ya está instalado."
else
  echo "Abriendo Tailscale en la Mac App Store (gratis). Instálalo e inicia sesión."
  open "macappstore://apps.apple.com/app/tailscale/id1475387142" || open "https://tailscale.com/download/mac"
fi

# 3) Permisos de macOS que RustDesk necesita para ser controlado
echo
echo "Abriendo Privacidad y seguridad. Activa RustDesk en:"
echo "  - Grabación de pantalla (para que se vea tu pantalla)"
echo "  - Accesibilidad (para recibir mouse y teclado)"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

# 4) Opciones seguras (requiere RustDesk abierto y contraseña de administrador)
echo
echo "Abriendo RustDesk…"
open "$APP"
sleep 5
echo "Aplicando opciones (te pedirá la contraseña de administrador de la Mac):"
OUT1="$(sudo "$BIN" --option direct-server Y 2>&1 || true)"
OUT2="$(sudo "$BIN" --option whitelist "$WHITELIST" 2>&1 || true)"
CHECK="$(sudo "$BIN" --option whitelist 2>&1 || true)"
if [ "$CHECK" = "$WHITELIST" ]; then
  echo "Listo: conexión directa activada y lista blanca = $WHITELIST"
else
  echo "No se pudieron aplicar por línea de comandos (${OUT1}${OUT2})."
  echo "Hazlo a mano en RustDesk > Ajustes > Seguridad:"
  echo "  - Activa «Habilitar acceso directo por IP» (puerto 21118)"
  echo "  - En «Lista blanca de IP» pon: $WHITELIST"
fi

# 5) Datos para conectarte
echo
if [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]; then
  TSIP="$(/Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null || true)"
  [ -n "$TSIP" ] && echo "IP de Tailscale de esta Mac: $TSIP"
fi
LANIP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
[ -n "$LANIP" ] && echo "IP en la red de casa: $LANIP"
echo
echo "Siguiente: sigue docs/PRUEBAS.md"
