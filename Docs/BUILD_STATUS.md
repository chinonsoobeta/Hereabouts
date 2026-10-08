# Localiser build status

Goal: implement the entire approved plan locally. No remote repository or publication.

| Phase | Status | Evidence still required |
| --- | --- | --- |
| 0. Project/local storage | Local implementation tested; gate partial | Network-disabled runtime and physical-device/signing checks |
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
