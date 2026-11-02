# Emm Remote

Control remoto de mis propias computadoras (Mac, Windows y celular), como AnyDesk:
abres la app, ves un **ID**, y desde otro equipo escribes ese ID para ver y controlar.
Solo para equipos propios o con permiso explícito.

## Instalar (un clic)

| Equipo | Qué hacer |
| --- | --- |
| Windows | Abre PowerShell (`Win + X` > Terminal), pega el comando de abajo y acepta el permiso de administrador |
| Mac | Doble clic en **`Instalar Emm Remote - Mac.command`** |
| Celular | Instala **RustDesk** desde App Store o Google Play |

Comando para Windows (lo descarga en tu escritorio, aunque OneDrive lo haya movido, y lo abre):

```powershell
$d=[Environment]::GetFolderPath('Desktop'); $f="$d\Instalar Emm Remote.cmd"; irm "https://raw.githubusercontent.com/xG0ta/emm-remote/main/Instalar%20Emm%20Remote%20-%20Windows.cmd" -OutFile $f; Start-Process $f
```

El instalador descarga RustDesk oficial y verifica su firma antes de instalarlo. En Mac te guía con los permisos de pantalla y teclado. Te pregunta si quieres acceso desatendido y al final te muestra el ID del equipo.

Para probarlo paso a paso: [docs/PRUEBAS.md](docs/PRUEBAS.md).

## Qué puede hacer

Lo mismo que AnyDesk o TeamViewer en lo importante, porque por dentro usa [RustDesk](https://github.com/rustdesk/rustdesk) (código abierto, AGPL-3.0):

- Ver y controlar la pantalla con mouse y teclado, con varios monitores y ajuste de calidad o fluidez.
- Copiar y pegar entre equipos, y mandar archivos en los dos sentidos.
- Chat, audio de la otra computadora y grabación de la sesión.
- Acceso desatendido con contraseña permanente (opcional).
- Equipos recientes y favoritos, y descubrimiento en la red de casa.
- Controlar desde el celular.
- Funciona fuera de casa sin abrir puertos ni tener servidor: usa los servidores públicos y gratis de RustDesk para encontrar al otro equipo. La sesión va cifrada de punta a punta, así que esos servidores no ven tu pantalla.

## ¿Tiene límite de tiempo?

- **La app no tiene límite de tiempo de sesión** y no tiene el aviso de «uso comercial» que corta a AnyDesk o TeamViewer gratis.
- **Los servidores públicos de RustDesk:**
  - Solo sirven para encontrar al otro equipo y, cuando no hay conexión directa, para retransmitir.
  - Desde 2026 piden que el equipo que controla inicie sesión con una cuenta gratis de RustDesk.
  - RustDesk los describe como de demostración: pueden ir lentos o cambiar sus reglas.
- **Desde nov-2026 los servidores públicos rechazan conexiones sin cuenta** («The connection is not allowed»). Por eso Emm Remote usa:
  - **Tailscale** (red privada gratis, atraviesa CGNAT, sin abrir puertos) en cada equipo.
  - **Conexión directa por IP** en RustDesk: en el campo de ID se escribe la IP de Tailscale del equipo (`100.x.y.z`).
  - Firewall de Windows: puerto 21118 abierto solo para Tailscale (`100.64.0.0/10`) y la red local.

## Seguridad

- Cada conexión necesita una de dos cosas: el código temporal que cambia en cada sesión, o que alguien la acepte en el equipo controlado.
- El acceso desatendido es **opcional**. Se activa en el propio equipo con una contraseña de 12 caracteres o más, escrita en el instalador sin que se vea. RustDesk la guarda cifrada en su configuración local. Ni el instalador ni el repo la guardan.
- La ventana de conexión **siempre se ve** en el equipo controlado mientras dura una sesión, con un botón para desconectar. El instalador deja apagada la opción de ocultarla.
- Solo se instalan programas oficiales y firmados. Nada se oculta ni evade al antivirus.

## Próximas fases

1. **App con marca propia:** compilar RustDesk como «Emm Remote», con tu ícono y la configuración incluida. Se hace con un fork y GitHub Actions, gratis. Por la licencia AGPL, el código debe ser público, y sin certificados de firma aparecen avisos de «desarrollador no identificado».
2. **Servidor propio** (hbbs/hbbr), opcional, para no depender de los servidores públicos.
3. **Encender la PC a distancia** (Wake-on-LAN).

El diseño original de una app propia en Python + WebRTC quedó en [docs/diseno-mvp-python.md](docs/diseno-mvp-python.md). Nunca se programó.
