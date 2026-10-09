# Changelog

All notable changes to Quatuor are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] — 2026-10-09

First release under the name Quatuor, as a signed and notarized `.dmg`. The
earlier releases were published as Stem, under another bundle identifier:
Quatuor installs beside it rather than over it, and downloads its model again.

### Added
- The app is distributed as `Quatuor-2.0.0.dmg`, signed with a Developer ID,
  notarized and stapled.
- README captures in English and French, taken by `outils/captures.sh` on a
  public-domain song; a social preview; a project site (`site/`).
- `make sign`, `make dmg`, `make shots`, `make release-check`.
- A file handed over at launch (`open -a Quatuor song.mp3`) opens in the window.
- The window opens tall enough to show the four stems without scrolling.

### Fixed
- The archive failed to link: it built an x86_64 slice, which neither MLX nor
  the arm64-only libmp3lame can provide. The app is built for Apple Silicon only.
- The loaded file's details were formatted by hand: "44.1 kHz" kept its decimal
  point and "ch" stayed untranslated in French. They now follow the language
  ("44,1 kHz · 2 canaux"), and the duration is truncated like the player's.
- The solo button's "S" and the progress percentage were missing from the
  string catalogue (the percentage was catalogued under a key the code never
  looked up).
- The download screen announced a ~336 MB model; it is ~670 MB.
- Quitting from the result screen left the four temporary WAV files behind.
- The app bundles the icon `make icon` generates. It shipped a copy placed by
  hand before the charter, while the generated `.icns` was versioned and unused.

### Changed
- The model cache and the temporary stem directories carry the app's own name;
  they were still written under the previous one.
- The project compiles in the Swift 6 language mode, which both README badges
  already claimed; it was building in Swift 5 mode.
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

[Unreleased]: https://github.com/gwenn-ha-dev/Quatuor/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/gwenn-ha-dev/Quatuor/releases/tag/v2.0.0
[0.1.0]: https://github.com/gwenn-ha-dev/Quatuor/releases/tag/v0.1.0
