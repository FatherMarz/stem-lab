# stem-lab

Local audio stem splitter for macOS (Apple Silicon). Splits a track into four stems using the best free model for each part:

| Stem | Model |
|------|-------|
| **vocals** | Mel-Band Roformer (`vocals_mel_band_roformer.ckpt`) — current state of the art |
| **drums** | htdemucs_ft |
| **bass** | htdemucs_ft |
| **other** | htdemucs_ft — synths / pads / ambience |

It discards the weaker outputs (Roformer's instrumental, Demucs' vocals) and keeps only the best version of each stem. Everything runs locally on the GPU (MPS) — nothing is uploaded.

## Download the App

No terminal, no setup: **[⬇ StemLab-1.2.0.dmg](https://github.com/FatherMarz/stem-lab/releases/latest/download/StemLab-1.2.0.dmg)** (1.3 GB, Apple Silicon only — newer builds under [Releases](https://github.com/FatherMarz/stem-lab/releases)).

Drag *Stem Lab* to Applications, open it once via System Settings → Privacy & Security → "Open Anyway" (it's unsigned), then drop any song on the window or icon. Stems land in a `stems/` folder next to the song. Fully offline.

## Usage

```bash
stems /path/to/recording.wav      # alias -> ./split
stems --help
```

Stems land in a `stems/<trackname>/` folder beside the source file. Takes wav, mp3, flac, m4a. Roughly 6 minutes for a 4-minute track.

## Setup

Requires [`uv`](https://github.com/astral-f/uv) and `ffmpeg` (`brew install ffmpeg`).

```bash
# Python 3.13 — NOT 3.14 (no stable torch wheels yet)
uv venv --python 3.13 .venv
uv pip install --python .venv/bin/python demucs torchcodec "audio-separator[cpu]"
```

`torchcodec` is required alongside `demucs` — torchaudio routes audio writes through it, and saving fails without it.

Add the alias to your shell (`~/.zshrc`):

```bash
alias stems='/path/to/stem-lab/split'
```

Model weights download automatically on first run and are cached (htdemucs_ft ~320MB, Roformer ~200MB).

## Packaging the App

The distributable DMG (native SwiftUI wrapper + fully self-contained runtime: standalone CPython, model weights, ffmpeg dylibs) is built from `packaging/`:

```bash
packaging/collect-ffmpeg.sh   # stage the Homebrew ffmpeg dylib closure
packaging/build-app.sh        # payload tarball + Stem Lab.app + DMG
```

See the header comments in `packaging/build-app.sh` for the staged-payload prereqs. Bump `ENGINE_VERSION` only when payload contents change — that's what triggers the 2.3 GB runtime reinstall on users' machines.

## Notes

- Built as the free alternative to paid stem splitters (LALAL.ai, Moises).
- For vocals-only / karaoke, Roformer alone is the fastest good result; the full pipeline exists for when you want the instrumental layers broken out too.
