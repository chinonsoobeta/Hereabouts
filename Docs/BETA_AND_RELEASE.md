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

Ask whether they opened Hereabouts again without prompting, which problem it solved, whether US$2.99 a month, US$19.99 a year or US$49.99 once feels fair, and which they'd pick, and which tool it would replace. Record exact defects. Small-sample percentages do not show demand. Do not add analytics for the beta.

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
| Subtitle | Find things at home | 30 |
| Primary category | Productivity | |
| Secondary category | Utilities | |
| Age rating | 4+ | |
| Price | Free, with Hereabouts Pro as a monthly or yearly plan (two weeks free) or Lifetime. No price is written in the listing; the App Store shows each country's | |
| Keywords | `where,find,belongings,inventory,home,organizer,packing,list,storage,lost,lend,borrow,keys,notebook` | 100 |

The keywords leave out "Hereabouts", plurals and category names because the App Store already indexes those.

**Promotional text** (170 characters, editable without review):

> Free for up to 15 things. Try Pro free for two weeks, or buy it once for life. No account, no ads, no tracking.

**Description:**

> Where did you put it? Hereabouts remembers.
>
> Save a thing with just its name. Add where it lives, like "Garage › Shelf 4", and find it again in seconds by name, nickname or place.
>
> HOMES AND PLACES
> Keep more than one home in the same notebook, and move things or whole places between them. Mark a thing private and its place stays out of Spotlight and Siri's spoken answers.
>
> LEND IT, GET IT BACK
> Note who has your drill. Choose a date to ask for it back, and Hereabouts reminds you.
>
> SAY IT (IF VOICE MEMOS SHIP)
> Hold the microphone, or tap Say it on the widget, and say "the spare key's in the blue tin on the hall shelf". Hereabouts turns it into a thing and a place for you to check. It's heard on your iPhone, the recording isn't kept, and nothing is saved until you tap. English only for now.
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
> "Where is my passport?" Hereabouts answers from your notebook. Write things down and put them away hands-free.
>
> FREE, OR PRO
> Free for 15 things, 1 packing kit and 2 homes. Hereabouts Pro removes the limits and backs up your notebook every week to your own iCloud Drive. Choose monthly or yearly with a two-week free trial, or buy Lifetime once. Household sharing is coming later. If Pro ends, nothing you wrote down is locked away.
>
> Subscriptions renew automatically unless canceled at least 24 hours before the period ends, and you can manage or cancel them in the Settings app under your name, then Subscriptions. Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/. Privacy Policy: https://hereabouts.app/privacy.

Leave the voice paragraph out if voice memos don't ship (voice rule, `RELEASE_PLAN.md` section 1). The listing carries no price, because prices differ by country. Description and subtitle are for the owner to approve in O7, after the wording pass.

Before publishing, check each sentence against the shipped build. Do not claim sync, sharing between people or guaranteed reminders.

## Screenshots

Use the demo library with the Debug-only launch argument `--demo-library` on a 6.9-inch and a 6.5-inch iPhone simulator. Light mode, default text size, status bar at 9:41.

1. **Find** showing "Running shoes" and its place path. Caption: "Find anything by where it lives".
2. **Scan review** with a confirmed "Return by" date. Caption: "Scan a receipt. Never miss a return".
3. **Due soon** with return and warranty sections. Caption: "Every deadline in one place".
4. **Trip detail** with packing progress. Caption: "Pack once, reuse forever".
5. **Pro screen** or a plain caption card. Caption: "No account. Nothing locked away. Export anytime".

Simulator QA screenshots in `Docs/Verification` are not store screenshots. Remove any real names or numbers from documents shown on screen.

## App Review notes

Paste into App Store Connect, App Review Information. These notes carry no prices, because they differ by country; the paywall shows each country's price from the App Store.

> Hereabouts has no account or login. Everything is stored on the device.
>
> The free plan allows 15 things in total, 1 packing kit and 2 homes. Hereabouts Pro removes those limits. It is sold as a monthly subscription, a yearly subscription (both with a two-week free trial) and a one-time Lifetime purchase, all in the group "Hereabouts Pro" (dev.hereabouts.pro.monthly, dev.hereabouts.pro.yearly, dev.hereabouts.pro.lifetime). Lifetime has Family Sharing on. Lifetime is offered for people who don't want a subscription.
>
> What the subscriptions keep giving: automatic weekly backups of the whole notebook to the person's own iCloud Drive (or to the phone if iCloud Drive is off), keeping the last five; regular updates; and household sharing, planned for version 1.1. Nothing saved is ever locked if Pro ends, and existing data stays visible, editable and exportable.
>
> To reach the paywall: open the Settings tab (bottom right), then tap Hereabouts Pro. "Restore purchases", the Privacy Policy and the Terms of Use are on the same screen. The purchases can be tested in the sandbox. Adding a 16th thing on the free plan also opens the paywall.
>
> Shelf photos and voice understanding use Apple's on-device model, so they appear only on iPhones that support Apple Intelligence. On other iPhones the app uses simpler rules and still works. Voice memos are transcribed on the phone with Apple's Speech framework, the recording is not kept, and nothing is saved without the person tapping Save. (Include the voice-memo sentences only if voice memos ship.)
>
> Reminders are local notifications. The app does not use the calendar.
>
> The app is designed for iPhone. On iPad it runs in iPhone compatibility mode.
>
> Privacy policy: https://hereabouts.app/privacy. Support: https://hereabouts.app/support.

Replace both links if the domain changes.

## Reviewer walkthrough

Ten steps from a fresh install to the paywall and back, for the review notes' reader and for the owner's own rehearsal (M45):

1. Install the build on a clean phone and open Hereabouts. The introduction appears.
2. Page through the introduction and tap through to the Find tab. No account or permission is asked for.
3. Add a first thing by name, for example "Spare key", and save it.
4. Add a place for it, for example "Hall shelf", and put the thing there.
5. Go back to Find and search "key". The thing appears with its place.
6. Open the Settings tab (bottom right) and check the four tabs: Find, Places, Trips, Settings.
7. In Settings, tap Hereabouts Pro. The paywall shows the plans with the price from the App Store, the trial terms, that it renews automatically, Restore purchases, and the Privacy Policy and Terms of Use links.
8. In the sandbox, buy a plan (or tap Restore purchases). The screen says Pro is on.
9. Go back to Find and add things until the free limit would have been reached. With Pro on there is no limit. On a fresh install without Pro, the 16th thing opens the same paywall instead.
10. Close the paywall and return to Find. Everything saved is still there.

## App Privacy label

- **Data collection:** "Data Not Collected". Hereabouts has no server, analytics, advertising or tracking SDK.
- **Privacy manifest:** `Localiser/PrivacyInfo.xcprivacy` declares app-private UserDefaults use, reason `CA92.1`. Check the final archive's privacy report before submitting.
- **Policy text:** `Site/privacy.html`. It covers on-device storage, device backups, user-made export files, on-device text recognition, notifications, write-only calendar access and StoreKit.

## Owner inputs

These live in `HUMAN_BLOCKED.md`: enrolment, domain and email, the App Store Connect product and price schedule, name clearance, TestFlight and the physical checks above. Uploading, inviting testers and submitting each need the owner's explicit go-ahead.
