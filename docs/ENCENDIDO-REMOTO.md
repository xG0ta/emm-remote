# Encender la PC desde fuera de casa (Wake-on-WAN)

El botón **Despertar** de Emm Remote manda el «paquete mágico» a dos lugares a la vez:

1. **A la red donde está la Mac.** Sirve cuando estás en casa.
2. **A la IP pública de tu casa**, al puerto que abras en el router. Sirve desde cualquier lugar.

La app aprende sola la IP pública de tu casa mientras la PC está en línea con Tailscale. También la puedes escribir tú en **Editar…**.

## Qué tiene que estar listo en la PC

- [x] Tarjeta por cable (Intel I225-V): «Activar en Magic Packet» y «Reactivar desde S5» habilitados. Ya estaba así el 2-nov-2026.
- [ ] **Quitar el inicio rápido de Windows.** Abre Inicio, da clic derecho y elige **Terminal (Administrador)**. Escribe:

  ```
  powercfg /h off
  ```

  Esto también borra el archivo de hibernación y libera varios GB en C:.
- [ ] En la BIOS: «Power On By PCI-E» (o «Wake on LAN») activado y «ErP» desactivado. Si ya encendías la PC con WoL dentro de casa, esto ya está.
- [ ] La PC conectada **por cable**. Con Wi-Fi no enciende.

## Qué hacer en el módem Infinitum (lo haces tú)

1. **Entra al módem.** Desde la PC o el celular conectado a tu casa, abre `http://192.168.1.254` en el navegador. Si no abre, prueba `http://192.168.1.1`. El usuario y la contraseña vienen en la etiqueta del módem.

2. **Reserva la IP de la PC.** Búscalo como *LAN → DHCP → Asignación estática* (o *DHCP estático*). Agrega:
   - MAC `7C:10:C9:46:49:70`
   - IP `192.168.1.158`

3. **Fija la MAC a esa IP (si tu módem lo permite).** Búscalo como *ARP estático* o *Enlace IP-MAC*, con los mismos datos. Sin esto, el módem «olvida» a la PC unos minutos después de que se apaga, y la señal deja de llegarle.

4. **Abre el puerto.** Búscalo como *Aplicación → Reenvío de puertos*, *Mapeo de puertos* o *Servidor virtual*:
   - Protocolo: **UDP**
   - Puerto externo: **9**
   - IP interna: **192.168.1.255** si la acepta (es lo mejor). Si no, **192.168.1.158**.
   - Puerto interno: **9**

5. Guarda los cambios. No hace falta reiniciar el módem: si se reinicia, puede cambiar tu IP pública.

Si tu módem no tiene el paso 3 ni acepta `.255`, el encendido por internet solo funcionará los primeros minutos después de apagar la PC. En ese caso, la alternativa confiable es un aparato siempre encendido en casa, como un celular viejo o una Raspberry Pi con Tailscale.

## Cómo probarlo

Pruébalo la primera vez con alguien en casa, por si no prende.

1. Abre Emm Remote con la PC encendida y espera unos segundos. En la tarjeta de «PC Casa» debe aparecer «casa 187.x.x.x».
2. Apaga la PC desde Inicio → Apagar.
3. Espera 5 minutos, para comprobar que el módem no la «olvida».
4. Desde **otra red** (por ejemplo, los datos del celular compartidos a la Mac), pulsa **Despertar**.
5. En 1 o 2 minutos la tarjeta debe pasar a «En línea».

## Seguridad

- El puerto abierto solo deja pasar el paquete que **enciende** la PC. No permite entrar a ella ni ver nada.
- Para controlar la PC sigue haciendo falta Tailscale y la contraseña de RustDesk.
- Lo peor que puede pasar es que alguien que sepa tu IP, el puerto y la MAC encienda tu PC.

## Limitaciones

- Si se va la luz en casa, la PC queda apagada. Al volver la luz, la tarjeta puede no quedar lista para WoL hasta que la PC se encienda una vez. Algunas BIOS tienen la opción «Restore on AC power loss» para que encienda sola al volver la luz.
- Si tu IP pública cambia mientras la PC está apagada (por ejemplo, porque se reinició el módem), la app no conoce la nueva. Para evitarlo hay servicios gratuitos de DDNS (como Duck DNS), que dan un nombre que siempre apunta a tu casa. Ese nombre se escribe en «IP pública de su casa».
