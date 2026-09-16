# Quatuor

[![CI](https://github.com/gwenn-ha-dev/Quatuor/actions/workflows/ci.yml/badge.svg)](https://github.com/gwenn-ha-dev/Quatuor/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/Platform-macOS%2026.4%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

*🇬🇧 [English](./README.md) · 🇫🇷 Français*

App macOS native de séparation de stems — isole voix, batterie, basse et autres instruments de n'importe quel morceau, par apprentissage profond, entièrement sur le GPU Apple Silicon. Quatre stems : un quatuor.

## Fonctionnalités

- **Glisser-déposer** n'importe quel fichier audio (MP3, WAV, AIFF, M4A).
- **Séparation accélérée GPU** via MLX sur Apple Silicon (Metal).
- **htdemucs_ft** — le Hybrid Transformer Demucs affiné de Meta.
- **Lecture multipiste synchronisée** — tous les stems au pas via `AVAudioEngine`, précision à l'échantillon.
- **Mute / solo / volume** par stem — karaoké instantané : coupe la voix et chante dessus.
- **Vue waveform** avec progression live et clic pour naviguer, **export MP3** (un stem ou tout, VBR V2 via libmp3lame).
- **Mémoire adaptative** : le cache Metal de MLX est plafonné à 70 % de la mémoire disponible ; modèle et tampons sont libérés après séparation.

## Installation

```sh
git clone https://github.com/gwenn-ha-dev/Quatuor.git
cd Quatuor
make build
```

## Comment ça marche

`Stem`, `StemKind` et `StemPlayer` gardent leurs noms dans tout le code : *stem* est le terme audio pour une piste séparée, et il reste le mot juste quel que soit le nom de l'app.

## Construction

| Commande | Ce qu'elle fait |
|---|---|
| `make build` | Compilation release, tout avertissement est une erreur |
| `make test` | Lance la suite de tests |
| `make run` | Lance l'app |
| `make icon` | Régénère `Resources/AppIcon.icns` |
| `make package` | Produit un bundle distribuable dans `build/` |
| `make lint` | Vérifie la conformité à la charte |
| `make help` | Liste toutes les cibles |

## Dépendances

MLX-Swift pour l'inférence GPU. Tout le reste est en frameworks Apple.

## Licence

MIT © 2026 gwenn-ha-dev — voir [LICENSE](./LICENSE).
