# Network Troubleshooting Toolkit

A menu-driven PowerShell toolkit for L1/L2 IT support network troubleshooting.

This repo is designed to show practical helpdesk and sysadmin troubleshooting skills: adapters, IP configuration, DNS, gateway checks, public connectivity, Microsoft 365 connectivity, Wi-Fi, proxy, firewall, route tables, ARP, netstat, and safe repair actions.

## Features

- Quick network summary
- Full network troubleshooting report
- Adapter status and driver information
- IP configuration and gateway testing
- DNS troubleshooting with `Resolve-DnsName`
- Public internet and Microsoft 365 connectivity checks
- TCP port testing with `Test-NetConnection`
- Traceroute export
- Wi-Fi interface and profile information
- WinHTTP and user proxy checks
- Firewall profile checks
- DNS cache flush
- Adapter restart with confirmation
- DHCP release/renew with confirmation
- Winsock and TCP/IP reset with confirmation
- Route, ARP, netstat, and ipconfig exports
- HTML, CSV, JSON, and log output

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Administrator rights recommended
- Network cmdlets available on modern Windows builds

## How to run

Open PowerShell as Administrator and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Network_Troubleshooting_Toolkit.ps1
```

Run a full report directly:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Network_Troubleshooting_Toolkit.ps1 -RunAll
```

Run a full report with a custom target:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Network_Troubleshooting_Toolkit.ps1 -RunAll -TargetHost example.com
```

Send reports to a custom output folder:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Network_Troubleshooting_Toolkit.ps1 -RunAll -OutputPath C:\Temp\NetworkReports
```

## Output

By default, reports are saved on the desktop in:

```text
Network_Troubleshooting_Reports
```

Generated files include:

```text
*.html
*.csv
*.json
*.log
ipconfig_all_*.txt
route_print_*.txt
arp_a_*.txt
netstat_ano_*.txt
tracert_*.txt
```

## Menu options

| Option | Description |
|---|---|
| 1 | Quick network summary |
| 2 | Full network troubleshooting report |
| 3 | Adapter status and driver info |
| 4 | IP configuration and gateway check |
| 5 | DNS troubleshooting |
| 6 | Public and Microsoft 365 connectivity check |
| 7 | TCP port test |
| 8 | Traceroute |
| 9 | Wi-Fi information |
| 10 | Proxy and firewall check |
| 11 | Flush DNS cache |
| 12 | Restart a network adapter |
| 13 | Renew DHCP lease |
| 14 | Reset Winsock and TCP/IP stack |
| 15 | Export route, ARP, netstat, and ipconfig data |
| 16 | Open report folder |

## Safety

Most options are diagnostic-only.

The following options can interrupt connectivity and require confirmation:

- Flush DNS cache
- Restart a network adapter
- Renew DHCP lease
- Reset Winsock and TCP/IP stack

The Wi-Fi check does **not** export Wi-Fi passwords.

## Good use cases

- Internet not working
- DNS resolution issues
- Microsoft 365 sign-in/connectivity issues
- VPN troubleshooting
- Wi-Fi troubleshooting
- Printer or file-share reachability checks
- Port/firewall troubleshooting
- Ticket escalation evidence

## Suggested repo topics

```text
powershell
networking
windows
it-support
helpdesk
troubleshooting
dns
dhcp
sysadmin
microsoft-365
```
