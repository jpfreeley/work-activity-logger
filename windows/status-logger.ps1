# status-logger.ps1
# Run with: powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\status-logger.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuration & defaults ---
$global:lastInput     = ""
$global:intervalMinutes = 15
$global:snoozeMinutes   = 60
$global:timeoutSeconds  = 60
$global:noteName        = "Work Status Log"
$global:firstRun        = $true
$global:debugMode       = $false
$global:allowedDays     = @("Monday","Tuesday","Wednesday","Thursday","Friday")
$global:startHour      = 9
$global:startMinute    = 0
$global:endHour        = 17
$global:endMinute      = 0
$global:logPath        = Join-Path $env:USERPROFILE "Documents\$($global:noteName).txt"
$global:entryMaxLength = 180

function Log-Debug {
    param($msg)
    if (-not $global:debugMode) { return }
    $stamp = (Get-Date).ToString()
    $entry = "`r`nDEBUG [${stamp}]: $msg"
    Add-Content -Path $global:logPath -Value $entry -Encoding UTF8
}

function Log-Entry {
    param($text)
    if ($null -eq $text) { $text = "" }
    
    # Length validation
    if ($text -ne "*user entry timed out*" -and $text.Length -gt $global:entryMaxLength) {
        $text = $text.Substring(0, $global:entryMaxLength)
    }
    
    # Update last input only if it's a real entry
    if ($text -ne "*user entry timed out*" -and $text -ne "") {
        $global:lastInput = $text
    }

    $stamp = (Get-Date).ToString()
    $entry = "`r`n${stamp}: $text"
    Add-Content -Path $global:logPath -Value $entry -Encoding UTF8
    Log-Debug "Wrote log entry: $text"
}

function Format-Time($h, $m) {
    $mStr = $m.ToString().PadLeft(2,'0')
    return "$h`:$mStr"
}

function Parse-HoursPair($input) {
    $parts = $input.Trim() -split '\s+'
    if ($parts.Count -ne 2) { throw "Please supply two times separated by space (e.g. 9:00 17:00)" }
    
    $start = $parts[0] -split ':'
    $end = $parts[1] -split ':'
    
    if ($start.Count -ne 2 -or $end.Count -ne 2) { throw "Invalid time format. Use H:MM (e.g. 9:00)" }
    
    # Return flat array to avoid PowerShell unrolling issues
    return @([int]$start[0], [int]$start[1], [int]$end[0], [int]$end[1])
}

function Setup-Config {
    Add-Type -AssemblyName Microsoft.VisualBasic
    try {
        $intervalText = [Microsoft.VisualBasic.Interaction]::InputBox("Prompt interval (minutes):", "Setup", $global:intervalMinutes)
        if ($intervalText -eq "") { return }
        $global:intervalMinutes = [int]$intervalText

        $snoozeText = [Microsoft.VisualBasic.Interaction]::InputBox("Snooze time (minutes):", "Setup", $global:snoozeMinutes)
        if ($snoozeText -eq "") { return }
        $global:snoozeMinutes = [int]$snoozeText

        $timeoutText = [Microsoft.VisualBasic.Interaction]::InputBox("Dialog timeout (seconds):", "Setup", $global:timeoutSeconds)
        if ($timeoutText -eq "") { return }
        $global:timeoutSeconds = [int]$timeoutText

        $defaultHours = Format-Time $global:startHour $global:startMinute + " " + Format-Time $global:endHour $global:endMinute
        $hoursText = [Microsoft.VisualBasic.Interaction]::InputBox("Work hours (format: '9:00 17:00'):", "Setup", $defaultHours)
        if ($hoursText -ne "") {
            $times = Parse-HoursPair $hoursText
            $global:startHour   = $times[0]
            $global:startMinute = $times[1]
            $global:endHour     = $times[2]
            $global:endMinute   = $times[3]
        }

        $daysDefault = ($global:allowedDays -join ",")
        $daysText = [Microsoft.VisualBasic.Interaction]::InputBox("Work days (e.g. Monday,Tuesday):", "Setup", $daysDefault)
        if ($daysText -ne "") {
            $global:allowedDays = $daysText -split ',' | ForEach-Object { $_.Trim() }
        }

        $dbg = [System.Windows.Forms.MessageBox]::Show("Enable debug logging?", "Setup", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        $global:debugMode = ($dbg -eq [System.Windows.Forms.DialogResult]::Yes)

        $formattedStart = Format-Time $global:startHour $global:startMinute
        $formattedEnd = Format-Time $global:endHour $global:endMinute
        
        [System.Windows.Forms.MessageBox]::Show("Settings saved:`n• Interval: $($global:intervalMinutes)m`n• Snooze: $($global:snoozeMinutes)m`n• Timeout: $($global:timeoutSeconds)s`n• Hours: $formattedStart - $formattedEnd`n• Days: $($global:allowedDays -join ',')`n• Debug: $global:debugMode", "Setup", [System.Windows.Forms.MessageBoxButtons]::OK)

        Log-Debug "CONFIG: Int=$($global:intervalMinutes) Snooze=$($global:snoozeMinutes) Timeout=$($global:timeoutSeconds) Hours=$formattedStart-$formattedEnd Days=$($global:allowedDays -join ',')"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Setup Error")
    }
}

function Should-Prompt {
    $now = Get-Date
    $dayName = $now.DayOfWeek.ToString()
    if ($global:allowedDays -notcontains $dayName) { return $false }

    $currentSeconds = $now.TimeOfDay.TotalSeconds
    $startSeconds = ($global:startHour * 3600) + ($global:startMinute * 60)
    $endSeconds = ($global:endHour * 3600) + ($global:endMinute * 60)
    return ($currentSeconds -ge $startSeconds -and $currentSeconds -le $endSeconds)
}

function Show-StatusDialog {
    param($defaultText, $timeoutSeconds, $snoozeLabel)

    $result = [PSCustomObject]@{ Button = $null; Text = ""; GaveUp = $false }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Status Logger"; $form.Size = "420,200"; $form.StartPosition = "CenterScreen"; $form.Topmost = $true
    $form.FormBorderStyle = 'FixedDialog'; $form.MinimizeBox = $false; $form.MaximizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "What are you working on?"; $label.Location = "12,14"; $label.AutoSize = $true
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = "12,38"; $textbox.Size = "380,22"; $textbox.Text = $defaultText
    $form.Controls.Add($textbox)

    $btnLog = New-Object System.Windows.Forms.Button
    $btnLog.Text = "Log"; $btnLog.Location = "310,110"; $btnLog.Size = "80,28"
    $btnLog.Add_Click({ $result.Button = "Log"; $result.Text = $textbox.Text; $form.Close() })
    $form.Controls.Add($btnLog)

    $btnSkip = New-Object System.Windows.Forms.Button
    $btnSkip.Text = "Skip"; $btnSkip.Location = "220,110"; $btnSkip.Size = "80,28"
    $btnSkip.Add_Click({ $result.Button = "Skip"; $form.Close() })
    $form.Controls.Add($btnSkip)

    $btnSnooze = New-Object System.Windows.Forms.Button
    $btnSnooze.Text = $snoozeLabel; $btnSnooze.Location = "130,110"; $btnSnooze.Size = "80,28"
    $btnSnooze.Add_Click({ $result.Button = "Snooze"; $result.Text = $textbox.Text; $form.Close() })
    $form.Controls.Add($btnSnooze)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = [int]($timeoutSeconds * 1000)
    $timer.Add_Tick({ $result.GaveUp = $true; $result.Text = $textbox.Text; $form.Close() })
    $timer.Start()

    [void]$form.ShowDialog()
    $timer.Stop()
    
    if ($null -eq $result.Button -and -not $result.GaveUp) { $result.Button = "Skip" }
    return $result
}

# --- Main Loop ---
while ($true) {
    try {
        if ($global:firstRun) { Setup-Config; $global:firstRun = $false }

        if (-not (Should-Prompt)) {
            Start-Sleep -Seconds ($global:intervalMinutes * 60)
            continue
        }

        $snoozeLabel = "Snooze ($global:snoozeMinutes) min"
        $dialog = Show-StatusDialog -defaultText $global:lastInput -timeoutSeconds $global:timeoutSeconds -snoozeLabel $snoozeLabel

        if ($dialog.GaveUp) {
            Log-Entry "*user entry timed out*"
            Start-Sleep -Seconds ($global:intervalMinutes * 60)
            continue
        }

        switch ($dialog.Button) {
            "Log" {
                $text = $dialog.Text.Trim()
                if ($text -ne "") {
                    Log-Entry $text
                } else {
                    $stamp = (Get-Date).ToString()
                    Add-Content -Path $global:logPath -Value "`r`n${stamp}: *Skipped* for $global:intervalMinutes minutes"
                    Log-Debug "Empty Log treated as Skip"
                }
                Start-Sleep -Seconds ($global:intervalMinutes * 60)
            }
            "Skip" {
                $stamp = (Get-Date).ToString()
                Add-Content -Path $global:logPath -Value "`r`n${stamp}: *Skipped* for $global:intervalMinutes minutes"
                Log-Debug "Skip clicked"
                Start-Sleep -Seconds ($global:intervalMinutes * 60)
            }
            "Snooze" {
                $text = $dialog.Text.Trim()
                $stamp = (Get-Date).ToString()
                if ($text -ne "" -and $text -ne $global:lastInput) {
                    Add-Content -Path $global:logPath -Value "`r`n${stamp}: $text"
                }
                Add-Content -Path $global:logPath -Value "`r`n${stamp}: *Snoozed* for $global:snoozeMinutes minutes"
                Log-Debug "Snoozed for $global:snoozeMinutes minutes"
                Start-Sleep -Seconds ($global:snoozeMinutes * 60)
            }
        }
    }
    catch {
        Log-Debug "Exception: $_"
        Start-Sleep -Seconds 5
    }
}