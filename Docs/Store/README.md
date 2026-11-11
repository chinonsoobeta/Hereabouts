# Store screenshots

The iPhone set was taken 7 November 2026 on the iPhone 17 Pro Max simulator (6.9-inch, 1320 × 2868), iOS 27, light mode, default text size, status bar at 9:41. The iPad set (`iPad-13/`, 2064 × 2752, upright) was taken on 8 November on the iPad Pro 13-inch (M5) simulator, iOS 27, the same way. They come from the Debug-only demo library, so no real names or documents appear.

Retaken 10 November (owner, O37): shot 5 is now a room with a box inside (`5-places.png`) instead of the Pro screen, because the English (U.S.) shots stand in for every country and the Pro screen showed US prices. The lending shot now shows the demo's drill, lent two evenings ago, so its history line no longer reads later than the 9:41 status bar. The Pro screen, with the plans from the local StoreKit file, is kept as `Review/pro.png` for the products' review screenshots (O22). All five shots in each set were retaken together, so each set comes from one run. The iPhone set was retaken on the iPhone 18 Pro Max simulator (also 1320 × 2868), because the 17 Pro Max simulator is no longer installed; the iPad set on the iPad Pro 13-inch (M5) and the Duo set on the stock iPhone Duo, all iOS 27.2.

Retake them with the simulator booted and its status bar and appearance set:

```bash
xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui <device> appearance light
TEST_RUNNER_STORE_SHOTS=/private/tmp/hb-store xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=<device>' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

The test also writes `review-*` design-review shots to the same folder. They are not for the store, except `review-pro.png`, which becomes `Review/pro.png`. Since the Pro screen was redesigned (10 November) it opens on your plan and Free and Pro side by side, so for this shot the test scrolls the ways to pay to the top: App Review checks the plans, the prices and the trial terms.

The iPad and Duo shots come from a separate test, in portrait. `STORE_SHOTS` is the folder, and the test writes the five files straight into it, then `review-pro.png` and `review-pro-more.png` of the Pro screen for checking the wide layout (not for the store):

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
| `iPhone-6.9/5-places.png` | Every room, shelf and box |
| `iPad-13/1-find.png` to `iPad-13/5-places.png` | The same five screens, with the sidebar, on the 13-inch iPad |
| `Duo/1-find.png` to `Duo/5-places.png` | The same five screens on the Duo's inner screen, for App Store Connect's iPhone Duo slot |

Notes:
- **Voice memo:** `2-voice.png` is the only shot that shows voice memos. If they are cut, delete that file and upload four.
- **Duo:** a UI test's own screenshot of the Duo comes back black, so the Duo set (2853 × 2007, landscape, unfolded) is taken with `xcrun simctl io <duo> screenshot --display=3`. Put an empty file called `external` in the `STORE_SHOTS` folder: the test then writes `<name>.ready` at each screen and waits up to a minute for `<name>.done`, and a script takes the screenshot in between. The order is 2-voice, 3-lending, 1-find, 4-trip, 5-places. `simctl` saves the capture with an alpha channel, which App Store Connect can refuse, so the files here are redrawn onto an opaque canvas (every pixel was already opaque, so nothing changes visually).
- **Reminders:** the test turns reminders on before the first shot, so Settings carries no warning badge. On a simulator where notifications were already denied, run `xcrun simctl uninstall <device> dev.hereabouts.app` first.
- **Sizes:** the 6.9-inch set goes in the "iPhone with Dynamic Island (large display)" slot. App Store Connect lists the 6.1/6.3-inch iPhone (1206 × 2622) as the required size, and fills it from the 6.9-inch set ("Using Existing Assets"), so one iPhone set covers every iPhone. The app runs on iPad, so the 13-inch iPad set (2064 × 2752) is required too, and App Store Connect scales it down for smaller iPads. App Store Connect also has an iPhone Duo slot, which takes 2853 × 2007 (landscape) or 2007 × 2853.

`night-review/` holds the same five screens in dark mode, downscaled, for checking against the night board. They are not for the store.
