# Localiser

Local iPhone project. No remote repository, developer backend, analytics SDK, or external publication.

Approved launch scope: finding belongings, confirmed return/warranty/expiry reminders, receipt/document OCR, packing/departure/coming-home checklists, private iCloud sync, export/recovery and a lifetime Pro unlock. Development checkpoints do not reduce the launch scope.

Open `Localiser.xcodeproj`. The project is generated from `project.yml` using the already-installed XcodeGen; there are no third-party app dependencies. Regenerate after changing target configuration with `xcodegen generate`.

The temporary bundle identifier is `dev.localiser.app`; a developer team and production identifier have not been selected. Unsigned simulator builds and local tests do not require membership. Signing, CloudKit provisioning, production purchases, real-device checks, beta participation and release approval remain explicit gates.

The approved plan is at `../outputs/Localiser-build-plan.md`. Track implementation and verification in `Docs/BUILD_STATUS.md`.

The local implementation now includes belongings/places/history, confirmed dates and reminder scheduling, on-device OCR review, packing/departure/coming-home, CSV and versioned backup/restore, private-sync configuration and lifetime Pro. Availability in source does not mean the release gates have passed.

Use the `Localiser` scheme and `Localiser` test plan. The plan selects `LocaliserTests/Localiser.storekit` for **local test purchases**, and the Run action selects the same file. It is a test-target resource, not a production app resource. Its US$49.99 price and `dev.localiser.pro.lifetime` identifier are placeholders. Remove the test configuration for production sandbox verification after configuring the actual product; never enter a real Apple account into an unexpected test prompt.

Private sync is off by default. Set the permanent bundle ID, `DEVELOPMENT_TEAM` and matching `LOCALISER_CLOUD_CONTAINER` before signed-device verification. Local export and restore do not require an account or purchase. Restore requires an empty store. Restored stores stay local, and full erase/restore is restricted for stores that previously used sync until reset/reconnection has been verified on two devices.

See `Docs/BETA_AND_RELEASE.md` for the local beta script, listing/policy drafts and missing owner inputs. Nothing has been uploaded, published or sent to testers.
