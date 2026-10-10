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
