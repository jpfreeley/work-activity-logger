# work-activity-logger

A small pop-up that asks "What are you working on?" at a set interval during your work hours, and appends the answer
with a time stamp to a plain log. At the end of the day you have a running record to look back on.

There are two versions, one for macOS (AppleScript) and one for Windows (PowerShell).

| | macOS | Windows |
|---|---|---|
| Script | [`macos/status-logger.applescript`](macos/status-logger.applescript) | [`windows/status-logger.ps1`](windows/status-logger.ps1) |
| Log goes to | Apple Notes, or a Markdown file (for example in an Obsidian vault) | A text file, `Documents\Work Status Log.txt` |
| Setup guide | below | [windows/README.md](windows/README.md) |

## What a session looks like

Every interval (default 15 minutes), inside your work hours and on your work days, a dialog asks what you are working on.
It is pre-filled with your last answer, so a repeat is one click.

- **Log** saves the text.
- **Skip** records that you skipped this round.
- **Snooze** records the snooze and asks again after the snooze time (default 60 minutes).
- No answer within the timeout (default 60 seconds) is logged as `*user entry timed out*`, so gaps are visible.

Entries are cut at 180 characters. A log looks like this:

```
Mon Oct 26 09:15:02 2026: reviewing the pull request for the billing service
Mon Oct 26 09:30:03 2026: reviewing the pull request for the billing service
Mon Oct 26 09:45:01 2026: *Skipped* for 15 minutes
Mon Oct 26 10:00:04 2026: *user entry timed out*
Mon Oct 26 10:15:02 2026: *Snoozed* for 60 minutes
```

## Settings

Both versions ask for these the first time they run. Defaults are in the script.

| Setting | Default | |
|---|---|---|
| Prompt interval | 15 min | How often it asks |
| Snooze | 60 min | How long **Snooze** waits |
| Dialog timeout | 60 s | When an unanswered dialog is logged as timed out |
| Work hours | 9:00 to 17:00 (local time) | It stays quiet outside them |
| Work days | Monday to Friday | |
| Log name | `Work Status Log` | The note or file name |
| Debug | off | Writes DEBUG lines into the log |

## macOS setup

1. Open **Script Editor**, open `macos/status-logger.applescript`, and choose **File > Export**.
2. Set **File Format** to **Application** and tick **Stay open after run handler**. The script works through an `idle`
   handler, so it must stay open.
3. Run the exported app. Answer the setup questions: where to log (Apple Notes or a Markdown file), the interval and the rest.
4. To start it at login: **System Settings > General > Login Items**, add the app.

Choosing a Markdown file: the default is `~/Documents/Obsidian Vault/Work Status Log.md`. You can type any path at the
prompt. The first time, macOS asks permission to let the app control Notes, or to write in the folder.

## Windows setup

See [windows/README.md](windows/README.md). In short:

```
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File .\status-logger.ps1
```

## Limits

- There is no config file. Settings are answered in dialogs when the script starts (the Windows version asks every time it starts).
- The log is plain text, with no sync. Writing to iCloud so other devices see it is on the to-do list.
- Times use the computer's local clock and its default date format, so lines are not machine-sortable.
- There are no automated tests. It is a personal tool.

## Notes

This project was AI assisted, mainly Perplexity (free) with some help from Gemini 3 Flash and Qwen3 Coder.
No license has been chosen yet, so the default is all rights reserved. Ask if you want to reuse it.
