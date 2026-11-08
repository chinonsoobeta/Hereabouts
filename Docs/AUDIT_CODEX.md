# Adversarial audit: Codex's half (M64)

Codex audited the app's logic on its own and didn't see Claude's half. It wrote nine tests in the class `AuditCodexTests`, under `LocaliserTests/Audit/`. Its sandbox couldn't compile the app, so the auditor compiled and ran them. Before any fix, all nine fail on iOS 27 and iOS 26.5 (9 tests, 12 failed assertions on each), each for the reason given below. The one change the auditor made to Codex's tests was to rewrite the class's setup and teardown so they compile under Swift 6's isolation checks.

## Auditor's decisions

| # | Finding | Decision |
| --- | --- | --- |
| 1 | Edits lost when a stale shared notebook returns | Fixed in `c8e4633`: when the shared copy is missing, go back to the original and copy it across again on the next launch. Only phones that ran a build from before the App Group can reach this. |
| 2 | Blank Shortcuts search lists private things | Already fixed: the same bug as Claude's F3 (`419146c`). |
| 3 | Put back after deleting the place clears it | Already fixed: the same bug as Claude's F1 (`b71be59`). |
| 4 | Restore isn't held to the free limits | Accepted. A person whose Pro has lapsed must be able to restore their own notebook. Going past the limits this way means writing a backup file by hand. The test is left out of the suite. |
| 5 | Restore accepts a thing in another home from its place | Accepted. Only a backup file edited by hand can do this; the app keeps a thing and its place in the same home. The test is left out of the suite. |
| 6 | Restore accepts one thing packed for two overlapping trips | Accepted, for the same reason as 5. The person can unpack either trip. The test is left out of the suite. |
| 7 | Siri doesn't say which home | Fixed in `8a4e97a`: with more than one home, the answer leads with the home, the same way places are shown in Shortcuts ("Cottage · Drawer"). |
| 8 | Voice matches a place nested the other way round | Accepted. It needs a place tree nested the opposite way to how the person describes it. The suggested fix would break the natural "in the hall closet, on the top shelf" order. The person checks the place on the Put away screen before saving. The test is left out of the suite. |
| 9 | Restored notes over the limit block unrelated edits | Accepted. Only a hand-edited backup can carry notes over 5,000 characters. The editor shows the counter, so the person can trim them. The test is left out of the suite. |

With both fixes, the unit tests pass: 165 run on iOS 27 with 0 failures, and 165 run on iOS 26.5 with 6 skipped (the StoreKit purchase tests) and 0 failures.

The rest of this file is Codex's report as written, apart from the Verification section, which now gives the auditor's results.

## Findings, ranked

### 1. Recovery edits disappear when a stale shared notebook returns

- **Severity:** data loss.
- **Location:** `Localiser/Data/NotebookFile.swift:35–39`.
- **What happens:** After a missing App Group copy causes a fallback to the original notebook, the migration flag stays set. If a readable stale copy later returns, the app opens it and deletes the original, including anything saved during recovery.
- **Test:** `testMigrationFallbackEditsSurviveAStaleGroupCopyReturning`, in `LocaliserTests/Audit/MigrationFallbackTests.swift`.
- **Evidence:** The fixture completes the initial migration, removes the group copy before the next launch, saves a new thing through the fallback, and recreates the old group snapshot; the final notebook contains only Passport instead of Passport and Wallet added after recovery.
- **Suggested fix:** Record fallback as a change of authoritative notebook and require a verified transfer of its latest contents before selecting a group copy or removing the original.

### 2. Blank Shortcuts searches reveal private names

- **Severity:** privacy leak.
- **Location:** `Localiser/System/Intents.swift:54–57`; `Localiser/Find/Search.swift:54`.
- **What happens:** An empty or whitespace-only entity query returns private thing names in Shortcuts without the person naming those things. Private suggestions are filtered separately, but the blank search route bypasses that protection.
- **Test:** `testBlankShortcutSearchDoesNotDisclosePrivateNames`, in `LocaliserTests/Audit/AuditCodexTests.swift`.
- **Evidence:** Both queries return the private Recovery codes entity because an empty search receives a non-nil score even when the privacy filter removes place and notes.
- **Suggested fix:** Exclude private things from blank entity searches before applying name and alias matching.

### 3. Deleting a packed thing's return place erases its replacement location

- **Severity:** data loss, limited to the saved location.
- **Location:** `Localiser/Data/LocaliserStore.swift:218–227`; `Localiser/Packing/PackingStore.swift:132`; `Localiser/Data/Localiser.xcdatamodeld/LocaliserV8.xcdatamodel/contents:30`.
- **What happens:** Deleting Box with its contents moves Camera into Room, but clears the packed trip's return reference. Choosing Put back when coming home then removes Camera from Room and saves it without a place.
- **Test:** `testDeletingAPackedReturnPlaceKeepsTheReplacementLocation`, in `LocaliserTests/Audit/DeletedReturnPlaceTests.swift`.
- **Evidence:** The fixture includes a nested Pocket, a lent Charger, a kit, and a packed trip; the final assertion expects Camera to remain in Room but its place becomes nil.
- **Suggested fix:** Redirect trip return references to the deleted place's parent in the same transaction that relocates its contents.

### 4. Restore bypasses all three free allowances

- **Severity:** limit bypass.
- **Location:** `Localiser/Recovery/LibraryBackup.swift:110–145`; `Localiser/Recovery/LibrarySettingsView.swift:220–224`.
- **What happens:** A person on the free plan can import a backup containing 16 active things, two kits, and three homes, including over an already full notebook. Neither the restore screen nor the restore operation checks the allowances.
- **Test:** `testRestoreCannotCreateAnOverLimitFreeNotebook`, in `LocaliserTests/Audit/RestoreLimitsTests.swift`.
- **Evidence:** A serialized backup exceeds each allowance by one; after replacement, all three count assertions fail instead of the operation refusing the import and preserving the existing notebook.
- **Suggested fix:** Check the entitlement and resulting counts at the restore boundary while preserving access to already retained records after a lapse.

### 5. Restore accepts a thing assigned to a different home than its place

- **Severity:** wrong answer.
- **Location:** `Localiser/Recovery/LibraryBackup.swift:189–213`; `Localiser/Data/Homes.swift:98–114`.
- **What happens:** An imported thing can belong to Cottage while its Drawer belongs to the original home. The person sees inconsistent home lists, counts, and location information even though the import reports success.
- **Test:** `testRestoreDoesNotSplitAThingFromItsPlacesHome`, in `LocaliserTests/Audit/RestoreHomeConsistencyTests.swift`.
- **Evidence:** The fixture changes the thing's home and both home inverse lists, keeping all relationship types and inverses valid; restore accepts it, and the thing's home differs from its place's home.
- **Suggested fix:** Validate or normalize home ownership throughout each place tree and for things inside those places before committing a restore.

### 6. Restore allocates one physical thing to overlapping trips

- **Severity:** wrong answer.
- **Location:** `Localiser/Recovery/LibraryBackup.swift:178–201`; compare the ordinary packing check at `Localiser/Packing/PackingStore.swift:88–94`.
- **What happens:** An imported notebook can report the same Camera packed for two trips on the same day. The app blocks the equivalent ordinary packing operation or trip-date edit, but accepts it through restore.
- **Test:** `testRestoreDoesNotAllocateOneThingToOverlappingTrips`, in `LocaliserTests/Audit/RestorePackingConflictsTests.swift`.
- **Evidence:** The fixture first packs Camera for two nonoverlapping trips through normal operations, then changes only the second trip's serialized dates; both overlapping allocations survive restore.
- **Suggested fix:** Check active item allocations across overlapping trips before committing restored records.

### 7. Siri omits the home after a move between identical place paths

- **Severity:** wrong answer.
- **Location:** `Localiser/System/Intents.swift:111–119`.
- **What happens:** After Passport moves from Downtown's Drawer to Cottage's Drawer, Siri still says only that it is in Drawer. The person cannot tell which home's drawer to search.
- **Test:** `testSiriLocationDistinguishesIdenticalPathsInDifferentHomes`, in `LocaliserTests/Audit/IntentHomeAnswerTests.swift`.
- **Evidence:** Both homes contain Drawer; the answer after the cross-home move contains no Cottage identifier.
- **Suggested fix:** Include the item's home in location answers when several homes would make the place path ambiguous.

### 8. Voice matching ignores reversed place hierarchy

- **Severity:** wrong answer.
- **Location:** `Localiser/Voice/VoiceParser.swift:35–38,154–160`.
- **What happens:** Saying key in box on shelf in hall selects the existing Shelf inside Box inside Hall. Saving the suggestion records the opposite containment relationship from the one the person described.
- **Test:** `testVoiceDoesNotMatchAReversedPlaceHierarchy`, in `LocaliserTests/Audit/VoiceHierarchyTests.swift`.
- **Evidence:** The matching code flattens the spoken segments into a set; a local execution of the unchanged parser selected the reversed Shelf candidate.
- **Suggested fix:** Match the innermost spoken place against the candidate's own name and preserve the order of explicitly separated parent places.

### 9. Accepted backup notes prevent unrelated edits

- **Severity:** other.
- **Location:** `Localiser/Recovery/LibraryBackup.swift:167–168`; `Localiser/Data/LocaliserStore.swift:166–168`.
- **What happens:** Restore accepts notes longer than the editor's 5,000-character limit. A person who later changes only the thing's name cannot save without deleting some of those accepted notes.
- **Test:** `testRestoredNotesRemainEditableWithoutDeletingExistingText`, in `LocaliserTests/Audit/RestoreTextLimitsTests.swift`.
- **Evidence:** The fixture imports 5,001 characters of notes and then renames Camera while preserving the restored notes; `editItem` throws the length error.
- **Suggested fix:** Apply the same field limits during restore validation as during editing, or explicitly allow unchanged legacy text to remain during unrelated edits.

## Verification

- Codex ran `xcodegen generate`, a syntax check of the nine test files, and `git diff --check`, and all three passed. The required `build-for-testing` failed in its sandbox, which stops the compiler's macro helper from starting, so none of the tests had been compiled or run.
- The auditor built and ran `-only-testing:LocaliserTests/AuditCodexTests` on iOS 27 (`HB Audit 27`) and iOS 26.5 (`HB Audit`). All nine tests failed as predicted, with 12 failed assertions on each version.

## What held up in local checks

- Executed the backup envelope types from `LibraryBackup.swift:1–66` in a temporary host harness, with only the error type supplied separately: non-JSON, truncated JSON, a malformed future-version envelope, and a 209,715,201-byte input were rejected; a valid empty envelope decoded. This did not execute Core Data restore.
- Executed the unchanged voice parser with empty, whitespace-only, emoji-only, accented, right-to-left, and 50,010-character input: no crash occurred in those cases. Empty and emoji-only input returned no parse; the reversed-hierarchy defect above reproduced separately.
- Executed the unchanged search scoring code with empty, accented, emoji, right-to-left, and a 50,000-character nonmatching query in a temporary host harness with stand-in record declarations. Exact emoji and right-to-left text matched, cafe matched Café, and the long query returned no match without a crash; this did not exercise the persistent search index.
- Executed Gregorian date parsing and day arithmetic: February 30 was rejected, and subtracting a day around the March daylight-saving transition retained the intended date in Vancouver, Auckland, and Kolkata. These checks did not exercise scheduled notification delivery.
- Inspected 3,060 translated catalog values across the five catalogs for the existing integer, string, floating-point, and percent format types; found no mismatch, allowing the existing singular-number omission rule. Runtime localization and argument-position handling were not verified.

## Other reviewed paths and remaining runtime checks

- **Creation routes:** reviewed the add editor, onboarding, shelf-photo additions, Siri add, links, voice, widget buttons, and Control Center intent. The ordinary routes check counts or lead into the checked editor; archive restoration has a UI check, and moving existing records does not increase their count. Restore is the bypass reported above. No live purchase or simultaneous app/intent execution was performed.
- **Privacy:** reviewed Spotlight filtering, Siri answers and suggestions, private reminder inputs, the widget's SQL reader, in-app search, CSV, and backups. Private names are filtered from the Spotlight selection and widget SQL; private reminder name/person fields are blank. Exports deliberately include private records and the backup screen explicitly warns that files are unencrypted. The widget deliberately shows the borrower of a private thing; that existing policy was not treated as a new regression. Actual index removal, delivered notifications, widget snapshots, and system logs still need device checks.
- **Backup semantics:** reviewed type checks, inverses, duplicate IDs, dangling links, place cycles, per-attachment limits, the 100,000-record bound, staging rollback, atomic automatic-backup writes, pruning after successful writes, and the retry clock. These are source-review observations, not executed persistence, disk-full, or crash tests. No share-file extension exists in the current target configuration; the implemented external import route is the backup picker.
- **Migration:** the regression fixture models a missing copy followed by a stale readable copy; existing tests cover missing and damaged copies and interrupted-copy cleanup before the migration flag. No real process was killed during migration.
- **Links:** reviewed the fixed route parser, UUID parsing, scheme rejection, and routing into the normal editor. Extra URL components can be ignored, but the parser does not turn URL text into notebook writes; no confirmed hostile-input crash or data change was established.
- **Trips, kits, and places:** reviewed deletion, nested-place moves, duplicate-place merging, lending references, trip conflicts, return resolution, and cross-home ownership. The deletion fixture includes a nested place, a loan, a kit, and a packed trip; all persistence assertions still await the iPhone run.
- **Pro:** reviewed verified-entitlement and revocation checks, Family Sharing ownership, transaction updates, and access after lapse. Existing purchase tests skip iOS 26.5 because of the recorded local purchase-service failure; no refund, lapse, or Family Sharing behavior was exercised in this environment.
- **Concurrency:** reviewed reuse of the app's store by intents, the read-only widget, serialized main-actor mutations, history merging, and automatic-backup attempt marking before suspension. Cross-process scheduling and notification refresh races remain unverified.

For the remaining crash checks, use a disposable notebook and retain its backup: terminate during a normal save, terminate after group copy creation but before the flag is saved, terminate after fallback edits, and terminate during both insertion and final save of an erase-and-restore. After each restart, compare every record ID, relationship, selected attachment byte sequence, and active store location against the complete old or complete new snapshot; do not accept a mixed snapshot. Repeat reminder delivery checks after a timezone change, a daylight-saving transition, a backward clock change, and month-end dates. These are proposed checks, not completed experiments or additional findings.
