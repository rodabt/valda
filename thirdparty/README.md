# Third-party code

Both libraries are vendored single-header C libraries, compiled into valda by
`engine/valda_engine.c`.

| File | Project | Version | License |
|---|---|---|---|
| `tsf.h` | [TinySoundFont](https://github.com/schellingb/TinySoundFont) | master (2026) | MIT (`LICENSE.TinySoundFont`) |
| `miniaudio.h` | [miniaudio](https://github.com/mackron/miniaudio) | 0.11.25 | Public domain or MIT No Attribution (see the end of the header) |

The V runtime and standard library are also compiled into the valda binary.
They are MIT licensed; `LICENSE.V` is a copy of V's license, to ship with
binary distributions.
