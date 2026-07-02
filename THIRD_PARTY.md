# Third-Party Components

First-party code in this repository (the `split` script, packaging scripts, Swift app,
and landing page) is MIT-licensed — see [LICENSE](LICENSE). The distributable Stem Lab
DMG additionally bundles the components below. Licenses were verified against each
project's published license as of 2026-07 — corrections welcome via issue.

## Model Weights

| Component | Author | License | Source |
|-----------|--------|---------|--------|
| MelBand Roformer vocal model (`vocals_mel_band_roformer.ckpt`) | Kim Jensen | MIT | [huggingface.co/KimberleyJSN/melbandroformer](https://huggingface.co/KimberleyJSN/melbandroformer) |
| htdemucs_ft weights (bag of 4 checkpoints) | Meta AI | Part of the MIT-licensed Demucs project | [github.com/facebookresearch/demucs](https://github.com/facebookresearch/demucs) |

## Separation Engines

| Component | License | Source |
|-----------|---------|--------|
| Demucs 4.0.1 | MIT | [github.com/facebookresearch/demucs](https://github.com/facebookresearch/demucs) |
| audio-separator 0.44.2 | MIT | [github.com/nomadkaraoke/python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator) |
| PyTorch 2.12 / torchaudio / torchvision / torchcodec | BSD-3-Clause | [github.com/pytorch/pytorch](https://github.com/pytorch/pytorch) |

## Python Runtime

CPython 3.13 (PSF-2.0) from [python-build-standalone](https://github.com/astral-sh/python-build-standalone)
(build scripts MPL-2.0; bundled components — OpenSSL, SQLite, zlib, etc. — under their own
licenses, documented upstream).

The bundled environment contains ~70 Python packages, all under permissive licenses
(MIT / BSD / Apache-2.0 / ISC / PSF / MPL-2.0). Each package's license text ships inside
the app at `python/lib/python3.13/site-packages/*.dist-info/`. Copyleft-adjacent notables:

- **soxr** (LGPL-2.1-or-later) — [github.com/dofuuz/python-soxr](https://github.com/dofuuz/python-soxr)
- **lameenc** (LGPL-3.0-or-later, binds the LAME MP3 encoder) — [github.com/chrisstaite/lameenc](https://github.com/chrisstaite/lameenc)

**Not bundled:** `diffq` (CC BY-NC 4.0) is a Demucs dependency used only for
DiffQ-quantized checkpoints, which Stem Lab does not use. It is excluded from the DMG.
If you install the CLI pipeline yourself per the README, pip will pull it onto your
machine under its own non-commercial license.

## FFmpeg

The DMG bundles `ffmpeg`/`ffprobe` binaries and their dylib closure from the Homebrew
build of **FFmpeg 8** — licensed **GPL-3.0-or-later** as built (includes GPL x264/x265;
also SVT-AV1, libvpx, dav1d, opus, libvmaf under BSD-family licenses; LAME under LGPL;
OpenSSL under Apache-2.0). FFmpeg is used unmodified. Corresponding sources:
[ffmpeg.org/download](https://ffmpeg.org/download.html) and the pinned
[Homebrew formula](https://github.com/Homebrew/homebrew-core/blob/master/Formula/f/ffmpeg.rb);
build configuration is reproducible via `brew install ffmpeg`.

## Site

The landing page loads Archivo Narrow, Space Grotesk, and JetBrains Mono (all SIL OFL)
from Google Fonts; no font files are redistributed.
