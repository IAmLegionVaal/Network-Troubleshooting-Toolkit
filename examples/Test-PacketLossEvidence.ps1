#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only, timestamped ICMP packet loss and latency collector.
.EXAMPLE
    .\Test-PacketLossEvidence.ps1 -TargetHosts 1.1.1.1,8.8.8.8 -Count 30 -CsvPath .\loss.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$TargetHosts,
    [ValidateRange(1,200)][int]$Count = 30,
    [ValidateRange(100,10000)][int]$TimeoutMs = 2000,
    [string]$CsvPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$rows = @()
foreach ($target in $TargetHosts) {
    $ping = New-Object System.Net.NetworkInformation.Ping
    $rtts = @()
    $started = (Get-Date).ToUniversalTime().ToString('o')
    try {
        for ($i = 0; $i -lt $Count; $i++) {
            try {
                $reply = $ping.Send($target, $TimeoutMs)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $rtts += [long]$reply.RoundtripTime
                } else {
                    Write-Verbose ("ICMP {0}: {1}" -f $target, $reply.Status)
                }
            } catch {
                Write-Verbose ("ICMP {0} error: {1}" -f $target, $_.Exception.Message)
            }
            if ($i -lt $Count - 1) { Start-Sleep -Milliseconds 250 }
        }
    } finally { $ping.Dispose() }

    $received = @($rtts).Count
    $stats = if ($received) { $rtts | Measure-Object -Average -Minimum -Maximum } else { $null }
    $rows += [pscustomobject]@{
        TimestampUtc = $started
        Target = $target
        Sent = $Count
        Received = $received
        Lost = $Count - $received
        LossPercent = [math]::Round((100.0 * ($Count - $received) / $Count), 2)
        AverageRttMs = if ($stats) { [math]::Round($stats.Average,1) } else { $null }
        MinimumRttMs = if ($stats) { $stats.Minimum } else { $null }
        MaximumRttMs = if ($stats) { $stats.Maximum } else { $null }
    }
}
$rows | Format-Table -AutoSize
if ($CsvPath) {
    try {
        $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CsvPath)
        $folder = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
        }
        $rows | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host ("Evidence saved to {0}" -f $path)
    } catch { throw ("Failed to save evidence: {0}" -f $_.Exception.Message) }
}
# A timeout may indicate ICMP filtering; it does not prove a faulty ISP.
