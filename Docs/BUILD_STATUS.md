# Localiser build status

Goal: implement the entire approved plan locally. No remote repository or publication.

| Phase | Status | Evidence still required |
| --- | --- | --- |
| 0. Project/local storage | Local implementation tested; signed iPhone installation/launch passed | Network-disabled runtime checks |
| 1. Find belongings | Local implementation tested; gate partial | Real-device capture timing and broader UI review |
| 2. Search/capture quality | Logic tests passed; gate partial | Independent quality dataset, slowest-device benchmark |
| 3. Dates/reminders | Local implementation tested; notification denial, calendar preview/cancel and date deletion UI passed | Permission revocation/actions/queue, saved calendar event and real-device long inactivity |
| 4. Scan/confirm | Local implementation tested; gate partial | Import/review UI checks, blurred real receipts, camera, no-AI physical device, cleanup review |
| 5. Pack/depart/come home | Local implementation tested; gate partial | Physical workflow review |
| 6. Private sync/recovery | Local recovery tested; private-sync configuration implemented | Signing/provisioning; two-device sync, account/storage errors and safe cloud reset/reconnection |
| 7. Integrated/purchases | Lifetime Pro tested in iOS 27's local StoreKit environment; UI review partial | Full small-screen/light/dark/large-text/VoiceOver review, denied permissions and signed-device sandbox purchases |
| 8. Beta/distribution prep | Local beta script and listing/privacy drafts prepared | Actual consented beta workflows and owner configuration; publication requires separate authorization |

No phase is complete from code inspection alone. Record exact verification commands/results and distinguish simulator evidence from physical devices and user-account operations.

## Verified October 7, 2026

- Xcode 27.0 / Swift 6.4. Dedicated empty iOS 26.5 simulator `Localiser Verification` (`15434DA2-3643-4612-B5AB-FE973104A4DD`). No remote Git configured.
- `xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO test`: **passed**, nine logic/integration tests and one UI test. Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_19-15-25--0700.xcresult`.
- Coverage includes persisted item/place retrieval, container moves, cycle/deletion safety, historical-schema migration with photos, date confirmation, independent reminder types, DST, search/ambiguity, actual Vision OCR on a generated expiry image, PDF rejection, and scan retention/counters. UI test saves by name, restarts and searches. This does not establish physical-device performance or complete feature UI coverage.
- Historical V1 storage configuration was matched by entity/property hashes before switching to bundled versioned models. Migration tests preserve its records. Current model V4 includes scan and packing records; V1/V2/V3 remain for migration compatibility.
- The initial connected-device inventory listed an iPhone 16 Pro Max as unavailable. After the user connected it via USB-C, it was paired and available on iOS 27.0.1 with Developer Mode enabled. An existing Apple Development certificate identifies team `BRLCAAM57K`. No paid developer enrollment, production signing, CloudKit provisioning, StoreKit product setup or distribution has been performed.
- `xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Device -jobs 10 CODE_SIGNING_ALLOWED=NO build`: **passed**. Explicit orientation configuration, app icon and privacy manifest are now included. The final plist was inspected: iPhone family only, configured cloud identifier and an empty signing team. AppIntents metadata extraction is skipped because that deferred feature is not present.

## Packing, recovery and purchases

- Kit rows and departure tasks are copied into independent trips. Fixed/per-night quantities, flying/international/work conditions, packed counts and manual overrides are preserved. Physical-item overlap conflicts are rejected. Home locations remain separate from trip allocations; coming home requires explicit resolution.
- Versioned JSON backup includes all eleven record types and selected photos/documents. Restore validates fields, identities, inverse relationships, dates and place cycles before staging insertion, and refuses a non-empty library. Tests cover file round trips, history/dates/trip progress, malformed files, cycles, no overwrite and reset. CSV quotes multiline text and neutralizes spreadsheet formula prefixes.
- Item deletion removes its dates/scans/movements and leaves kit/trip rows unlinked with names retained. Removing a scan original preserves confirmed dates and the successful-scan count.
- Private sync uses the same local Core Data store and remains off by default. Event/error status is based on actual container operations; a completed operation is not a claim of complete two-device consistency. Previously synced stores cannot be reset/restored through the local erase flow yet. File-restored stores cannot reconnect to cloud yet. These restrictions prevent unverified cloud deletion or duplicate-record behavior; they are unresolved Phase 6 requirements.
- Lifetime Pro uses one verified entitlement decision. Proposed free creation limits are fifty saved items, one kit and three successful scans. Editing existing records, trips, manual dates and export remain accessible without entitlement. No real product, price, purchase, Family Sharing setting or production account has been configured.
- Explicit test-plan selection of the local StoreKit file was necessary on iOS 27. The iOS 26.5 test service still reports `SKInternalErrorDomain` code 3. The two StoreKit tests now explicitly skip below iOS 27; this is not purchase proof for the minimum supported OS. See [Apple's StoreKit test-service discussion](https://developer.apple.com/forums/thread/826971).
- On iOS 27, eighteen logic/integration tests passed, including actual local purchase, restore, cancellation, network failure, pending approval and refund/revocation. The initial UI restart/search check failed because the search field was not available in its default placement. An explicit navigation drawer placement and Find selection passed the rerun. The settings test was corrected to scroll each export control into view independently.

## Final verification for this implementation stage

Baseline iOS 26.5:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO test
```

**Succeeded: nineteen passed, two StoreKit tests skipped, zero failures.** Sixteen logic/integration tests passed plus three UI tests (capture/date confirmation/relaunch/search; full kit/trip/coming-home; all tabs/settings/Pro/export controls). Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_20-24-24--0700.xcresult`. This run used the settings test before its additional large-text scrolling adjustment; that adjustment is exercised by the current-OS run below.

Current iOS 27.0, iPhone 17 Pro, dark appearance and `accessibility-extra-extra-extra-large` text:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/CurrentOS -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests -only-testing:LocaliserUITests/LocaliserUITests/testSettingsExportsAndProAreReachable test
```

**Succeeded: nineteen passed, no skips, zero failures.** Eighteen logic/integration tests plus one settings/tab/Pro/export reachability UI test. Result: `DerivedData/CurrentOS/Logs/Test/Test-Localiser-2026.10.07_20-25-56--0700.xcresult`. Earlier iOS 27 UI evidence also passed capture/date/relaunch/search and the packing cycle. Failed earlier iOS 27 runs stalled during result cleanup and were stopped; final successful bundles are the authoritative results.

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Device -jobs 10 CODE_SIGNING_ALLOWED=NO build
git diff --check
git diff --cached --check
plutil -lint Localiser/Localiser.entitlements Localiser/PrivacyInfo.xcprivacy
```

**Release build and checks passed.** The only reported final build warning is skipped AppIntents metadata for the deferred feature. Inspecting the built plist confirmed iPhone family `1`, all orientation entries, the cloud container value, an empty signing team and remote-notification background mode. Neither the unsigned binary nor simulator tests prove provisioning or live cloud behavior.

All nine successful baseline UI screenshots and all six current-OS screenshots were visually inspected. Baseline light-mode screens showed readable controls; maximum-text dark-mode screens wrapped text and required scrolling, including to reach export controls. This is a focused visual/reachability review, not a complete accessibility audit or proof that every large-text workflow works. Six unchanged screenshots are retained in `Docs/Verification/` for review; full attachments remain in the result bundles.

## Final deletion regression check

The final deletion regression check passed both selected tests with zero failures:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests/LocaliserTests/testReturnedPackedItemCanBeResolvedWithoutPuttingItBack -only-testing:LocaliserUITests/LocaliserUITests/testNameOnlyCaptureSurvivesRelaunchAndCanBeFound test
```

Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_20-32-50--0700.xcresult`. The logic test verifies that deleting a renamed item retains its current name in kit/trip rows. The UI test verifies deletion after saving, relaunching and searching, then returning to Find without rendering the deleted managed object.

## Personal iPhone installation

The user connected an iPhone 16 Pro Max on iOS 27.0.1 and authorized testing with the existing free developer account. Developer Mode was already enabled. Xcode confirmed that this Personal Team does not support iCloud or push capabilities. An empty command-line entitlement setting did not remove its inferred capability requests; an explicit empty entitlement plist did. The source entitlement file and release configuration were preserved.

```sh
python3 -c 'import plistlib; plistlib.dump({}, open("/private/tmp/localiser-personal.entitlements", "wb"))'
xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Debug -destination 'platform=iOS,id=00008140-000659260A84801C' -derivedDataPath DerivedData/PersonalDeviceLocal -jobs 10 -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=BRLCAAM57K CODE_SIGN_STYLE=Automatic CODE_SIGN_ENTITLEMENTS=/private/tmp/localiser-personal.entitlements LOCALISER_CLOUD_CONTAINER= build
xcrun devicectl device install app --device 00008140-000659260A84801C DerivedData/PersonalDeviceLocal/Build/Products/Debug-iphoneos/Localiser.app
xcrun devicectl device process launch --device 00008140-000659260A84801C dev.localiser.app
```

**Signed build, installation and launch passed.** A subsequent process inventory confirmed that Localiser remained running. The signed entitlements contain the application/team identifiers and debug permission, with no iCloud or push entitlements. The built cloud-container plist value is empty, so the app cannot offer private sync in this test build. Local notifications remain available. The provisioning profile expires October 14, 2026; rebuilding/reinstalling will be required. This is launch evidence, not a completed physical-device workflow or accessibility test. No real StoreKit product is configured, and command-line launching does not attach the simulator's local StoreKit test session.

Xcode created the Personal Team development profile required for this installation. No paid enrollment, upload, invitation or public distribution occurred.

The subsequent physical UI run was blocked before executing tests: `LocaliserUITests-Runner` could not install because the iPhone already had three apps using free development profiles (Consigliere, Localiser and Hisense Remote). `MIInstallerErrorDomain` code 13 explicitly identified this limit. No installed apps were deleted to make room. This failed run provides no physical UI-workflow evidence; it does not contradict the successful standalone installation/launch. Log: `/private/tmp/localiser-physical-ui-test.log`.

The hosted non-purchase logic tests then ran inside Localiser's existing app slot:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS,id=00008140-000659260A84801C' -derivedDataPath DerivedData/PersonalDeviceLocal -jobs 10 -parallel-testing-enabled NO -allowProvisioningUpdates DEVELOPMENT_TEAM=BRLCAAM57K CODE_SIGN_STYLE=Automatic CODE_SIGN_ENTITLEMENTS=/private/tmp/localiser-personal.entitlements LOCALISER_CLOUD_CONTAINER= -only-testing:LocaliserTests -skip-testing:LocaliserTests/LocaliserTests/testLifetimePurchaseRestoreRefundAndCreationLimitsPreserveLibrary -skip-testing:LocaliserTests/LocaliserTests/testCanceledFailedAndPendingPurchasesDoNotUnlock test
```

**Succeeded: sixteen tests passed, zero failures.** Tests exercised persistence, historical migration, place safety, search, confirmed dates/DST, actual Vision OCR on a generated printed-expiry image, PDF rejection, scan retention, packing conflicts/coming home and backup recovery on the physical iPhone. Result: `DerivedData/PersonalDeviceLocal/Logs/Test/Test-Localiser-2026.10.07_20-41-06--0700.xcresult`. The two purchase tests were deliberately excluded; this run does not establish camera capture, interactive UI, notification delivery, offline network conditions, Apple Intelligence absence or private sync. Each logic test uses its own temporary/in-memory library. Localiser was relaunched afterward without test-library arguments for normal use.

## Remaining release requirements

## Wireless installation and search performance

After the user unplugged USB and confirmed both devices were on Wi-Fi, `devicectl device info details` reported **Transport Type: localNetwork**. Installing the previously verified signed app through `devicectl device install app` succeeded, followed by successful launch and a process inventory showing Localiser running. This establishes a wireless development installation/update path for this paired phone, not an App Store distribution channel. The user authorized installing the latest verified build after autonomous completion/review, while saving human-blocked work for later. That final delivery remains separate from this successful OTA connection test.

The original optimized physical 5,000-item search benchmark missed the proposed 50 ms target (slowest samples approximately 63–77 ms). Removing repeated query normalization alone remained insufficient. Search now prepares normalized item text once on the existing library refresh path and reuses it across queries. Both Find and tests call the same ranking implementation. Tests verify fresh results after container moves, item/alias/note edits, archival and deletion. No persisted index or schema change was added.

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Release ENABLE_TESTABILITY=YES -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData/SearchSimulator -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests/LocaliserTests/testSearchPerformanceAtFiveThousandItems -only-testing:LocaliserTests/LocaliserTests/testSearchAndAmbiguousCaptureSuggestions -only-testing:LocaliserTests/LocaliserTests/testLocalPersistenceAndContainerMove test
```

**Succeeded: three tests passed, zero failures.** Result: `DerivedData/SearchSimulator/Logs/Test/Test-Localiser-2026.10.07_21-04-25--0700.xcresult`. Slowest of five measured queries: passport 23.07 ms; travel id 25.80 ms; passprt 22.57 ms; drawr 28.22 ms; potato 25.65 ms. The fixture contains 5,000 records, 250 archived records, nested places, aliases and notes. These measurements cover query matching/ranking, not row rendering, initial text preparation or an independent quality dataset. Release tests enforce the 50 ms target; Debug tests check correctness and report timing without enforcing an optimized-build budget.

The final optimized physical run could not start because the phone locked; Xcode explicitly requested an unlock. The waiting test process was stopped, not reported as passed. Final physical timing and slower-supported-device coverage are human-blocked, documented in HUMAN_BLOCKED.md.

The normal Find UI workflow also passed after this change using `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testNameOnlyCaptureSurvivesRelaunchAndCanBeFound test`: one test, zero failures. Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_21-05-41--0700.xcresult`. It exercised capture, confirmed dates with denied notifications, calendar cancellation, date deletion, relaunch/search and item deletion through the prepared search data.

The date workflow UI test was extended to open Apple's calendar editor, verify the generic event title, cancel with the system's Discard Changes confirmation, delete the date, relaunch/search and delete the item. The final test uses ordinary named controls; temporary coordinate taps and the unproven app dismissal change were removed. Earlier failures skipped the calendar discard confirmation and do not establish an app dismissal defect.

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testNameOnlyCaptureSurvivesRelaunchAndCanBeFound test
```

**Succeeded: one extended UI test passed, zero failures.** Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_20-49-43--0700.xcresult`. The calendar-preview screenshot was inspected: generic title, all-day event and the confirmed date. No broad calendar-access request appeared. This verifies preview/cancellation and date deletion in iOS 26.5, not saving an event to a real calendar or physical-device calendar behavior. The existing application code is unchanged.

The same workflow now starts by declining notification permission (or verifying an already-denied state on reruns). It asserts the notification-settings link, then saves an item and confirmed date and completes calendar cancellation, date deletion, relaunch/search and item deletion. An initial test locator expected a standalone permission text element; the final test uses the actual Settings link, which is conditional on denied permission. No application code changed.

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testNameOnlyCaptureSurvivesRelaunchAndCanBeFound test
```

**Succeeded: one extended UI test passed, zero failures.** Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_20-54-15--0700.xcresult`. The actual denial occurred in the preceding run through SpringBoard's Don't Allow button; the final run verified its persisted state. The successful screenshot was inspected and visibly shows Disabled in Settings and Open notification settings. This establishes a usable manual-date workflow with denied permission, not permission revocation, scheduling a populated queue, delivery/actions or physical-device notification behavior.

See BETA_AND_RELEASE.md for the beta workflow, listing/policy drafts and physical test matrix. No real-user beta, live iCloud operation, production StoreKit setup, developer enrollment, upload, invitation or public release has occurred. Commercial demand and launch timing remain unverified. The full launch combination has not been reduced.

## Continued accessibility and system reminder verification

The full XCTest accessibility audit initially reported 38 findings on the iPhone SE (3rd generation), iOS 26.5. Direct screenshot inspection confirmed truncation of the Places empty-state title and low-contrast explanatory labels. The shared empty-state label now wraps, and secondary text uses an opaque colour for light/dark appearance. The search placeholder is shorter, and the tested closed-date/close/done toolbar controls use labelled icons.

After the first wrapping/colour changes, the same audit reported 22 findings. A subsequent run with the toolbar changes reported seven findings, but the text-size setting was applied after initial launch: its tab screenshots do not establish maximum-text behaviour. Its Pro/settings screenshots do show large wrapping text. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_21-24-27--0700.xcresult`. These are **failed audits**, not passing accessibility results. The remaining contrast/Dynamic Type/clipping findings require individual verification; none has been suppressed. An iOS 27 audit reported ten findings and stalled in result cleanup; its command was terminated after the test suite ended. Its unfinished bundle is not authoritative passing evidence.

Apple explains that audits can produce false positives and that assistive-technology testing remains necessary: [Apple accessibility audit guidance](https://developer.apple.com/videos/play/wwdc2023/10035/). An [Apple engineer response](https://developer.apple.com/forums/thread/823968) also discusses reported Inspector Dynamic Type issues when text visibly scales. These sources do not establish that any particular Localiser finding is false.

Actual system notification requests are now exercised by the existing unit/integration target on disposable simulators. The new check requests quiet permission only if it is available; physical devices are skipped, and denied simulator permission is not changed. It verifies 50 scheduled requests out of 70 candidates, the exact earliest-request identifiers, generic content without sensitive document details, local-time calendar triggers, preservation of an unrelated request, replacement after editing, deletion, return categories, keeping versus warranty reminders, and cancellation after returning an item.

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Debug -destination 'platform=iOS Simulator,id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/CurrentOS -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test
```

**Succeeded: twenty tests passed, zero failures and no skips.** Result: `DerivedData/CurrentOS/Logs/Test/Test-Localiser-2026.10.07_21-27-40--0700.xcresult`. This includes the extended actual-queue test and both local StoreKit tests. It does not prove physical notification delivery/action handling after long inactivity.

The first maximum-text small-screen capture/packing run failed because the UI tests attempted to tap controls below the visible area. The existing tests now scroll to the necessary controls. Verification is still in progress. Private-sync unavailable copy was also corrected: this personal build has a signing team but lacks private-cloud configuration.

The corrected capture/date test passed on the iPhone SE simulator with `accessibility-extra-extra-extra-large` set and read back before app launch. It exercised denied notification settings, capture, date confirmation, calendar cancellation, date deletion, relaunch/search and item deletion. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_21-35-29--0700.xcresult`. That two-test run was **overall failed**, because packing's test could not position a departure switch; it is not a passing packing result. The test now asserts departure switch values and the away state, stops on unexpected alerts, and uses smaller gestures when positioning a visible control. The date-row layout also now uses native adaptable `LabeledContent` rather than squeezing both labels into a horizontal row at accessibility text sizes.

The focused packing rerun passed: one test, zero failures, 127.656 seconds. Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Debug -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testKitTripPackingAndComingHome test`. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_21-41-12--0700.xcresult`. It verified kit creation, a free-text row, a derived trip, packing, all three departure switches, away, coming home, unpacked and finished on the smallest screen at maximum text size.

Later typography audits still failed: six contrast findings in `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_21-45-51--0700.xcresult` and again with categories run separately in `Test-Localiser-2026.10.07_21-49-12--0700.xcresult`. A scrolling/filter experiment did not establish reliable results and was removed. The permanent settings reachability test now checks element detection, hit regions, sufficient descriptions and traits. It does not run contrast, Dynamic Type or clipping categories, and does not establish a passing full accessibility audit. The failed diagnostics remain evidence for individual review; no issue handler or suppression is present. Physical VoiceOver and remaining visual/typography checks remain distinct requirements.

## Photo scan workflow and crash correction

The new simulator flow selects the documented synthetic printed-expiry photo through Apple's picker, performs actual Vision OCR, selects `2028-07-14`, creates an item, verifies Save is disabled before confirmation and original retention is off, confirms the date, saves, and opens the date-only scan. Initial test attempts needed picker loading/onboarding and large-text scrolling corrections. The first complete save attempt then exposed an application crash in UIKit's collection-view first-responder rebasing during dismissal (`Test-Localiser-2026.10.07_22-11-00--0700.xcresult`). The scan name field now relinquishes focus before opening the final review, preventing the rows from being removed while that field remains focused.

The same full flow passed after the focus correction: one test, zero failures, 72.179 seconds, on iPhone SE, iOS 26.5, maximum accessibility text. Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Debug -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testPhotoScanNeedsConfirmationAndKeepsDateOnlyRecord test`. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_22-14-57--0700.xcresult`. Its date-only screenshot was visually inspected. The date-only screen subsequently adopted the existing shared wrapping/opaque-secondary empty state; final regression verification of that visual adjustment remains pending.

Xcode prunes old result bundles in a DerivedData directory as new runs are added. Earlier paths above identify historical runs and may no longer exist; recorded results and exported review images must not be confused with currently retained bundles. Preserve the final run summaries and selected screenshots for the final handoff.

## File-provider recovery workflow

The settings test passed structural accessibility checks (element detection, hit regions, descriptions and traits), with all six iPhone SE maximum-text screenshots visually inspected: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_22-16-36--0700.xcresult`. Labels wrap and require scrolling; some screenshots intentionally show text partially under native navigation/tab overlays. They are viewport captures, not proof of every offscreen label's contrast. A later exporter-ready run passed at `Test-Localiser-2026.10.07_22-18-25--0700.xcresult`.

The dedicated recovery UI test now saves a synthetic item, exports actual JSON under a verified unique filename, launches a separate empty test library, selects that file from Recents, verifies the one-record restore confirmation, restores, and checks the item after another relaunch. It does not erase or replace the owner's library or any existing export. The full flow **passed** at default text size on iPhone SE / iOS 26.5: one test, zero failures, 42.182 seconds. Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Debug -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testBackupExportsAndRestoresIntoFreshLibrary test`. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_22-48-55--0700.xcresult`.

At maximum text size, the initial system export dialog did not expose `DOCPicker.filenameTextField`; the unique-filename test stopped before writing anything. Default size exposed the field and completed export/restore. This remains a system-dialog layout/automation finding to investigate, not a passing maximum-text file round trip. Application settings/export buttons were reachable at maximum text size. The application export implementation did not change during this verification.

The subsequent full baseline run was **failed**, with 21 passes, three explicit skips and one failure: photo scanning's test could not reach Create item while the keyboard covered the control at default text size. All seventeen runnable logic tests and the other four UI workflows passed. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_22-50-55--0700.xcresult`. The two local StoreKit cases skip on iOS 26.5; the system notification test skips on this already-denied simulator. The scan name field now offers Done and relinquishes focus on submission. The updated complete photo workflow passed at default size: one test, zero failures, 39.933 seconds, `Test-Localiser-2026.10.07_22-56-32--0700.xcresult`. The test subsequently added an explicit assertion for the saved `Jul 14, 2028` value; final regression verification remains pending.

All twenty logic/integration tests on iOS 27 passed with zero skips/failures after the scan Done change, including both local StoreKit cases and actual notification scheduling/cancellation. Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Debug -destination 'platform=iOS Simulator,id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/CurrentOS -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test`. Result: `DerivedData/CurrentOS/Logs/Test/Test-Localiser-2026.10.07_22-56-30--0700.xcresult`, 7.723 seconds for the suite. This is separate from the failed baseline UI run.

The optimized unsigned app build also passed: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData/ReleaseFinal -jobs 10 CODE_SIGNING_ALLOWED=NO build`. Built-plist/privacy inspection confirmed iPhone/iOS 26, declared orientations, no signing team, the configured cloud-container identifier, and the app-private UserDefaults reason. Neither the local StoreKit fixture nor printed-expiry verification fixture was bundled. The only build warning was skipped deferred AppIntents metadata. This build predates the final Done/warning-colour adjustments and must be rebuilt for final delivery.

Three ambiguity/archived packing warnings now use the existing theme with a darker light-mode colour and light amber in dark mode. Solid-source contrast calculations are 6.92:1 against white and 10.84:1 against dark ground. These calculations do not replace rendered accessibility checks. The independent capture/search evaluation protocol is now recorded in BETA_AND_RELEASE.md; its targets are not achieved holdout results.

## Latest reviewed build and delivery attempt

The saved-date assertion was corrected to the observed native accessibility label `Expiry, Jul 14, 2028`; no date logic changed. The full corrected iPhone SE / iOS 26.5 UI run passed all five workflows, zero failures/skips, 225.150 seconds:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -only-testing:LocaliserUITests test
```

Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_23-09-06--0700.xcresult`. Its machine-readable summary is preserved in `Docs/Verification/Final-small-screen-default-summary.json`. Selected date-only scan and restored-library screenshots are preserved beside it. Direct visual review also covered Places wrapping, Pro, export settings and the completed packing screen. This run establishes default-size light-mode UI behaviour, not full typography/VoiceOver clearance.

The unsigned Release rebuild including the final scan Done and warning-colour adjustments succeeded (`/private/tmp/localiser-release-final-reviewed-build.log`). Final signed Release compilation then reached code signing using the existing Personal Team:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Release -destination 'platform=iOS,id=00008140-000659260A84801C' -derivedDataPath DerivedData/PersonalDeviceFinal -jobs 10 -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=BRLCAAM57K CODE_SIGN_STYLE=Automatic CODE_SIGN_ENTITLEMENTS=/private/tmp/localiser-personal.entitlements LOCALISER_CLOUD_CONTAINER= build
```

The live codesign process and macOS SecurityAgent waited while computer-use inspection explicitly reported the Mac locked. The signing process was stopped; the command therefore finished **failed at CodeSign**, not successfully signed. Log: `/private/tmp/localiser-final-signed-release.log`. No lock protection was bypassed and no password was obtained. Unlock/native signing authorization is saved in HUMAN_BLOCKED.md. Do not install the partially signed output. The latest reviewed build has not yet been delivered.

Immediately before this attempt, `xcrun devicectl device info details --device 00008140-000659260A84801C --timeout 20` again confirmed paired/connected **localNetwork** transport. That connection evidence and the earlier successful wireless installation remain distinct from final delivery. After successful signing, use `xcrun devicectl device install app --device 00008140-000659260A84801C --timeout 45 DerivedData/PersonalDeviceFinal/Build/Products/Release-iphoneos/Localiser.app`, then launch/read back if the phone permits it.

## Final large-text and native-provider checks

With iPhone SE text size set and read back before launch as `accessibility-extra-extra-extra-large`, all four selected UI tests passed, zero failures/skips, 350.884 seconds:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests -skip-testing:LocaliserUITests/LocaliserUITests/testBackupExportsAndRestoresIntoFreshLibrary test
```

Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_23-13-25--0700.xcresult`; summary preserved in `Docs/Verification/Final-small-screen-max-summary.json`. Packing, capture/calendar, confirmed photo scanning and settings/structural audit passed. Latest date-only scan, confirmed-date layout, Places and Pro screenshots were reviewed: text wraps, and large screens require scrolling past native overlays. This remains separate from the unresolved full native typography audit and physical VoiceOver.

The initial current-iOS dark/default-text five-flow run failed two checks and stalled after its suite during result cleanup. Its command was stopped; its incomplete bundle is not passing evidence (`/private/tmp/localiser-final-current-dark-ui.log`). Direct hierarchy inspection established that iOS 27 reports the notification-settings control as a Link, its calendar title field as `title-field`, and cancels an unchanged calendar preview without the iOS 26 discard confirmation. Existing tests now match those actual controls and assert that cancellation returns to the deadline screen; application date/notification/calendar code did not change.

The native exporter investigation also removed the incorrect requirement that a filename field must be exposed. The recovery test creates a uniquely named synthetic destination folder using More > New Folder, then saves the app's default filename. No previous file is replaced. iOS 27 / dark / maximum text completed actual export, import into an empty library, confirmation and relaunch successfully: one test, zero failures/skips, 91.951 seconds. Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/CurrentOS -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testBackupExportsAndRestoresIntoFreshLibrary test`. Result: `DerivedData/CurrentOS/Logs/Test/Test-Localiser-2026.10.07_23-21-15--0700.xcresult`; summary preserved in `Docs/Verification/Final-current-max-recovery-summary.json`. Earlier folder-selection locator experiments failed and were removed; they do not establish a defective application export implementation. Smallest-screen recovery and the corrected full current-OS UI rerun remain pending.

The existing OCR test now verifies a supported image-only PDF through PDFKit/Vision, exact expiry candidate, PDF MIME/original data and preview, as well as malformed/eleven-page rejection. Focused verification passed, one test, zero failures/skips, 1.795 seconds: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData/FinalOCR -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests/LocaliserTests/testOnDeviceOCRReadsPrintedExpiryAndPDFLimits test`. Result: `DerivedData/FinalOCR/Logs/Test/Test-Localiser-2026.10.07_23-19-46--0700.xcresult`; summary preserved in `Docs/Verification/Final-valid-pdf-summary.json`. This proves the document-reading path, not physical camera operation or the entire native PDF-selection UI.

## Final regression results

The corrected current-iOS dark/default-text run passed all five UI workflows, zero failures/skips, 225.218 seconds: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=795B0913-F0A1-4316-A268-4DAC0EE9189D' -derivedDataPath DerivedData/FinalCurrentUI -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests test`. Result: `DerivedData/FinalCurrentUI/Logs/Test/Test-Localiser-2026.10.07_23-24-44--0700.xcresult`; preserved summary `Docs/Verification/Final-current-dark-ui-summary.json`. Latest dark-mode date-only scan, Places and Pro screenshots were inspected and readable.

Smallest-screen, maximum-text recovery also passed: one test, zero failures/skips, 82.984 seconds: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/SmallScreen -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testBackupExportsAndRestoresIntoFreshLibrary test`. Result: `DerivedData/SmallScreen/Logs/Test/Test-Localiser-2026.10.07_23-24-06--0700.xcresult`; summary `Docs/Verification/Final-small-screen-max-recovery-summary.json`. All five UI workflows now have passing maximum-text small-screen evidence across the four-flow run and focused recovery run. The missing filename field is no longer an unresolved export/restore finding; default save within a new folder completed the actual round trip.

The final current-OS logic/integration suite, including the added valid-PDF check, passed all twenty tests with zero failures/skips, 9.755 seconds: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/FinalCurrentUnits -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test`. Result: `DerivedData/FinalCurrentUnits/Logs/Test/Test-Localiser-2026.10.07_23-25-26--0700.xcresult`; summary `Docs/Verification/Final-current-units-summary.json`. These checks include local StoreKit, actual notification queue changes, valid PDF/image OCR, migration, search, recovery and packing safety. They do not replace the owner-dependent public-release gates.

## October 8 wireless delivery

The Mac became accessible again; retrying the same signed Release build succeeded without a password request. The first strict signature inspection found a missing sealed `Localiser.cstemp` left by the interrupted overnight codesign attempt. The first installation had already been accepted by iOS, but it was not counted as validated delivery. A normal `xcodebuild ... clean build` with the same final signing arguments removed the generated temporary resource at its source. No application code, owner data, signing permissions or lock protections changed. Log: `/private/tmp/localiser-final-signed-release-clean.log`.

The clean build passed `codesign --verify --deep --strict --verbose=4 DerivedData/PersonalDeviceFinal/Build/Products/Release-iphoneos/Localiser.app`: **valid on disk; satisfies its Designated Requirement**. No `.cstemp` remained. Final executable SHA-256: `244f79ba4ad29faad3887cd9eed99e743dd92702d08a8acf3e30fa321711b989`. Built metadata: `dev.localiser.app`, version 1.0/build 1, team BRLCAAM57K, empty cloud container. Entitlements contain the application/team identifiers and development debug permission, with no iCloud/push capability.

`devicectl device info details` again reported paired/connected **localNetwork** transport. `xcrun devicectl device install app --device 00008140-000659260A84801C --timeout 45 DerivedData/PersonalDeviceFinal/Build/Products/Release-iphoneos/Localiser.app` **succeeded**; installed bundle URL ended in `9EA0D7BD-92F7-4155-BF77-AD9ABA4B0B96/Localiser.app`. `xcrun devicectl device process launch --device 00008140-000659260A84801C --timeout 20 dev.localiser.app` **succeeded**. Process inventory confirmed PID 33384 from that exact installed bundle. This establishes delivery and launch of the latest clean reviewed Release build over Wi-Fi. It is a free-team development installation, not App Store distribution or completed physical workflow/accessibility validation. The earlier locked-Mac signing/final-delivery blocker is resolved.

Because launch became available, the focused optimized physical search benchmark is being retried. Its test-host installation will be followed by reinstalling/relaunching the same normal signature-verified Release app; benchmark result and final readback are still pending.


## Final unlocked physical benchmark and normal app restoration

After the owner unlocked the iPhone, the optimized hosted benchmark passed: one test, zero failures, 0.825 seconds. The earlier locked-phone retry was stopped (exit 143) and supplied no timing evidence. Final command:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -configuration Release ENABLE_TESTABILITY=YES -destination 'platform=iOS,id=00008140-000659260A84801C' -derivedDataPath DerivedData/PersonalDeviceBenchmark -jobs 10 -parallel-testing-enabled NO -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=BRLCAAM57K CODE_SIGN_STYLE=Automatic CODE_SIGN_ENTITLEMENTS=/private/tmp/localiser-personal.entitlements LOCALISER_CLOUD_CONTAINER= -only-testing:LocaliserTests/LocaliserTests/testSearchPerformanceAtFiveThousandItems test
```

Log: `/private/tmp/localiser-final-physical-search-unlocked.log`; result: `DerivedData/PersonalDeviceBenchmark/Logs/Test/Test-Localiser-2026.10.08_08-13-49--0700.xcresult`; retained summary: `Docs/Verification/Final-physical-search-summary.json`.

At 5,000 items, the slowest of five measurements for each query was: passport 21.166333 ms; travel id 23.840208 ms; passprt 20.954 ms; drawr 25.483459 ms; potato 23.462083 ms. All passed the existing 50 ms acceptance threshold on iPhone 16 Pro Max / iOS 27.0.1. This is not evidence for slower supported phones or independent search quality.

After testing, installation of the same strict-signature-verified normal Release app succeeded again using the install command above. Final installed bundle: `1EBABC45-299C-4225-B8B8-8C5FB9F634D3/Localiser.app`. The normal launch command succeeded; separate device process readback confirmed PID 33471 from that exact bundle. The test-host build is no longer the delivered app. No password was needed. The final implementation audit and owner handoff are in COMPLETION_AUDIT.md and HUMAN_BLOCKED.md. Full native accessibility findings and owner-dependent release gates remain explicitly unverified.


## October 8 focused full typography audit

Added `testTypographyAccessibilityOnLaunchTabs` to the existing UI test target to reproduce the unresolved typography checks separately from the structural/reachability checks. Production code and the delivered normal Release app are unchanged. Before launch, simulator text size was set and read back as `accessibility-extra-extra-extra-large`, with light appearance on iPhone SE / iOS 26.5.

Command: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/TypographyAudit -resultBundlePath /private/tmp/Localiser-typography-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testTypographyAccessibilityOnLaunchTabs test`.

Result: **failed**, one test, four contrast issues, 21.671 seconds. No Dynamic Type or text-clipping failures were reported in this focused four-tab run. This does not clear earlier findings on other screens. After the suite ended, Xcode's specific `simctl diagnose` collector remained live; only that collector was terminated. Xcode then finalized a readable bundle and returned exit 65. Summary retained in `Docs/Verification/Typography-small-screen-max-summary.json`; four screenshots retained in `Docs/Verification/Typography-20261008/`. Full exported attachments: `/private/tmp/localiser-typography-20261008-attachments`.

Individual review: Find reported its explanatory empty-state paragraph, Places its explanatory paragraph, Due soon the queue-count sentence, and Packing an unavailable SwiftUI accessibility node. All four viewport screenshots show lower content behind the native floating tab bar at this text size. Three element screenshots include below-viewport/black areas; the Packing node could not be resolved during audit. The descriptions contain only “Contrast failed for SwiftUI.AccessibilityNode”. These observations identify the reported context; they are not sufficient to label all findings false or establish complete accessible use. No audit issue handler, expected failure, clipping filter or suppression was added. The full typography test remains a failing gate requiring further review; the earlier passing functional suites retain their narrower scope.
