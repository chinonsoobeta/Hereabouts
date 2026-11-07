# Store screenshots

Taken 10 October 2026 on the iPhone 17 Pro Max simulator (6.9-inch, 1320 × 2868), iOS 26.5, light mode, default text size, status bar at 9:41. They come from the Debug-only demo library, so no real names or documents appear.

Retake them with:

```bash
TEST_RUNNER_STORE_SHOTS=/private/tmp/hb-store xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test
```

Set the status bar first with `xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100`.

| File | Suggested caption |
| --- | --- |
| `iPhone-6.9/1-find.png` | Your house's notebook |
| `iPhone-6.9/2-search.png` | Find anything by where it lives |
| `iPhone-6.9/4-due.png` | Never miss a return |
| `iPhone-6.9/5-trips.png` | Pack once, reuse forever |
| `iPhone-6.9/6-recap.png` | One quiet recap on Sundays |
| `iPhone-6.9/7-stocktake.png` | Still there? Keeps itself honest |

Before uploading:
- **Due:** the test turns reminders on before the first shot, so Due shows reminders queued and no screen carries the warning badge. The name-only capture test turns notifications off until the app is deleted, so on a simulator that has run the full suite, first run `xcrun simctl uninstall <device> dev.hereabouts.app`. If you forget, the test stops and says so.
- **Pro:** not included. The iOS 26.5 simulator's local StoreKit service doesn't load the product (the purchase unit tests skip there for the same reason), so the Pro screen says Pro isn't available. Take it from a sandbox build once the App Store Connect product exists.
- The app is iPhone-only, so iPad screenshots aren't required. App Store Connect scales the 6.9-inch set down for smaller iPhones.

`night-review/` holds the same eight screens in dark mode, downscaled, for checking against the night board. They are not for the store.
