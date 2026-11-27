[English](README.en.md) | [العربية](README.ar.md) | [فارسی](README.fa.md) | [中文](README.zh.md) | **Español** | [Русский](README.md) | [Türkçe](README.tr.md)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="media/logo-dark.svg">
    <img src="media/logo-light.svg" alt="X-Fleet" width="420">
  </picture>
</p>

# X-Fleet — instalación

Aquí están las versiones listas de X-Fleet (pestaña **Releases**): el programa para Linux (amd64, arm64),
el instalador `install.sh` y las sumas de comprobación `SHA256SUMS`. Abajo se explica cómo instalarlo.

X-Fleet es un panel para gestionar una VPN Xray en muchos servidores a la vez. Se instala con un solo comando,
sin Docker y sin base de datos aparte.

> El instalador y la interfaz del panel están disponibles en **inglés** y **ruso**. Abajo, los nombres de los menús y botones se dan en inglés, tal como aparecen en el panel.

## Requisitos

- Un servidor (VPS) con **Ubuntu 22.04+** o **Debian 12+**, procesador amd64 o arm64.
- Acceso **root** por SSH.
- Preferiblemente un dominio propio (por ejemplo `panel.example.com`) con un registro A hacia la IP del servidor.
  Sin dominio también funciona: el panel usará un nombre gratuito como `1-2-3-4.sslip.io`.
- Puertos abiertos en el proveedor (en su panel de control, si tiene su propio cortafuegos):

| Puerto | Para qué |
|---|---|
| 80 | Let's Encrypt comprueba el dominio para emitir el certificado |
| aleatorio (lo muestra el instalador) | acceso al panel |
| 8444 | los nodos se conectan al panel |
| 2096 | enlaces de suscripción para los clientes |
| 443 y 8443 | la propia VPN (si este servidor también da VPN) |

Si `ufw` está activo en el servidor, el instalador abre en él los puertos necesarios.

## 1. Instalar el panel

Entre al servidor como root y ejecute:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh)
```

Se abre un asistente que hace preguntas paso a paso. Si no está seguro, pulse Enter: se elige la opción por defecto.

1. **Idioma:** ruso o inglés.
2. **Comprobación del sistema y paquetes.** El instalador ofrece actualizar el sistema (`apt upgrade`).
   En un servidor que ya ejecuta algo, puede rechazarlo.
3. **Dirección y HTTPS.** Escriba su dominio o elija la opción sin dominio (sslip.io).
   El panel obtiene el certificado de Let's Encrypt por sí mismo.
4. **Ajustes del panel.** El puerto, la ruta secreta y el usuario se eligen al azar; la contraseña se genera sola.
5. **VPN en este servidor.** Puede convertir este mismo servidor en el primer nodo:
   - VLESS Reality XHTTP en el puerto 443 (conexión principal);
   - TCP + Vision en el puerto 8443 (de reserva).

   Aquí también se elige el sitio de camuflaje y se crea el primer usuario.
6. **Arranque y comprobación.** Los servicios se inician y vuelven a arrancar solos tras reiniciar el servidor.

Al final se muestran la **dirección del panel, el usuario y la contraseña**, y el código QR de suscripción del primer usuario.
Los datos de acceso se guardan en `/root/x-fleet-admin.txt`. Para verlos otra vez:

```bash
cat /root/x-fleet-admin.txt
```

### Instalación sin preguntas

Añada `--yes` y todo se elegirá por defecto. Los demás parámetros se pueden indicar directamente:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --yes --domain panel.example.com
```

| Parámetro | Qué hace |
|---|---|
| `--lang ru\|en` | idioma del instalador y del menú |
| `--domain panel.example.com` | dominio propio para el panel y las suscripciones |
| `--https le\|ip\|self\|none` | HTTPS: dominio propio / sin dominio (sslip.io) / autofirmado / sin HTTPS (solo por túnel SSH) |
| `--cert archivo --key archivo` | su propio certificado en lugar de Let's Encrypt |
| `--email you@example.com` | correo para los avisos de Let's Encrypt |
| `--port 31234` | puerto del panel (aleatorio por defecto) |
| `--login nombre` | usuario del administrador (aleatorio por defecto) |
| `--connections rec\|xhttp\|vision\|none` | VPN en este servidor: ambas conexiones / solo XHTTP / solo Vision / ninguna |
| `--mask neighbor\|self\|<sitio>` | camuflaje Reality: sitio vecino de la subred / sitio propio en el servidor / el sitio indicado |
| `--user nombre` | primer usuario (por defecto `user`) |
| `--name nombre` | nombre del servidor en las apps de los clientes, en letras latinas |
| `--upgrade` / `--no-upgrade` | actualizar el sistema o no |
| `--bbr` / `--no-bbr` | activar la aceleración TCP (BBR) o no; se activa por defecto |
| `--version v0.7.1` | instalar una versión concreta |

Ayuda completa de los parámetros:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --help
```

## 2. Primer acceso

1. Abra en el navegador la dirección que mostró el instalador, por ejemplo
   `https://panel.example.com:31234/AbCdEf123/`.
   La dirección es secreta: sin la ruta correcta el panel no se abre y los escáneres no lo encuentran.
2. Entre con el usuario y la contraseña de `/root/x-fleet-admin.txt`.
3. Recomendamos hacer enseguida:
   - **Settings → Security**: cambiar la contraseña y activar el acceso en dos pasos;
   - **Settings → Notifications**: conectar Telegram para enterarse de los fallos;
   - **Settings → System**: activar las copias de seguridad programadas.

## 3. Añadir nodos (otros servidores VPN)

Un **nodo** es un servidor a través del cual los clientes se conectan a la VPN. El panel gestiona los nodos a distancia.
Cada nodo nuevo necesita un **comando de instalación**. Lo genera el propio panel, no está en GitHub:
el comando contiene la dirección de su panel y una clave de un solo uso.

### Paso 1. Obtener el comando en el panel

1. Abra el panel en el navegador y entre.
2. En el menú de la izquierda elija **Nodes**.
3. Pulse el botón azul **Add node** (arriba a la derecha).
4. Rellene el formulario:

   | Campo | Qué escribir |
   |---|---|
   | **Name** | cualquier nombre claro en letras latinas, por ejemplo `amsterdam-1` |
   | **Address (IP or domain)** | la IP del servidor nuevo, por ejemplo `203.0.113.10`. Los clientes la verán en la suscripción |
   | **Node domain (for camouflage)** | puede quedar vacío. Si tiene un dominio con registro A hacia la IP de este servidor, escríbalo, por ejemplo `nl1.example.com` |
   | **Country** y **City** | pueden quedar vacíos: el panel los detecta por la IP. Los clientes verán, por ejemplo, `🇳🇱 Netherlands, Amsterdam` |
   | **Add inbounds from templates right away** | déjelo marcado: las conexiones del nodo se crean solas |

5. Pulse **Create**.
6. Se abre la ventana **Install node** con un comando largo. Empieza por `curl -fsSL https://…/node.sh | bash -s -- …`.
   Pulse el icono de **copiar** a la derecha del comando.

El comando se parece a esto (su dirección, token y huella serán otros):

```text
curl -fsSL https://panel.example.com:2096/install/Ab12Cd/node.sh | bash -s -- --panel panel.example.com:8444 --token 7f3a… --pin 9c1e…
```

> **Importante:** el comando es de un solo uso y vale **15 minutos** (la hora de caducidad aparece en la ventana).
> ¿No le dio tiempo o cerró la ventana? Abra **Nodes** → pulse sobre el nodo → **New install token**,
> y aparecerá un comando nuevo.

**Otra forma: desde el servidor del panel.** Entre por SSH al servidor donde está el panel y ejecute:

```bash
x-fleet node-cmd
```

El programa pide el nombre del nodo, su IP y su dominio (Enter: sin dominio) e imprime el comando listo. Vale 30 minutos.

### Paso 2. Ejecutar el comando en el servidor nuevo

1. Entre por SSH al **servidor nuevo** (el futuro nodo, no el servidor del panel) como root:
   ```bash
   ssh root@203.0.113.10
   ```
2. Pegue el comando copiado (en la terminal: clic derecho o Ctrl+Shift+V / Cmd+V) y pulse Enter.
3. Espere 1–2 minutos. El nodo por sí solo:
   - descarga el programa de su panel y comprueba la suma de comprobación;
   - se conecta al panel por un canal seguro;
   - descarga y arranca Xray.

### Paso 3. Comprobar

Vuelva al panel → **Nodes**. En unos segundos el nodo nuevo tendrá estado verde.
Las conexiones de las plantillas ya están creadas. El nodo aparecerá en las suscripciones de los usuarios de su grupo
(sección **Squads**). No hace falta cambiar el enlace de suscripción: la app recibe el servidor nuevo al actualizar la suscripción.

### Si no funcionó

- **«install token expired»:** obtenga un comando nuevo: página del nodo → **New install token**.
- **El nodo no se conecta al panel:** en el servidor del panel debe estar abierto el puerto **8444**
  (y el **2096**, desde él se descarga el programa). Revise el cortafuegos del proveedor.
- **En el servidor nuevo ya funciona otra VPN** (por ejemplo 3x-ui) y los puertos 443/8443 están ocupados: el instalador se detiene
  y muestra qué programa ocupa el puerto. Así la VPN anterior no se rompe. Libere los puertos o asigne a este nodo
  otros puertos en el panel.
- **El nodo es el propio servidor del panel:** no hay que instalar nada, el asistente del panel lo ofrece desde el principio (paso «VPN en este servidor»).

## 4. Usuarios y suscripciones

**Users** → **New user**. Cada usuario tiene un enlace de suscripción que se añade a la app.
La página de suscripción muestra un código QR y botones para las apps.

### Apps para los clientes

| App | Cómo añadir la suscripción |
|---|---|
| **NOX** (recomendada, Android 7+) | [descargar NOX.apk](https://github.com/richdodcom-pixel/nox-updates/releases/latest/download/NOX.apk). El botón **NOX** de la página de suscripción abre la app y añade la suscripción |
| Happ, Hiddify, INCY, v2RayTun, Streisand, v2rayNG, Clash Verge / FlClash | el botón de la app en la página de suscripción (o pegar el enlace de suscripción en la app) |
| sing-box y otros clientes Clash / Mihomo | pegar el enlace de suscripción: el panel entrega el formato adecuado |

## Gestión desde el servidor: el comando `x-fleet`

Escriba `x-fleet` en el servidor y se abrirá el menú. Comandos rápidos:

| Comando | Qué hace |
|---|---|
| `x-fleet url` | mostrar la dirección del panel y el usuario |
| `x-fleet password` | nueva contraseña del administrador |
| `x-fleet 2fa off` | desactivar el acceso en dos pasos (si perdió el teléfono) |
| `x-fleet status` | estado de los servicios |
| `x-fleet restart` | reiniciar los servicios |
| `x-fleet log` | registro |
| `x-fleet port 31234` | cambiar el puerto del panel |
| `x-fleet path` | nueva ruta secreta del panel |
| `x-fleet https` | certificado del panel |
| `x-fleet update` | actualizar X-Fleet |
| `x-fleet backup` | copia de seguridad ahora |
| `x-fleet check` | comprobación del servidor |
| `x-fleet link nombre` | enlace de suscripción de un usuario con código QR |
| `x-fleet node-cmd` | comando de instalación de un nodo nuevo |

## Actualización

- **Panel:** **Settings → System → Panel update**. O en el servidor: `x-fleet update`.
  La versión anterior se guarda para poder volver atrás.
- **Nodos:** **Settings → Cores**: actualizar Xray y los agentes en todos los nodos a la vez.
  O uno a uno en la página del nodo. **Settings → System → Update all servers** actualiza todos los nodos con un clic.

## Cambiar la dirección o el dominio del panel

**Settings → Network & certificates**. Aquí se cambian el puerto, la ruta secreta y el certificado
(dominio propio, sslip.io o autofirmado).

- El panel obtiene el certificado del dominio nuevo **antes** de cambiar. Si Let's Encrypt lo rechaza, no cambia nada
  y en pantalla aparece el motivo.
- Tras el cambio, abra el panel en la dirección nueva y entre **en menos de 10 minutos**. Si no, vuelven solos los ajustes anteriores
  y no se pierde el acceso.

## Si algo no funciona

- **No se emite el certificado:**
  - compruebe que el registro A del dominio apunta a la IP del servidor y que en Cloudflare la nube está en gris (solo DNS);
  - compruebe que el puerto 80 está abierto en el proveedor;
  - Let's Encrypt emite como máximo 5 certificados por nombre a la semana. Si reinstala a menudo, espere
    o elija temporalmente la opción sin dominio (sslip.io).
- **Olvidó la dirección o la contraseña:** entre al servidor y ejecute `x-fleet url` o `x-fleet password`.
- **Comprobación general:** `x-fleet check`.

## Desinstalación

```bash
x-fleet uninstall
```

El comando detiene los servicios y borra el programa, los ajustes y los datos. Las copias de seguridad se quedan en `/var/lib/x-fleet/backups`.

---

## Para quien actualiza desde versiones antiguas (nodepanel)

Antes de v0.5.0 el programa se llamaba `nodepanel`. Al actualizar con el botón, todo pasa a los nombres nuevos por sí solo:

| Antes | Ahora |
|---|---|
| `/usr/local/bin/nodepanel` | `/usr/local/bin/x-fleet` (el nombre antiguo queda como enlace) |
| servicios `nodepanel-panel`, `nodepanel-node` | `x-fleet-panel`, `x-fleet-node` |
| `/etc/nodepanel`, `/var/lib/nodepanel`, `/var/lib/nodepanel-node` | `/etc/x-fleet`, `/var/lib/x-fleet`, `/var/lib/x-fleet-node` |
| `/root/nodepanel-admin.txt` | `/root/x-fleet-admin.txt` |

Si el servicio nuevo no arranca, todo vuelve a como estaba. Para repetirlo a mano: `x-fleet migrate`;
registro de la migración: `journalctl -u x-fleet-migrate`.

## Apoyar el proyecto

X-Fleet es gratuito y lo desarrolla una sola persona en su tiempo libre. Si el panel le resulta útil,
puede apoyar su desarrollo con cualquier cantidad. Es voluntario: todas las funciones son gratuitas.

| Moneda | Red | Dirección |
|---|---|---|
| USDT | **TRON (TRC20)** | `TYWjc2oNwm32wcQUX5cDjQ2vWCCLuS1vkH` |
| TON | **TON** | `UQB6Fryf-lEQXMGQlOIdHu5QTk_lcOgeKL0m424k92hbiWhw` |

> ⚠️ Envíe monedas solo por la red indicada: las transferencias desde otras redes se perderán.
> Los códigos QR de estas direcciones están en el propio panel: el apartado **Support** del menú.

¡Gracias! 💙
