#!/usr/bin/env bash
# check.sh — validate an Alda score with valda and optionally export it.
#
#   check.sh FILE.alda [--midi OUT.mid] [--wav OUT.wav]
#
# Prints parts, note count and total length on success; prints valda's
# line:column error and exits 1 on failure.
set -euo pipefail

usage() { echo "usage: $(basename "$0") FILE.alda [--midi OUT.mid] [--wav OUT.wav]" >&2; exit 2; }
[ $# -ge 1 ] || usage
file="$1"; shift
[ -f "$file" ] || { echo "check.sh: no such file: $file" >&2; exit 2; }

midi="" wav=""
while [ $# -gt 0 ]; do
	case "$1" in
		--midi) midi="${2:?}"; shift 2 ;;
		--wav) wav="${2:?}"; shift 2 ;;
		*) usage ;;
	esac
done

# Find valda: $VALDA, then PATH, then the binary in the repo this skill lives in.
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
valda="${VALDA:-}"
if [ -z "$valda" ]; then
	if command -v valda >/dev/null 2>&1; then
		valda="$(command -v valda)"
	elif [ -x "$here/../../../valda" ]; then
		valda="$(cd "$here/../../.." && pwd)/valda"
	else
		echo "check.sh: valda not found (set VALDA=/path/to/valda or put it on PATH)" >&2
		exit 2
	fi
fi

if ! data="$("$valda" parse -f "$file" -o data 2>&1)"; then
	echo "FAIL $file"
	echo "$data"
	exit 1
fi

if command -v python3 >/dev/null 2>&1; then
	python3 -I -c '
import json, sys
d = json.loads(sys.stdin.read())
ev = d["events"]
end = max((e["offset"] + e["duration"] for e in ev), default=0) / 1000
label = {k: p["name"] if p["name"] == p["stock-instrument"] else "%s (%s)" % (p["name"], p["stock-instrument"]) for k, p in d["parts"].items()}
parts = dict.fromkeys(label.values(), 0)
for e in ev:
    parts[label[e["part"]]] += 1
print("OK   %s" % sys.argv[1])
print("     %d notes, %d:%04.1f long" % (len(ev), end // 60, end % 60))
for name, n in parts.items():
    print("     %-40s %5d notes" % (name, n))
if d["markers"]:
    print("     markers: " + ", ".join("%s@%.1fs" % (k, v / 1000) for k, v in sorted(d["markers"].items(), key=lambda kv: kv[1])))
' "$file" <<<"$data"
else
	echo "OK   $file"
fi

if [ -n "$midi" ]; then
	"$valda" export -f "$file" -O midi -o "$midi"
fi
if [ -n "$wav" ]; then
	"$valda" export -f "$file" -O wav -o "$wav"
fi
