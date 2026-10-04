# Registers (or removes) a daily unattended opencode run via Windows Task Scheduler.
# Usage:
#   powershell -ExecutionPolicy Bypass -File Register-AgentTask.ps1
#   powershell -ExecutionPolicy Bypass -File Register-AgentTask.ps1 -Unregister
param([switch]$Unregister)
$ErrorActionPreference = 'Stop'
$TaskName = 'opencode-agent-daily'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Bat = Join-Path $Dir 'agent-task.bat'
if ($Unregister) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Output "unregistered: $TaskName"
  return
}
if (-not (Test-Path -LiteralPath $Bat)) { throw "not found: $Bat" }
$Action = New-ScheduledTaskAction -Execute $Bat -WorkingDirectory $Dir
$Trigger = New-ScheduledTaskTrigger -Daily -At 09:00
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
Write-Output "registered: $TaskName daily 09:00 -> $Bat"
Write-Output 'Manual run: schtasks /Run /TN opencode-agent-daily'
