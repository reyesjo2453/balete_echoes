# Review — BALETE: Echoes of the Sunken Veil (Game Intro)

## 1. Creative Calls & Alternatives Not Built

- **Built Storyline 1 ("Four Minutes, Seventeen Seconds" — The Borrowed-Time Overture):** An object-to-object prologue following Lolo Pido's balete pocket watch from the nine stopped parlor clocks (`4:17 AM`) and the 1998 flood rewind into Teo's inheritance and the Quiapo title screen (`title_keyart.webp`), scored at 80 BPM with Scott Buckley's *Aphelion* (`144.765 s` offset so the musical swell lands on the `25.5 s` title reveal) and Quiapo rain/SFX from `godot/assets/`.
- **Storylines not built:**
  1. *"The Sundô's Seal"* — an ensemble cast parade cutting around the rotating watch dial across Teo, Lola Ising, Kardo, Lolo Pido, Mang Berto, and Celeste (kept as an unbuilt alternative because it risked spoiling Act 3's Celeste reveal).
  2. *"Abangan: The Night Shift"* — a rain-first teleserye cold open that withholds music until Magwayen's boat enters the doorway.
- **Canon UI fusion:** Combined the game's actual comic art, `ep1_c02_pido_rewind.mp4` animated clip, fonts (`Anton`, `Oswald`, `Barlow`), and JRPG cobalt `Retro.window` (`PRESS START` button) with a deterministic SVG sundô dial crest and seeded canvas spirit motes.

## 2. Measured vs. Visually Checked

- **Measured via `npx hyperframes check --json` (revision `84690b73-aa10-4d1e-9713-2acf2d92787c`):**
  - Lint: `0` errors (`1` kept warning — see §4).
  - Runtime: `0` errors, `0` warnings.
  - Layout: `0` errors across `9` samples (`2 s .. 34 s`).
  - Contrast: `11/11` checked text blocks passed.
  - Craft: `0` errors, `0` warnings across `288` temporal samples (`0.125 s` step — verified no `line_unread`, `dead_stretch`, `text_below_floor`, or `first_frame_empty`).
  - Audio mix spec in `check`: `0` errors, `0` warnings across 13 tracks (`bgm-aphelion`, `sfx-rain`, and 11 beat-locked SFX clips).
- **Visually inspected via `snapshot --review` and targeted `--at` contact sheets:**
  - `review-beats-1.jpg`, `review-beats-2.jpg`, `review-phone-1.jpg`, `review-phone-2.jpg`, `review-seam-02.jpg`, `review-seam-08.jpg`, and verification sheet `f9e8f39f-6ffe-4918-9c8f-661755245dae/contact-sheet.jpg`.
  - Confirmed `<video>` playback animates across `4.6 s` and `5.2 s` (`ep1_c02_pido_rewind.mp4` water splash), caption cards are crisp at 360 px phone scale, and the landed title lockup (`28.5 s .. 35.75 s`) holds still.
- **Fixes applied after visual review:**
  - **P0 — `t=28.5 s · scene-07-title`:** Removed the Baybayin glyph line (`ᜊᜎᜒᜆᜒ`) that rendered as five missing-glyph boxes (`▯▯▯▯▯`) because neither the game fonts (`godot/assets/fonts/`) nor system fonts cover `U+1700–U+171F`; aligned the title lockup (`QUIAPO, MANILA · 1998 – 2026` -> `BALETE`) to match [main.gd](file:///home/antigravity/reyesjo2453/balete_echoes/godot/scripts/main.gd) inside the rotating sundô seal.
  - **P1 — `t=4.4 s, 21.3 s · scenes 01..06`:** Wrapped `.caption-band` inside an unstyled `.caption-slot.clip` and animated `.caption-band` directly so the dark caption box and left accent border never appear 1–2 frames before the text fades in.
- **Not heard:** Audio tracks, loudness, and hit timing were measured via `ffprobe` / FFmpeg / `hyperframes audio --json`. **The sound was measured, not heard.**

## 3. Weakest Shot & Future Iteration

- **Weakest shot:** `scene-02a-flood.html` (`3.0–4.3 s`). At 1.3 s (`1` bar minus the rewind clip), `PARLOR SWALLOWED` enters and exits quickly compared with the 3.0 s holds around it. With more time, extending the full opening to 42 s so `scene-02a-flood` gets a full 2.25 s beat before Pido's rewind clip would let the flooded parlor breathe longer.

## 4. Warnings Kept on Purpose

- `composition_file_too_large` on `index.html` (`304` lines): kept deliberately because `index.html` only declares root timeline variables, mounts the 10 modular scene files under `compositions/`, and arranges the 13 non-overlapping `<audio>` stems cleanly with one attribute per line for Studio/human readability.
