property lastInput : ""
property intervalMinutes : 15
property snoozeMinutes : 60
property timeoutSeconds : 60
property noteName : "Work Status Log"
property firstRun : true
property debugMode : false
property allowedDays : {2, 3, 4, 5, 6}
property startHour : 9
property startMinute : 0
property endHour : 17
property endMinute : 0

on logDebug(actionDesc)
	if not debugMode then return
	set nowStamp to (current date) as string
	set debugEntry to return & "DEBUG [" & nowStamp & "]: " & actionDesc
	tell application "Notes"
		try
			set localAccount to first account whose name contains "My Mac"
			tell folder "Notes" of localAccount
				try
					set targetNote to first note whose name is noteName
					set body of targetNote to (body of targetNote) & debugEntry
				on error
					make new note at end with properties {name:noteName, body:debugEntry}
				end try
			end tell
		end try
	end tell
end logDebug

on parseTime(timeStr)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ":"
	set timeParts to text items of timeStr
	set AppleScript's text item delimiters to oldDelims
	return {(item 1 of timeParts) as integer, (item 2 of timeParts) as integer}
end parseTime

on setupConfig()
	set intervalText to text returned of (display dialog "Prompt interval (minutes):" default answer "15" buttons {"OK"} default button "OK")
	set intervalMinutes to intervalText as integer
	
	set snoozeText to text returned of (display dialog "Snooze time (minutes):" default answer "60" buttons {"OK"} default button "OK")
	set snoozeMinutes to snoozeText as integer
	
	set timeoutText to text returned of (display dialog "Dialog timeout (seconds):" default answer "60" buttons {"OK"} default button "OK")
	set timeoutSeconds to timeoutText as integer
	
	set hoursText to text returned of (display dialog "Work hours (format: '9:00 17:00'):" default answer "9:00 17:00" buttons {"OK"} default button "OK")
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to space
	set timePairs to text items of hoursText
	set AppleScript's text item delimiters to oldDelims
	set startParts to my parseTime(item 1 of timePairs)
	set endParts to my parseTime(item 2 of timePairs)
	set startHour to item 1 of startParts
	set startMinute to item 2 of startParts
	set endHour to item 1 of endParts
	set endMinute to item 2 of endParts
	
	set daysText to text returned of (display dialog "Work days (Mon=2,Tue=3,Wed=4,Thu=5,Fri=6,Sat=7):" default answer "2,3,4,5,6" buttons {"OK"} default button "OK")
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ","
	set dayStrings to text items of daysText
	set AppleScript's text item delimiters to oldDelims
	set allowedDays to {}
	repeat with i from 1 to count of dayStrings
		set end of allowedDays to (item i of dayStrings) as integer
	end repeat
	
	set debugResult to button returned of (display dialog "Enable debug logging?" buttons {"No", "Yes"} default button "No")
	set debugMode to (debugResult is "Yes")
	
	-- Format hours with leading zeros for minutes
	set startMinuteStr to startMinute as string
	if length of startMinuteStr is 1 then set startMinuteStr to "0" & startMinuteStr
	
	set endMinuteStr to endMinute as string
	if length of endMinuteStr is 1 then set endMinuteStr to "0" & endMinuteStr
	
	set startHourStr to startHour as string
	set endHourStr to endHour as string
	
	set formattedStart to startHourStr & ":" & startMinuteStr
	set formattedEnd to endHourStr & ":" & endMinuteStr
	
	display dialog "Settings saved:" & return & "• Interval: " & intervalMinutes & "m" & return & "• Snooze: " & snoozeMinutes & "m" & return & "• Timeout: " & timeoutSeconds & "s" & return & "• Hours: " & formattedStart & "-" & formattedEnd & return & "• Days: " & allowedDays & return & "• Debug: " & debugMode buttons {"OK"} default button "OK"
	
	if debugMode then my logDebug("CONFIG: Int=" & intervalMinutes & " Snooze=" & snoozeMinutes & " Timeout=" & timeoutSeconds & " Hours=" & formattedStart & "-" & formattedEnd & " Days=" & allowedDays)
end setupConfig

on shouldPrompt()
	set now to current date
	set weekdayNum to (weekday of now) as integer
	if weekdayNum is not in allowedDays then return false
	set currentTime to (time of now)
	set startTime to (startHour * 3600) + (startMinute * 60)
	set endTime to (endHour * 3600) + (endMinute * 60)
	return (currentTime ≥ startTime and currentTime ≤ endTime)
end shouldPrompt

on idle
	if firstRun then
		set firstRun to false
		my setupConfig()
		if debugMode then my logDebug("Setup complete")
		return 2
	end if
	
	if not my shouldPrompt() then return (intervalMinutes * 60)
	
	tell me to activate
	
	set snoozeLabel to "Snooze (" & snoozeMinutes & ") min"
	
	set inputText to ""
	
	set buttonName to ""
	try
		set dialogResult to display dialog "What are you working on?" default answer lastInput buttons {snoozeLabel, "Skip", "Log"} default button "Log" giving up after timeoutSeconds
		set inputText to text returned of dialogResult
		set buttonName to button returned of dialogResult
		
		if gave up of dialogResult then
			set inputText to "*user entry timed out*"
			set buttonName to "Log"
		else if buttonName is snoozeLabel then
			error number -128
		end if
	on error number errNum
		if errNum is -1712 then
			set inputText to "*user entry timed out*"
			set buttonName to "Log"
		else if errNum is -128 then -- Snooze clicked!
			if debugMode then my logDebug("SNOOZE - delaying " & snoozeMinutes & " min")
			
			set nowStamp to (current date) as string
			
			-- Check if there's a message to log before the snooze entry
			if inputText is not "" and inputText is not lastInput then
				set snoozeEntry to return & nowStamp & ": " & inputText & return & "---> *Snoozed* for " & snoozeMinutes & " minutes"
			else
				set snoozeEntry to return & nowStamp & ": *Snoozed* for " & snoozeMinutes & " minutes"
			end if
			
			tell application "Notes"
				try
					set localAccount to first account whose name contains "My Mac"
					tell folder "Notes" of localAccount
						try
							set targetNote to first note whose name is noteName
							set body of targetNote to (body of targetNote) & snoozeEntry
						on error
							make new note at end with properties {name:noteName, body:snoozeEntry}
						end try
					end tell
				end try
			end tell
			
			return (snoozeMinutes * 60)
		end if
		
		
	end try
	
	if buttonName is "Log" or (buttonName is not "Skip" and inputText is not "") then
		if inputText is not "*user entry timed out*" and (length of inputText) > 180 then set inputText to text 1 thru 180 of inputText
		if inputText is not "*user entry timed out*" then set lastInput to inputText
		set nowStamp to (current date) as string
		set logEntry to return & nowStamp & ": " & inputText
		
		tell application "Notes"
			try
				set localAccount to first account whose name contains "My Mac"
				tell folder "Notes" of localAccount
					try
						set targetNote to first note whose name is noteName
						set body of targetNote to (body of targetNote) & logEntry
					on error
						make new note at end with properties {name:noteName, body:logEntry}
					end try
				end tell
			end try
		end tell
		return (intervalMinutes * 60)
	else
		if debugMode then my logDebug("Skip clicked")
		
		set nowStamp to (current date) as string
		set skipEntry to return & nowStamp & ": *Skipped* for " & intervalMinutes & " minutes"
		
		tell application "Notes"
			try
				set localAccount to first account whose name contains "My Mac"
				tell folder "Notes" of localAccount
					try
						set targetNote to first note whose name is noteName
						set body of targetNote to (body of targetNote) & skipEntry
					on error
						make new note at end with properties {name:noteName, body:skipEntry}
					end try
				end tell
			end try
		end tell
		
		return (intervalMinutes * 60)
	end if
	
end idle

on run
end run
