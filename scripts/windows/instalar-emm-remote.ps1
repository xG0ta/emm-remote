# Emm Remote — preparación en Windows.
# Ejecutar en PowerShell como administrador:
#   powershell -ExecutionPolicy Bypass -File .\scripts\windows\instalar-emm-remote.ps1
# Instala RustDesk y Tailscale oficiales con winget y aplica las opciones seguras:
# conexión directa por IP y lista blanca (solo Tailscale y red de casa).
# No guarda ni pide contraseñas: la contraseña permanente (acceso desatendido)
# la pones tú en RustDesk, en este mismo equipo.
$ErrorActionPreference = 'Stop'

$Whitelist = '100.64.0.0/10,fd7a:115c:a1e0::/48,192.168.0.0/16'
$Exe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'

Write-Host '== Emm Remote: preparación en Windows ==' -ForegroundColor Cyan

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Abre PowerShell con "Ejecutar como administrador" y vuelve a correr este script.' -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host 'Falta winget (Instalador de aplicaciones). Instálalo desde Microsoft Store.' -ForegroundColor Yellow
    exit 1
}

# 1) RustDesk
if (Test-Path $Exe) {
    Write-Host 'RustDesk ya está instalado.'
} else {
    Write-Host 'Instalando RustDesk (winget, paquete oficial)…'
    winget install --id RustDesk.RustDesk -e --source winget --accept-package-agreements
}

# 2) Tailscale
if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    Write-Host 'Tailscale ya está instalado.'
} else {
    Write-Host 'Instalando Tailscale (winget, paquete oficial)…'
    winget install --id tailscale.tailscale -e --source winget --accept-package-agreements
    Write-Host 'Abre Tailscale desde la bandeja e inicia sesión con la misma cuenta que en la Mac.' -ForegroundColor Yellow
}

if (-not (Test-Path $Exe)) {
    Write-Host "No encuentro $Exe. Abre RustDesk una vez, elige Instalar, y vuelve a correr el script." -ForegroundColor Yellow
    exit 1
}

# 3) Opciones seguras (las aplica el servicio de RustDesk)
Write-Host 'Aplicando opciones de seguridad…'
Start-Process -FilePath $Exe -ArgumentList '--option', 'direct-server', 'Y' -Wait -WindowStyle Hidden
Start-Process -FilePath $Exe -ArgumentList '--option', 'whitelist', $Whitelist -Wait -WindowStyle Hidden
$check = (& $Exe --option whitelist | Out-String).Trim()
if ($check -eq $Whitelist) {
    Write-Host "Listo: conexión directa activada y lista blanca = $Whitelist" -ForegroundColor Green
} else {
    Write-Host 'No pude confirmar las opciones por línea de comandos. Hazlo a mano en RustDesk > Ajustes > Seguridad:' -ForegroundColor Yellow
    Write-Host '  - Activa "Habilitar acceso directo por IP" (puerto 21118)'
    Write-Host "  - En 'Lista blanca de IP' pon: $Whitelist"
}

# 4) Firewall: el puerto directo solo desde Tailscale y la red de casa
$rule = 'Emm Remote (RustDesk directo 21118)'
Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol TCP -LocalPort 21118 `
    -RemoteAddress '100.64.0.0/10', 'fd7a:115c:a1e0::/48', 'LocalSubnet' -Action Allow | Out-Null
Write-Host "Regla de firewall creada: $rule"

# 5) Datos para conectarte
Write-Host ''
if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    $ts = (& tailscale ip -4 2>$null | Select-Object -First 1)
    if ($ts) { Write-Host "IP de Tailscale de esta PC: $ts" -ForegroundColor Cyan }
}
Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host "IP en la red de casa: $($_.IPAddress)" -ForegroundColor Cyan }
Write-Host ''
Write-Host 'Siguiente: sigue docs\PRUEBAS.md'
