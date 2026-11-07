# Hereabouts

Hereabouts remembers where you put things and when return windows, warranties and expiry dates run out. It also keeps reusable packing lists for trips. Everything stays on the iPhone. There is no account, server, analytics or advertising.

The Xcode project and folders still use the working name Localiser. The bundle identifier is `dev.hereabouts.app`.

## Build

The project is generated from `project.yml` with XcodeGen. There are no third-party dependencies.

```sh
xcodegen generate
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run the logic tests with `test -only-testing:LocaliserTests` and the UI tests with `test -only-testing:LocaliserUITests`.

There are two targets. `Localiser` is the app. `HereaboutsControls` is a small extension holding the Control Centre and Lock Screen button, "Put something away". It only opens the app, so it needs no App Group and builds on a free Personal Team.

Phone installs on the free team pass `HEREABOUTS_FREE_THINGS=200`, because they can't buy Pro.

## Links and shortcuts

The app opens these links, from the app icon's shortcuts, Siri, box labels and (later) the widget:

| Link | Opens |
| --- | --- |
| `hereabouts://find` | Find, with the search field focused |
| `hereabouts://new` | The new-thing screen |
| `hereabouts://putaway` | The new-thing screen, camera first |
| `hereabouts://due` | Due |
| `hereabouts://item/<id>` | A thing |
| `hereabouts://place/<id>` | A place; box labels carry this as a QR code |

App Shortcuts cover finding a thing, writing one down, putting something away, "I found my…" and what's due.

## Test fixtures

Two UI tests need synthetic files in the test simulator. Never seed a personal phone.

```sh
xcrun simctl addmedia <simulator-UUID> Docs/Verification/Printed-expiry.png
```

Copy `Docs/Verification/Localiser-test-expiry.pdf` into the simulator's Files app under On My iPhone. The provider folder lives under the simulator's `Containers/Shared/AppGroup/<id>/File Provider Storage`.

Launch arguments for manual checks:

| Argument | Effect |
| --- | --- |
| `--ui-test-library <UUID>` | Opens a fresh, separate library and skips the introduction |
| `--demo-library` | Fills that library with sample places, items, dates and kits |
| `--show-onboarding` | Shows the introduction again |
| `--show-tips` | Shows the sticky-note tips, which UI tests otherwise hide |
| `--open-ritual recap` or `stocktake` | Opens the Sunday recap or the monthly stocktake |
| `--stand-in-shelf-reader` | Debug builds: "Several things in this photo?" returns Drill, Spirit level and Tape measure instead of asking the on-device model |

## Screenshots

`testStoreScreenshots` takes the eight store screenshots from the demo library. It also takes design-review shots of Settings, Leaving, Places, a place, the place chooser, the thing editor, a kit and a trip. It runs only when given a folder:

```sh
TEST_RUNNER_STORE_SHOTS=/path/to/folder xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

The test turns reminders on before the first shot, so Due shows no warning. The name-only capture test (`testNameOnlyCaptureSurvivesRelaunchAndCanBeFound`) turns notifications off, and that lasts until the app is deleted. On a simulator that has run the full suite, first run `xcrun simctl uninstall <simulator-UUID> dev.hereabouts.app`. For the dark set, run `xcrun simctl ui <simulator-UUID> appearance dark`. `Docs/Store/README.md` has the sizes and captions.

## Purchases

`LocaliserTests/Localiser.storekit` is a local StoreKit configuration for testing. It defines the Hereabouts Pro subscription group (`dev.hereabouts.pro.monthly` at US$2.99 and `dev.hereabouts.pro.yearly` at US$19.99, each with a two-week free trial) and `dev.hereabouts.pro.lifetime` at US$49.99, all with Family Sharing. The real products must be created in App Store Connect before release; see `Docs/FEATURE_PLAN.md`. The free plan holds 15 things, 1 packing kit and 2 homes; the thing limit is set by `HEREABOUTS_FREE_THINGS` in `project.yml`.

## Notebook data

The Core Data model is at V8. Above places sits `Home`: things, places, kits and trips each belong to one, and a notebook from before V8 lands in one home named as before. The current home lives in `UserDefaults` (`currentHomeID`); the home's name is in the record, and `homeName` only mirrors the current one for the Find subtitle and the recap.

Backups are JSON, format 3 (`LibraryBackup.currentVersion`). Formats 1 and 2 still restore; anything they lack, such as homes or who made a move, is filled in on restore. The spreadsheet export has a `home` column after the name.

## Where things are

- `Docs/AUDIT_AND_LAUNCH_PLAN.md` holds the plan being implemented.
- `Docs/FEATURE_PLAN.md` plans the subscription and the features agreed on 12 October 2026.
- `Docs/BUILD_STATUS.md` records what was built and verified.
- `Docs/HUMAN_BLOCKED.md` lists what only the owner can do.
- `Docs/BETA_AND_RELEASE.md` has the beta script and listing drafts.
- `Site/` holds the privacy policy and support pages to host.
