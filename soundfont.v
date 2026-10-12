module main

import os

// SoundFont discovery. valda renders General MIDI instruments from a SoundFont
// (.sf2). The first match wins:
//
//   1. the --soundfont flag
//   2. the VALDA_SOUNDFONT environment variable
//   3. <config dir>/valda/default.sf2, or any .sf2 in <config dir>/valda
//   4. well-known system locations (e.g. Debian's /usr/share/sounds/sf2)

fn config_dir() string {
	return os.join_path(os.config_dir() or { os.home_dir() }, 'valda')
}

fn soundfont_candidates() []string {
	mut candidates := []string{}

	if env := os.getenv_opt('VALDA_SOUNDFONT') {
		candidates << env
	}

	cfg := config_dir()
	candidates << os.join_path(cfg, 'default.sf2')
	if files := os.ls(cfg) {
		mut sf2s := files.filter(it.to_lower().ends_with('.sf2'))
		sf2s.sort()
		for f in sf2s {
			candidates << os.join_path(cfg, f)
		}
	}

	$if linux || freebsd || openbsd {
		for dir in ['/usr/share/sounds/sf2', '/usr/share/soundfonts', '/usr/local/share/soundfonts',
			'/usr/share/sounds/sf3'] {
			for name in ['default-GM.sf2', 'default.sf2', 'FluidR3_GM.sf2', 'GeneralUser-GS.sf2',
				'TimGM6mb.sf2'] {
				candidates << os.join_path(dir, name)
			}
		}
	}
	$if macos {
		home := os.home_dir()
		candidates << os.join_path(home, 'Library', 'Audio', 'Sounds', 'Banks', 'default.sf2')
		candidates << '/opt/homebrew/share/soundfonts/default.sf2'
		candidates << '/usr/local/share/soundfonts/default.sf2'
		candidates << '/opt/homebrew/share/fluid-synth/sf2/VintageDreamsWaves-v2.sf2'
	}
	$if windows {
		candidates << 'C:\\soundfonts\\default.sf2'
	}

	return candidates
}

fn find_soundfont(flag_value string) !string {
	if flag_value != '' {
		if !os.is_file(flag_value) {
			return error('SoundFont not found: ${flag_value}')
		}
		return flag_value
	}

	for candidate in soundfont_candidates() {
		if os.is_file(candidate) {
			return os.real_path(candidate)
		}
	}

	return error(no_soundfont_help())
}

fn no_soundfont_help() string {
	default_path := os.join_path(config_dir(), 'default.sf2')
	return 'No SoundFont (.sf2) found.

valda plays music with a built-in synthesizer, which needs a General MIDI
SoundFont. For example, GeneralUser GS (about 30 MB, free to use):

  https://schristiancollins.com/generaluser.php

Then either:

  • save it as ${default_path}
  • set VALDA_SOUNDFONT=/path/to/soundfont.sf2
  • pass --soundfont /path/to/soundfont.sf2

On Debian/Ubuntu, `sudo apt install fluid-soundfont-gm` also works.'
}
