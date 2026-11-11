# Hereabouts: beta and release preparation

Updated 7 November 2026. Nothing has been invited, uploaded, created in App Store Connect or submitted. `BUILD_STATUS.md` holds verification results, and the owner's list is checklist A in `RELEASE_PLAN.md` (section 4).

## Beta workflow

Start with a small consented group of household organizers, frequent shoppers and travelers. Grow to fifteen to twenty households once obvious defects are fixed. Ask people to use their own belongings.

| Task | Success to observe | Record |
| --- | --- | --- |
| Save one real item | Save by name, optionally choose a place, find it again after a restart | Time, search phrase, whether help was needed |
| Find after moving | Move an item or a box and find its new place | Wrong or ambiguous suggestions, corrections |
| Say it | Hold the microphone, say where a thing is, check the name and place, save | Wrong names or places, corrections, whether a place was ever filled in unseen |
| Lend and get it back | Lend a thing with an ask-back date, get the reminder, mark it back | Reminder timing, wrong names, accidental archiving |
| Complete a packing cycle | Plan a trip from a kit, pack, check off tasks, "I'm leaving", "I'm coming home", put things back, "Finish trip" | Missing rows, quantities, unresolved things |
| Recover a library | Back up with selected files, restore into a fresh install | Record counts, attachments, trip progress |

Ask whether they opened Hereabouts again without prompting, which problem it solved, whether the monthly, yearly or Lifetime price shown in the paywall feels fair, and which they'd pick, and which tool it would replace. Record exact defects. Small-sample percentages do not show demand. Do not add analytics for the beta.

## Frozen quality check

Freeze the app commit and expected answers before scoring 200 capture sentences and 100 search pairs. Use consented, de-identified examples from people who did not write the code. Keep every example in the denominator, including failures and corrections. Do not swap out hard examples after seeing results. Unit-test fixtures are not this holdout.

- **Capture.** Record the intended name, the existing place or an explicit "unknown", the suggestion, corrections and time to save. A suggestion is correct only when both name and place match. Target: 90% of captures finished correctly within ten seconds, corrections included.
- **Safety.** An unknown place must never be silently assigned, by typing or by voice. The allowed count is zero.
- **Search.** Record the query and acceptable items first. A positive query passes when an acceptable item is in the top three. Target: 95%. Report false positives on negative queries separately.
- **Speed.** Measure search over 5,000 records on the slowest supported phone. Target: 50 ms. Simulator timings do not count.

These are targets, not results. If one is missed, keep the failed run, fix the defects and re-test on a new holdout.

## Physical-device checks before launch

These match O39 in `RELEASE_PLAN.md`; check them off there.

- Test iOS 26 on the smallest supported phone you can borrow, and on phones with and without Apple Intelligence.
- Use airplane mode with no iCloud account: create, edit, move, search, a voice memo and relaunch without loss.
- Time name-only capture and search with 5,000 records, on the iPhone 16 Pro Max.
- Review every tab, Settings and Pro in light and dark mode, at the largest text size and with VoiceOver. Check focus order, error announcements and labels.
- Check that tips appear once and in order.
- Notifications: deny, revoke, act on an ask-back reminder, force-quit, leave the phone idle for days, change time zone. The Settings tab's warning shows when notifications are off.
- Purchases: StoreKit sandbox buy of each product, start the yearly trial and cancel, restore on a second device, failure, Ask to Buy and refund. Family Sharing unlocks a family member. After a refund, existing data, editing and export still work.
- Voice: microphone denied, then allowed; a long sentence; a place the notebook doesn't know is left blank.
- Siri: "Where is <thing> in Hereabouts" and "Write something down in Hereabouts", with the phone locked and unlocked. The 16th free thing is refused politely. A private thing's place is never spoken. A missing thing is reported as missing.
- Sunday recap and stocktake: leave the phone through a Sunday 18:00 and a first Saturday with things not checked for three months. Tap each notification and check it opens the right sheet. Turn both off in Settings and check nothing more arrives. Check the trip-eve reminder the evening before a trip that isn't fully packed.
- Automatic backups: one arrives in iCloud Drive, a restore from it brings everything back, and turning Pro off keeps the saved ones.
- Widgets: both buttons at small size and on the Lock Screen; the lent-out widget if it ships.
- iPad: install on an iPad and walk all four sections in the sidebar, in both orientations, in Split View and Slide Over at a third of the screen (the iPhone layout), and with Stage Manager windows resized. Try the keyboard shortcuts and dragging a thing onto a place.

No public launch with an open data-loss defect, a place filled in without the person seeing it, or missing proof that real reminders arrive.

## App Store listing

| Field | Value | Limit |
| --- | --- | --- |
| Name | Hereabouts: Find Your Things (App Store Connect name since 8 November: plain "Hereabouts" was taken). The name under the icon stays Hereabouts | 30 |
| Subtitle | Remember where you put it (owner's OK, 8 November) | 30 |
| Primary category | Productivity | |
| Secondary category | Utilities | |
| Age rating | 4+ | |
| Price | Free, with Hereabouts Pro as a monthly plan, a yearly plan (the first week free) or Lifetime. No price is written in the listing; the App Store shows each country's | |
| Keywords | `where,find,belongings,inventory,home,organizer,packing,list,storage,lost,lend,borrow,keys,notebook` | 100 |

The keywords leave out "Hereabouts", plurals and category names because the App Store already indexes those.

**Promotional text** (170 characters, editable without review):

> Keep up to 15 things for free. Try Pro free for a week on the yearly plan, or buy Lifetime once. No account, ads or tracking.

**Description:**

> Write down where you put things. Find them later.
>
> Save a thing by name. Add its place, like "Garage › Shelf 4". Find it in seconds by name, other name or place.
>
> HOMES AND PLACES
> Keep more than one home in your notebook. Move things or whole places between them. Mark a thing private to keep its place out of Spotlight and Siri's spoken answers.
>
> LEND A THING
> Write down who has your drill. Choose a date to ask for it back. Get a reminder that day.
>
> SAY WHERE
> Hold the microphone or tap Say where on the widget. Say "the spare key's in the blue tin on the hall shelf". Check the thing and place before you save. Hereabouts hears you on your iPhone. It doesn't keep the recording. Nothing is saved until you tap. English only for now.
>
> PACK FOR A TRIP
> Save a kit for trips you take often. Plan a trip. Check off things by place as you pack. Use your checklist to put them away when you're home.
>
> YOUR PRIVATE NOTEBOOK
> You don't need an account. There are no ads or tracking. Your notebook is saved on your iPhone and in your device backup. Copies you save and Pro's weekly backups go to places you control. Export a backup or spreadsheet anytime.
>
> CHECK YOUR THINGS
> Get one quiet recap on Sunday evenings. Once a month, check a few things you haven't looked at lately. You can turn off both reminders.
>
> ASK SIRI
> Ask "Where's my passport in Hereabouts?" to get an answer from your notebook. Write things down and put them away hands-free.
>
> FREE, OR PRO
> Save 15 things, 1 kit and 2 homes for free. Pro removes the limits. Weekly notebook backups to your own iCloud Drive are on by default. Choose monthly or yearly, or buy Lifetime once. Yearly starts with a one-week free trial. Household sharing is coming later. If Pro ends, you can still see, edit and export everything you saved.
>
> Your subscription renews automatically unless you cancel at least 24 hours before the period ends. To manage or cancel it, open the Settings app. Tap your name, then Subscriptions. Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/. Privacy Policy: https://hereaboutsapp.com/privacy.

Voice memos ship (owner, 8 November), so the voice paragraph stays. The listing carries no price, because prices differ by country. Description and subtitle are for the owner to approve in O7, after the wording pass.

Before publishing, check each sentence against the shipped build. Do not claim sync, sharing between people or guaranteed reminders.

## Screenshots

Use the demo library with the Debug-only launch argument `--demo-library` on the 6.9-inch iPhone 17 Pro Max simulator. App Store Connect scales the 6.9-inch set for smaller iPhones, so no 6.5-inch set is needed. Light mode, default text size, status bar at 9:41.

1. **Find** showing "Running shoes" and its place path. Caption: "Find your things by place".
2. **Voice memo** with the heard sentence and the filled-in Put away screen. Caption: "Say where it is. Check it. Save it."
3. **Lending** showing a lent thing with its ask-back date. Caption: "Know who to ask for it back".
4. **Trip detail** with packing progress. Caption: "Reuse your packing list".
5. **Places** showing a room with a box inside. Caption: "Every room, shelf and box". *(Changed 10 November: the Pro screen showed US prices in every country's listing, so it is kept only as the products' review screenshot, `Docs/Store/Review/pro.png`.)*

Voice memos ship (owner, 8 November), so shot 2 stays.

Simulator QA screenshots in `Docs/Verification` are not store screenshots. Remove any real names or numbers from documents shown on screen.

## App Review notes

Paste into App Store Connect, App Review Information. These notes carry no prices, because they differ by country; the paywall shows each country's price from the App Store.

> Hereabouts needs no account or login. The notebook is stored on the device.
>
> The free plan allows 15 things, 1 kit and 2 homes. Pro removes those limits. There are monthly and yearly subscriptions and a one-time Lifetime purchase. The yearly subscription has a one-week free trial; the monthly one has none. The products are dev.hereabouts.pro.monthly, dev.hereabouts.pro.yearly and dev.hereabouts.pro.lifetime in the group "Hereabouts Pro". All three support Family Sharing.
>
> Pro includes automatic weekly backups of the whole notebook. They're on by default and go to the person's own iCloud Drive, or the device if iCloud Drive is off. The newest five are kept. Subscriptions also include regular updates. Household sharing is planned for version 1.1. If Pro ends, saved data remains visible, editable and exportable.
>
> To reach the paywall, open Settings (the tab at the bottom right on iPhone, or in the sidebar on iPad), then tap Hereabouts Pro. The screen shows the current plan, what Free and Pro each include, and the three ways to pay. Restore purchases, Privacy Policy and Terms of Use are on the same screen. Purchases can be tested in the sandbox. Adding a 16th thing on the free plan also opens the paywall.
>
> Shelf photos and voice understanding use Apple's on-device model on devices that support Apple Intelligence. On other devices, the app uses simpler rules. Voice memos are transcribed on the device with Apple's Speech framework. The recording isn't kept. Nothing is saved until the person taps Save.
>
> Reminders are local notifications. Hereabouts doesn't use the calendar.
>
> Hereabouts runs on iPhone and iPad. On iPad, places and things show side by side, and it works in Split View, Slide Over and Stage Manager.
>
> Privacy policy: https://hereaboutsapp.com/privacy. Support: https://hereaboutsapp.com/support.

Replace both links if the domain changes.

## Reviewer walkthrough

Ten steps from a fresh install to the paywall and back, for the review notes' reader and for the owner's own rehearsal (M45):

1. Install the build on a clean phone and open Hereabouts. The introduction appears.
2. Page through the introduction and tap through to the Find tab. No account or permission is asked for, and no plan is chosen: page 2 says the first 15 things are free and that the plan can be changed in Settings.
3. Add a first thing by name, for example "Spare key", and save it.
4. Add a place for it, for example "Hall shelf", and put the thing there.
5. Go back to Find and search "key". The thing appears with its place.
6. Open the Settings tab (bottom right) and check the four tabs: Find, Places, Trips, Settings.
7. In Settings, tap Hereabouts Pro. The screen shows, from the top: your plan (Free, with how many things, kits and homes are used); Free and Pro side by side; and the three ways to pay, each with the price from the App Store, the yearly trial, that it renews automatically, Restore purchases, and the Privacy Policy and Terms of Use links.
8. In the sandbox, buy a plan (or tap Restore purchases). The plan card at the top changes to Pro, with the plan, when it renews and the price.
9. Go back to Find and add things until the free limit would have been reached. With Pro on there is no limit. On a fresh install without Pro, the 16th thing opens the same paywall instead.
10. Close the paywall and return to Find. Everything saved is still there.

## App Privacy label

- **Data collection:** "Data Not Collected". Hereabouts has no server, analytics, advertising or tracking SDK.
- **Privacy manifest:** `Localiser/PrivacyInfo.xcprivacy` declares app-private UserDefaults use, reason `CA92.1`. Check the final archive's privacy report before submitting.
- **Policy text:** `Site/privacy.html`. It covers on-device storage, homes, lending and the contact picker, private things, shelf-photo names, box labels, voice memos, automatic backups to the person's iCloud Drive, the widget, notifications, StoreKit, deleting data and support emails.

## Owner inputs

These live in checklist A of `RELEASE_PLAN.md` (section 4): domain and email, the App Store Connect products and price schedule, name clearance, TestFlight and the physical checks above. Uploading, inviting testers and submitting each need the owner's explicit go-ahead.
