# Prompt for Codex: finish the Hereabouts plan and the notebook restyle

Paste everything below the line into Codex, run from the repo root.

---

You are picking up the Hereabouts iOS app (repo folder still named Localiser, bundle `dev.localiser.app`) where Claude left off on 9 October 2026. Implement `Docs/AUDIT_AND_LAUNCH_PLAN.md` in full, including the new section 10 (design direction) and phase 3.5, then phase 3. Show what you are doing as you do it: say which plan row you are on, make the change, run the relevant tests, report the real result, commit. Do not ask whether to proceed; the plan is the decision record.

## Read first, in this order

1. `Docs/AUDIT_AND_LAUNCH_PLAN.md`: the plan. The Decisions table at the top and sections 8, 9 and 10 are binding.
2. `Docs/BUILD_STATUS.md`: what has been verified and how.
3. `Docs/HUMAN_BLOCKED.md`: things only the owner can do. Add to it, never work around it.
4. `Docs/BETA_AND_RELEASE.md`: beta and store listing.
5. `Docs/Design/canvas/*.dc.html` and `canvas.json`: the design artboards as plain HTML. Open them in a browser to see the screens; `support.js` is missing on purpose and can be ignored. The index tabs drawn on Find/Due/Trips and the four alternatives on the "Bottom navigation options" board were all rejected: the bottom nav stays the stock iOS tab bar the app already has.

## State of the working tree

There is an uncommitted chunk from the last session: Due soon and Packing UI pass, Settings reachable from every tab, TipKit tips (`Localiser/System/Tips.swift`, new), and the rewritten `Docs/BETA_AND_RELEASE.md`. `git status` lists it. It builds for testing. Of the 8 UI tests, two contrast audits were still red before the last two fixes (empty-state icon colour changed to `Theme.purpleInk` in `LocaliserApp.swift`; the Packing empty card's "New kit" button restyled and its sentence exempted in the `audit` helper in `LocaliserUITests.swift`) and have not been rerun since.

Step one: rerun the two contrast UI tests, then the full suite. If 8/8 UI and all unit tests pass, commit the chunk as "Due soon and Packing UI pass, Settings on every tab, TipKit tips, release doc". If not, fix and then commit. Then update `Docs/BUILD_STATUS.md`.

## How to build and test

- XcodeGen project: after adding or removing files run `xcodegen generate`, then commit `Localiser.xcodeproj/project.pbxproj` too.
- Simulator: iPhone 17, id `B8B1FAFF-A20B-443F-9AA2-9D5A86987F23` (check `xcrun simctl list devices` if it is gone and pick any iOS 26 iPhone).
- Build: `xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'id=<SIM>' -derivedDataPath DerivedData/Audit build`
- Unit tests: same with `test -only-testing:LocaliserTests`
- UI tests: same with `test -only-testing:LocaliserUITests`. They take ~10 minutes. Run in the background, write the log to a file, and poll for `Test Suite 'All tests' (passed|failed)`. Kill leftovers with `pkill -f "xcodebuild -project Localiser"` before a rerun.
- Demo data for screenshots and manual checks: `xcrun simctl launch <SIM> dev.localiser.app --ui-test-library <any UUID> --demo-library`.
- The UI tests use a custom `audit(_:_:)` helper with a short exemption list. Add an exemption only after looking at the element and confirming it genuinely passes by eye; say so in the commit message.
- Never commit with failing tests. Never skip a test to make it pass.
- Commit messages: imperative subject, a body that lists plan rows touched. End every commit message with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` on its own line, keeping prior history consistent; add your own co-author line above it if your tooling adds one.

## Remaining plan work, in order

### A. Finish phase 2 (store readiness)

- iPad run-through: launch on an iPad simulator with the demo library, screenshot every tab and sheet, fix layout faults (split views, sheet sizes, toolbar overflow). Record in BUILD_STATUS.
- Store screenshots: the five shots listed in `Docs/BETA_AND_RELEASE.md`, taken from the demo library on iPhone 17 Pro Max and iPad Pro 13", saved under `Docs/Store/`. Retake them again at the end of phase 3.5 since the look changes.

### B. Phase 3.5 · Notebook restyle (section 10 of the plan)

Follow 10.8 step by step; each step is its own commit with green tests:

1. Download Fraunces and Atkinson Hyperlegible (both SIL OFL) from Google Fonts, add the font files and OFL licences under `Localiser/Design/Fonts/`, register them with `UIAppFonts` in `project.yml`, and rebuild `Theme` in `Localiser/Design/DesignSystem.swift` to the 10.2 tokens and 10.3 type scale, keeping Dynamic Type (`relativeTo:`). Nothing else changes in this step; the app must look different and every test must still pass.
2. Rows and lists: dotted leader, stamp, highlighter across Find, Places, Thing, Due, Trips.
3. Bottom nav stays the stock `TabView` bar: tint `purpleInk`, swap the tab symbols for the four line icons on the boards, rename to Find / Places / Due / Trips, nothing custom. Settings, Pro, Leaving pages.
4. Onboarding three pages; sticky-note tips (restyle TipKit via `TipViewStyle`, or replace with a custom view if it cannot match).
5. Core Data model V6 with `confirmedAt` on Item (lightweight migration; backfill from `createdAt` on first launch); monthly stocktake; Sunday recap; keeping-up count; notification scheduling and the two Settings switches. Add unit tests for the week counting, the stocktake selection (3+ months unconfirmed, max 5, archived excluded) and the migration.
6. Dark mode against the night board; accessibility audits; retake store screenshots.

Copy: use the words on the Voice board and each screen verbatim. Rename tabs to Find / Places / Due / Trips. Update UI tests when a label changes; do not keep old labels around just for the tests.

### C. Phase 3 · Differentiators

- Spotlight indexing of things and places (`CSSearchableItem`), removed on archive.
- App Intents: "Where is my …" returning the place path, plus "Add a thing" with name and place. Siri phrases in the `AppShortcutsProvider`.
- Due soon widget: build it, but App Groups need a paid team, so gate the shared store behind a build setting and leave the widget target out of the scheme until the team is set. Document in `HUMAN_BLOCKED.md`.
- Photo-first capture: camera opens first on "Add a thing", name is typed after, place picked last.

### D. Wrap up

- `Docs/BUILD_STATUS.md` updated with the final test run (counts, result bundle paths) and the commands used.
- `Docs/HUMAN_BLOCKED.md` updated with anything new that needs the owner.
- Phase 1.x (more than one home) is designed in the plan but **not** built now. Do not add a Home entity.

## Rules

- Local-only app. No sync, no accounts, no analytics, no network calls other than StoreKit.
- Free tier: 200 things, 2 kits, 5 scans a month. Pro is one lifetime purchase. Pro gates volume only; every feature is free. Do not gate anything new.
- No glassy gradients, no floating orbs, no soft-shadow rounded cards. If a stock SwiftUI control cannot match the board, draw it.
- Keep every screen usable at accessibility XXXL text and with VoiceOver; the UI tests run the audits.
- Nothing is uploaded, published, or sent to anyone. Physical-device installs are the owner's job.
