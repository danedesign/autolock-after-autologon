# Autolock after Autologon

Lock the Windows session on the first sign-in after each boot, allowing apps to keep running behind the lock screen. Later unlocks and sign-outs/sign-ins during the same boot are skipped.

Designed to accompany Microsoft Sysinternals Autologon. This project does not configure Autologon, store passwords, or change Windows Update settings.

## Expected behavior

| Event | Result |
| --- | --- |
| First sign-in after a restart | Requests a session lock as soon as the task starts |
| Unlocking the session | Leaves it unlocked |
| Signing out and back in during the same boot | Does not lock again |
| Next restart and sign-in | Requests a lock again |

This is a once-per-boot lock, not an idle timeout. Apps can continue starting and running in the signed-in session behind the lock screen. Confirm that your particular remote-access tools support that state.

## Configure Autologon separately

Download [Microsoft Sysinternals Autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon), run the appropriate executable, enter your Windows account details directly in its window, and click **Enable**. Use your account password, not a Windows Hello PIN.

Autologon is optional: this task also works with a manual first sign-in. Neither your password nor Microsoft's Autologon executable belongs in this repository.

## Install

Requires 64-bit Windows with Windows PowerShell 5.1, Task Scheduler, and the .NET Framework C# compiler. Tested on Windows 10; other versions are not verified.

Download or clone this repository. Open PowerShell **as administrator using the Windows account that automatically signs in**, change to this directory, and run:

```powershell
git clone https://github.com/danedesign/autolock-after-autologon.git
cd autolock-after-autologon
.\Install.ps1
```

If you downloaded a ZIP instead, extract it and open PowerShell in the extracted directory; run only the last command. If Windows has marked the downloaded files as blocked, review the installer and source, then use the file's Properties dialog to unblock them before running. Follow any organization execution-policy requirements.

The installer compiles `BootLock.cs` locally, performs a non-locking self-check, and registers the `BootIdleLock` logon task for that account. It replaces an existing task with that name. The executable, boot marker, and logs are stored under `%LOCALAPPDATA%\BootIdleLock`.

No reboot is initiated. After restarting, leave the PC untouched and confirm the session automatically signs in and then locks. Verify remote access from a second device. Unlock, sign out, and sign in again to confirm the task skips later sign-ins in that boot.

## Disable or uninstall

To temporarily disable automatic locking, run in administrator PowerShell:

```powershell
Disable-ScheduledTask -TaskName BootIdleLock
```

To re-enable it for future sign-ins:

```powershell
Enable-ScheduledTask -TaskName BootIdleLock
```

To remove the task, open administrator PowerShell in the repository folder and run:

```powershell
.\Install.ps1 -Uninstall
```

Uninstalling retains `%LOCALAPPDATA%\BootIdleLock`, including the executable and diagnostic logs. You can delete that directory after removing the task if you no longer need it.

**These commands do not disable automatic sign-in.** To disable that too, open Microsoft Sysinternals Autologon and click **Disable**.

## How it works and limitations

The task starts a compiled executable directly, avoiding PowerShell startup and runtime compilation during logon. It obtains the current boot time through `NtQuerySystemInformation(SystemTimeOfDayInformation)` and compares it with a per-user marker. On a new boot it calls `LockWorkStation`, retrying for up to five seconds if Windows rejects the request, and records the boot after an accepted request.

- Task Scheduler can still start after the desktop appears. This cannot guarantee a zero-exposure sign-in.
- A successful lock request is asynchronous; the log records acceptance, not proof the lock screen appeared.
- It applies to the first sign-in for the configured account, whether automatic or manual. It does not detect Autologon specifically.
- The boot marker is per user. Multiple concurrent sessions for the same account are outside the intended use.
- The native system-information structure is Windows-specific; a failed query is logged and the program exits with an error.
- Locking does not remove the credential-storage risks of Autologon or guarantee any remote-access application works while locked.

## Troubleshooting

Check `%LOCALAPPDATA%\BootIdleLock\boot-lock.log` and Task Scheduler's last result for `BootIdleLock` (zero indicates success or an already-processed boot). Running `BootLock.exe --check` checks the boot-time query without locking or consuming the boot marker.

- **Desktop remains visible briefly:** Task Scheduler may not launch the task until after the desktop appears. This tool cannot promise an instant or invisible transition.
- **Task does not run:** Confirm `BootIdleLock` exists, is enabled, and targets the account that signs in. The task must run in that user's interactive session.
- **Task runs but does not lock:** Check the log. An already-recorded boot is intentionally skipped. A restart creates the next intended test opportunity.
- **Installer reports access denied:** Use administrator PowerShell under the intended account, rather than elevating as another user.
- **Compiler missing:** Installation requires the 64-bit .NET Framework compiler at the path specified in `Install.ps1`.
- **Remote access fails while locked:** Investigate the remote-access application's configuration separately; this tool only requests a Windows session lock.

Useful read-only checks:

```powershell
Get-ScheduledTask -TaskName BootIdleLock
Get-ScheduledTaskInfo -TaskName BootIdleLock
Get-Content "$env:LOCALAPPDATA\BootIdleLock\boot-lock.log" -Tail 20
Start-Process "$env:LOCALAPPDATA\BootIdleLock\BootLock.exe" -ArgumentList '--check' -Wait
```

## Security and update-reboot testing

Automatic locking reduces the time an automatically signed-in desktop remains exposed. It does not make Autologon equivalent to requiring a password before sign-in. Anyone with physical access may see the desktop before the task runs; Microsoft also warns that administrators can recover the password stored by Autologon. Use this only where that tradeoff is acceptable.

A normal restart checks the basic behavior. To test a real update-servicing reboot, install a legitimate applicable update that requires restarting, use its restart prompt, and check the session from another device without signing in locally. Success in that test does not establish behavior under every unattended Windows Update restart scenario. Keep security updates installed after testing.

## Repository contents

- `BootLock.cs`: compiled lock program and once-per-boot marker logic.
- `Install.ps1`: local compilation, self-check, task registration, and task removal.
- `.gitignore`: excludes generated executables, debug symbols, and logs.

The executable is compiled locally; no prebuilt binary or third-party package is required.
