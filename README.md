# work-activity-logger
prompts for a snippet about what you are currently working on at standard configurable intervals

applescript file available for MacOS
```
Configuration options which are asked for at initial run: 
property intervalMinutes : 15          # Prompt Interval
property snoozeMinutes : 60            # Snooze Length
property timeoutSeconds : 60           # Dialog Box Timeout
property noteName : "Work Status Log"  # Name of Note to save log entries 
property debugMode : false             # Print DEBUG statements in the Note
property allowedDays : {2, 3, 4, 5, 6} # Mon (2) through Fri (6)
property startHour : 9                 # Only prompt from Start Hour (Local Time)
property startMinute : 0               # Only prompt from Start Minute (Local Time)
property endHour : 17                  # Only prompt until End Hour (Local Time) 
property endMinute : 0                 # Only prompt until End Minute (Local Time) 
```
