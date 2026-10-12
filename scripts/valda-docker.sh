#!/usr/bin/env bash
# valda-docker.sh: run valda from its Docker image as if it were installed.
#
#   scripts/valda-docker.sh export -f song.alda -o song.mid
#   VALDA=scripts/valda-docker.sh skills/valda-music/scripts/check.sh song.alda
#
# The current directory is mounted at the same path inside the container, so
# relative paths and absolute paths under it work unchanged. Files outside it
# are not visible to valda. Output files belong to you, not to root.
#
# If the host runs a PulseAudio or PipeWire server, its socket is passed
# through so that `play` and the REPL make sound (on WSL, PULSE_SERVER points
# at it). VALDA_IMAGE picks the image (default: valda, built with `docker
# build -t valda .`). VALDA_SOUNDFONT, if set to a file under the current
# directory, is passed through.
set -euo pipefail

args=(--rm -i --user "$(id -u):$(id -g)" -v "$PWD":"$PWD" -w "$PWD")
# Allocate a terminal only for interactive use: a TTY would corrupt binary
# output such as `export` writing MIDI to stdout.
if [ -t 0 ] && [ -t 1 ]; then
	args+=(-t)
fi
pulse="${PULSE_SERVER:-}"
pulse="${pulse#unix:}"
[ -n "$pulse" ] || pulse="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"
if [ -S "$pulse" ]; then
	args+=(-v "$pulse":/tmp/pulse -e PULSE_SERVER=unix:/tmp/pulse)
fi
if [ -n "${VALDA_SOUNDFONT:-}" ]; then
	args+=(-e VALDA_SOUNDFONT="$VALDA_SOUNDFONT")
fi

exec docker run "${args[@]}" "${VALDA_IMAGE:-valda}" "$@"
