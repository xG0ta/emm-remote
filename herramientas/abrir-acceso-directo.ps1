# Emm Remote - convierte esta PC en su propio servidor (conexion directa por IP).
# Correr en PowerShell como administrador:
#   irm https://raw.githubusercontent.com/xG0ta/emm-remote/main/herramientas/abrir-acceso-directo.ps1 | iex
# Que hace:
#   1. Activa en RustDesk la conexion directa por IP (puerto 21118).
#   2. Abre ese puerto en el Firewall de Windows.
#   3. Pide al modem, por UPnP, que reenvie el puerto 21118 a esta PC (sin contrasena del modem).
#   4. Compara la IP que ve el modem con la IP publica real para saber si hay CGNAT.
# No guarda contrasenas. La conexion sigue pidiendo la contrasena de RustDesk o aceptar aqui.
$ErrorActionPreference = 'Stop'
$Port = 21118
$Exe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'

function Paso($t) { Write-Host ''; Write-Host "== $t" -ForegroundColor Cyan }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Abre PowerShell como administrador.' }
if (-not (Test-Path $Exe)) { throw "No encuentro $Exe. Instala Emm Remote primero." }

# 1) RustDesk
Paso 'RustDesk: conexion directa por IP'
$svc = Get-Service -Name RustDesk -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Running') { Start-Service -Name RustDesk; Start-Sleep 5 }
Start-Process -FilePath $Exe -ArgumentList '--option', 'direct-server', 'Y' -WindowStyle Hidden
Start-Sleep 3
$v = (& $Exe --option direct-server | Out-String).Trim()
Write-Host "direct-server = $v"

# 2) Firewall
Paso 'Firewall de Windows'
$rule = 'Emm Remote (RustDesk directo 21118)'
Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Any | Out-Null
Write-Host "Regla creada: $rule"

# 3) UPnP en el modem
Paso 'Modem: abrir puerto por UPnP'
$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
$localIp = $cfg.IPv4Address[0].IPAddress
Write-Host "IP local de esta PC: $localIp (puerta de enlace $($cfg.IPv4DefaultGateway.NextHop))"

$udp = New-Object Net.Sockets.UdpClient
$udp.Client.ReceiveTimeout = 3000
$ep = New-Object Net.IPEndPoint ([Net.IPAddress]::Parse('239.255.255.250')), 1900
$locations = @()
foreach ($st in 'urn:schemas-upnp-org:device:InternetGatewayDevice:1', 'urn:schemas-upnp-org:device:InternetGatewayDevice:2', 'upnp:rootdevice') {
    $msg = "M-SEARCH * HTTP/1.1`r`nHOST: 239.255.255.250:1900`r`nMAN: `"ssdp:discover`"`r`nMX: 2`r`nST: $st`r`n`r`n"
    $bytes = [Text.Encoding]::ASCII.GetBytes($msg)
    [void]$udp.Send($bytes, $bytes.Length, $ep)
    $deadline = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $deadline) {
        try {
            $remote = New-Object Net.IPEndPoint ([Net.IPAddress]::Any), 0
            $resp = [Text.Encoding]::ASCII.GetString($udp.Receive([ref]$remote))
            if ($resp -match '(?im)^location:\s*(\S+)') { $locations += $Matches[1] }
        } catch { break }
    }
    if ($locations) { break }
}
$udp.Close()
$locations = $locations | Select-Object -Unique

$ctrl = $null; $stype = $null
foreach ($loc in $locations) {
    try {
        $xml = [xml](Invoke-WebRequest $loc -UseBasicParsing -TimeoutSec 5).Content
        $svcNode = $xml.SelectNodes('//*[local-name()="service"]') | Where-Object { $_.serviceType -match 'WAN(IP|PPP)Connection' } | Select-Object -First 1
        if ($svcNode) {
            $u = [Uri]$loc
            $ctrl = (New-Object Uri ($u, $svcNode.controlURL)).AbsoluteUri
            $stype = $svcNode.serviceType
            break
        }
    } catch { }
}

function Soap($action, $body) {
    $env = "<?xml version=`"1.0`"?><s:Envelope xmlns:s=`"http://schemas.xmlsoap.org/soap/envelope/`" s:encodingStyle=`"http://schemas.xmlsoap.org/soap/encoding/`"><s:Body><u:$action xmlns:u=`"$stype`">$body</u:$action></s:Body></s:Envelope>"
    Invoke-WebRequest $ctrl -Method Post -UseBasicParsing -TimeoutSec 8 -ContentType 'text/xml; charset="utf-8"' `
        -Headers @{ SOAPAction = "`"$stype#$action`"" } -Body $env
}

$routerIp = $null
if (-not $ctrl) {
    Write-Host 'El modem no respondio por UPnP (puede estar apagado en el modem).' -ForegroundColor Yellow
} else {
    Write-Host "Modem UPnP encontrado: $ctrl"
    try {
        $r = [xml](Soap 'GetExternalIPAddress' '').Content
        $routerIp = $r.SelectSingleNode('//*[local-name()="NewExternalIPAddress"]').InnerText
    } catch { }
    try {
        [void](Soap 'DeletePortMapping' "<NewRemoteHost></NewRemoteHost><NewExternalPort>$Port</NewExternalPort><NewProtocol>TCP</NewProtocol>")
    } catch { }
    try {
        [void](Soap 'AddPortMapping' "<NewRemoteHost></NewRemoteHost><NewExternalPort>$Port</NewExternalPort><NewProtocol>TCP</NewProtocol><NewInternalPort>$Port</NewInternalPort><NewInternalClient>$localIp</NewInternalClient><NewEnabled>1</NewEnabled><NewPortMappingDescription>Emm Remote</NewPortMappingDescription><NewLeaseDuration>0</NewLeaseDuration>")
        Write-Host "Puerto $Port reenviado a $localIp" -ForegroundColor Green
    } catch {
        Write-Host "El modem rechazo abrir el puerto: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 4) IP publica y CGNAT
Paso 'IP publica'
$publicIp = (Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 10).Trim()
Write-Host "IP publica real: $publicIp"
if ($routerIp) { Write-Host "IP que ve el modem: $routerIp" }
if ($routerIp -and $routerIp -ne $publicIp) {
    Write-Host 'CGNAT: el modem no tiene IP publica propia. La conexion directa desde fuera NO va a funcionar; usa Tailscale.' -ForegroundColor Red
} elseif ($routerIp) {
    Write-Host "Sin CGNAT. Desde fuera, en Emm Remote escribe:  $publicIp" -ForegroundColor Green
}
Write-Host ''
Write-Host "RESULTADO local=$localIp publica=$publicIp modem=$routerIp upnp=$([bool]$ctrl)"
