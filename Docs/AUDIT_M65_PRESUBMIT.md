# Pre-submission audit (M65), 14 November

The owner asked for two adversarial audits of the build that will be submitted, once the hint cards were in (14 November): one by Claude, one by Codex (GPT 6.1 Sol, medium reasoning, read-only). They worked separately. Codex's scope was the diff since `7c07cd6` (hint cards, shelf-photo capitals, strings), the Send feedback path end to end against the privacy claims, and a sweep for App Review risks (2.1, 3.1, 5.1) and data loss.

Each finding got a failing test first (`ac325c6`, `b167966`), then the fix (`5cf4d26`).

## Found and fixed

| # | Found by | Severity | What went wrong | Fix |
|---|---|---|---|---|
| 1 | Codex | Should fix | Voice: tapping Cancel while the speech model was still downloading closed the sheet, but the suspended start carried on and turned the microphone on afterwards, with nothing left to stop it. | `VoiceCapture.Attempts`: each start gets a number, and Cancel retires it. A start checks after every wait and stops quietly once it is no longer the current one. |
| 2 | Codex | Should fix | Send feedback sent the phone's language, but the form, `Site/privacy.html` and `BETA_AND_RELEASE.md` didn't list it. Apple's optional-disclosure rule for feedback forms needs the page to show everything that is sent. | The form now names the language (for example "French (Canada)") along with the versions, in every language. The policy and the release notes list it too. The privacy page needs redeploying, which needs the owner's yes. |
| 3 | Codex | Should fix | An automatic backup that failed to save (iCloud Drive full, for example) was silently dropped. Settings kept showing the last good date. | `AutomaticBackups.lastFailure` is set when a backup fails and cleared by the next one that works. Settings › Backups shows a warning line until then, with iPad wording. |
| 4 | Both | Minor | The "Moved it?" card said "Tap Move" on a thing with no place, where the button reads "Choose a place…". | `Hint.suggestsMove` needs a place, an active thing, and put-away mode off. |

## Checked and fine

- **Hint cards:**
  - Dismissal persists, and "Turn on" switches put-away mode on.
  - At accessibility sizes the buttons stack.
  - Tap areas are 44 points.
  - The new strings are in all five languages.
  - No TipKit is left (a test scans for it).
- **Shelf photo names:**
  - Capitals are added.
  - iPad, eBook and USB are kept as written.
  - Duplicates are removed ignoring case.
  - Unticking keeps the capitals; the owner checked this on build 7.
- **Feedback transport:**
  - Uses HTTPS and an ephemeral session.
  - The server checks length and fields, and rejects newlines in headers.
  - Reply-To is optional.
  - Nothing from the notebook is sent.
- **Purchases:**
  - Verified entitlements, revocation, restore and localized prices.
  - The trial is shown only to eligible people.
  - The renewal wording is present.
  - Free limits are 15 things, 1 kit and 2 homes. Editing and export still work without Pro.
- **Data:**
  - Restore validates the file before replacing anything, with a staged save and rollback.
  - The App Group migration checks the copy before removing the original.
- **Privacy:**
  - All three privacy manifests parse, and the UserDefaults reasons are declared.
  - The camera, photo and microphone usage strings are localized.
  - Private things stay out of Spotlight, and Siri doesn't say their places.
- **App Store Connect:** the age rating's new social-media questions are already answered No.

## Open

- **Build 4 crash report.** One crash came in from a tester on 12 November (iPhone 17 Pro Max, iOS 27.2.1), and it doesn't match a known cause. It was on build 4, and builds 5 to 7 changed the code since. Reading it means downloading the report, which waits for the owner's OK.
- **What neither audit covered.** Device behaviour, live StoreKit, Cloudflare settings and the packaged resources of the submission archive. Those are checked by `scripts/check-release.sh` and the owner's check of the build on the phone.
