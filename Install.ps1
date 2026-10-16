param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$taskName = 'BootIdleLock'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as administrator under the account that uses Autologon.'
}
if ($Uninstall) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    Write-Output 'Task removed. Local program and logs retained.'
    return
}
$directory = Join-Path $env:LOCALAPPDATA 'BootIdleLock'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$exe = Join-Path $directory 'BootLock.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw '64-bit .NET Framework C# compiler not found.' }
& $compiler /nologo /target:winexe /optimize+ "/out:$exe" (Join-Path $PSScriptRoot 'BootLock.cs')
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
$check = Start-Process -FilePath $exe -ArgumentList '--check' -Wait -PassThru
if ($check.ExitCode -ne 0) { throw "Self-check failed. See $directory\boot-lock.log" }
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute $exe
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $taskPrincipal -Settings $settings -Description 'Lock on the first sign-in after boot; skip subsequent sign-ins.' -Force -ErrorAction Stop | Out-Null
Write-Output 'Installed. No restart or immediate lock was initiated. Test on the next restart.'
