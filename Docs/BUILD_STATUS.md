# Localiser build status

Goal: implement the entire approved plan locally. No remote repository or publication.

| Phase | Status | Evidence still required |
| --- | --- | --- |
| 0. Project/local storage | Local implementation tested; gate partial | Network-disabled runtime and physical-device/signing checks |
| 1. Find belongings | Local implementation tested; gate partial | Real-device capture timing and broader UI review |
| 2. Search/capture quality | Logic tests passed; gate partial | Independent quality dataset, slowest-device benchmark |
| 3. Dates/reminders | Local implementation tested; gate partial | Permission/actions/queue and calendar UI tests, real-device long inactivity |
| 4. Scan/confirm | Local implementation tested; gate partial | Import/review UI checks, blurred real receipts, camera, no-AI physical device, cleanup review |
| 5. Pack/depart/come home | Not started | Full phase gate from approved plan |
| 6. Private sync/recovery | Not started | Full phase gate from approved plan |
| 7. Integrated/purchases | Not started | Full phase gate from approved plan |
| 8. Beta/distribution prep | Not started | Full phase gate from approved plan; external publication separately approved |

No phase is complete from code inspection alone. Record exact verification commands/results and distinguish simulator evidence from physical devices and user-account operations.

## Verified October 7, 2026

- Xcode 27.0 / Swift 6.4. Dedicated empty iOS 26.5 simulator `Localiser Verification` (`15434DA2-3643-4612-B5AB-FE973104A4DD`). No remote Git configured.
- `xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,id=15434DA2-3643-4612-B5AB-FE973104A4DD' -derivedDataPath DerivedData -jobs 10 -parallel-testing-enabled NO test`: **passed**, nine logic/integration tests and one UI test. Result: `DerivedData/Logs/Test/Test-Localiser-2026.10.07_19-15-25--0700.xcresult`.
- Coverage includes persisted item/place retrieval, container moves, cycle/deletion safety, historical-schema migration with photos, date confirmation, independent reminder types, DST, search/ambiguity, actual Vision OCR on a generated expiry image, PDF rejection, and scan retention/counters. UI test saves by name, restarts and searches. This does not establish physical-device performance or complete feature UI coverage.
- Historical V1 storage configuration was matched by entity/property hashes before switching to bundled versioned models. Migration tests preserve its records. Current model V3 adds scan records; V1/V2 remain for migration compatibility.
- Connected-device inventory lists an iPhone 16 Pro Max as **unavailable**. No physical-device tests, developer enrollment, production signing, CloudKit provisioning, StoreKit product setup or distribution have been performed.
- `xcodebuild -project Localiser.xcodeproj -scheme Localiser -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData/Device -jobs 10 CODE_SIGNING_ALLOWED=NO build`: **passed**. Xcode reports a missing explicit orientation configuration, to address during integrated UI/release configuration. AppIntents metadata extraction is skipped because that deferred feature is not present.
