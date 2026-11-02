# Pruebas de Emm Remote

Ve marcando cada paso con ✅ o ❌. Si algo falla, toma una captura del mensaje.

## 0. Instalar

**Windows (laptop RTX 4060)**
1. Abre PowerShell (`Win + X` > Terminal), pega esto y presiona Enter:
   ```powershell
   $d=[Environment]::GetFolderPath('Desktop'); $f="$d\Instalar Emm Remote.cmd"; irm "https://raw.githubusercontent.com/xG0ta/emm-remote/main/Instalar%20Emm%20Remote%20-%20Windows.cmd" -OutFile $f; Start-Process $f
   ```
   No lo bajes desde el navegador: GitHub lo muestra como texto en vez de descargarlo.
2. Se abre la ventana del instalador.
3. Acepta el permiso de administrador.
4. Contesta si quieres acceso desatendido. Al final anota el **ID**.
   - ✅ Aparece «Firma oficial verificada», el acceso «Emm Remote» queda en el escritorio y se muestra un ID.

**Mac Intel**
1. En Finder, abre `Proyectos/emm-acceso-remoto` y dale doble clic a `Instalar Emm Remote - Mac.command`.
2. Activa RustDesk en Grabación de pantalla y en Accesibilidad cuando te lo pida. Si no aparece en la lista, agrégalo con el botón +.
3. Contesta si quieres acceso desatendido y anota el **ID**.
   - ✅ Aparece «Firma de Apple verificada» y se muestra un ID.

**Celular**: instala RustDesk desde la tienda oficial.

## 1. En casa, aceptando a mano

1. En la Mac, abre RustDesk y escribe el ID de la PC Windows en «Controlar escritorio remoto». Dale a Conectar.
2. Escribe la contraseña de un solo uso que se ve en la ventana de la PC, o acepta la conexión en la PC.
   - ✅ Ves la pantalla de Windows y puedes mover el mouse y escribir.
   - ✅ En Windows se ve la ventana de RustDesk con el nombre del equipo conectado y un botón para desconectar.
3. Haz lo mismo al revés: desde Windows, conéctate al ID de la Mac.
4. Copia texto en un equipo y pégalo en el otro. Manda un archivo con el ícono de carpeta de la barra de arriba.


## 1b. Conexión por Tailscale (la que usa Emm Remote)

Los servidores públicos de RustDesk ya no dejan conectarse sin cuenta. Por eso la conexión va por Tailscale.

1. Instala Tailscale en los dos equipos e inicia sesión con **la misma cuenta**. En Mac hay que aprobar la VPN y la extensión de sistema.
2. En el equipo que vas a controlar, abre RustDesk > Ajustes > Seguridad y activa «Habilitar acceso directo por IP».
3. Para el acceso desatendido, en ese mismo equipo pon una **contraseña permanente** fuerte.
4. En el otro equipo, escribe en RustDesk la **IP de Tailscale** del equipo controlado (`100.x.y.z`) y escribe la contraseña. Marca «Recordar contraseña» para que las siguientes veces entre con un clic.
   - ✅ Probado el 2-nov-2026: la Mac llegó a la PC por Tailscale y RustDesk pidió la contraseña, sin pasar por los servidores públicos. Falta probar la sesión completa.

## 2. Fuera de casa

1. Pon el celular en datos móviles, sin Wi‑Fi.
2. En RustDesk del celular, escribe el ID de la PC o de la Mac y conéctate.
   - ✅ Ves la pantalla y la controlas con toques. El teclado está en la barra de abajo.

## 3. Acceso desatendido (solo si lo activaste)

1. Que nadie toque la computadora controlada.
2. Desde otro equipo, conéctate a su ID y escribe la contraseña permanente que pusiste en el instalador.
   - ✅ Entra sin que alguien acepte.
   - ✅ Aun así, en la computadora controlada se ve la ventana de la sesión con el botón de desconectar.
3. En la Mac, si quieres entrar aunque no hayas iniciado sesión en ella (pantalla de inicio de sesión), RustDesk te pedirá instalar su servicio. Acéptalo.

## 4. Desconectar

1. Durante una sesión, en la computadora controlada, da clic en **Desconectar** en la ventana de RustDesk.
   - ✅ La sesión se corta al momento del otro lado.

## Qué reportar

El ✅ o ❌ de cada paso. Y cómo se siente la fluidez en casa y fuera de casa: buena, aceptable o lenta.
