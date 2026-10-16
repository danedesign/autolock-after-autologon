# Autolock after Autologon

Lock the Windows session on the first sign-in after each boot, allowing apps to keep running behind the lock screen. Later unlocks and sign-outs/sign-ins during the same boot are skipped.

Designed to accompany Microsoft Sysinternals Autologon. This project does not configure Autologon, store passwords, or change Windows Update settings.

## Install

Requires 64-bit Windows with Windows PowerShell 5.1, Task Scheduler, and the .NET Framework C# compiler. Tested on Windows 10; other versions are not verified.

Download or clone this repository. Open PowerShell **as administrator using the Windows account that automatically signs in**, change to this directory, and run:

```powershell
.\Install.ps1
```

The installer compiles `BootLock.cs` locally, performs a non-locking self-check, and registers the `BootIdleLock` logon task for that account. It replaces an existing task with that name. The executable, boot marker, and logs are stored under `%LOCALAPPDATA%\BootIdleLock`.

No reboot is initiated. After restarting, leave the PC untouched and confirm the session automatically signs in and then locks. Verify remote access from a second device. Unlock, sign out, and sign in again to confirm the task skips later sign-ins in that boot.

## How it works and limitations

The task starts a compiled executable directly, avoiding PowerShell startup and runtime compilation during logon. It obtains the current boot time through `NtQuerySystemInformation(SystemTimeOfDayInformation)` and compares it with a per-user marker. On a new boot it calls `LockWorkStation`, retrying for up to five seconds if Windows rejects the request, and records the boot after an accepted request.

- Task Scheduler can still start after the desktop appears. This cannot guarantee a zero-exposure sign-in.
- A successful lock request is asynchronous; the log records acceptance, not proof the lock screen appeared.
- It applies to the first sign-in for the configured account, whether automatic or manual. It does not detect Autologon specifically.
- The boot marker is per user. Multiple concurrent sessions for the same account are outside the intended use.
- The native system-information structure is Windows-specific; a failed query is logged and the program exits with an error.
- Locking does not remove the credential-storage risks of Autologon or guarantee any remote-access application works while locked.

## Diagnostics and removal

Check `%LOCALAPPDATA%\BootIdleLock\boot-lock.log` and Task Scheduler's last result for `BootIdleLock` (zero indicates success or an already-processed boot). Running `BootLock.exe --check` checks the boot-time query without locking or consuming the boot marker.

To remove the task, run from an elevated PowerShell window:

```powershell
.\Install.ps1 -Uninstall
```

This retains the local executable and logs. Disable automatic sign-in separately using Sysinternals Autologon if desired.
