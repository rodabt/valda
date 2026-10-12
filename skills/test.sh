#!/usr/bin/env bash
# skills/test.sh — check the valda skills: structure, and that every ```alda
# block in the docs and every template parses with valda. Also warns when the
# parts of one snippet end at different times (a bar-count or octave slip).
#
# Run from anywhere: bash skills/test.sh   (VALDA=/path/to/valda to override)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
valda="${VALDA:-$here/../valda}"
[ -x "$valda" ] || { echo "test.sh: valda not found at $valda (set VALDA)" >&2; exit 2; }

fail=0
for skill in valda-music valda-drums; do
	md="$here/$skill/SKILL.md"
	if ! head -5 "$md" | grep -q "^name: $skill$" || ! head -5 "$md" | grep -q '^description:'; then
		echo "FAIL $skill/SKILL.md: missing name/description frontmatter"
		fail=1
	fi
	cmp -s "$here/$skill/scripts/check.sh" "$here/valda-music/scripts/check.sh" ||
		{ echo "FAIL $skill/scripts/check.sh differs from valda-music's copy"; fail=1; }
done

python3 -I - "$valda" "$here" <<'EOF' || fail=1
import glob, json, os, re, subprocess, sys

valda, root = sys.argv[1], sys.argv[2]
sources = []
for md in sorted(glob.glob(os.path.join(root, "*", "SKILL.md")) +
                 glob.glob(os.path.join(root, "*", "references", "*.md"))):
    text = open(md).read()
    for m in re.finditer(r"^```alda\n(.*?)^```", text, re.S | re.M):
        line = text[:m.start()].count("\n") + 2
        sources.append(("%s:%d" % (os.path.relpath(md, root), line), m.group(1)))
for t in sorted(glob.glob(os.path.join(root, "*", "templates", "*.alda"))):
    sources.append((os.path.relpath(t, root), open(t).read()))

bad = warn = 0
for name, code in sources:
    r = subprocess.run([valda, "parse", "-o", "data", "-c", code], capture_output=True, text=True)
    if r.returncode != 0:
        bad += 1
        print("FAIL %s\n     %s" % (name, (r.stderr or r.stdout).strip()))
        continue
    d = json.loads(r.stdout)
    ends = {p["name"]: p["current-offset"] for p in d["parts"].values()}
    if len(set(round(v) for v in ends.values())) > 1:
        warn += 1
        print("WARN %s: parts end at different times: %s" % (
            name, ", ".join("%s=%.0fms" % kv for kv in ends.items())))
print("%d snippets/templates parsed, %d failed, %d warnings" % (len(sources), bad, warn))
sys.exit(1 if bad else 0)
EOF

[ $fail -eq 0 ] && echo "skills OK" || { echo "skills FAILED"; exit 1; }
