# Arma las páginas que indexa Google y que leen Facebook y WhatsApp para la
# vista previa (ver .github/workflows/paginas-eventos.yml):
#   e/<id>/index.html     una por evento, con su contenido y enlaces a otros
#   e/index.html          todos los eventos por mes
#   fotos/<id>/index.html una por escuela, jardín o institución, con todos sus
#                         eventos por año (desde el 28/11/2026: la gente busca
#                         «escuela 712 fotos», no el acto de un año suelto)
#   fotos/index.html      todas las instituciones por tipo
#   sitemap.xml           todo lo anterior más las páginas sueltas
# Las páginas de eventos solo saltan a la tienda con #fotos, que es como las
# comparte la tienda; si no, Google las descarta como «Página con redirección».
# Anda en Windows PowerShell 5.1 (el archivo va con BOM) y en pwsh 7.
#   paginas-eventos.ps1 <eventos.json> e (solo se permite la carpeta e del repo)
param(
    [Parameter(Mandatory = $true)][string]$Json,
    [Parameter(Mandatory = $true)][string]$Salida
)
$ErrorActionPreference = "Stop"
$sitio = "https://trelewflash.com.ar/"
$marca = "Trelew Flash"
$meses = "enero","febrero","marzo","abril","mayo","junio","julio",
         "agosto","septiembre","octubre","noviembre","diciembre"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$data = [System.IO.File]::ReadAllText((Resolve-Path $Json), $utf8) | ConvertFrom-Json
if (-not $data.ok -or -not $data.eventos -or @($data.eventos).Count -eq 0) {
    throw "La lista de eventos vino vacía o con error"
}

# Escuelas, jardines y academias identificados a mano (investigación de
# septiembre 2026): nombre completo, nombre corto, tipo y sus redes. Solo hay
# entradas de confianza alta: mejor faltar un enlace que poner uno equivocado.
# Las escuelas y jardines con número que no están en la lista se reconocen
# solos por el título ($tiposAuto).
$institucionesPath = Join-Path $PSScriptRoot "instituciones.json"
$instituciones = [System.IO.File]::ReadAllText($institucionesPath, $utf8) | ConvertFrom-Json

$tiposAuto = @(
    @{ re = '\bJard[ií]n\s*(?:N\s*[°º.]\s*)?(\d{2,4})\b'; tipo = 'jardin'; nombre = 'Jardín' },
    @{ re = '\bInstituto\s*(?:N\s*[°º.]\s*)?(\d{3,4})\b'; tipo = 'instituto'; nombre = 'Instituto' },
    @{ re = '\bEPJA\s*(?:N\s*[°º.]\s*)?(\d{3,4})\b'; tipo = 'escuela'; nombre = 'EPJA' },
    @{ re = '\b(\d{3,4})\s*EPJA\b'; tipo = 'escuela'; nombre = 'EPJA' },
    @{ re = '\b(?:Escuela|Colegio)\s*(?:N\s*[°º.]\s*|n[uú]mero\s*)?(\d{1,4})\b'; tipo = 'escuela'; nombre = 'Escuela' },
    @{ re = '^\s*(\d{3,4})\s+(?:Acad[eé]mico|Enet)\b'; tipo = 'escuela'; nombre = 'Escuela' }
)

function Esc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }
function Cap([string]$s) { if (-not $s) { return $s }; $s.Substring(0, 1).ToUpper() + $s.Substring(1) }
function Comillas([string]$s) { $s -replace '"([^"]+)"', '«$1»' }

function InstitucionDe([string]$titulo) {
    foreach ($inst in $instituciones) {
        if ($titulo -match $inst.re) {
            $corto = [string]$inst.corto
            if (-not $corto) { $corto = [string]$inst.nombre }
            $tipo = [string]$inst.tipo
            if (-not $tipo) { $tipo = "otro" }
            return [pscustomobject]@{
                id = [string]$inst.id; nombre = Comillas ([string]$inst.nombre); corto = $corto; tipo = $tipo
                instagram = [string]$inst.instagram; facebook = [string]$inst.facebook
            }
        }
    }
    foreach ($t in $tiposAuto) {
        if ($titulo -match $t.re) {
            $num = [int]$Matches[1]
            if ($num -lt 1) { continue }
            return [pscustomobject]@{
                id = "$($t.tipo)-$num"; nombre = "$($t.nombre) N° $num"; corto = "$($t.nombre) $num"; tipo = $t.tipo
                instagram = ""; facebook = ""
            }
        }
    }
    return $null
}

function BloqueInstitucion($inst) {
    if (-not $inst) { return "" }
    $links = @()
    if ($inst.instagram) { $links += "<a href=`"$(Esc $inst.instagram)`" target=`"_blank`" rel=`"noopener`">Instagram</a>" }
    if ($inst.facebook) { $links += "<a href=`"$(Esc $inst.facebook)`" target=`"_blank`" rel=`"noopener`">Facebook</a>" }
    if ($links.Count -eq 0) { return "" }
    return "`n<div class=`"trelewflash-institucion`"><p style=`"font-size:0.9em;color:#666;`">$(Esc $inst.nombre) · $($links -join ' · ')</p></div>"
}

function CiudadDe([string]$texto) {
    if ($texto -match 'Gaiman') { return "Gaiman" }
    if ($texto -match 'Rawson') { return "Rawson" }
    if ($texto -match 'Madryn') { return "Puerto Madryn" }
    if ($texto -match 'Dolavon') { return "Dolavon" }
    return "Trelew"
}

# Salida: solo las carpetas e y fotos del repo, que se borran y se rearman.
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$salidaEsperada = [System.IO.Path]::GetFullPath((Join-Path $repo "e"))
$salidaAbsoluta = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Salida))
if (-not [string]::Equals($salidaAbsoluta, $salidaEsperada, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "La salida debe ser exactamente la carpeta e del repositorio ($salidaEsperada). No se modificó ningún archivo."
}
$salidaFotos = [System.IO.Path]::GetFullPath((Join-Path $repo "fotos"))

function PrepararCarpeta([string]$ruta) {
    if (Test-Path -LiteralPath $ruta) {
        $atributos = [System.IO.File]::GetAttributes($ruta)
        if (($atributos -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "La carpeta $ruta es un enlace o punto de reanálisis; se cancela el borrado."
        }
        $real = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ruta).Path)
        if (-not [string]::Equals($real, $ruta, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "La carpeta $ruta resuelve fuera de su ruta esperada; se cancela el borrado."
        }
        Remove-Item -LiteralPath $ruta -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ruta | Out-Null
}
PrepararCarpeta $salidaEsperada
PrepararCarpeta $salidaFotos

$hoy = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$telWa = "5492804696961"
$urlsSitemap = New-Object System.Collections.Generic.List[string]
$urlsSitemap.Add("  <url><loc>$(Esc $sitio)</loc><lastmod>$hoy</lastmod><changefreq>daily</changefreq><priority>1.0</priority></url>")
$urlsSitemap.Add("  <url><loc>$(Esc ($sitio + "e/"))</loc><lastmod>$hoy</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>")
$urlsSitemap.Add("  <url><loc>$(Esc ($sitio + "fotos/"))</loc><lastmod>$hoy</lastmod><changefreq>weekly</changefreq><priority>0.8</priority></url>")
# Páginas sueltas de servicios (escritas a mano, no salen de la hoja).
$urlsSitemap.Add("  <url><loc>$(Esc ($sitio + "bajar-fotos-del-celular/"))</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>")

# JSON para <script type="application/ld+json">. pwsh 7 no escapa «<», así
# que se corta a mano cualquier «</» que pudiera cerrar el script antes.
function JsonLd($obj) { (ConvertTo-Json $obj -Depth 8 -Compress) -replace '</', '<\/' }

function FechaLarga([string]$f) {
    if ($f -match '^(\d{4})-(\d{2})-(\d{2})') {
        return "$([int]$Matches[3]) de $($meses[[int]$Matches[2] - 1]) de $($Matches[1])"
    }
    return ""
}

# La fecha de la hoja es la de publicación: en los eventos que vinieron de
# WordPress es la del día en que se subieron (la 712 «Egresados 2024» decía
# «29 de julio de 2025»). Si el título trae mes y año, o un año, distintos de
# esa fecha, manda el título.
$mesesRe = $meses -join '|'
function FechaEvento([string]$titulo, [string]$fecha) {
    $fy = 0; $fm = 0
    if ($fecha -match '^(\d{4})-(\d{2})-(\d{2})') { $fy = [int]$Matches[1]; $fm = [int]$Matches[2] }
    if ($titulo -match "(?:\b(\d{1,2})\s+de\s+)?\b($mesesRe)\s*(?:de\s*)?((?:19|20)\d{2})\b") {
        $tm = [array]::IndexOf($meses, $Matches[2].ToLower()) + 1
        $ty = [int]$Matches[3]
        $td = 0
        if ($Matches[1]) { $td = [int]$Matches[1] }
        if ($fy -ne $ty -or $fm -ne $tm) {
            if ($td -ge 1 -and $td -le 31) {
                return @{ texto = "$td de $($meses[$tm - 1]) de $ty"; orden = ('{0:D4}-{1:D2}-{2:D2}' -f $ty, $tm, $td); anio = $ty; mes = $tm }
            }
            return @{ texto = "$(Cap $meses[$tm - 1]) de $ty"; orden = ('{0:D4}-{1:D2}-00' -f $ty, $tm); anio = $ty; mes = $tm }
        }
    } elseif ($titulo -match '\b((?:19|20)\d{2})\b') {
        $ty = [int]$Matches[1]
        if ($fy -ne $ty) { return @{ texto = "$ty"; orden = "$ty-12-99"; anio = $ty; mes = 0 } }
    }
    if ($fy) { return @{ texto = (FechaLarga $fecha); orden = $fecha.Substring(0, 10); anio = $fy; mes = $fm } }
    return @{ texto = ""; orden = ""; anio = 0; mes = 0 }
}

# Primero se juntan los eventos válidos (para enlazarlos entre sí), del más
# nuevo al más viejo. Los que tienen galería y no PDF entran si tienen portada.
$eventos = New-Object System.Collections.Generic.List[object]
foreach ($e in @($data.eventos)) {
    $id = [string]$e.id
    # Solo slugs: van en una carpeta y en la URL.
    if ($id -notmatch '^[a-z0-9][a-z0-9-]{0,150}$') { continue }
    $tienePdf = ($e.pdfs -and @($e.pdfs).Count -gt 0)
    $img = [string]$e.portada
    if ($img -notmatch '^https://') {
        if (-not $tienePdf) { continue }
        $img = "https://lh3.googleusercontent.com/d/" + @($e.pdfs)[0].id + "=w1200"
    }
    $titulo = [string]$e.titulo
    $lugar = [string]$e.lugar
    $fe = FechaEvento $titulo ([string]$e.fecha)
    $eventos.Add([pscustomobject]@{
        id     = $id
        titulo = $titulo
        fecha  = [string]$e.fecha
        fe     = $fe
        orden  = $fe.orden
        lugar  = $lugar
        desc   = [string]$e.descripcion
        tags   = @($e.etiquetas | Where-Object { $_ } | ForEach-Object { [string]$_ })
        img    = $img
        pdf    = [bool]$tienePdf
        inst   = InstitucionDe $titulo
        ciudad = CiudadDe ($titulo + " " + $lugar)
        url    = $sitio + "e/" + $id + "/"
    })
}
$eventos = @($eventos | Sort-Object -Property @{ Expression = "orden"; Descending = $true }, @{ Expression = "fecha"; Descending = $true })

# Instituciones con al menos un evento, con sus eventos ya ordenados.
$porInst = [ordered]@{}
foreach ($o in $eventos) {
    if (-not $o.inst) { continue }
    $k = $o.inst.id
    if (-not $porInst.Contains($k)) {
        $porInst[$k] = [pscustomobject]@{ inst = $o.inst; eventos = (New-Object System.Collections.Generic.List[object]); ciudad = "Trelew"; url = $sitio + "fotos/" + $k + "/" }
    }
    $porInst[$k].eventos.Add($o)
}
foreach ($g in $porInst.Values) {
    foreach ($o in $g.eventos) { if ($o.ciudad -ne "Trelew") { $g.ciudad = $o.ciudad; break } }
}

function LiEvento($o) {
    $meta = @()
    if ($o.fe.texto) { $meta += $o.fe.texto }
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
.btn-inst{background:#e0e7ff;color:#3730a3}
.caja{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:12px 16px;margin:16px 0}
.caja h2{font-size:1.1em;margin:0 0 6px}
.caja ol{margin:0;padding-left:20px}
.lista{list-style:none;margin:0;padding:0}
.lista li{padding:8px 0;border-top:1px solid #f1f5f9}
.lista li:first-child{border-top:0}
.lista span{display:block;font-size:.85em;color:#64748b}
main h2.anio{font-size:1.15em;margin:22px 0 4px}
footer{text-align:center;font-size:.85em;color:#64748b;padding:20px 16px 30px}
"@

$pie = @"
<footer>
<p><b>Trelew Flash · Foto Flash</b> · Belgrano 386, Trelew, Chubut · WhatsApp <a href="https://wa.me/$telWa">2804 69-6961</a></p>
<p><a href="$sitio">Tienda</a> · <a href="$($sitio)e/">Fotos de eventos</a> · <a href="$($sitio)fotos/">Fotos por escuela</a> · <a href="$($sitio)?ver=servicios">Fotografía para tu evento</a></p>
</footer>
"@

function Cabeza([string]$titulo, [string]$desc, [string]$url, [string]$img, [string]$ogTitulo, [string]$icono, [string]$ld, [string]$extra) {
    $ogImg = ""
    if ($img) { $ogImg = "`n<meta property=`"og:image`" content=`"$(Esc $img)`">`n<meta name=`"twitter:card`" content=`"summary_large_image`">" }
    return @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Esc $titulo)</title>
<meta name="description" content="$(Esc $desc)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="$marca">
<meta property="og:locale" content="es_AR">
<meta property="og:url" content="$(Esc $url)">
<link rel="canonical" href="$(Esc $url)">
<meta property="og:title" content="$(Esc $ogTitulo)">
<meta property="og:description" content="$(Esc $desc)">$ogImg
<meta name="theme-color" content="#FCFC14">
<link rel="icon" href="$icono" sizes="any">$extra
<script type="application/ld+json">$ld</script>
<style>$css</style>
</head>
"@
}

function Migas($items) {
    # $items: lista de @(nombre, url); el último va sin enlace.
    $partes = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -lt $items.Count - 1) { $partes += "<a href=`"$(Esc $items[$i][1])`">$(Esc $items[$i][0])</a>" }
        else { $partes += (Esc $items[$i][0]) }
    }
    return "<p class=`"migas`">" + ($partes -join " › ") + "</p>"
}

function MigasLd($items) {
    $lista = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $lista += [ordered]@{ "@type" = "ListItem"; "position" = $i + 1; "name" = $items[$i][0]; "item" = $items[$i][1] }
    }
    return [ordered]@{ "@type" = "BreadcrumbList"; "itemListElement" = $lista }
}

# ---------- e/<id>/: una página por evento ----------
$n = 0
foreach ($o in $eventos) {
    $inst = $o.inst
    $grupo = $null
    if ($inst) { $grupo = $porInst[$inst.id] }

    # «Escuela N° 712 «Don Santiago Estrada», Trelew · 2024 · Teatro Verdi. Buscá…»
    $partes = @($o.ciudad)
    if ($inst) { $partes = @("$($inst.nombre), $($grupo.ciudad)") }
    if ($o.fe.texto) { $partes += $o.fe.texto }
    if ($o.lugar) { $partes += $o.lugar }
    $desc = ($partes -join " · ") + ". Buscá tus fotos del evento y pedilas por WhatsApp."

    $destino = $sitio + "?ver=eventos&evento=" + $o.id
    $wa = "https://wa.me/$telWa" + "?text=" + [uri]::EscapeDataString("Hola! Quiero pedir fotos del evento «" + $o.titulo + "».")

    $datos = ""
    if ($o.fe.texto) { $datos += "<p class=`"dato`">📅 $(Esc $o.fe.texto)</p>" }
    if ($o.lugar) { $datos += "<p class=`"dato`">📍 $(Esc $o.lugar)</p>" }
    $tags = ""
    if ($o.tags.Count) { $tags = "<ul class=`"tags`">" + (($o.tags | ForEach-Object { "<li>$(Esc $_)</li>" }) -join "") + "</ul>" }
    $parrafo = ""
    if ($o.desc) { $parrafo = "<p>$(Esc $o.desc)</p>" }

    $pasos = "<li>Tocá «Ver las fotos del evento» y buscá las tuyas.</li>`n<li>Anotá los números de las que te gustan.</li>`n<li>Mandanos los números por WhatsApp y te confirmamos el precio y cuándo están listas.</li>"
    if (-not $o.pdf) {
        $pasos = "<li>Tocá «Ver las fotos del evento» y buscá las tuyas.</li>`n<li>Tocá las que te gustan para elegirlas.</li>`n<li>Tocá «Pedir por WhatsApp»: te mostramos el total y cómo pagar.</li>"
    }

    # Las otras fotos de la misma institución van primero, en su propia caja.
    $cajaInst = ""
    $botonInst = ""
    $yaListados = @{ $o.id = $true }
    if ($grupo) {
        $hermanos = @($grupo.eventos | Where-Object { $_.id -ne $o.id } | Select-Object -First 12)
        $botonInst = "`n<a class=`"btn btn-inst`" href=`"$(Esc $grupo.url)`">🏫 Todas las fotos de $(Esc $inst.corto)</a>"
        if ($hermanos.Count) {
            foreach ($x in $hermanos) { $yaListados[$x.id] = $true }
            $cajaInst = @"
<section class="caja">
<h2>Más fotos de $(Esc $inst.corto)</h2>
<ul class="lista">
$(($hermanos | ForEach-Object { LiEvento $_ }) -join "`n")
</ul>
<p><a href="$(Esc $grupo.url)">Todas las fotos de $(Esc $inst.corto) ›</a></p>
</section>
"@
        }
    }

    # Otros eventos: primero los del mismo lugar, después los más nuevos.
    $otros = New-Object System.Collections.Generic.List[object]
    if ($o.lugar) {
        foreach ($x in $eventos) {
            if ($otros.Count -ge 4) { break }
            if (-not $yaListados.Contains($x.id) -and $x.lugar -eq $o.lugar) { $otros.Add($x); $yaListados[$x.id] = $true }
        }
    }
    foreach ($x in $eventos) {
        if ($otros.Count -ge 8) { break }
        if (-not $yaListados.Contains($x.id)) { $otros.Add($x); $yaListados[$x.id] = $true }
    }
    $listaOtros = ($otros | ForEach-Object { LiEvento $_ }) -join "`n"

    $migas = New-Object System.Collections.Generic.List[object]
    $migas.Add(@("Inicio", $sitio))
    if ($grupo) { $migas.Add(@("Fotos por escuela", ($sitio + "fotos/"))); $migas.Add(@($inst.corto, $grupo.url)) }
    else { $migas.Add(@("Fotos de eventos", ($sitio + "e/"))) }
    $migas.Add(@($o.titulo, $o.url))

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
            (MigasLd $migas)
        )
    })

    $extra = @"

<!-- Los enlaces que se comparten desde la tienda terminan en #fotos: esas
     personas van derecho a las fotos. Google no ve el #, así que lee esta
     página entera y la puede indexar. Sin meta refresh a propósito:
     Facebook lo seguiría y se quedaría con la vista previa de la tienda. -->
<script>if (location.hash === "#fotos") location.replace("$destino");</script>
"@
    $html = (Cabeza "Fotos de $($o.titulo) · $marca" $desc $o.url $o.img "Fotos de «$($o.titulo)»" "../../assets/favicon.ico?v=2" $ld $extra) + @"
<body>
<div class="sup"><a href="$sitio">📸 $marca</a></div>
<main>
$(Migas $migas)
<h1>Fotos de $(Esc $o.titulo)</h1>
$datos
$tags
<img class="portada" src="$(Esc $o.img)" alt="Portada de las fotos de $(Esc $o.titulo)" loading="eager">
$parrafo
<a class="btn btn-fotos" href="$(Esc $destino)">📷 Ver las fotos del evento</a>
<a class="btn btn-wa" href="$(Esc $wa)" target="_blank" rel="noopener">🟢 Pedir mis fotos por WhatsApp</a>$botonInst$(BloqueInstitucion $inst)
<section class="caja">
<h2>¿Cómo pido mis fotos?</h2>
<ol>
$pasos
</ol>
</section>
$cajaInst
<section class="caja">
<h2>Más fotos de eventos en Trelew</h2>
<ul class="lista">
$listaOtros
</ul>
<p><a href="$($sitio)e/">Ver todos los eventos ›</a> · <a href="$($sitio)fotos/">Fotos por escuela ›</a></p>
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

# ---------- fotos/<id>/: una página por institución ----------
$nombresTipo = [ordered]@{
    escuela   = @("Escuelas", "escuelas")
    jardin    = @("Jardines", "jardines")
    instituto = @("Institutos y terciarios", "institutos")
    danza     = @("Danza y academias", "academias")
    otro      = @("Otras instituciones", "instituciones")
}
function ClaveOrden([string]$s) { [regex]::Replace($s.ToLower(), '\d+', { param($m) $m.Value.PadLeft(6, '0') }) }
function LiInstitucion($g) {
    $c = $g.eventos.Count
    $ult = $g.eventos[0].fe.texto
    $txt = "$c " + $(if ($c -eq 1) { "evento" } else { "eventos" })
    if ($ult) { $txt += " · el último: $ult" }
    return "<li><a href=`"$(Esc $g.url)`">$(Esc $g.inst.corto)</a><span>$(Esc $txt)</span></li>"
}

$nInst = 0
foreach ($g in $porInst.Values) {
    $inst = $g.inst
    $lista = $g.eventos.ToArray()
    $anios = @($lista | ForEach-Object { $_.fe.anio } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
    $rango = ""
    if ($anios.Count -eq 1) { $rango = " en $($anios[0])" }
    elseif ($anios.Count -gt 1) { $rango = ", de $($anios[0]) a $($anios[-1])" }
    $cant = "$($lista.Count) " + $(if ($lista.Count -eq 1) { "evento con fotos" } else { "eventos con fotos" })

    $deQue = "fotos de sus eventos"
    if ($inst.tipo -in @("escuela", "jardin", "instituto")) { $deQue = "fotos de actos y egresados" }
    elseif ($inst.tipo -eq "danza") { $deQue = "fotos de muestras y galas" }
    $tituloPag = "$($inst.corto) de $($g.ciudad): $deQue · $marca"
    if ($inst.corto -match [regex]::Escape($g.ciudad)) { $tituloPag = "$($inst.corto): $deQue · $marca" }
    $desc = "Todas las fotos de $($inst.nombre) ($($g.ciudad)): $cant$rango. Elegí el acto, buscá tus fotos y pedilas por WhatsApp."

    # Eventos agrupados por año, del más nuevo al más viejo.
    $bloques = New-Object System.Collections.Generic.List[string]
    $anioActual = $null
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($o in $lista) {
        $a = "Otros"
        if ($o.fe.anio) { $a = [string]$o.fe.anio }
        if ($a -ne $anioActual) {
            if ($items.Count) { $bloques.Add("<h2 class=`"anio`">$(Esc $anioActual)</h2>`n<ul class=`"lista`">`n" + ($items -join "`n") + "`n</ul>") }
            $items = New-Object System.Collections.Generic.List[string]
            $anioActual = $a
        }
        $items.Add((LiEvento $o))
    }
    if ($items.Count) { $bloques.Add("<h2 class=`"anio`">$(Esc $anioActual)</h2>`n<ul class=`"lista`">`n" + ($items -join "`n") + "`n</ul>") }

    # Otras instituciones del mismo tipo, las de eventos más nuevos primero.
    $mismas = @($porInst.Values | Where-Object { $_.inst.tipo -eq $inst.tipo -and $_.inst.id -ne $inst.id } | Select-Object -First 12)
    $plural = $nombresTipo[$inst.tipo][1]
    $cajaOtras = ""
    if ($mismas.Count) {
        $cajaOtras = @"
<section class="caja">
<h2>Fotos de otras $plural</h2>
<ul class="lista">
$(($mismas | ForEach-Object { LiInstitucion $_ }) -join "`n")
</ul>
<p><a href="$($sitio)fotos/">Ver todas las escuelas e instituciones ›</a></p>
</section>
"@
    }

    $wa = "https://wa.me/$telWa" + "?text=" + [uri]::EscapeDataString("Hola! Busco las fotos de un acto de " + $inst.corto + ".")
    $migas = @(@("Inicio", $sitio), @("Fotos por escuela", ($sitio + "fotos/")), @($inst.corto, $g.url))
    $sameAs = @(@($inst.instagram, $inst.facebook) | Where-Object { $_ })
    $tipoOrg = "Organization"
    if ($inst.tipo -in @("escuela", "jardin", "instituto")) { $tipoOrg = "EducationalOrganization" }
    $org = [ordered]@{ "@type" = $tipoOrg; "name" = $inst.nombre; "address" = [ordered]@{ "@type" = "PostalAddress"; "addressLocality" = $g.ciudad; "addressRegion" = "Chubut"; "addressCountry" = "AR" } }
    if ($sameAs.Count) { $org["sameAs"] = $sameAs }
    $ld = JsonLd ([ordered]@{
        "@context" = "https://schema.org"
        "@graph" = @(
            [ordered]@{
                "@type" = "CollectionPage"
                "@id" = $g.url
                "url" = $g.url
                "name" = "Fotos de $($inst.corto)"
                "description" = $desc
                "inLanguage" = "es-AR"
                "about" = $org
                "primaryImageOfPage" = [ordered]@{ "@type" = "ImageObject"; "url" = $lista[0].img }
            },
            (MigasLd $migas)
        )
    })

    $html = (Cabeza $tituloPag $desc $g.url $lista[0].img "Fotos de $($inst.corto)" "../../assets/favicon.ico?v=2" $ld "") + @"
<body>
<div class="sup"><a href="$sitio">📸 $marca</a></div>
<main>
$(Migas $migas)
<h1>Fotos de $(Esc $inst.nombre)</h1>
<p class="dato">📍 $(Esc $g.ciudad) · $(Esc $cant)$(Esc $rango)</p>
<img class="portada" src="$(Esc $lista[0].img)" alt="Fotos de $(Esc $lista[0].titulo)" loading="eager">
<p>Acá están todas las fotos que sacamos en los actos y eventos de $(Esc $inst.corto), ordenadas por año. Elegí el evento, buscá tus fotos y pedilas por WhatsApp.</p>$(BloqueInstitucion $inst)
$($bloques -join "`n")
<section class="caja">
<h2>¿No encontrás tu acto?</h2>
<p>Las fotos de cada acto aparecen acá unos días después. Si el tuyo todavía no está, escribinos y te decimos cuándo van a estar.</p>
<a class="btn btn-wa" href="$(Esc $wa)" target="_blank" rel="noopener">🟢 Preguntar por WhatsApp</a>
</section>
$cajaOtras
</main>
$pie
</body>
</html>
"@
    $dir = Join-Path $salidaFotos $inst.id
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir "index.html"), ($html -replace "`r`n", "`n"), $utf8)
    $lastmod = $hoy
    $pub = @($lista | ForEach-Object { $_.fecha } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object -Descending)
    if ($pub.Count) { $lastmod = $pub[0].Substring(0, 10) }
    $urlsSitemap.Add("  <url><loc>$(Esc $g.url)</loc><lastmod>$lastmod</lastmod><changefreq>weekly</changefreq><priority>0.7</priority></url>")
    $nInst++
}

# ---------- fotos/index.html: todas las instituciones por tipo ----------
$secciones = New-Object System.Collections.Generic.List[string]
foreach ($tipo in $nombresTipo.Keys) {
    $gs = @($porInst.Values | Where-Object { $_.inst.tipo -eq $tipo } | Sort-Object -Property @{ Expression = { ClaveOrden $_.inst.corto } })
    if (-not $gs.Count) { continue }
    $secciones.Add("<h2 class=`"anio`">$(Esc $nombresTipo[$tipo][0])</h2>`n<ul class=`"lista`">`n" + (($gs | ForEach-Object { LiInstitucion $_ }) -join "`n") + "`n</ul>")
}
$urlFotos = $sitio + "fotos/"
$descFotos = "Fotos de actos escolares, egresados, jardines y academias de Trelew y la zona, ordenadas por escuela. Buscá la tuya, mirá las fotos y pedilas por WhatsApp."
$ldFotos = JsonLd ([ordered]@{
    "@context" = "https://schema.org"
    "@graph" = @(
        [ordered]@{ "@type" = "CollectionPage"; "@id" = $urlFotos; "url" = $urlFotos; "name" = "Fotos por escuela e institución"; "description" = $descFotos; "inLanguage" = "es-AR" },
        (MigasLd @(@("Inicio", $sitio), @("Fotos por escuela", $urlFotos)))
    )
})
$htmlFotos = (Cabeza "Fotos de escuelas, jardines y academias de Trelew · $marca" $descFotos $urlFotos "" "Fotos por escuela e institución" "../assets/favicon.ico?v=2" $ldFotos "") + @"
<body>
<div class="sup"><a href="$sitio">📸 $marca</a></div>
<main>
$(Migas @(@("Inicio", $sitio), @("Fotos por escuela", $urlFotos)))
<h1>Fotos por escuela e institución</h1>
<p>$(Esc $descFotos)</p>
<a class="btn btn-fotos" href="$($sitio)e/">📅 Ver todos los eventos por fecha</a>
$($secciones -join "`n")
</main>
$pie
</body>
</html>
"@
[System.IO.File]::WriteAllText((Join-Path $salidaFotos "index.html"), ($htmlFotos -replace "`r`n", "`n"), $utf8)

# ---------- e/index.html: todos los eventos, agrupados por mes ----------
# Es la puerta de entrada para Google (se enlaza desde el pie de la tienda) y
# para quien busca su evento.
$grupos = New-Object System.Collections.Generic.List[string]
$mesActual = $null
$items = New-Object System.Collections.Generic.List[string]
foreach ($o in $eventos) {
    $mes = "Otros eventos"
    if ($o.fe.mes) { $mes = (Cap $meses[$o.fe.mes - 1]) + " " + $o.fe.anio }
    elseif ($o.fe.anio) { $mes = [string]$o.fe.anio }
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
$hub = (Cabeza "Fotos de eventos en Trelew · $marca" $descHub $urlHub "" "Fotos de eventos en Trelew" "../assets/favicon.ico?v=2" $ldHub "").Replace("</style>", "main h2{font-size:1.1em;margin:22px 0 4px}</style>") + @"
<body>
<div class="sup"><a href="$sitio">📸 $marca</a></div>
<main>
<p class="migas"><a href="$sitio">Inicio</a> › Fotos de eventos</p>
<h1>Fotos de eventos en Trelew</h1>
<p>$(Esc $descHub)</p>
<a class="btn btn-fotos" href="$($sitio)?ver=eventos">🔎 Buscar en la galería de eventos</a>
<a class="btn btn-inst" href="$($sitio)fotos/">🏫 Buscar por escuela, jardín o academia</a>
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

"Páginas de eventos: $n · Instituciones: $nInst"
