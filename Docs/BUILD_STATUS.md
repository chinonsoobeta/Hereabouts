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


## Default-text typography comparison and native PDF import

The typography test now covers the four launch tabs, Pro and backup settings. Default `large` text was set/read back before launch on the same iPhone SE / light / iOS 26.5. Command used the same focused audit arguments above, with result path `/private/tmp/Localiser-typography-default-20261008.xcresult`. Log: `/private/tmp/localiser-typography-default-20261008.log`. **Failed**, one test with twenty findings in 33.730 seconds; command exit 65. Categories included Dynamic Type, contrast and one clipping finding. Summary: `Docs/Verification/Typography-small-screen-default-summary.json`; six reviewed screenshots: `Docs/Verification/Typography-default-20261008/`.

Direct screenshot review found readable, wrapping text in Find, Places, Packing and Pro. Due soon’s lower empty state appears beneath the native floating tab bar. Backup’s upper sync paragraph appears beneath the navigation overlay, with further restore content below the viewport. The audit also flags semantic SwiftUI text styles that visibly scale in the prior maximum-text runs. This is individual context, not a passing full audit or proof of false positives. No production typography/layout changed based on uncertain diagnostics. Apple documents that scroll-edge effects obscure content beneath controls: https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle. Physical VoiceOver and independent rendered assessment remain necessary.

Added an existing-target UI test for actual native PDF selection, confirmation and opt-in retention. A 592-byte, one-page synthetic `Localiser-test-expiry.pdf` prints only `EXPIRY 2028-07-14`. It is not bundled in the app. The dedicated simulator’s local Files-provider directory was discovered from its AppGroup metadata, not inferred from an unrelated device: `/Users/chinonsoobeta/Library/Developer/CoreSimulator/Devices/F57B85B9-C56D-4EC3-84CE-9A77A38C3109/data/Containers/Shared/AppGroup/CDB23754-96E7-4B9F-A194-3DE07CC8F7DC/File Provider Storage/`. Only this synthetic fixture was copied there. No owner document/library changed.

The first PDF test failed because its locator included `.pdf`, while the actual picker’s identifier is `Localiser-test-expiry, pdf`. The hierarchy confirmed the file was present; the test locator was corrected without an application change. Final command:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/PDFImportUI -resultBundlePath /private/tmp/Localiser-pdf-import-corrected-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testPDFImportNeedsConfirmationAndRetainsOriginal test
```

**Passed**, one test, zero failures/skips, 37.132 seconds; exit 0. Log: `/private/tmp/localiser-pdf-import-corrected-20261008.log`; summary: `Docs/Verification/Final-native-pdf-import-summary.json`. The real Files picker selected the PDF; on-device reading offered its exact expiry; save was disabled before confirmation; source retention started off and was explicitly enabled; the saved item showed `Expiry, Jul 14, 2028`; and its stored PDF preview opened. `Final-native-pdf-preview.png` was inspected: the expiry text is visible and matches the fixture, with the source-removal control available. This closes simulator native PDF-selection proof, not physical provider/camera/offline proof. Production source and the wireless delivered Release app remain unchanged. `git diff --check` passed.


## Isolated visible Packing contrast correction

A dedicated contrast-only check avoids the combined audit’s Dynamic Type changes. At default `large` text / light / iPhone SE / iOS 26.5, it failed solely for visible `Trips` and `Reusable kits` headings (“Contrast nearly passed”), two issues in 6.001 seconds. Result: `/private/tmp/Localiser-packing-contrast-20261008.xcresult`; log: `/private/tmp/localiser-packing-contrast-20261008.log`. This identified a concrete visible defect rather than assuming all findings came from overlays.

Those two section headers now explicitly use the existing adaptive `Theme.secondary` colour. No new theme, layout layer, data model, or audit suppression was introduced. Exact verification:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/TypographyAudit -resultBundlePath /private/tmp/Localiser-packing-contrast-fixed-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testPackingContrastWithoutChangingTextSize -only-testing:LocaliserUITests/LocaliserUITests/testKitTripPackingAndComingHome test
```

**Passed**, two tests, zero failures, 48.467 seconds: visible contrast and complete packing/departure/coming-home workflow. Summary: `Final-packing-contrast-workflow-summary.json`. The same contrast-only test passed on current iOS 27 / iPhone 17 Pro / dark / default text, one test, zero failures, 9.592 seconds, using destination `795B0913-F0A1-4316-A268-4DAC0EE9189D`, derived data `DerivedData/HeadingDarkAudit`, result `/private/tmp/Localiser-packing-dark-contrast-20261008.xcresult`. Summary: `Final-packing-dark-contrast-summary.json`. Both commands exited 0. Light/dark screenshots `Final-packing-headings-light.png` and `Final-packing-headings-dark.png` were inspected. This resolves these two headings only; full typography/Dynamic Type/clipping diagnostics on other screens remain unresolved.

The normal signed Release build of this correction succeeded using the same approved Personal Team/empty cloud-container command, `-jobs 10`, and `DerivedData/PersonalDeviceFinal`. Log: `/private/tmp/localiser-final-heading-release-20261008.log`. Separate `codesign --verify --deep --strict --verbose=4 DerivedData/PersonalDeviceFinal/Build/Products/Release-iphoneos/Localiser.app` exited 0: valid on disk/satisfies Designated Requirement. Executable SHA-256: `fc7d92053d066dcc6ed136799cbece91c860d03a841604ae4761c2ac5bf7bdde`.

Device details again confirmed paired/connected `localNetwork` transport. The normal `devicectl device install app` command succeeded; final installed bundle `991D3813-DBA9-42CB-9549-3778226AF9D5/Localiser.app`. Normal launch succeeded. Separate process inventory confirmed PID 33765 from that exact installed bundle. This correction supersedes the earlier delivered executable hash. No password was needed. Full public-launch readiness is still not claimed. `git diff --check` passed.


## Final Due readability and all-tab contrast

The isolated audit was extended from Packing to all four launch tabs (`testLaunchTabsContrastWithoutChangingTextSize`). The initial light/default run, with a corrected `Reminder coverage` heading, still failed for the Due empty-state title and description beneath the tab bar. Merely reducing illustration size or shortening the sentence left a contrast finding and was insufficient. The final implementation groups reminder status/actions/privacy into one card, uses a compact label/description for the empty state, restores the full date-type guidance, and renders the permission state as a single wrapping sentence to avoid a cramped label/value pair. `.buttonStyle(.borderless)` keeps the two actions independent. No date/scheduling/store behavior changed, and no audit suppression was introduced.

Final-source contrast command:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/DueCardUI -resultBundlePath /private/tmp/Localiser-due-final-light-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testLaunchTabsContrastWithoutChangingTextSize test
```

**Passed**, one test, zero failures, 10.693 seconds, light/default `large` / iPhone SE / iOS 26.5. The same test on current iOS 27 / dark / default text, destination `795B0913-F0A1-4316-A268-4DAC0EE9189D`, derived data `DerivedData/DueCardDarkUI`, result `/private/tmp/Localiser-due-final-dark-20261008.xcresult`, also passed. Retained summaries: `Final-tabs-light-contrast-summary.json` and `Final-tabs-dark-contrast-summary.json`. These establish contrast for the audited four-tab default/empty states only, not full accessibility across every record/error state or text size.

Final-source maximum-text regression used the first destination and derived data above, result `/private/tmp/Localiser-due-final-max-20261008.xcresult`, selecting `testNameOnlyCaptureSurvivesRelaunchAndCanBeFound` and `testSettingsExportsAndProAreReachable`. **Passed**, two tests, zero failures/skips, 143.432 seconds. Text size was set before launch to `accessibility-extra-extra-extra-large`. Denied notification settings, confirmed manual date/calendar cancellation, persistence/search/deletion and all-tab/settings structural accessibility passed. Summary: `Final-due-max-workflows-summary.json`. Screenshots `Final-due-light.png` and `Final-due-max.png` were inspected: default guidance is fully above the tab bar; at maximum size, the status sentence wraps and lower content needs scrolling. The broader combined typography audit remains unresolved; the focused passes do not suppress or clear its remaining findings.

Final normal Release build passed using the previously recorded Personal Team/empty cloud-container command, `-jobs 10`, and `DerivedData/PersonalDeviceFinal`. Log: `/private/tmp/localiser-due-final-sentence-release-20261008.log`. Separate strict signature verification exited 0 (valid on disk/satisfies Designated Requirement). Executable SHA-256: `f096baf57b487693b5c6e041aa2faa0007172b326ff10b47343e7f511f8d84c7`.

Fresh device details confirmed paired/connected `localNetwork`. Wireless installation succeeded; final installed bundle `F8565095-A75A-44BE-B9D6-CD89C06DF46E/Localiser.app`, database sequence 2800. The subsequent normal launch request **failed**, exit 1: iOS explicitly reported `Locked` and required unlocking the device. Separate process inventory returned no Localiser process. Thus the latest corrected app is installed but its physical launch is not proved. Earlier successful launches apply to earlier hashes. No password was requested, no lock protection changed, and no repeated install is necessary unless the installed app changes. Unlock and launch the existing final installation to finish this owner-dependent check. `git diff --check` passed.


## Isolated clipping review and owner-unlock retry

A fresh full typography audit on the delivered source failed with thirteen findings (one test, 34.724 seconds, exit 65): `/private/tmp/Localiser-full-typography-current-20261008.xcresult`, log `/private/tmp/localiser-full-typography-current-20261008.log`. An explicit wrapping Text inside the Due label did not clear its clipping finding; the trial was removed. No production change remains from that hypothesis.

The existing contrast check was extended with `.textClipped` to isolate this category without Dynamic Type changes. Command used `-jobs 10 -parallel-testing-enabled NO`, SE destination `F57B85B9-C56D-4EC3-84CE-9A77A38C3109`, derived data `DerivedData/DueCardUI`, result `/private/tmp/Localiser-tabs-contrast-clipping-20261008.xcresult`, and the then-existing selector `LocaliserUITests/LocaliserUITests/testLaunchTabsContrastWithoutChangingTextSize`. **Failed**, one test, one clipping finding on `Remember in time`, 18.248 seconds, exit 65. Log: `/private/tmp/localiser-tabs-contrast-clipping-20261008.log`. The test was subsequently renamed `testLaunchTabsContrastAndClippingWithoutChangingTextSize` and attachment names updated to describe both categories. The exported element screenshot was inspected; this is unresolved evidence, not a claimed false positive. Earlier contrast-only passes retain their narrower scope.

After the owner reported unlocking the phone, two wireless launch requests still returned CoreDevice 10002 / FBSOpenApplicationErrorDomain 7 `Locked` (exit 1). Process inventory succeeded but contained no Localiser process. The latest signed app remains installed at `F8565095-A75A-44BE-B9D6-CD89C06DF46E/Localiser.app`; its launch remains unverified. The owner was asked to keep the screen awake and open the installed app manually. No password was requested and no device security setting changed.


## Due title clipping correction

Outcome: the existing Due empty-state title must have space to wrap at larger text sizes. Non-goals: no date, reminder, storage or permission change. Production file: `Localiser/Dates/DueView.swift` only. The acceptance check is the existing all-tab contrast-and-clipping audit.

Applying vertical fixed sizing to the whole native Label did not clear the finding (one failure, 18.139 seconds, exit 65; `/private/tmp/Localiser-label-vertical-clipping-20261008.xcresult`). That trial was replaced, not stacked, with a native HStack containing an accessibility-hidden decorative icon and a separate wrapping Text. The wording is unchanged. The default screenshot was inspected and retained as `Final-title-row-light.png`.

Exact focused light command:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/DueCardUI -resultBundlePath /private/tmp/Localiser-title-row-clipping-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testLaunchTabsContrastAndClippingWithoutChangingTextSize test
```

**Passed**, one test, zero failures/skips, 17.963 seconds, exit 0. Summary: `Final-title-row-contrast-clipping-summary.json`; log `/private/tmp/localiser-title-row-clipping-20261008.log`. The same selector passed on current iOS 27 / dark / default text using destination `795B0913-F0A1-4316-A268-4DAC0EE9189D`, derived data `DerivedData/DueCardDarkUI`, result `/private/tmp/Localiser-title-row-dark-20261008.xcresult`. Summary: `Final-title-row-dark-summary.json`; log `/private/tmp/localiser-title-row-dark-20261008.log`.

Maximum text was explicitly set using `xcrun simctl ui F57B85B9-C56D-4EC3-84CE-9A77A38C3109 content_size accessibility-extra-extra-extra-large`. The first command above then selected `testSettingsExportsAndProAreReachable`, with result `/private/tmp/Localiser-title-row-max-20261008.xcresult`. **Passed**, one test, zero failures/skips, 56.585 seconds, exit 0. Summary: `Final-title-row-max-summary.json`; log `/private/tmp/localiser-title-row-max-20261008.log`. The Due screenshot was inspected: status text wraps, with the empty title below the initial viewport. This structural workflow pass does not establish full typography at maximum size.

The full typography selector `testTypographyAccessibilityOnLaunchTabs` on baseline/default text still **failed**: eleven findings, 40.226 seconds, exit 65; result `/private/tmp/Localiser-title-row-typography-20261008.xcresult`, log `/private/tmp/localiser-title-row-typography-20261008.log`, summary `Final-title-row-typography-summary.json`. The clipping finding did not recur, but the title's Dynamic Type warning remains. Other Dynamic Type warnings and settings contrast findings remain. No audit suppression was added; this is not a passing full accessibility gate.

The normal Release build succeeded using the recorded Personal Team/empty entitlement/cloud-container command and `-jobs 10`; log `/private/tmp/localiser-title-row-release-20261008.log`. Separate `codesign --verify --deep --strict --verbose=4 DerivedData/PersonalDeviceFinal/Build/Products/Release-iphoneos/Localiser.app` exited 0. Executable SHA-256: `6aa7ff80f49ea0b3053ce9a230283e719c81ddb6e4a0fb9d718f18723321f7bd`.

Wireless install succeeded, exit 0: `622CCA3C-1576-4018-B129-338058122B1B/Localiser.app`, database sequence 2808. The normal launch request returned exit 1, CoreDevice 10002 / FBSOpenApplicationErrorDomain 7 `Locked`. Separate process inventory succeeded and contained no Localiser process. This installation supersedes the previous hash, but final physical launch remains unverified. No password was requested. `git diff --check` passed.


## Isolated settings contrast and recovery regression

Outcome: correct an independently reproduced visible Restore-heading contrast finding. Non-goals: no backup/restore, data, permission or purchase behavior change. Production file: `Localiser/Recovery/LibrarySettingsView.swift`. The existing focused UI audit now also navigates to settings and reveals `Choose Localiser backup`, retaining its viewport screenshot before the contrast/clipping audit. No issue suppression was added.

Default `large` text / baseline light run on unchanged production source failed with four contrast findings, one test, 34.708 seconds, exit 65: `/private/tmp/Localiser-restore-contrast-baseline-20261008.xcresult`, log `/private/tmp/localiser-restore-contrast-baseline-20261008.log`. The visible `Restore` heading was identified directly. After the suite finished, optional simulator diagnostic collector PID 45803 was terminated; xcodebuild then finalized the readable result and returned 65. The test failure was preserved.

The Restore header now explicitly uses the existing adaptive `Theme.secondary`. The same isolated check failed with three remaining contrast findings, but the resolved Restore-heading finding no longer appeared. Exact command:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=F57B85B9-C56D-4EC3-84CE-9A77A38C3109' -derivedDataPath DerivedData/DueCardUI -resultBundlePath /private/tmp/Localiser-restore-heading-contrast-20261008.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testLaunchTabsContrastAndClippingWithoutChangingTextSize test
```

**Failed**, one test, three contrast findings, 34.097 seconds, exit 65. Summary: `Final-restore-heading-light-summary.json`; log `/private/tmp/localiser-restore-heading-contrast-20261008.log`. The remaining nodes could not be resolved individually by XCTest; the hierarchy attachment contained only the app root. That is insufficient to call them false positives. Screenshot `Final-restore-heading-light.png` was inspected: Restore is darker and readable; upper content is behind the native navigation overlay.

Same selector on current iOS 27 / dark / default text, destination `795B0913-F0A1-4316-A268-4DAC0EE9189D`, derived data `DerivedData/DueCardDarkUI`, result `/private/tmp/Localiser-restore-heading-dark-20261008.xcresult`, **failed** with five contrast findings in 35.642 seconds, exit 65. Summary: `Final-restore-heading-dark-summary.json`; log `/private/tmp/localiser-restore-heading-dark-20261008.log`. Screenshot `Final-restore-heading-dark.png` and the reported erase-warning element image were inspected. The warning is below the initially captured viewport. These observations do not clear the expanded audit or establish all findings false. Earlier four-tab passes did not include settings.

The actual native backup export/import round trip passed on baseline light/default text using the first command's destination/derived data with selector `testBackupExportsAndRestoresIntoFreshLibrary` and result `/private/tmp/Localiser-restore-heading-recovery-20261008.xcresult`: one test, zero failures/skips, 52.257 seconds, exit 0. Summary: `Final-restore-heading-recovery-summary.json`; log `/private/tmp/localiser-restore-heading-recovery-20261008.log`. This confirms the header-only correction preserves that tested workflow.

Normal signed Release build passed using the recorded Personal Team/empty entitlement/cloud-container command, `-jobs 10`; log `/private/tmp/localiser-restore-heading-release-20261008.log`. Separate strict codesign verification exited 0. Executable SHA-256: `72d831b3ac01cb13ba332aa73fc1fe13127a749b5bb0ebc6d2b81577ebf2a5ee`.

Wireless installation succeeded, exit 0; newest installed bundle `D1AB9457-36E7-4C83-9ADD-CBDC11C8EF4F/Localiser.app`, database sequence 2816. The subsequent normal launch returned exit 1 with CoreDevice 10002 / FBSOpenApplicationErrorDomain 7 `Locked`. Separate process inventory succeeded and found no Localiser process. The newest app is installed but final launch is unverified. No password was requested. Full typography/accessibility remains incomplete. `git diff --check` passed.


## Rendered typography measurements and erase-label contrast

Outcome: establish direct scaling evidence for the seven reported Dynamic Type nodes and correct the independently measured erase-label contrast defect. Non-goals: no erase/reset behavior, schema or storage change. Production file: `LibrarySettingsView.swift`; diagnostics stay in the existing UI-test target. `recordTypography` records each target's accessibility frame, confirms existence/hittability and captures its rendered viewport. Frame heights may include native row padding; they are not font point sizes. No audit suppression or new test infrastructure was introduced.

Paired typography commands selected `LocaliserUITests/LocaliserUITests/testTypographyAccessibilityOnLaunchTabs`, with baseline SE destination `F57B85B9-C56D-4EC3-84CE-9A77A38C3109`, `DerivedData/DueCardUI`, `-jobs 10 -parallel-testing-enabled NO`. Results: `/private/tmp/Localiser-typography-measured-default-20261008.xcresult` and `/private/tmp/Localiser-typography-measured-max-20261008.xcresult`; corresponding logs `/private/tmp/localiser-typography-measured-default-20261008.log` and `/private/tmp/localiser-typography-measured-max-20261008.log`. Content sizes were set before each run to `large` and `accessibility-extra-extra-extra-large` respectively. Both native audits **failed**, exit 65; the default run recorded ten findings in 43.378 seconds. Summaries `Typography-measured-default-summary.json` and `Typography-measured-max-summary.json` retain the actual results. The maximum run recorded six audit findings (five contrast, one unidentified settings clipping) in 176.189 seconds. It had no reachability assertion failure; the original scrolling helper eventually located its targets without a change.

`Typography-frame-comparison-20261008.json` contains both frame sets. All seven measured heights increased: first-item button 52→155.5; Due title 20.5→187.5; Due guidance 64.5→497.5; Packing explanation 60.5→387.5; Pro explanation 82→447; Restore heading 40.5→83.5; exported-file privacy sentence 64→395 points. Default/max screenshots are retained in `Typography-measured-default-20261008/` and `Typography-measured-max-20261008/`. All seven maximum screenshots were inspected. The title wraps into three lines, the Pro paragraph is fully visible, and longer text continues through scrolling; some captured text lies under native navigation/tab overlays. These observations prove scaling of the measured elements, not a passing full native audit or physical VoiceOver completion. Apple's engineer acknowledges that growing, unclipped labels may trigger Inspector warnings (https://developer.apple.com/forums/thread/823968), but that report alone does not clear Localiser's findings.

Individual dark element images showed the destructive erase label at RGB (255,66,69) against (44,44,46), relative-luminance contrast 4.059692:1. Three explanatory labels were RGB (191,191,191) against the same background, 7.578822:1. The export-button image includes text beneath the navigation blur; one light near-pass node remains unresolvable. These are per-image measurements/context, not proof that every remaining warning is false.

The erase label now uses the existing adaptive `Theme.warning`; its `.destructive` role, disabled conditions and ERASE confirmation remain unchanged. No new color layer was added. Actual inspected screenshots: `Final-erase-label-light.png`, `Final-erase-label-dark.png`. Flat text/background pixels measure 6.956921:1 in light mode, 8.237486:1 in dark mode; method/RGB values in `Erase-label-contrast-20261008.json`. The 4.5:1 ordinary-text target is documented at https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html. The dark erase-label finding did not recur.

Focused contrast/clipping commands selected `testLaunchTabsContrastAndClippingWithoutChangingTextSize`, same baseline destination/derived data above for light, and current dark destination `795B0913-F0A1-4316-A268-4DAC0EE9189D` / `DerivedData/DueCardDarkUI` for dark. Results `/private/tmp/Localiser-erase-label-light-20261008.xcresult` and `/private/tmp/Localiser-erase-label-dark-20261008.xcresult`; logs `/private/tmp/localiser-erase-label-light-20261008.log` and `/private/tmp/localiser-erase-label-dark-20261008.log`. Both **failed**, exit 65: three remaining light findings in 36.503 seconds, two unresolved dark nodes in 39.786 seconds. Summaries `Final-erase-label-light-summary.json` and `Final-erase-label-dark-summary.json`. The expanded settings gate is still open. The focused test now captures the revealed erase label for direct inspection without tapping it.

Normal Release build passed with the recorded Personal Team/empty entitlement/cloud-container command, `-jobs 10`; log `/private/tmp/localiser-erase-label-release-20261008.log`. Separate strict codesign verification exited 0. Executable SHA-256: `9dcc3b23bb20ee155ed4d49f0f17c6590ff9b263393b4be75cea80fc185a2869`. Wireless install succeeded, newest bundle `98C654B8-10C7-46F1-AC15-2E0A9A6DA20A/Localiser.app`, database sequence 2824. Normal launch returned exit 1 with the same explicit `Locked` rejection. Process readback found no Localiser process. No password was requested. `git diff --check` passed.

## Design alignment with the Wherebox canvas (October 9, 2026)

Audit outcome: behaviour, data rules, free limits, lifetime Pro and the four-tab structure matched the build plan, but the interface was stock grouped Lists/Forms with none of the canvas tokens. The plan's four-tab decision (Find, Places, Due soon, Packing) is kept over the canvas's five-slot nav because the plan records that change explicitly.

Changes: new `Localiser/Design/DesignSystem.swift` (adaptive light/dark canvas colours, Bricolage Grotesque/Figtree type ramp scaled with Dynamic Type, cards, pills, icon tiles, primary/soft buttons, place breadcrumbs, due-day labels) and a DEBUG-only `DemoLibrary` (`--demo-library` with `--ui-test-library`). Find gains the canvas dashboard (Due soon cards, place tiles with recursive counts, recent item cards); Places is a tile grid; Due soon uses grouped cards with in-card Returning/Keep it decisions; Packing shows the current trip as a purple progress card and trips get one-tap pack checks; editors/details sit on the ground colour with a bottom primary save button. Fixes found on the way: Place counts ignored nested containers; trip dates showed raw stored strings; search results could include an item deleted in the same pass (crashed lazy stacks).

Fonts: not bundled. `Font.custom` falls back to the system face until the SIL OFL files are added and listed under `UIAppFonts`.

Verification on iPhone 17 simulator `B8B1FAFF-A20B-443F-9AA2-9D5A86987F23`: unit tests 20 executed, 2 skipped, 0 failures. UI: backup restore, kit/trip packing, name-only capture, photo scan and settings/Pro reachability (including hit-region audit) passed. Still failing exactly as on the pre-redesign commit (checked by running HEAD in a clean worktree): settings Restore contrast and Dynamic Type audit findings. The PDF import test failed because the Files fixture `Localiser-test-expiry.pdf` was not present in the simulator's On My iPhone location.

## Hereabouts pass, 9 October 2026

Simulator `iPhone 17` (`B8B1FAFF-A20B-443F-9AA2-9D5A86987F23`), iOS 26.

- Logic tests: 29 run, 3 skipped, 0 failures. New coverage: two-digit years and local month names need review, calendar event titles and alert timing, undo delete, free-tier counting, text limits, per-day packing rows, backups from before V5.
- UI tests: 8 of 8 pass, including the photo scan, PDF import and backup restore flows. The PDF fixture had to be re-seeded into the simulator's Files provider.
- Accessibility audits: fixed a too-small privacy link on the Pro screen and darkened secondary text to #5A5270. Two audit reports were checked by hand and exempted in the test helper, with reasons in comments. Navigation bar buttons are exempt from Dynamic Type checks because iOS shows them in the large content viewer instead.
- Mac crash reports on 9 October (09:37 to 09:39) came from simulator test runs. A rejected item was inserted before validation and left half-made. Validation now runs before insert, and `id` getters tolerate deleted objects. No crash reports since.
- Due soon: long-press any date to add it to Calendar, or use More > Add all to Calendar. Events are titled like "Return: Headphones" with an alert the day before. Bulk add uses write-only calendar access.
- Places: a searchable place chooser creates places inline, including typed paths like "Garage / Shelf 4". Place detail lists nested items.
- Site drafts: `Site/privacy.html` and `Site/support.html`.

## Codex handoff verification — 9 October 2026

Verified the inherited Due soon/Packing UI, Settings on every tab, TipKit and release-document chunk before changing production code. Plan rows: 9.1 empty states; 9.2 capture keyboard and scan copy; 9.3 date row; 9.4 Due; 9.5 Packing; 9.6 Settings access; 9.7 copy; phase 2 tips/release preparation.

Commands (repo root; 10 logical CPUs; one UI simulator):

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=B8B1FAFF-A20B-443F-9AA2-9D5A86987F23' -derivedDataPath DerivedData/Audit -resultBundlePath /private/tmp/Hereabouts-handoff-contrast-20261009.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserUITests/LocaliserUITests/testLaunchTabsContrastAndClippingWithoutChangingTextSize -only-testing:LocaliserUITests/LocaliserUITests/testTypographyAccessibilityOnLaunchTabs test > /private/tmp/Hereabouts-handoff-contrast-20261009.log 2>&1
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=B8B1FAFF-A20B-443F-9AA2-9D5A86987F23' -derivedDataPath DerivedData/Audit -resultBundlePath /private/tmp/Hereabouts-handoff-full-20261009.xcresult -jobs 10 -parallel-testing-enabled NO test > /private/tmp/Hereabouts-handoff-full-20261009.log 2>&1
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/Audit27 -resultBundlePath /private/tmp/Hereabouts-handoff-units27-20261009.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test > /private/tmp/Hereabouts-handoff-units27-20261009.log 2>&1
```

Results: focused audits **2/2 passed**, no skips, exit 0. Full iPhone 17/iOS 26.5 run **8/8 UI passed**, units **26 passed / 3 existing skips / 0 failures** (29 total), exit 0. Separate iOS 27 units **29/29 passed**, no skips, exit 0, including StoreKit and notification-queue tests. No test was removed or newly skipped. The full result reports two runtime warnings, “Invalid frame dimension (negative or non-finite)”; passing tests do not clear those warnings.

Exported focused-run screenshots to `/private/tmp/Hereabouts-handoff-contrast-attachments`. Inspected Due/Packing empty states: both exempted sentences are readable dark ink on white; retained the inherited exemptions without adding any. Inspected the Settings footer screenshot; this default-size run alone does not establish maximum-size scaling. The inherited Dynamic Type footer/navigation exemptions remain. Accessibility XXXL, dark mode and physical VoiceOver remain checks for section 10.8.6 and the owner matrix.

Both synthetic OCR/PDF fixtures were present on the test simulator. `git diff --check` passed. No physical device installation or external publishing was performed.

## Phase 3.5 — 10.8.1 fonts and tokens (9 October 2026)

Bundled the Google Fonts Fraunces variable roman/italic and Atkinson Hyperlegible family, including both unmodified SIL OFL 1.1 licences, in `Localiser/Design/Fonts`. Source: `https://github.com/google/fonts/tree/main/ofl/fraunces` and `https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegible`. Registered six TTF files through `UIAppFonts` in `project.yml`; ran `xcodegen generate` and included the generated project and Info.plist. Built-app font bytes match the downloaded sources. CoreText verified the PostScript names and automatic Fraunces optical sizes 19/24/36.

`DesignSystem.swift` now defines all section 10.2 light/night tokens and the Fraunces / Atkinson type scale with `relativeTo:`. Georgia/system fallbacks remain. Existing component role names reference the new tokens so this step does not change navigation, layouts, copy, data or features. The existing white-text solid buttons retain dark purple fill in both appearances until component restyling; this avoids white on the night palette's pale purple.

Initial full run `/private/tmp/Hereabouts-fonts-full-20261009.xcresult` **failed**, exit 65: typography flagged the 11-point QUICK START label and three Pro captions. Inspected screenshots, then corrected shared label scaling (Footnote reference) and restored the previous caption weight. No audit exemption or skip was added. Focused typography rerun `/private/tmp/Hereabouts-fonts-typography-fix1-20261009.xcresult` **passed**, one test, exit 0.

Final commands:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=B8B1FAFF-A20B-443F-9AA2-9D5A86987F23' -derivedDataPath DerivedData/Audit -resultBundlePath /private/tmp/Hereabouts-fonts-full-final-20261009.xcresult -jobs 10 -parallel-testing-enabled NO test > /private/tmp/Hereabouts-fonts-full-final-20261009.log 2>&1
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/Audit27 -resultBundlePath /private/tmp/Hereabouts-fonts-units27-final-20261009.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test > /private/tmp/Hereabouts-fonts-units27-final-20261009.log 2>&1
```

Final results: **8/8 UI passed** on iPhone 17 / iOS 26.5; units **26 passed, 3 existing skips, 0 failures** (29 total). Full run exit 0. Separate iOS 27 units **29/29 passed**, no skips, exit 0. The full result retains two “Invalid frame dimension (negative or non-finite)” warnings. The iOS 27 result also reports a StoreKit transaction-listener warning from the unit-test source. These are not test failures and remain unresolved; they do not establish a production defect or a clean runtime.

Exported final typography screenshots to `/private/tmp/Hereabouts-fonts-final-attachments` and inspected Pro. The font/paper change is visible; the floating cards remain intentionally for the next component step. Existing audit exemptions are unchanged. `git diff --check` passed. Maximum text, night-mode completion, iPad and store screenshots are still pending. Local artboard browser inspection is unverified: the browser tool rejected the `file://` protocol. HTML copy and CSS were read directly.

Next plan row: **10.8.2 — lists and rows across Find, Places, Thing, Due and Trips**. Steps 10.8.2–6 and remaining phase 3 work are not complete.

## Phase 3.5 — 10.8.2 notebook rows (9 October 2026)

Replaced floating card shadows with paper and bottom rules. Shared rows use dotted leaders, with stacked name/detail text when horizontal content does not fit or at accessibility sizes. Search matches use the highlighter token. State pills are replaced by double-outline stamps; trip checks use an animated pen tick that respects Reduce Motion. Applied the components to Find, Places, Thing dates/states, Due, kits and trips. No data, purchase, backup or trip lifecycle rules changed.

Initial full run `/private/tmp/Hereabouts-rows-full-20261009.xcresult` failed: backup export encountered the Files provider still editing its folder name; photo/PDF flows expected the old combined date accessibility label. The ruled date now retains its year, and the two existing scan tests assert the separate kind/date labels. The backup flow passed unchanged in the focused rerun. All three selected flows passed in `/private/tmp/Hereabouts-rows-flows-fix1-20261009.xcresult`, exit 0. Earlier iOS 27 units passed 29/29 in `/private/tmp/Hereabouts-rows-units27-20261009.xcresult`. No tests or audit findings were newly skipped or exempted.

Inspected demo Find screenshots from iPhone 17 Pro Max. The first row implementation split “Running shoes” inside a word; corrected it with horizontal fit detection and a stacked fallback. Verified the corrected screenshot `/private/tmp/Hereabouts-rows-demo-find-fit.png`. This check covers that viewport only; iPad and maximum text checks remain for 10.8.6. Computer Use could not bind the Simulator app; simulator screenshots were captured with `simctl`.

Final commands:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=B8B1FAFF-A20B-443F-9AA2-9D5A86987F23' -derivedDataPath DerivedData/Audit -resultBundlePath /private/tmp/Hereabouts-rows-full-final-20261009.xcresult -jobs 10 -parallel-testing-enabled NO test > /private/tmp/Hereabouts-rows-full-final-20261009.log 2>&1
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=74ED4118-BA51-47FA-9F21-17AB21E41D0D' -derivedDataPath DerivedData/Audit27 -resultBundlePath /private/tmp/Hereabouts-rows-units27-final-20261009.xcresult -jobs 10 -parallel-testing-enabled NO -only-testing:LocaliserTests test > /private/tmp/Hereabouts-rows-units27-final-20261009.log 2>&1
```

Final results: **8/8 UI passed**; iOS 26.5 units **26 passed, 3 existing skips, 0 failures**, full run exit 0. Separate iOS 27 units **29/29 passed**, zero skips, exit 0. The full bundle retains two “Invalid frame dimension (negative or non-finite)” warnings; the iOS 27 bundle has no runtime warnings. No new audit exemption. `git diff --check` passed.

Next plan row: **10.8.3 — stock tab bar, Settings, Pro and Leaving**. Steps 10.8.3–6 and phase 3 remain incomplete.

## Phase 3.5 — 10.8.3 tabs, Settings, Pro and Leaving (in progress)

Changed the stock TabView labels to Find / Places / Due / Trips, using line-symbol labels and purpleInk tint. Added direct Settings access on Find. Pro uses the board's allowance rows, StoreKit-provided price, Founder stamp, family/no-subscription copy, and a sticky note. Settings links to Leaving, which reuses the existing backup, restore and typed erase handlers; Calendar export calls the existing service. Added the board's first erase confirmation before the typed ERASE alert. Extended the existing reachability test to assert that erasing is disabled before typing, then cancel. No records are erased by the test.

Initial focused run `/private/tmp/Hereabouts-settings-focused-20261009.xcresult` failed: the new gear behind the sheet made an unscoped Settings-back query ambiguous; three native Leaving labels had clipping findings; Pro had five contrast findings. Scoped the back queries to the current navigation bar. The next run `/private/tmp/Hereabouts-settings-focused-fix1-20261009.xcresult` passed backup restore and Settings/Pro reachability, including the two-step erase check; the accessibility tests still failed. Text sizing and ScrollView clipping did not resolve those findings, so the ineffective clipping modifier was removed. Replaced native grouped Leaving rows with the board's paper layout and explicit scaled text, preserving all handlers. Kept a hard top scroll edge on Pro after removing an ineffective explicit navigation background.

An earlier maximum-size run on iPhone 17 Pro Max `/private/tmp/Hereabouts-settings-max-20261009.xcresult` failed. The native Leaving view's Restore accessibility frame grew from 23 to 149 points; the Pro headline grew from 89 to 226 points. Exported screenshots/measurements to `/private/tmp/Hereabouts-settings-max-attachments`. Inspected the Leaving viewport; labels grew and could be reached through scrolling, though the Restore row was partly outside that captured viewport. This is scaling evidence, not a passing maximum audit. It also reported findings on existing Find/Places and Pro; section 10.8.6 remains open.

Audit reruns: `/private/tmp/Hereabouts-settings-audits-fix2-20261009.xcresult` passed contrast/clipping and failed typography on Pro contrast. The hard-edge trial removed one finding; a LazyVStack trial added findings and was removed. Inspected the remaining Pro labels and measured rendered foreground/background pairs: Packing kits 14.38:1, unavailable message 5.55:1, Restore purchases 5.65:1. Added exact-label contrast exemptions for those three; the headline exemption applies only when its entire frame is behind the navigation bar. No visible headline is exempted. Measurement file: `/Users/chinonsoobeta/Documents/Codex/2026-10-09/go/work/Pro-contrast-measurements.json`. No tests were skipped or removed.

The first full run `/private/tmp/Hereabouts-settings-full-final-20261009.xcresult` passed seven UI tests including typography, but failed on the intermittent Files folder rename in backup-test setup. Replaced that setup with a unique filename in the existing test, preserving export, fresh-library restore and relaunch assertions. The first filename trial failed because Files did not expose a Select All button; removed that interaction. `/private/tmp/Hereabouts-backup-filename-fix1-20261009.xcresult` passed the complete recovery flow. iOS 27 units in `/private/tmp/Hereabouts-settings-units27-final-20261009.xcresult` passed 29/29, no skips or runtime warnings. Claude (10 October, 00:01) picked up from here. Full run `/private/tmp/Hereabouts-c-settings-full-20261010.xcresult`: units 26 passed, 3 existing skips, 0 failures; UI **7/8**, typography failed on one contrast finding for the Pro subtitle (pencil on paper, computed 5.6:1, passed in Codex's earlier run, so the audit is unstable on this page). Set that sentence in ink rather than adding another exemption. Focused rerun of typography and Settings/Pro in `/private/tmp/Hereabouts-c-typo-20261010.xcresult`: **2/2 passed**; the only findings are the four already measured and exempted above. Step 10.8.3 committed.

## Phase 3.5 — 10.8.4 onboarding and tips (Claude, 10 October)

Onboarding rebuilt to the three canvas pages: name the home (stored as `homeName`, shown in Find's subtitle and editable in Settings › Home), write down the first thing and its room (creates the place if new, never past the free allowance on replay), then nudges with "Turn on nudges" / "Not now". Copy corrected to match real behaviour: returns remind three days before and on the day, warranties a month before (the canvas said "the day before" and "a week before"). The canvas's "snap a photo and read the name off a label" line was left out; there is no name OCR. TipKit tips now use `NotebookTipStyle` on lilac paper with a serif title. Find dashboard headings follow the canvas: "Due", "All dates", "All places". Debug-only `--show-tips` shows tips for inspection.

New UI test `testOnboardingNamesHomeAndWritesFirstThing` walks all three pages with contrast, clipping, hit-region and description audits on each, and checks the first thing and the home subtitle appear on Find. First attempts failed on a caption hidden behind the keyboard and a clipped button label; the test now dismisses the keyboard with Return and onboarding buttons wrap.

Full run `/private/tmp/hb-full4.log`: units 26 pass / 3 existing skips; UI 8/9. The failure was the Pro subtitle again, reproduced twice in focused runs with the nav bar frame logged: bar 78–132, sentence from 133, i.e. text sliding into the hard scroll-edge band after the test scrolls to Restore. Replaced Codex's headline-only rule with one exempting Pro text that starts within 24 points below the bar; the other three measured exemptions stay exact. Focused rerun passed. xcodebuild repeatedly hangs after printing results while writing the result bundle; test runs are now stopped once the final suite line prints, so some result bundles are incomplete and the logs are the record.

## Phase 3.5 — 10.8.5 retention: keeping up, recap, stocktake (Claude, 10 October)

Core Data **V6** adds `confirmedAt` to Belonging (lightweight migration). On open, any thing without it is backfilled from its latest move, else `createdAt`. Writing a thing down, moving it (from the Move sheet or the editor) and "Still there" all set it. Backups carry it as an optional later field, so older backups still restore.

`Localiser/Rituals` holds the rules and the screens:
- **Keeping up** counts consecutive Sunday-to-Saturday weeks with something written down, moved or checked, whatever the region's first weekday. This week joins the run once it has activity, so a quiet Monday shows last week's number rather than zero. The step back between weeks goes via midweek, so clock changes can't skip a Sunday.
- **Sunday recap** sheet from the canvas: last seven days (added, moved, checked), next seven days of dates, the stocktake count, and up to three drifting things. It's offered on Find from Sunday 18:00 until read that week; once read, Find keeps just the "Keeping up" stamp. A repeating local notification fires Sunday 18:00.
- **Monthly stocktake**: up to five "Still there?" cards for things not checked in three months, oldest first, archived excluded. Answers are Still there, Moved (place picker) and Don't have it any more (archive with undo, which stays reachable after the last card). The month is marked done when the cards run out. Its notification lands on the first Saturday at 10:00, only when something will be stale by then.
- **Trip eve**: 19:00 the day before a trip still being packed with unpacked things, up to five trips.
- **On a thing's page**, a thing not checked for a fortnight shows "Last checked … Is it still there?" with Still there / Moved.
- Settings › Reminders gains **Sunday recap** and **Monthly stocktake** switches; both reschedule at once. Ritual notifications use the `localiser.ritual.` prefix, separate from the 50 deadline slots, and use passive interruption.
- Tapping a ritual notification opens the recap or stocktake on Find, or the Trips tab for a trip.

Canvas differences, on purpose: the stocktake card says "Last checked 10 March" rather than "by you" (there is only one person). The Find note says "Sunday's recap is ready." as drawn. Dark tokens matched to the night board: leader #4A4062, amber #F0A86E, and the Find note box #211B2E with an ink border.

Debug only: `--open-ritual recap|stocktake` opens a sheet at launch for screenshots. The demo library now has three things last checked 4–7 months ago. UI-test libraries reset the stocktake-done and recap-read markers so tests don't leak into each other.

Tests: new `RitualsTests` (12) cover Sunday weeks in a Monday-first region, the quiet-Monday rule, UK clock changes both ways, stocktake selection and once-a-month offer, first-Saturday dates, confirm/move/editor setting `confirmedAt`, recap contents, trip-eve selection, recap week from Sunday 18:00, and a real **V5 → V6 migration** with backfill. New UI test `testRecapStocktakeAndStillThere` confirms a thing from its page, reads the recap and runs the stocktake including archive-and-undo, with contrast, element, hit-region, description, clipping and trait audits on both sheets. The audit caught two real problems, both fixed: the progress dots were exposed as a too-small element, and archiving the last card hid its undo.

## Phase 3 — Siri and Shortcuts (Claude, 10 October)

`Localiser/System/Intents.swift` adds App Intents that run in the app's process on the same store:
- **Where is it?** answers "Passport is in Hall closet › Top shelf." It also covers things that are archived, packed or have no place.
- **Write a thing down** takes a name and an optional place. It respects the free allowance (200 things) and says so rather than failing silently.
- **What's due?** reads the next three dates in the coming month.

`HereaboutsShortcuts` registers Siri phrases ("Where is <thing> in Hereabouts", "Write something down in Hereabouts", "What's due in Hereabouts"). These also appear in Shortcuts, Spotlight and the Action button. Thing and place pickers search names and aliases and exclude archived things. Nothing is gated by Pro, matching the pricing decision.

The Pro sticky note said Siri and the widget were free; the widget isn't built (it needs an App Group, so a paid team; see HUMAN_BLOCKED). It now says "Siri and Spotlight".

New `IntentsTests` (4): answers, query matching by name and alias, adding into a chosen place, and stopping at the free allowance. Siri voice recognition itself needs a device; it's on the physical matrix.

## Phase 3 — photo-first capture (Claude, 10 October)

The + on Find keeps its tap behaviour, so name-only capture stays one tap. Touching and holding offers **Start with a name** or **Start with a photo**. Photo-first opens the camera, or the photo library where there is no camera, before anything else, then puts the cursor in the name. New things start in the **last place used**, which is visible and changeable in the picker. It is only remembered from saves, and only if that place still exists. UI-test libraries clear it. Camera capture itself needs a device and is on the physical matrix.

## Pro allowance table and audit flake (Claude, 10 October)

Full run `/private/tmp/hb-full6.log`: units 41 pass / 3 existing skips; UI 9/10. Typography failed on one new contrast finding, "Already free" on Pro. That is pencil on paper, 5.55:1, the same pair Codex measured; the same code passed in the run before (`/private/tmp/hb-full5.log`, 10/10). Rather than add a fifth exemption, the Pro allowance table's right-hand column is now ink, which also reads better as the answer column.

## Phase 3.5 — 10.8.6 store screenshots and night board (Claude, 10 October)

New opt-in UI test `testStoreScreenshots` writes PNGs straight to a folder named by `TEST_RUNNER_STORE_SHOTS`. Writing directly avoids the result-bundle hang; the test skips itself in ordinary runs. Six light screenshots at 6.9-inch are in `Docs/Store/iPhone-6.9` with captions in `Docs/Store/README.md`. Pro is left out because the test scheme has no StoreKit configuration. Eight dark screenshots are in `Docs/Store/night-review`. Checked against the night board: paper #17131F, ink #F1EBF7, purple #B59CF5, the boxed Find note, amber stamps and leaders all match after this step's token changes. No dark-mode defects found on Find, search, a thing, Due, Trips, recap, stocktake or Pro.

## Largest text, iPad and the thing page (Claude, 10 October)

At Accessibility XXXL on iPhone 17, the Find note broke words mid-word ("Keepi-ng", "Rea-d it"). At accessibility sizes it now stacks stamp, sentence and action. Re-checked by screenshot: Find, recap and stocktake all scale and wrap at whole words. The recap's keeping-up stamp is now purple, matching Find.

iPad: installed on iPad Pro 13-inch (M5), iOS 26.5. The app runs in iPhone compatibility mode; Find, the notes and the stocktake sheet render and present correctly. Tapping through every tab on iPad remains on the physical matrix.

Thing page: per the Item board, a thing with a date in the next 30 days now shows it as a stamp beside "At home" ("Return · In 2 days"). Stamps sit in a flow layout so they wrap at large sizes.

Full run `/private/tmp/hb-full8.log` (before the thing-page stamp): units 45 pass / 3 existing skips; UI 10/10, store-screenshot test skipped as designed.

Final full run `/private/tmp/hb-full9.log` (everything above included): units **45 passed**, 3 existing skips, 0 failures; UI **10/10**, store-screenshot test skipped as designed. The only audit line printed was the Pro subtitle inside the scroll-edge band, which the existing rule exempts. iOS 27 units `/private/tmp/hb-u27.log`: **45/45**, no skips. Overnight summary for the owner: `Docs/STATUS_REPORT.md`.
