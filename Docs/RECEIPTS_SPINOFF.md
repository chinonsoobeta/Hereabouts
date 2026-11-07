# Receipts app: where to start

Hereabouts 1.0 drops receipts, return dates, warranties and expiry dates (decided 7 November). They could become a separate app. This page records where that app would start.

## Starting point

The local tag `receipts-spinoff-base` marks the last commit before the cut. Check it out to get the working feature:

```
git checkout -b receipts receipts-spinoff-base
```

## What to take

| Part | Files at the tag |
| --- | --- |
| Reading receipts and documents (photos, PDFs, on-device text recognition, date finding) | `Localiser/Scanning/ScanReader.swift` |
| The scan and confirm screen | `Localiser/Scanning/ScanView.swift` |
| Pasted order emails | `Localiser/Scanning/OrderEmail.swift` |
| Share sheet import (never shipped as an extension) | `Localiser/Scanning/ShareImport.swift` |
| Date kinds, return windows, reminder plans | `Localiser/Dates/DateRules.swift` |
| Notification queue, actions and Sunday recap | `Localiser/Dates/ReminderService.swift` |
| Add to Calendar | `Localiser/Dates/CalendarExport.swift` |
| The Due tab and date editor | `Localiser/Dates/DueView.swift` |
| The "What's due?" Siri phrase | `WhatsDueIntent` in `Localiser/System/Intents.swift` |
| Data | `Deadline` and `ScanRecord` in the Core Data model (V8) |

Tests at the tag: `LocaliserTests/OrderEmailTests.swift`, `LocaliserTests/ShareImportTests.swift`, and the scan, calendar, due-group, return-window and reminder-queue tests in `LocaliserTests.swift`, `LendingTests.swift` and `IntentsTests.swift`. The UI tests for pasting an order email and scanning photos and PDFs are in `LocaliserUITests.swift`.

Store screenshots and design work for the Due tab are in `Docs/Store/*/4-due.png` and `Docs/Design/canvas/Due.dc.html`.

## Known problems to fix first

These came from the 5 November review (`Docs/RELEASE_PLAN_SECOND_OPINION.md`) and were left unfixed when the feature was cut.

1. **Private text in calendar notes.** `CalendarExport.swift` hides a private thing's name but copies its source text into the event notes as is. Bulk export includes private things.
2. **The scan count drops on delete.** The monthly scan allowance is counted from the scan records that remain, so deleting a scanned thing, or restoring an older backup, gives scans back.
3. **"No reminders left" on the Due page.** `DueView.swift` says this whenever a date has nothing queued, including when the 50-reminder cap or a failed schedule left it out.
4. **Share sheet picks the wrong date.** `ShareImport.swift` preselects the first date it finds, defaults it to a return date and saves it as confirmed, with no editor, return-window sum or unclear-date warning.
5. **Share sheet saves half a thing.** `ShareImport.swift` saves the new thing before the date. If the date fails, the thing stays and uses a free slot, and a retry makes another.
6. **Building the share extension.** It needs its own target, the App Group entitlement and the shared-defaults privacy reason, which need a paid developer account.
