# Fresh-install walkthrough (M45)

`testFreshInstallReleaseWalkthrough` on an iOS 27 simulator, Release build, fresh install, 7 November 2026.

| Step | Result |
| --- | --- |
| 1. Skip the introduction | Passes (`1-introduction`) |
| Find straight after install | Both Siri tips show at once. The where-is tip's text appeared about 2 s after Find opened (`2a`, `2b`) |
| 2. Settings, then Pro | The screen opens, but **no plans**: "Pro isn't available to buy right now" (`2-settings`, `3-pro`) |
| 3. Add 15 things | Passes (`4-fifteen-things`) |
| 4. The 16th thing | Opens the paywall instead of saving, again without plans (`5-paywall-on-16th`) |

## Why the plans are missing

It's the simulator's StoreKit testing, not the app. Checked on `HB Store 27` the same evening:

1. Fresh install, then the Pro UI test with the local StoreKit session open: no plans.
2. One StoreKit unit test, which applies the test plan's StoreKit file to the app.
3. The same Pro UI test again: all three plans and the trial button.

So the app sees the local plans only after a unit test has run since it was installed, and the UI test's own session doesn't change that. A fresh install, which this walkthrough needs, can't show plans in a simulator, in Debug or in Release. The product code (`ProAccess.loadProduct`) is the same in both configurations. The Pro screen asks for the products again every time it opens, so a failed load isn't permanent.

The plans in a real build are proven on a phone: by O35 (sandbox purchases) and by rehearsing the reviewer walkthrough in `BETA_AND_RELEASE.md` (steps 7 and 8). Both use the App Store's sandbox, not this file.

The first StoreKit unit test after a fresh install also failed once (`testRefundLocks`: the purchase took longer than the test waits). All seven subscription tests passed when run again straight after.
