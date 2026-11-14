# Hereabouts for Android: plan

Written 13 November 2026, at the owner's request, while build 6 was being prepared. It's a plan only. Nothing here starts until the owner says go, and the decisions in "What the owner decides" come first.

## The short version

- **Build it natively** in Kotlin with Jetpack Compose, in an `Android/` folder in this repo. Don't rewrite the iPhone app in a cross-platform toolkit.
- **Start after iPhone 1.0 is out and settled**: once it's on the App Store and the first round of fixes has shipped.
- **Android 1.0 is the iPhone 1.0 notebook.** Find, Places, homes, Trips and kits, Lent out, private things, box labels, voice, backups, Pro, widgets and the five languages. It leaves out the parts only Apple has (Siri, Spotlight, iCloud Drive) and adds what Android needs.
- **About 22 working sessions** (about a day each), then Google's 14-day closed test. Roughly 6 to 8 weeks from go to the Play Store.
- **The biggest open question isn't the build.** iCloud sync and household sharing (B4 and B6, planned for 1.1) only work between Apple devices. A household with an iPhone and an Android phone couldn't share a notebook. That needs deciding before B6 is built (decision D9).

## Why native

| Way | What it means here | Verdict |
| --- | --- | --- |
| **Kotlin and Jetpack Compose** | A second app, written for Android, that follows the iPhone app's rules and shares its test cases | **Recommended.** Best fit for the quality bar the iPhone app set (TalkBack, text size, foldables, widgets, reminders) |
| Kotlin Multiplatform | Shared logic in Kotlin, which means rewriting the iPhone app's logic too | No: it reopens a finished, tested app |
| Flutter or React Native | One new codebase for both | No: it throws away the iPhone app |
| Skip (Swift turned into Compose) | Keeps one Swift codebase | No: it doesn't cover Core Data, App Intents, WidgetKit or the on-device model, so the iPhone app would need rebuilding around it |

The iPhone app is about 9,100 lines of Swift with about 220 unit tests and 44 UI tests. An Android app of the same scope will be a similar size.

## What carries over as it is

- **The backup file** (format 3, `Localiser/Recovery/LibraryBackup.swift`). It's the bridge: someone moving from an iPhone restores their backup on Android, and back again. It gets written down first (see "The backup format, written down").
- **Send feedback.** `Server/feedback` takes the same note from Android unchanged; `system` reads "Android 16" instead of "iOS 27".
- **The rules, with shared test cases.** The Kotlin versions are checked against the same cases as the Swift ones, so both apps behave the same way:
  - voice: `LocaliserTests/Fixtures/voice-practice.json`, the same 48-of-50 bar;
  - search, including ignoring accents;
  - ask-back and reminder dates (`Dates/DateRules.swift`);
  - the Sunday recap and stocktake (`Rituals/Rituals.swift`);
  - packing quantities (`Packing/PackingStore.swift`);
  - the free plan's limits (15 things, 1 kit, 2 homes) and what happens after Pro ends;
  - plain words for every failure (`Support/PlainWords.swift`).
- **The wording, in five languages.** 825 strings in the string catalogs, converted to Android's `strings.xml` by a script. 15 have plural forms, which become Android `<plurals>`. 15 change between iPhone and iPad; those become phone and tablet versions. 25 name something Apple (iPhone, iCloud Drive, Siri, Lock Screen, Control Center, Messages) and need Android wording in all five languages.
- **The look.** Fraunces and Atkinson Hyperlegible are both under the Open Font License, so they ship on Android too. The marigold palette and the paper-and-pencil style carry over. The Circled stamp icon becomes an Android adaptive icon, with the one-color version Android 13 and later use for themed icons.
- **Pricing and the free plan.** The same three ways to pay. See D4 and D5 for what can't match.
- **The website.** The privacy page gains Android lines, and the home page gets a Google Play badge.

## From iPhone to Android

| Part | iPhone | Android |
| --- | --- | --- |
| Screens | SwiftUI | Jetpack Compose, themed to the notebook look, not stock Material |
| The notebook | Core Data (model V8), shared with the widget through an App Group, with history merging | Room (SQLite), with the same entities. The widget runs in the app's own process, so no file sharing or history merging is needed |
| iPad and the Duo | Sidebar layout, fold handling, ⌘ shortcuts | Compose's adaptive layouts for tablets and foldables (Pixel Fold, Galaxy Z Fold), Ctrl shortcuts. The Duo and iPad designs carry over |
| Keeping what's typed | Editors presented from the root so a fold keeps them (M65) | Android rebuilds the screen on a fold, a rotation, a dark mode change or a language change, and may stop the app in the background. Everything typed is kept in a ViewModel with saved state from the first day, with a test for each editor |
| Reminders (ask-back, recap, stocktake) | Local notifications | Local notifications scheduled with AlarmManager, set again after a restart. Android 13 and later ask permission. A private thing's reminder shows "Ask for something back" on the lock screen |
| Text them | Messages' compose sheet | The phone's own texting app opens with the note written and no number. The notification button needs the phone unlocked first, as on iPhone. No SMS permission |
| Choosing a borrower | Contacts picker, no permission | Android's contact picker, no permission; only the name is kept |
| Photos | Photos picker and camera | Android's photo picker (no permission) and the camera |
| Words on a photo | Vision | ML Kit text recognition, on the phone |
| Box labels | QR codes drawn and scanned on the phone; a PDF to print | A QR library to draw them, ML Kit to scan them, and Android's print service for the PDF. Letter or A4 by region, as now |
| Voice | On-device speech transcriber, English only. The recording isn't kept | Android's on-device speech recognizer (Android 12 and later). Hidden when the phone can't recognize speech on the phone, so "Nothing is recorded" stays true |
| Understanding a sentence | The rules first, then Apple's on-device model if the rules don't find a split | The same rules first, then Gemini Nano on phones that have it. Rules only elsewhere |
| Shelf photos ("Several things?") | Apple's on-device model, iOS 27 | Gemini Nano with photos, on the phones that support it (recent Pixels and some Galaxy phones). Hidden elsewhere, as on older iPhones |
| Widgets | Find and Say it buttons; Lent out | Glance widgets: the same two buttons and Lent out. Private things show as "A private thing" |
| Control Center, Lock Screen, Action button | Controls | A Quick Settings tile for "Put something away". The Action button has no equivalent |
| App icon shortcuts | Find something; Put something away | The same, as Android app shortcuts |
| Siri ("Where are my keys in Hereabouts?") | App Intents and App Shortcuts | Later. Google is moving from Assistant to Gemini, and how other apps plug into Gemini is still changing (Android 16's AppFunctions is the likely route). Decide when the build starts |
| Spotlight | Things and places in system search | Later. Android's AppSearch reaches system search on some phones only |
| Backups you make, spreadsheet, restore | Files | Android's file picker: save anywhere, Google Drive included |
| Automatic weekly backups (Pro) | The app's iCloud Drive folder, newest five kept | A folder the person picks once through Android's file picker (Google Drive appears there when it's installed), newest five kept, written weekly in the background |
| Device backup | The iPhone's own backup | Android's own backup to the person's Google account, end-to-end encrypted when the phone has a screen lock. The developer can't see it |
| Buying Pro | StoreKit 2, checked on the phone, with Family Sharing | Google Play Billing: monthly and yearly plans in one subscription, the free week as an offer on yearly, Lifetime as a one-time product. Each purchase is confirmed to Google within three days or Google refunds it. Checked on the phone with the app's Play key, since there's no server (D4) |
| Send feedback | Feedback Worker | The same Worker |

## Android 1.0 scope

**In:**
- Find, things, places, homes, moving between homes, private things, Found it and missing;
- Lent out with ask-back reminders and Text them;
- Trips and kits;
- Put away, photos, words on a photo, box labels;
- voice, in English;
- backups, restore (including iPhone backups), the spreadsheet, Erase this notebook;
- Pro, the free plan, the free week, automatic weekly backups;
- widgets, app shortcuts, the Quick Settings tile;
- the Sunday recap and stocktake;
- the introduction;
- Send feedback;
- five languages;
- phones, tablets and foldables, with TalkBack, large text and keyboard shortcuts.

**Later:**
- Gemini ("Where are my keys?");
- system search;
- shelf photos, if Gemini Nano with photos isn't widely available by then.

**Not planned:** sync with iPhones (D9); Wear OS; Chromebooks beyond what tablet support gives for free.

## Phases

| Phase | Work | Sessions | Needs first |
| --- | --- | --- | --- |
| **P0** Setup and specs | Owner decisions D1 to D3 and D10. Install the Android tools. Write down the backup format with test files both apps check against (useful to the iPhone app too). Script the string conversion. List the Android wording for the 25 Apple strings | 2 | Go |
| **P1** Foundations | The project, Room with every entity, backup restore and save matching the iPhone app on the shared files, the look (fonts, colors, cards), and the navigation shell with Find, Places, Trips, Lent out and Settings that adapts to phone, tablet and foldable | 3 | P0 |
| **P2** The notebook | Find and search, a thing's page, the editor, moving, archiving, deleting with undo, private things, places and rooms, homes, Found it and missing, box labels with scanning and printing | 4 | P1 |
| **P3** Lending, reminders and trips | Lend it, Lent out, It's back, ask-back reminders with Text them, the recap and stocktake, trips and kits with packing | 3 | P2 |
| **P4** Capture | Put away, camera and photo picker, words on a photo, voice and its rules, Gemini Nano where it's there, the Quick Settings tile, app shortcuts, widgets | 3 | P2 |
| **P5** Pro and backups | Play Billing, the Pro screen and plan card, limits, the free week, restore purchases, automatic weekly backups | 2 | P2, D4, D5, the Play products |
| **P6** Finish | Five languages, a TalkBack and text size pass, tablet and foldable layouts with keyboard shortcuts, the introduction, Settings, Send feedback, plain words for every failure | 3 | P3 to P5 |
| **P7** Check and release | An adversarial check like M64. Then the store listing (phone and tablet screenshots, five languages), the Data safety form, the content rating questionnaire, and the closed test (D2) | 2, then the closed test | P6 |

About 22 sessions in all. The closed test needs 14 days, and a personal Play account can't publish until it's done.

## The backup format, written down

Today the format only exists as Swift code. Android needs it as a document and a set of test files. This is what Swift writes now (checked 13 November), with keys sorted:

```json
{"createdAt":800000000,"records":[{"attributes":{"archived":{"boolean":{"_0":false}},"lentAt":{"date":{"_0":800000000}},"name":{"string":{"_0":"Drill"}},"photo":{"data":{"_0":"AQID"}}},"entity":"Belonging","id":"11111111-2222-3333-4444-555555555555","relationships":{"place":["AAAAAAAA-2222-3333-4444-555555555555"]}}],"version":3}
```

- **Values** are wrapped by kind: `string`, `integer`, `boolean`, `date` or `data`, each holding its value under `_0`.
- **Dates** are seconds since 1 January 2001 (UTC), not since 1970.
- **Photos** are inside the file, in base64.
- **Records** are one per entity: Belonging, Place, Movement, Deadline, ScanRecord, Kit, KitEntry, KitTask, TripRecord, TripEntry, TripTask and Home. Each has its `id` and its relationships as lists of ids.
- **Limits:** a file over 200 MB is refused, and so is a photo over 20 MB.
- **Versions:** versions 1 and 2 restore into one home. A newer version than the app knows is refused with "made by a newer Hereabouts".

From the day Android starts, the two apps share the format. Any change to it is made in both, with a new version number and new test files. The document and the test files go in `Docs/Backup/`, and both test suites read them.

## What the owner decides

- [ ] **D1 Go, and when.** Recommended: after iPhone 1.0 is on the App Store and its first fixes have shipped.
- [ ] **D2 The Google Play account.** A Play developer account costs US$25 once.
  - A **personal** account must run a closed test with at least 12 testers for 14 days before it can publish. The testers need Android phones.
  - An **organization** account skips that, but needs a D-U-N-S number.
  - As with Apple, Google shows a seller's contact details on paid apps in some regions (the EU).
- [ ] **D3 An Android phone to test on.** Voice, the camera, reminders and buying can't be fully checked on an emulator. A Samsung phone is the best single choice, because Samsung's battery saver is the most likely to delay reminders.
- [ ] **D4 Pro bought on one platform doesn't carry to the other.** Carrying it over needs accounts and a server, which Hereabouts doesn't have and shouldn't get for this. Recommended: separate purchases, said plainly in the listing and on the Pro screen. Also check purchases on the phone only (no server), accepting that a determined person could get around it.
- [ ] **D5 Family sharing.** On iPhone, Pro is shared with family (owner, 8 November). As far as I know, Google Play doesn't share in-app purchases or subscriptions with a family, so on Android Pro would belong to one Google account. Check this when the build starts.
- [ ] **D6 The oldest Android supported.** Recommended: Android 12. It's the first with on-device speech recognition, which keeps the voice promise simple. The iPhone app already supports only recent iOS.
- [ ] **D7 Tablets and foldables at launch.** Recommended: yes. The Duo and iPad work carries over, and foldables are more common on Android than anywhere else.
- [ ] **D8 The Data safety form.** Google's form has its own rules, separate from Apple's. Apple's exception for optional feedback forms may have no match there, so Send feedback may need declaring: the name, the email if given, and the message. Decide when filling it in, from Google's guidance at the time.
- [ ] **D9 Households with an iPhone and an Android phone.** iCloud sync and household sharing (B4, B6) can't include Android. Sharing across platforms needs a server holding the notebook, which runs into the same problem as smart speakers (FEATURE_PLAN, "Not in this round"). It could be done with end-to-end encryption, at the cost of accounts and running a server. Recommended: keep 1.1 on iCloud, and say in the Android listing that sharing is between Android phones only, or not offered yet. Decide before B6 is built, since building it on iCloud closes off Android.
- [ ] **D10 Installing the tools** (a download, so the owner's OK). This Mac has the Android command-line tools (Android 14 platform, build tools 34) and adb, but no Java runtime and no Android Studio. P0 installs Android Studio, which brings its own Java, plus the current Android platform and emulator images.
- [ ] **D11 Same repo.** Recommended: `Android/` in this public repo, beside the iPhone app, the Worker and the site, under the same rules. No phone numbers, emails or addresses in it.

## Rules carried over from the iPhone build

- Tests are written first and committed before the code. Commits keep the same attribution line.
- Nothing typed is lost to a fold, a rotation, a theme or language change, or Android stopping the app in the background.
- No permissions beyond notifications, the camera and the microphone. Contacts, photos and texting go through Android's own pickers.
- Voice and photos are understood on the phone only. Where a phone can't, the feature is hidden, not sent anywhere.
- Every failure is said in the app's own words, never Android's error text.
- Private things stay private everywhere: lock screen reminders, widgets, the Text them note's preview, and Gemini later.
- Nothing is uploaded, published, bought or sent without the owner's go-ahead. That covers Play uploads, testers, the listing, submitting and site deploys.
- One build at a time. Emulators count toward the limit of two simulators running at once.

## Risks

- **Two apps to keep in step.** Every later change lands twice. The shared test files (backup, voice, search, dates) catch the apps drifting apart. Codex time is limited, so I'd build both.
- **Reminders on some Android phones.** Battery savers (Samsung, Xiaomi, OnePlus) can delay or drop scheduled notifications. Use the alarm route meant for reminders, test on a Samsung, and if reminders look switched off, Settings says how to allow them.
- **On-device AI is uneven.** Gemini Nano is only on some phones. Voice works on the rules alone (they're right 48 times in 50), so only shelf photos depend on it.
- **Buying without a server.** Checking on the phone is weaker than Google's recommended server check, and the app learns about refunds late. Fine for a US$2.99 app; revisit if piracy shows up.
- **Google Play's process.** The closed test (D2), the required target Android version, the Data safety form and the content rating. Their rules change every year, so P7 checks them fresh.
- **Gemini integration is moving.** Siri's Android match isn't settled, which is why it's later and not in 1.0.

## If the owner says go

1. Answer D1 to D3, D6 and D10.
2. I write the backup format document and its test files (P0). The iPhone app's tests check against them too, so it's worth doing even before Android starts.
3. Then P1, with the same check-ins as the iPhone build: tests first, a note in this file at the end of each phase, and nothing outside this repo without a yes.
