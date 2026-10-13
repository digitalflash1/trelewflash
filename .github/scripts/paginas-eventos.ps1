# Arma e/<id>/index.html para cada evento: la página que leen Facebook y
# WhatsApp para la vista previa (ver .github/workflows/paginas-eventos.yml)
# y que Google indexa, con su contenido y enlaces a otros eventos. Arma
# también e/index.html (todos los eventos por mes) y sitemap.xml (home,
# e/ y una entrada por evento) en la raíz del repo.
# Antes estas páginas saltaban solas a la tienda y Google las descartaba
# como «Página con redirección»: ahora solo saltan con #fotos, que es como
# las comparte la tienda.
# Anda en Windows PowerShell 5.1 y en pwsh 7.
#   paginas-eventos.ps1 <eventos.json> e (solo se permite la carpeta e del repo)
param(
    [Parameter(Mandatory = $true)][string]$Json,
    [Parameter(Mandatory = $true)][string]$Salida
)
$ErrorActionPreference = "Stop"
$sitio = "https://trelewflash.com.ar/"
$meses = "enero","febrero","marzo","abril","mayo","junio","julio",
         "agosto","septiembre","octubre","noviembre","diciembre"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$data = [System.IO.File]::ReadAllText((Resolve-Path $Json), $utf8) | ConvertFrom-Json
if (-not $data.ok -or -not $data.eventos -or @($data.eventos).Count -eq 0) {
    throw "La lista de eventos vino vacía o con error"
}

# Instagram/Facebook de escuelas, jardines y academias identificados a mano
# (investigación de septiembre 2026). Si el título del evento menciona a una
# de estas instituciones, se agrega un enlace real a su cuenta — da contenido
# indexable de verdad y ayuda a que la propia institución encuentre sus fotos
# buscándose a sí misma. Solo hay entradas de confianza alta: mejor faltar un
# enlace que arriesgar uno de una institución equivocada.
$institucionesPath = Join-Path $PSScriptRoot "instituciones.json"
$instituciones = [System.IO.File]::ReadAllText($institucionesPath, $utf8) | ConvertFrom-Json

function Esc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

function BloqueInstitucion([string]$titulo) {
    foreach ($inst in $instituciones) {
        if ($titulo -match $inst.re) {
            $links = @()
            if ($inst.instagram) { $links += "<a href=`"$(Esc $inst.instagram)`" target=`"_blank`" rel=`"noopener`">Instagram</a>" }
            if ($inst.facebook) { $links += "<a href=`"$(Esc $inst.facebook)`" target=`"_blank`" rel=`"noopener`">Facebook</a>" }
            if ($links.Count -eq 0) { return "" }
            return "`n<div class=`"trelewflash-institucion`"><p style=`"font-size:0.9em;color:#666;`">$(Esc $inst.nombre) · $($links -join ' · ')</p></div>"
        }
    }
    return ""
}

$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$salidaEsperada = [System.IO.Path]::GetFullPath((Join-Path $repo "e"))
$salidaAbsoluta = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Salida))
if (-not [string]::Equals($salidaAbsoluta, $salidaEsperada, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "La salida debe ser exactamente la carpeta e del repositorio ($salidaEsperada). No se modificó ningún archivo."
}
if (Test-Path -LiteralPath $salidaEsperada) {
    $atributosSalida = [System.IO.File]::GetAttributes($salidaEsperada)
    if (($atributosSalida -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "La carpeta e es un enlace o punto de reanálisis; se cancela el borrado."
    }
    $salidaReal = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $salidaEsperada).Path)
    if (-not [string]::Equals($salidaReal, $salidaEsperada, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "La carpeta e resuelve fuera de su ruta esperada; se cancela el borrado."
    }
    Remove-Item -LiteralPath $salidaEsperada -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $salidaEsperada | Out-Null


$hoy = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$telWa = "5492804696961"
$urlsSitemap = New-Object System.Collections.Generic.List[string]
$urlsSitemap.Add("  <url><loc>$(Esc $sitio)</loc><lastmod>$hoy</lastmod><changefreq>daily</changefreq><priority>1.0</priority></url>")
$urlsSitemap.Add("  <url><loc>$(Esc ($sitio + "e/"))</loc><lastmod>$hoy</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>")

# JSON para <script type="application/ld+json">. pwsh 7 no escapa «<», así
# que se corta a mano cualquier «</» que pudiera cerrar el script antes.
function JsonLd($obj) { (ConvertTo-Json $obj -Depth 6 -Compress) -replace '</', '<\/' }

function FechaLarga([string]$f) {
    if ($f -match '^(\d{4})-(\d{2})-(\d{2})') {
        return "$([int]$Matches[3]) de $($meses[[int]$Matches[2] - 1]) de $($Matches[1])"
    }
    return ""
}

# Primero se juntan los eventos válidos (para enlazarlos entre sí), del más
# nuevo al más viejo.
$eventos = New-Object System.Collections.Generic.List[object]
foreach ($e in @($data.eventos)) {
    $id = [string]$e.id
    # Solo slugs: van en una carpeta y en la URL.
    if ($id -notmatch '^[a-z0-9][a-z0-9-]{0,150}$') { continue }
    if (-not $e.pdfs -or @($e.pdfs).Count -eq 0) { continue }
    $img = [string]$e.portada
    if ($img -notmatch '^https://') { $img = "https://lh3.googleusercontent.com/d/" + @($e.pdfs)[0].id + "=w1200" }
    $eventos.Add([pscustomobject]@{
        id     = $id
        titulo = [string]$e.titulo
        fecha  = [string]$e.fecha
        lugar  = [string]$e.lugar
        desc   = [string]$e.descripcion
        tags   = @($e.etiquetas | Where-Object { $_ } | ForEach-Object { [string]$_ })
        img    = $img
        url    = $sitio + "e/" + $id + "/"
    })
}
$eventos = @($eventos | Sort-Object -Property fecha -Descending)

function LiEvento($o) {
    $meta = @()
    $fl = FechaLarga $o.fecha
    if ($fl) { $meta += $fl }
    if ($o.lugar) { $meta += $o.lugar }
    $m = ""
    if ($meta.Count) { $m = "<span>$(Esc ($meta -join ' · '))</span>" }
    return "<li><a href=`"$(Esc $o.url)`">$(Esc $o.titulo)</a>$m</li>"
}

$css = @"
body{margin:0;font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;background:#f8fafc;color:#1e293b;line-height:1.5}
a{color:#1d4ed8}
.sup{background:#FCFC14;padding:10px 16px;text-align:center}
.sup a{color:#111;font-weight:800;text-decoration:none;font-size:1.15em}
main{max-width:720px;margin:0 auto;padding:16px}
.migas{font-size:.85em;color:#64748b;margin:0 0 10px}
.migas a{color:#64748b}
h1{font-size:1.5em;line-height:1.2;margin:0 0 6px}
.dato{margin:0;color:#475569}
.tags{margin:8px 0 0;padding:0;list-style:none;display:flex;flex-wrap:wrap;gap:6px}
.tags li{background:#e0e7ff;color:#3730a3;border-radius:999px;padding:2px 10px;font-size:.85em}
.portada{display:block;width:100%;height:auto;border-radius:14px;margin:14px 0;background:#e2e8f0}
.btn{display:block;text-align:center;text-decoration:none;font-weight:800;border-radius:12px;padding:14px;margin:10px 0;font-size:1.1em}
.btn-fotos{background:#111;color:#FCFC14}
.btn-wa{background:#25D366;color:#fff}
.caja{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:12px 16px;margin:16px 0}
.caja h2{font-size:1.1em;margin:0 0 6px}
.caja ol{margin:0;padding-left:20px}
.lista{list-style:none;margin:0;padding:0}
.lista li{padding:8px 0;border-top:1px solid #f1f5f9}
.lista li:first-child{border-top:0}
.lista span{display:block;font-size:.85em;color:#64748b}
footer{text-align:center;font-size:.85em;color:#64748b;padding:20px 16px 30px}
"@

$pie = @"
<footer>
<p><b>Trelewflash · Foto Flash</b> · Belgrano 386, Trelew, Chubut · WhatsApp <a href="https://wa.me/$telWa">2804 69-6961</a></p>
<p><a href="$sitio">Tienda</a> · <a href="$($sitio)e/">Fotos de eventos</a> · <a href="$($sitio)?ver=servicios">Fotografía para tu evento</a></p>
</footer>
"@

$n = 0
foreach ($o in $eventos) {
    $fl = FechaLarga $o.fecha
    $partes = @()
    if ($fl) { $partes += $fl }
    if ($o.lugar) { $partes += $o.lugar }
    $desc = "Mirá las fotos, anotá los números y pedilas por WhatsApp."
    if ($partes.Count) { $desc = ($partes -join " · ") + ". " + $desc }

    $destino = $sitio + "?ver=eventos&evento=" + $o.id
    $bloqueInst = BloqueInstitucion $o.titulo
    $wa = "https://wa.me/$telWa" + "?text=" + [uri]::EscapeDataString("Hola! Quiero pedir fotos del evento «" + $o.titulo + "».")

    $datos = ""
    if ($fl) { $datos += "<p class=`"dato`">📅 $(Esc $fl)</p>" }
    if ($o.lugar) { $datos += "<p class=`"dato`">📍 $(Esc $o.lugar)</p>" }
    $tags = ""
    if ($o.tags.Count) { $tags = "<ul class=`"tags`">" + (($o.tags | ForEach-Object { "<li>$(Esc $_)</li>" }) -join "") + "</ul>" }
    $parrafo = ""
    if ($o.desc) { $parrafo = "<p>$(Esc $o.desc)</p>" }

    # Enlaces a otros eventos: primero los del mismo lugar, después los más
    # nuevos. Le dan a Google un camino de una página a la otra.
    $otros = New-Object System.Collections.Generic.List[object]
    if ($o.lugar) {
        foreach ($x in $eventos) {
            if ($otros.Count -ge 4) { break }
            if ($x.id -ne $o.id -and $x.lugar -eq $o.lugar) { $otros.Add($x) }
        }
    }
    foreach ($x in $eventos) {
        if ($otros.Count -ge 8) { break }
        if ($x.id -ne $o.id -and -not ($otros | Where-Object { $_.id -eq $x.id })) { $otros.Add($x) }
    }
    $listaOtros = ($otros | ForEach-Object { LiEvento $_ }) -join "`n"

    $ld = JsonLd ([ordered]@{
        "@context" = "https://schema.org"
        "@graph" = @(
            [ordered]@{
                "@type" = "WebPage"
                "@id" = $o.url
                "url" = $o.url
                "name" = "Fotos de " + $o.titulo
                "description" = $desc
                "inLanguage" = "es-AR"
                "primaryImageOfPage" = [ordered]@{ "@type" = "ImageObject"; "url" = $o.img }
            },
            [ordered]@{
                "@type" = "BreadcrumbList"
                "itemListElement" = @(
                    [ordered]@{ "@type" = "ListItem"; "position" = 1; "name" = "Trelewflash"; "item" = $sitio },
                    [ordered]@{ "@type" = "ListItem"; "position" = 2; "name" = "Fotos de eventos"; "item" = $sitio + "e/" },
                    [ordered]@{ "@type" = "ListItem"; "position" = 3; "name" = $o.titulo; "item" = $o.url }
                )
            }
        )
    })

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fotos de $(Esc $o.titulo) · Trelewflash</title>
<meta name="description" content="$(Esc $desc)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Trelewflash">
<meta property="og:locale" content="es_AR">
<meta property="og:url" content="$(Esc $o.url)">
<link rel="canonical" href="$(Esc $o.url)">
<meta property="og:title" content="Fotos de «$(Esc $o.titulo)»">
<meta property="og:description" content="$(Esc $desc)">
<meta property="og:image" content="$(Esc $o.img)">
<meta property="og:image:alt" content="$(Esc $o.titulo)">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#FCFC14">
<link rel="icon" href="../../assets/favicon.ico" sizes="any">
<!-- Los enlaces que se comparten desde la tienda terminan en #fotos: esas
     personas van derecho a las fotos. Google no ve el #, así que lee esta
     página entera y la puede indexar. Sin meta refresh a propósito:
     Facebook lo seguiría y se quedaría con la vista previa de la tienda. -->
<script>if (location.hash === "#fotos") location.replace("$destino");</script>
<script type="application/ld+json">$ld</script>
<style>$css</style>
</head>
<body>
<div class="sup"><a href="$sitio">📸 Trelewflash</a></div>
<main>
<p class="migas"><a href="$sitio">Inicio</a> › <a href="$($sitio)e/">Fotos de eventos</a></p>
<h1>Fotos de $(Esc $o.titulo)</h1>
$datos
$tags
<img class="portada" src="$(Esc $o.img)" alt="Portada de las fotos de $(Esc $o.titulo)" loading="eager">
$parrafo
<a class="btn btn-fotos" href="$(Esc $destino)">📷 Ver las fotos del evento</a>
<a class="btn btn-wa" href="$(Esc $wa)" target="_blank" rel="noopener">🟢 Pedir mis fotos por WhatsApp</a>$bloqueInst
<section class="caja">
<h2>¿Cómo pido mis fotos?</h2>
<ol>
<li>Tocá «Ver las fotos del evento» y buscá las tuyas.</li>
<li>Anotá los números de las que te gustan.</li>
<li>Mandanos los números por WhatsApp y te confirmamos el precio y cuándo están listas.</li>
</ol>
</section>
<section class="caja">
<h2>Más fotos de eventos en Trelew</h2>
<ul class="lista">
$listaOtros
</ul>
<p><a href="$($sitio)e/">Ver todos los eventos ›</a></p>
</section>
</main>
$pie
</body>
</html>
"@
    $dir = Join-Path $salidaEsperada $o.id
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir "index.html"), ($html -replace "`r`n", "`n"), $utf8)
    $lastmod = $hoy
    if ($o.fecha -match '^\d{4}-\d{2}-\d{2}') { $lastmod = $o.fecha.Substring(0, 10) }
    $urlsSitemap.Add("  <url><loc>$(Esc $o.url)</loc><lastmod>$lastmod</lastmod><changefreq>monthly</changefreq><priority>0.6</priority></url>")
    $n++
}

# e/index.html: todos los eventos, agrupados por mes. Es la puerta de entrada
# para Google (se enlaza desde el pie de la tienda) y para quien busca su evento.
$grupos = New-Object System.Collections.Generic.List[string]
$mesActual = $null
$items = New-Object System.Collections.Generic.List[string]
foreach ($o in $eventos) {
    $mes = "Otros eventos"
    if ($o.fecha -match '^(\d{4})-(\d{2})') {
        $nombre = $meses[[int]$Matches[2] - 1]
        $mes = $nombre.Substring(0, 1).ToUpper() + $nombre.Substring(1) + " " + $Matches[1]
    }
    if ($mes -ne $mesActual) {
        if ($items.Count) { $grupos.Add("<h2>$(Esc $mesActual)</h2>`n<ul class=`"lista`">`n" + ($items -join "`n") + "`n</ul>") }
        $items = New-Object System.Collections.Generic.List[string]
        $mesActual = $mes
    }
    $items.Add((LiEvento $o))
}
if ($items.Count) { $grupos.Add("<h2>$(Esc $mesActual)</h2>`n<ul class=`"lista`">`n" + ($items -join "`n") + "`n</ul>") }

$urlHub = $sitio + "e/"
$descHub = "Fotos de muestras de danza, actos escolares, teatro y eventos de Trelew y la zona. Buscá tu evento, mirá las fotos y pedilas por WhatsApp."
$ldHub = JsonLd ([ordered]@{
    "@context" = "https://schema.org"
    "@type" = "CollectionPage"
    "url" = $urlHub
    "name" = "Fotos de eventos en Trelew"
    "description" = $descHub
    "inLanguage" = "es-AR"
})
$hub = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fotos de eventos en Trelew · Trelewflash</title>
<meta name="description" content="$(Esc $descHub)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Trelewflash">
<meta property="og:locale" content="es_AR">
<meta property="og:url" content="$(Esc $urlHub)">
<link rel="canonical" href="$(Esc $urlHub)">
<meta property="og:title" content="Fotos de eventos en Trelew">
<meta property="og:description" content="$(Esc $descHub)">
<meta name="theme-color" content="#FCFC14">
<link rel="icon" href="../assets/favicon.ico" sizes="any">
<script type="application/ld+json">$ldHub</script>
<style>$css
main h2{font-size:1.1em;margin:22px 0 4px}</style>
</head>
<body>
<div class="sup"><a href="$sitio">📸 Trelewflash</a></div>
<main>
<p class="migas"><a href="$sitio">Inicio</a> › Fotos de eventos</p>
<h1>Fotos de eventos en Trelew</h1>
<p>$(Esc $descHub)</p>
<a class="btn btn-fotos" href="$($sitio)?ver=eventos">🔎 Buscar en la galería de eventos</a>
$($grupos -join "`n")
</main>
$pie
</body>
</html>
"@
[System.IO.File]::WriteAllText((Join-Path $salidaEsperada "index.html"), ($hub -replace "`r`n", "`n"), $utf8)

$sitemap = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n" +
    "<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n" +
    ($urlsSitemap -join "`n") + "`n</urlset>`n"
[System.IO.File]::WriteAllText((Join-Path $repo "sitemap.xml"), $sitemap, $utf8)

"Páginas: $n"
