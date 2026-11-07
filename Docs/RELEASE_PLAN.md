# Hereabouts 1.0: release plan and checklist

Written 7 November 2026 against commit `ca75b98`. This replaces the 5 November plan. It keeps every open item from that plan and adds the owner's decisions of 7 November:

- Return, warranty and expiry dates leave the app, along with receipt scanning. They may become a separate app later. The "ask for it back" date for lent things stays.
- Settings moves from the gear at the top left into its own tab, at the bottom right.
- The widget's new job is two quick buttons, Find and Say it, plus a medium widget listing what you've lent out.
- Voice memos are attempted for 1.0. If they aren't good enough in time, they move to 1.1.
- Codex rewrites every piece of wording in the app so it reads naturally.

`FEATURE_PLAN.md` stays the record of what each feature is, and item M39 updates it for these decisions. `BETA_AND_RELEASE.md` stays the home of the listing text, the review notes and the beta script. The raw reviews are in `RELEASE_PLAN_SECOND_OPINION.md`.

Nothing in this plan authorises an upload, a purchase, a message to anyone, an invitation or a submission. Each one needs the owner's explicit go-ahead at the time.

**How to read it**

- **O** items are the owner's (checklist A, section 4). **M** items are done on this Mac (checklist B, section 5). Feature codes are the ones in `FEATURE_PLAN.md`.
- Every M item gives the file and line, the change, the check that proves it, and where it came from.
- Source key: **P** = the 4 November plan. **X1** = Codex's review of it. **C2** = Claude's file-by-file pass, 5 November. **X2** = Codex's file-by-file pass, 5 November. **D** = the owner's decisions of 7 November. **merge** = found while writing a plan.
- Priority: **P0** must be in the first TestFlight build. **P1** must be in the submitted build. **Gated** waits for an owner step.
- Effort is in working sessions. These are estimates.

## 1. What 1.0 is

**In 1.0**

- Finding things: places, homes (two free) with moving things and places between them (M62), search, private things, Found it, Put away with the Control Centre button and the Action button, box labels, and shelf-photo names on supported iPhones.
- Lending, with an optional "ask for it back" date and its reminder.
- Trips and packing kits, the Sunday recap and the monthly stocktake.
- Siri: where is it, write it down, put it away, I found it.
- Pro: no limits on things, kits and homes, plus automatic weekly backups (M59). The free plan has 15 things in total, 1 packing kit and 2 homes (M60). Sold monthly, yearly or as Lifetime, with a two-week trial on the plans (O4). Voice memos are unlimited for everyone.
- Settings as the fourth tab, bottom right. The tabs become Find, Places, Trips and Settings.
- The widget's two buttons, Find and Say it, at small size and on the Lock Screen.
- Voice memos, if they pass the voice rule below.
- Five languages (owner, 7 November): English (US), English (UK), French, Spanish and Portuguese (M63).
- The lent-out widget and the shared notebook file (B1), if they pass the cut rule below.

**Out of 1.0**

- Return, warranty and expiry dates, receipt scanning, pasting an order email (A9), the Due tab, Add to Calendar, the share sheet (B3) and the "What's due?" Siri phrase. The last commit before they go is tagged so a separate app can start from it (M1).
- B4 iCloud sync, unless it passes its two-device week during the beta. B6 household sharing. Both are 1.1.
- iPad and Mac layouts. The app still runs on iPad in compatibility mode and is checked there.
- Buying Lifetime while subscribed (O5). Apple's purchase sheet handles it; the app explaining it waits for 1.1.
- Anything else new. During the beta, only fixes go in.

**Voice rule.** Voice memos ship in 1.0 only if all of these hold when Stage 1 ends:

1. M20 is merged, within its three sessions.
2. On the 50 practice sentences in M20, at least 90% come back with the right name and place, corrections included.
3. A place the notebook doesn't know is never filled in on its own, and nothing is saved without a tap.
4. It works with no network on iOS 26.

Otherwise the microphone button and the widget's Say it button are switched off for 1.0, and voice memos become the 1.1 headline.

**Cut rule for the shared notebook and the lent-out widget.** They ship in 1.0 only if, when the first TestFlight build is due, M50 (the safe notebook move) is merged with its tests and the owner's real-notebook move (O32) has passed. Otherwise they move to 1.1. The two widget buttons don't depend on this.

**Release gates.** No public launch with an open data-loss defect, a place filled in without the person seeing it, or missing proof that real reminders arrive. This replaces the wording in `BETA_AND_RELEASE.md` line 47, whose middle gate was about scanned dates (M38 updates it, O2 confirms it).

## 2. Where things stand

**The app**, checked on 4 November 2026 on Xcode 27.2. The code hasn't changed since.

| Check | Result |
| --- | --- |
| Debug build, iPhone 17 simulator | Builds, 12 warning lines |
| Release build, generic iOS device, unsigned | Builds, 10 warning lines. Debug-only code is fenced correctly |
| Release bundle | Both fonts with their licence texts, the privacy manifest, the Control Centre extension, `HereaboutsFreeThings` = 20 |
| Unit tests, iOS 26.5 simulator | 114 run, 0 failures, 6 purchase tests skipped below iOS 27 |
| UI tests | 18, not run since October |
| Reviews | Four whole-app reviews. 32 findings from the last one, all confirmed. Those about receipts, dates and the share sheet are now cut with the feature (section 9) |

**The developer account**, as of 7 November 2026.

| Item | State |
| --- | --- |
| Apple Developer Program | Enrolled 6 November as an individual. Team ID `BRLCAAM57K`, the same as the old free team. Renews 6 November 2027 |
| Free Apps Agreement | Active |
| Paid Apps Agreement | Processing (all forms in, 7 November) |
| Bank account | Active |
| US tax form W-8BEN | Active |
| Canadian GST/HST Form 506 | Active. Registered with the CRA 7 November, annual filing |
| EU trader status | Declared a trader, in review |
| US Certificate of Foreign Status | Active |

Nothing has been uploaded, published, purchased or sent to anyone.

## 3. Order of work

| Stage | Who | Items | Done when | Effort |
| --- | --- | --- | --- | --- |
| 0. Decisions | Owner | O1 to O7 | Each answer is written down in this conversation. O3 and O4 are answered | — |
| 1. Build 1.0 | Mac, Codex (M41 and M64 only) | M1 to M47 and M63, in order, then M64 last | All merged. Unit tests pass on iOS 26.5 and 27.0, all UI tests pass, no warnings. The voice rule is decided | About 14.5 sessions, plus Codex's pass |
| 2. Business, identifiers, site | Owner | O8 to O19 | Paid Apps Agreement active, App Group registered, pages live | CRA and Apple checks take days |
| 3. After those steps | Mac, then owner | M48 to M53, O20 to O33 | Signed device builds on both phones. The cut rule is decided | 1.5 sessions |
| 4. Beta | Owner, then Mac | O34 to O44, M54 to M56 | A week of real use. The physical checks and the quality check pass | At least one week |
| 5. Submission | Owner | O20 to O30 finished, section 7, O45, O46 | The pre-submit check is all ticked | — |

Stages 1 and 2 run side by side. Inside Stage 1, the cut and the Settings tab go first, because most later items touch the same screens. Each M item is its own local commit on `main`, with tests green (the owner agreed to local commits on 7 November; nothing is pushed), except Codex's pass, which uses its own branch (M41). Nothing is pushed or uploaded.

Codex's usage is limited, so it does only the wording pass (M41) and the fixes from its review (M42), run once after the feature work is merged, and one of the two adversarial audits at the very end (M64). The wording pass comes first if its usage runs short. Claude builders do every other M item (owner, 7 November).

## 4. Checklist A: owner-blocked

### Decisions

- [x] **O1 Orientation.** Portrait only, decided 7 November (M23).
- [ ] **O2 1.0 scope.** Confirm section 1, including the voice rule, the cut rule and the reworded release gate.
- [x] **O3 English variant.** American English (en-US), decided 7 November. Codex's wording pass (M41) settles the spelling.
- [x] **O4 How Pro is sold in 1.0.** Option B, decided 7 November: US$2.99 a month, US$19.99 a year with a two-week trial, and US$49.99 Lifetime, as planned on 12 October. **Prices by country** (owner, 7 November): the US prices are the base, and every other country gets Apple's automatic equivalent of them, except Canada, which is set by hand to the same numbers in Canadian dollars: CA$2.99, CA$19.99 and CA$49.99. Canadian prices on the App Store are shown before tax, with GST/HST added at checkout, and a price set by hand doesn't follow exchange rates. M30 and O23 apply, and the review notes make the case for ongoing value (M34). If App Review rejects the subscriptions under guideline 3.1.2(a), the fallback is to detach them and ship Lifetime only (Option A), with the subscriptions returning in 1.1 alongside household sharing.
- [x] **O5 Two product gaps.** Decided 7 November: moving a thing or place to another home is in 1.0 (M62); explaining Lifetime while subscribed waits for 1.1.
- [x] **O6 The phone for the speed check.** The iPhone 16 Pro Max, decided 7 November; results are labelled "slowest phone tested". Original wording: The quality check times search over 5,000 records on the slowest supported phone. Say which phone; if only the iPhone 16 Pro Max is available, the result is labelled "slowest phone tested".
- [ ] **O7 The listing's subtitle and wording.** The subtitle "Find things, track returns" has to change. Approve the new subtitle, description and captions after Codex's pass (M36, M41).

### Business and accounts

- [x] **O8 Enrol in the Apple Developer Program.** Done 6 November.
- [ ] **O9 Paid Apps Agreement.** Accepted. It turns Active once the bank, both tax forms and Apple's checks are through. See section 2.
- [x] **O10 Register with the CRA.** Done 7 November; Form 506 is Active. Use Business Registration Online as a sole proprietor and open a GST/HST account. Enter the 9-digit Business Number and the RT number (usually 0001) on Form 506 in App Store Connect, under Business. Registering means filing GST/HST returns from then on; ask an accountant how often.
- [x] **O11 The leftover US tax row.** Filed 7 November; Active. If "U.S. Certificate of Foreign Status of Beneficial Owner" still shows missing once everything else is in, ask Apple through Contact Us rather than filing a second form.
- [ ] **O12 Small Business Program** (15% commission). Apply once the Paid Apps Agreement is Active, before the first sale.
- [x] **O13 EU contact details.** Decided 7 November: keep the current details for now. They can be changed later under Business, Compliance; Apple checks the new details again, and anything already shown may have been seen or copied.

### Identifiers

- [x] **O14 Bundle ID.** Registered 7 November as `dev.hereabouts.app` ("Hereabouts"), `dev.hereabouts.app.controls` and `dev.hereabouts.app.widget`. The app ID has App Groups, iCloud and In-App Purchase; the widget has App Groups. M61 moves the code to these IDs.
- [x] **O15 App Group.** Registered 7 November as `group.dev.hereabouts.app` and linked to the app and the widget.
- [x] **O15a iCloud Drive container.** Registered 7 November as `iCloud.dev.hereabouts.app` and linked to the app. It can never be deleted.
- [ ] **O16 Name.** Check "Hereabouts" is free when you create the app record, and search trademarks where you'll sell.

### Website and mailbox

- [ ] **O17 Domain.** Own and host a domain, and tell me the site address and support email (M49).
- [ ] **O18 Put the two pages live** at `/privacy` and `/support` once M32, M33 and M41 are merged. Open both from a phone off your Wi-Fi.
- [ ] **O19 Support mailbox.** Set it up and test it from a phone.

### App Store Connect

- [ ] **O20 App record.** Name, primary language (per O3), bundle ID, SKU. Productivity, with Utilities second.
- [ ] **O21 Products.** `dev.hereabouts.pro.lifetime` at US$49.99, non-consumable, Family Sharing on. Then `dev.hereabouts.pro.monthly` at US$2.99 and `dev.hereabouts.pro.yearly` at US$19.99 in the group "Hereabouts Pro", each with a two-week free trial. Family Sharing can't be turned off later. For each product, choose the United States as the base country so Apple fills in the other countries, then change Canada by hand to CA$2.99, CA$19.99 and CA$49.99 (O4).
- [ ] **O22 Product metadata.** A display name, description and review screenshot for each product and for the subscription group.
- [ ] **O23 Billing Grace Period**, 16 days.
- [ ] **O24 App Privacy.** "Data Not Collected". Voice memos are transcribed on the phone and the recording is not kept, and automatic backups go to the person's own iCloud Drive, which the developer can't see, so this answer doesn't change. Apple's own TestFlight crash reports don't count.
- [ ] **O25 Age rating.** Expect 4+.
- [ ] **O26 URLs.** Privacy Policy and Support URLs. The Terms of Use line goes at the end of the description.
- [ ] **O27 Availability.** Turn off Mac and Apple Vision Pro for 1.0.
- [ ] **O28 Review notes.** Paste the rewritten notes (M34). No demo account is needed.
- [ ] **O29 Attach the products to the 1.0 version** before submitting.
- [ ] **O30 TestFlight test information**: a beta description, a feedback email and a review contact.

### Hands-on checks

- [ ] **O31 Reinstall** on your iPhone and Angela's from the paid team, moving each notebook across with a backup first (M61). Never seed a personal phone with the demo library.
- [ ] **O32 Real-notebook move** (only if the shared notebook ships). Install the current build, then the App Group build, open it twice, and check every thing, place and photo is still there. The steps (written with M51):
  1. Before anything else, make a backup in Settings and send it to yourself. Note how many things, places and photos you have (the Find and Places tabs; open three things that have photos).
  2. Build the commit before M51 onto your iPhone, open it, and check the notebook is as you noted. Close it.
  3. Build the App Group commit over the top (don't delete the app). Open it once and check the same counts, and the same three photos. The old notebook is kept on this first launch.
  4. Force-close it and open it a second time. Check the counts and photos again. The old notebook is removed on this launch.
  5. Add a thing with a photo, lend one out, close and open the app once more. All of it should still be there.
  6. If anything is missing at any step, stop, don't delete the app, and send me the backup from step 1. The move falls back to the old notebook when the new one doesn't open or its counts don't match.
- [ ] **O33 Shelf photo** on the iPhone 16 Pro Max with Apple Intelligence on. Is it worth keeping? Try it once with Keep private on.
- [ ] **O34 Voice memos in your own words.** Say 20 sentences the way you'd really say them, in a quiet room and a noisy one, with and without Wi-Fi. Note each one it got wrong. This feeds the voice rule.
- [ ] **O35 Sandbox purchases.** Buy each product; start both trials and cancel; restore on a second device; a failed purchase; Ask to Buy; a refund; Family Sharing. After the refund, check everything is still visible, editable and exportable.
- [ ] **O36 First run on a clean phone.** Introduction, first thing, first place, a voice memo, lending with an ask-back date, a kit, the Sunday recap preview, erase.
- [ ] **O37 Screenshots.** Approve the set from M46.
- [ ] **O38 Codex's wording.** Read the before-and-after list from M41 and M42, and mark anything that doesn't sound like you.
- [ ] **O39 Physical-device checks**, one tick each:
  - [ ] iOS 26 on the smallest supported phone you can borrow, and phones with and without Apple Intelligence.
  - [ ] Airplane mode with no iCloud account: create, edit, move, search, a voice memo and relaunch, with nothing lost.
  - [ ] Name-only capture and search timed with 5,000 records, on the iPhone 16 Pro Max (O6).
  - [ ] Every tab, Settings and Pro in light and dark, at the largest text size, and with VoiceOver.
  - [ ] Tips appear once and in order.
  - [ ] Notifications: deny, revoke, an ask-back reminder, force-quit, idle for days, change time zone. The Settings tab's warning shows when notifications are off.
  - [ ] Purchases, done as O35.
  - [ ] Voice: microphone denied, then allowed; a long sentence; a place the notebook doesn't know is left blank; live speech from the microphone (the simulator only tried typed and stand-in text); the first memo downloads the speech model, and after that one works in airplane mode (part 4 of the voice rule).
  - [ ] Siri: "Where is <thing> in Hereabouts", "Write something down in Hereabouts", locked and unlocked. The 16th free thing is refused politely. A private thing's place is never spoken. A missing thing is reported as missing.
  - [ ] Sunday recap, first-Saturday stocktake and trip-eve reminder arrive, open the right sheet, and stop when turned off.
  - [ ] Automatic backups: one arrives in iCloud Drive, a restore from it brings everything back, and turning Pro off keeps the saved ones.
  - [ ] Widgets: both buttons at small size and on the Lock Screen; the lent-out widget if it ships.
  - [ ] iPad in compatibility mode, all four tabs.
- [ ] **O40 Quality-check examples.** 200 capture sentences, written as people would say them, and 100 search pairs, from people who didn't write the code. I freeze the commit and score them (M47).
- [ ] **O41 Ask Angela** whether she'll be the second tester.
- [x] **O47 Voice memos in other languages.** Decided 7 November: English only in 1.0. The microphone and Say it buttons show only when the app's language is English; French, Spanish and Portuguese voice memos come in 1.1, each with its own practice sentences and the voice rule.
- [ ] **O48 A fluent reader for each language.** Have someone who speaks French, Spanish, Portuguese and British English read the app in that language (the screenshots from M63 are enough to start), and mark anything that sounds machine-made. Defaults chosen for you, change any: international French (serves France and Canada), one neutral Spanish (Spain and Latin America), Brazilian Portuguese (Portugal falls back to it).
- [x] **O49 Listing languages in App Store Connect.** Approved 7 November; I add them in App Store Connect once O20 and M63 are done. Add English (U.K.), French, French (Canada), Spanish (Spain), Spanish (Mexico) and Portuguese (Brazil) to the listing, and paste the text from `Docs/Localization/LISTING.md` (M63). Screenshots can stay English at first; App Store Connect uses them for every language that has none.

### Go-aheads (each one separately, at the time)

- [ ] **O42** Upload the first build to TestFlight.
- [ ] **O43** Invite each tester. External testers need O30 and Apple's beta review.
- [ ] **O44** Upload each later build.
- [ ] **O45** Submit 1.0 for review.
- [ ] **O46** Release it, on manual release.

## 5. Checklist B: everything else

### Stage 1, part A: the cut, the Settings tab and the free limits (P0, 3.25 sessions)

- [x] **M1 Keep a starting point for the receipts app.** Tag the current `main` as `receipts-spinoff-base` (local only). Add `Docs/RECEIPTS_SPINOFF.md` listing what a separate app would start from: `Scanning/`, `Dates/DateRules.swift`, `Dates/ReminderService.swift`, `Dates/CalendarExport.swift`, `Dates/DueView.swift`, their tests, and the release-plan findings about them (section 9). · D
- [x] **M2 Remove receipt scanning.** Delete `Scanning/ScanReader.swift`, `ScanView.swift`, `OrderEmail.swift` and `ShareImport.swift`, and every button that opens them. `Recovery/LibraryBackup.swift:162` uses `ScanReader.maximumBytes` for the 20 MB photo check; move that constant into `LibraryBackup` before deleting `ScanReader`. Remove `CreationKind.scan` (`Purchases/ProAccess.swift:6`) and the scan count from `LocaliserStore`. Keep the `ScanRecord` entity in the data model, unused, so no migration is needed. **Check:** the app builds with no reference to the deleted files; `OrderEmailTests` and `ShareImportTests` are deleted; scan cases leave `LocaliserTests`. · D
- [x] **M3 Remove return, warranty and expiry dates.** Remove the Due tab (`LocaliserApp.swift:71`) and `Dates/DueView.swift`, `Dates/CalendarExport.swift`, the "What's due?" intent and its phrases (`System/Intents.swift:145` and `:204`), the `hereabouts://due` link, and the Returning it and Keeping it notification buttons (`Dates/ReminderService.swift:32` to `:34`). Shrink `DeadlineKind` (`Dates/DateRules.swift:43`) to `askBack`. The thing page shows the ask-back date as "Ask for it back · <when>", which also fixes the old "Expires" label. The 50-reminder queue stays for ask-back dates. **Check:** `LendingTests` cover setting, reminding and clearing an ask-back date; no test refers to the removed kinds. · D, X2
- [x] **M4 Follow the cut through.** Every place that mentioned dates or scans:
  - The introduction's reminders page: list the ask-back reminder, the trip-eve reminder, the Sunday recap and the stocktake.
  - The Sunday recap (`Rituals/Rituals.swift:107`): drop dates due this week, keep ask-backs.
  - Tips: remove the Scan and Add to Calendar tips.
  - The demo library: no receipts or return dates.
  - The paywall and the Pro list: no limits on things, kits and homes, automatic backups (M59), and household sharing marked as coming later.
  - `project.yml:64` to `:66`: delete the calendar usage string; take receipts out of the camera and photo strings.
  - Backups: restoring an older backup skips return, warranty and expiry dates and scans, and keeps ask-back dates. On first launch after the update, delete those dates and scans from an existing notebook.
  - **Check:** a restore test with a format-3 backup that holds all four kinds keeps only the ask-back date; a search of the code finds no "receipt", "warranty", "expiry" or "Due" left in visible wording. · D
- [x] **M5 Settings becomes a tab, bottom right.** Add `AppTab.settings` (`LocaliserApp.swift:58`) as the last tab, labelled Settings with the gear symbol, showing `LibrarySettingsView` in its own navigation stack. Remove the gear buttons (`Find/FindView.swift:83` and `:106`, and the `SettingsButton` modifier at `Recovery/LibrarySettingsView.swift:235`). The three `dismiss()` calls in Settings go, since it's no longer a sheet; "Show the introduction again" switches to the Find tab. The notification warning badge moves from the Due tab to the Settings tab. **Check:** UI tests reach Settings and Pro through the tab; the review notes' route becomes "Settings tab, Hereabouts Pro". · D

- [x] **M60 New free limits: 15 things and 1 kit** (owner, 7 November). Numbered last but done with this part. Things count in total across all homes, as now. Set `HEREABOUTS_FREE_THINGS` to 15 at `project.yml:14` and the fallback at `Purchases/ProAccess.swift:14` (and its comment at line 10). Set the kit limit to 1 at `ProAccess.swift:8`. Homes stay at 2. Over-limit notebooks keep everything; only adding is blocked, and archiving frees a space. Free-team phone builds keep 200. **Check:** `LocaliserTests.swift:24` expects 15; a kit test refuses the second kit; `ShelfPhotoTests` still pass with their own limit. · D

- [x] **M61 Move to the Hereabouts identifiers** (owner, 7 November). Numbered last but done with this part. Change every `dev.localiser` identifier to `dev.hereabouts`: the bundle IDs in `project.yml` (and regenerate the project), `ProPlan.prefix` at `Purchases/ProAccess.swift:22` so products become `dev.hereabouts.pro.monthly`, `.yearly` and `.lifetime`, the three products in `LocaliserTests/Localiser.storekit`, `SubscriptionTests`, the Spotlight domain at `System/Spotlight.swift:7`, and the control kind at `HereaboutsControls/HereaboutsControls.swift:13`. Folder and target names stay as they are. A new bundle ID installs as a different app, so the old Hereabouts on your phone and Angela's keeps its notebook: before O31, make "Back up everything" in the old app, restore it in the new one, check it, then delete the old app. **Check:** a search finds no `dev.localiser` outside the docs' history; unit and UI tests pass; a signed device build installs. · D

### Stage 1, part B: wrong answers and privacy leaks (P0, 1 session)

- [x] **M6 A missing thing is reported as missing.** `System/Intents.swift:97` and `System/AppLinks.swift:75` give the recorded place for a thing marked Not there. After the private and archived checks, say "<name> is marked missing. It was last in <path>." **Check:** `IntentsTests` and `AppLinkTests`. · X2
- [x] **M7 The Shortcuts picker doesn't find private things by place or notes.** `System/Intents.swift:50` searches the full index. Keep a private thing only when the query matches its name or another name. **Check:** in `PrivateThingsTests`, a private passport in a drawer isn't found by "drawer", and is found by "passport" with the path "Private". · X2
- [x] **M8 "Several things in this photo?" keeps Keep private.** Add `isPrivate` to `addItems` (`Find/ShelfPhoto.swift:83`) and `ShelfNamesView` (line 89), passed from `Find/FindView.swift:411`. **Check:** `ShelfPhotoTests`. · X2
- [x] **M9 Found it keeps a thing in the right home.** `Find/Finding.swift:15` sets the place but not the home. Set the home as `recordMove` does (`Data/LocaliserStore.swift:193`), and limit `foundSuggestions` (line 27) to the thing's home. **Check:** `FindingTests` with two homes. · X2
- [x] **M10 Trips shows the chosen home.** `Packing/PackingView.swift:9`, `:10` and `:15` read `store.trips`. Use `store.tripsHere` and add `HomeSwitcher()` as Find does (`Find/FindView.swift:125`). **Check:** extend `testAddingAndSwitchingHomes`. · X2
- [x] **M11 Trip-eve reminders go to the nearest trips.** `Dates/ReminderService.swift:119` takes five trips sorted latest first. Sort earliest first in `Rituals.tripsNeedingEveReminder` (`Rituals/Rituals.swift:131`). **Check:** `RitualsTests` with six trips. · X2

### Stage 1, part C: smaller defects (P1, 1.25 sessions)

- [x] **M12 The stocktake leaves lent things out.** Add `!$0.isLent` to `stale` (`Rituals/Rituals.swift:54`). **Check:** `RitualsTests`. · X2
- [x] **M13 No recap banner on the first day.** `Rituals/RitualViews.swift:243` treats an empty read-week key as unread. Seed it with the current week on first appearance. **Check:** a `RitualsTests` case before and after the first Sunday 18:00. · X2
- [x] **M14 Tidying duplicate places keeps packing return places.** `Places/DuplicatePlaces.swift:25` deletes a spare without moving its `tripHomes`. Point them at the keeper first. **Check:** `DuplicatePlacesTests`. · X2
- [x] **M15 Restore saves once.** `Recovery/LibraryBackup.swift:104` saves, then `ensureHomes` (`Data/Homes.swift:71`) saves again. Move the delete loop inside `do` and make one save. **Check:** a format-2 restore over an existing notebook leaves one home and no unsaved changes. · X2
- [x] **M16 The failure screen's copy includes photos.** `LocaliserApp.swift:130` leaves out the `.Localiser_SUPPORT` folder. Add it, or rename the button to say photos stay on the phone. · X2
- [x] **M17 Replaying the introduction at the limit says why.** `Onboarding/OnboardingView.swift:168` ignores Pro. Use `pro.allows(.item, count:)` and show the editor's message (`Find/FindView.swift:434`). **Check:** a unit test for Pro and free. · X2
- [x] **M18 Siri's place choices name the home.** `System/Intents.swift:60` to `:79`: with several homes, title a place "<home> · <path>". **Check:** `IntentsTests`. · X2
- [x] **M19 The paywall UI test on iOS 27.** `LocaliserUITests/LocaliserUITests.swift:28` accepts "Pro isn't available" on any iOS. Accept it only below iOS 27. · X2

### Stage 1, part D: new features (P0, 6.5 sessions)

- [x] **M20 Voice memos, time-boxed to three sessions.** Hold the microphone button on Find, or tap Say it on the widget, and say something like "the spare key's in the blue tin on the hall shelf".
  - **Hearing:** transcribe on the phone with the Speech framework's on-device transcriber (iOS 26), English only. Download the speech model on first use and say so if there's no network then. Keep no recording.
  - **Understanding:** first, rules that split the sentence at words like in, on, under, behind and inside, and match the place half against existing places, other names and path parts. On iPhones with Apple Intelligence, use the on-device Foundation Models framework to pull out the thing and the place when the rules can't.
  - **Saving:** open the existing Put away screen with the name and place filled in. A place the notebook doesn't know stays blank, with a "New place: <words>" suggestion to tap. Nothing saves without a tap. The free limit applies.
  - **Permissions:** add the microphone usage string, and the speech recognition string if the framework asks for it.
  - **Check:** a parser test over 50 practice sentences written now (not the owner's holdout), at least 90% right on name and place; tests that an unknown place is never filled in; a UI test with a stand-in transcript. The voice rule in section 1 decides whether it ships. · D
- [x] **M21 Widget buttons.** A widget extension, `dev.hereabouts.app.widget`: a small widget and a Lock Screen widget with Find (opens search) and Say it (opens the voice memo). They read nothing from the notebook. Give the extension a privacy manifest. If voice memos miss 1.0, the widget shows Find alone. **Check:** both open the right screen on the simulator. · D *Done 7 November: the links open Find and the voice memo (unit tests); tapping the widget itself is checked on the phone in O39.*
- [x] **M22 Help people find Siri.** Add Siri tips to the Find tab for "Where is…" and "Write something down", and a line on the introduction's last page. · D *Done 7 November. The tips are hidden in UI tests (the system view fails the accessibility audit), so their text is checked by eye on the phone (O39, tips).*

- [x] **M59 Automatic backups (Pro).** Numbered last so the other numbers stay put; it belongs in this part. Once a week, and when the app opens if a week has passed, write the same backup "Back up everything" makes (format 3, with the photos the person chose) to the app's iCloud Drive folder, or to the phone if iCloud Drive is off. Keep the last five and delete older ones. Settings shows "Automatic backups: on, last one <when>" with a switch, and Restore lists the saved backups by date. Free keeps the manual button. A lapsed subscription stops new backups but never deletes the saved ones. Add the iCloud Drive container (`iCloud.dev.hereabouts.app`, documents only, no CloudKit) to the entitlements. **Check:** unit tests for the weekly schedule, keeping five, the lapsed-Pro case and restoring from the list; one real backup and restore on a phone (O39). · D *Merged 7 November. A follow-up moves the encoding off the main thread and coordinates iCloud Drive files, including ones not yet downloaded.*

- [x] **M62 Move to another home** (O5, owner 7 November). Numbered last but done with this part. On a thing's page, "Move to another home" picks a home, then a place in it (or the new home's top level). On a place's page, the same moves the place with everything inside it, its sub-places and their things. Packing kits and trips that point at a moved place keep pointing at it. The Siri place choices and Found it follow the new home (see M9 and M18). Private things stay private. **Check:** `HomesTests` for moving a thing, a place with nested places and things, a place used as a trip's return place, and a move into a home at the free limit (allowed: a move isn't a new thing); a UI test of the thing move. · D

### Stage 1, part E: release hygiene (P0, 1 session)

- [x] **M23 Portrait only** (O1). Set iPhone orientations to portrait at `project.yml:63`; leave iPad as it is for compatibility mode. **Check:** rotating the simulator leaves every screen upright. · P, X1
- [x] **M24 No build warnings.** `Places/BoxLabels.swift:183`, `Support/Support.swift:26`, `Data/NotebookFile.swift:95`. **Check:** zero warnings in Debug and Release. · P
- [x] **M25 Privacy manifest for the Control Centre extension.** Add `HereaboutsControls/PrivacyInfo.xcprivacy`. · P
- [x] **M26 Acknowledgements in Settings**, naming both typefaces with their licences. · P, C2
- [x] **M27 No badge permission.** `Dates/ReminderService.swift:38`: ask for alerts and sounds only. · C2
- [x] **M28 A stale comment** at `Onboarding/OnboardingView.swift:3`. · C2
- [x] **M29 Release check script.** `scripts/check-release.sh` fails unless the free limit is 15 and the kit limit 1, the App Group is as intended, every target has a privacy manifest and both licence texts are present. · P
- [x] **M30 Trial shown per product** `Purchases/ProAccess.swift:83` and `:119` read one trial flag for both plans. · P, X1
- [x] **M31 Signing.** Set `DEVELOPMENT_TEAM` to `BRLCAAM57K` at `project.yml:10`, regenerate, and check a signed device build and an archive succeed. · P

### Stage 1, part F: the facts in the docs (P0, 1 session)

These set what's true. Codex's pass then makes it read well.

- [x] **M32 Support page.** The free plan becomes "15 things, 1 packing kit and 2 homes". Remove receipt answers. Say "Back up everything" carries only the photos you tick. Say a restore replaces the whole notebook. Add how to cancel a subscription. · P, X2, D
- [x] **M33 Privacy page.** Remove receipts and calendar. Add homes, lending and the contact picker, private things, shelf-photo names, box labels, voice memos (transcribed on the phone, recording not kept), automatic backups to your own iCloud Drive, the widget, the trial reminder, what StoreKit tells the app, deleting your data, and support emails. · P, X1, C2, D
- [x] **M34 Review notes.** No account; the free plan; Pro per O4 and what it keeps giving (no limits, weekly automatic backups, household sharing coming in 1.1); the route to the paywall through the Settings tab; sandbox testing; shelf photos and voice understanding on supported iPhones; iPad compatibility mode; the final URLs. · P, X1, D
- [x] **M35 Reviewer walkthrough.** Ten steps from a fresh install to the paywall and back. · P, X1
- [x] **M36 Description and subtitle.** A draft without receipts or returns, with Homes, lending, private things and voice memos (if they ship), and the Terms of Use line. For the owner to approve in O7. · P, X1, D
- [x] **M37 Screenshot list.** Drop the Due shot. Add voice memos (if they ship), lending and Pro. · merge, D
- [x] **M38 Beta doc.** In `BETA_AND_RELEASE.md`: the release gate at line 47 and the safety rule at line 26 (keep "never fill in an unknown place", drop the date half); the 201st free thing at line 43 becomes the 16th; the checks at lines 34 to 45 match O39; "Owner inputs" (line 131) points here. · X2, D
- [x] **M39 Feature plan.** In `FEATURE_PLAN.md`: A9 and B3 cut, B2 redefined, voice memos added, the receipts app noted for later. · D
- [x] **M40 One owner list.** Replace `HUMAN_BLOCKED.md` with a pointer to checklist A. Mark `CODEX_HANDOFF.md` and `AUDIT_AND_LAUNCH_PLAN.md` as history. · P, merge

### Stage 1, part G: wording that sounds human (Codex)

- [ ] **M41 Codex rewrites every piece of wording**, after parts A to F are merged and, ideally, after O3. The brief below is complete, because Codex can't see this conversation. Codex works on a local branch `copy-rewrite`, one commit per area, and pushes nothing. · D
- [ ] **M42 Review and merge.** I read every change against the brief, run all tests, and fix layouts that no longer fit. The owner signs off in O38. Then merge into `main`. · D

**Brief for Codex**

> Rewrite all user-facing wording in the Hereabouts iPhone app, its website and its store listing so it reads as if a thoughtful person wrote it: plain, warm, short, and specific. Hereabouts is a private notebook for where things are in your home. Change the words, not the behaviour.
>
> **In scope:** every string a person can see or hear in `Localiser/` and `HereaboutsControls/` and the widget: screen text, buttons, labels, alerts, errors, empty states, tips, the introduction, notifications, Siri dialogs and App Shortcut phrases, widget text, VoiceOver labels and hints, and the usage strings in `project.yml`. Also `Site/privacy.html`, `Site/support.html`, and the description, subtitle, captions and review notes in `Docs/BETA_AND_RELEASE.md`.
>
> **Out of scope:** code identifiers, comments, logic, layout and file names.
>
> **Rules:**
> 1. Write to one person, as "you". Use contractions. One idea per sentence. Prefer everyday words; no jargon, no marketing tone, no exclamation marks.
> 2. Keep the app's words consistent: thing, place, home, kit, trip, notebook, lend, ask for it back, put away, Pro. Don't introduce synonyms.
> 3. Keep every fact, except prices outside the app: the listing description, review notes and website don't state prices, because they differ by country (the App Store shows each country's price). The paywall must still show the price, the period, the trial terms if any, that it renews automatically, Restore purchases, and the Privacy Policy and Terms of Use links. Privacy promises must stay exactly as strong.
> 4. Spelling: American English throughout (color, favorite, organize, canceled). The current text mixes British and American spellings; make it all American.
> 5. Siri phrases must keep `\(.applicationName)` and stay short enough to say aloud. Don't remove a phrase people may already use.
> 6. Stay about the same length or shorter, so nothing clips at the largest text size.
> 7. When a UI test or unit test matches a string, update the test in the same commit.
>
> **Deliverable:** commits per area (Find, Places, Trips, Settings and Pro, introduction and tips, notifications and Siri, widget and Control Centre, usage strings, website, listing). Add `Docs/COPY_CHANGES.md`, a table of every change with file, line, before and after. All unit and UI tests pass.

### Stage 1, part G2: languages (P1, 2.5 sessions)

- [ ] **M63 Five languages** (owner, 7 November), after M42, so the translations start from the final English. A Claude builder does it. English (US) stays the source language; the app adds English (UK), French, Spanish and Portuguese. · P, X1
  - **Groundwork.** The app has no localization yet: no string catalogs and no `String(localized:)`. Set `developmentLanguage: en` and the known regions in `project.yml`, turn on `LOCALIZATION_PREFERS_STRING_CATALOGS` and `SWIFT_EMIT_LOC_STRINGS`, and add string catalogs for the app, `HereaboutsControls` and `HereaboutsWidget`: `Localizable.xcstrings`, `InfoPlist.xcstrings` (usage strings; the display name stays Hereabouts) and `AppShortcuts.xcstrings` (Siri phrases, each keeping the app name).
  - **Make every string localizable.** Text built as a plain `String` (alerts, errors, notification titles and bodies, App Intents dialogs, widget and control text including the lent-out rows' "Since" and "Ask back" in `LentOutRows.swift`, VoiceOver labels, tips) moves to `String(localized:)` or `LocalizedStringResource`. Counts use plural variations ("1 thing", "2 things"). Dates, numbers and prices go through formatters and StoreKit's `displayPrice`, never hand-built.
  - **Translate.** Use `xcodebuild -exportLocalizations` and `-importLocalizations`, or edit the catalogs directly. Write the way the English does: second person, short, warm, no marketing tone. French uses "vous", Spanish "tú", Portuguese "você". `Docs/Localization/GLOSSARY.md` fixes one word per language for thing, place, home, kit, trip, notebook, lend, ask for it back, put away and Found it; "Pro" and "Hereabouts" stay as they are. English (UK) changes only spelling and the odd word (colour, favourite, organise, cancelled). The paywall keeps every fact in every language: price, period, trial, automatic renewal, Restore purchases and both links.
  - **Search** ignores accents, so "cafe" finds "Café".
  - **Voice** is English only in 1.0 (O47): the microphone and Say it buttons hide in the other languages, and their strings are still translated for 1.1.
  - **Prices.** Never written into the app, the listing, the review notes or the website: the paywall shows StoreKit's price for the person's country, and the App Store shows its own (O4).
  - **Listing.** `Docs/Localization/LISTING.md`: the subtitle (30 characters at most), promotional text, description, keywords (100 characters at most) and the review notes' first line, for each App Store language in O49. Nothing is uploaded. The website pages stay English for 1.0.
  - **Check:** a unit test that every catalog entry is translated in every language, that format specifiers match the English, and that every Siri phrase keeps the app name; the UI tests pin English so they stay stable; a screenshot tour of every tab, Settings, Pro and the introduction in each language, at the default and the largest text size, saved to `Docs/Verification/Languages` for O48, with nothing clipped or overlapping.

### Stage 1, part H: verification (P0, 1 session)

- [ ] **M43 Unit tests** on iOS 26.5 and iOS 27.0, recorded in `BUILD_STATUS.md`. · P, X1
- [ ] **M44 All UI tests**, fixed until green. An accessibility-audit exemption only after checking the element by eye. · P
- [ ] **M45 Fresh-install Release walkthrough** on an iOS 27 simulator with the local StoreKit file: skip the introduction, open the Settings tab, open Pro, add 15 things and check the 16th opens the paywall. Screenshots to `Docs/Verification`. · X1
- [ ] **M46 Store screenshots.** Retake the set from M37 with the demo library on the iPhone 17 Pro Max simulator, including Pro. · P, X1
- [x] **M47 Quality-check harness.** Fixtures and a scoring script for capture (now through the voice parser), search and speed, waiting for O40. · P, X1, D *Done 7 November with 10 stand-in sentences and 10 search pairs (10 of 10 and 9 of 10; "tnet" for Tent is a real miss). O40's examples replace them.*

### Stage 1, part I: adversarial audit (P0, the very last step, 2 sessions)

- [ ] **M64 Two adversarial audits of the app's logic** (owner, 7 November), after everything else in Stage 1 is merged. Two auditors work separately and don't see each other's findings until both are done: I do one myself, and Codex (GPT 6.1 Sol, medium reasoning) does the other with the brief below. Each tries to break the code, not to review its style. Claude builders fix what's confirmed; I check each fix. If Codex's usage has run out, this half is recorded as blocked and discussed with the owner, not swapped for another auditor. · D
  - **What counts as the app's logic** (there's no server): the notebook store and its model (`Data/`), backups, restore and automatic backups (`Recovery/`), the notebook move to the App Group (`NotebookFile`), Pro and the free limits (`Purchases/`), lending and reminders, trips, kits, the recap and stocktake (`Rituals/`, `Packing/`), Siri and Shortcuts (`System/Intents.swift`, `PutAwayIntent.swift`), links (`AppLinks.swift`), Spotlight, search, moving between homes, the voice parser, the widget and the Control Center buttons.
  - **Each finding** comes with a failing test that proves it (or exact steps when a test can't), the file and line, what goes wrong for the person, and a severity: data loss or a privacy leak first, then a free limit that can be got round or a wrong answer, then a crash, then the rest. Fixes don't go into the audit branches.
  - **Check:** every confirmed finding is fixed with its test kept, or recorded here as accepted with the reason; then the unit tests on iOS 26.5 and 27.0 and all UI tests run again and pass.

**Brief for Codex (M64)**

> You are auditing the Hereabouts iPhone app (SwiftUI, Swift 6, Core Data, StoreKit 2, App Intents; iOS 26 minimum). Work only in your worktree on a local branch `audit-codex`; never push, never upload, and don't fix anything. Your job is to break the app's logic and prove each break.
>
> **Try at least these:** malformed, truncated, huge or hostile backup files and shared files; a restore over a full notebook; crashes and kills mid-save, mid-move and mid-restore; the App Group move with a missing, damaged, short or stale copy; deleting or moving a place that has nested places, lent things, and trip or kit references; moving things between homes; every way to get past the free limits (15 things in total, 1 kit, 2 homes): Siri, Shortcuts, links, the widget, the Control Center buttons, voice, restore, moving between homes, undo, duplicates; Pro that lapses, is refunded or is shared by Family Sharing, and what a lapsed person can still see, edit and export; private things leaking through Siri, Spotlight, the widget, notifications, search, backups or logs; reminders across time zones, daylight saving, clock changes and months without the day; links with odd or hostile input; search and the voice parser with empty, very long, accented, emoji and right-to-left text; translated strings whose format specifiers don't match; concurrency between the app, the widget and the intents.
>
> **For each finding:** a failing XCTest in `LocaliserTests/Audit/` that proves it (or exact steps when a test can't), the file and line, what goes wrong for the person, and a severity: data loss or privacy leak; limit bypass or wrong answer; crash; other. Compile with `xcodebuild ... build-for-testing` (you can't run simulators; the auditor runs the tests). One commit per finding. Finish with `Docs/AUDIT_CODEX.md`: every finding, ranked, with its test's name. Don't write your model name anywhere.

### After an owner step

- [ ] **M48 Builds for both phones** (after M31). Development builds, or TestFlight once O42 is given. · P
- [ ] **M49 Final site address and email** (after O17). `project.yml:12` and `:13`, both pages, the review notes. Then open every Help link from a phone. · P
- [x] **M50 Safe notebook move** (before the App Group is switched on). `Data/NotebookFile.swift:31` removes the original as soon as a flag is set, and line 54 trusts any existing copy. Remove the original only after the group copy opens and its record counts match; otherwise fall back. **Check:** `NotebookFileTests` for a missing, damaged and short copy. · X2
- [x] **M51 Switch on the App Group** (after O15 and M50). `project.yml:16`, the entitlements for the app and the widget, and the 1C8F.1 reason in the privacy manifests. Write the O32 steps. · P, X1
- [x] **M52 The lent-out widget** (after M51). Medium size: who has what, since when, and the ask-back date. Private things show as "A private thing". The app reloads it after saves. · D
- [ ] **M53 Ship or cut** the shared notebook and the lent-out widget, by the cut rule, and record the result here. · merge
- [ ] **M54 Purchase wording** (after O35). Fix anything that read wrong in the sandbox. · P
- [ ] **M55 One English.** Done by Codex's pass (M41) in American English. Check with a search for British spellings in the source before the first build; British spellings belong only in the English (UK) catalog (M63). · P
- [ ] **M56 Each archive** (after O42 or O44). Raise `CURRENT_PROJECT_VERSION` at `project.yml:69` and `:92`, archive with Xcode 27.2, run `scripts/check-release.sh`, upload only on the go-ahead. · P, X1
- [ ] **M57 Sync week** (only if B4 is tried for 1.0). · P
- [ ] **M58 CloudKit schema** to production, for a release with sync. · P, X1
- [ ] **M65 Adversarial check of the late changes** (owner, 7 November), just before the submission archive (M56 for O45). Code that lands after M64 because it waits on an owner step (M50 to M54, and any beta fixes) gets the same treatment as M64, limited to the diff since M64: I try to break it, each finding needs a failing test, fixes are checked, and all tests run again. · D

### Set aside for the owner

Blocked items found while building. Each waits for a talk with the owner.

- **Voice rule, parts 1 to 3 pass** (7 November): M20 merged within its time box; 48 of the 50 practice sentences right (96%; 47 on the first run, before a plural rule for "shelves"); a place the notebook doesn't know is never filled in; nothing saves without a tap. Part 4, working offline on iOS 26, and live microphone capture need a phone (O39). Voice stays on until then.
- **Family Sharing for the monthly and yearly plans.** O21 turns it on for Lifetime. The test StoreKit file shares all three products, and the support page now says only Lifetime is shared. Decide in O21; it can't be turned off later.
- **Signed builds.** An archive signed with the Apple Development certificate for team BRLCAAM57K built and verified on the Mac (M31). Installing on a phone waits for M48.
- **Pushing.** Decided 7 November: everything stays local until the app is ready for submission. Then the owner creates a new Git repository, and I add it as the remote and push `main` with its history. Until then nothing is pushed.

## 6. Recommendations

1. **Make the subscription case in the review notes** (O4, M34). Say what Pro keeps getting: weekly automatic backups (M59), regular updates, and household sharing and sync planned for 1.1. Keep Lifetime alongside for people who don't want a subscription. If Apple still objects, ship Lifetime only and bring the plans back in 1.1.
2. **Portrait only** (O1, decided).
3. **Run Codex's pass once**, in American English, after the cut and the Settings tab, so the wording and the spelling are settled together.
4. **Keep voice memos honest.** Show what was heard, never guess a place, keep no recording. If it isn't reliable by the end of Stage 1, ship without it.
5. **Turn off Mac and Vision Pro** (O27).
6. **Tell people Siri can find things** (M22). It's built, and the feedback suggests nobody found it.

## 7. App Review

| Guideline | Usual failure | Hereabouts |
| --- | --- | --- |
| 2.1 Completeness | Crashes, placeholders, products not attached | Products attached (O29). Real phones checked (O31 to O39) |
| 2.1 Completeness | Paywall can't load in review | Products ready and attached. Route to the paywall in the notes; M45 proves it |
| 2.1 Data safety | Data loss on update | Release gates; the shared notebook ships only with M50 and O32 |
| 2.3 Accurate metadata | Listing promises what the build lacks | Description rewritten without receipts (M36). Voice and shelf photos only if they ship, "on supported iPhones" |
| 2.3.3 Screenshots | Not the real app | Real screens from the demo library (M46) |
| 3.1.1 In-app purchase | Paying outside Apple | StoreKit only |
| 3.1.2 Subscriptions | Missing terms, unclear trial, thin ongoing value | Terms on the paywall, trial per plan (M30), Terms of Use line, ongoing value from weekly automatic backups (M59) and argued in the notes (M34), Lifetime offered alongside. Fallback: Lifetime only |
| 4.2 Minimum functionality | Thin utility | Native app with Siri, widgets and Control Centre |
| 5.1.1 Privacy policy | Missing or incomplete | Rewritten (M33), live (O18) |
| 5.1.1 Permissions | Vague strings, asking at launch | Calendar permission gone. Microphone and speech asked only when you first record. Badge dropped (M27) |
| 5.1 Privacy claims | App does more than it says | Data Not Collected (O24). Private-thing promises kept by M7 and M8. Recordings not kept |
| Privacy manifests | Missing reasons | App, Control Centre (M25), widget (M21), App Group reason (M51) |
| Orientation | Broken landscape | Portrait only (M23) |

**Pre-submit check**, on the day:

- [ ] The archive is from `main` and passed `scripts/check-release.sh`.
- [ ] It's the exact build tested in TestFlight.
- [ ] The voice rule and the cut rule are recorded, and the description matches them.
- [ ] No open data-loss defect, no place ever filled in unseen, and proof that real reminders arrived.
- [ ] Products attached and ready, with metadata and review screenshots.
- [ ] Privacy and Support URLs open on a phone off your Wi-Fi.
- [ ] Terms of Use line in the description.
- [ ] Data Not Collected, age rating done, Mac and Vision Pro off.
- [ ] Review notes pasted.
- [ ] Manual release selected.
- [ ] The owner has written "submit" in this conversation.

## 8. Not in 1.0

- **1.1:** household sharing, sync if it missed 1.0, voice memos or the shared notebook if their rules moved them.
- **A separate app:** receipts, returns, warranties and expiry dates, starting from the `receipts-spinoff-base` tag (M1).
- **Later:** iPad and Mac layouts, a Face ID lock, NFC tags, an insurance report, Android.

## 9. Where this plan came from

| Run | Date | Reviewer | What it added |
| --- | --- | --- | --- |
| P | 4 Nov | Claude | The first plan, the owner and Mac split, the review table |
| X1 | 4 Nov | Codex, medium reasoning | Factual corrections, the App Group entitlement and reason, privacy-page gaps, the launch gates, beta review, the fresh-install route, per-product trials, ongoing value |
| C2 | 5 Nov | Claude, every file read | Font licences present, the trial reminder, the badge permission, a stale comment |
| X2 | 5 Nov | Codex, low reasoning | 32 findings, all confirmed in the source |
| D | 7 Nov | Owner | Cut receipts and return dates, Settings tab, new widget job, voice memos, the wording pass |

**What happened to the 5 November items**

- **Cut with the receipts feature, recorded in `RECEIPTS_SPINOFF.md` for the separate app:** private source text in calendar notes, the scan count dropping on delete, "no reminders left" on the Due page, both share-sheet fixes, and building the share extension.
- **Folded into M3:** the "Expires" label on ask-back dates.
- **Renumbered:** the 5 November M1, M3 to M6 and M8 are now M6 to M11. M10, M11 and M13 to M18 are now M12 to M19. Hygiene, docs and verification follow as M23 to M47. The safe notebook move and the App Group are now M50 and M51.
- **Not taken:** the accessibility-audit exemptions (each has a by-eye check, the rule in `CODEX_HANDOFF.md` line 31) and the refund-as-expiry test (the local test store can't expire a subscription; the sandbox pass covers it). Shipping without the shared notebook was the owner's call on 12 October; the cut rule handles the risk instead.

## 10. Next step

O3, O4, O10, O11 and O14 to O15a are done. The owner answers the rest of Stage 0 and waits for the Paid Apps Agreement to turn Active. I start Stage 1 with M1 to M5, M60 and M61: the cut, the Settings tab and the new free limits, which don't depend on any answer.
