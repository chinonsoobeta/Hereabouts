# Second opinion on RELEASE_PLAN.md

This file is the raw record of the two Codex reviews. Every finding in it is merged into `RELEASE_PLAN.md`, and section 9 there says what each one became. Work from the plan, not from this file.

Produced by Codex CLI 0.163.0, reasoning effort medium, read-only sandbox, 4 November 2026. Reviewed against commit `ca75b98` plus the uncommitted plan. Verified against the code afterwards; the "yearly-only trial" item rests on a wrong line in the plan, not on the app (the feature plan gives the trial to both subscriptions). Everything else checked out and is folded into `RELEASE_PLAN.md`.

---

## Factual errors in the plan

- **“Trial is on the yearly product only, matching the sentence in the app”** (`Docs/RELEASE_PLAN.md:183`) is false for the implementation. `ProAccess.swift:119` derives one eligibility flag from yearly; `ProView.swift:80`, `:111` and `:147–150` apply it to **both subscriptions**. The local configuration also gives monthly a two-week trial (`LocaliserTests/Localiser.storekit:49`). Your yearly-only requirement needs code, configuration and test changes.

- **“6 skipped … need the StoreKit configuration attached”** (`Docs/RELEASE_PLAN.md:13`) gives the wrong explanation. The configuration is already attached (`Localiser.xctestplan:4`). The purchase tests explicitly skip below iOS 27 because of the iOS 26.5 StoreKit test-service failure (`LocaliserTests/SubscriptionTests.swift:9`; `LocaliserTests/LocaliserTests.swift:13`).

- **“Archive with the iOS 26 SDK from Xcode 27.2”** (`Docs/RELEASE_PLAN.md:149`, repeated at `:197`) confuses deployment target with SDK. `project.yml:4` sets the **minimum OS** to 26.0; the shelf implementation uses iOS 27 APIs (`Localiser/Find/ShelfPhoto.swift:61–75`). Reading the installed Xcode’s `SDKSettings.plist` returned SDK version **27.2**.

- **“Deploy the CloudKit schema to production … for 1.1 only”** (`Docs/RELEASE_PLAN.md:151`) contradicts its optional 1.0 sync path. The existing instruction correctly says **before the release containing sync** (`Docs/FEATURE_PLAN.md:357`). Production schema deployment must also precede TestFlight testing of sync. [Apple CloudKit guidance](https://developer.apple.com/icloud/cloudkit/designing/)

- **“Build number higher than any TestFlight build”** (`Docs/RELEASE_PLAN.md:204`) is unnecessary. Submit the tested TestFlight build itself; a replacement upload needs a new number. [Apple TestFlight guidance](https://developer.apple.com/testflight/)

- **Several guideline labels are wrong:** “2.3.8 Screenshots” (`:180`) concerns all-audience metadata; actual-app screenshots fall under **2.3.3**. “3.1.2(c)” for lifetime alongside subscriptions (`:184`) should reference **3.1.2(a)**; (c) concerns subscription information. “5.1.1(ix) Data not collected” (`:190`) actually concerns regulated services and sensitive information. [Apple’s guidelines](https://developer.apple.com/app-store/review/guidelines/)

- **The proposed guard checks a misspelled key:** `HeareaboutsFreeThings` (`Docs/RELEASE_PLAN.md:135`). The actual key is `HereaboutsFreeThings` (`project.yml:38`; `Localiser/Purchases/ProAccess.swift:13`).

## Things the plan misses

- **Fix and verify yearly-only trial disclosure — Mac, no paid account needed.** Make the badge, purchase button and terms depend on the selected product’s actual offer and eligibility. Remove monthly’s local offer and update the existing test that explicitly expects a monthly trial (`LocaliserTests/SubscriptionTests.swift:33–37`). Run the purchase tests on iOS 27; retain the separate device sandbox check.

- **Complete App Group configuration if B1–B3 ship — owner registration; local code/configuration work on this Mac.** Setting `HEREABOUTS_APP_GROUP` alone is insufficient: the app’s entitlements are empty (`Localiser/Localiser.entitlements:3`). The existing handoff explicitly requires the entitlement (`Docs/HUMAN_BLOCKED.md:11`). Shared defaults also need the applicable **1C8F.1** reason: `NotebookFile.swift:18` accesses a suite, while `PrivacyInfo.xcprivacy:9` declares only app-private CA92.1. [Apple’s required-reason definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

- **Add privacy-policy retention/deletion and support handling — Mac drafting; owner confirms actual practices.** The policy omits how to erase the notebook and what survives in exported/device backups. The app already explains this (`Localiser/Recovery/LibrarySettingsView.swift:123–124`). Its statement that it “only learns whether Pro is unlocked” (`Site/privacy.html:16`) also understates the purchase information read in `ProAccess.swift:68–74`. Explain voluntary support emails and diagnostic attachments too (`Support.swift:25–30`; `LocaliserApp.swift:141–146`).

- **Carry forward the existing launch gates explicitly — mixed responsibility.** The plan cites the older documents but does not schedule their holdout assessment, real reminder delivery, offline recovery, denied permissions, refund/Ask to Buy/Family Sharing checks, or smallest-phone accessibility checks (`Docs/BETA_AND_RELEASE.md:23–47`). Fixture preparation and simulator checks are possible on this Mac; physical checks need the owner/devices, and sandbox/Family Sharing checks need account setup.

- **Account for external TestFlight review — owner/account work.** Stage 3 assumes upload followed by invitations. External testing requires beta information and first-build review. [Apple’s external-testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

## Where I disagree with its recommendations

- **Freeze scope before Stage 0.** Orientation and B1–B3 inclusion are owner decisions, yet Stage 0 calls its work owner-independent (`Docs/RELEASE_PLAN.md:39–49`, `:129`). Decide scope first, fix purchases next, then validate and finalise copy/screenshots.

- **Prefer the currently implemented product for 1.0.** B1–B3 add a storage migration and two extensions. They are useful features, but unnecessary to establish the existing notebook’s usefulness. The feature plan itself identifies B1 as its riskiest single step (`Docs/FEATURE_PLAN.md:365`). Exclude sync firmly rather than introducing it during beta.

- **Portrait-only is a product choice, not a free fix.** “Locking costs nothing” (`Docs/RELEASE_PLAN.md:157`) ignores loss of landscape use. Check the current layouts before removing an advertised orientation. Keeping the iPhone target also does not eliminate iPad compatibility testing, already required by `Docs/BETA_AND_RELEASE.md:45`.

- **Include Homes in 1.0 copy now.** It is already accessible in Settings (`Localiser/Recovery/LibrarySettingsView.swift:33–35`) and priced in the paywall (`ProView.swift:19`). Deferring its mention to 1.1 obscures an existing feature. Likewise, a Pro screenshot can be prepared with local StoreKit now; live products are needed for sandbox verification, not screenshot preparation.

## App Review risks it under- or over-states

- **Understates 3.1.2(c): misleading trial disclosure.** With all three products available and yearly-trial eligibility, a reviewer who selects Monthly would see “2 weeks free” and “Try free for 2 weeks,” despite your intended monthly product charging immediately. This is a code defect, contradicting the plan’s “metadata and configuration, not code” conclusion (`Docs/RELEASE_PLAN.md:35`). See `ProView.swift:80`, `:111`, `:149`. [Guideline 3.1.2(c)](https://developer.apple.com/app-store/review/guidelines/#subscriptions)

- **Misses 3.1.2(a)’s ongoing-value question.** Pro currently removes limits; reminders, exports and other features remain free (`ProView.swift:17–21`, `:35`). Explain the continuing value honestly. Local-only software subscriptions are not categorically forbidden, and lifetime alongside subscriptions is not itself a rejection reason. [Guideline 3.1.2(a)](https://developer.apple.com/app-store/review/guidelines/#subscriptions)

- **Understates 5.1.1(i): policy completeness.** A working URL alone does not address the missing retention/deletion explanation. The in-app policy link already exists (`LibrarySettingsView.swift:57`); improve the destination. [Guideline 5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#privacy)

- **Overstates the difficulty of reaching Pro; understates fresh-install verification.** Release has no demo library (`LocaliserApp.swift:35–37`). Reviewers get three-page onboarding, can skip adding a thing, and can decline notifications (`OnboardingView.swift:113–118`). They can then open **Settings → Hereabouts Pro immediately** (`LibrarySettingsView.swift:28`); adding 21 things is unnecessary. Verify that route with the actual 20-thing limit, all three products and no DEBUG arguments. On iOS 26, reviewers will not see shelf-photo naming (`ShelfPhoto.swift:20`).

## Verdict

This is a useful inventory, but it is not safe to follow unchanged. Fix the yearly-only trial implementation and local purchase tests first, then choose a firm 1.0 scope and restore the omitted release gates. Prefer submitting the exact build tested through TestFlight, with B1–B3 and sync deferred unless explicitly required for launch. I reviewed source, configuration, docs and Apple’s published guidance; I changed no files and did not independently rerun the reported builds or tests.

---

## Second pass, 5 November 2026

Codex CLI 0.163.0, Codex. The full-file walk started on medium reasoning, read nearly every file and stopped at the ChatGPT usage limit before writing. The same session was resumed on low reasoning (one refusal by the limit, then a run once the owner reset the quota). The report below is as Codex wrote it, read-only, no subagents, no builds or tests. Every finding was checked against the code and placed in `RELEASE_PLAN.md` (checklist B and section 8).

## Findings by area

### App entry, configuration, privacy

- **[should-fix]** Localiser/LocaliserApp.swift:133 — The recovery share includes only the SQLite file and its WAL/SHM files. The model permits photos and scan documents to be stored externally, but the adjacent support directory is omitted. Someone following “Save a copy of the notebook file” could retain the records while losing their attachments if the original installation is subsequently removed. **Who can fix it: Mac without a developer account.**

### Data

- **[blocker]** Localiser/Data/NotebookFile.swift:31 — **If B1 is enabled**, the next launch deletes the original notebook solely because a defaults flag is set, before checking that the group notebook still exists and opens successfully. Also, `move` accepts any existing destination as `.alreadyThere` at line 54 without validating it. A missing, damaged or incomplete destination can therefore lead to deletion of the usable original, followed by an empty notebook or the failure screen. This is a specific failure path beyond the already-planned migration verification. **Who can fix it: Mac without a developer account; owner-only activation of the App Group remains separate.**

- **[should-fix]** Localiser/Data/LocaliserStore.swift:242 — Permanently deleting a thing also deletes its counted scan records. Since `completedScans` is calculated from those remaining records at lines 133–136, deleting scanned things replenishes the five-scan allowance during the same month. Restoring an earlier backup likewise rolls usage back. **Who can fix it: Mac without a developer account.**

### Find tab

- **[should-fix]** Localiser/Find/ShelfPhoto.swift:168 — “Several things in this photo?” does not preserve the parent editor’s **Keep private** choice. The batch calls `addItem` with its default `isPrivate: false`, then closes the parent editor. A user who selected privacy before opening the batch screen gets public items eligible for Spotlight and Siri. **Who can fix it: Mac without a developer account.**

- **[should-fix]** Localiser/Find/Finding.swift:20 — `found` changes an item’s place without updating its home, unlike `recordMove`. This is reachable through Siri’s unrestricted place query and through the Found-it suggestions, which are not filtered to the item’s home. The item can appear inside a place in one home while remaining assigned to another home in lists, packing pickers and exports. **Who can fix it: Mac without a developer account.**

- **[minor]** Localiser/Find/FindView.swift:498 — The next-date badge treats every kind other than return or warranty as “Expires.” A lent item with an ask-back date therefore displays an expiry badge instead of an ask-back badge. **Who can fix it: Mac without a developer account.**

### Places and homes

- **[should-fix]** Localiser/Places/PlaceChooser.swift:99 — Ordinary move and place-edit screens restrict choices to the existing home, with no home selector. Although the store supports moving things and whole place trees between homes, users cannot perform that move through those screens. Someone reorganising two homes must recreate records or use the inconsistent Found-it/Siri route instead. **Who can fix it: Mac without a developer account.**

- **[should-fix]** Localiser/Places/DuplicatePlaces.swift:25 — Tidying an empty duplicate deletes it without transferring `TripEntry.homePlace` references to the keeper. A place can have no current items yet still be a packed item’s recorded return location. After tidying it, “Put back” can offer “no place yet” and clear the item’s location instead of returning it to the equivalent retained place. **Who can fix it: Mac without a developer account.**

### Dates, reminders, calendar

- **[should-fix]** Localiser/Dates/CalendarExport.swift:32 — Calendar export redacts a private item’s name but copies its source/terms text verbatim. `upcoming` also includes private items, so bulk export can disclose identifying receipt or document notes without an individual preview. The existing privacy test uses an empty source and checks only the title. **Who can fix it: Mac without a developer account.**

- **[should-fix]** Localiser/Dates/ReminderService.swift:119 — Trip-eve reminders take the first five eligible trips from `store.trips`, which is sorted by departure date descending. With six or more eligible trips, the farthest trips receive reminders while the nearest can receive none. There is no corresponding coverage warning for these omitted trip reminders. **Who can fix it: Mac without a developer account.**

- **[minor]** Localiser/Dates/DueView.swift:396 — An active deadline with no scheduled request is described as having “No reminders left before this date” whenever permission is enabled. That also covers a future reminder excluded by the 50-request cap or a scheduling failure. The detail screen can therefore imply that no reminder is due when it simply has not been queued. **Who can fix it: Mac without a developer account.**

### Scanning and share import

- **[should-fix]** Localiser/Scanning/ShareImport.swift:106 — **If B3 ships**, the share screen preselects the first extracted date, defaults ordinary order/delivery dates to `.returns`, and saves them as confirmed. Unlike the main date editor, it offers neither a final-date editor nor a return-window calculation, and it omits ambiguity/two-digit-year warnings. Sharing an email containing only an order date can create a return deadline on the purchase day. **Who can fix it: Mac without a developer account; the extension’s provisioning remains owner-dependent.**

- **[should-fix]** Localiser/Scanning/ShareImport.swift:40 — Shared import saves a new item before validating and saving the deadline. For example, an extracted source line longer than the 2,000-character source limit leaves the new item saved while reporting “That didn’t save.” Retrying with “Something new” creates another item and consumes another free slot. **Who can fix it: Mac without a developer account.**

### Packing

- **[should-fix]** Localiser/Packing/PackingView.swift:9 — Active and past trips use `store.trips` rather than `store.tripsHere`, and the Trips screen has no `HomeSwitcher`. Kits are filtered to the selected home, but trips are not. Users see mixed-home trips despite Settings explicitly saying that Trips shows the chosen home, and must leave the tab to change which home supplies new kits/trips. **Who can fix it: Mac without a developer account.**

### Rituals

- **[should-fix]** Localiser/Rituals/Rituals.swift:54 — Stocktake excludes missing and archived things, but includes lent things. Lending does not update `confirmedAt`, and the stocktake card displays the normal home location without the borrower. A recently lent, previously stale item can immediately prompt “Is it still there?” at home; answering “Still there” leaves it simultaneously recorded as lent out. **Who can fix it: Mac without a developer account.**

- **[minor]** Localiser/Rituals/RitualViews.swift:243 — Recap availability compares an empty read-week preference with the current recap key without checking whether the notebook existed during that week. On a fresh install, adding the first thing can immediately produce “Sunday’s recap is ready,” including midweek before the user’s first Sunday. **Who can fix it: Mac without a developer account.**

### Purchases

- **[should-fix]** Localiser/Purchases/ProView.swift:23 — Anyone with an active subscription sees only the owned-state section; all purchase choices, including Lifetime, disappear. A subscriber cannot switch to the advertised lifetime product from the app, even though the code handles lifetime ownership alongside a renewing subscription. **Who can fix it: Mac without a developer account.**

### Settings, backup, recovery, onboarding, support

- **[should-fix]** Localiser/Recovery/LibraryBackup.swift:135 — Restore commits the replacement notebook before calling `ensureHomes`. Restoring an older backup therefore requires a second persistent save to create and assign its home. If that step fails, rollback cannot recover the already-committed original notebook, contrary to the confirmation message promising that any failure leaves it exactly as it was. The destructive fetch/delete loop also begins outside the rollback-protected `do` block. **Who can fix it: Mac without a developer account.**

- **[should-fix]** Localiser/Onboarding/OnboardingView.swift:168 — Replaying onboarding checks only the free item limit and never consults Pro entitlement. With 20 or more active things, even a paying user’s “Write it down” action silently advances without saving. A free user at the limit gets the same silent result rather than an explanation. **Who can fix it: Mac without a developer account.**

### System integration

- **[should-fix]** Localiser/System/Intents.swift:52 — Siri/Shortcuts search returns private things by name, alias, notes and place because it uses the unrestricted search index. `ThingEntity` exposes their real names and replaces only the location with “Private.” Searching can therefore reveal a private item in entity-selection results despite the editor promising it “stays out of … Siri.” Filtering only suggested entities does not prevent this. **Who can fix it: Mac without a developer account.**

- **[should-fix]** Localiser/System/Intents.swift:103 — “Where is it?” ignores `missingSince` and confidently answers that a missing thing is in its recorded place. The sharing sentence in `Localiser/System/AppLinks.swift:78` makes the same claim. After marking something “Not there,” users still receive or share the location they have just said is wrong. **Who can fix it: Mac without a developer account.**

- **[minor]** Localiser/System/Intents.swift:65 — Place entities contain only the place path, without the home name. Two homes with “Kitchen › Drawer” produce indistinguishable Siri/Shortcuts choices; selecting the wrong one can save or move an item into the wrong home. **Who can fix it: Mac without a developer account.**

### Design and demo

Nothing new.

### Tests

- **[should-fix]** LocaliserTests/LocaliserTests.swift:171 — The free-limit tests check counts, month rollover and the allowance predicate, but do not exercise deleting a counted scan, restoring an older usage state, or replaying onboarding as a Pro user above the free limit. Those missing cases leave the allowance defects above undetected. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserTests/PrivateThingsTests.swift:27 — Privacy coverage checks a calendar title with empty source notes and a canned Siri answer, but not private search results, calendar source notes or shelf capture after selecting Keep private. These tests can pass while the privacy disclosures described above still occur. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserTests/NotebookFileTests.swift:68 — Migration coverage exercises a healthy destination only. It does not test an existing invalid destination, a missing destination with the moved flag set, or failure before the replacement notebook has opened. Backup replacement tests likewise reject malformed input before mutation rather than testing failure during replacement and home creation. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserTests/HomesTests.swift:19 — Home-filtering tests inspect store properties but do not verify the Trips screen, cross-home Found-it operations, or duplicate-place cleanup with packing return references. The UI home test checks only Places. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserUITests/LocaliserUITests.swift:21 — The paywall test accepts the unavailable-products screen whenever Yearly fails to appear, regardless of OS version. On the intended iOS 27 test environment, a broken configuration or product-loading regression can therefore pass instead of failing the three-product acceptance check. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserTests/SubscriptionTests.swift:47 — The test named for subscription lapse substitutes a refund for actual expiry, and the grace-period test asserts only that access remains unlocked without asserting that the simulated subscription entered grace. Natural expiry and the transition out of grace remain unproven by these tests. This is separate from merely running the currently skipped tests. **Who can fix it: Mac without a developer account.**

- **[should-fix]** LocaliserUITests/LocaliserUITests.swift:516 — Accessibility audit exceptions suppress every static-text contrast failure within 24 points below a navigation bar, plus several labels unconditionally. They are broader than the particular rendered cases documented in comments, so a future genuine contrast regression in those positions or labels can pass. **Who can fix it: Mac without a developer account.**

### Site and docs

- **[should-fix]** Site/support.html:6 — The new-phone instructions recommend “Back up everything” without explaining that photos and documents are excluded by default and must be selected separately. Someone relying on these instructions can transfer a notebook without its attachments and discover that only after retiring the old phone. **Who can fix it: Mac without a developer account.**

- **[minor]** Site/support.html:10 — “Restore from a backup” is presented as the recovery step for one accidentally deleted thing without warning that restore replaces the entire current notebook. Users may recover that thing while discarding everything added or changed since the backup. **Who can fix it: Mac without a developer account.**

- **[minor]** Docs/BETA_AND_RELEASE.md:43 — The physical Siri test still asks testers to check rejection of the **201st** free thing. The planned correction to the separate reviewer-notes paragraph does not fix this instruction; testers need to verify rejection of the **21st** thing. **Who can fix it: Mac without a developer account.**

## Cross-cutting

- **Privacy needs consistent enforcement across creation and output paths.** The editor’s privacy promise is stronger than the behavior of shelf capture, Siri entity search and calendar source-note export. Redacting a display name alone does not prevent disclosure.
- **Home identity is not consistently maintained or presented.** Normal moves update the home, Found-it does not; ordinary move pickers prevent cross-home selection, Found-it suggestions can allow it; Trips mixes homes; Siri place choices omit home names.
- **Monthly usage and retained content are currently the same records.** Deleting or restoring content consequently changes the scan allowance. This differs from the intended active-item allowance, where archiving deliberately frees a slot.
- **The font licence files are already present.** Both `atkinsonhyperlegible-OFL.txt` and `fraunces-OFL.txt` were read. I have not repeated the previous review’s missing-licence finding; I did not verify their inclusion in a built archive.
- This was a source/configuration/test review, not an interactive Release-install walkthrough. No files were modified, no subagents were used, and no builds or tests were run. Findings describe traced code paths; device behavior, rendered accessibility, live StoreKit and extension execution remain unverified here. The B1 and B3 findings apply only if those features are enabled for 1.0.

## Coverage

Every path below was read in full across this session. For the model, coverage includes the current-version pointer and both V7 and V8. For Fonts, the directory was inventoried and both licence texts were read; the six binary font files were not inspected internally.

```text
Docs/RELEASE_PLAN.md
Docs/RELEASE_PLAN_SECOND_OPINION.md
project.yml
Localiser/Info.plist
Localiser/Localiser.entitlements
Localiser/PrivacyInfo.xcprivacy
Localiser/LocaliserApp.swift
Localiser.xctestplan
Localiser/Assets.xcassets/AppIcon.appiconset/Contents.json
Localiser/Data/LocaliserStore.swift
Localiser/Data/Records.swift
Localiser/Data/Homes.swift
Localiser/Data/NotebookFile.swift
Localiser/Data/Localiser.xcdatamodeld/.xccurrentversion
Localiser/Data/Localiser.xcdatamodeld/LocaliserV7.xcdatamodel/contents
Localiser/Data/Localiser.xcdatamodeld/LocaliserV8.xcdatamodel/contents
Localiser/Find/FindView.swift
Localiser/Find/Search.swift
Localiser/Find/Finding.swift
Localiser/Find/PutAway.swift
Localiser/Find/Lending.swift
Localiser/Find/LendSheet.swift
Localiser/Find/ShelfPhoto.swift
Localiser/Find/CameraPicker.swift
Localiser/Find/UndoDeletionToast.swift
Localiser/Places/PlacesView.swift
Localiser/Places/PlaceChooser.swift
Localiser/Places/HomesView.swift
Localiser/Places/DuplicatePlaces.swift
Localiser/Places/BoxLabels.swift
Localiser/Dates/DueView.swift
Localiser/Dates/DateRules.swift
Localiser/Dates/ReminderService.swift
Localiser/Dates/CalendarExport.swift
Localiser/Scanning/ScanView.swift
Localiser/Scanning/ScanReader.swift
Localiser/Scanning/ShareImport.swift
Localiser/Scanning/OrderEmail.swift
Localiser/Packing/PackingView.swift
Localiser/Packing/PackingStore.swift
Localiser/Packing/PackingRecords.swift
Localiser/Rituals/Rituals.swift
Localiser/Rituals/RitualViews.swift
Localiser/Purchases/ProAccess.swift
Localiser/Purchases/ProView.swift
Localiser/Recovery/LibrarySettingsView.swift
Localiser/Recovery/LibraryBackup.swift
Localiser/Onboarding/OnboardingView.swift
Localiser/Support/Support.swift
Localiser/System/Intents.swift
Localiser/System/PutAwayIntent.swift
Localiser/System/AppLinks.swift
Localiser/System/Spotlight.swift
Localiser/System/Tips.swift
HereaboutsControls/HereaboutsControls.swift
HereaboutsControls/Info.plist
Localiser/Design/DesignSystem.swift
Localiser/Design/DemoLibrary.swift
Localiser/Design/Fonts/atkinsonhyperlegible-OFL.txt
Localiser/Design/Fonts/fraunces-OFL.txt
LocaliserTests/AppLinkTests.swift
LocaliserTests/BoxLabelTests.swift
LocaliserTests/DuplicatePlacesTests.swift
LocaliserTests/FindingTests.swift
LocaliserTests/HomesTests.swift
LocaliserTests/IntentsTests.swift
LocaliserTests/LendingTests.swift
LocaliserTests/Localiser.storekit
LocaliserTests/LocaliserTests.swift
LocaliserTests/ModelV7Tests.swift
LocaliserTests/NotebookFileTests.swift
LocaliserTests/OrderEmailTests.swift
LocaliserTests/PrivateThingsTests.swift
LocaliserTests/PutAwayTests.swift
LocaliserTests/RitualsTests.swift
LocaliserTests/ShareImportTests.swift
LocaliserTests/ShelfPhotoTests.swift
LocaliserTests/SubscriptionTests.swift
LocaliserUITests/LocaliserUITests.swift
Site/privacy.html
Site/support.html
Docs/BETA_AND_RELEASE.md
Docs/HUMAN_BLOCKED.md
Docs/Store/README.md
README.md
```
