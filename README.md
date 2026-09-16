# Quatuor

[![CI](https://github.com/gwenn-ha-dev/Quatuor/actions/workflows/ci.yml/badge.svg)](https://github.com/gwenn-ha-dev/Quatuor/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

*🇬🇧 English · 🇫🇷 [Français](./README.fr.md)*

A native macOS app for audio stem separation — isolate vocals, drums, bass and other instruments from any song using state-of-the-art deep learning, running entirely on the Apple Silicon GPU. Four stems: a quartet.

## Features

- **Drag and drop** any audio file (MP3, WAV, AIFF, M4A).
- **GPU-accelerated** separation via MLX on Apple Silicon (Metal).
- **htdemucs_ft** — Meta's fine-tuned Hybrid Transformer Demucs.
- **Synchronised multi-track playback** — all stems in lock-step via `AVAudioEngine`, sample-accurate.
- **Mute / solo / volume** per stem — instant karaoke: mute the vocals and sing along.
- **Waveform view** with live progress and click-to-seek, **MP3 export** (single stem or batch, VBR V2 via libmp3lame).
- **Adaptive memory**: the MLX Metal cache is capped at 70 % of available system memory; model and buffers are released after separation.

## Install

```sh
git clone https://github.com/gwenn-ha-dev/Quatuor.git
cd Quatuor
make build
```

## How it works

`Stem`, `StemKind` and `StemPlayer` keep their names throughout the code: *stem* is the audio term for a separated track, and it stays the right word whatever the app is called.

## Build

| Command | What it does |
|---|---|
| `make build` | Release build, warnings are errors |
| `make test` | Run the test suite |
| `make run` | Launch the app |
| `make icon` | Regenerate `Resources/AppIcon.icns` |
| `make package` | Produce a distributable bundle in `build/` |
| `make lint` | Check compliance with the project charter |
| `make help` | List every target |

## Dependencies

MLX-Swift for GPU inference. Everything else is Apple frameworks.

## License

MIT © 2026 gwenn-ha-dev — see [LICENSE](./LICENSE).
