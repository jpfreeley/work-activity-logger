# status-logger.ps1
# Run with: powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\status-logger.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuration & defaults ---
$global:lastInput     = ""
$global:intervalMinutes = 15
$global:snoozeMinutes   = 60
$global:timeoutSeconds  = 60
$global:noteName        = "Work Status Log"         # used only for display; log filename below
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
    $entry = "`r`nDEBUG [$stamp]: $msg"
    Add-Content -Path $global:logPath -Value $entry -Encoding UTF8
}

function Log-Entry {
    param($text)
    if ($null -eq $text) { $text = "" }
    if ($text -ne "*user entry timed out*" -and $text.Length -gt $global:entryMaxLength) {
        $text = $text.Substring(0, $global:entryMaxLength)
    }
    if ($text -ne "*user entry timed out*" -and $text -ne "") {
        $global:lastInput = $text
    }

    $stamp = (Get-Date).ToString()
    $entry = "`r`n$stamp: $text"
    Add-Content -Path $global:logPath -Value $entry -Encoding UTF8
    Log-Debug "Wrote log entry: $text"
}

function Format-Time($h, $m) {
    $mStr = $m.ToString().PadLeft(2,'0')
    return "$h`:$mStr"
}

function Parse-HoursPair($input) {
    # input like "9:00 17:00" or "9:0 17:0"
    $parts = $input -split '\s+' | Where-Object { $_ -ne "" }
    if ($parts.Count -ne 2) { throw "Please supply two times separated by space (e.g. 9:00 17:00)" }
    $parse = {
        param($t)
        $pp = $t -split ':'
        [int]$pp[0], [int]$pp[1]
    }
    return ,(@($parse.Invoke($parts[0])), @($parse.Invoke($parts[1])))
}

function Setup-Config {
    # simple GUI/inputs using InputBox and MessageBox
    Add-Type -AssemblyName Microsoft.VisualBasic
    try {
        $intervalText = [Microsoft.VisualBasic.Interaction]::InputBox("Prompt interval (minutes):", "Setup", $global:intervalMinutes)
        if ($intervalText -ne "") { $global:intervalMinutes = [int]$intervalText }

        $snoozeText = [Microsoft.VisualBasic.Interaction]::InputBox("Snooze time (minutes):", "Setup", $global:snoozeMinutes)
        if ($snoozeText -ne "") { $global:snoozeMinutes = [int]$snoozeText }

        $timeoutText = [Microsoft.VisualBasic.Interaction]::InputBox("Dialog timeout (seconds):", "Setup", $global:timeoutSeconds)
        if ($timeoutText -ne "") { $global:timeoutSeconds = [int]$timeoutText }

        $defaultHours = Format-Time $global:startHour $global:startMinute + " " + Format-Time $global:endHour $global:endMinute
        $hoursText = [Microsoft.VisualBasic.Interaction]::InputBox("Work hours (format: '9:00 17:00'):", "Setup", $defaultHours)
        if ($hoursText -ne "") {
            $pair = Parse-HoursPair $hoursText
            $global:startHour = $pair[0][0]
            $global:startMinute = $pair[0][1]
            $global:endHour = $pair[1][0]
            $global:endMinute = $pair[1][1]
        }

        $daysDefault = ($global:allowedDays -join ",")
        $daysText = [Microsoft.VisualBasic.Interaction]::InputBox("Work days (comma-separated names, e.g. Monday,Tuesday,...):", "Setup", $daysDefault)
        if ($daysText -ne "") {
            $arr = $daysText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            $global:allowedDays = $arr
        }

        $dbg = [System.Windows.Forms.MessageBox]::Show("Enable debug logging?", "Setup", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        $global:debugMode = ($dbg -eq [System.Windows.Forms.DialogResult]::Yes)

        $formattedStart = Format-Time $global:startHour $global:startMinute
        $formattedEnd = Format-Time $global:endHour $global:endMinute
        [System.Windows.Forms.MessageBox]::Show("Settings saved:`n• Interval: $($global:intervalMinutes)m`n• Snooze: $($global:snoozeMinutes)m`n• Timeout: $($global:timeoutSeconds)s`n• Hours: $formattedStart - $formattedEnd`n• Days: $($global:allowedDays -join ',')`n• Debug: $global:debugMode", "Setup", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        Log-Debug "CONFIG: Int=$($global:intervalMinutes) Snooze=$($global:snoozeMinutes) Timeout=$($global:timeoutSeconds) Hours=$formattedStart-$formattedEnd Days=$($global:allowedDays -join ',')"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Configuration cancelled or invalid: $_", "Setup Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        throw
    }
}

function Should-Prompt {
    $now = Get-Date
    $dayName = $now.DayOfWeek.ToString()
    if (-not ($global:allowedDays -contains $dayName)) { return $false }

    $currentSeconds = $now.TimeOfDay.TotalSeconds
    $startSeconds = ($global:startHour * 3600) + ($global:startMinute * 60)
    $endSeconds = ($global:endHour * 3600) + ($global:endMinute * 60)
    return ($currentSeconds -ge $startSeconds -and $currentSeconds -le $endSeconds)
}

function Show-StatusDialog {
    param($defaultText, $timeoutSeconds, $snoozeLabel)

    $result = [PSCustomObject]@{
        Button = $null
        Text   = ""
        GaveUp = $false
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Status Logger"
    $form.Size = New-Object System.Drawing.Size(420,200)
    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true
    $form.FormBorderStyle = 'FixedDialog'
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.AcceptButton = $null

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "What are you working on?"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(12,14)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Multiline = $false
    $textbox.Size = New-Object System.Drawing.Size(380,22)
    $textbox.Location = New-Object System.Drawing.Point(12,38)
    $textbox.Text = $defaultText
    $form.Controls.Add($textbox)

    # Buttons
    $btnLog = New-Object System.Windows.Forms.Button
    $btnLog.Text = "Log"
    $btnLog.Size = New-Object System.Drawing.Size(80,28)
    $btnLog.Location = New-Object System.Drawing.Point(310,110)
    $btnLog.Add_Click({
        $result.Button = "Log"
        $result.Text = $textbox.Text
        $form.Close()
    })
    $form.Controls.Add($btnLog)

    $btnSkip = New-Object System.Windows.Forms.Button
    $btnSkip.Text = "Skip"
    $btnSkip.Size = New-Object System.Drawing.Size(80,28)
    $btnSkip.Location = New-Object System.Drawing.Point(220,110)
    $btnSkip.Add_Click({
        $result.Button = "Skip"
        $result.Text = $textbox.Text
        $form.Close()
    })
    $form.Controls.Add($btnSkip)

    $btnSnooze = New-Object System.Windows.Forms.Button
    $btnSnooze.Text = $snoozeLabel
    $btnSnooze.Size = New-Object System.Drawing.Size(80,28)
    $btnSnooze.Location = New-Object System.Drawing.Point(130,110)
    $btnSnooze.Add_Click({
        $result.Button = "Snooze"
        $result.Text = $textbox.Text
        $form.Close()
    })
    $form.Controls.Add($btnSnooze)

    # Timer for timeout
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = [int]($timeoutSeconds * 1000)
    $timer.Add_Tick({
        # capture text before closing
        $result.GaveUp = $true
        $result.Text = $textbox.Text
        $timer.Stop()
        $form.Close()
    })
    $timer.Start()

    # Show modal dialog
    [void]$form.ShowDialog()
    if ($timer.Enabled) { $timer.Stop() }

    # If user closed window without clicking a button (shouldn't happen often), treat as Skip
    if ($null -eq $result.Button -and -not $result.GaveUp) {
        $result.Button = "Skip"
        $result.Text = $textbox.Text
    }

    return $result
}

# --- Main Loop ---
while ($true) {
    try {
        if ($global:firstRun) {
            Setup-Config
            $global:firstRun = $false
            Log-Debug "Setup complete"
        }

        if (-not (Should-Prompt)) {
            Start-Sleep -Seconds ($global:intervalMinutes * 60)
            continue
        }

        $snoozeLabel = "Snooze ($($global:snoozeMinutes)) min"
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
                    # If empty, treat like Skip
                    $stamp = (Get-Date).ToString()
                    $skipMsg = "*Skipped* for $($global:intervalMinutes) minutes"
                    Add-Content -Path $global:logPath -Value "`r`n$stamp: $skipMsg" -Encoding UTF8
                    Log-Debug "Empty Log treated as Skip"
                }
                Start-Sleep -Seconds ($global:intervalMinutes * 60)
            }
            "Skip" {
                $stamp = (Get-Date).ToString()
                $skipMsg = "*Skipped* for $($global:intervalMinutes) minutes"
                Add-Content -Path $global:logPath -Value "`r`n$stamp: $skipMsg" -Encoding UTF8
                Log-Debug "Skip clicked"
                Start-Sleep -Seconds ($global:intervalMinutes * 60)
            }
            "Snooze" {
                $text = $dialog.Text.Trim()
                $stamp = (Get-Date).ToString()
                if ($text -ne "" -and $text -ne $global:lastInput) {
                    # log the message entered before snooze
                    Add-Content -Path $global:logPath -Value "`r`n$stamp: $text" -Encoding UTF8
                }
                $snoozeMsg = "*Snoozed* for $($global:snoozeMinutes) minutes"
                Add-Content -Path $global:logPath -Value "`r`n$stamp: $snoozeMsg" -Encoding UTF8
                Log-Debug "Snoozed for $($global:snoozeMinutes) minutes"
                Start-Sleep -Seconds ($global:snoozeMinutes * 60)
            }
            default {
                # Fallback
                Log-Debug "Unknown button/result: $($dialog.Button). Treating as Skip."
                $stamp = (Get-Date).ToString()
                $skipMsg = "*Skipped* for $($global:intervalMinutes) minutes"
                Add-Content -Path $global:logPath -Value "`r`n$stamp: $skipMsg" -Encoding UTF8
                Start-Sleep -Seconds ($global:intervalMinutes * 60)
            }
        }
    }
    catch {
        Log-Debug "Exception in main loop: $_"
        Start-Sleep -Seconds 5
    }
}