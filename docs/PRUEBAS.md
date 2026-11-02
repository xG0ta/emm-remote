# Pruebas de Emm Remote (versión 0.1)

La prueba se hace entre la Mac Intel y la laptop Windows. Ve marcando cada paso.

## 0. Preparar las dos computadoras

**Windows** (PowerShell como administrador, desde la carpeta del repo):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\instalar-emm-remote.ps1
```

**Mac**: doble clic en `scripts/mac/instalar-emm-remote.command`. Si macOS no te deja abrirlo, córrelo en Terminal:

```bash
bash scripts/mac/instalar-emm-remote.command
```

En la Mac, activa RustDesk en **Ajustes del Sistema > Privacidad y seguridad > Grabación de pantalla** y también en **Accesibilidad**. Luego cierra RustDesk y vuelve a abrirlo.

Al final, cada script imprime la **IP en la red de casa** y la **IP de Tailscale** (empieza con `100.`). Anótalas.

## 1. Casa, con aceptación manual (lo mínimo)

1. Las dos computadoras deben estar en el mismo Wi‑Fi.
2. En la Mac, abre RustDesk y escribe en «Controlar escritorio remoto» la **IP de casa** de la PC Windows, por ejemplo `192.168.1.70`. Dale a Conectar.
3. En Windows aparece la ventana de RustDesk que pide aceptar la conexión. Acéptala.
   - ✅ Debes ver la pantalla de Windows en la Mac y poder mover el mouse y escribir.
   - ✅ Mientras dure la sesión, Windows debe mostrar la ventana de RustDesk con el nombre del equipo conectado y un botón para desconectar.
4. Haz la prueba al revés: desde Windows, conéctate a la IP de casa de la Mac.
5. Prueba también copiar y pegar texto entre las dos y mandar un archivo (ícono de carpeta en la barra de arriba).

Si no conecta: revisa que «Habilitar acceso directo por IP» esté activo en **Ajustes > Seguridad** de la computadora a la que te conectas.

## 2. Bloqueo de IP desconocidas

1. En la computadora controlada, abre **Ajustes > Seguridad > Lista blanca de IP**. Debe decir `100.64.0.0/10,fd7a:115c:a1e0::/48,192.168.0.0/16`.
2. Si quieres comprobar que funciona, borra temporalmente `192.168.0.0/16` e intenta conectarte por la IP de casa.
   - ✅ Debe salir «Your ip is blocked by the peer». Al terminar, vuelve a dejar la lista completa.

## 3. Fuera de casa (Tailscale)

1. Inicia sesión en Tailscale con **la misma cuenta** en la Mac, en Windows y en el celular.
2. Repite la prueba 1 usando la **IP de Tailscale** (`100.x.y.z`) en vez de la de casa.
3. Prueba real: conecta el celular a datos móviles (sin Wi‑Fi) o pide prestado otro internet, y conéctate desde ahí.
   - ✅ Debe conectarse aunque tu Infinitum esté detrás de CGNAT. Tailscale lo atraviesa por su cuenta.

## 4. Desde el celular

1. Instala en el celular **RustDesk** y **Tailscale**, las dos desde la tienda oficial.
2. Enciende Tailscale en el celular.
3. En RustDesk, escribe la IP de Tailscale de la PC o de la Mac y conéctate.
   - ✅ Debes ver la pantalla y controlarla con toques. El teclado está en la barra de abajo.

## 5. Acceso desatendido (opcional, configúralo en cada equipo)

Solo hazlo en los equipos que quieras controlar sin que nadie acepte.

1. En ese equipo, abre RustDesk > **Ajustes > Seguridad > Contraseña**:
   - Elige «Usar contraseña permanente» y pon una contraseña **fuerte y única**, de 16 caracteres o más. Guárdala en tu gestor de contraseñas o en el llavero.
   - En «Aceptar sesiones», elige «Por contraseña».
2. Deja **apagada** cualquier opción para ocultar la ventana de conexión (por ejemplo «Ocultar ventana de gestión de conexiones»). La ventana debe verse siempre durante una sesión.
3. Para entrar a la Mac aunque no hayas iniciado sesión en ella, en RustDesk de la Mac dale a **Instalar/Iniciar servicio** cuando lo ofrezca.
   - ✅ Desde el otro equipo, la conexión entra pidiendo la contraseña, sin que alguien acepte.
   - ✅ Del lado controlado, la ventana de RustDesk sigue mostrando que hay una sesión.

> Dónde queda guardada la contraseña: RustDesk la cifra y la guarda en su archivo de configuración, en ese equipo. No usa el llavero de Mac ni el Administrador de credenciales de Windows, y este repo nunca la ve. La protegen la lista blanca (solo Tailscale y tu red de casa) y tu cuenta de Tailscale. Activa la verificación en dos pasos en esa cuenta.

## Qué reportar

Para cada prueba: ✅ o ❌ y, si falla, una captura del mensaje. También dime cómo se siente la fluidez: buena, aceptable o lenta.
