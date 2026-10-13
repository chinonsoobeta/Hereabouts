# Hereabouts: owner handoff

Everything that can be built and checked on this Mac is done or tracked in BUILD_STATUS.md. These items need the owner.

| Item | Why it needs you | What to do |
| --- | --- | --- |
| Website and support email | The app links to `https://hereabouts.app` and `support@hereabouts.app`. These are placeholders, not registered. | Register a domain and mailbox, or pick existing ones. Set `HEREABOUTS_SITE_URL` and `HEREABOUTS_SUPPORT_EMAIL` in `project.yml`, then run `xcodegen generate`. |
| Privacy and support pages | App Store review requires a reachable privacy policy and support page. Drafts are in `Site/`. | Host `Site/privacy.html` and `Site/support.html` at `/privacy` and `/support` on the chosen site. Terms link to Apple's standard licence. Update the email address in both pages if it changes. |
| Apple Developer Program | The free Personal Team can't use TestFlight, App Store distribution or App Groups for the widget. | Enrol (US$99 a year), then set `DEVELOPMENT_TEAM` in `project.yml`. |
| Due soon widget | A widget extension reads the library through an App Group, which a free Personal Team can't create. Siri and Spotlight are built and don't need one. | After enrolment, ask for the widget to be built. The plan is in AUDIT_AND_LAUNCH_PLAN.md section 4.3. The app already handles `hereabouts://due` and `hereabouts://item/<id>` links for it. |
| App Store Connect products | Pricing changed on 12 Oct to a subscription (US$2.99 a month or US$19.99 a year, each with a two-week free trial) or US$49.99 for lifetime. The app still has the old one-off until that's built. | Don't create the old US$4.99 product. Settle the bundle ID first, then create the three products listed under "Owner tasks" in `FEATURE_PLAN.md`. |
| App icon | The icon is still the pin-and-box mark from the Localiser days, one flat image with no dark or tinted version. It works, but it predates the notebook look, and iOS 26 draws dark, clear and tinted icons best from a layered Icon Composer file. | Decide whether the mark stays. Then make it in Icon Composer, or ask for a layered version of the current one. |
| Name clearance | "Hereabouts" needs a trademark and App Store name check. | Search the App Store and trademark registers before submitting. |
| TestFlight beta | Real people and real receipts can't be simulated. | After enrolment, upload a build and invite testers using `Docs/BETA_AND_RELEASE.md`. |
| Physical-device checks | Camera capture, real notifications over days, VoiceOver and older phones need hands on a device. | Follow the physical matrix in `Docs/BETA_AND_RELEASE.md` with synthetic documents first. |

Nothing has been uploaded, published, purchased or sent to anyone.
