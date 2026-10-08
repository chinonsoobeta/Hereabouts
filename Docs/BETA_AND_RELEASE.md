# Localiser: beta and release preparation

Local draft, October 7, 2026. No invitations, account changes, product creation or submission have been performed. Use BUILD_STATUS.md for actual verification results.

## Beta workflow

Start with a small consented group of household organizers, frequent shoppers and travellers. Expand toward fifteen to twenty households only after obvious defects are resolved. Ask participants to use their own ordinary belongings; synthetic documents are sufficient for initial expiry tests.

| Task | Success to observe | Record |
| --- | --- | --- |
| Save one real item | Save by name, choose an optional place, then retrieve after restarting | Time, search phrase, whether help was needed |
| Find after moving | Move a container or belonging and retrieve its new location | Incorrect/ambiguous suggestions and corrections |
| Confirm a date | Review a scan, choose its meaning, confirm the final date | Wrong suggestions, manual corrections, trust |
| Complete a return decision | Keep, plan a return or mark returned without suppressing unrelated dates | Reminder changes and accidental archival |
| Complete a packing cycle | Reuse a kit, pack, check departure tasks, resolve coming home | Missing rows, quantities, conflicts and unresolved items |
| Recover a library | Export selected files and restore into a fresh local installation | Record counts, attachment recovery and trip progress |

Ask whether they used Localiser again without prompting, which problem it helped with, what they would pay, and which existing tool they would replace. Record observations and exact defects; small-sample percentages do not establish commercial demand. Do not add an analytics service solely for this beta.

## Frozen quality-check protocol

Freeze the app commit and expected answers before evaluating the independent examples proposed in the plan: 200 capture sentences and 100 search pairs. Use consented, de-identified examples from people who did not write the implementation. Keep all examples in the reported denominator, including failures, ambiguous inputs and manual corrections. Do not replace difficult examples after seeing the result. Development fixtures and the current unit tests are not this holdout dataset.

For each capture sentence, record the intended item name, existing place identifier or explicit unknown/ambiguous result, suggested values, required corrections and time to finish saving. Score an automatic suggestion as correct only when both its name and place result match the frozen answer. Report suggestion accuracy separately from successful corrected capture. The usability target is at least 90% of attempted captures completed correctly within ten seconds, including any corrections. Unknown/ambiguous locations must never be silently assigned, and dates must never be saved without explicit confirmation: the allowed count for either safety failure is zero.

For each search pair, record the query and acceptable item identifiers before running it. Score a successful positive query when an acceptable item appears among the first three results; the initial target is at least 95% of positive queries. Report negative-query false positives and ambiguity separately, rather than counting them as successful retrievals. Measure the separate 5,000-record / 50 ms performance target on the slowest supported test phone. Do not infer it from search accuracy or simulator timing.

These are evaluation targets, not achieved results. If the frozen evaluation misses a target, record the defects and repeat on a new independent holdout after correcting them; preserve the failed evaluation. Representative inputs, user observations and the physical timing checks remain owner/beta work.

## Physical-device verification before public launch

- Test iOS 26 and the current OS, the smallest supported screen, and phones with and without Apple Intelligence where available.
- Test airplane mode/no iCloud account: create, edit, move, search, scan and relaunch without loss.
- Measure name-only capture and search with 5,000 records. The ten-second capture and 50 ms search figures are targets until measured on the slowest test device.
- Review Find, Places, Due soon, Packing, scan confirmation, backup and purchase screens in light/dark mode, maximum Dynamic Type and VoiceOver. Check focus order, error announcements and control labels.
- Test notification permission denial/revocation, actions, date edits/deletions, termination, long inactivity, time-zone changes and more than sixty-four candidate reminders. Check the visible queue against actual pending requests. Test the calendar editor without broad calendar access.
- Scan blurred receipts, multiple/ambiguous/missing dates, an expired document, a camera scan, a photo and a PDF. Verify canceled/failed scans consume no successful-scan allowance. Inspect retention and cancellation cleanup.
- Two devices on the same Apple ID: initial sync, offline edits, reconnection, conflict handling, unavailable/full iCloud, sign-out, relaunch and later account availability. Verify photos and source documents. Do not claim household sharing.
- Verify deletion with an offline second device. Implement and verify a safe reset/reconnect procedure before removing the current safety restrictions on previously synced or file-restored stores.
- Complete StoreKit sandbox purchase, restore, cancellation, failure, pending approval and refund checks. Verify existing data/edit/export access after loss of the entitlement. Local StoreKit evidence does not establish production setup.

No public launch while there are unresolved data-loss defects, silently accepted wrong dates, unverified cloud reconnection, or missing physical reminder proof.

## Draft listing

Name: **Localiser**

Subtitle candidate: **Find, remember, pack**

Description candidate, subject to final verified behavior:

> Remember where you put things and what you need to do next. Save a belonging with just a name, add a place when useful, and find it by name, alias or location. Scan a receipt or document on your iPhone, review possible dates, and confirm return, warranty or expiry reminders. Prepare trips with reusable packing kits, departure tasks and explicit coming-home checklists.
>
> Start gradually. Free use includes fifty saved belongings, one reusable kit and three successful scans. A lifetime Pro purchase removes those creation limits. Existing records, manual dates, trips and export remain accessible if a purchase becomes unavailable.
>
> Local use works without an app account. Optional private iCloud sync connects your own devices when configured and available. Notification scheduling has a finite queue; Localiser shows its coverage and offers calendar export. Review every scanned date against the original document.

Do not publish this description until the referenced behavior passes its gates. No delivery date, instant-sync claim or guaranteed reminder claim is approved.

Screenshot sequence: Find with a real example; item/place/history detail; scan source and confirmed date; Due soon with queue coverage; place-grouped packing and coming home. Use synthetic documents and remove identifiers. Simulator QA screenshots are not yet store-ready screenshots.

## Privacy policy draft content

Owner must supply the legal publisher name, effective date, support contact and hosted policy URL before publishing.

- Localiser stores user-entered belongings, places, notes, aliases, dates, location history, kits, trips and checklist progress in the app's local library.
- Text recognition happens on the device. Recognized source text is not retained automatically. A scan original is stored only when the user chooses to keep it; user-entered notes and retained originals may include sensitive information.
- Retained data may participate in device backup. If private sync is enabled in a properly configured build, local library data and retained files may be mirrored to the user's private iCloud database. Availability and storage limits depend on Apple services and the user's account.
- Localiser has no developer-operated document server, advertising SDK or analytics SDK in this implementation. The final privacy declaration must be checked against the shipped binary and Apple service behavior, including StoreKit and any optional user-submitted support material.
- Local notifications use generic text. The user controls reminders and can export a calendar event through Apple's editor. A saved date is user-confirmed information, not a verified retail policy, warranty coverage determination or travel-validity decision.
- CSV is an inventory export. A JSON backup includes all library records and only the selected files. Exported files are readable to anyone with access to the destination; Localiser does not encrypt the export itself.
- Deleting an item removes its local dates, scans and movement records. Historical kit/trip rows remain as unlinked checklist rows. Sync deletion is eventual and must be tested across offline devices; do not promise instant deletion of every copy.
- Full local erase is available only for a local store that has not used private sync. Previously synced stores and cloud reconnection after file recovery remain restricted pending verification.

This content is an implementation-based draft, not a completed legal review or App Store privacy declaration. The privacy manifest currently declares app-private UserDefaults use (`CA92.1`); inspect the final archive and dependencies before submission. See [Apple's required-reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and [private CloudKit database documentation](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase).

## Owner configuration and submission inputs

1. Developer membership, signing team, permanent bundle identifier and matching private iCloud container. Do not use the temporary development identifiers for a public release.
2. Lifetime non-consumable identifier, actual price and storefronts. US$49.99 in the local StoreKit file is test metadata only. Do not configure Family Sharing automatically.
3. Publisher/support details, privacy/support URLs and listing/name clearance. Confirm applicable business/employment obligations separately.
4. A signed device/archive build, validated privacy report, provisioned production CloudKit schema, production StoreKit product and completed physical/beta evidence.
5. Explicit owner approval to invite testers, upload a build, publish materials or submit the app. Local preparation does not authorize any of those actions.
