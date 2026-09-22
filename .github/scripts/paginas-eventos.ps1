# Arma e/<id>/index.html para cada evento: la página que leen Facebook y
# WhatsApp para la vista previa (ver .github/workflows/paginas-eventos.yml).
# Anda en Windows PowerShell 5.1 y en pwsh 7.
#   paginas-eventos.ps1 <eventos.json> <carpeta de salida>
param(
    [Parameter(Mandatory = $true)][string]$Json,
    [Parameter(Mandatory = $true)][string]$Salida
)
$ErrorActionPreference = "Stop"
$sitio = "https://digitalflash1.github.io/trelewflash/"
$meses = "enero","febrero","marzo","abril","mayo","junio","julio",
         "agosto","septiembre","octubre","noviembre","diciembre"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$data = [System.IO.File]::ReadAllText((Resolve-Path $Json), $utf8) | ConvertFrom-Json
if (-not $data.ok -or -not $data.eventos -or @($data.eventos).Count -eq 0) {
    throw "La lista de eventos vino vacía o con error"
}

function Esc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

if (Test-Path $Salida) { Remove-Item -Recurse -Force $Salida }
New-Item -ItemType Directory -Force $Salida | Out-Null

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
<p>Abriendo las fotos de <b>$(Esc $titulo)</b>…</p>
<p><a href="$(Esc $destino)">Tocá acá si no se abre solo</a></p>
</body>
</html>
"@
    $dir = Join-Path $Salida $id
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir "index.html"), ($html -replace "`r`n", "`n"), $utf8)
    $n++
}
"Páginas: $n"
