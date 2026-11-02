# Emm Remote

Control remoto de mis propias computadoras (Mac, Windows y celular), como AnyDesk pero
con piezas gratis y de código abierto. Solo para equipos propios o con permiso explícito.

## Cómo está armado (versión 0.1)

```text
Celular / Mac / Windows  --RustDesk, cifrado de punta a punta-->  Equipo controlado
          \__________ Tailscale (red privada cifrada, atraviesa CGNAT) _________/
```

- **[RustDesk](https://github.com/rustdesk/rustdesk)** (AGPL-3.0) se encarga de la pantalla, el mouse, el teclado, el portapapeles y los archivos. Usa la versión oficial firmada.
- **[Tailscale](https://tailscale.com)** (gratis para uso personal) une tus equipos en una red privada. Así no necesitas abrir puertos en el módem ni tener un servidor encendido.
- Conexión **directa por IP** (puerto 21118) con **lista blanca**: solo se aceptan conexiones desde Tailscale (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`) y desde tu red de casa (`192.168.0.0/16`).

## Seguridad

- El cifrado es de punta a punta (RustDesk) y además va por dentro de Tailscale (WireGuard).
- Por defecto, cada conexión se acepta a mano en el equipo controlado, o se entra con la contraseña temporal que cambia en cada sesión.
- El acceso desatendido es **opcional** y se activa en el propio equipo, con una contraseña permanente fuerte. Ni los scripts ni el repo guardan contraseñas.
- Mientras haya una sesión, RustDesk muestra su ventana en el equipo controlado, con el nombre del que se conectó y un botón para desconectar. No se oculta ni se desactiva.
- Nada de evadir el antivirus: se usan los instaladores oficiales y firmados.

## Uso

1. Prepara cada computadora:
   - Windows: `scripts/windows/instalar-emm-remote.ps1` (PowerShell como administrador)
   - Mac: `scripts/mac/instalar-emm-remote.command`
2. Sigue [docs/PRUEBAS.md](docs/PRUEBAS.md): primero en la red de casa, luego con Tailscale y luego desde el celular.

## Próximas fases

1. **Marca Emm:** compilar RustDesk con el nombre «Emm Remote», tu ícono y las opciones de arriba ya incluidas. Se hace con un fork y GitHub Actions, gratis. Por la licencia AGPL, el código del fork debe ser público.
2. **Servidor propio** (hbbs/hbbr), opcional, para conectarte por ID sin Tailscale. Puede vivir en una VPS gratis.
3. **Encender la PC a distancia** (Wake-on-LAN por Tailscale desde otro equipo de la red, o Wake-on-WAN si el módem lo permite).

El diseño original de una app propia en Python + WebRTC quedó en [docs/diseno-mvp-python.md](docs/diseno-mvp-python.md). Nunca se programó.
