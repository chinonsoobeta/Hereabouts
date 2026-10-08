# Localiser implementation and verification audit

Reviewed against `../outputs/Localiser-build-plan.md` and the owner's requirement to include all four jobs before launch. The owner authorized completing autonomous work and saving human-blocked items. This audit preserves those exceptions; it does not declare every release phase or public launch complete.

The current implementation has one native iPhone target, feature folders, Core Data model versions V1–V4, two existing test targets, on-device Vision/PDFKit, local UserNotifications/EventKitUI and a single StoreKit lifetime entitlement. There are no third-party app dependencies, server, app account or remote Git. Deferred integrations and sharing remain deferred as approved.

## Fifteen data and behaviour rules

| Plan rule | Current implementation and evidence | Limit of the evidence |
| --- | --- | --- |
| 1. Stable belonging identity and lifecycle | Records.swift and LocaliserStore.swift; persistence/migration, name-only capture, movement-history and returned-item tests pass. Photos/notes/place are optional. Packing is held by trip entries. | Physical capture speed is an owner check. |
| 2. Place tree safety | Place ancestry checks reject cycles; occupied deletion requires explicit clearing. Container moves refresh paths/search. Existing persistence and cycle/deletion tests pass. | Two-device concurrent edits require supported iCloud provisioning. |
| 3. Explicit confirmed calendar dates | `setDeadline` rejects unconfirmed dates; records store the final day. Date editor/save, deletion and photo-review UI pass. | No retail policy or insurance/travel-validity inference is implemented. |
| 4. Return window and anchor convention | DueView.swift has purchase/delivery anchor, day-count choice and final-date preview with explicit confirmation. No remembered store-window feature is present. | Real receipts and independent usability timing belong to the consented beta. |
| 5. Provisional OCR and ambiguity | ScanReader.swift emits interpretations/source lines, rejects invalid dates and requires the final review. Ambiguity/confirmation tests and actual Vision photo/PDF reading pass. Manual entry remains available. | Blurred/representative camera inputs need physical user participation. |
| 6. One scan/one item and bounded import | ScanView.swift links one selected date to one new/existing item. Photo and native Files PDF picker UI pass; valid PDF reading/preview and malformed/eleven-page rejection pass. Reader enforces 20 MB/25 MP/10-page bounds. | Physical camera and physical file-provider checks remain manual device checks; simulator native PDF-selection evidence is now retained. |
| 7. Opt-in original retention | Review defaults to date-only, displays retention/backup/sync implications and discards the draft on dismissal. Date-only photo UI and retention/removal tests pass. No OCR text/ID number is persisted by default. | Physical backup/sync propagation requires the owner device matrix. |
| 8. Independent return decision | Keeping/returning/returned are separate from other date types and packing. Returned archives and deactivates reminders; closed returns require explicit reopening. Existing confirmation, notification and returned-packed-item tests pass. | Real notification action interaction is a physical check. |
| 9. Calendar/local-time reminders and privacy | DateRules.swift and ReminderService.swift use local calendar dates, adjustable lead/hour, generic notification text and a 50-request budget. DST/past/closed-return logic and actual queue replacement/cancellation tests pass. Denied permission and calendar preview/cancel UI pass. | Long inactivity, timezone changes on hardware, permission revocation and saving into a real calendar are owner checks. |
| 10. Independent kit/trip progress | Kits copy linked/free-text rows into separate trip entries and tasks. Independent progress/manual-count tests and the complete packing UI cycle pass. | Physical workflow observations remain in the beta matrix. |
| 11. Quantity/condition rules | Fixed/per-night quantities, same-day zero nights and flying/international/work conditions use calendar-day trip details. Changed dates preserve packed/manual counts and display affected rows. Existing packing rule/date-edit tests pass. | Independent usability observations are not fabricated. |
| 12. Place grouping and overlapping allocation | Entries use current belonging places or Anywhere; overlapping packed-item allocation is rejected. Cancellation/deletion affects the trip allocation, not home location. Packing conflict and container-move tests pass. | Cloud conflict behavior requires two real devices. |
| 13. Departure/coming home confirmation | Trip tasks are independent checklist rows; away requires completion. Coming home requires explicit put-back/new-place/unresolved resolution, with free rows handled separately. Tests and full UI packing cycles pass. | Trip dates never claim automatic physical put-away. |
| 14. Local use/private sync status | Local Core Data is available with private sync off; optional mirroring has actual operation/error status. Local file persistence/relaunch and recovery pass. Free-team device builds omit unsupported cloud/push capabilities. | iCloud provisioning, two-device reconnection/reset, account/storage errors and network-disabled physical operation are incomplete owner-dependent gates. Previously synced/restored libraries keep the documented recovery restrictions until that procedure is verified. |
| 15. CSV and complete recovery | CSV quotes multiline fields and neutralizes formulas. Versioned JSON includes all eleven record types and selected attachments. Validation precedes mutation; non-empty restore is rejected. Logic and actual native file export/import into fresh libraries pass, including smallest-screen maximum text. | iCloud recovery and physical file-provider behavior are distinct owner checks. |

## Build phases and remaining gates

| Phase | Verified local delivery | Saved owner-dependent work |
| --- | --- | --- |
| 0. Project/storage | Runnable simulator project; local file persistence/search/relaunch; historical migration; unsigned Release build; signing identity identified without paid enrollment. | Explicit physical no-network/no-account matrix. |
| 1. Find | Name-only capture, photos/notes/aliases, nested places, move/history/put-away code and tests; UI capture/relaunch/search/delete. | Capture timing and representative physical workflows. |
| 2. Search/quality | Shared prepared index; exact/prefix/place/alias/typo/ambiguous logic; optimized simulator and physical iPhone 16 Pro Max 5,000-item timing; frozen independent quality protocol. | Slower-phone 50 ms target and independent 200-capture/100-search holdout. |
| 3. Dates/reminders | Confirm/save/edit/delete rules, independent return decisions, real simulator scheduling/queue changes, denied permission and user-reviewed calendar cancellation. | Delivery/actions after inactivity, revocation and real calendar save. |
| 4. Scan | On-device photo/PDF reading and limits, candidate review, manual fallback, opt-in source retention, crash/focus correction, confirmed photo UI. | Physical camera/blurred receipts, no-AI device, offline physical operation and physical file-provider review. |
| 5. Packing | Kit/trip rules and all lifecycle/conflict checks; packing/departure/coming-home UI at default and maximum text. | Physical usability observations. |
| 6. Sync/recovery | Configured optional mirroring/status; local export/validated restore including selected files; actual file-provider UI round trips. | Supported team, second device and cloud reconnection/reset proof. Those restrictions are not reported as completed sync. |
| 7. Experience/purchases | Four tabs, first-item entry, adaptive light/dark typography, settings/Pro, local StoreKit purchase/restore/cancel/failure/pending/refund tests and structural accessibility checks. | Physical VoiceOver/assistive technology and outstanding full native typography-audit findings; real StoreKit product/sandbox configuration. No passing full accessibility audit is claimed. |
| 8. Beta/distribution | Local beta script, frozen quality targets and listing/privacy drafts. | Consent, users, publisher/contact/URL/price/identifiers, applicable clearance, supported distribution and publication authorization. |

## Authoritative final checks

Exact commands, bundle paths, failures/corrections and delivery records are in BUILD_STATUS.md. Machine-readable passing summaries are retained under Docs/Verification:

- `Final-current-units-summary.json`: twenty logic/integration tests, zero failures/skips, including actual local StoreKit and notification queue checks.
- `Final-current-dark-ui-summary.json`: five current-iOS dark/default-text UI workflows, zero failures/skips.
- `Final-small-screen-default-summary.json`: five baseline small-screen/default-text UI workflows, zero failures/skips.
- `Final-small-screen-max-summary.json` plus `Final-small-screen-max-recovery-summary.json`: four core/settings flows and the focused file-recovery flow at maximum text, zero failures/skips.
- `Final-current-max-recovery-summary.json`: current-iOS dark/maximum-text native file recovery.
- `Final-physical-search-summary.json`: optimized physical search, one test passed; worst of the measured queries 25.483459 ms at 5,000 items.
- `Final-valid-pdf-summary.json`: supported PDF OCR/preview/original preservation and rejection cases.

Passing structural audits and screenshots do not prove the outstanding contrast/Dynamic Type/clipping findings false. No suppression or issue handler is present. HUMAN_BLOCKED.md and BETA_AND_RELEASE.md preserve the remaining physical/account/release work; tests do not establish public-launch readiness, commercial demand or legal clearance. Final phone delivery must be assessed from the signed-build verification and actual wireless install/launch record, separately from the earlier OTA test.

The final normal Release app was restored after the physical benchmark and launched wirelessly. Process readback confirmed PID 33471 from installed bundle `1EBABC45-299C-4225-B8B8-8C5FB9F634D3/Localiser.app`. No password was required.

A fresh four-tab maximum-text typography audit on October 8 failed with four contrast findings. Its summary/screenshots are retained, and the new focused UI test reproduces that gate. Earlier functional passes do not imply the expanded default UI suite now passes. See BUILD_STATUS.md for the individual review and exact command.

The October 8 native PDF-selection/confirmed-date/opt-in-retention UI test passed (one test, zero failures/skips), with the actual retained PDF visually inspected. The default-text full typography comparison still failed; its six screenshots and failed summary are retained separately. No production code changed in these verification additions.

The two visible Packing section headings were isolated as genuine contrast findings and corrected using the existing adaptive secondary colour. Contrast-only checks pass at default text in baseline light and current-iOS dark appearance; the complete packing UI cycle also passes. The corrected signed Release app was verified, installed and launched wirelessly (PID 33765, bundle 991D3813-DBA9-42CB-9549-3778226AF9D5). The broader full typography gate remains unresolved; these focused passes do not clear other findings.
