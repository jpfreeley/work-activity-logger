# How to run?? 

1. Save the PowerShell script I provided earlier as `status-logger.ps1` in a folder you won’t move or delete, e.g., `C:\Scripts\status-logger.ps1`.

2. Run PowerShell with the STA apartment state:
**`powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\status-logger.ps1`**

# Where are logs stored??

In the PowerShell script I provided, the log file is stored in your **Documents** folder.

Specifically, the location is defined by this line in the script:
```powershell
$global:logPath = Join-Path $env:USERPROFILE "Documents\$($global:noteName).txt"
```

Since `$global:noteName` is set to `"Work Status Log"`, the full path on a standard Windows 11 installation will be:
**`C:\Users\YourUsername\Documents\Work Status Log.txt`**

### Key Details about the Log File:
*   **Format:** It is a plain text file (`.txt`).
*   **Encoding:** It uses **UTF8** encoding to ensure special characters are handled correctly.
*   **Behavior:** The script uses `Add-Content`, which means it **appends** new entries to the end of the file rather than overwriting it.
*   **Debug Logs:** If you enabled "Debug Mode" during the initial setup, debug messages (like "Setup complete" or "Skip clicked") will also be written into this same file, prefixed with `DEBUG`.

### How to change the location:
If you would prefer the logs to be saved elsewhere (for example, in a Dropbox or OneDrive folder for syncing), you can simply change that one line in the script to a hardcoded path, like this:
```powershell
$global:logPath = "C:\MyLogs\WorkStatus.txt"
```

# How to run continuously??

To have this PowerShell status logger run continuously at startup on Windows 11, the best approach is:

1. Save the script as a `.ps1` file (e.g., `status-logger.ps1`).

2. Create a shortcut or a scheduled task that runs PowerShell with the right parameters to launch this script in the background at user login.

### Recommended: Use Windows Task Scheduler to run at startup

Here’s how to set it up:

---

### Step 1: Save your script

Save the PowerShell script I provided earlier as `status-logger.ps1` in a folder you won’t move or delete, e.g., `C:\Scripts\status-logger.ps1`.

---

### Step 2: Create a Scheduled Task

Open PowerShell **as Administrator** and run the following commands to create a scheduled task that runs at user logon:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File 'C:\Scripts\status-logger.ps1' -STA"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel LeastPrivilege
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "StatusLogger" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
```

**Explanation:**

- Runs PowerShell with your script at user logon.
- Runs hidden (`-WindowStyle Hidden`) so no window pops up.
- Uses `-STA` to support Windows Forms GUI.
- Runs with least privileges and only when the user is logged in.

---

### Step 3: Test the task

You can test the task by running:

```powershell
Start-ScheduledTask -TaskName "StatusLogger"
```

---

### Optional: Create a shortcut to run manually

If you want to run it manually sometimes, create a shortcut with this target:

```
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\status-logger.ps1" -STA
```

---

### Notes

- The script will keep running in the background, prompting you at intervals.
- If you want to stop it, open Task Scheduler, find "StatusLogger", and disable or delete it.
- You can edit the script anytime; changes will take effect next time it runs.

---
