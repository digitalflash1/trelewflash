# Foto Trelew Flash — Versión DEMO (v4.3)

Copia de la app pensada para **mostrar a clientes**. Contiene solo los archivos
actualizados de la v4.3, con algunas funciones deshabilitadas a propósito hasta
que estén terminadas.

---

## Qué hay en esta carpeta

| Archivo | Qué es |
|---|---|
| `index.html` | **La tienda pública** (antes `foto-trelew-flash-v4.3.html`). Es la portada del demo: el cliente entra directo a armar su pedido. |
| `galeria-evento.html` | Prototipo de galería de fotos de eventos sociales (demo aparte, no enlazado desde la portada). |
| `assets/` | Recursos de la tienda. Imágenes del carrusel (cada una en `.webp` liviana + `.jpg` de respaldo): `bienvenida`, `set-jardin`, `taza-caja`, `remera`. Animación `taza-magica.webp` (+ `taza-magica.gif` original de respaldo). Más: `og-image.jpg` (vista previa al compartir el link), `favicon.ico` y `apple-touch-icon.png`. |
| `assets/_sin-uso/` | `theme.css`, `data.js` y `catalogo_precios.json`: **no los usa `index.html`** (son de los paneles y la galería, y traen el catálogo v1 desactualizado). Ver el LEEME de esa subcarpeta. |
| `apps-script-pedidos-v2.gs` | Backend para Google Apps Script (registra pedidos, guarda imágenes en Drive y sirve el catálogo). **Se despliega en la cuenta Google de la empresa.** |
| `README-despliegue-v4_3.md` | Guía técnica de despliegue del backend y estructura de la hoja de cálculo. |
| `CONECTAR-HOJA.md` | Guía paso a paso para conectar la app con la hoja de Google. |
| `LEEME-DEMO.md` | Este documento. |

---

## Qué está DESHABILITADO en el demo (y cómo reactivarlo)

Todo se deshabilitó **comentando** el código (no se borró), así que reactivar es
quitar el comentario. Buscá la palabra `DEMO:` en `index.html`.

1. **Catálogo de cuadros** — botón "🖼️ Ver catálogo de cuadros" de la pantalla de inicio.
2. **Zona administrativa** — link del pie de página que llevaba al panel de precios (`precios-admin.html`, no incluido en el demo).
3. **Paneles de administradores y fotógrafos** — no se incluyeron en esta carpeta
   (`admin.html`, `fotografos.html`, `precios-admin.html` siguen en la carpeta original
   del proyecto para seguir trabajándolos).

---

## Comportamientos específicos del demo

1. **Galería de eventos → WordPress.** `galeria-evento.html` ya no es un prototipo:
   **redirige automáticamente** a `https://digitalflashtw.wordpress.com/eventos/`
   (redirección por `meta refresh` + JavaScript, con link de respaldo). El botón
   "🥳 Ver fotos de eventos sociales" de la portada también apunta a ese mismo link.

2. **Mensaje de WhatsApp sin enlace a Drive.** El texto que se arma para WhatsApp
   incluye **solo el N° de pedido, el detalle de los ítems y el total**. El enlace a
   la carpeta de Drive **queda oculto para el cliente** aunque el backend lo devuelva
   (la carpeta se sigue creando: la ves vos desde la hoja de pedidos, no el cliente).
   Se controla en la función `mensajePedido()` de `index.html` (buscá el comentario
   `DEMO:` sobre la carpeta de Drive).

   Como el cliente no ve ese link, las carpetas de Drive se crean **privadas**
   (solo las abrís vos con la cuenta de la empresa). Si algún día volvés a mostrarle
   la carpeta al cliente, hay que reactivar la línea `setSharing(...)` que quedó
   comentada en `apps-script-pedidos-v2.gs`, o el link no le va a abrir.

3. **Aviso del comprobante de transferencia.** Antes de tocar el botón que abre
   WhatsApp, el cliente ve un recuadro que le indica que debe **enviar el comprobante
   de la transferencia** por WhatsApp para que el pedido **pase a revelar / hacer**;
   sin comprobante, el pedido queda pendiente. El mismo recordatorio va incluido en el
   texto del mensaje. Se controla en el modal `#modal-pedido` (recuadro naranja) y en
   `mensajePedido()`.

---

## Google Tag Manager

Contenedor **`GTM-K9M24PKG`** instalado en `index.html`: el `<script>` va arriba de
todo en el `<head>` y el `<noscript>` justo después de `<body>`, como pide Google.
Para cambiar el contenedor, reemplazá ese ID en **los dos** lugares.

### Eventos que ya se envían

La tienda es una **sola página** (las pantallas son `<div>` que se muestran y
ocultan), así que GTM por sí solo contaría **una visita** por cliente. Por eso la
app avisa cada paso con la función `medir()` (buscá `function medir` en `index.html`):

| Evento | Cuándo | Datos que trae |
|---|---|---|
| `pantalla_vista` | Cada cambio de pantalla | `pantalla` (nombre legible), `pantalla_id`, `items_carrito` |
| `agregar_al_carrito` | Al agregar cualquier producto | `producto`, `variante`, `cantidad`, `fotos_adjuntas`, `valor` |
| `iniciar_checkout` | Al entrar al carrito con ítems | `valor`, `items` |
| `pedido_enviado` | Al registrar el pedido | `valor`, `items`, `fotos`, `estado`, `imagenes_omitidas` |
| `clic_whatsapp` | Al tocar "Abrir WhatsApp" | `valor`, `items`, `estado` |
| `consentimiento_cookies` | Al elegir en el cartel | `decision` |

**Para usarlos en GTM:** Activador → *Evento personalizado* → nombre del evento.
Los datos extra quedan disponibles como *Variables de capa de datos*.

Dos detalles que valen la pena:

- **`clic_whatsapp` es la conversión de verdad.** Que un pedido se registre no
  significa que el cliente haya escrito: puede cerrar la pantalla sin tocar el
  botón. La diferencia entre `pedido_enviado` y `clic_whatsapp` son pedidos perdidos.
- **`estado`** distingue un pedido guardado en la hoja (`ok`) de uno que falló
  (`error`). Si ves muchos `error`, el problema es el backend, no la tienda.

**No se envía ningún dato personal:** ni nombre, ni teléfono, ni email, ni fotos.

### Aviso de cookies

Cartel abajo de todo con **Aceptar / Rechazar**. Usa **Consent Mode v2**: el
consentimiento arranca en `denied` en el `<head>` (antes de que cargue GTM), así
que **no se escriben cookies de estadística hasta que el cliente acepta**.
Rechazar no otorga ningún permiso. La elección se guarda en `localStorage`
(`tf_cookies`) y el cartel no vuelve a aparecer.

Para que el cliente pueda cambiar de opinión, alcanza con borrar esa clave:

```js
localStorage.removeItem('tf_cookies');
```

## Redes sociales

En el pie de página (visible en **todas** las pantallas) están los botones de
Instagram y Facebook:

| Red | Cuenta |
|---|---|
| Instagram | [@fotoflashtw](https://www.instagram.com/fotoflashtw/) |
| Facebook | [FOTO FLASH TW](https://www.facebook.com/people/FOTO-FLASH-TW/61571162657400/) |

Para cambiar un link, editá el `href` dentro de `<div class="pie-redes">` en el
`<footer>` de `index.html`. Los íconos son **SVG embebidos** (no se descargan de
ningún lado), así que cargan al instante. Si más adelante sumás otra red, copiá
uno de los `<a>` y agregá su color en la clase `.pie-redes .red-XX` del CSS.

## Imágenes del carrusel de inicio

El carrusel usa proporción **16:9** (`aspect-ratio` en `.carrusel`), así que las
imágenes se muestran **completas, sin recortar**. Para que entren bien:

- **Proporción ~16:9** (más anchas que altas). Las actuales son 800–900 px de ancho.
- **Ancho recomendado: 800–1000 px** (no hace falta más; solo pesaría de más).
- **Formato: `.webp` de calidad 82** como principal + **`.jpg`** del mismo tamaño
  como respaldo para navegadores viejos. Un PNG de celular de ~2 MB queda en ~40–100 KB.

Cada tarjeta se define en el arreglo `NOVEDADES` (buscá `const NOVEDADES` en
`index.html`). Si la imagen **ya trae texto adentro** (los banners promocionales),
la tarjeta va **sin** `titulo`/`texto` para no encimar texto sobre texto. Si es una
foto **sin** texto (como `bienvenida`), sí lleva `titulo`/`texto`, que aparecen sobre
un **recuadro de color** (`.nov-cap`) para que se lean bien.

## Fotos que adjunta el cliente

Las fotos se **achican antes de enviarse** al backend: una foto de celular pesa
4–8 MB y en base64 un 33% más, así que con 4 o 5 el envío fallaba y el pedido
quedaba sin registrar (en silencio). Constantes al inicio de la sección
"7) ADJUNTOS" de `index.html`:

| Constante | Valor | Qué hace |
|---|---|---|
| `MAX_LADO_FOTO` | `2000` | Piso de resolución (lado mayor en píxeles). |
| `DPI_OBJETIVO` | `240` | Calidad de impresión buscada para calcular el lado según la medida. |
| `MAX_LADO_FOTO_TOPE` | `4000` | Techo: ni las medidas enormes piden más que esto. |
| `CALIDAD_FOTO` | `0.85` | Calidad del JPEG. |
| `MAX_FOTOS_ITEM` | `20` | Tope de fotos por producto (avisa al cliente). |
| `MAX_POST_MB` | `18` | Si el pedido supera esto, se registra **sin imágenes** antes que perderse. |

**La resolución se adapta a la medida pedida.** Al adjuntar, la foto se prepara en
2000 px (rápido). Cuando el cliente agrega el ítem al carrito, `ladoParaMedida()`
calcula los píxeles que necesita esa medida a 240 dpi y, si hace falta más, la foto
**se rehace desde el archivo original**. Los centímetros salen del nombre de la
variante ("20x30 cm"), así que si agregás medidas al catálogo se ajusta sola:

| Medida | Píxeles enviados | Calidad |
|---|---|---|
| 10x15 | 2000 | 338 dpi |
| 13x18 | 2000 | 282 dpi |
| 15x21 | 2000 | 242 dpi |
| 20x30 | 2835 | 240 dpi |
| 30x40 | 3780 | 240 dpi |

Una foto que el cliente **recortó a mano** no se rehace (perdería el recorte): queda
con la resolución que tenía.

## Qué se le pide al cliente por WhatsApp

Las fotos **ya viajan solas a tu Drive** con el pedido, así que el mensaje solo se
las pide cuando de verdad hacen falta:

| Situación | Texto del mensaje |
|---|---|
| Pedido registrado con sus fotos | "Ya subí N imágenes junto con el pedido." |
| Falló el registro, o el pedido era muy pesado, o no hay backend | "Te mando N imágenes por este chat." |

**Si el registro falla**, además, el cliente ve un recuadro naranja avisándole que el
pedido no se guardó pero que el detalle viaja completo en el mensaje, y el texto lleva
la marca `⚠️ (Este pedido no se pudo registrar solo en el sistema)` para que sepas que
hay que cargarlo a mano. Antes, un backend caído se veía igual que un envío exitoso.

---

## Backend: conectar con la cuenta Google de la EMPRESA

El demo viene **desconectado del backend** a propósito. Mientras `PEDIDOS_URL`
esté vacío, la app funciona en **modo local**: usa el catálogo embebido y el pedido
se arma y se manda por WhatsApp, pero **no** se registra en una hoja ni sube imágenes
a Drive.

Para conectarlo con la empresa:

1. Iniciá sesión con la **cuenta Google de la empresa**.
2. Creá (o abrí) la hoja de cálculo de pedidos → **Extensiones → Apps Script**.
3. Pegá el contenido de `apps-script-pedidos-v2.gs`, ejecutá `setup()` una vez y
   autorizá los permisos. (Detalle completo en `README-despliegue-v4_3.md`.)
4. **Implementar → Nueva implementación → App web**, acceso "Cualquier persona".
   Copiá la URL que termina en `/exec`.
5. En `index.html`, buscá la línea marcada con `⚙️ BACKEND` (cerca del inicio del
   `<script>`) y pegá esa URL:

   ```js
   const PEDIDOS_URL = "https://script.google.com/macros/s/XXXXX/exec";
   ```

6. Listo: desde ese momento los pedidos se registran en la hoja de la empresa.

> El número de WhatsApp está en la constante `TELEFONO_WA` (misma zona del código),
> por si hay que cambiarlo por el de la empresa.

---

## Publicar en GitHub Pages (cuenta de la empresa)

1. Creá la cuenta/organización de GitHub de la empresa.
2. Creá un repositorio nuevo (por ejemplo `foto-trelew-flash`) y subí **el contenido
   de esta carpeta** (que `index.html` quede en la raíz del repo).
3. En el repo: **Settings → Pages → Build and deployment → Source: "Deploy from a branch"**,
   rama `main`, carpeta `/ (root)` → **Save**.
4. A los pocos minutos el sitio queda publicado en
   `https://<usuario-empresa>.github.io/<repo>/`.
   Ese es el link que compartís con los clientes.

> GitHub Pages sirve `index.html` automáticamente como portada, por eso la tienda
> se renombró a `index.html`.

Podés conectar el backend (paso anterior) antes o después de publicar: alcanza con
editar `index.html` y volver a subir el archivo.
