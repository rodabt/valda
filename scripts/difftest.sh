#!/usr/bin/env bash
# Differential test: compares valda's output with Alda's Go client (the
# reference implementation) for every .alda file given (default: examples/).
#
# Usage:
#   ALDA=/path/to/alda scripts/difftest.sh [files...]
#
# The reference binary is run with telemetry disabled and an isolated HOME,
# so it doesn't touch your Alda configuration.
set -uo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
valda=${VALDA:-$here/valda}
alda=${ALDA:?set ALDA to the path of a reference alda binary}
modes=${MODES:-events data ast ast-human}

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

run_alda() {
	ALDA_DISABLE_TELEMETRY=yes HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config" \
		XDG_CACHE_HOME="$sandbox/cache" XDG_STATE_HOME="$sandbox/state" \
		"$alda" "$@" 2>/dev/null
}

if [ $# -eq 0 ]; then
	set -- "$here"/examples/*.alda
fi

pass=0
fail=0
for mode in $modes; do
	for f in "$@"; do
		expected=$(run_alda parse -o "$mode" -f "$f")
		rc_expected=$?
		actual=$("$valda" parse -o "$mode" -f "$f" 2>/dev/null)
		rc_actual=$?
		if [ $rc_expected -ne 0 ] || [ $rc_actual -ne 0 ]; then
			if [ $rc_expected -ne 0 ] && [ $rc_actual -ne 0 ]; then
				pass=$((pass + 1))
			else
				fail=$((fail + 1))
				echo "FAIL $mode $(basename "$f"): exit codes differ (alda=$rc_expected valda=$rc_actual)"
			fi
		elif [ "$expected" == "$actual" ]; then
			pass=$((pass + 1))
		else
			fail=$((fail + 1))
			echo "FAIL $mode $(basename "$f")"
			diff <(echo "$expected") <(echo "$actual") | head -5
		fi
	done
done

echo "identical: $pass, different: $fail"
[ $fail -eq 0 ]
