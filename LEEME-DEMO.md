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
| `assets/` | Estilos, datos y recursos (`theme.css`, `data.js`, `catalogo_precios.json`, `taza-magica.gif`). |
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

3. **Aviso del comprobante de transferencia.** Antes de tocar el botón que abre
   WhatsApp, el cliente ve un recuadro que le indica que debe **enviar el comprobante
   de la transferencia** por WhatsApp para que el pedido **pase a revelar / hacer**;
   sin comprobante, el pedido queda pendiente. El mismo recordatorio va incluido en el
   texto del mensaje. Se controla en el modal `#modal-pedido` (recuadro naranja) y en
   `mensajePedido()`.

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
