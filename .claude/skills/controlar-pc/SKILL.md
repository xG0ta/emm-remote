---
name: controlar-pc
description: Ver y controlar la PC Windows de la casa del usuario desde la Mac (Emm Remote/RustDesk, o AnyDesk de respaldo) cuando el usuario lo pida. Úsalo con frases como "entra a mi PC", "controla mi PC", "revisa algo en la PC de la casa".
---

# Controlar la PC de la casa

Solo cuando el usuario lo pida en el chat. Los IDs están en el `CLAUDE.md` local de este proyecto, que no se sube a Git.

1. Pide acceso con `request_access` a **RustDesk** (Emm Remote) y, de respaldo, a **AnyDesk**. Es una vez por sesión: macOS y la app de Claude piden ese permiso y no se puede saltar.
2. Conéctate:
   - **Emm Remote (RustDesk):** abre RustDesk y entra a la PC desde Favoritos o Recientes con un clic. La contraseña la guarda RustDesk («Recordar contraseña»), así que no tienes que escribirla.
   - **Respaldo con AnyDesk:** en Favoritos, doble clic en la PC. Usa el token guardado de AnyDesk, sin contraseña.
3. AnyDesk no deja verse con las herramientas de segundo plano (`app_*`): no reporta ventanas. Para AnyDesk hace falta control de pantalla completa (`request_full_control`).
4. **Nunca escribas contraseñas.** Si una conexión pide contraseña o iniciar sesión, detente y pídele al usuario que la escriba él.
5. Al terminar, desconecta la sesión y libera el control (`release_full_control`, `app_release`).
6. Dile al usuario qué hiciste en la PC y qué dejaste abierto.
