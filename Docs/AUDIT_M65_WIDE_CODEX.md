# Wide-screen and Siri audit

Reviewed `8665b49..9271306`, after reading M65–M68. No app code, catalogs, dependencies, or project settings were changed. The project was regenerated only to include the new test source.

## Evidence limits

Six regression tests are in the new audit test file, in `AuditWideTests`. They assert the requested behavior and are expected to fail for the reasons below; they have not been executed. The UI cases below follow directly from the view and state ownership, but their reproduction steps have not been run on a simulator. Treat them as source-supported findings awaiting runtime confirmation.

The requested build command was attempted twice, the second time with output captured to inspect the errors:

```sh
xcodebuild -project Localiser.xcodeproj -scheme Localiser -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/AuditWideCodex -quiet build-for-testing
```

Both attempts exited 65. The sandbox blocked compiler plug-ins: `sandbox-exec: sandbox_apply: Operation not permitted`, followed by `external macro implementation type 'ObservationMacros.ObservableMacro' could not be found` and a malformed response from `swift-plugin-server`. Core Simulator access also failed. Neither app compilation nor compilation of both test targets is confirmed. No simulator tests or physical-device checks ran.

## Ranked findings

### 1. Siri can still receive a private thing's name

- **Severity:** Privacy leak.
- **Location:** `Localiser/System/Intents.swift:48`, `:58`, and `:42`; compare the new filter at `:65`.
- **What goes wrong:** After a suggested thing becomes private, Siri can resolve its remembered ID and receive its current name, including a later private rename. Name matching also returns a private name; replacing the location with “Private” does not conceal the name in the entity title.
- **Tests:** `testSiriIdentifierResolutionDoesNotReturnAThingMadePrivate`; `testSiriNameMatchingDoesNotReturnAPrivateRenamedThing`.
- **Expected failure:** Both queries return the entity named “Hidden heirloom,” although the new shareable list is empty.
- **Suggested fix:** Apply the private-name exclusion to identifier resolution and name matching as well as suggestions.
- **Scope note:** These two lookup paths predate this range, and the existing privacy tests explicitly allow private name matching. This is a retained behavior in the M68 entity-query path that conflicts with this audit's explicit requirement to keep private names from the system, not a newly introduced lookup regression.

### 2. Resizing discards drafts in sheets still owned by a layout

- **Severity:** Data loss (unsaved input).
- **Location:** `Localiser/LocaliserApp.swift:258`; `Localiser/Places/PlacesView.swift:189` and `:278`; `Localiser/Packing/PackingView.swift:6` and `:65`.
- **What goes wrong:** New thing and item action sheets were moved above the layout switch, but place editing, adding a nested place, and trip/kit creation still belong to views below it. On a change between regular and compact, those views are replaced along with their presentation flags and editor drafts.
- **iPad steps:** Use a full-width regular window, finish the introduction, select a room in the sidebar, choose Place options → Edit, and type a distinctive replacement name without saving. Resize in Split View or Stage Manager until the app shows compact tabs, then return to full width; check that the editor and typed name are gone. Repeat from Trips → Plan a trip with an unsaved trip name, and from a room → Add a place with an unsaved nested-place name.
- **Suggested fix:** Keep these presentation flags and their draft lifetime above the compact/regular branch, as already done for New thing.

### 3. A crafted outside drag payload can move an existing thing

- **Severity:** Wrong answer (an unintended change to the recorded location).
- **Location:** `Localiser/Find/FindView.swift:215`; `Localiser/LocaliserApp.swift:412`; `Localiser/Data/LocaliserStore.swift:187`.
- **What goes wrong:** The exported drag type carries only a UUID, and the receiver has no record of an app-originated drag. Another app that knows a thing's UUID, for example from an inventory export, can offer JSON under that type and cause a move when the person drops it on a room; an exported type name does not authenticate its sender.
- **Test:** `testExternallyConstructedDragCannotMoveAThing`.
- **Expected failure:** Decoding a manually constructed `{"id":"…"}` succeeds, `moveDropped` returns 1, and the thing changes from Drawer to Shelf without an internal drag ever starting.
- **Suggested fix:** Validate a short-lived token issued for an active internal drag before allowing a drop to mutate the notebook.
- **Limit:** The test proves decoding and receiver acceptance, not the item-provider negotiation between two running apps; ordinary plain text is not accepted by the typed drop destination.

### 4. Wide-screen links to a thing in another home open Find instead

- **Severity:** Wrong answer.
- **Location:** `Localiser/LocaliserApp.swift:296`, `:468`, and `:540`; `Localiser/Find/FindView.swift:77`.
- **What goes wrong:** The root consumes a linked thing with a place and selects its room, even if that room belongs to another home. The detail renderer searches only the current home's places and falls back to Find, after the link has already been cleared; the compact Find route does not impose this restriction.
- **iPad steps:** With Pro or a restored two-home notebook, create a named thing in a room in Home B and record its UUID from an export. Switch to Home A and keep the window regular. Run `xcrun simctl openurl booted 'hereabouts://item/THING_UUID'`, substituting that UUID. Check that Find appears instead of the linked thing. Repeat with `hereabouts://place/PLACE_UUID`, using the Home B room's UUID. Repeat the item link at compact width to compare.
- **Suggested fix:** Resolve the linked object's home before choosing the wide destination, or show cross-home links through a detail route that can render them.

### 5. A home switch leaves the old compact place stack available

- **Severity:** Wrong answer.
- **Location:** `Localiser/LocaliserApp.swift:221`, `:228`, and `:234`.
- **What goes wrong:** Cleanup resets a wide room destination when it leaves the current home, but retains both the selected thing and the compact path because those objects still exist somewhere in the notebook. On the compact Places tab the person can return to the old home's room and thing while the current home is different.
- **Test:** `testHomeSwitchClearsThePreviousHomesCompactSelection`.
- **Expected failure:** The destination becomes Find, but `selectedItem` is still the old thing and `placesPath` still contains its old room and detail.
- **Suggested fix:** Clear or trim place-scoped selections and compact paths when their objects no longer belong to the current home, including after a move to another home.

### 6. A nested place is lost during a fold round trip

- **Severity:** Other (navigation state loss).
- **Location:** `Localiser/LocaliserApp.swift:209`–`:215` and `:195`–`:205`.
- **What goes wrong:** Unfolding records the top-level room and optionally a thing, but never the nested place that was open on its own. Folding again reconstructs only the room, so the person must navigate back to the drawer or shelf they were using.
- **Test:** `testNestedPlaceSurvivesACompactWideCompactRoundTrip`.
- **Expected failure:** `[room, drawer]` becomes `[room]` after the same two conversions used by the root view.
- **Suggested fix:** Preserve the selected nested place independently of the selected thing when translating the navigation state.

### 7. Unfolding closes a thing opened from Lent out

- **Severity:** Other (navigation state loss).
- **Location:** `Localiser/Places/PlacesView.swift:49`; `Localiser/LocaliserApp.swift:210`.
- **What goes wrong:** A Lent out row pushes an item directly on the compact Places tab. The conversion to the wide layout requires the first route to be a place, so it drops this valid item-only path and returns to All places.
- **Test:** `testThingOpenedDirectlyFromPlacesSurvivesUnfolding`.
- **Expected failure:** After adopting `[.item(drill.id)]`, neither the wide item selection nor the Find item selection contains the drill.
- **Suggested fix:** Resolve an item-only compact path to that item's place and selection, with a Find fallback for a thing without a place.

### 8. Find and Trips detail navigation is not carried across layouts

- **Severity:** Other (navigation state loss).
- **Location:** `Localiser/Find/FindView.swift:179`; `Localiser/LocaliserApp.swift:305`, `:363`, and `:470`; `Localiser/Packing/PackingView.swift:36`.
- **What goes wrong:** Find's visible result rows still use destination-based links rather than `ui.findItem`, and the compact Trips stack has no saved navigation path. When the root replaces those stacks, a thing opened from search closes; a trip selected in the wide sidebar also collapses to the Trips list at compact width.
- **iPad steps:** At regular width, search for an existing thing and tap its result. Resize to compact and verify the thing's detail closes; return to regular and check it does not reopen. Separately, select an active trip directly in the regular sidebar, resize to compact, and verify the Trips list appears instead of that trip. Open a trip from the compact list and return to regular to test the other direction.
- **Suggested fix:** Use the existing window selections for actual Find row navigation and persist the trip/kit destination in both layouts.

## Checks that held up on inspection

- New thing creation still reaches `ItemEditor.save()` and its current free-plan check, including the sidebar and Command-N routes; kit and home creation still reach their existing limit checks. Opening an editor is not itself a limit bypass.
- Same-place drops skip a move; source and destination in different homes skip a move; missing item IDs are ignored. Accepted drops call the existing `move`, so history, confirmation dates, home assignment, save/refresh, and widget reload follow the existing move path. Lent and packed status are not cleared by that path. Nested destinations are accepted by the store helper, although the sidebar exposes only top-level rooms.
- Private drag previews explicitly use “Private”; payloads contain no names. Sidebar counts expose quantities, not private names. The commands use fixed labels and the new navigation titles do not name individual private things.
- The new suggested-entity list excludes private, archived, and deleted things, sorts by confirmation date, and caps at 100. Its scope covers all homes, consistent with cross-home search. Deleted identifiers do not resolve. Archived identifiers still resolve through the older direct-ID path and receive the existing archived answer; they are excluded from the new suggestions and string search.
- Store saves, restores, imports, undo refreshes, and remote-change refreshes reach the new scheduling call. The scheduler cancels the prior task and checks cancellation before updating, so a synchronous burst is coalesced. `switchHome` only increments the revision and does not schedule an update, despite the comment in `refresh`; the published list covers all homes, so a home switch alone does not change its contents.
- Direct JSON inspection found 75 top-level device variations: all had iPad branches, matching format specifiers, and no unexpected iPhone wording. The camera permission text uses “device” in all five languages. Existing localization tests also cover plural/device combinations and Siri tip-to-phrase matching; those tests were read, not run.
- The added Siri phrases retain the application-name placeholder and thing parameter in the five languages. The tips teach matching app-qualified phrases.
- Keyboard handlers check onboarding, window-owned sheets, and UIKit presentations before acting. No free-limit bypass was found in the Command-N save path. Timing of repeated key presses, native purchase dialogs, and multiwindow focus remains unverified.
- `scripts/check-release.sh` completed with exit 0 on the current source configuration. This verifies its source checks only; no successfully built bundle was available to test its bundle checks.
- `xcodegen generate` completed with exit 0. The generated project diff only registers the audit test file. `git diff --check` passed.
- A syntax-only parse of the new test source with `xcrun swiftc -frontend -parse` completed with exit 0; this does not establish that its types compile or that its assertions ran.

## Runtime checks still needed

The simulator boundary prevented testing fold/resize timing, held voice capture, repeated shortcuts, incoming links during an open sheet, StoreKit purchases/restores in progress, and simultaneous external changes during a Siri question. Also check dropping onto a place deleted while the drag is held and large runs of rapid drops; the helper does not explicitly validate that its target place is still live. These are unverified cases, not additional claimed crashes or proven corruption.

The root preserves the Settings page path, but state inside that page is local: the selected purchase plan, restore confirmation, importer/exporter, and deeper backup-file navigation need checks during a compact/regular transition. No claim is made that an in-progress synchronous notebook restore can be interrupted by resizing.
