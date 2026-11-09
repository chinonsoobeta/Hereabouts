# Store screenshots

The iPhone set was taken 7 November 2026 on the iPhone 17 Pro Max simulator (6.9-inch, 1320 × 2868), iOS 27, light mode, default text size, status bar at 9:41. `5-pro.png` was retaken on 8 November for the "Share Pro with your family" row. The iPad set (`iPad-13/`, 2064 × 2752, upright) was taken on 8 November on the iPad Pro 13-inch (M5) simulator, iOS 27, the same way. They come from the Debug-only demo library, so no real names or documents appear. The Pro shots show the plans loaded from the local StoreKit file.

Retake them with the simulator booted and its status bar and appearance set:

```bash
xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui <device> appearance light
TEST_RUNNER_STORE_SHOTS=/private/tmp/hb-store xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=<device>' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

The test also writes `review-*` design-review shots to the same folder. They are not for the store.

The iPad and Duo shots come from a separate test, in portrait. `STORE_SHOTS` is the folder, and the test writes the five files straight into it:

```bash
xcrun simctl ui <ipad> appearance light
TEST_RUNNER_STORE_SHOTS=/private/tmp/hb-store-ipad xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=<ipad>' -only-testing:LocaliserUITests/LocaliserWideUITests/testWideStoreScreenshots test
```

| File | Caption |
| --- | --- |
| `iPhone-6.9/1-find.png` | Find your things by place |
| `iPhone-6.9/2-voice.png` | Say where it is. Check it. Save it. |
| `iPhone-6.9/3-lending.png` | Know who to ask for it back |
| `iPhone-6.9/4-trip.png` | Reuse your packing list |
| `iPhone-6.9/5-pro.png` | No account. Always yours to export |
| `iPad-13/1-find.png` to `iPad-13/5-pro.png` | The same five screens, with the sidebar, on the 13-inch iPad |
| `Duo/1-find.png` to `Duo/5-pro.png` | The same five screens on the Duo's inner screen (not an App Store size; for the website and review) |

Notes:
- **Voice memo:** `2-voice.png` is the only shot that shows voice memos. If they are cut, delete that file and upload four.
- **Duo:** a UI test's own screenshot of the Duo comes back black, so the Duo set (2853 × 2007, landscape, unfolded) is taken with `xcrun simctl io <duo> screenshot --display=3`. Put an empty file called `external` in the `STORE_SHOTS` folder: the test then writes `<name>.ready` at each screen and waits up to a minute for `<name>.done`, and a script takes the screenshot in between. The order is 2-voice, 3-lending, 1-find, 4-trip, 5-pro.
- **Reminders:** the test turns reminders on before the first shot, so Settings carries no warning badge. On a simulator where notifications were already denied, run `xcrun simctl uninstall <device> dev.hereabouts.app` first.
- **Sizes:** the 6.9-inch set is the only required iPhone size, and App Store Connect scales it down for smaller iPhones. The app runs on iPad, so the 13-inch iPad set (2064 × 2752) is required too, and App Store Connect scales it down for smaller iPads.

`night-review/` holds the same five screens in dark mode, downscaled, for checking against the night board. They are not for the store.
