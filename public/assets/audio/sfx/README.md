# Balete SFX — Sources & Licences

Assembled Nov 8–9, 2026 (UTC). All files are **CC0 1.0** unless noted. No file in
this folder comes from a source that forbids redistributing the raw file — that
rules out Mixkit, ZapSplat Basic, Sonniss, 99Sounds, and BBC Sound Effects, none
of which are used here. The repo `balete_echoes` is public, so every file below
may be committed as-is.

**AI-generated content:** the SFXMint files and the two ffmpeg builds derived
from them are AI-generated/synthesised. If the game is shipped on Steam or
itch.io, add the platform's AI-generated-content disclosure. The Kenney and
OpenGameArt files are real recordings, not AI.

**Attribution:** none required for any file in this folder (all CC0). The
Freesound "Rain Loop" by qubodup (CC-BY 3.0) was NOT used — see Failures below.

## Final files

| File | Source file | Creator / source | Duration | Size | Licence | AI? |
|---|---|---|---|---|---|---|
| slash-knife.ogg | `knifeSlice.ogg` | Kenney — RPG Audio pack | 0.60 s | 15,532 B | CC0 | No |
| hit-thud.ogg | `impactSoft_heavy_001.ogg` | Kenney — Impact Sounds pack | 0.57 s | 6,689 B | CC0 | No |
| hit-thud-metal.ogg | `impactMetal_light_002.ogg` | Kenney — Impact Sounds pack | 0.24 s | 6,804 B | CC0 | No |
| ui-select.ogg | `select_001.ogg` | Kenney — Interface Sounds pack | 0.04 s | 5,468 B | CC0 | No |
| heal-chime.ogg | `glass_001.ogg` | Kenney — Interface Sounds pack | 0.28 s | 6,103 B | CC0 | No |
| dodge-swish-1.wav | `swish-1.wav` | artisticdude — "Swishes Sound Pack", OpenGameArt | 0.13 s | 34,138 B | CC0 | No |
| dodge-swish-9.wav | `swish-9.wav` | artisticdude — "Swishes Sound Pack", OpenGameArt | 0.20 s | 52,906 B | CC0 | No |
| air-whoosh.wav | `whoosh2_0.wav` | qubodup — "Air Whoosh", OpenGameArt | 5.25 s | 925,662 B | CC0 | No |
| boss-growl-02.mp3 | `horror-growl-02.mp3` | SFXMint — Monster Growl set | 2.00 s | 33,061 B | CC0 | Yes |
| boss-growl-08.mp3 | `horror-growl-08.mp3` | SFXMint — Monster Growl set | 6.00 s | 97,009 B | CC0 | Yes |
| command-exit-riser.mp3 | `transition-riser-01.mp3` | SFXMint — Transition set | 2.00 s | 33,061 B | CC0 | Yes |
| extra-chime.mp3 | `feedback-success-02.mp3` | SFXMint — "Warm Gentle Success Chime 02" | 2.00 s | 33,061 B | CC0 | Yes |
| rain-loop.ogg | `3.ogg` (from Rain OGG.zip) | Ylmir — "Rain (loopable)", OpenGameArt | 45.00 s | 913,769 B | CC0 | No |
| footsteps-wet.ogg | `mud_02.ogg` (from 25-CC0-mud-sfx.zip) | rubberduck — "25 CC0 mud sfx", OpenGameArt | 0.68 s | 35,215 B | CC0 | No |
| command-enter-pitchdrop.mp3 | **built** — see Builds | OGA Air Whoosh (CC0) via ffmpeg | 2.02 s | 50,199 B | CC0 | No |
| stagger-break-3tone.mp3 | **built** — see Builds | SFXMint chime-bar-60 (CC0) via ffmpeg | 2.13 s | 52,461 B | CC0 | Yes (source) |

## Source details (page URL / direct download URL)

- **Kenney RPG Audio** — page https://kenney.nl/assets/rpg-audio — direct ZIP
  https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip
  (CC0 1.0; pack ships its own `License.txt`, copied here as
  `kenney-rpg-audio-LICENSE.txt`). Note: the direct media URL returns the asset
  page HTML unless a `Referer: https://kenney.nl/assets/rpg-audio` header is sent.
- **Kenney Impact Sounds** — page https://kenney.nl/assets/impact-sounds — direct ZIP
  https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip
  (CC0 1.0; `kenney-impact-sounds-LICENSE.txt`). Same Referer requirement.
- **Kenney Interface Sounds** — page https://kenney.nl/assets/interface-sounds — direct ZIP
  https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip
  (CC0 1.0; `kenney-interface-sounds-LICENSE.txt`). Same Referer requirement.
- **Swishes Sound Pack** (artisticdude) — page
  https://opengameart.org/content/swishes-sound-pack — direct ZIP
  https://opengameart.org/sites/default/files/swishes.zip (CC0 1.0).
  Real recordings (clothes hanger + sticks swung past a mic).
- **Air Whoosh** (qubodup) — page https://opengameart.org/content/air-whoosh —
  direct https://opengameart.org/sites/default/files/whoosh2_0.wav
  (CC0 1.0; WAV PCM 16-bit 44.1 kHz stereo).
- **Rain (loopable)** (Ylmir) — page https://opengameart.org/content/rain-loopable —
  direct https://opengameart.org/sites/default/files/Rain%20OGG.zip (CC0 1.0).
  Zip contains 4 real field recordings (1.ogg 27 s, 2.ogg 26 s, 3.ogg 45 s,
  4.ogg 37.5 s); `rain-loop.ogg` is 3.ogg, the longest. Recorded ~2 hours of
  rain; files are loopable by design.
- **25 CC0 mud sfx** (rubberduck) — page https://opengameart.org/content/25-cc0-mud-sfx —
  direct https://opengameart.org/sites/default/files/25-CC0-mud-sfx.zip
  (CC0 1.0; 25 files mud_01–mud_25.ogg, 0.48–0.73 s each). `footsteps-wet.ogg`
  is mud_02.ogg; the full pack is in `raw/mud/`.
- **SFXMint** — licence page states all library sounds CC0 1.0, no signup.
  Direct MP3s via https://sfxmint.com/dl/<slug>.mp3 :
  - `horror-growl-02.mp3` ("Low Monster Growl 02", 2.0 s) and
    `horror-growl-08.mp3` ("Rumbling Monster Growl 08", 6.0 s) — page
    https://sfxmint.com/sounds/horror-growl
  - `transition-riser-01.mp3` ("Rising Whoosh" / transition riser, 2.0 s) — page
    https://sfxmint.com/category/transition
  - `instrument-chime-bar-60.mp3` (chime-bar strike, 5.0 s — raw material for
    the 3-tone build) and `feedback-success-02.mp3` ("Warm Gentle Success
    Chime 02", 2.0 s).
  SFXMint files are AI-generated (open-source models / procedural synthesis).
  NOTE: anonymous downloads are capped at 5/day per network — the cap was hit
  on Nov 8 and the downloads only succeeded after the midnight UTC reset
  (Nov 9 00:01 UTC). A free account's API key raises it to 20/day.

## Builds (ffmpeg)

- **command-enter-pitchdrop.mp3** (2.02 s, MP3 192 kbps): first 2.0 s of the OGA
  Air Whoosh, split into 4 × 0.5 s segments with falling pitch
  (asetrate 1.00 → 0.90 → 0.80 → 0.70, atempo-compensated to keep duration),
  concatenated. Verified: mean volume −25.8 dB, max −10.7 dB (not silent);
  zero-crossing rate falls monotonically 3566 → 3245 → 2850 → 2511 Hz across
  the four quarters — the pitch drop is real.
- **stagger-break-3tone.mp3** (2.13 s, MP3 192 kbps): SFXMint chime-bar strike
  (fundamental measured ≈ 987 Hz) trimmed to 2.0 s, three copies pitch-shifted
  to ≈ 880 / 1320 / 1760 Hz (ratios 0.892 / 1.338 / 1.783), staggered 0 / 80 /
  160 ms, mixed, loudness-normalised (−16 LUFS). Verified: mean −22.8 dB,
  max −3.8 dB; FFT shows the 1760 Hz tone dominant in the tail with the
  2640 Hz (3×880) partial — a bright three-tone chime chord (root/fifth/octave).

## Failures / substitutions

- **Freesound (both attempts) — FAILED, anonymous download blocked.** "Rain Loop"
  by qubodup (CC-BY 3.0, 10:00 seamless) and "Walking through Mud" by Breviceps
  (CC0, 0:25) both return HTTP 403 without a login; Freesound requires a free
  account to download. No account was created (per task). Substituted with
  OGA CC0 equivalents: Ylmir's "Rain (loopable)" for rain, rubberduck's
  "25 CC0 mud sfx" for footsteps. The qubodup rain loop would still need its
  CC-BY credit if ever used — it was NOT downloaded.
- **itch.io Fantasy SFX Free Sampler — FAILED, JS-gated download.** The $0
  pay-what-you-want flow returns a signed download page; the file buttons are
  JS-driven and the POST endpoint rejected every curl attempt
  ("mismatched token" → "expected accept_nda" → "token expired" →
  "missing download key"). No account was created, nothing paid. The healing
  chime it would have supplied is covered by Kenney `glass_001.ogg`
  (`heal-chime.ogg`) and the SFXMint success chime (`extra-chime.mp3`).
- **SFXMint "Fast Air Whoosh Transition 11" — not downloaded.** The transition
  category page does not expose that exact slug in its static HTML, and the
  OGA Air Whoosh already covers the whoosh raw material. Not needed.
- **Pixabay — not attempted.** Blocked in this environment (per prior research);
  no Pixabay file is used.

## Raw material kept

`raw/` holds the original ZIPs, extracted packs, and page HTML used to trace the
downloads (kenney_*, swishes, mud, rain, whoosh2_0.wav, SFXMint MP3s, and the
itch/Freesound attempt artefacts). The flat files in this folder are the
ship-ready set.
