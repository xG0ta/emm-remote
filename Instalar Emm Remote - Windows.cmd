<# : Emm Remote - instalador de un clic para Windows (doble clic para correrlo)
@echo off
net session >nul 2>&1
if not errorlevel 1 goto run
powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
exit /b
:run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='%~f0'; iex ((Get-Content -LiteralPath $f -Encoding UTF8) -join [char]10)"
pause
exit /b
#>
# --- Desde aquí es PowerShell ---
# Instala RustDesk oficial (firmado), crea el acceso «Emm Remote» y, si lo pides,
# activa el acceso desatendido con una contraseña que escribes tú aquí mismo.
# Nada se guarda en este archivo ni en el repo.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = 'Emm Remote - Instalador'
$PinnedVersion = '1.5.1'
$Exe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'

function Paso($t) { Write-Host ''; Write-Host "== $t" -ForegroundColor Cyan }
function RD { (& $Exe @args | Out-String).Trim() }

Write-Host '============================================' -ForegroundColor Red
Write-Host '   EMM REMOTE - instalador'                   -ForegroundColor Red
Write-Host '   Solo para equipos propios o con permiso.'  -ForegroundColor Red
Write-Host '============================================' -ForegroundColor Red

# 1) RustDesk
Paso 'Programa de control remoto (RustDesk oficial)'
if (Test-Path $Exe) {
    Write-Host 'Ya estaba instalado.'
} else {
    $url = $null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -TimeoutSec 20
        $url = ($rel.assets | Where-Object { $_.name -match '^rustdesk-[\d.]+-x86_64\.exe$' } | Select-Object -First 1).browser_download_url
    } catch { }
    if (-not $url) { $url = "https://github.com/rustdesk/rustdesk/releases/download/$PinnedVersion/rustdesk-$PinnedVersion-x86_64.exe" }
    $tmp = Join-Path $env:TEMP 'emm-remote-rustdesk.exe'
    Write-Host "Descargando $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing

    $sig = Get-AuthenticodeSignature $tmp
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'PURSLANE') {
        Remove-Item $tmp -Force
        throw "La firma del instalador no es la oficial de RustDesk ($($sig.Status), $($sig.SignerCertificate.Subject)). No se instaló nada."
    }
    Write-Host 'Firma oficial verificada.' -ForegroundColor Green
    Write-Host 'Instalando (tarda menos de un minuto)…'
    Start-Process -FilePath $tmp -ArgumentList '--silent-install' -Wait
    for ($i = 0; $i -lt 90 -and -not (Test-Path $Exe); $i++) { Start-Sleep 2 }
    if (-not (Test-Path $Exe)) { throw 'La instalación no terminó. Vuelve a correr este instalador.' }
    Start-Sleep 5
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Host 'Instalado.' -ForegroundColor Green
}

# El servicio de RustDesk es el que aplica contraseña y opciones
$svc = Get-Service -Name RustDesk -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') { Start-Service -Name RustDesk; Start-Sleep 5 }

# 2) Acceso directo «Emm Remote» en el escritorio
$lnk = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Emm Remote.lnk'
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = $Exe
$sh.IconLocation = "$Exe,0"
$sh.Description = 'Emm Remote - control remoto de mis equipos'
$sh.Save()
Write-Host 'Acceso directo "Emm Remote" creado en el escritorio.'

# 3) Acceso desatendido (opcional)
Paso 'Acceso desatendido (entrar sin que alguien acepte aquí)'
Write-Host 'Si dices que no, cada conexión necesitará el código temporal que muestra Emm Remote'
Write-Host 'o que alguien la acepte en esta computadora.'
$r = Read-Host '¿Activarlo en ESTA computadora? (s/n)'
if ($r -match '^[sS]') {
    while ($true) {
        $p1 = Read-Host 'Escribe una contraseña fuerte (12+ caracteres, no se ve al escribir)' -AsSecureString
        $p2 = Read-Host 'Repítela' -AsSecureString
        $a = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        $b = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
        if ($a -ne $b) { Write-Host 'No coinciden. Otra vez.' -ForegroundColor Yellow; continue }
        if ($a.Length -lt 12) { Write-Host 'Muy corta: usa 12 caracteres o más.' -ForegroundColor Yellow; continue }
        break
    }
    $out = RD --password $a
    $a = $null; $b = $null
    RD --option verification-method use-both-passwords | Out-Null
    RD --option approve-mode password | Out-Null
    RD --option allow-hide-cm N | Out-Null
    if ($out -match 'Done') {
        Write-Host 'Acceso desatendido activado. Guarda la contraseña en tu gestor de contraseñas.' -ForegroundColor Green
    } else {
        Write-Host "RustDesk respondió: $out" -ForegroundColor Yellow
        Write-Host 'Ponla a mano: Emm Remote > Ajustes > Seguridad > Contraseña permanente.' -ForegroundColor Yellow
    }
} else {
    Write-Host 'Sin acceso desatendido.'
}

# 4) Datos para conectarte
Paso 'Listo'
Start-Process $Exe
Start-Sleep 4
$id = RD --get-id
Write-Host ''
Write-Host "   ID de esta computadora:  $id" -ForegroundColor Green
Write-Host ''
Write-Host 'Para controlarla desde la Mac o el celular: abre Emm Remote allá y escribe este ID.'
Write-Host 'Mientras haya alguien conectado, aquí se verá la ventana de Emm Remote con un botón para desconectar.'
