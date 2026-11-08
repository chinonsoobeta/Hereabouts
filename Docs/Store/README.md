# Store screenshots

Taken 7 November 2026 on the iPhone 17 Pro Max simulator (6.9-inch, 1320 × 2868), iOS 27, light mode, default text size, status bar at 9:41. They come from the Debug-only demo library, so no real names or documents appear. The Pro shot shows the plans loaded from the local StoreKit file.

Retake them with the simulator booted and its status bar and appearance set:

```bash
xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui <device> appearance light
TEST_RUNNER_STORE_SHOTS=/private/tmp/hb-store xcodebuild -project Localiser.xcodeproj -scheme Localiser -testPlan Localiser -destination 'platform=iOS Simulator,id=<device>' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

The test also writes `review-*` design-review shots to the same folder. They are not for the store.

| File | Caption |
| --- | --- |
| `iPhone-6.9/1-find.png` | Find your things by place |
| `iPhone-6.9/2-voice-optional.png` | Say where it is. Check it. Save it. |
| `iPhone-6.9/3-lending.png` | Know who to ask for it back |
| `iPhone-6.9/4-trip.png` | Reuse your packing list |
| `iPhone-6.9/5-pro.png` | No account. Always yours to export |

Notes:
- **Voice memo:** `2-voice-optional.png` is the only shot that shows voice memos. If they are cut for 1.0, delete that file and upload four.
- **Reminders:** the test turns reminders on before the first shot, so Settings carries no warning badge. On a simulator where notifications were already denied, run `xcrun simctl uninstall <device> dev.hereabouts.app` first.
- **Sizes:** the 6.9-inch set is the only required iPhone size. The app is iPhone-only, so iPad screenshots aren't required, and App Store Connect scales this set down for smaller iPhones.

`night-review/` holds the same five screens in dark mode, downscaled, for checking against the night board. They are not for the store.
