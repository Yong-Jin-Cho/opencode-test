# Registers (or removes) the Karrot RAM16 watch task: every 2 hours, 09:00-23:00.
# Usage:
#   powershell -ExecutionPolicy Bypass -File Register-KarrotWatch.ps1
#   powershell -ExecutionPolicy Bypass -File Register-KarrotWatch.ps1 -Unregister
param([switch]$Unregister)
$ErrorActionPreference = 'Stop'
$TaskName = 'karrot-ram16-watch'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script = Join-Path $Dir 'Watch-KarrotRam.ps1'
if ($Unregister) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Output "unregistered: $TaskName"
  return
}
if (-not (Test-Path -LiteralPath $Script)) { throw "not found: $Script" }
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-ExecutionPolicy Bypass -File "' + $Script + '"') -WorkingDirectory $Dir
$Trigger = New-ScheduledTaskTrigger -Daily -At 09:00
$Trigger.Repetition = (New-ScheduledTaskTrigger -Once -At 09:00 -RepetitionInterval (New-TimeSpan -Hours 2) -RepetitionDuration (New-TimeSpan -Days 365)).Repetition
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
Write-Output "registered: $TaskName every 2h -> $Script"
Write-Output 'Manual run: powershell -ExecutionPolicy Bypass -File Watch-KarrotRam.ps1'
