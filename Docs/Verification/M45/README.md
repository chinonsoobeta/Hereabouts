# Fresh-install Release walkthrough (M45)

`testFreshInstallReleaseWalkthrough` on an iOS 27 simulator, Release build, fresh install, 7 November 2026.

| Step | Result |
| --- | --- |
| 1. Skip the introduction | Passes (`1-introduction`) |
| Find straight after install | Both Siri tips show at once; the where-is tip appeared about 2 s after Find opened (`2a`, `2b`) |
| 2. Settings, then Pro | Screen opens. **No plans:** "Pro isn't available to buy right now" (`2-settings`, `3-pro`) |
| 3. Add 15 things | Passes (`4-fifteen-things`) |
| 4. The 16th thing | Opens the paywall instead of saving, again without plans (`5-paywall-on-16th`) |

**Why the plans are missing.** A Release build on an iOS 27 simulator gets no products from the local StoreKit file. This happened on two iOS 27 simulators. The product code (`ProAccess.swift`) is the same in Debug and Release, and the same session loads all three plans in Debug on `HB Store 27` (the M46 screenshots and `testSettingsExportsAndProAreReachable`). On the first simulator, `HB Walkthrough 27`, Debug didn't load them either, so the local StoreKit service on a simulator isn't dependable. Plans in a Release build are proven by O35 (sandbox purchase on a device) and O36 (TestFlight), which use the App Store's sandbox, not this file.
