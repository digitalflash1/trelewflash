# Archivos que la tienda NO usa

`index.html` no carga ninguno de estos tres archivos. Quedaron acá cuando se armó
el demo, porque pertenecen a las pantallas que no se incluyeron en esta carpeta
(`admin.html`, `fotografos.html`, `precios-admin.html`, `galeria-evento.html`).

| Archivo | Para qué era | Ojo |
|---|---|---|
| `theme.css` | Estilos compartidos de los paneles de administración y la galería. | La tienda tiene todo su CSS embebido en `index.html`. |
| `data.js` | Catálogo + datos de ejemplo (fotógrafos, pedidos, ventas) para navegar los paneles sin backend. | Tiene el **catálogo v1**, desactualizado. |
| `catalogo_precios.json` | Catálogo maestro v1. | Reemplazado por `CATALOGO_V2`, embebido en `index.html` y espejado en la pestaña `Catalogo` de la hoja. |

**Importante:** editar los precios acá **no cambia nada** en la tienda. Los precios
vivos salen de la pestaña `Catalogo` de la hoja de pedidos (o, si la hoja no
responde, del catálogo embebido en `index.html`).

Se movieron a esta subcarpeta en vez de borrarlos por si más adelante traés los
paneles o la galería a esta misma carpeta: en ese caso, subilos un nivel
(a `assets/`) y actualizá `data.js` al catálogo v2.
