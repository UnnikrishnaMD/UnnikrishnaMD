#!/usr/bin/env bash
# Fits a master render under NODE's 500 MB File Upload limit.
#
# The sketch writes a near-lossless master (output/occupy_<surface>_master.mp4). This re-encodes it with
# a two-pass H.264 bitrate calculated from its duration, so the result lands just under the target size
# with the best quality that size allows. If the master is already under the target it is copied as is.
#
# Usage: ./encode_for_node.sh output/occupy_wall_master.mp4 [target_MB]   (default 480 MB)
set -euo pipefail

in="${1:?usage: $0 output/occupy_<surface>_master.mp4 [target_MB]}"
target_mb="${2:-480}" # under 500 so container overhead and MB-vs-MiB rounding can't tip it over
out="${in%_master.mp4}_node.mp4"
[ "$out" = "$in" ] && out="${in%.mp4}_node.mp4"

size_bytes=$(wc -c < "$in")
target_bytes=$((target_mb * 1000 * 1000))
if [ "$size_bytes" -le "$target_bytes" ]; then
  cp "$in" "$out"
  echo "Master is already $((size_bytes / 1000000)) MB - copied to $out unchanged."
  exit 0
fi

dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$in")
# total kbit available / seconds, with 2% held back for the container and rate-control overshoot
kbps=$(awk -v mb="$target_mb" -v d="$dur" 'BEGIN { printf "%d", mb * 8000 * 0.98 / d }')
echo "Duration ${dur}s -> ${kbps} kbit/s for ~${target_mb} MB"

passlog="$(mktemp -d)/pass"
common=(-c:v libx264 -preset slow -b:v "${kbps}k" -maxrate "$((kbps * 3 / 2))k" -bufsize "$((kbps * 2))k"
        -pix_fmt yuv420p -profile:v high -an -passlogfile "$passlog")
ffmpeg -y -v error -stats -i "$in" "${common[@]}" -pass 1 -f mp4 /dev/null
ffmpeg -y -v error -stats -i "$in" "${common[@]}" -pass 2 -movflags +faststart "$out"
rm -f "$passlog"*

echo "Wrote $out ($(( $(wc -c < "$out") / 1000000 )) MB)"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name,pix_fmt -of compact=p=0 "$out"
