# Quatuor — agent context

## What this is

A native macOS app for audio stem separation — isolate vocals, drums, bass and other instruments from any song using state-of-the-art deep learning, running entirely on the Apple Silicon GPU. Four stems: a quartet.

Platform: macOS 26.4+. Build system: Xcode project. Bundle ID `dev.gwennha.Quatuor`.

## Build and test

```sh
make build   # release, warnings are errors
make test
make lint    # charter compliance — run before declaring anything done
```

Never invoke `swift build`, `xcodebuild` or a build script directly; go through
the `Makefile`. It is the same interface in every project here.

## Invariants — do not break these

- **No hard-coded user-visible strings.** Everything goes through
  `Quatuor/Localizable.xcstrings`, present in both `en` and `fr`. Adding a
  string means adding both translations in the same change.
- **No build artefacts committed.** No `.app`, no `build/`, no `.build/`.
- **Dependencies: MLX-Swift.** Adding one requires documenting it in the README's
  *Dependencies* section.
- **`README.md` and `README.fr.md` stay in sync.** Editing one means editing the other.
- **The icon is generated**, never hand-placed: `outils/icone.swift` is the
  source, `make icon` rebuilds `Resources/AppIcon.icns`, and the app bundles
  that file directly (`CFBundleIconFile`). There is no `AppIcon` in the asset
  catalogue: a second copy there is how the app shipped a stale icon for months.
- Identifiers, commit messages and both READMEs are in **English**; comments may
  be in English or French (charter §2).

- `Stem`, `StemKind`, `StemPlayer`, `StemRowView` are **audio domain vocabulary**, not leftovers from the old app name. They stay.
- The catalogue's source language is **French** (the keys are the French
  phrases), with explicit `en` and `fr` entries. A `Text("\(n) %")` is looked up
  as `%lld %%`, not `%lld %`: to find keys the code uses and the catalogue lacks,
  build with `SWIFT_EMIT_LOC_STRINGS=YES` and compare the `.stringsdata` keys.
  Numbers, durations and units go through `FormatStyle`, never `String(format:)`.
- **Apple Silicon only**: `Lame.xcconfig` sets `ARCHS = arm64`. MLX needs the
  Apple GPU and libmp3lame is built for arm64 alone; without it `make package`
  (an archive, which builds every architecture) fails to link.

## Public identity and releases (charter §12)

- Commit as `gwenn-ha-dev <13298867+gwenn-ha-dev@users.noreply.github.com>` (set
  in this repo's git config) and in UTC: `TZ=UTC git commit …`. No personal name,
  email or `/Users/…` path in tracked files. `../../Charte/outils/identite.sh .` checks.
- A release: `make sign && make dmg && make shots && make release-check`, then tag
  `v<version>` and attach `build/Quatuor-<version>.dmg` — see
  `../../Charte/DISTRIBUTION-AGENT.md`, phase 3. The version is `MARKETING_VERSION`
  in `Quatuor.xcodeproj`. Releases v1.0.0–v1.2.0 were published as **Stem**, under
  another bundle ID; 2.0.0 is the first as Quatuor.
- `make package` archives the scheme and copies the app to `build/Quatuor.app`.
  Xcode signs it "Apple Development"; `make sign` re-signs it with the Developer ID,
  hardened runtime, keeping its entitlements (sandbox, user-selected files,
  bookmarks, network client — the model download). The resource bundles
  (`mlx-swift_Cmlx.bundle` with `default.metallib`, swift-crypto, swift-transformers)
  hold no code and stay sealed by the app's signature: `codesign --verify --strict`
  passes.
- `make shots` (`outils/captures.sh`) downloads a CC0 song from Wikimedia Commons
  into `build/captures/`, opens it with `open -a`, and reaches the result screen with
  the launch key `-open.separate YES`. It needs the model (~670 MB), downloaded on the
  first separation into the app's container. Never use a song under copyright.

## Layout

```
.github/
.gitignore
CHANGELOG.md
CONTRIBUTING.md
LICENSE
Lame.xcconfig
Makefile
Quatuor.xcodeproj/
Quatuor/
QuatuorTests/
README.md
Resources/
Scripts/
ThirdParty/
docs/img/        # README captures (<view>.png, <view>.fr.png), social-preview.jpg
outils/          # captures.sh, deps.sh, icone.swift
site/            # GitHub Pages (published by Charte/outils/publier-site.sh)
```

## The charter

The full norm this project follows lives at `../../Charte/CHARTE.md`.
