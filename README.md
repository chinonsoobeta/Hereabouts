# Localiser

Local iPhone project. No remote repository, developer backend, analytics SDK, or external publication.

Approved launch scope: finding belongings, confirmed return/warranty/expiry reminders, receipt/document OCR, packing/departure/coming-home checklists, private iCloud sync, export/recovery and a lifetime Pro unlock. Development checkpoints do not reduce the launch scope.

Open `Localiser.xcodeproj`. The project is generated from `project.yml` using the already-installed XcodeGen; there are no third-party app dependencies. Regenerate after changing target configuration with `xcodegen generate`.

The temporary bundle identifier is `dev.localiser.app`; a developer team and production identifier have not been selected. Unsigned simulator builds and local tests do not require membership. Signing, CloudKit provisioning, production purchases, real-device checks, beta participation and release approval remain explicit gates.

The approved plan is at `../outputs/Localiser-build-plan.md`. Track implementation and verification in `Docs/BUILD_STATUS.md`.

