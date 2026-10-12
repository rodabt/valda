# valda in a container: the binary plus a small General MIDI SoundFont.
#
#   docker build -t valda .
#   docker run --rm -v "$PWD":/work valda export -f song.alda -M 1 -o song.mid
#
# See the Docker section of README.md for audio playback and the REPL server.

# --- Build valda with the V compiler it was tested with ---------------------
FROM debian:trixie-slim AS build

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates git gcc make libc6-dev \
	&& rm -rf /var/lib/apt/lists/*

# V 0.5.1 (4dc97d9), bootstrapped from the vc commit generated from it: V's
# plain `make` would pull the latest vc, which rejects this older vlib. To use
# another V commit, pass both build args; vc's commit messages name the V
# commit each one comes from.
ARG V_COMMIT=4dc97d9e46c104073c073e04b3082e3fbc4ae214
ARG VC_COMMIT=9971a058f29ca8fa9ee99d7cbca6effc4113c4e8
RUN fetch() { git init -q "$3" && git -C "$3" fetch -q --depth 1 "$1" "$2" && git -C "$3" checkout -q FETCH_HEAD; } \
	&& fetch https://github.com/vlang/v "$V_COMMIT" /opt/v \
	&& fetch https://github.com/vlang/vc "$VC_COMMIT" /opt/v/vc \
	&& make -C /opt/v fresh_tcc \
	&& make -C /opt/v local=1

WORKDIR /src
COPY . .
RUN /opt/v/v -prod -cc gcc -o /usr/local/bin/valda .

# --- Runtime ----------------------------------------------------------------
FROM debian:trixie-slim

# timgm6mb-soundfont: a 6 MB General MIDI SoundFont, found automatically in
# /usr/share/sounds/sf2. libpulse0 and libasound2t64: only needed for
# `valda play` and the REPL's audio, which load them at runtime.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends timgm6mb-soundfont libpulse0 libasound2t64 \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/valda /usr/local/bin/valda
COPY LICENSE NOTICE /usr/share/doc/valda/
COPY thirdparty/LICENSE.* thirdparty/README.md /usr/share/doc/valda/thirdparty/

# Run as an ordinary user. Pass --user "$(id -u):$(id -g)" so that files
# written to a mounted folder belong to you.
RUN useradd --create-home --uid 1000 valda
USER valda
WORKDIR /work

ENTRYPOINT ["valda"]
CMD ["--help"]
