# Wide-screen and Siri audit, second half

The adversarial check (M65) of M66, M67 and M68: `8665b49..9271306`. Codex's half is in [AUDIT_M65_WIDE_CODEX.md](AUDIT_M65_WIDE_CODEX.md). Its sandbox couldn't compile or reach a simulator, so its findings are from the source. Mine were run on the iPad Pro 13-inch simulator (iOS 27.0), using the demo library and a second home added through Settings › Homes.

## My findings

### C1. Leaving a Settings page on a wide screen crashes the app

- **Severity:** Crash. Every iPad, and the Duo unfolded.
- **Steps:** Open Settings in the sidebar. Open any page in it: Hereabouts Pro, Homes, Take your notebook with you, or Acknowledgments. Tap any other sidebar row, such as Garage. The app quits.
- The same happens when a thing's link arrives while a Settings page is open (tested). Spotlight results, reminders, the widget, box labels, Home Screen quick actions and ⌘1 to ⌘4 change the same selection, so they should crash the same way.
- **Crash:** `EXC_BREAKPOINT` in `swift_unexpectedError`, from SwiftUI's `NavigationColumnState.boundPathChange(to:environment:)`. Reproduced three times: twice from a link, once from a sidebar tap.
- **Where:** `Localiser/LocaliserApp.swift:477`. The detail column switches from `NavigationStack(path: $ui.settingsPath)` with a page pushed to a stack with no bound path. `settingsPath` (`:171`) keeps the page after you leave.
- **Not caught by tests:** the wide UI tests open Settings pages and fold with one open, but none leaves a page through the sidebar.

### F1. On a wide screen, a link to another home's thing or place shows Find with nothing open

- **Severity:** Wrong answer. Same as Codex's 4.
- **Steps:** Add a second home and switch to it. Run `xcrun simctl openurl <ipad> hereabouts://item/<id of a thing in the first home>`. Find shows, and nothing opens. On an iPhone the same link opens the thing.
- **Where:** `LocaliserApp.swift:296` reveals the thing's room even when it's in another home. `wideDetail` (`:468`) only looks in the current home, so it falls back to Find. `FindView.swift:77` leaves the link to the root, and the root has already cleared it. Place links (`:540`) go the same way.

### F2. On a wide screen, a box label opens the room, not the box

- **Severity:** Wrong answer.
- **Steps:** With the demo library, run `xcrun simctl openurl <ipad> hereabouts://place/<Rack 2's id>`. Rack 2 is inside Garage › Back wall. The detail shows Garage, not Rack 2. On an iPhone, the label opens Rack 2 itself, with "Put things in this box" (`PlacesView.swift:73`, `fromLabel: true`).
- **Where:** `WindowState.reveal` (`LocaliserApp.swift:188`) keeps only the top-level room. `WidePlaceView` has no way to open a nested place.

## Codex's findings, triaged

| # | Finding | Decision |
| --- | --- | --- |
| 1 | Siri can resolve a private thing's name | **Not a bug.** People can ask for a private thing by its name. Siri answers "That one's private" and never gives the place. Name matching needs the person to say the name, so there's nothing to give away. A Shortcut holding an old ID belongs to the person who made it. The new suggested list never includes private names. The existing privacy tests say the same. |
| 2 | Resizing or folding drops a half-typed place, nested place, trip or kit | **Fix.** Keep those editors above the layout switch, as New thing already is. |
| 3 | Another app could drop a made-up drag payload | **Harden.** Low risk: the person has to drop it themselves, and it needs a thing's ID from their own export. Mark the drag type for this app only, so a thing's drag data stays in the app. |
| 4 | Links to another home on a wide screen | **Fix.** Same as F1. |
| 5 | A home switch leaves the old home's place stack on the Places tab | **Fix.** |
| 6 | A nested place is lost on a fold round trip | **Fix**, along with F2. |
| 7 | A thing opened from Lent out closes when unfolding | **Fix.** |
| 8 | A thing opened from search, or a trip, closes on a layout change | **Fix.** |

## Also found

- **"Where are my keys?"** People ask for plural things this way. None of the Siri phrases cover "Where are my … in Hereabouts". Add one in all five languages. There are 8 phrases that take a thing; at the cap of 100 names that's 800, under the system's 1,000.
- **French and Portuguese possessives are masculine only.** "Où est mon …" and "Onde está meu …" don't cover "ma valise" or "minha mala". Make the "Where's my" phrase carry the feminine form in those two languages ("Où est ma …", "Onde está minha …"). The masculine form stays on "Where is my", and the tips keep working.

## Checks that held up

- ⌘N and the sidebar's "Add a thing" reach the same free-limit check when saving.
- There are no second windows: the app doesn't declare multiple scenes.
- Every device variation in the catalogs has an iPad branch in all five languages.
- A thing's drag carries only its ID, and a private thing's drag preview says "Private".
- M68's suggested list leaves out private, archived and deleted things. It is refreshed after every save, restore, import and remote change, and a burst of saves gives one update.

## Status

Fixes go to builders, then every test runs again: unit tests on the iPad and both iPhones, the full UI suite on iPhone 27, and the wide tests on the iPad and the Duo. Each fix gets a failing test first. Codex's tests for 3, 5, 6 and 7 come in with the fixes, not before. Its two Siri tests are dropped, because finding 1 isn't a bug.
