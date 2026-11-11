# Music credits and cue map

The game plays music by **cue** (a mood), not by file. `godot/data/music.json` maps each cue to a file here; story
beats and scene steps name cues in `tools/build_episode1.py`, and enemies name one in `data/enemies.json` (default
`battle`). `"silence"` fades the music out for a big emotional beat. Changes between cues crossfade (`scripts/sfx.gd`).

**To drop in a real track:** put the file here (`.ogg` preferred, `.mp3` or `.wav` also work), set the cue's `file`
(no extension) and `volume_db` in `music.json`, and add its credit below and on the title screen (`main.gd`).

| Cue | Used for | File now | Licence |
|---|---|---|---|
| `title` | Title screen, end card | `aphelion.ogg` | CC-BY 4.0 |
| `wake` | The wake, Lola's stairs, the morgue, dawn (quiet talk) | `aphelion.ogg` (placeholder) | CC-BY 4.0 |
| `tension` | The flood, the creek, the chase, the offer | `undertow.ogg` (placeholder) | CC-BY 4.0 |
| `battle` | Ordinary fights | `determined-pursuit.ogg` | Public domain |
| `boss` | The aswang, the Hiraya hound | `ph_boss.ogg` (placeholder) | CC0 |
| `sting` | The cliffhanger reveal (plays once) | `ph_cliffhanger.ogg` (placeholder) | CC0 |
| `silence` | Lolo's clocks, the hatid, "2:40", the dead sundô, the white streak, the blank dial, the tape, the photograph | none | n/a |

## Tracks
- **Aphelion**, Scott Buckley. CC-BY 4.0. Source: https://www.scottbuckley.com.au/library/aphelion/
  Credit (required): `'Aphelion' by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au`
- **Undertow**, Scott Buckley. CC-BY 4.0. Source: https://www.scottbuckley.com.au/library/undertow/
  Credit (required): `'Undertow' by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au`
- **Determined Pursuit**, Emma_MA. Public domain (per its OpenGameArt page). Source:
  https://opengameart.org/content/determined-pursuit-epic-orchestra-loop (credit optional).
- **ph_boss**, **ph_cliffhanger**: synthesized for this project by `tools/make_placeholder_music.py` (drums, a
  gong ostinato, a drone; a boom, a rising cluster and a clock tick). Dedicated to the public domain under CC0 1.0.
  Placeholders only: replace them with scored cues.

The `wake` and `title` cues share a file for now; every other cue has its own. Give `wake` its own track when one is licensed.
