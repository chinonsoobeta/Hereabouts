# Quality checks

Scores the voice parser (what a spoken sentence becomes) and search (what a typed query finds) against fixture
files, and times search over 1,000 things. Run with the rest of the unit tests:

    xcodebuild ... -only-testing:LocaliserTests/QualityTests test

Each test prints its score (look for `Quality capture:` and `Quality search:`) and fails only below the
`threshold` in its fixture. To use new examples, replace the contents of the two JSON files and keep the shape.
Keep these separate from the practice sentences in `Fixtures/voice-practice.json`, which the parser was tuned on.

## quality-capture.json

    {
      "threshold": 0.8,                       fraction that must be right, 0 to 1
      "places": ["Attic", "Attic › Trunk"],   the notebook's places, as paths joined with " › "
      "sentences": [
        {"text": "my winter gloves are in the attic trunk",   what was said
         "name": "Winter gloves",                              the thing's name (case doesn't matter)
         "place": "Attic › Trunk"}                             the place's path, or null
      ]
    }

Use `null` for a place the notebook doesn't have, or one that fits more than one place: the parser must leave it
unfilled. A sentence is right when the name and the place both match.

## quality-search.json

    {
      "threshold": 0.8,
      "topN": 3,                              a pair is a hit when the expected thing is in the first topN results
      "things": [
        {"name": "Passport", "aliases": "travel document", "place": "Study › Filing cabinet", "notes": ""}
      ],
      "pairs": [
        {"query": "travel document", "expect": "Passport"}   expect is a thing's name
      ]
    }

`aliases` is one name per line. Places are created from their paths, so a thing's place can be several levels deep.
