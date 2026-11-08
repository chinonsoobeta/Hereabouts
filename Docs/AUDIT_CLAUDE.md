# Adversarial audit: Claude's half (M64)

This half of the audit tried to break the app's data, privacy and money code from the inside: the store, packing, places and homes, App Intents, backups and restore, the free limits, reminders, Spotlight, the widget and links. It worked independently of the Codex half and didn't read it.

Each confirmed finding has a failing test in `LocaliserTests/Audit/AuditClaudeTests.swift`. Before any fix, all three tests fail on iOS 26.5 and iOS 27 (3 tests, 6 failed assertions on each). A fix is done when its test passes and the rest of the suite stays green.

**All three are fixed** (7 November). With the fixes, the unit tests pass: 161 run on iOS 27 with 0 failures, and 161 run on iOS 26.5 with 6 skipped (the StoreKit purchase tests) and 0 failures.

## Findings, most serious first

### F1. Putting a packed thing back after its place was deleted leaves it with no place

*Fixed in `b71be59`.*

- **Severity:** Medium. It loses where a thing lives, and the delete dialog promised otherwise.
- **Where:** `Localiser/Data/LocaliserStore.swift:218` (`deletePlace`) and `Localiser/Packing/PackingStore.swift:132` (`resolveHome`, `.putBack`).
- **What happens:**
  1. A thing in Hall › Drawer is packed for a trip.
  2. While the trip is away, the person deletes Drawer. The dialog says "Everything inside moves to "Hall". Nothing else is deleted." (`Localiser/Places/PlacesView.swift:267`), and the thing does move to Hall.
  3. The trip's packing entry still points at Drawer as the thing's home. The data model's Nullify rule (`TripEntry.homePlace`) quietly empties it.
  4. Coming home, the button reads "Put back: no place yet". Tapping it moves the thing out of Hall and leaves it with no place at all.
- **Why:** `deletePlace` moves items and child places up a level but never touches the packing entries that remember the place. `mergeSparePlaces` does this correctly (`Localiser/Places/DuplicatePlaces.swift:26`).
- **Test:** `testPuttingBackAPackedThingAfterItsPlaceIsDeletedKeepsAPlace`
- **Suggested fix:** in `deletePlace`, before deleting, point every trip entry whose `homePlace` is the deleted place at `place.parent`, mirroring `mergeSparePlaces`. Then "Put back" reads "Put back: Hall" and does what it says.

### F2. Automatic backups stop for as long as the clock was once set ahead

*Fixed in `222b08a`.*

- **Severity:** Medium impact, rare. Pro's weekly safety net goes quiet without an error.
- **Where:** `Localiser/Recovery/AutomaticBackups.swift:51-56` (`isDue()`).
- **What happens:**
  1. A backup, or a failed try, runs while the iPhone's clock is set ahead. This can happen after a manual date change, a time-travel trick in a game, or a clock that was wrong before the network corrected it.
  2. The stored date is now in the future. `current.timeIntervalSince(last)` is negative, so it is always less than a week (or less than a day for a failed try).
  3. No automatic backup runs until the real date passes that future date. With a year's jump, that's a year without backups.
  4. Settings shows "Last backup in 1 year", which is the only sign.
- **Test:** `testAutomaticBackupsAreDueAgainOnceTheClockIsCorrected` checks a last backup and a failed try, each dated a year ahead.
- **Suggested fix:** treat a last-backup or attempt date later than now as missing, so a backup is due. Optionally clear the stored date so Settings stops showing a future time.

### F3. A blank search from Shortcuts or Siri lists private things

*Fixed in `419146c`.*

- **Severity:** Low. A person needs the unlocked phone, but it breaks a stated promise.
- **Where:** `Localiser/System/Intents.swift:54-57` (`ThingQuery.matches`) and `Localiser/Find/Search.swift:54`.
- **What happens:**
  1. The rule written above `matches` says a private thing is only found by its name or another name.
  2. The filter keeps a private thing when `ItemSearch.score(...)` isn't nil.
  3. For an empty or whitespace-only query, `score` returns 0 rather than nil (`guard !query.isEmpty else { return 0 }`), so every private thing passes.
  4. As a result, a blank search in the Shortcuts thing picker lists private things by name. The picker's suggestions (`suggestedEntities`) correctly leave them out.
- **Test:** `testABlankSiriSearchDoesNotListPrivateThings` checks `""`, `" "` and `"\n"`. Searching by name still finds the private thing.
- **Suggested fix:** in `matches`, return no private things when the trimmed query is empty, or have the private check require a non-empty normalized query. Don't change `ItemSearch.score` itself, because Find relies on an empty query matching everything.

## Considered and accepted by design

- **Restore isn't held to the free limit.** A Pro user whose subscription lapsed must be able to restore their own notebook. Getting past the limit this way means writing a backup file by hand.
- **Restore accepts names up to the backup format's own limit, not the app's 120-character typing limit.** A stricter check could turn away older backups that are genuinely the person's own.
- **The lent-out widget shows who has a private thing.** This is deliberate: it names the person, not the thing.
- **Two Add Thing shortcuts at once can't both pass the free limit.** The check and the save run together on the main actor after the only suspension point.
- **Undo after a deletion can't sneak past the free limit.** Any other save closes the undo window (`LocaliserStore.swift:148`), so adding a thing first ends it.
- **Undo against outside changes.** In 1.0 the widget and intents don't write while the app is open, so the undo stack can't go stale.
- **Lending a thing that's already lent.** The Find screen only offers "Lend" for things at home (`FindView.swift:565`).

## Tried and held up

- **Free limits.** Every route that adds or brings back a thing checks `ProAccess.allows`: new thing, unarchive, the Add Thing intent, onboarding, shelf photos, kits and homes. Archived things don't count.
- **Export and backup when Pro has lapsed.** Neither is gated, so a lapsed user can always take their notebook with them.
- **Reminders.** Private things are named generically on the Lock Screen. Daylight saving changes, time zone moves and the Sunday and monthly rituals schedule correctly.
- **Box labels and Spotlight.** Box labels leave out private things. Spotlight leaves out private and archived things.
- **Logging.** Nothing writes thing names, places or notes to the system log.
- **Voice.** Speech is transcribed on the iPhone, starts only on a tap, and no recording is kept.
- **Links.** Deep links validate the UUID and ignore unknown hosts and paths.
- **Backup validation.**
  - Relationship inverses, place cycles, enum values and counts are checked before anything is written.
  - A bad file leaves the notebook untouched.
- **CSV export.** Cells that start with `=`, `+`, `-` or `@` are escaped, so a spreadsheet won't run them as formulas.
- **Homes.** Only an empty home can be deleted, and never the last one.
