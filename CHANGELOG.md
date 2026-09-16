# Changelog

All notable changes to Quatuor are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- The app bundles the icon `make icon` generates. It shipped a copy placed by
  hand before the charter, while the generated `.icns` was versioned and unused.

### Changed
- Stem names and error messages go through `Localizable.xcstrings` like every
  other user-visible string; they were hard-coded in French.
- The test suite covers audio decoding, MP3 encoding and temporary-file
  cleanup, in place of the Xcode template stubs.

### Removed
- The UI test target: template stubs that drove the app on screen and asserted
  nothing.
- `logo.png`, `capture.png`, `Scripts/fetch_models.sh`, the asset catalogue and
  three unreachable error paths — nothing referenced any of them.

## [0.1.0] — 2026-09-16

### Added
- Initial release.

[Unreleased]: https://github.com/gwenn-ha-dev/Quatuor/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gwenn-ha-dev/Quatuor/releases/tag/v0.1.0
