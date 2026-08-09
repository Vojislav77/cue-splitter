# CUE Splitter

<p align="center">
  <img src="icon.png" alt="CUE Splitter icon" width="128">
</p>

Split a `.cue` music image (album as a single file) into separate, tagged tracks right from the file manager context menu.

Adds a **CUE Splitter** entry to the Dolphin right-click menu on `.cue` files. Pick a format and quality, choose an output folder, and every track is extracted, tagged, and gets its cover embedded — in one go.

## Features

- Splits any `.cue` image: `.wav`, `.flac`, `.ape` (Monkey's Audio), `.wv` (WavPack), `.bin`+`.mp3`, `.m4a`, `.ogg`, ...
- Encodes to **MP3, FLAC, OGG/Vorbis, Opus, M4A/AAC, or WAV** with a selectable quality/bitrate
- Tags every track from the `.cue`: title, artist, album, album artist, track number
- Embeds the **cover image** automatically (`Folder.jpg`, `cover.jpg`, `front.jpg`, or a `FILE "..." JPEG/PNG` line in the cue)
- GUI dialogs via `kdialog` — format, quality, and output folder
- No extra packages needed — it uses `ffmpeg` (plus `kdialog`, standard on KDE)

## Requirements

- Fedora KDE / Plasma 6 (or any distro with KDE Frameworks 6)
- `ffmpeg`
- `kdialog`

On Fedora:

```bash
sudo dnf install ffmpeg kdialog
```

## Installation

```bash
git clone https://github.com/Vojislav77/cue-splitter.git
cd cue-splitter
./install.sh
```

Then fully quit and reopen Dolphin:

```bash
killall dolphin
```

Right-click a `.cue` file → **CUE Splitter → Split & Encode...**

> Note: the menu is registered per-user. Only the logged-in account that ran `install.sh` gets it.

## Usage

1. Right-click a `.cue` file in Dolphin
2. Choose **Split & Encode...**
3. Select the output format
4. Select the quality/bitrate
5. Pick the output folder (defaults to the folder of the `.cue`)
6. Confirm embedding the cover image (only asked when a cover is found)

Done — files are written as `NN - Title.ext` in the chosen folder.

## What's in this repo

| File | Purpose |
| --- | --- |
| `cue-splitter.sh` | The engine: parses the `.cue`, splits, encodes, tags, embeds cover |
| `cue-splitter.desktop` | Dolphin service-menu entry (`kio/servicemenus`) |
| `install.sh` | Copies the files into place and refreshes KDE's menu database |

## Uninstall

```bash
rm ~/.local/share/kio/servicemenus/cue-splitter.desktop
rm ~/.local/share/kio/scripts/cue-splitter.sh
```

## How it works

- The `.cue` sheet is parsed (audio file, track list, titles, artists, index times, cover file).
- `ffmpeg` decodes the image, cuts each track at the `INDEX 01` boundaries, and encodes with the chosen codec.
- Tags are written with `-metadata`, and the cover is attached as `attached_pic` (MP3) or embedded picture (FLAC/OGG/Opus/M4A).

## Known limitations

- Works on one `.cue` file at a time (select a single file).
- Output filenames use `NN - Title`; unusual characters in titles are kept as-is.
- Requires a `.cue` that follows the standard layout (`TRACK`, `TITLE`, `PERFORMER`, `INDEX 01`).
