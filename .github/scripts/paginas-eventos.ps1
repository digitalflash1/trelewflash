# Arma e/<id>/index.html para cada evento: la página que leen Facebook y
# WhatsApp para la vista previa (ver .github/workflows/paginas-eventos.yml).
# De paso arma sitemap.xml (home + una entrada por evento) en la raíz del
# repo, para que Google encuentre estas páginas: no tienen enlaces internas
# entre sí, solo se comparten sueltas por WhatsApp.
# Anda en Windows PowerShell 5.1 y en pwsh 7.
#   paginas-eventos.ps1 <eventos.json> <carpeta de salida>
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

if (Test-Path $Salida) { Remove-Item -Recurse -Force $Salida }
New-Item -ItemType Directory -Force $Salida | Out-Null

$hoy = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$urlsSitemap = New-Object System.Collections.Generic.List[string]
$urlsSitemap.Add("  <url><loc>$(Esc $sitio)</loc><lastmod>$hoy</lastmod><changefreq>daily</changefreq><priority>1.0</priority></url>")

$n = 0
foreach ($e in @($data.eventos)) {
    $id = [string]$e.id
    # Solo slugs: van en una carpeta y en la URL.
    if ($id -notmatch '^[a-z0-9][a-z0-9-]{0,150}$') { continue }
    if (-not $e.pdfs -or @($e.pdfs).Count -eq 0) { continue }

    $partes = @()
    if ([string]$e.fecha -match '^(\d{4})-(\d{2})-(\d{2})') {
        $partes += "$([int]$Matches[3]) de $($meses[[int]$Matches[2] - 1]) de $($Matches[1])"
    }
    if ($e.lugar) { $partes += [string]$e.lugar }
    $desc = "Mirá las fotos, anotá los números y pedilas por WhatsApp."
    if ($partes.Count) { $desc = ($partes -join " · ") + ". " + $desc }

    $img = [string]$e.portada
    if ($img -notmatch '^https://') { $img = "https://lh3.googleusercontent.com/d/" + @($e.pdfs)[0].id + "=w1200" }

    $titulo = [string]$e.titulo
    $url = $sitio + "e/" + $id + "/"
    $destino = $sitio + "?ver=eventos&evento=" + $id
    $bloqueInst = BloqueInstitucion $titulo

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Esc $titulo) · Trelewflash</title>
<meta name="description" content="$(Esc $desc)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Trelewflash">
<meta property="og:locale" content="es_AR">
<meta property="og:url" content="$(Esc $url)">
<link rel="canonical" href="$(Esc $url)">
<meta property="og:title" content="Fotos de «$(Esc $titulo)»">
<meta property="og:description" content="$(Esc $desc)">
<meta property="og:image" content="$(Esc $img)">
<meta property="og:image:alt" content="$(Esc $titulo)">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#FCFC14">
<link rel="icon" href="../../assets/favicon.ico" sizes="any">
<!-- Sin meta refresh a propósito: Facebook lo sigue y se quedaría con la
     vista previa general de la tienda. Las personas pasan por el script. -->
<script>location.replace("$destino" + location.hash);</script>
</head>
<body style="font-family:sans-serif;text-align:center;padding:40px 16px;">
<h1 style="font-size:1.1em;">$(Esc $titulo)</h1>$bloqueInst
<p>Abriendo las fotos…</p>
<p><a href="$(Esc $destino)">Tocá acá si no se abre solo</a></p>
</body>
</html>
"@
    $dir = Join-Path $Salida $id
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir "index.html"), ($html -replace "`r`n", "`n"), $utf8)
    $urlsSitemap.Add("  <url><loc>$(Esc $url)</loc><lastmod>$hoy</lastmod><changefreq>monthly</changefreq><priority>0.6</priority></url>")
    $n++
}

$sitemap = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n" +
    "<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n" +
    ($urlsSitemap -join "`n") + "`n</urlset>`n"
[System.IO.File]::WriteAllText("sitemap.xml", $sitemap, $utf8)

"Páginas: $n"
