# Hereabouts: feature and subscription plan

Written 12 October 2026. None of this is built yet. It covers the subscription the owner chose and the features agreed the same day. The work splits at enrolment in the Apple Developer Program: Phase A can be built and tested now with the free team, and Phase B needs the paid account.

## Changes of 7 November 2026

`RELEASE_PLAN.md` is the plan for 1.0 now. This document stays the record of what each feature is. Where the two differ, the release plan wins. The owner's decisions of 7 November change this plan like so:

| Item | Change |
| --- | --- |
| **A9** Paste an order email | Cut from 1.0 with receipt scanning, return/warranty/expiry dates and the Due tab (M1 to M4). |
| **B3** Share sheet | Cut from 1.0. The share sheet and the "What's due?" Siri phrase go with the receipts. |
| **B2** Due widget | Redefined. It is now two quick buttons, Find and Say it, at small size and on the Lock Screen, reading nothing from the notebook (M21). A medium "lent out" widget, listing who has what and the ask-back date, ships only if the shared notebook (B1) passes the cut rule (M52). |
| **Voice memos** | Added (M20). Hold the microphone on Find, or tap Say it on the widget. Transcribed on the phone with the Speech framework, English only in 1.0, recording not kept, nothing saved without a tap, and an unknown place is never filled in. Ships only if it passes the voice rule in `RELEASE_PLAN.md` section 1. |
| **A6** Ask-back dates | Stay, with their reminder. The thing page shows "Ask for it back". |
| **A1** Free plan | 15 things in total, 1 packing kit, 2 homes (M60). Scans are gone. Pro also gets automatic weekly backups (M59). |
| **B5** Homes | Built, with moving things and places between homes (M62). The free plan has 2 homes. |
| **B4**, **B6** | Sync and household sharing are 1.1. |
| **Settings** | A fourth tab, bottom right (M5). |
| **Receipts app** | Receipt scanning, return/warranty/expiry dates, the Due tab and the share sheet may become a separate app later, starting from the `receipts-spinoff-base` tag. See `RECEIPTS_SPINOFF.md`. |

The sections below are as written on 12 October. Read them with that table beside them.

Effort is in working sessions, as in `AUDIT_AND_LAUNCH_PLAN.md`. Each step is committed in small pieces with the tests green, and nothing is pushed or uploaded.

## What the owner decided

| | Decision |
| --- | --- |
| Pricing | Subscription: US$2.99 a month, or US$19.99 a year with a one-week free trial (owner, 10 November; it was two weeks on both). Or US$49.99 once for lifetime. |
| Free plan | 20 things (was 200). Kits stay at 2 and receipt scans at 5 a month. |
| Features | Household sharing and iCloud sync; the Due widget; faster capture (share sheet, a "Put away…" button for Control Centre, the Lock Screen and the Action button, and naming things from a shelf photo); "Lent to…"; box labels; "Found it"; Private things; quick wins (send where it is by Messages, shortcuts on the app icon). |
| Not chosen | iPad and Mac. |

## Choices I made for the plan

Say if any should change. Each is cheap to change before its step starts.

1. **Pro removes the limits now and adds household sharing when that ships.** Everything else stays free, including iCloud sync to your own devices. Sync runs on each person's own iCloud storage, so it costs nothing to run, and it protects their notebook. Cubby charges for it, which makes free sync a selling point. The 20-thing limit is what makes people pay.
2. **The trial is Apple's free-trial offer.** People who choose yearly pay nothing for the first week; monthly starts paid. They can cancel in Settings before it ends. If reminders are on, the app says two days before the trial ends.
3. **Yearly is the plan shown first.** The app works out its saving from the store prices (44% at US prices).
4. **Nobody loses anything.** Over the limit, every thing stays findable, editable and exportable, and only adding new things stops. The app already behaves this way at the limit.
5. **The builds I put on phones keep a 200-thing limit.** They can't buy Pro. TestFlight and the App Store use 20, and TestFlight purchases are free test purchases.
6. **Private things are still private-from-the-system only.** They stay out of Spotlight, Siri, notifications, the widget and the Lock Screen. They are still in backups and exports, and anyone you share a home with can see them.
7. **Lending stores a name, never a contact card.**
8. **Box labels hold only a random code.** They open the app with a `hereabouts://` link until the website exists.
9. **A home is what you share.** Kits and trips belong to a home, so a household packs from the same lists.
10. **Shelf photos are named on the phone, never on a server.** Phones without Apple Intelligence don't show the option.

## Order of work

| Step | Work | Paid account? | Effort | Needs first |
| --- | --- | --- | --- | --- |
| A1 | Subscription | No (simulator test store) | 1.5 | — |
| A2 | One data-model update (V7) and backup format 2 | No | 0.5 | — |
| A3 | Private things | No | 1 | A2 |
| A4 | Found it | No | 1 | A2 |
| A5 | Quick wins | No | 0.5 | A3 |
| A6 | Lent to… | No | 1 | A2, A3 |
| A7 | Put away: one-screen capture, Action button, Control Centre | Control may need it | 1 | A3 |
| A8 | Box labels | No | 1 | — |
| A9 | Paste an order email | No | 0.25 | — |
| A10 | Shelf photo names (half-session trial first) | No | 0.5 + 1 | A7 |
| B1 | Shared notebook file (App Group) and history tracking | Yes | 1 | enrolment |
| B2 | Due widget | Yes | 1 | B1 |
| B3 | Share sheet | Yes | 1.5 | B1, A9 |
| B4 | iCloud sync | Yes | 2, then a week of two-device use | B1 |
| B5 | Homes | No, but pointless before B4 | 2 | B4 |
| B6 | Household sharing | Yes | 3, then a week with a second person | B5 |

Phase A is about 9 sessions and Phase B about 10, plus the testing weeks. A1 comes first because the app shouldn't reach anyone else while it still says "No subscription, ever." A3 comes before any feature that shows a thing outside the app.

---

## Phase A: now, before enrolment

### A1. Subscription

**What people see.** The Pro screen offers three plans: yearly first, then monthly, then lifetime. Its main button says "Try free for 1 week" on the yearly plan when the person can still have the trial; otherwise it gives the plan's price. Under the button, the screen says what the plan costs after the trial and that it renews until cancelled. It links to the Terms of Use, the privacy policy, Restore purchases and, for subscribers, Manage subscription. Once someone has Pro, the screen shows their status. For example:
- "Pro, renews 12 Nov"
- "Free trial, ends 26 Oct"
- "Lifetime. Thank you."
- "Your subscription ended. Everything you wrote down is still here."

Settings keeps "Free plan · 14 of 20 things". The thing editor adds a quiet line when three or fewer free places are left.

**How.**
- `Purchases/ProAccess.swift`
  - Load three products. Pro is unlocked by any verified, unrevoked entitlement: the lifetime purchase, or a subscription that is active or in its grace period.
  - Read the subscription's status for the Pro screen. Check trial eligibility with `product.subscription?.isEligibleForIntroOffer`.
  - Family-shared transactions count.
  - Someone who buys lifetime while subscribed is told to cancel the subscription. A button opens Apple's manage-subscriptions sheet.
- `CreationKind.freeLimit`: things now come from an Info.plist key, `HereaboutsFreeThings`, set from the `HEREABOUTS_FREE_THINGS` build setting.
  - `project.yml` sets the default to 20.
  - The personal-install command in `BUILD_STATUS.md` adds `HEREABOUTS_FREE_THINGS=200`.
  - Kits and scans don't change.
- `Purchases/ProView.swift` is rewritten:
  - The "Founder's price" stamp and the struck-through price go, and so does the `HereaboutsFoundersPricing` key in `project.yml`.
  - "Pay once. Keep it forever." and "No subscription, ever." go too.
  - Prices always come from StoreKit, never from the code.
- `LocaliserTests/Localiser.storekit` gets the subscription group, yearly with a one-week free trial, monthly with none, and lifetime at 49.99.
- These need updating to match:
  - the free-limit message in `System/Intents.swift`;
  - the onboarding limit check;
  - the "Pay once" and "No subscription" checks in `LocaliserUITests.swift`;
  - the listing copy in `BETA_AND_RELEASE.md`;
  - the StoreKit paragraph in `README.md`;
  - the Pro screenshot.
- **Trial reminder.** A local notification goes out two days before a trial ends. It uses the existing reminder permission and the same "show names" rule.

**Tests.** These are unit tests with StoreKitTest's local session, extending the two existing purchase tests:
- Each plan unlocks Pro.
- When a subscription expires, Pro locks. The library is untouched: editing still works, and adding stops at 20.
- A refund locks Pro.
- A failed renewal inside the grace period stays unlocked.
- Ask to Buy stays pending and doesn't unlock.
- Lifetime plus an expired subscription stays unlocked.
- After the trial has been used, the person isn't offered it again.
- The Info.plist limit is respected.
- A UI test checks the three plans, the terms and the links on the smallest phone at the largest text size.

**Needs the owner** before release: products in App Store Connect and a hosted privacy policy. See "Owner tasks".

### A2. One data-model update (V7) and backup format 2

All of Phase A's new fields go into one new model version, so people's notebooks migrate once.
- **`Belonging`**:
  - `isPrivate` (Boolean, NO)
  - `missingSince` (Date, optional)
  - `lentTo` (String, "")
  - `lentAt` (Date, optional)
- **`Movement`**: `kindRaw` (String, "moved"). Its values are moved, found, lent and back.
- **`DeadlineKind`** gains `askBack`. Its title is "Ask for it back", it defaults to reminding on the day, and it needs no new field.

Every new field is optional or has a default, so the model stays ready for iCloud. V7 is marked `usedWithCloudKit` so Xcode checks this.

`LibraryBackup` changes:
- It goes to version 2, and the new fields join `laterFields`. Version 1 backups still restore.
- An older app says that a version 2 backup "is from a newer Hereabouts", rather than calling it damaged.
- The backup check accepts the new deadline kind.

**Tests:**
- A V6 store migrates with every record intact.
- A version 1 backup restores into V7.
- A V7 backup round-trips.

### A3. Private things

**What people see.** The thing editor gets a "Keep private" switch, which says: "Stays out of Spotlight, Siri, notifications and widgets. Still in backups and exports."

**How.** Each place the app shows a thing outside itself checks `isPrivate`:
- `System/Spotlight.swift` skips private things and adds the flag to its change signature, so a thing becomes private and leaves the index.
- `System/Intents.swift`:
  - The thing search leaves private things out of suggestions.
  - "Where is it?" on a private thing answers "That one's private. Open Hereabouts to see it." and doesn't say where.
- Reminders: `ReminderInput` carries `isPrivate`. `content(showingNames:)` in `Dates/DateRules.swift` already says "A saved thing" when names are off, and now also says it for a private thing.
- Calendar events (`Dates/CalendarExport.swift`) leave the name out.
- The CSV export gains a Private column.
- The same rule then covers the later work: app-icon shortcuts (A5), the widget (B2) and the controls (A7).

**Tests:**
- The Spotlight entries leave out private things.
- The intent reply doesn't give the place.
- The reminder and calendar text has no name.
- Switching a thing to private takes it out of the index.

### A4. Found it

**What people see.**
- **On a thing's page**, next to "Still there", there's "Not there". It marks the thing missing, and missing things sit in a "Looking for" strip at the top of Find.
- **"Found it"** appears on missing things. It also appears on any thing as "Found it somewhere else". It opens the place chooser with these first: where the thing was supposed to be, the last three places it has been, then recent places. Choosing one records the find and clears "missing". The app then says something like "Noted. Next time it's in Hall › Drawer."
- **When a search finds nothing**, Find offers "Found it? Write down where". The editor opens with the name filled in.
- **The Sunday recap** counts finds.

**How.**
- `LocaliserStore` gains `markMissing(_:)` and `found(_:at:)`. The find records a `Movement` of kind found and sets `confirmedAt`.
- The views are `Find/FindView.swift` and `Places/PlaceChooser.swift`, which gets a "suggested" section.
- `Rituals/Rituals.swift` counts finds as activity.
- An App Shortcut, "I found my …", lets Siri and the Action button record a find.

**Tests:**
- Store tests check the find movement, the confirmation date and that "missing" clears.
- The recap count.
- A UI test that searches, finds nothing, and writes the thing down.

### A5. Quick wins

- **Send where it is.** A share button on a thing's page sends plain text such as "The spare key is in Hall › Key bowl." For a lent thing it says "The drill is with Sam." The button is hidden when the thing has no place. It works for private things too, because sending is the person's own choice.
- **App icon shortcuts.** Pressing and holding the app icon offers "Find something", "Put something away" and "What's due".
  - A small app delegate and scene delegate pass them to the links the app already handles. `hereabouts://due` exists, and `hereabouts://find` and `hereabouts://new` are added to the `onOpenURL` code in `LocaliserApp.swift`.
  - The three shortcuts are fixed. There are no "recent thing" shortcuts, so nothing private can appear.

**Tests:** the links are parsed correctly, and the share text is right for a placed thing, a lent thing and a thing with no place.

### A6. Lent to…

**What people see.**
- **Lending.** A thing's page gets "Lend it…". This asks who, with a button that picks a name from Contacts. It can also set a date to ask for the thing back, which defaults to two weeks. Find shows "With Sam · since 3 Oct" in place of the place, and the thing's home stays underneath.
- **Finding lent things.** Searching "Sam" finds everything lent to Sam. Places gets a "Lent out" list.
- **Due.** The ask-back date appears in Due, with "It's back" and "Ask again next week".
- **The reminder** says "Ask Sam for the drill back". For a private thing it says "Ask for something back".

**How.**
- `LocaliserStore` gains `lend(_:to:askBackOn:)` and `gotBack(_:)`.
  - Lending records a lent movement to "With Sam".
  - "It's back" records a back movement to the thing's home, sets the confirmation date and closes the ask-back date.
- **Contacts:** Apple's contact picker needs no Contacts permission, and only the name is kept.
- **Search:** `Find/Search.swift` indexes `lentTo`.
- **Dates:** `Dates/DateRules.swift` groups ask-back dates like returns. A date is active while the thing is still lent.
- **Calendar:** events get the ask-back wording.
- **Packing** shows "With Sam" and warns before packing a lent thing.
- **Siri's "Where is it?"** answers "With Sam since 3 October."

**Tests:** in the store, the lend and back movements, the ask-back date and the Due grouping; plus search, reminder text and a backup round trip.

### A7. Put away: one-screen capture, Action button, Control Centre

**What people see.** "Put away…" opens straight into the camera. After a photo, one screen asks for:
- a name, with suggestions from any text in the photo;
- a place, with recent places first.

Save takes one tap. The same screen opens from:
- the app icon shortcut (A5);
- an App Shortcut, which the Action button can run;
- a Control Centre or Lock Screen button.

**How.**
- A new `PutAwayIntent` opens the app on the capture screen and is added to `HereaboutsShortcuts`.
- The capture screen reuses `Find/CameraPicker.swift`, the Vision text reading in `Scanning/ScanReader.swift` and the place chooser.
- **The control** is a `ControlWidgetButton` in a widget extension. B2's widget will live in the same extension. The control only opens the app and reads nothing, so it may not need an App Group. I'll try it on the free team. If signing refuses, the control waits for B1, and the Action button and icon shortcut still work.

**Tests:** the intent opens the capture screen, and saving creates the thing in the chosen place within the free limit.

### A8. Box labels

**What people see.**
- **Printing.** A place's page gets "Print a label": the place's name and path, plus a QR code. From Places, several labels can go on one sheet. Paper is A4 or US Letter, by region, eight labels to a page. "List what's inside" is off by default, because printed lists go out of date.
- **Scanning.** Scanning a label with the iPhone Camera opens that place in Hereabouts. In the app, "Scan a label" opens the place too, and offers "Put things in this box", which helps with moving house.

**How.**
- The QR code holds only `hereabouts://place/<id>`, made with Core Image's QR generator. `onOpenURL` gets a `place` route.
- The sheet is drawn to a PDF and shared or printed through the share sheet.
- The in-app scanner uses VisionKit's `DataScannerViewController`. `ScanView` already imports VisionKit.
- A label for a place that's gone says "This label's box isn't in your notebook."
- When the website exists, labels can switch to web links that also tell people without the app what they're looking at. The `hereabouts://` links keep working.

**Tests:**
- The links are parsed.
- An unknown place is handled.
- The PDF has the right page count for 1, 8 and 9 labels.
- A UI test opens a place from its link.

### A9. Paste an order email

**Cut from 1.0 (7 November).** Kept here for the receipts app.

The return-date editor gets "Paste order email". It reads the text on the clipboard with the date reading `ScanReader` already uses, and offers the dates it finds to confirm, exactly as a receipt scan does. This is the share sheet's reading step built early: B3 reuses it, and it works today.

**Tests:** sample order-email text in US and UK date styles gives the right candidates. Text without a date says so.

### A10. Shelf photo names

**What people see.** The Put away screen gets "Several things?". After one photo of a shelf, a list of suggested names appears with every item ticked. People untick or edit, choose a place, and save them all. The screen shows how many they can add on the free plan.

**How.** First comes a half-session trial on the owner's iPhone 16 Pro Max, which must have Apple Intelligence turned on. The trial confirms whether iOS 27's Foundation Models framework accepts an image on that phone. Apple announced image input at WWDC26, but it is not yet clear whether the standard on-device model takes images, or only the newer, larger one on higher-end phones.

If the trial works:
- **The model:** a small `@Generable` result holds up to 12 names, made entirely on the phone.
- **Where it shows:** the option appears only when `SystemLanguageModel` reports it's available. It won't appear on Angela's iPhone 13 mini.
- **Tests:** the model sits behind a small protocol, so unit tests use a stand-in.

If the trial fails, A10 waits for a later iOS, and nothing else depends on it.

---

## Phase B: after enrolment

These start when the owner says they've enrolled.

### B1. Shared notebook file

The widget, share sheet and controls run outside the app, so the notebook file must move into an App Group container.
- **Moving the file.** On first launch of that build, the app copies the store across with `replacePersistentStore`. That covers the database and the separate folder where Core Data keeps photos. The app checks the counts match before using the new copy, and keeps the old file until the next launch.
- **History.** The weekly history trim in `LocaliserStore.trimHistory` is replaced. Each part of the app remembers how far it has read the change history. The app merges changes made by the widget and the share sheet, and trims only what everyone has read. With sync on, it also trims only what has been uploaded. Deleting history that sync hasn't processed can force a full re-sync.
- **Remote changes.** The store refreshes when another process changes the file. The notification for this is already switched on.
- **Pro status.** The app writes its Pro status to the group's shared settings, so the extensions can apply the limits.

**Tests:**
- Moving a library with photos keeps every record and photo.
- Moving twice is harmless.
- A change from a second store on the same file shows up in the app.

### B2. Due widget

**Redefined (7 November).** The widget is now Find and Say it buttons, plus a lent-out list if the shared notebook ships (M21, M52). There is no Due tab or date to show. What follows is the 12 October design.

As planned in `AUDIT_AND_LAUNCH_PLAN.md` section 4.3 and `HUMAN_BLOCKED.md`:
- Sizes: small (the next date), medium (the next three) and the Lock Screen.
- It reads the notebook and doesn't write to it. Taps open `hereabouts://item/<id>` or `hereabouts://due`; both links already work.
- Private things show as "A private thing". Lent things' ask-back dates are included.
- The app reloads the widget after saves, at most once every few seconds.

### B3. Share sheet

**Cut from 1.0 (7 November).** Kept here for the receipts app.

"Save to Hereabouts" appears in the share sheet for PDFs, images and text. It reads the dates with the A9 code, then asks:
- which date it is (return-by first);
- which thing it belongs to, either an existing one or a new name.

It then saves into the shared notebook.
- **Limits:** it counts against the free scan and thing limits.
- **Memory:** share extensions get much less memory than the app, so it reads at most the first five pages and shrinks large images first.
- **From Mail:** Mail doesn't share whole messages to apps. People select the text and share it, or use Print and share the PDF. The help page should say so.

### B4. iCloud sync

- **Container.** The app always uses `NSPersistentCloudKitContainer`, with iCloud turned off until the person switches it on.
  - The test asserting `restored.container is NSPersistentCloudKitContainer` is false changes to check that iCloud is off.
  - Settings gets "Keep in iCloud", which starts and stops sync without a restart by reopening the store. A restart was one reason sync was taken out before (`AUDIT_AND_LAUNCH_PLAN.md` 3.2).
- **Safety backup.** The app writes an automatic backup before sync first starts, and again when the iCloud account changes. Signing out of iCloud can remove synced data from the phone, and this must be checked on a device.
- **Duplicate places.** Two phones set up separately each make their own starter places. After the first sync, the app offers to merge empty places with the same name at the same level. It never merges things on its own.
- **Restore and erase with sync on** apply everywhere, and the confirmation says so.
- **The home's name** moves out of `@AppStorage` (`Home.nameKey`) so it syncs.
- **Spotlight and reminders** are rebuilt after changes arrive from other devices.
- **Testing:** a week of daily use on the owner's iPhone and a simulator signed in to the same Apple Account, including flight mode, deleting on one device while editing on the other, and signing out and in.

### B5. Homes

This is the 1.x design in `AUDIT_AND_LAUNCH_PLAN.md` section 8, now needed because a home is what gets shared. `CODEX_HANDOFF.md` said not to add the `Home` entity yet; this step lifts that.
- **The model (V8).** `Home` sits above `Place`. Kits and trips belong to a home. The app creates one home from today's home name.
- **Screens.** Find and Places get a switcher, and search and export work across all homes.
- **Limits.** Pro has no limit on homes. The earlier plan let the free plan have 2.
- **V8 also adds** `Movement.by`, the name of whoever moved a thing. B6 needs it.

### B6. Household sharing

- **Inviting.** A home's page gets "Share this home…", which uses Apple's sharing sheet to invite people by Messages or email. The people invited can see and change everything in that home.
- **Who did what.** History says who moved what: "Sam moved it to the garage on Tuesday."
- **Leaving.** Anyone can leave a shared home, and the owner can remove people.
- **How it's built.** It follows Apple's two-store pattern for sharing Core Data objects:
  - a private store and a shared store;
  - `CKSharingSupported` in Info.plist;
  - accepting invitations in the scene delegate.
  A trip packs from its own home's things. That's the cost of keeping each home self-contained.
- **Pro rules.**
  - Starting a share needs Pro; joining is free.
  - Things in a shared home count only against its owner's limit.
  - If the owner's Pro ends, the sharing carries on.
  - A free member can add things to a Pro owner's home. That's accepted, because it's a household.
- **Reminders.** Each person gets the home's reminders, with a switch per home.
- **Private things in a shared home** are visible to its members, and the "Keep private" switch says so once sharing exists.
- **Testing:** a week with two Apple Accounts. Angela on TestFlight is the natural second person, if she's willing.

### B7. TestFlight

TestFlight replaces the 7-day installs. The beta follows `BETA_AND_RELEASE.md`, with the subscription tested through free test purchases: trial, renewal, cancellation, refund and Ask to Buy.

---

## Releases

- **1.0:** Phase A, plus B1–B3. Anything in Phase A that isn't ready when the beta starts moves to 1.1 rather than delaying it. iCloud sync joins 1.0 only if it passes its week of two-device use during the beta.
- **1.1:** Homes and household sharing, which become the headline of Pro. Sync too, if it missed 1.0.

## Owner tasks

In order:
1. **Enrol** in the Apple Developer Program (US$99 a year). Phase B, TestFlight and selling all wait for this.
2. **Settle the bundle ID** before creating anything in the developer portal. Today it's `dev.localiser.app`; the launch plan suggested something like `app.hereabouts.ios`. Some identifiers can never be changed or reused once created: the bundle ID once uploaded, the iCloud container, the App Group and product IDs.
3. **Get the domain and host** `Site/privacy.html` and `Site/support.html`. A subscription screen must link to a privacy policy and terms of use, and Apple's standard licence serves as the terms.
4. **In App Store Connect**, accept the Paid Applications Agreement and fill in tax and banking. Join the Small Business Program, which takes Apple's commission from 30% to 15%.
5. **Create the products**, using the bundle ID from step 2 in place of `<id>`:

   | Product | Type | Product ID | Price | Free trial | Family Sharing |
   | --- | --- | --- | --- | --- | --- |
   | Pro monthly | Auto-renewable, group "Hereabouts Pro" | `<id>.pro.monthly` | US$2.99 | None | On |
   | Pro yearly | Same group, same level | `<id>.pro.yearly` | US$19.99 | 1 week | On |
   | Pro lifetime | Non-consumable | `<id>.pro.lifetime` | US$49.99 | — | On |

   Then turn on the billing grace period (16 days). Family Sharing can't be turned off once it's on.
6. **Deploy the iCloud schema to production** in the CloudKit Console before the release that includes sync. I'll prepare it and give step-by-step instructions.
7. **Ask Angela**, or another person with their own Apple Account, to test sharing for a week.

`HUMAN_BLOCKED.md` points here for the products. Don't create the old US$4.99 one-off.

## Risks

- **Subscription reception.** Some people will call it "a subscription for a notebook". The answers are the lifetime option, the trial, never taking anything away, and sharing arriving in 1.1. Reviews in the first month will show whether it worked.
- **Moving the notebook file (B1)** is the riskiest single step, because photos live outside the database file. The app copies, checks and keeps the old file, and I'll test it on a copy of a real notebook first.
- **Sync** can duplicate or remove data when accounts change. That's why sync is off until switched on, the app takes automatic backups, and there's a week of two-device use before release.
- **Sharing** forces kits and trips into homes, which changes how packing works for anyone with more than one home.
- **Shelf photos** depend on an Apple capability that isn't confirmed for the standard model, so they get the trial first.
- **Enrolment timing:** all of Phase B waits for it, and the phone builds keep expiring every 7 days until then.

## Not in this round

- iPad and Mac.
- A Face ID lock for the app or for private things.
- NFC tags for boxes.
- An insurance-value report.
- Importing from web pages, which would need the app to go online.
- Android: the backup format in `LibraryBackup.swift` is the thing to write down first.
