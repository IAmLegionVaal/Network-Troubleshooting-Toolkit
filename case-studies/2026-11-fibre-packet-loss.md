# Field case: ISP-confirmed packet loss despite plausible speed-test throughput

**Incident month:** November 2026. **Current status:** Provider confirmed 1% packet loss (198/200 packets received), escalated upstream. Fix and end-user retest not yet confirmed.

## Original symptoms and evidence
Users described severe slowness. Endpoint speed testing showed roughly 34–38 Mbps download and 25 Mbps upload, idle ping 16–21 ms, and loaded latency 38 ms down / 33 ms up. These values alone cannot establish a faulty fibre line; the ISP independently confirmed packet loss.

## Reproducible triage
1. Eliminate endpoint saturation, Wi-Fi variability, and LAN switch/cabling issues.
2. Record timestamped ping measurements for default gateway and more than one external target; record loss and RTT separately.
3. Capture latency *under load*, not only headline up/down speeds.
4. Compare tests across affected endpoints and time windows. Preserve original results for ISP escalation.
5. Request ISP path diagnostics, upstream incident reference and a retest after remediation.

## Useful commands
```powershell
Get-NetAdapter | Format-Table Name,Status,LinkSpeed
Get-NetIPConfiguration
Test-Connection -ComputerName 1.1.1.1 -Count 30
Test-NetConnection -ComputerName 1.1.1.1 -InformationLevel Detailed
```

## Verified vs pending
**Verified:** An ISP acknowledged 1% packet loss and escalated. **Not verified:** repair, final measured packet loss, actual root-cause segment or user acceptance.

## Security and interpretation
Redact client name, WAN IP, circuit and internal topology before publishing evidence. ICMP may be deprioritized; loss at one hop does not necessarily indicate forwarding loss. Do not reset adapters or alter DNS without a differential diagnosis.
