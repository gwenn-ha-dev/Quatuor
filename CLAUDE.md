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
  `Resources/Localizable.xcstrings`, present in both `en` and `fr`. Adding a
  string means adding both translations in the same change.
- **No build artefacts committed.** No `.app`, no `build/`, no `.build/`.
- **Dependencies: MLX-Swift.** Adding one requires documenting it in the README's
  *Dependencies* section.
- **`README.md` and `README.fr.md` stay in sync.** Editing one means editing the other.
- **The icon is generated**, never hand-placed: `outils/icone.swift` is the
  source, `make icon` rebuilds `Resources/AppIcon.icns`.
- Identifiers, commit messages and both READMEs are in **English**; comments may
  be in English or French (charter §2).

- `Stem`, `StemKind`, `StemPlayer`, `StemRowView` are **audio domain vocabulary**, not leftovers from the old app name. They stay.

## Layout

```
.github/
.gitignore
CHANGELOG.md
CONTRIBUTING.md
LICENSE
Lame.xcconfig
Makefile
Models/
Quatuor.xcodeproj/
Quatuor/
QuatuorTests/
QuatuorUITests/
README.md
Resources/
Scripts/
ThirdParty/
capture.png
logo.png
outils/
```

## The charter

The full norm this project follows lives at `../../Charte/CHARTE.md`.
