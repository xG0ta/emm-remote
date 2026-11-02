#!/bin/bash
# Emm Remote — instalador de un clic para Mac (doble clic para correrlo).
# Instala RustDesk oficial (firmado por Apple), te guía con los permisos y, si
# lo pides, activa el acceso desatendido con una contraseña que escribes tú
# aquí mismo. Nada se guarda en este archivo ni en el repo.
set -euo pipefail

PINNED_VERSION="1.5.1"
APP="/Applications/RustDesk.app"
BIN="$APP/Contents/MacOS/RustDesk"

paso() { printf '\n\033[36m== %s\033[0m\n' "$1"; }

printf '\033[31m============================================\n'
printf '   EMM REMOTE - instalador\n'
printf '   Solo para equipos propios o con permiso.\n'
printf '============================================\033[0m\n'

# 1) RustDesk
paso "Programa de control remoto (RustDesk oficial)"
if [ -d "$APP" ]; then
  echo "Ya estaba instalado."
else
  case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    arm64)  ARCH="aarch64" ;;
    *) echo "Arquitectura no reconocida: $(uname -m)"; exit 1 ;;
  esac
  URL="$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest 2>/dev/null \
        | grep -o "https://[^\"]*/rustdesk-[0-9.]*-${ARCH}\.dmg" | head -1 || true)"
  [ -n "$URL" ] || URL="https://github.com/rustdesk/rustdesk/releases/download/${PINNED_VERSION}/rustdesk-${PINNED_VERSION}-${ARCH}.dmg"
  TMP="$(mktemp -d)"
  echo "Descargando $URL"
  curl -fL --progress-bar -o "$TMP/rustdesk.dmg" "$URL"
  MNT="$(hdiutil attach -nobrowse -readonly "$TMP/rustdesk.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"
  if ! codesign --verify --deep --strict "$MNT/RustDesk.app" || ! spctl --assess --type execute "$MNT/RustDesk.app"; then
    hdiutil detach "$MNT" -quiet; rm -rf "$TMP"
    echo "La firma de la app no es válida. No se instaló nada."; exit 1
  fi
  echo "Firma de Apple verificada."
  cp -R "$MNT/RustDesk.app" /Applications/
  hdiutil detach "$MNT" -quiet
  rm -rf "$TMP"
  echo "Instalado en Aplicaciones."
fi

# 2) Permisos de macOS
paso "Permisos (para que esta Mac se pueda ver y controlar)"
echo "Se abrirá Ajustes del Sistema. Activa RustDesk en:"
echo "  1. Grabación de pantalla (o «Grabación de pantalla y audio del sistema»)"
echo "  2. Accesibilidad"
echo "Si no aparece, usa el botón + y elige Aplicaciones > RustDesk."
open "$APP"
sleep 3
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
read -r -p "Cuando actives Grabación de pantalla, presiona Enter… " _ </dev/tty
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
read -r -p "Cuando actives Accesibilidad, presiona Enter… " _ </dev/tty
echo "Reiniciando RustDesk para que tome los permisos…"
osascript -e 'quit app "RustDesk"' 2>/dev/null || true
sleep 2
open "$APP"
sleep 4

# 3) Acceso desatendido (opcional)
paso "Acceso desatendido (entrar sin que alguien acepte aquí)"
echo "Si dices que no, cada conexión necesitará el código temporal que muestra la app"
echo "o que alguien la acepte en esta Mac."
read -r -p "¿Activarlo en ESTA Mac? (s/n) " R </dev/tty
if [[ "$R" =~ ^[sS] ]]; then
  while true; do
    read -r -s -p "Escribe una contraseña fuerte (12+ caracteres, no se ve al escribir): " P1 </dev/tty; echo
    read -r -s -p "Repítela: " P2 </dev/tty; echo
    [ "$P1" = "$P2" ] || { echo "No coinciden. Otra vez."; continue; }
    [ "${#P1}" -ge 12 ] || { echo "Muy corta: usa 12 caracteres o más."; continue; }
    break
  done
  echo "Te pedirá la contraseña de administrador de la Mac:"
  OUT="$(sudo "$BIN" --password "$P1" 2>&1 || true)"
  unset P1 P2
  sudo "$BIN" --option verification-method use-both-passwords >/dev/null 2>&1 || true
  sudo "$BIN" --option approve-mode password >/dev/null 2>&1 || true
  sudo "$BIN" --option allow-hide-cm N >/dev/null 2>&1 || true
  if [[ "$OUT" == *Done* ]]; then
    echo "Acceso desatendido activado. Guarda la contraseña en el llavero o tu gestor."
  else
    echo "RustDesk respondió: ${OUT:-nada}"
    echo "Ponla a mano: RustDesk > Ajustes > Seguridad > Desbloquear > Contraseña permanente."
  fi
else
  echo "Sin acceso desatendido."
fi

# 4) Datos para conectarte
paso "Listo"
ID="$("$BIN" --get-id 2>/dev/null | tail -1 || true)"
echo
printf '   \033[32mID de esta Mac:  %s\033[0m\n' "${ID:-(míralo en la ventana de RustDesk)}"
echo
echo "Para controlarla desde la PC o el celular: abre Emm Remote allá y escribe este ID."
echo "Mientras haya alguien conectado, aquí se verá la ventana de RustDesk con un botón para desconectar."
