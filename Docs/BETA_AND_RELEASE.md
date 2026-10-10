# Hereabouts: beta and release preparation

Updated 9 October 2026. Nothing has been invited, uploaded, created in App Store Connect or submitted. `BUILD_STATUS.md` holds verification results and `HUMAN_BLOCKED.md` lists what needs the owner.

## Beta workflow

Start with a small consented group of household organisers, frequent shoppers and travellers. Grow to fifteen to twenty households once obvious defects are fixed. Ask people to use their own belongings. Use synthetic receipts for the first expiry tests.

| Task | Success to observe | Record |
| --- | --- | --- |
| Save one real item | Save by name, optionally choose a place, find it again after a restart | Time, search phrase, whether help was needed |
| Find after moving | Move an item or a box and find its new place | Wrong or ambiguous suggestions, corrections |
| Confirm a date | Scan a receipt, check the date, save it | Wrong suggestions, manual corrections, trust |
| Decide a return | "I'm returning it", "I'm keeping it" or "It's been returned" without touching other dates | Reminder changes, accidental archiving |
| Add to Calendar | Add one date and "Add all to Calendar" from Due soon | Calendar title, alert time, duplicates |
| Complete a packing cycle | Plan a trip from a kit, pack, tick tasks, "I'm leaving", "I'm coming home", put things back, "Finish trip" | Missing rows, quantities, unresolved things |
| Recover a library | Back up with selected files, restore into a fresh install | Record counts, attachments, trip progress |

Ask whether they opened Hereabouts again without prompting, which problem it solved, whether $9.99 once feels fair, and which tool it would replace. Record exact defects. Small-sample percentages do not show demand. Do not add analytics for the beta.

## Frozen quality check

Freeze the app commit and expected answers before scoring 200 capture sentences and 100 search pairs. Use consented, de-identified examples from people who did not write the code. Keep every example in the denominator, including failures and corrections. Do not swap out hard examples after seeing results. Unit-test fixtures are not this holdout.

- **Capture.** Record the intended name, the existing place or an explicit "unknown", the suggestion, corrections and time to save. A suggestion is correct only when both name and place match. Target: 90% of captures finished correctly within ten seconds, corrections included.
- **Safety.** An unknown place must never be silently assigned, and a date must never be saved without confirmation. The allowed count for either is zero.
- **Search.** Record the query and acceptable items first. A positive query passes when an acceptable item is in the top three. Target: 95%. Report false positives on negative queries separately.
- **Speed.** Measure search over 5,000 records on the slowest supported phone. Target: 50 ms. Simulator timings do not count.

These are targets, not results. If one is missed, keep the failed run, fix the defects and re-test on a new holdout.

## Physical-device checks before launch

- Test iOS 26 on the smallest supported phone and on a phone with and without Apple Intelligence.
- Use airplane mode with no iCloud account: create, edit, move, search, scan and relaunch without loss.
- Time name-only capture and search with 5,000 records.
- Review every tab, scan confirmation, backup, Settings and Pro in light and dark mode, at the largest text size and with VoiceOver. Check focus order, error announcements and labels.
- Check that tips appear once and in order: Scan after the first item, put-away after five items, Move, Add to Calendar, "I'm leaving".
- Notifications: deny, revoke, act on a reminder, edit and delete dates, force-quit, leave the phone idle for days, change time zone, exceed 64 pending reminders. Compare the coverage card with the real pending queue. Check the item-name switch in Settings.
- Calendar: add one date and all dates with write-only access, then with access denied.
- Scanning: blurred receipt, several dates, no date, an expired document, camera, photo and PDF. A cancelled or failed scan must not use one of the 5 free monthly scans.
- Purchases: StoreKit sandbox buy, restore on a second device, cancel, failure, Ask to Buy and refund. Family Sharing unlocks a family member. After a refund, existing data, editing and export still work.
- Siri: "Where is <thing> in Hereabouts", "Write something down in Hereabouts" and "What's due in Hereabouts", with the phone locked and unlocked. Check the thing picker understands nicknames, and that the 201st thing on the free plan is refused politely.
- Sunday recap and stocktake: leave the phone through a Sunday 18:00 and a first Saturday with things not checked for three months. Tap each notification and check it opens the right sheet. Turn both off in Settings and check nothing more arrives. Check the trip-eve reminder the evening before a trip that isn't fully packed.
- iPad: install on an iPad and walk all four tabs. The app is iPhone-only and runs in compatibility mode.

No public launch with an open data-loss defect, a silently accepted wrong date or missing proof that real reminders fire.

## App Store listing

| Field | Value | Limit |
| --- | --- | --- |
| Name | Hereabouts | 30 |
| Subtitle | Find things, track returns | 30 |
| Primary category | Productivity | |
| Secondary category | Utilities | |
| Age rating | 4+ | |
| Price | Free with a US$4.99 in-app Founder's price, then US$9.99 | |
| Keywords | `where,find,belongings,inventory,home,organizer,receipt,return,warranty,packing,list,storage,lost` | 100 |

The keywords leave out "Hereabouts", plurals and category names because the App Store already indexes those.

**Promotional text** (170 characters, editable without review):

> Founder's price: unlock everything for US$4.99, once. No subscription, no account. Free for up to 200 things.

**Description:**

> Where did you put it? Hereabouts remembers.
>
> Save a thing with just its name. Add where it lives, like "Garage › Shelf 4", and find it again in seconds by name, nickname or place.
>
> NEVER MISS A RETURN
> Scan a receipt or label. Hereabouts reads the dates on your iPhone and asks you to confirm them. It reminds you before the return window closes, a warranty ends or something expires. Add any date to your calendar with one tap.
>
> PACK ONCE
> Make a kit for trips you take often. Plan a trip, tick things off by where they live, and get a checklist for putting everything back when you're home.
>
> YOURS, ON YOUR PHONE
> No account. No ads. No tracking. Everything stays on your iPhone and in your device backup. Export a backup or a spreadsheet whenever you like.
>
> KEEPS ITSELF HONEST
> One quiet recap on Sunday evenings. Once a month, a few "Still there?" questions about things you haven't looked at in a while. Both can be turned off.
>
> ASK SIRI
> "Where is my passport?" Hereabouts answers from your notebook. Add things and hear what's due, hands-free.
>
> FAIR PRICE
> Free for up to 200 things, 2 kits and 5 scans a month. Hereabouts Pro removes the limits for a single payment, shared with your family. No subscription, ever. Every feature is in the free version.

Before publishing, check each sentence against the shipped build. Do not claim sync, sharing between people or guaranteed reminders.

## Screenshots

Use the demo library with the Debug-only launch argument `--demo-library` on a 6.9-inch and a 6.5-inch iPhone simulator. Light mode, default text size, status bar at 9:41.

1. **Find** showing "Running shoes" and its place path. Caption: "Find anything by where it lives".
2. **Scan review** with a confirmed "Return by" date. Caption: "Scan a receipt. Never miss a return".
3. **Due soon** with return and warranty sections. Caption: "Every deadline in one place".
4. **Trip detail** with packing progress. Caption: "Pack once, reuse forever".
5. **Pro screen** or a plain caption card. Caption: "No account. No subscription. Export anytime".

Simulator QA screenshots in `Docs/Verification` are not store screenshots. Remove any real names or numbers from documents shown on screen.

## App Review notes

Paste into App Store Connect, App Review Information:

> Hereabouts has no account or login. Everything is stored on the device.
>
> The free version allows 200 saved things, 2 packing kits and 5 successful receipt scans per calendar month. Pro is a single non-consumable in-app purchase, "Hereabouts Pro" (dev.localiser.pro.lifetime), with Family Sharing on. It removes those limits and nothing else. To see the paywall quickly, open Packing and create a third kit, or open Settings › Hereabouts Pro. The purchase can be tested in the sandbox. "Restore purchases" is on the same screen.
>
> Receipt scanning uses the camera, a photo or a PDF. Text is read on the device with Apple's Vision framework. Dates are never saved without the user confirming them.
>
> Reminders are local notifications. "Add to Calendar" uses write-only calendar access and adds events to the default calendar.
>
> The app is designed for iPhone. On iPad it runs in iPhone compatibility mode.
>
> Privacy policy: https://hereabouts.app/privacy. Support: https://hereabouts.app/support.

Replace both links if the domain changes.

## App Privacy label

- **Data collection:** "Data Not Collected". Hereabouts has no server, analytics, advertising or tracking SDK.
- **Privacy manifest:** `Localiser/PrivacyInfo.xcprivacy` declares app-private UserDefaults use, reason `CA92.1`. Check the final archive's privacy report before submitting.
- **Policy text:** `Site/privacy.html`. It covers on-device storage, device backups, user-made export files, on-device text recognition, notifications, write-only calendar access and StoreKit.

## Owner inputs

These live in `HUMAN_BLOCKED.md`: enrolment, domain and email, the App Store Connect product and price schedule, name clearance, TestFlight and the physical checks above. Uploading, inviting testers and submitting each need the owner's explicit go-ahead.
