#!/usr/bin/env bash
# Makes the demo GIF from a screen recording (webm, mp4, ...) with ffmpeg and gifski. Either is run through
# "nix shell" when it is not installed (Homebrew: brew install ffmpeg gifski).
#   docs/demo/to-gif.sh <recording> [output.gif] [start seconds] [length seconds]
# The output defaults to docs/demo.gif. GIF_WIDTH (default 800 px) and GIF_FPS (default 15) change the size.
set -euo pipefail
if [ $# -lt 1 ]; then
  sed -n '2,5p' "$0" >&2
  exit 2
fi
in=$1
out=${2:-$(cd "$(dirname "$0")/.." && pwd)/demo.gif}
start=${3:-0}
len=${4:-}
width=${GIF_WIDTH:-800}
fps=${GIF_FPS:-15}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

run() {
  if command -v "$1" > /dev/null; then
    "$@"
  elif command -v nix > /dev/null; then
    nix shell "nixpkgs#$1" -c "$@"
  else
    echo "$1 is not installed" >&2
    exit 1
  fi
}

# Frames as PNG first: gifski makes much better colors than ffmpeg's own GIF output
run ffmpeg -loglevel error -ss "$start" ${len:+-t "$len"} -i "$in" \
  -vf "fps=$fps,scale=$width:-1:flags=lanczos" "$tmp/f%04d.png"
run gifski --quiet --fps "$fps" --width "$width" --quality 90 -o "$out" "$tmp"/f*.png
ls -l "$out"
