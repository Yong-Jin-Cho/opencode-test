# Run THIS file ON THE SIDE PC as Administrator (right-click > Run as Administrator).
# Purpose: enable PowerShell remoting so the main PC can control this PC over LAN.
$ErrorActionPreference = "Stop"
Write-Output "STEP 1: Enable-PSRemoting"
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Write-Output "STEP 2: Network profile"
Get-NetConnectionProfile | Format-Table Name, NetworkCategory
Write-Output "STEP 3: WinRM listener + firewall"
winrm enumerate winrm/config/listener
Get-NetFirewallRule -DisplayGroup "Windows Remote Management" | Select-Object DisplayName, Enabled, Profile | Format-Table -AutoSize
Write-Output "STEP 4: IP and hostname"
hostname
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object IPAddress, InterfaceAlias | Format-Table -AutoSize
Write-Output "STEP 5: Self test"
Test-WSMan localhost | Select-Object -First 5
Write-Output "DONE. Tell the main PC the IPv4 shown above."
