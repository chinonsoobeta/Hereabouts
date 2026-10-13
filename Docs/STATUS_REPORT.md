# Status report — 12 October 2026

You asked for the whole feature plan: Phase A, then as much of Phase B as works without the paid account. Everything is committed locally on `main`. Nothing was pushed, uploaded or published.

Phase A is done, A1 to A10: the subscription, private things, Found it, quick wins, Lent to, camera-first Put away with the Control Centre button, box labels, pasting an order email, and naming a shelf from one photo.

Phase B, as far as it goes before enrolment:

| Step | State |
| --- | --- |
| B5 Homes | **Done** (`3c7ac8d`). More than one home, a switcher on Find and Places, Settings › Homes. Two homes on the free plan. |
| B6 Household sharing | Groundwork (`ecc2553`): every move records who made it. Sharing itself needs iCloud. |
| B4 iCloud sync | Groundwork (`692fd19`): Places offers to tidy up empty copies of a place, the problem two phones set up apart would cause. Sync needs the paid account. |
| B1 Shared notebook file | Groundwork (`afb5362`): moving the notebook with its photos, and reading changes from other processes, both tested. Switching it on needs an App Group. |
| B2 Widget | Waiting for your word that you've enrolled, as agreed. |
| B3 Share sheet, B7 TestFlight | Need the paid account. |

`HUMAN_BLOCKED.md` has a row for each, with what to do. One thing only your phone can tell us: whether "Several things in this photo?" names a real shelf well. It needs Apple Intelligence on.

Last runs:

| Suite | Result |
| --- | --- |
| Unit tests, iOS 27 | **110 of 110** passed |
| Unit tests, iOS 26.5 | **110**: 104 passed, 6 skipped (purchase tests need iOS 27's local StoreKit), 0 failed |
| UI tests, iOS 26.5 | **18**: 17 passed, the screenshot test skipped itself as designed |

Your phones have the build from before A1. Free-team installs stop opening on **Sat 17 Oct at 12:11 PDT**. Reinstall before then to get everything above.

---

# Status report — 10 October 2026

## This morning: the end-to-end sweep

You asked for an adversarial sweep of the whole app: UI, code and engineering, fixing what turned up. Everything is committed locally on `main`. Nothing was pushed, uploaded or published. Your iPhone has the latest app, installed over the air today.

What was actually wrong, in order of how much it would have hurt:

| Found | Fixed in |
| --- | --- |
| "Add all to Calendar" added every date again on each tap, and each event covered two days | `bbd08c8` |
| Passed warranty and expiry dates stayed on Due as if still due | `9d708bc` |
| The app version was fixed at 1.0 (1) in Info.plist, so a version bump would never have shipped | `0a5678b` |
| The library file kept every edit ever made (history tracked, never read or trimmed) | `0a5678b` |
| Going Back in onboarding and writing again added a second thing | `0a5678b` |
| Putting a thing back after a trip didn't count as seeing it, so it came up in Still there? | `0a5678b` |
| Deleting a place left its things with no place, made its shelves into rooms, and counted the things as checked | `9451eb4` |
| Siri read dates as "Sun 11 Oct", and could say "last in no particular place" | `c47e428` |
| Places quick start offered six rooms but vanished after the first tap | `c47e428` |
| On the two Sundays the clocks change, the recap opened an hour early or late | `c47e428` |
| Every visit to the Pro screen opened with "Pro isn't available to buy right now" until the App Store answered | `9451eb4` |
| In dark mode, lists and forms showed grey system panels on the purple-black paper | `e75c7ba` |
| The recap named four of eight new things as if that were all | `9451eb4` |
| The recap counted moves, not things, and counted a moved thing again as checked | `9451eb4` |
| A cut-off backup was called "not a Hereabouts backup" | `9451eb4` |
| The store screenshots showed a red warning badge on Due, and their recap said "8 new things" while calling one of them unchecked since March | `b3ca71e` |
| The place chooser left a stray place behind when it refused a path | `9451eb4` |
| In dark mode, Settings still had grey rows; long lines stacked in the middle of the row; a trip's add row looked torn off | `9451eb4` |
| "Item", "location", "deadline", "library", "records" and "Could not…" all over the app; "Put away. Nice." praised; reminder buttons said "Keep purchase" where Due says "Keeping it" | `ce122d5`, `c47e428`, `e75c7ba`, `9451eb4` |
| The PDF import test failed when the test phone's Files folder filled up | `7bdd327` |

Smaller fixes are listed in `BUILD_STATUS.md` under "End-to-end sweep".

Checked and fine: the privacy manifest, photo storage and memory, the 64-reminder system limit, Siri sharing the app's store, every tip pointing at a real control, the usage strings and the store icon.

Three word choices are yours:
- "Archive" is on the voice guide's don't-use list, but nothing has replaced it.
- The expiry kind says "Expires" rather than "Goes off", because its 180-day lead fits passports and licences.
- British and American English are mixed: "The flat" and "Don't have it any more", but "canceled" and "Winter tires". The launch plan makes en-GB primary; tell me which way to go and I'll make it consistent.

One design item: the app icon is still the pin-and-box mark, with no dark or tinted version. It works, but it predates the notebook look.

Last runs, after every fix above:

| Suite | Result |
| --- | --- |
| Unit tests, iPhone 17, iOS 26.5 | **54**: 52 passed, 2 skipped (purchases need iOS 27 here), 0 failed |
| UI tests, iPhone 17, iOS 26.5 | **10 of 10** passed (one after a test fix*); the screenshot test skips itself, as designed |
| Unit tests, iPhone 17 Pro, iOS 27 | **54 passed**, 0 skipped, 0 failed |
| Store screenshots, iPhone 17 Pro Max | Light and dark sets retaken, both passing |

*In the full run, the backup restore test failed because old test backups had pushed its file out of view in the picker. The test now searches for it and takes it from the search results. Rerun with the PDF test, which uses the same search, both passed.

Your iPhone has this build: `9451eb4`, installed over the air and opened. Everything committed after it is tests, demo data and notes, which don't change the app.

---

# Overnight status report — 10 October 2026

Claude picked up from Codex at 00:01 and stopped at about 01:45. Everything is committed locally on `main`; nothing was pushed, uploaded or published. The last full test run is green.

## In one paragraph

Codex's work was careful and honest, and its tests were green apart from one flaky audit. I committed its unfinished step, then built the rest of phase 3.5 and most of phase 3:
- the canvas onboarding;
- the Sunday recap, monthly stocktake and keeping-up count, with a Core Data V6 migration;
- Siri and Shortcuts;
- photo-first capture;
- dark-mode tokens matched to the night board;
- fixes at the largest text size;
- store screenshots.

What's left is either human-blocked or needs a real device, plus one design difference on the Due screen that I'd like you to decide.

## What Codex had done

| Plan step | State when I arrived |
| --- | --- |
| 10.8.1 Fonts and paper-and-ink tokens | Committed (`fc72e5c`) |
| 10.8.2 Notebook rows, stamps, search highlights | Committed (`8440d59`) |
| 10.8.3 Tab bar, Settings, Pro, Leaving | Done but **uncommitted**; full run 7/8 UI |
| 10.8.4 – 10.8.6, phase 3 | Not started |

Earlier work was already in place: Spotlight indexing, the place chooser, camera capture and Calendar export.

## What the audit found

- **Quality was good.** Codex's changes matched the plan and the canvas. Every audit exemption it added was backed by measured contrast ratios, and BUILD_STATUS recorded failures honestly.
- **One flaky test.** The Pro screen's contrast audit failed on and off. I traced it to text sliding under the navigation bar's blurred scroll edge once the test scrolls. I replaced a headline-only exemption with one limited to text within 24 points of the bar.
- **Copy that promised too much.** The Pro note said Siri *and the widget* were free, but neither existed. Siri now exists. The widget can't be built without a paid developer team, so the note now says "Siri and Spotlight".
- **Canvas copy that didn't match behaviour.** The onboarding board said reminders come "the day before a return" and "a week before a warranty ends". The app does three days before plus the day itself, and 30 days for warranties, so the copy now matches the app.
- **Tooling.** xcodebuild hangs after printing results while writing the result bundle. Test runs are now stopped once results print, and the logs are the record.

## What I fixed and built

| Commit | What |
| --- | --- |
| `ab7cdb8` | Codex's 10.8.3, audited and committed with the flake fix |
| `cca1419` | **10.8.4** Three-page canvas onboarding: name your home, write down the first thing and its room, turn on nudges. The home name appears on Find and is editable in Settings. Tips use the sticky-note style. |
| `a408946` | **10.8.5** Core Data V6 (`confirmedAt`) with backfill. Sunday recap, monthly "Still there?" stocktake with undo, keeping-up count, "Is it still there?" on a thing's page, trip-eve reminder, and Settings switches. **Siri/Shortcuts:** "Where is…", "Write something down", "What's due". **Photo-first capture:** touch and hold +. New things default to the last place used. Night-board dark tokens. |
| `4b4e9da` | **10.8.6** Store screenshots (6.9-inch, light) in `Docs/Store/`, and dark-mode review shots |
| `7fa0c68` | Find note stacks at the largest text sizes. Next-date stamp on a thing's page. iPad compatibility check. This report. |

The tests caught real bugs along the way, and all are fixed:
- the stocktake's undo vanished after the last card;
- the progress dots were a too-small accessibility element;
- the Find note broke words mid-word at the largest text size;
- changing a thing's place in the editor didn't count as "seen".

## Test results

Last full run, iPhone 17 simulator, iOS 26.5:

| Suite | Result |
| --- | --- |
| Unit tests | **45 passed**, 3 skipped (the same 3 Codex had), 0 failed |
| UI tests | **10 passed**, 0 failed; the opt-in screenshot test skips itself as designed |
| Unit tests on iOS 27 simulator | **45 passed**, 0 skipped, 0 failed |

New tests this session:
- `RitualsTests`, 12 tests. They cover weeks in a Monday-first region, UK clock changes, the stocktake rules, a real V5 → V6 migration and the recap timing.
- `IntentsTests`, 4 tests. They cover Siri's answers, search, adding into a place and the free-limit guard.
- Two UI tests: onboarding, and recap/stocktake/still-there, each with accessibility audits on every screen.
- An opt-in screenshot test.

Logs are in `/private/tmp/hb-full*.log`. They will not survive a restart; BUILD_STATUS keeps the numbers.

## What's left, and why

| Item | Why it isn't done |
| --- | --- |
| Due soon widget | Needs an App Group, which a free Personal Team can't create. Added to `HUMAN_BLOCKED.md`. |
| Pro store screenshot | The test scheme has no StoreKit configuration, so Pro shows "unavailable". Take it from a sandbox build once the product exists. |
| Siri by voice, camera, notifications over days, VoiceOver, iPad tapping-through | Need a real device. Added to the physical matrix in `BETA_AND_RELEASE.md`. |
| Onboarding "read the name off a label" | Left out: there is no name recognition, and the line would promise something the app doesn't do. |
| Everything already in `HUMAN_BLOCKED.md` | Domain, privacy pages, developer enrolment, App Store product, name clearance, TestFlight. |

## Decisions (answered 10 October, morning)

1. **Due screen:** This week / Later / Done. Done.
2. **Recap and stocktake:** on by default. Already the case.
3. **Last place used:** kept, but only within 10 minutes of the last save. Done.
4. **Widget:** to be built after developer enrolment.

To see the new screens: run the app with the demo library, then add `--open-ritual recap` or `--open-ritual stocktake` to open them directly.
