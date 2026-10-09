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

## Purchases

`LocaliserTests/Localiser.storekit` is a local StoreKit configuration for testing. It defines `dev.localiser.pro.lifetime` at the US$4.99 Founder's price with Family Sharing. The real product must be created in App Store Connect before release.

## Where things are

- `Docs/AUDIT_AND_LAUNCH_PLAN.md` holds the plan being implemented.
- `Docs/BUILD_STATUS.md` records what was built and verified.
- `Docs/HUMAN_BLOCKED.md` lists what only the owner can do.
- `Docs/BETA_AND_RELEASE.md` has the beta script and listing drafts.
- `Site/` holds the privacy policy and support pages to host.
