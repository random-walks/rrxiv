# Parser conformance

Implementations of the rrvix TeX → CIR parser are conformant if they pass
the suite under [`../runner.py`](../runner.py) against every fixture in
[`../fixtures/`](../fixtures/).

## Reference implementation

[`rrvix-python`](https://github.com/random-walks/rrvix-python) is the
reference. From this directory:

```bash
python ../runner.py --impl 'uv run rrvix parse'
```

## Adding a new implementation

If you're building a parser in another language (Rust, Go, JavaScript,
Typst-side, …), the conformance contract is:

1. **Take a `.tex` path** as the first positional argument.
2. **Read the `.rrvix.aux` sidecar** from the same directory as the
   `.tex` (default location), or accept a `--sidecar` flag.
3. **Read the `.bib` file** referenced via `\bibliography{NAME}` from
   the same directory, or accept a `--bib` flag. Also fall back to
   `\begin{thebibliography}` blocks in the source.
4. **Write the CIR JSON** to the path passed via `--output`, or stdout
   if no `--output` is given.
5. **Validate** the produced CIR against
   [`schema/cir.schema.json`](../../../schema/cir.schema.json) before
   declaring success.

Once your CLI satisfies the above, run the suite:

```bash
python ../runner.py --impl '/path/to/your-parser'
```

A passing run constitutes parser conformance for the v0.1 protocol.

## Fields excluded from the comparison

The runner ignores environment-specific fields by default
(`submitted_at`, `source.uri`). Each fixture may add to that list via
its `_ignore_fields` array — see `../README.md` §"Comparison rules".

## Future

When this repository accumulates more fixtures (a paper with edges, a
paper with multiple claims, a paper that exercises `\dependson` /
`\contradicts` / `\extendsclaim` / `\supports`), each will land here as
its own subdirectory. The runner discovers fixtures by directory name
without needing to be told.
