# Localiser: end-to-end audit and launch plan

> **History.** Written 9 October 2026 and no longer current. The plan for 1.0 is `Docs/RELEASE_PLAN.md`, and `Docs/FEATURE_PLAN.md` records what each feature is. Some of what follows (the Due tab, receipt scanning, the gear-button Settings, the 200-thing free plan) has changed or been cut.

Prepared 9 October 2026 against commit `99dc1dc`. This is a plan, not a change set: nothing below has been implemented.

Evidence: full read of every source file, a run of the Debug build on the iPhone 17 simulator with the demo library, the unit and UI test results from today, and an App Store market review (sources listed in section 6).

---

## 1. Verdict in one paragraph

The engine is sound. The data rules, date confirmation, packing lifecycle, backup/restore and purchase handling are careful and tested (20 unit tests, 5 of 8 UI flows green; the remaining three are pre-existing accessibility audits plus a fixture-less PDF test). What stands between this and a shippable 1.0 is (a) a handful of first-run usability traps that make the app feel broken, two of which you hit yourself, (b) developer-facing copy and half-configured features (iCloud sync, push) that an App Store reviewer will flag, and (c) the missing store-side paperwork. No accounts are needed, and I recommend against adding them. Estimated effort to a TestFlight-ready build: about 3 working sessions of fixes plus your Developer Program enrolment and listing assets.

---

## Decisions taken (9 October 2026)

| Question | Decision | Why |
| --- | --- | --- |
| Name | **Hereabouts** | Free on the US/UK App Store today (section 7). Reserve it in App Store Connect on enrolment day; check USPTO/UKIPO class 9/42 and buy hereabouts.app before the rename. |
| iCloud sync | **Out of 1.0** (Option A in 3.2). Ship local-only with file backup; sync in 1.1. | A Personal Team cannot deploy a production CloudKit schema, the toggle needs a restart, and `hasUsedSync` permanently disables Restore/Erase. A disabled placeholder is a 2.1/2.3 rejection risk; a local app with export is not. |
| Pricing | **Aggressive, lifetime only**: free up to 200 items / 2 kits / 5 scans a month; Pro $9.99 one-off, $4.99 Founder's price for 8 weeks, step to $14.99 later (section 6). No yearly anchor in 1.0. | Zero server cost makes a land-grab affordable; the category's complaints (subscriptions, tiny free limits, $30–60 unlocks) become the pitch. Prices can only comfortably move up later, so aggressive-first is the reversible order. A subscription would add states `ProAccess.swift` does not model and a second paywall surface for review. |
| Item names in reminders | **On by default**, with a Settings switch "Show item names in reminders". Never include document numbers, amounts, notes or retailer in notification text. | "Running shoes: return by Sunday" is actionable from the lock screen; "A saved return deadline needs your attention" is not. The sensitive data is the document content, not the item name, and iOS already hides previews on the lock screen for users who want that. |
| More than one home | **Yes, in 1.x, gated by count**: free 2 homes, Pro no limit. Not in 1.0. | There is no home entity today and nobody has asked. When it lands, a count limit keeps the "Pro gates volume only, every feature free" promise; the second home (a parent's house, a storage unit) is the one most people want, so free still covers the useful case. Decided 9 Oct, later. |
| Visual direction | **"A well-kept notebook"** (section 10): paper and ink, Fraunces + Atkinson Hyperlegible, the stock iOS tab bar kept (not the index tabs on the canvas), retention rituals (Sunday recap, keeping-up count, monthly stocktake). Implemented after 1.0's store-readiness work, before beta. | The owner wants the app to look unlike generic app UI; purple stays dominant. Nav alternatives were drawn and reviewed; testers preferred the app's existing stock tab bar, so it stays. Decided 9 Oct, later. |

---

## 2. What works (verified)

| Area | Status | Evidence |
| --- | --- | --- |
| Name-only capture, edit, move, archive, delete, movement history | Works | Unit + UI tests pass; exercised in simulator |
| Nested places, cycle prevention, occupied-place deletion | Works | Unit tests; simulator |
| Search: exact, prefix, alias, place words, typo tolerance; 5,000 items < 50 ms on iPhone 16 Pro Max | Works | Unit perf test; Codex's physical benchmark |
| Dates: explicit confirmation, return-window calculation, keep/return/returned decisions, closed returns need reopening | Works | Unit + UI tests |
| Reminders: calendar-day maths incl. DST, 50-request queue, stale-request cleanup, denied-permission state | Works | Unit tests; coverage card in Due soon |
| Add to Calendar (per date, via Apple's event editor; no permission prompt needed) | Works but buried | `DueView.swift:239`, only reachable from a date's detail screen |
| On-device OCR for photos and PDFs, 20 MB / 25 MP / 10-page limits, ambiguous-date review, date-only retention by default | Works | Unit + UI tests |
| Kits → trips, per-night quantities, conditions, overlap conflicts, departure checklist, coming-home resolution | Works | Unit + UI tests; simulator |
| Lifetime Pro: purchase, restore, cancel, pending, refund; limits never lock existing data or export | Works (local StoreKit only) | Unit tests; needs sandbox once the product exists |
| Backup JSON (validated before any write) and CSV with formula neutralisation | Works | Unit + UI tests |
| Design: canvas colours, cards, pills, breadcrumbs, dark mode, Dynamic Type scaling | Works | Yesterday's redesign; screenshots |
| Privacy posture: no SDKs, no network calls except StoreKit/iCloud, privacy manifest present | Works | `PrivacyInfo.xcprivacy`; no third-party code |

---

## 3. What is not working, and the in-between

Severity: **P0** blocks launch · **P1** fix before TestFlight · **P2** fix before 1.0 · **P3** later.

### 3.1 The two you reported

**P0 · Places feel broken on first use.** Three things compound:
1. The item editor's "Where does it live?" picker (`FindView.swift:309`) only lists existing places. On a fresh install it shows a single option, "Unspecified", with no way to create a place from inside the form. The user has to abandon the item, go to Places, add one, come back.
2. A place tile shows the recursive count ("Garage · 3 things"), but opening it shows an empty **Belongings** section because the items are in a child place ("Back wall"). Confirmed in the simulator with the demo library. It reads as data loss.
3. There is no inline "new place" in the Places tab's grid itself, only the toolbar "+" (the dashed "New place" tile exists on Find, not on Places).

Plan: add "New place…" as the first row of the place picker (sheet, returns the new ID and selects it); allow typing a path ("Garage › Shelf B") that creates missing levels on save; in place detail, show items from child places under a "Inside Back wall" grouping, or show the recursive list with breadcrumbs; add the dashed tile to the Places grid.

**P0 · "Snap a photo" has no camera.** The tile (`FindView.swift:227`) is wired to `PhotosPicker` (library only). The copy and icon promise a camera. On a phone the library sheet appears instead, which is the "doesn't quite work" you saw.

Plan: tap opens a menu: **Take photo** (`UIImagePickerController` with `.camera`, falls back to library on devices without one) / **Choose from library** / **Remove**. Keep the existing 1600 px downscale. The camera usage string already exists but says "Scan a receipt"; broaden it to cover item photos (Apple rejects strings that don't match actual use).

### 3.2 Launch blockers found in the audit

**P0 · iCloud sync is half-shipped and visibly so.** The toggle is disabled with the text "This build is not configured for private iCloud", sync needs an app restart to apply, and once a store has *ever* synced, Restore and Erase are permanently disabled (`hasUsedSync` in `LibraryBackup.swift:83,185`). Reviewers flag disabled/placeholder features (Guideline 2.1, 2.3). Decide now:
- **Option A (recommended for 1.0):** hide the sync section entirely, remove `UIBackgroundModes: remote-notification` and the `aps-environment`/iCloud entitlements from the Release build, and ship as a local app with file backup. Add sync in 1.1 once you have a paid team, a deployed CloudKit schema and a two-device test.
- **Option B:** ship sync. Requires the paid team, production schema deployment, the restart-free toggle, a defined reset/reconnect procedure, and the two-device matrix in `BETA_AND_RELEASE.md`. Roughly a week of work plus a second device.

**P0 · Developer-facing copy throughout.** Dozens of strings read like a compliance log: "This status does not confirm another device has received every change", "Reconnecting it to an existing cloud library has not been verified", "Restore requires an empty local library and private sync off". These need a plain-English pass (Settings, Pro, Scan, Due soon, every error). Apple's reviewers judge polish from this, and the research in section 6 shows users punish confusing apps hard.

**P0 · Store paperwork missing.** See the checklist in section 4.

### 3.3 Edge cases and defects

| Sev | Finding | Where | Plan |
| --- | --- | --- | --- |
| P1 | Restore only works into an empty library. A user who installs on a new phone, adds one item, then finds their backup must erase first. The erase button is a typed-"ERASE" alert, so it is survivable, but the path is hostile. | `LibraryBackup.swift:80` | Offer "Merge" restore that skips existing IDs, or at minimum a one-tap "Erase and restore" in the restore flow. Explain in onboarding that backups go to Files. |
| P1 | Notification actions ("Keep purchase" / "Plan to return") are dropped on cold launch: the handler reads a `weak var store` that is nil until `RootView` appears. | `ReminderService.swift:85` | Buffer the pending action and replay once the store is attached. |
| P1 | Archived and returned items count toward the free item limit (`store.items.count`). A free user who has returned 20 things has 20 dead slots. | `FindView.swift:299`, `ScanView.swift:61` | Count only non-archived items. Cheap goodwill, and part of the pitch under the aggressive pricing (section 6). |
| P1 | OCR is English-only: `recognitionLanguages = ["en-US"]` and the month-name parser uses `en_US_POSIX`. A French or German receipt yields no candidates. | `ScanReader.swift:62,116` | Use `Locale.preferredLanguages` for recognition and parse month names with the current locale as well as POSIX. |
| P1 | Two-digit years are always 2000–2099, even "12/05/98". Flagged as "ambiguous" only when day/month swap, not for century. | `ScanReader.swift:59` | Mark two-digit-year candidates as ambiguous too. |
| P1 | Per-night quantities use `nights`, so a day trip (0 nights) needs 0 socks and a one-night trip needs 1. Most people pack nights + 1. | `PackingRecords.swift:305` | Add a per-kit choice "per night" vs "per day (nights + 1)", default to days. |
| P1 | Migration or store-open failure shows a dead-end screen with no export path. | `LocaliserApp.swift:35` | Add "Export raw library file" (share the SQLite + wal/shm) and a support link on that screen. |
| P2 | No maximum length on names, notes or aliases. A pasted 50,000-character note is accepted and renders in every list row. | `LocaliserStore.swift:requiredName` | Cap name at 120, aliases at 1,000, notes at 5,000 characters, trimmed with a visible counter. |
| P2 | Duplicate place names at the same level are allowed ("Garage" twice). | `LocaliserStore.swift:addPlace` | Warn (not block) when a sibling with the same name exists. |
| P2 | Deleting an item is immediate and permanent (its dates, scans and history go with it). No undo. | `FindView.swift` delete action | Archive by default; permanent delete only from the archived view, with a 5-second undo toast. |
| P2 | Reminder text never names the item ("A saved return deadline needs your attention"). Privacy-safe, but users will not know what it refers to from the lock screen. | `ReminderService.swift:58` | Decided: item names on by default; Setting "Show item names in reminders" (off keeps current behaviour). Never include numbers, amounts or notes. Use `interruptionLevel` and a thread per item. |
| P2 | Notification queue is capped at 50 of iOS's 64. Users with many expiries get partial coverage; the coverage card explains it but only inside Due soon. | `ReminderService.swift:63` | Prioritise soonest dates (already sorted) and surface a badge on the tab when coverage is partial. |
| P2 | Trip in "away" state cannot have entries added or quantities changed, with a generic error. | `PackingStore.swift:473,494` | Clearer message: "Items can't change while you're away. Start coming home first." |
| P2 | `deleteItem` leaves kit and trip rows as free-text rows with the old name. Intentional (history survives), but the row shows no hint that the item is gone. | `LocaliserStore.swift:deleteItem` | Show "(deleted item)" caption on unlinked rows that once had an item. |
| P2 | Item name shown in Settings for retained files ("Photo: Passport") leaks into the backup file-picker list; fine, but the whole backup is plaintext JSON including base64 photos and any retained receipts. | `LibrarySettingsView.swift` | Offer "Encrypt backup with a passphrase" (CryptoKit, AES-GCM) in 1.1. Say "not encrypted" more plainly until then. |
| P2 | The app is iPhone-only (`TARGETED_DEVICE_FAMILY 1`). It will run letterboxed on iPad and App Review often tests on iPad. | `project.yml` | Test on an iPad simulator before submission; consider native iPad in 1.1. |
| P2 | Three accessibility audits still fail on the Settings and Pro screens (contrast and Dynamic Type), inherited from before the redesign. | `LibrarySettingsView.swift`, `ProView.swift` | These screens are still stock Forms; restyle them with the design system and re-run the audit. |
| P3 | iOS 26 minimum; iOS 27 is current. Fine for a new app, but note that iOS 25 devices are excluded. | `project.yml` | Keep. |
| P3 | English only; no String Catalog. | all | Add a String Catalog before 1.1 so copy edits don't block localisation later. |
| P3 | No Spotlight, Siri, widgets or Shortcuts. Not bugs, but these are the cheapest differentiators (see 4.3). | — | Phase 2. |

### 3.4 Already fixed today

The crash when deleting an item (deleted object read by a lazy stack), the nested place counts, raw trip date strings, the too-small "Open notification settings" tap target, and the clipped search field. All in `99dc1dc`.

---

## 4. App Store readiness: what to add

### 4.1 Required or near-required by Apple

| Item | Why | Plan |
| --- | --- | --- |
| **Privacy policy URL** | Guideline 5.1.1(i): every app, no exceptions. | Host the draft in `BETA_AND_RELEASE.md` (rewritten in plain English) on a static page. Link it from Settings and from the paywall. |
| **Support URL and contact** | Required in App Store Connect. | Same static site, one page, an email address. |
| **App Privacy "nutrition label"** | Required at submission. | Declare **Data Not Collected**. True as long as no analytics/crash SDK is added. Keep it that way; it is a selling point (section 6). |
| **`ITSAppUsesNonExemptEncryption = NO`** | Otherwise every build asks the export-compliance question. | One Info.plist key via `project.yml`. |
| **Permission strings that match use** | 5.1.1(iii). Camera string currently says "Scan a receipt"; it will also take item photos. | Rewrite camera and photo-library strings. Add `NSCalendarsWriteOnlyAccessUsageDescription` only if 4.2's background calendar sync ships (the current Apple event editor needs no permission). |
| **Paywall completeness** | 3.1.1 and 3.1.2: price, what is unlocked, restore, and links to privacy policy and terms. | ProView already shows price, limits and Restore. Add Privacy Policy and Terms of Use (Apple's standard EULA link is acceptable for non-consumables). Restyle with the design system. |
| **Real StoreKit product** | The `$49.99` in `Localiser.storekit` is test metadata. | Create the non-consumable in App Store Connect at the price in section 7, enable Family Sharing, test in sandbox: buy, restore on second device, refund via sandbox. |
| **Remove unconfigured capabilities** | Entitlements request iCloud, CloudKit and push; `UIBackgroundModes` lists `remote-notification`. Without a paid team these fail signing; with one, Apple asks why push is declared. | Per section 3.2 Option A: strip until sync ships. |
| **No placeholder or disabled features** | 2.1 completeness. | Hide the sync section; rewrite copy. |
| **Review notes** | Reviewers need to know there is no login and how to test Pro. | Explain free limits, that no account exists, how to hit the limit (add 51 items) and that purchase is testable in sandbox. Mention the demo-library launch argument is Debug-only. |
| **Age rating, category, keywords** | Required. | 4+. Primary category **Productivity**, secondary **Utilities** (do not use "Finance" or "Shopping"). |
| **Screenshots and preview** | Required for 6.9" and 6.5" iPhone. | Five screenshots in the order the research recommends: find by location path → receipt scan to "Return by" reminder → Due soon → packing progress → "No account, no subscription, export anytime". Use the demo library. |
| **iPad run-through** | Reviewers use iPads. | Install on an iPad simulator and walk all four tabs once. |
| **Apple Developer Program** | $99/yr. Blocks everything above. | Enrol first; reserve the app name the same day (section 8). |

### 4.2 Strongly recommended

| Item | Why | Plan |
| --- | --- | --- |
| **Onboarding (3 screens, skippable)** | The first-run experience currently drops users on an empty Find tab. The research shows "setup effort" and "slow entry" are the second-biggest complaint in the category. | Screen 1: "Save where things live" with a worked example. Screen 2: "Never miss a return or expiry" (scan a receipt). Screen 3: "Pack from a kit". Then land on the Add item sheet, pre-focused, with the place picker offering "Create a place" (3.1). Store a `hasOnboarded` flag; re-openable from Settings. |
| **Contextual walkthrough with TipKit** | A one-time tour is forgotten; tips appear where the feature is. Native, no SDK. | Tips on: the breadcrumb ("tap to open the place"), put-away mode, the scan button, "Mark away", and the coverage card. |
| **Account creation: do not add** | Apple only requires account deletion (5.1.1(v)) if you offer accounts. A local-first app with no account is a stated differentiator; competitors are criticised for mandatory accounts (section 6). Sign in with Apple would also become mandatory the moment any third-party login appears. | Keep "no account" and say it on the listing. Data portability is covered by export; "delete my data" is covered by Erase. |
| **Add to Calendar on Due soon** (your request) | Currently per-date, two taps deep. | See 4.4. |
| **Plain-English copy pass** | Section 3.2. | One session. Keep the safety semantics, change the words. Example: "Private sync is off." → "Your library is only on this iPhone." |
| **Restyle Settings and Pro with the design system** | Last two stock screens; also where the accessibility audits fail. | Half a session. |
| **TestFlight external beta** | Catches device-only issues (camera, notifications after days, Files providers). | 10–20 testers from the plan in `BETA_AND_RELEASE.md`. Two weeks. |
| **What's-new and support in Settings** | Expected polish. | Version string, "Send feedback" mailto, privacy and terms links, "Replay introduction". |

### 4.3 Differentiators worth adding before or soon after 1.0

| Item | Why | Effort |
| --- | --- | --- |
| **Spotlight indexing (Core Spotlight)** | Type "passport" in iPhone search and get "Passport · Bedroom › Drawer 2" without opening the app. No competitor in the research does this well, and it is the purest expression of the product. | Half a session: index name, aliases, path; deep link to the item. |
| **App Intents / Siri** | "Where is my passport?" and "Add raincoat to the hall closet." | One session; also gives Shortcuts and the Action button. |
| **Due soon widget** | Lock-screen and home-screen glanceable deadlines. | One session (WidgetKit, shared App Group with the SQLite file). |
| **Photo-first quick capture** | Research: "fast capture is becoming table stakes". Camera opens first, name typed after, place defaults to the last used. | Part of the 3.1 camera fix. |
| **Container operations** | "Move everything in this box", print QR labels for bins (users invent "A:3:2" codes themselves). | Phase 3. |

### 4.4 Due soon → iPhone Calendar (your request)

Today: each deadline's detail screen has "Add to Calendar", which opens Apple's `EKEventEditViewController` pre-filled with the item name, date and reminder lead. It needs no calendar permission because Apple's editor runs out of process. Plan in two steps:

1. **Surface it (1.0):** add "Add to Calendar" to every Due soon card's long-press menu and swipe actions, and a toolbar action "Add all due dates to Calendar" that walks the list (one editor at a time, or a batch confirmation). Pre-fill an all-day event titled "Return: Running shoes" with the place in the notes and an alert at the chosen lead time.
2. **Keep in sync (1.1, optional, off by default):** a Settings toggle "Keep a Localiser calendar up to date" that requests write-only calendar access (`NSCalendarsWriteOnlyAccessUsageDescription`), creates a dedicated calendar, writes one event per active deadline, stores `eventIdentifier` on `Deadline` (model version V5), and updates or removes the event when the date changes, is decided, or is deleted. This gives people reminders that survive the 64-notification cap and show in Calendar widgets.

---

## 5. Competitive picture and how to win

Full source list and quotes are in the research notes; the themes, ranked by how often they recur in reviews across Sortly, Under My Roof, Everspruce, Nest Egg, Itemtopia, Memento, Homer, PackPoint, Packr, Smart Receipts, Keep Receipt and the small warranty/return apps:

1. **Subscription resentment** is the single most common complaint. "Charge me $10 once and move on." Multiple apps have reviews begging for a lifetime option.
2. **Data loss on update or migration** is the most damaging: Sortly, Everspruce and Nest Egg all have one-star reviews describing entire libraries vanishing, often with no export.
3. **Slow data entry** and setup effort.
4. **Features held hostage**: backup/restore behind a paywall (Smart Receipts), Face ID removed in an update (Sortly).
5. **Mandatory accounts and cloud-only storage**; privacy worries where email access is requested (Route).
6. **Abandonment**: Centriq shut down in January 2026 after going paid; Slice and the original TripList are gone. Users are wary.
7. Packing apps upsell insurance on every trip (Packr) and can't do multi-stop trips (PackPoint).

What users praise: fast search-as-you-type, simple visual hierarchy, responsive indie developers, iCloud sync that just works.

**Unmet needs that map directly onto this app:** a one-time price for a set-it-up-once tool; export you own; expiry and return dates *inside* the inventory rather than in a separate app; family access without per-seat fees; faster capture; bin addressing that makes *locating* fast (users invent grid codes and QR labels themselves). The return/warranty niche is fragmented into tiny apps with under ten ratings each, all marketing "on-device" and "no sign-up", which signals demand with no winner.

**Positioning:** lead with the location path and "find it", not "inventory" (which reads as business stock-keeping and Sortly's prices). Say the three things competitors get punished for in the first two lines: *no account, no subscription, export anytime.* The combination of find + due dates + packing exists nowhere else; market it as replacing three apps. Avoid insurance-valuation features (Sortly, Encircle, HomeZada already own that) and never paywall export, backup or reminders already set.

---

## 6. Pricing strategy (aggressive, decided 9 October)

Market anchors from the research: single-purpose utilities sell lifetime for $2–7; full home-inventory lifetime unlocks sit at $30–60 (Itemlist $59.99, Quick Home Inventory $29.99, BluePlum $29.99); subscriptions in the category run $35–80/yr and draw the loudest complaints. RevenueCat's data puts lifetime at 2–12× annual, with conversion collapsing above ~5×.

Goal chosen: take share. With sync out of 1.0 the app has no server cost, so a free user costs nothing and every sale is margin. That is what makes a land-grab affordable here.

| Element | Choice | Reasoning |
| --- | --- | --- |
| Free tier | **200 active items**, unlimited places, **2 kits**, **5 successful scans per calendar month**; unlimited trips, manual dates, reminders, export, backup | A one-person flat fits in free, so reviews come from real use rather than from hitting a wall. Monthly scans instead of a lifetime cap of 3 removes the "bait" feeling. Count only non-archived items (3.3). Never gate export or existing data. |
| **Pro lifetime** | **$9.99** (£8.99 / €9.99), Family Sharing on | A third of Quick Home Inventory/BluePlum, a sixth of Itemlist, under three months of any competitor's subscription. Low enough to be an impulse buy. |
| Launch price | **$4.99 "Founder's price"** for the first 8 weeks, shown as a strike-through | Early reviews matter most. Apple introductory offers exist only for subscriptions, so this is a scheduled price change in App Store Connect with the strike-through drawn on the paywall. |
| Price ladder | Raise to $14.99 after ~1,000 buyers or 6 months, whichever first; existing buyers keep it | Non-consumable prices can go up at any time without affecting buyers. Going *down* from a high launch price annoys early buyers, so aggressive-first is the reversible order. The later step also answers the "cheap = low quality" perception once reviews exist. |
| What Pro gates | **Volume only**: unlimited items, kits, scans. Every feature (widgets, Spotlight, App Intents, calendar, export, backup) is free | Keeps the free app the best free app in the category, which is where share comes from. Gating features pushes people to a competitor's free tier. |
| Subscription | None. Say "No subscription, ever" on the paywall | The category's top complaint, turned into the headline. |
| Refunded | Keep everything viewable and exportable; limits apply to *new* records only | Already how the code treats a refunded lifetime purchase. State it on the paywall. |
| Tip jar / later | Not for 1.0 | Adds paywall clutter. |

**Pitch:** "Everything is free for up to 200 things. Pay once, $9.99, for unlimited. No subscription, no account."

**The bet, stated plainly:** at $9.99 you need 3× the buyers of a $29.99 plan for the same revenue; at $4.99, 6×. Review evidence ("I'd happily pay a few dollars once") says elasticity is high in this category, but that is inference, not measurement. The downside is capped by the price ladder.

**Code impact:** `Purchases/ProAccess.swift` limits 50/1/3 → 200/2/5; the scan counter needs a month key so it resets (today `completedScans` is a lifetime total); the archived-items fix in 3.3 becomes part of the selling point.

---

## 7. Name recommendations

Method: each candidate was checked against the App Store search API in the US and UK storefronts for an app whose title is, or starts with, the name. "Free" means no such app was listed today. This is not a trademark search: before committing, check USPTO and UKIPO, buy the .app or .com domain, and reserve the name in App Store Connect the day you enrol (names are first-come and can be held for a limited time).

**Taken (by direct competitors, so avoid even as a variant):** Wherebox (WhereBox – Home Inventory), Stashmap, Stowed, Tuckaway, Stowkeep, Putaway, Findbox, Cubby, Stowbox, Stashbox, Placenote, Whereabouts, Kept, Shelved, Trove, Itemize, Boxly, Tucked. The canvas name **Wherebox is taken**, so the brand assets will need a new word regardless.

**Shortlist, all free on the App Store today**

| Rank | Name | Why it works | Watch-outs |
| --- | --- | --- | --- |
| 1 | **Hereabouts** | Says "where things are" in one warm, real word; easy to spell after hearing it; no competitor association; works as a verb-free brand ("open Hereabouts"). | Ten letters; check trademark classes 9/42. |
| 2 | **Keepwhere** | Literal promise: keep track of where. Reads naturally in a sentence ("Keepwhere says it's in the garage"). | Slight risk of "Keep" apps (Google Keep) in search. |
| 3 | **Stowhere** | "Stow" + "where", short, clever once seen. | Pronunciation ambiguity (sto-where vs stow-here); fine in writing, weaker aloud. |
| 4 | **Putback** | Matches the put-away / coming-home loop; short and punchy. | Says the chore, not the benefit; could read as a sports term. |
| 5 | **Cubbyhole** | Cosy, memorable, storage-native. | Long; doesn't say "find"; "Cubby" apps exist (different category). |
| 6 | Boxkeep | Clear, utilitarian. | Generic; close to "Stashbox"/"Stowbox" neighbours. |
| 7 | Homestash | Descriptive. | "Stash" has drug-slang baggage in ASO. |
| 8 | Thingkeeper | Fully descriptive. | Clunky. |
| 9 | Hereish / Whereish | Playful. | Reads as a joke; weak for search. |
| 10 | Located | Plain. | Common word: unsearchable in the App Store. |

Also free but weaker: Kitbox, Stashspot, Wherebin, Keptwhere, Thingspot, Wherely, Binned, Thingsy, Wherekeep, Homebin, Tidbin, Lodged, Nestbox, Findery, Stashery.

**Decided: Hereabouts** (9 Oct). Keepwhere was the runner-up. Both pass the "heard once, spelled right" test, neither collides with a competitor, and both describe the core job (where things are) rather than the method (notes, boxes, stashing). Notecation, as discussed, collides with "notification" aloud and points at note-taking.

Rename scope when you decide: display name and `CFBundleDisplayName`, app icon wordmark if any, notification titles, strings that say "Localiser" (about 25), the design canvas, docs, and the bundle ID *before* the first App Store Connect record is created (bundle IDs cannot change afterwards; `dev.localiser.app` would be visible only in URLs and receipts, but it is cleaner to fix now).

---

## 8. Phased plan

| Phase | Scope | Est. |
| --- | --- | --- |
| **0 · Decide** | Decided 9 Oct: Hereabouts, sync out, aggressive lifetime-only pricing, item names on. Remaining: enrol in the Developer Program; reserve "Hereabouts" and buy the domain; create the bundle ID (`app.hereabouts.ios` or similar) and the non-consumable product. | You, this week |
| **1 · Make it not feel broken** | Place picker with inline create and typed paths; place detail shows nested items; camera on "Snap a photo"; archived items off the free count; notification action replay; day-trip quantities; name/notes limits; delete → archive with undo; restore "erase and restore" path; plain-English copy pass; hide sync (Option A); all P1 rows from the UI pass (section 9). | 2 sessions |
| **2 · Store readiness** | Privacy policy + support page hosted; Info.plist keys; permission strings; strip unused entitlements; Settings and Pro restyled with policy/terms links; onboarding (3 screens) and TipKit tips; Due soon "Add to Calendar" actions; iPad run-through; accessibility audits green; screenshots from the demo library; review notes; remaining P2 rows from the UI pass (section 9). | 2 sessions |
| **3 · Differentiators** | Spotlight indexing; App Intents ("Where is my…"); Due soon widget; photo-first capture. | 2 sessions |
| **3.5 · Notebook restyle** | Section 10 in full: bundle fonts, retoken `DesignSystem.swift`, restyle every screen to the canvas, onboarding and leaving screens, copy pass, Sunday recap, keeping-up count, monthly stocktake, per-thing "confirmed on" date. UI tests and audits stay green throughout. | 3 sessions |
| **4 · Beta** | TestFlight external group per `BETA_AND_RELEASE.md`; sandbox purchase/restore/refund on two devices; notification delivery after several days; camera with real receipts; Files providers; time-zone change. Fix what surfaces. | 2–3 weeks elapsed |
| **5 · Submit 1.0** | Final localisation of copy (en-GB primary with en-US), App Privacy label, age rating, keywords, Founder's price and its 8-week end date scheduled, submit. | 1 session + review time |
| **1.x** | More than one home: `Home` above `Place`, switcher on Find and Places, search and export across homes, free 2 / Pro no limit, Pro page gets a fourth dotted-leader row. | later |
| **1.1** | iCloud sync done properly (two-device verified, no restart), calendar keep-in-sync, encrypted backups, String Catalog, native iPad, container operations and QR labels. | later |

All four open questions were decided on 9 October; see the Decisions table at the top.

---

## 9. UI pass: intuitive, welcoming, easy to use

Method: walked every screen in the simulator twice, once with the demo library and once as a fresh install (empty library, no notification permission), asking three questions of each screen: can a first-time user tell what to do next, does the copy sound like a person, and is the primary action the most visible thing. Nothing here is implemented; each row names the file to touch. P1 = a new user gets stuck or misreads the app; P2 = friction or developer-speak; P3 = polish.

### 9.1 First run and empty states

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | Due soon (empty) | "+" opens "Choose an item" that says only "Add a belonging in Find first." and a Done button. Dead end on a fresh install. | Replace with an inline "Add an item" button that opens the item editor, then returns to the deadline editor with that item preselected. Hide the "+" entirely while the library is empty. | `Dates/DueView.swift` (DeadlineEditor item picker) |
| P1 | Due soon (empty) | "Reminder coverage: Notifications: Disabled in Settings · 0 of 0 upcoming reminder requests scheduled" is the second thing a new user reads. It sounds like an error before they have done anything. | Do not render the coverage card until at least one deadline exists. When it does render, lead with a sentence and one button: "Turn on notifications so we can remind you before the 11 Oct return." / [Enable notifications]. Keep the technical counts behind a disclosure. | `Dates/DueView.swift` |
| P1 | Due soon (empty) | The eye-icon toolbar toggle (show/hide resolved) is present with nothing to toggle, and it has no label anywhere. | Hide it while there are no resolved deadlines; when shown, use a Menu with a labelled item ("Show completed") or a segmented "Upcoming / Done" control. | `Dates/DueView.swift` |
| P2 | Places (empty) | Headline and copy are good, but there is no button; the only affordance is the "+" in the corner. Find's empty state has "Add your first item", so the two screens feel inconsistent. | Add "Add a place" button under the copy, same style as Find. Suggest three starters as chips ("Bedroom", "Kitchen", "Garage") that create with one tap. | `Places/PlacesView.swift` |
| P2 | Packing (empty) | Two grey buttons, a sentence of theory ("Create a trip from a reusable kit or start an empty checklist"), and a footnote about kits. Nothing says why you'd want this. | One warm empty state: "Pack once, never forget the charger" + "Plan a trip" primary button. Mention kits only after the first trip exists. | `Packing/PackingView.swift` |
| P2 | Find (empty) | Good: "Find it next time" + "Add your first item". The hamburger and Scan buttons are the same weight as the main action though, and a new user has no idea what Scan does. | Keep. Add a one-line TipKit tip on Scan after the first item is saved ("Scan a receipt to get a return deadline"). Covered by onboarding in 4.2. | `Find/FindView.swift` |
| P2 | All tabs (empty) | Every empty state uses the same grey box icon, including Due soon and Packing where a box means nothing. | Per-tab icons: Find magnifier, Places house/door, Due soon calendar-clock, Packing suitcase, in the tint colour at reduced opacity rather than grey. | new shared `EmptyState` view |

### 9.2 Adding things

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | New item | "Where does it live?" → Place: Unspecified, a plain picker. With no places yet, the picker is empty and there is no way to make one without leaving the sheet. (Same root cause as 3.1.) | Place field opens a searchable list with "New place '…'" as the first row when the typed text does not match; recent places on top. Typed paths ("Garage › Shelf B") create the chain. | `Find/FindView.swift` PlacePicker |
| P1 | New item | "Snap a photo" tile with a camera icon opens the photo library, not the camera (3.1). | Tile opens the camera; secondary "Choose from library" text button beneath. Photo tile should also show the chosen image as the tile background once picked. | `Find/FindView.swift` ItemEditor |
| P2 | New item | "Suggest name and place from sentence" is a mystery link. It reads like a developer feature. | Rename to "Describe it instead…" and show a placeholder example when tapped: "e.g. passport in the hall closet top drawer". Or drop it from the first-run path and surface it as a Tip after the fifth item. | `Find/FindView.swift` |
| P2 | New item | "Aliases (one per line)" in the optional details. Nobody calls them aliases. | "Also known as (e.g. 'charger, USB-C brick')" with comma separation. | `Find/FindView.swift` |
| P2 | New item | Keyboard stays up with no Done; the Save button sits exactly at the keyboard's top edge. | Add a keyboard toolbar with Done; make Return in the name field move focus to the place field. | `Find/FindView.swift` |
| P2 | Scan | Header "1. Read a document" implies numbered steps, but step 2 only appears later and the user cannot see the sequence. | Replace with a three-dot step indicator at the top ("Read · Review · Save") or drop the number. | `Scanning/ScanView.swift` |
| P3 | Scan | Footer copy is three legal-sounding sentences ("A purchase date alone does not establish a return deadline"). | One line: "Everything is read on your phone. You'll confirm the dates before anything is saved." Move the purchase-date rule to the review step where it applies. | `Scanning/ScanView.swift` |

### 9.3 Item and place detail

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | Item detail | "Found here / move here" row is ambiguous (is it a status or a button?) and is a no-op when the place is unchanged. | Split into a clear "Location" card with the breadcrumb and one "Move…" button; show "Moved 3 days ago" as a caption. | `Find/FindView.swift` ItemDetail |
| P1 | Item detail | "Delete item permanently" sits one tap from Archive at the bottom, both in red-adjacent styling. | Archive is the only bottom action; Delete lives in the "…" menu, is red, and shows a confirmation that names the item. Pair with the undo toast from 3.3. | `Find/FindView.swift` |
| P2 | Item detail | The date row repeats the item name ("Running shoes · Return by…") inside the item's own page. | Show the deadline kind and date only: "Return by Sun 11 Oct · 2 days". | `Find/FindView.swift` |
| P2 | Place detail | Shows only direct children (3.1); tile count on Find includes nested items, so "3 things" opens a page with one. | Show nested places as a sub-grid at the top and all contained items below, grouped by sub-place. Counts must match what the page shows. | `Places/PlacesView.swift` |
| P2 | Place detail | No way to add an item *to this place* from its page. | Add "+ Add item here" that opens the editor with the place preselected. | `Places/PlacesView.swift` |

### 9.4 Due soon and deadlines

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | Deadline detail | "No future notification is currently scheduled for this date." in grey with nothing to do about it. | Positive state ("We'll remind you Fri 9 Oct at 9:00") or a button ("Turn on reminders"). Add the "Add to Calendar" button from 4.4 directly below. | `Dates/DueView.swift` DeadlineDetailView |
| P2 | Deadline detail | Decisions are link-style rows: "Returning", "Keep it", "Open". "Open" is unclear (reopen? open the shop?). | Two full-width buttons in first person: "I'm returning it" / "I'm keeping it"; a resolved deadline gets "Mark as not done" instead of "Open". | `Dates/DueView.swift` |
| P2 | Deadline detail | Source ("Sport Shop") is a bare caption with no label; nav title repeats the card label. | "From Sport Shop receipt" with a document icon; nav title becomes the item name. | `Dates/DueView.swift` |
| P2 | Due soon list | Row badge "2 days" has no verb; the orange tone is the only hint of urgency. | "Due in 2 days" / "Due tomorrow" / "Overdue 1 day", with the overdue state in a distinct colour and sorted to the top. | `Dates/DueView.swift` |

### 9.5 Packing

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | Trip detail | "Mark away" is a text link, and "Start coming home" is visible while still packing. The trip's lifecycle (packing → away → coming home → done) is never shown. | A single primary button that changes with state: "I'm leaving" (disabled with reason until the departure tasks are done) → "I'm coming home" → "Finish trip". Show the state as a segmented progress strip at the top. | `Packing/PackingView.swift` (TripDetail) |
| P1 | Trip detail | "Cancel trip" and "Delete trip" both red, side by side, with no explanation of the difference. | Keep only "Delete trip" in the "…" menu with a confirm sheet. If cancel must stay (keeps history), name it "Archive trip" and explain in the confirm sheet. | `Packing/PackingView.swift` (TripDetail) |
| P2 | Trip detail | "Add item or free-text row" is developer-ese; the card has square corners unlike every other card. | "Add something to pack" with a search field that offers library items first and "Just type it" as the last row. Match corner radius. | `Packing/PackingView.swift` (TripDetail) |
| P2 | Trip and kit detail | Departure tasks are rendered as toggles; the "New departure task" text field and "Add departure task" button are both present. | Checkboxes (circle → checkmark) like Reminders; one "Add task" row that becomes a text field when tapped. | `Packing/PackingView.swift` |
| P2 | Kit detail | "Create trip from this kit", the point of a kit, is the last row and hidden under the tab bar on first load. | Move it to a primary button under the title or into the toolbar. | `Packing/PackingView.swift` (KitDetail) |
| P2 | Kit detail | "Packing rows", "1 total · Every trip", "Reusable departure routine". | "What to pack", "1 · every trip" / "1 per night", "Before you leave". | `Packing/PackingView.swift` (KitDetail) |
| P2 | Packing home | The current trip card floats above a "Trips" header whose only content is "New trip". "4 rows" on the kit. | Put the active trip inside the Trips section as the first card; past trips collapsed below. "4 items". Rename the demo so the kit and the trip are not both "Ski trip". | `Packing/PackingView.swift`, demo seed |
| P3 | Trip detail | "Status: packing" plain caption. | Replace with the progress strip above. | `Packing/PackingView.swift` (TripDetail) |

### 9.6 Navigation and chrome

| Pri | Screen | What I saw | Proposed fix | Where |
| --- | --- | --- | --- | --- |
| P1 | Find | Settings, backup, Pro and "Put-away mode" are under a hamburger menu that exists only on Find. From the other three tabs there is no way to reach Settings. | A gear in the top-left of every tab (or a fifth "More" tab if the list grows). Put-away mode becomes a labelled toolbar button with a Tip the first time it is seen. | `LocaliserApp.swift` (RootView), `Find/FindView.swift` |
| P1 | Pro | Two dismiss controls (back "<" and "X"), no benefit list, no price hero. | Single close. Layout: headline, three benefit bullets with icons, the price as the largest text, one purchase button, "Restore purchases" and policy/terms links in the footer (also needed for 4.1). | `Purchases/ProView.swift` |
| P2 | Find | "Due soon" and "Places" sections on the Find home duplicate the Places and Due soon tabs. Fine as a dashboard, but the section headers do not navigate anywhere. | Make the headers tappable ("See all ›") so the duplication reads as a summary, and cap each to three rows. | `Find/FindView.swift` |
| P2 | Settings | Wall of grey text (already noted in 4.1/4.2). | Grouped list: Reminders, iCloud (if shipped), Backup, Pro, Privacy & Support, About. One sentence per group. | `Recovery/LibrarySettingsView.swift` |
| P3 | Tab bar | Tab order Find · Places · Due soon · Packing is right. The Find icon is a magnifier but the tab is also "home"; fine. | No change. | — |

### 9.7 Copy principles to apply across the app

- Second person, first person on decisions: "I'm returning it", "I'm leaving".
- Verbs on buttons, nouns on headers; never "row", "request", "coverage", "alias", "free-text" in user-facing text.
- One sentence of explanation per card, the rest behind a disclosure or a Tip.
- Positive by default: say what will happen, not what is not scheduled.
- Every empty state has a headline, one line of why, and one button.

### 9.8 Where this lands in the phased plan

- Phase 1 absorbs all P1 rows (they are the "feels broken" list) and the New item / Place detail P2 rows, since they share code with the place-picker fix.
- Phase 2 absorbs the remaining P2 rows alongside the onboarding and Settings/Pro restyle, so the copy pass happens once.
- P3 rows are optional and can ride with 1.1.

---

## 10. Design direction: a well-kept notebook (decided 9 October, later)

The canvas is at https://claude.ai/artifact/LoqZd8A3TCpKVEDLvDkeDH (private, owner's account). The artboard sources are checked in under `Docs/Design/canvas/` (`*.dc.html`, plain HTML; open in a browser, the `support.js` reference can be ignored) with `canvas.json` listing the boards. This section is the source of truth when the two disagree.

### 10.1 Feel and rules

One nameable look: a notebook someone keeps well. Paper, ink, a pencil, a highlighter, a rubber stamp. Flat colour, 1.5px ink rules, no shadows, no gradients, no blur, no orbs, no rounded-rectangle cards floating on grey. Purple is the ink, not a wash: the dominant colour comes from ink on paper, not from large purple fills.

### 10.2 Tokens (replace `Theme` in `Localiser/Design/DesignSystem.swift`)

| Token | Light | Dark ("night") | Use |
| --- | --- | --- | --- |
| paper | `#F6F1E9` | `#17131F` | Page background |
| lilacPaper | `#ECE5F3` | `#2A2340` | Second surface: sticky notes, inactive tabs, sheets |
| highlighter | `#E6DBF7` | `#3A3150` | Selected row, search match, active state behind text |
| ink | `#241B3D` | `#F1EBF7` | Text, rules, borders, the ink bar |
| purpleInk | `#5B3DB8` | `#B59CF5` | Primary buttons, links, pen strokes, ticks |
| deepInk | `#3B2A7A` | `#B59CF5` | Pressed/hover of purpleInk |
| pencil | `#655C7A` | `#B5ABC9` | Secondary text, captions, leaders |
| rule | `#D9D0E6` | `#3A3150` | Hairlines between rows |
| leader | `#B4A9C7` | `#5A4F78` | Dotted leaders |
| amber | `#9A4A14` | `#E8A772` | Due, overdue, erase, "Founder's price" stamp |
| green | `#2E6B3F` | `#8BD1A0` | Done, confirmed, "still there" |

Every text/background pair above passes 4.5:1 in the role it is used for; keep the XCUI contrast audits on.

### 10.3 Type

- Display and item names: **Fraunces** (variable, optical size on, weight 500 for headlines, italic for quotes and sticky notes). Headlines 34–38pt at Large, `-0.01em` tracking, line height 1.05.
- Body and UI: **Atkinson Hyperlegible** 400/700. Body 16–17pt, captions 13pt, uppercase labels 11pt with `.16em` tracking.
- Both are SIL OFL. Bundle the TTF/OTF files in the app, register them in `Info.plist` (`UIAppFonts`) via `project.yml`, wrap in `Font.custom(_:size:relativeTo:)` so Dynamic Type still scales. Fall back to Georgia / system if a font fails to load.

### 10.4 Motifs and components

| Motif | Where | Spec |
| --- | --- | --- |
| Dotted leader | Every list row: name on the left, place/count on the right, 2px dotted `leader` between, baseline aligned | `Find`, `Places`, `Trips`, `Pro` rows |
| Rubber stamp | States: "Due Sun", "Overdue", "Packed", "Founder's price", "4 months ago" | Uppercase 11–12pt 700, `.14em`, 1.5px border + 1px outline offset 2px, 3px radius, rotated −3° to −6°, colour = state (amber/green/ink) |
| Bottom nav | Find · Places · Due · Trips | **Stock iOS `TabView` tab bar, as the app has today.** Not the index tabs drawn on the Find/Due/Trips boards and not the four alternatives on the "Bottom navigation options" board; all were reviewed and rejected. Tint it `purpleInk`, use the same four line icons as the boards for the tab symbols, and leave the system bar background alone. |
| Highlighter | Selected row, search-term match, active filter | `highlighter` fill behind the text only, 2px radius, no border |
| Pen tick | Checklist and "still there" | Hand-drawn path, `purpleInk`, 2.2px stroke, animates on in 180ms |
| Sticky note | Tips, Pro explainer, leaving note | `lilacPaper`, 6px radius, rotated ±0.8°, a paper "tape" strip at top centre; replaces TipKit's default popover styling where TipKit allows, otherwise a custom view |
| Ticket stub | A trip on the Trips tab | Perforated edge, destination in Fraunces, dates stamped |
| Sentence search | Find | The field reads "Where is…" and the user completes the sentence; results appear as "lives in Kitchen › Top drawer" |

### 10.5 Words

Plain and warm. "Things" not items; "lives in" not located at; "put back" not restock; "Due" and "Trips" are the tab names (Due soon → Due, Packing → Trips, Kits stay kits inside Trips). "Keeping up: 6 weeks" and never "streak broken". Settings → "Leaving" page is "Take your notebook with you." Full copy is on the Voice board and in each screen board; apply it verbatim unless it breaks a test, then adjust the test.

### 10.6 Screens on the canvas

Onboarding 1–3 (your notebook / first thing / nudges, no account), Find, Thing, Due, Trips, Find at night, Sunday recap, Monthly stocktake, Pro, Leaving. Every screen ships; the night boards define dark mode.

### 10.7 Retention features (new behaviour)

| Feature | Behaviour | Data |
| --- | --- | --- |
| Keeping up | "Keeping up: N weeks" = consecutive weeks (Sunday to Saturday, local) in which the user wrote something down or confirmed something. Shown on the recap and the Find header. Never shown as broken; when it resets it just shows the new count. | Derived from `createdAt`/`confirmedAt`; no new store |
| Sunday recap | A sheet offered once a week (Sunday 6pm local, or next launch after): what was added, what is due this week, what has drifted. Opt-out in Settings. | Local notification + in-app sheet |
| Monthly stocktake | Up to five "Still there?" cards a month for things not confirmed in 3+ months. Answers: Still there (sets `confirmedAt`), Moved (opens place picker), Don't have it any more (archive with undo). Opt-out in Settings. | Needs `confirmedAt: Date?` on Item (Core Data V6, lightweight migration; default to `createdAt`) |
| Drifting | On the recap: things whose `confirmedAt` is oldest | Derived |

### 10.8 Order of work (Phase 3.5)

1. Fonts bundled and `DesignSystem.swift` retokened; the app builds and all tests pass with nothing else changed.
2. Lists and rows (leader, stamp, highlighter) across Find, Places, Thing, Due, Trips.
3. Tab bar tint and symbols (stock bar stays); Settings, Pro, Leaving.
4. Onboarding three pages; sticky-note tips.
5. Core Data V6 `confirmedAt`; stocktake; recap; keeping up; notifications and Settings switches for both.
6. Dark mode pass against the night board; accessibility audits; store screenshots retaken from the demo library.
