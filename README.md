# stem-lab

Local audio stem splitter for macOS (Apple Silicon). Splits a track into four stems using the best free model for each part:

| Stem | Model |
|------|-------|
| **vocals** | Mel-Band Roformer (`vocals_mel_band_roformer.ckpt`) — current state of the art |
| **drums** | htdemucs_ft |
| **bass** | htdemucs_ft |
| **other** | htdemucs_ft — synths / pads / ambience |

It discards the weaker outputs (Roformer's instrumental, Demucs' vocals) and keeps only the best version of each stem. Everything runs locally on the GPU (MPS) — nothing is uploaded.

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

## Notes

- Built as the free alternative to paid stem splitters (LALAL.ai, Moises) and audio tools like SoundSource.
- For vocals-only / karaoke, Roformer alone is the fastest good result; the full pipeline exists for when you want the instrumental layers broken out too.
