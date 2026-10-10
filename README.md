# Hereabouts

Hereabouts remembers where you put things and when return windows, warranties and expiry dates run out. It also keeps reusable packing lists for trips. Everything stays on the iPhone. There is no account, server, analytics or advertising.

The Xcode project and folders still use the working name Localiser. The bundle identifier stays `dev.localiser.app` so existing installs keep their data.

## Build

The project is generated from `project.yml` with XcodeGen. There are no third-party dependencies.

```sh
xcodegen generate
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run the logic tests with `test -only-testing:LocaliserTests` and the UI tests with `test -only-testing:LocaliserUITests`.

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

## Screenshots

`testStoreScreenshots` takes the eight store screenshots from the demo library. It also takes design-review shots of Settings, Leaving, Places, a place, the place chooser, the thing editor, a kit and a trip. It runs only when given a folder:

```sh
TEST_RUNNER_STORE_SHOTS=/path/to/folder xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

The test turns reminders on before the first shot, so Due shows no warning. The name-only capture test (`testNameOnlyCaptureSurvivesRelaunchAndCanBeFound`) turns notifications off, and that lasts until the app is deleted. On a simulator that has run the full suite, first run `xcrun simctl uninstall <simulator-UUID> dev.localiser.app`. For the dark set, run `xcrun simctl ui <simulator-UUID> appearance dark`. `Docs/Store/README.md` has the sizes and captions.

## Purchases

`LocaliserTests/Localiser.storekit` is a local StoreKit configuration for testing. It defines `dev.localiser.pro.lifetime` at the US$4.99 Founder's price with Family Sharing. The real product must be created in App Store Connect before release.

## Where things are

- `Docs/AUDIT_AND_LAUNCH_PLAN.md` holds the plan being implemented.
- `Docs/BUILD_STATUS.md` records what was built and verified.
- `Docs/HUMAN_BLOCKED.md` lists what only the owner can do.
- `Docs/BETA_AND_RELEASE.md` has the beta script and listing drafts.
- `Site/` holds the privacy policy and support pages to host.
