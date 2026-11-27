#!/usr/bin/env bash
# levels.sh — render a score to WAV and report loudness per %marker section,
# so you can check the dynamic arc (build -> climax -> tail) and catch clipping.
#
# usage: levels.sh FILE.alda [--keep OUT.wav]
# Prints one line per section: start time, RMS dBFS, peak dBFS, and a bar.
# Exits 1 if any samples clip (lower the (track-vol) values and re-run).
set -euo pipefail

usage() { echo "usage: $(basename "$0") FILE.alda [--keep OUT.wav]" >&2; exit 2; }
[ $# -ge 1 ] || usage
file="$1"; shift
[ -f "$file" ] || { echo "levels.sh: no such file: $file" >&2; exit 2; }
keep=""
while [ $# -gt 0 ]; do
	case "$1" in
		--keep) keep="${2:?}"; shift 2 ;;
		*) usage ;;
	esac
done
command -v python3 >/dev/null 2>&1 || { echo "levels.sh: needs python3" >&2; exit 2; }

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
valda="${VALDA:-}"
if [ -z "$valda" ]; then
	if command -v valda >/dev/null 2>&1; then
		valda="$(command -v valda)"
	elif [ -x "$here/../../../valda" ]; then
		valda="$(cd "$here/../../.." && pwd)/valda"
	else
		echo "levels.sh: valda not found (set VALDA=/path/to/valda or put it on PATH)" >&2
		exit 2
	fi
fi

# Write the WAV next to the score (works with the Docker wrapper, which only sees the current directory).
wav="${keep:-$(dirname "$file")/.levels-$$.wav}"
[ -n "$keep" ] || trap 'rm -f "$wav"' EXIT
data="$("$valda" parse -f "$file" -o data)"
out="$("$valda" export -f "$file" -O wav -o "$wav" 2>&1)" || { echo "$out" >&2; exit 1; }

python3 -I -c '
import json, math, struct, sys, wave
d = json.loads(sys.stdin.read())
w = wave.open(sys.argv[1]); n = w.getnframes(); sr = w.getframerate(); ch = w.getnchannels()
s = struct.unpack("<%dh" % (n * ch), w.readframes(n))
marks = sorted(((v / 1000.0, k) for k, v in d["markers"].items()))
if not marks or marks[0][0] > 0:
    marks.insert(0, (0.0, "(start)"))
end = n / sr
clipped = sum(1 for x in s if abs(x) >= 32700)
print("%-14s %7s %8s %8s" % ("section", "start", "rms dB", "peak dB"))
for i, (t, name) in enumerate(marks):
    t2 = marks[i + 1][0] if i + 1 < len(marks) else end
    seg = s[int(t * sr) * ch:int(t2 * sr) * ch:ch] or (0,)
    rms = math.sqrt(sum(x * x for x in seg[::4]) / max(1, len(seg[::4])))
    pk = max(abs(x) for x in seg)
    db = 20 * math.log10(rms / 32768 + 1e-9)
    print("%-14s %6.1fs %8.1f %8.1f  %s" % (name, t, db, 20 * math.log10(pk / 32768 + 1e-9), "#" * max(0, int((db + 45) / 1.5))))
print("length %.1fs, clipped samples: %d" % (end, clipped))
if clipped:
    print("CLIPPING: lower (track-vol) on the loudest parts (about x0.8) and re-run")
    sys.exit(1)
' "$wav" <<<"$data"
