#!/usr/bin/env bash
# Headless render of the Reel / Short with the real Processing 4 core
# (no Processing app, no screen). Needs: java 17+, ffmpeg, xvfb-run, curl.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
sketch="$here/../series_07_contour_threads"
build="${BUILD_DIR:-$here/.build}"
mkdir -p "$build"
core="$build/core-4.5.7.jar"
[ -f "$core" ] || curl -sSL -o "$core" https://repo1.maven.org/maven2/org/processing/core/4.5.7/core-4.5.7.jar
python3 "$here/pde_to_java.py" "$sketch" "$build/Sketch.java" RECORD_ON_START=true EXIT_AFTER_RECORD=true
javac -nowarn -cp "$core" -d "$build" "$build/Sketch.java"
cd "$here/.."     # sketchPath → series-07/, so the MP4 lands in series-07/reel/
xvfb-run -a -s "-screen 0 1280x2048x24" \
  java -Djava.awt.headless=false -cp "$core:$build" Sketch "--sketch-path=$PWD"
