#requires -Version 5.1
<#
.SYNOPSIS
    Network Troubleshooting Toolkit.

.DESCRIPTION
    Menu-driven PowerShell toolkit for L1/L2 IT support network troubleshooting.
    Collects adapter, IP, DNS, gateway, Wi-Fi, proxy, firewall, route, ARP,
    netstat, TCP port, traceroute, and Microsoft 365 connectivity information.

.NOTES
    Author: Dewald Pretorius / Dtech IT Solutions
    Version: 1.0.0
    Most options are diagnostic-only. Repair options require confirmation.
#>

[CmdletBinding()]
param(
    [switch]$RunAll,
    [string]$OutputPath,
    [string]$TargetHost = 'www.microsoft.com'
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.0'
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-ReportFolder {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $Path = Join-Path $desktop 'Network_Troubleshooting_Reports'
    }
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    return $Path
}

$ReportRoot = Initialize-ReportFolder -Path $OutputPath
$LogFile = Join-Path $ReportRoot "NetworkTroubleshooting_$RunStamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}

function Pause-Menu {
    Write-Host
    [void](Read-Host 'Press Enter to return to the menu')
}

function Confirm-ToolkitAction {
    param([Parameter(Mandatory)] [string]$Message)
    $answer = Read-Host "$Message Type YES to continue"
    return ($answer -eq 'YES')
}

function Show-Header {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '   NETWORK TROUBLESHOOTING TOOLKIT' -ForegroundColor Cyan
    Write-Host "   Version $ScriptVersion" -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("   Computer : {0}" -f $env:COMPUTERNAME)
    Write-Host ("   User     : {0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
    Write-Host ("   Admin    : {0}" -f (Test-IsAdministrator))
    Write-Host ("   Reports  : {0}" -f $ReportRoot)
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host
}

function New-Check {
    param(
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Name,
        [ValidateSet('OK','Warning','Critical','Info')] [string]$Status = 'Info',
        [string]$Value = '',
        [string]$Recommendation = ''
    )
    [PSCustomObject]@{
        Category       = $Category
        Name           = $Name
        Status         = $Status
        Value          = $Value
        Recommendation = $Recommendation
    }
}

function Export-ToolkitReport {
    param(
        [Parameter(Mandatory)] [object[]]$Checks,
        [Parameter(Mandatory)] [string]$ReportName,
        [switch]$OpenReport
    )
    $safeName = $ReportName -replace '[^\w\-]', '_'
    $csvPath = Join-Path $ReportRoot "$safeName`_$RunStamp.csv"
    $jsonPath = Join-Path $ReportRoot "$safeName`_$RunStamp.json"
    $htmlPath = Join-Path $ReportRoot "$safeName`_$RunStamp.html"
    $Checks | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $Checks | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    $htmlHeader = @"
<h1>$ReportName</h1>
<p><b>Computer:</b> $env:COMPUTERNAME<br><b>User:</b> $env:USERDOMAIN\$env:USERNAME<br><b>Generated:</b> $(Get-Date)<br><b>Administrator:</b> $(Test-IsAdministrator)</p>
<style>body{font-family:Segoe UI,Arial;margin:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;vertical-align:top}th{background:#eee}.OK{color:green;font-weight:bold}.Warning{color:#b8860b;font-weight:bold}.Critical{color:red;font-weight:bold}.Info{color:#555;font-weight:bold}</style>
"@
    $table = $Checks | ConvertTo-Html -Fragment -Property Category,Name,Status,Value,Recommendation
    $table = $table -replace '<td>OK</td>', '<td class="OK">OK</td>'
    $table = $table -replace '<td>Warning</td>', '<td class="Warning">Warning</td>'
    $table = $table -replace '<td>Critical</td>', '<td class="Critical">Critical</td>'
    $table = $table -replace '<td>Info</td>', '<td class="Info">Info</td>'
    ConvertTo-Html -Title $ReportName -Body ($htmlHeader + $table) | Set-Content -Path $htmlPath -Encoding UTF8
    Write-Log "Created HTML report: $htmlPath" 'SUCCESS'
    Write-Log "Created CSV report: $csvPath" 'SUCCESS'
    Write-Log "Created JSON report: $jsonPath" 'SUCCESS'
    if ($OpenReport) {
        try { Start-Process $htmlPath } catch { Write-Log "Could not open report automatically: $($_.Exception.Message)" 'WARN' }
    }
}

function Show-ChecksAndExport {
    param([object[]]$Checks, [string]$ReportName, [switch]$OpenReport)
    $Checks | Sort-Object Category, Status, Name | Format-Table Category, Name, Status, Value, Recommendation -AutoSize -Wrap
    Export-ToolkitReport -Checks $Checks -ReportName $ReportName -OpenReport:$OpenReport
}

function Get-AdapterChecks {
    $checks = @()
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop
        if (-not $adapters) {
            $checks += New-Check 'Adapters' 'Network adapters' 'Critical' 'None found' 'Check Device Manager and network drivers.'
            return $checks
        }
        foreach ($adapter in $adapters) {
            $status = if ($adapter.Status -eq 'Up') { 'OK' } elseif ($adapter.Status -eq 'Disabled') { 'Warning' } else { 'Info' }
            $value = "Status: $($adapter.Status); Speed: $($adapter.LinkSpeed); MAC: $($adapter.MacAddress)"
            $checks += New-Check 'Adapters' $adapter.Name $status $value 'Confirm expected adapter is enabled and connected.'
        }
        $upCount = @($adapters | Where-Object Status -eq 'Up').Count
        $checks += New-Check 'Adapters' 'Active adapter count' ($(if ($upCount -gt 0) { 'OK' } else { 'Critical' })) "$upCount active adapter(s)" 'If zero, check cable, Wi-Fi, docking station, switch port, or drivers.'
    }
    catch { $checks += New-Check 'Adapters' 'Adapter query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.' }
    return $checks
}

function Get-IpGatewayChecks {
    $checks = @()
    try {
        Get-NetIPConfiguration -ErrorAction Stop | ForEach-Object {
            $ipv4 = ($_.IPv4Address | Select-Object -First 1).IPAddress
            $prefix = ($_.IPv4Address | Select-Object -First 1).PrefixLength
            $gateway = ($_.IPv4DefaultGateway | Select-Object -First 1).NextHop
            $dnsServers = ($_.DNSServer.ServerAddresses -join ', ')
            if ($ipv4 -like '169.254.*') { $status = 'Critical'; $rec = 'APIPA address detected. DHCP likely failed.' }
            elseif ([string]::IsNullOrWhiteSpace($ipv4)) { $status = 'Warning'; $rec = 'No IPv4 address found.' }
            else { $status = 'OK'; $rec = 'IPv4 configuration exists.' }
            $checks += New-Check 'IP Configuration' $_.InterfaceAlias $status "IPv4: $ipv4/$prefix; Gateway: $gateway; DNS: $dnsServers" $rec
            if ($gateway) {
                $gatewayPing = Test-Connection -ComputerName $gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
                $checks += New-Check 'Gateway' "Ping gateway $gateway" ($(if ($gatewayPing) { 'OK' } else { 'Critical' })) "$gatewayPing" 'If this fails, check local network path, VLAN, Wi-Fi, router, or firewall.'
            } else {
                $checks += New-Check 'Gateway' "Gateway on $($_.InterfaceAlias)" 'Warning' 'No default gateway' 'No default gateway can prevent internet and routed network access.'
            }
        }
    }
    catch { $checks += New-Check 'IP Configuration' 'IP query' 'Critical' $_.Exception.Message 'Run PowerShell as Administrator and retry.' }
    return $checks
}

function Get-DnsChecks {
    param([string]$HostName = 'www.microsoft.com')
    $checks = @()
    $names = @($HostName, 'www.microsoft.com', 'login.microsoftonline.com') | Select-Object -Unique
    foreach ($name in $names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        try {
            $records = Resolve-DnsName -Name $name -ErrorAction Stop
            $summary = ($records | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress -Unique) -join ', '
            if ([string]::IsNullOrWhiteSpace($summary)) { $summary = 'Resolved without direct IP summary' }
            $checks += New-Check 'DNS' "Resolve $name" 'OK' $summary 'DNS query succeeded.'
        }
        catch { $checks += New-Check 'DNS' "Resolve $name" 'Critical' $_.Exception.Message 'Check DNS servers, VPN, proxy, firewall, or filtering.' }
    }
    try {
        Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object {
            $servers = ($_.ServerAddresses -join ', ')
            $status = if ([string]::IsNullOrWhiteSpace($servers)) { 'Warning' } else { 'Info' }
            $checks += New-Check 'DNS' "DNS servers $($_.InterfaceAlias)" $status $servers 'Confirm DNS servers match network design.'
        }
    }
    catch { $checks += New-Check 'DNS' 'DNS server query' 'Warning' $_.Exception.Message 'Could not query DNS client server addresses.' }
    return $checks
}

function Get-ConnectivityChecks {
    param([string]$HostName = 'www.microsoft.com')
    $checks = @()
    $targets = @('1.1.1.1','8.8.8.8','www.microsoft.com','login.microsoftonline.com',$HostName) | Select-Object -Unique
    foreach ($target in $targets) {
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $ping = Test-Connection -ComputerName $target -Count 2 -Quiet -ErrorAction SilentlyContinue
        $checks += New-Check 'Connectivity' "Ping $target" ($(if ($ping) { 'OK' } else { 'Warning' })) "$ping" 'ICMP can be blocked even when HTTPS works.'
        if ($target -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
            try {
                $tcp = Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
                $checks += New-Check 'Connectivity' "TCP 443 $target" ($(if ($tcp) { 'OK' } else { 'Warning' })) "$tcp" 'If this fails, check firewall, proxy, VPN, or internet access.'
            }
            catch { $checks += New-Check 'Connectivity' "TCP 443 $target" 'Warning' $_.Exception.Message 'Test-NetConnection failed.' }
        }
    }
    return $checks
}

function Get-WiFiChecks {
    $checks = @()
    try {
        $interfaces = (& netsh.exe wlan show interfaces 2>&1) -join ' | '
        if ($interfaces -match 'There is no wireless interface') {
            $checks += New-Check 'Wi-Fi' 'Wireless interface' 'Info' 'No wireless interface found' 'Device may be desktop, VM, or missing Wi-Fi driver.'
        } else {
            $state = if ($interfaces -match 'State\s+:\s+connected') { 'OK' } elseif ($interfaces -match 'State\s+:\s+disconnected') { 'Warning' } else { 'Info' }
            $checks += New-Check 'Wi-Fi' 'Wireless interface details' $state $interfaces 'Review SSID, signal, radio type, channel, and authentication.'
        }
        $profiles = (& netsh.exe wlan show profiles 2>&1) -join ' | '
        $checks += New-Check 'Wi-Fi' 'Saved Wi-Fi profiles' 'Info' $profiles 'This does not export Wi-Fi passwords.'
    }
    catch { $checks += New-Check 'Wi-Fi' 'Wi-Fi query' 'Warning' $_.Exception.Message 'Could not query WLAN information.' }
    return $checks
}

function Get-ProxyFirewallChecks {
    $checks = @()
    try {
        $winHttpProxy = (& netsh.exe winhttp show proxy 2>&1) -join ' '
        $checks += New-Check 'Proxy' 'WinHTTP proxy' 'Info' $winHttpProxy 'Unexpected WinHTTP proxy settings can break updates and Microsoft 365 sign-in.'
    }
    catch { $checks += New-Check 'Proxy' 'WinHTTP proxy' 'Warning' $_.Exception.Message 'Could not query WinHTTP proxy.' }
    try {
        $proxyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        $proxy = Get-ItemProperty -Path $proxyPath -ErrorAction Stop
        $value = "ProxyEnable: $([bool]$proxy.ProxyEnable); ProxyServer: $($proxy.ProxyServer); AutoConfigURL: $($proxy.AutoConfigURL)"
        $checks += New-Check 'Proxy' 'User proxy settings' 'Info' $value 'Unexpected user proxy settings can affect browsers and Microsoft apps.'
    }
    catch { $checks += New-Check 'Proxy' 'User proxy settings' 'Warning' $_.Exception.Message 'Could not query user proxy registry settings.' }
    try {
        Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
            $status = if ($_.Enabled) { 'OK' } else { 'Warning' }
            $value = "Enabled: $($_.Enabled); DefaultInbound: $($_.DefaultInboundAction); DefaultOutbound: $($_.DefaultOutboundAction)"
            $checks += New-Check 'Firewall' "Firewall profile $($_.Name)" $status $value 'Firewall should normally be enabled unless managed by security software.'
        }
    }
    catch { $checks += New-Check 'Firewall' 'Firewall profile query' 'Warning' $_.Exception.Message 'Could not query firewall profiles.' }
    return $checks
}

function Export-NetworkCommandOutputs {
    $checks = @()
    $commands = @(
        @{ Name = 'ipconfig_all'; Command = 'ipconfig.exe'; Arguments = '/all' },
        @{ Name = 'route_print'; Command = 'route.exe'; Arguments = 'print' },
        @{ Name = 'arp_a'; Command = 'arp.exe'; Arguments = '-a' },
        @{ Name = 'netstat_ano'; Command = 'netstat.exe'; Arguments = '-ano' }
    )
    foreach ($item in $commands) {
        try {
            $path = Join-Path $ReportRoot "$($item.Name)_$RunStamp.txt"
            & $item.Command $item.Arguments 2>&1 | Out-File -FilePath $path -Encoding UTF8
            $checks += New-Check 'Exports' $item.Name 'OK' $path 'Attach this file to tickets when deeper evidence is needed.'
        }
        catch { $checks += New-Check 'Exports' $item.Name 'Warning' $_.Exception.Message 'Command export failed.' }
    }
    return $checks
}

function Invoke-TcpPortTest {
    Show-Header
    Write-Host '[7] TCP port test' -ForegroundColor Cyan
    $hostName = Read-Host 'Enter hostname or IP'
    if ([string]::IsNullOrWhiteSpace($hostName)) { Write-Log 'No host entered.' 'WARN'; Pause-Menu; return }
    $portInput = Read-Host 'Enter TCP port, for example 443, 3389, 445, 25'
    $port = 0
    if (-not [int]::TryParse($portInput, [ref]$port) -or $port -lt 1 -or $port -gt 65535) { Write-Log 'Invalid TCP port.' 'WARN'; Pause-Menu; return }
    $checks = @()
    try {
        $result = Test-NetConnection -ComputerName $hostName -Port $port -WarningAction SilentlyContinue
        $status = if ($result.TcpTestSucceeded) { 'OK' } else { 'Warning' }
        $value = "TcpTestSucceeded: $($result.TcpTestSucceeded); RemoteAddress: $($result.RemoteAddress)"
        $checks += New-Check 'TCP Test' "$hostName`:$port" $status $value 'If this fails, check firewall, routing, DNS, VPN, service state, or port exposure.'
    }
    catch { $checks += New-Check 'TCP Test' "$hostName`:$port" 'Warning' $_.Exception.Message 'Test-NetConnection failed.' }
    Show-ChecksAndExport -Checks $checks -ReportName "TCP_Port_Test_$hostName`_$port"
    Pause-Menu
}

function Invoke-Traceroute {
    Show-Header
    Write-Host '[8] Traceroute' -ForegroundColor Cyan
    $hostName = Read-Host 'Enter hostname or IP'
    if ([string]::IsNullOrWhiteSpace($hostName)) { Write-Log 'No host entered.' 'WARN'; Pause-Menu; return }
    try {
        $safeTarget = $hostName -replace '[^\w\-\.]', '_'
        $path = Join-Path $ReportRoot "tracert_$safeTarget`_$RunStamp.txt"
        tracert.exe $hostName 2>&1 | Tee-Object -FilePath $path
        Write-Log "Traceroute exported: $path" 'SUCCESS'
    }
    catch { Write-Log "Traceroute failed: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Invoke-FlushDns {
    Show-Header
    Write-Host '[11] Flush DNS cache' -ForegroundColor Cyan
    Write-Host 'This clears the local DNS resolver cache.' -ForegroundColor Yellow
    if (-not (Confirm-ToolkitAction 'Flush DNS resolver cache now?')) { Write-Log 'Operation cancelled.'; Pause-Menu; return }
    try { Clear-DnsClientCache; Write-Log 'DNS resolver cache cleared.' 'SUCCESS' }
    catch { ipconfig.exe /flushdns; Write-Log 'DNS resolver cache cleared using ipconfig.' 'SUCCESS' }
    Pause-Menu
}

function Invoke-AdapterRestart {
    Show-Header
    Write-Host '[12] Restart a network adapter' -ForegroundColor Cyan
    Write-Host 'WARNING: This can disconnect the current network session.' -ForegroundColor Yellow
    try {
        $adapters = Get-NetAdapter | Sort-Object Name
        for ($i = 0; $i -lt $adapters.Count; $i++) { Write-Host ('{0,3}. {1,-30} {2,-12} {3}' -f ($i + 1), $adapters[$i].Name, $adapters[$i].Status, $adapters[$i].InterfaceDescription) }
        Write-Host
        $selection = Read-Host 'Select adapter number, or 0 to cancel'
        $number = 0
        if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 0 -or $number -gt $adapters.Count) { Write-Log 'Invalid selection.' 'WARN'; Pause-Menu; return }
        if ($number -eq 0) { return }
        $adapter = $adapters[$number - 1]
        if (-not (Confirm-ToolkitAction "Restart adapter '$($adapter.Name)'?")) { Write-Log 'Operation cancelled.'; Pause-Menu; return }
        Disable-NetAdapter -Name $adapter.Name -Confirm:$false
        Start-Sleep -Seconds 3
        Enable-NetAdapter -Name $adapter.Name -Confirm:$false
        Write-Log "Adapter restarted: $($adapter.Name)" 'SUCCESS'
    }
    catch { Write-Log "Adapter restart failed: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Invoke-RenewDhcp {
    Show-Header
    Write-Host '[13] Renew DHCP lease' -ForegroundColor Cyan
    Write-Host 'WARNING: This can briefly interrupt network connectivity.' -ForegroundColor Yellow
    if (-not (Confirm-ToolkitAction 'Run ipconfig /release and /renew now?')) { Write-Log 'Operation cancelled.'; Pause-Menu; return }
    try { ipconfig.exe /release; ipconfig.exe /renew; Write-Log 'DHCP release/renew completed.' 'SUCCESS' }
    catch { Write-Log "DHCP renew failed: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Invoke-WinsockReset {
    Show-Header
    Write-Host '[14] Reset Winsock and TCP/IP stack' -ForegroundColor Cyan
    Write-Host 'WARNING: This changes network stack settings and requires a reboot.' -ForegroundColor Yellow
    if (-not (Test-IsAdministrator)) { Write-Log 'Administrator rights are required for this action.' 'ERROR'; Pause-Menu; return }
    if (-not (Confirm-ToolkitAction 'Reset Winsock and TCP/IP stack?')) { Write-Log 'Operation cancelled.'; Pause-Menu; return }
    try { netsh.exe winsock reset; netsh.exe int ip reset; Write-Log 'Winsock and TCP/IP reset commands completed. Reboot required.' 'SUCCESS' }
    catch { Write-Log "Network stack reset failed: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

function Invoke-QuickNetworkSummary {
    Show-Header
    Write-Host '[1] Quick network summary' -ForegroundColor Cyan
    $checks = @()
    $checks += Get-AdapterChecks
    $checks += Get-IpGatewayChecks
    $checks += Get-ConnectivityChecks -HostName $TargetHost
    Show-ChecksAndExport -Checks $checks -ReportName 'Quick_Network_Summary'
    Pause-Menu
}

function Invoke-FullNetworkReport {
    Show-Header
    Write-Host '[2] Full network troubleshooting report' -ForegroundColor Cyan
    $checks = @()
    $checks += Get-AdapterChecks
    $checks += Get-IpGatewayChecks
    $checks += Get-DnsChecks -HostName $TargetHost
    $checks += Get-ConnectivityChecks -HostName $TargetHost
    $checks += Get-WiFiChecks
    $checks += Get-ProxyFirewallChecks
    $checks += Export-NetworkCommandOutputs
    Show-ChecksAndExport -Checks $checks -ReportName 'Full_Network_Troubleshooting_Report' -OpenReport
    Pause-Menu
}

function Invoke-DnsMenu {
    Show-Header
    Write-Host '[5] DNS troubleshooting' -ForegroundColor Cyan
    $hostName = Read-Host "Enter DNS name to test. Default is $TargetHost"
    if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName = $TargetHost }
    $checks = Get-DnsChecks -HostName $hostName
    Show-ChecksAndExport -Checks $checks -ReportName 'DNS_Troubleshooting_Check'
    Pause-Menu
}

function Invoke-ConnectivityMenu {
    Show-Header
    Write-Host '[6] Public and Microsoft 365 connectivity check' -ForegroundColor Cyan
    $hostName = Read-Host "Enter optional custom target. Default is $TargetHost"
    if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName = $TargetHost }
    $checks = Get-ConnectivityChecks -HostName $hostName
    Show-ChecksAndExport -Checks $checks -ReportName 'Connectivity_Check'
    Pause-Menu
}

function Invoke-SingleCheck {
    param([Parameter(Mandatory)] [string]$Name)
    Show-Header
    $checks = switch ($Name) {
        'Adapters'      { Get-AdapterChecks }
        'IPGateway'     { Get-IpGatewayChecks }
        'WiFi'          { Get-WiFiChecks }
        'ProxyFirewall' { Get-ProxyFirewallChecks }
        'Exports'       { Export-NetworkCommandOutputs }
    }
    Show-ChecksAndExport -Checks $checks -ReportName "$Name`_Check"
    Pause-Menu
}

function Open-ReportFolder {
    Show-Header
    Write-Host '[16] Open report folder' -ForegroundColor Cyan
    try { Start-Process explorer.exe -ArgumentList "`"$ReportRoot`""; Write-Log "Opened report folder: $ReportRoot" 'SUCCESS' }
    catch { Write-Log "Could not open report folder: $($_.Exception.Message)" 'ERROR' }
    Pause-Menu
}

Write-Log "Network Troubleshooting Toolkit v$ScriptVersion started."
Write-Log "Administrator: $(Test-IsAdministrator)"
Write-Log "Report folder: $ReportRoot"

if ($RunAll) {
    Invoke-FullNetworkReport
    return
}

do {
    Show-Header
    Write-Host '  1. Quick network summary'
    Write-Host '  2. Full network troubleshooting report'
    Write-Host '  3. Adapter status and driver info'
    Write-Host '  4. IP configuration and gateway check'
    Write-Host '  5. DNS troubleshooting'
    Write-Host '  6. Public and Microsoft 365 connectivity check'
    Write-Host '  7. TCP port test'
    Write-Host '  8. Traceroute'
    Write-Host '  9. Wi-Fi information'
    Write-Host ' 10. Proxy and firewall check'
    Write-Host ' 11. Flush DNS cache'
    Write-Host ' 12. Restart a network adapter'
    Write-Host ' 13. Renew DHCP lease'
    Write-Host ' 14. Reset Winsock and TCP/IP stack'
    Write-Host ' 15. Export route, ARP, netstat, and ipconfig data'
    Write-Host ' 16. Open report folder'
    Write-Host
    Write-Host '  0. Exit'
    Write-Host
    $choice = Read-Host 'Select an option'
    switch ($choice) {
        '1'  { Invoke-QuickNetworkSummary }
        '2'  { Invoke-FullNetworkReport }
        '3'  { Invoke-SingleCheck -Name 'Adapters' }
        '4'  { Invoke-SingleCheck -Name 'IPGateway' }
        '5'  { Invoke-DnsMenu }
        '6'  { Invoke-ConnectivityMenu }
        '7'  { Invoke-TcpPortTest }
        '8'  { Invoke-Traceroute }
        '9'  { Invoke-SingleCheck -Name 'WiFi' }
        '10' { Invoke-SingleCheck -Name 'ProxyFirewall' }
        '11' { Invoke-FlushDns }
        '12' { Invoke-AdapterRestart }
        '13' { Invoke-RenewDhcp }
        '14' { Invoke-WinsockReset }
        '15' { Invoke-SingleCheck -Name 'Exports' }
        '16' { Open-ReportFolder }
        '0'  { Write-Log 'Toolkit closed by the user.'; Write-Host 'Goodbye.' -ForegroundColor Green }
        default { Write-Host 'Invalid selection.' -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
    }
}
while ($choice -ne '0')
