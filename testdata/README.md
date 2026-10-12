# Test data

- `golden/`: output recorded from Alda's Go client (version 2.4.7, built from
  the alda repository at commit 0b85428) for a selection of `examples/`:
  `parse -o events`, `parse -o data`, `parse -o ast-human` and `format`.
  `tests/golden_test.v` checks that valda reproduces it byte for byte.
- `musicxml/`: the MusicXML examples from the alda repository
  (`client/interop/musicxml/examples`), with the expected `.alda` import
  output. The expected output was produced by valda and checked against Alda's
  importer; the only difference is the order of letters in key signatures,
  which is nondeterministic in Alda (it iterates a Go map) and fixed to
  circle-of-fifths order in valda.

To compare valda with a reference `alda` binary across many inputs, see
`scripts/difftest.sh`.
