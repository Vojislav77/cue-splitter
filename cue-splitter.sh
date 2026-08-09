#!/usr/bin/env bash
#
# CUE Splitter — split a .cue music image into separate tagged tracks.
# Adds a right-click "CUE Splitter" menu to Dolphin (Plasma 6 / Frameworks 6).
#
# Features:
#   - Splits .cue image files (.wav, .flac, .ape, .wv, .bin, .mp3, ...) via ffmpeg
#   - Encodes to MP3, FLAC, OGG/Vorbis, Opus, M4A/AAC or WAV
#   - Writes title / artist / album / track-number tags from the .cue
#   - Embeds the cover image (Folder.jpg, cover.jpg, or FILE "...".JPEG/PNG)
#   - kdialog GUI: format, quality, output folder
#
# Usage: cue-splitter.sh <album.cue>

set -euo pipefail

CUE_FILE="$1"
CUE_DIR="$(cd "$(dirname "$CUE_FILE")" && pwd)"
CUE_NAME="$(basename "$CUE_FILE" .cue)"

tmp_cover=""

cleanup() {
  [ -n "$tmp_cover" ] && rm -f "$tmp_cover"
}
trap cleanup EXIT

err() {
  kdialog --error "$1"
  exit 1
}

command -v ffmpeg >/dev/null || err "ffmpeg is not installed. Run: sudo dnf install ffmpeg"

# ---- Parse the .cue file ---------------------------------------------------
# Fields: file=audio file, cover=cover image, tracks: title, artist, start(frames)
declare -a t_title t_artist t_start
audio_file=""
cover_file=""
performer_album=""
title_album=""
cur_track=""
idx=0

while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
  line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
  [[ -z "$line" ]] && continue

  if [[ "$line" =~ ^FILE[[:space:]]+\"(.*)\"[[:space:]]+([A-Za-z0-9]+) ]]; then
    fname="${BASH_REMATCH[1]}"
    ftype="${BASH_REMATCH[2]}"
    case "$ftype" in
      JPEG|PNG)
        [ -z "$cover_file" ] && cover_file="$fname"
        ;;
      *)
        [ -z "$audio_file" ] && audio_file="$fname"
        ;;
    esac
    continue
  fi

  if [[ "$line" =~ ^REM[[:space:]]+ ]]; then continue; fi

  if [[ "$line" =~ ^TRACK[[:space:]]+[0-9]+ ]]; then
    cur_track=$((idx + 1))
    idx=$((idx + 1))
    continue
  fi

  if [[ "$line" =~ ^TITLE[[:space:]]+\"(.*)\" ]]; then
    val="${BASH_REMATCH[1]}"
    if [ -n "$cur_track" ]; then
      t_title[$((cur_track-1))]="$val"
    else
      title_album="$val"
    fi
    continue
  fi

  if [[ "$line" =~ ^PERFORMER[[:space:]]+\"(.*)\" ]]; then
    val="${BASH_REMATCH[1]}"
    if [ -n "$cur_track" ]; then
      t_artist[$((cur_track-1))]="$val"
    else
      performer_album="$val"
    fi
    continue
  fi

  if [[ "$line" =~ ^INDEX[[:space:]]+01[[:space:]]+([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
    mm="${BASH_REMATCH[1]}"; ss="${BASH_REMATCH[2]}"; ff="${BASH_REMATCH[3]}"
    seconds=$(awk -v m="$mm" -v s="$ss" -v f="$ff" 'BEGIN{printf "%.3f", m*60 + s + f/75}')
    t_start[$((cur_track-1))]="$seconds"
    cur_track=""
    continue
  fi
done < "$CUE_FILE"

[ "$idx" -gt 0 ] || err "No TRACK entries found in cue file."
[ -n "$audio_file" ] || err "No audio file found in cue."

# Resolve audio file path (relative to cue dir, fallback to common extensions)
audio_path=""
if [ -f "$CUE_DIR/$audio_file" ]; then
  audio_path="$CUE_DIR/$audio_file"
else
  for ext in wav flac ape wv mp3 m4a ogg bin; do
    for f in "$CUE_DIR"/*."$ext" "$CUE_DIR"/*."${ext^^}"; do
      [ -f "$f" ] && audio_path="$f" && break 2
    done
  done
fi
[ -n "$audio_path" ] || err "Audio file '$audio_file' not found next to the cue."

# Resolve cover image
cover_path=""
if [ -n "$cover_file" ] && [ -f "$CUE_DIR/$cover_file" ]; then
  cover_path="$CUE_DIR/$cover_file"
else
  for c in Folder.jpg folder.jpg folder.JPG Cover.jpg cover.jpg cover.png front.jpg; do
    [ -f "$CUE_DIR/$c" ] && cover_path="$CUE_DIR/$c" && break
  done
fi
if [ -n "$cover_path" ]; then
  tmp_cover="$(mktemp --suffix=.jpg)"
  ffmpeg -y -loglevel error -i "$cover_path" -vf "scale=1200:-2" -q:v 3 "$tmp_cover"
  [ -s "$tmp_cover" ] || tmp_cover=""
fi

# ---- Choose settings via kdialog ------------------------------------------
format=$(kdialog --combobox "Output format:" "MP3" "FLAC" "OGG / Vorbis" "Opus" "M4A / AAC" "WAV" --default "MP3" 2>/dev/null) || exit 1

case "$format" in
  MP3)
    quality=$(kdialog --combobox "MP3 quality:" "192 kbps (good)" "128 kbps" "160 kbps" "256 kbps" "320 kbps (best)" "VBR q2" "VBR q0" --default "192 kbps (good)" 2>/dev/null) || exit 1
    ;;
  FLAC)
    quality=$(kdialog --combobox "FLAC compression (0 = fastest, 8 = smallest):" "5 (default)" "0" "1" "2" "3" "4" "6" "7" "8" --default "5 (default)" 2>/dev/null) || exit 1
    ;;
  "OGG / Vorbis")
    quality=$(kdialog --combobox "Vorbis bitrate:" "192 kbps" "128 kbps" "160 kbps" "256 kbps" "320 kbps" --default "192 kbps" 2>/dev/null) || exit 1
    ;;
  Opus)
    quality=$(kdialog --combobox "Opus bitrate:" "128 kbps" "96 kbps" "160 kbps" "192 kbps" "256 kbps" --default "128 kbps" 2>/dev/null) || exit 1
    ;;
  "M4A / AAC")
    quality=$(kdialog --combobox "AAC bitrate:" "192 kbps" "128 kbps" "160 kbps" "256 kbps" "320 kbps" --default "192 kbps" 2>/dev/null) || exit 1
    ;;
  WAV)
    quality=""
    ;;
esac

out_dir=$(kdialog --getexistingdirectory "$CUE_DIR" --title "Choose output folder" 2>/dev/null) || exit 1

embed_cover=1
if [ -n "$cover_path" ]; then
  kdialog --yesno "Embed cover image into the tracks?" 2>/dev/null || embed_cover=0
fi

# ---- Build encoder options -------------------------------------------------
case "$format" in
  MP3)
    ext="mp3"
    enc=(-c:a libmp3lame)
    case "$quality" in
      128*) enc+=(-b:a 128k) ;;
      160*) enc+=(-b:a 160k) ;;
      256*) enc+=(-b:a 256k) ;;
      320*) enc+=(-b:a 320k) ;;
      VBR*) enc+=(-q:a "${quality#VBR q}") ;;
      *)    enc+=(-b:a 192k) ;;
    esac
    ;;
  FLAC)
    ext="flac"
    lvl="${quality%% *}"
    enc=(-c:a flac -compression_level "$lvl")
    ;;
  "OGG / Vorbis")
    ext="ogg"
    br="${quality%% *}"
    enc=(-c:a libvorbis -b:a "$br")
    ;;
  Opus)
    ext="opus"
    br="${quality%% *}"
    enc=(-c:a libopus -b:a "$br")
    ;;
  "M4A / AAC")
    ext="m4a"
    br="${quality%% *}"
    enc=(-c:a aac -b:a "$br" -movflags +faststart)
    ;;
  WAV)
    ext="wav"
    enc=(-c:a pcm_s16le)
    ;;
esac

# ---- Encode each track ------------------------------------------------------
total=$idx
n=0
start=""
end=""
for ((i=0; i<total; i++)); do
  n=$((n+1))

  title="${t_title[$i]:-}"
  artist="${t_artist[$i]:-${performer_album:-}}"
  album="${title_album:-}"
  tracknum=$(printf "%02d" $((i+1)))

  [ -n "$title" ] || title="Track $tracknum"
  [ -n "$artist" ] || artist="${performer_album:-Unknown Artist}"
  [ -n "$album" ] || album="$(basename "$CUE_NAME")"

  out_file="$out_dir/${tracknum} - ${title}.${ext}"
  sname=$(basename "$out_file")

  start="${t_start[$i]}"
  if [ $((i+1)) -lt $total ]; then
    end="${t_start[$((i+1))]}"
    dur=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", e - s}')
  else
    dur=""
  fi

  common=(-map_metadata -1)
  [ -n "$artist" ] && common+=(-metadata artist="$artist")
  [ -n "$album" ]  && common+=(-metadata album="$album")
  [ -n "$title" ]  && common+=(-metadata title="$title")
  common+=(-metadata album_artist="${performer_album:-$artist}")
  common+=(-metadata track="$n/$total")
  [ -n "$title_album" ] || true

  cover_args=()
  if [ "$embed_cover" = "1" ] && [ -n "$tmp_cover" ]; then
    cover_args=(-i "$tmp_cover")
    case "$ext" in
      m4a) cover_args+=(-map 0:a -map 1 -c:v mjpeg -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)") ;;
      wav) cover_args=() ;;
      *)   cover_args+=(-map 0:a -map 1 -c:v copy -disposition:v attached_pic) ;;
    esac
  fi

  seek_args=()
  [ -n "$start" ] && seek_args=(-ss "$start")
  to_args=()
  [ -n "$dur" ] && to_args=(-t "$dur")

  kdialog --passivepopup "Encoding $n/$total: $sname" 2 2>/dev/null || true

  if [ ${#cover_args[@]} -gt 0 ]; then
    ffmpeg -y -loglevel error -nostdin ${seek_args[@]} -i "$audio_path" "${cover_args[@]}" \
      ${to_args[@]} ${enc[@]} "${common[@]}" "$out_file"
  else
    ffmpeg -y -loglevel error -nostdin ${seek_args[@]} -i "$audio_path" \
      ${to_args[@]} ${enc[@]} "${common[@]}" "$out_file"
  fi
done

kdialog --msgbox "Done. $n track(s) written to:\n$out_dir" 2>/dev/null || true
