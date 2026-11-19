# HANDOFF.md: start here

Engineering + design handoff for a fresh session taking over *Balete: Echoes of the Sunken Veil*
(Godot 4.3). Updated Nov 19, 2026 at commit `fcc10db` (`origin/main` synced). Read this whole file before touching
anything; then read `docs/RETRO_JRPG_PLAN.md` (earlier design rounds) and `STORY_HANDOFF.md` (narrative snapshot).

---

## 1. The project and the person

- **John (repo owner, creative director).** He makes the creative calls; you build, test and report. He reviews on
  his phone through the deployed web build and the screenshots you send. He likes short, concrete reports
  (what changed, how to try it, what you were unsure about), Pinoy humor in the writing, and uses *Bleach* as a
  tone touchstone (humor sprinkled into quiet moments, never in the tragic beats). When a choice is genuinely his
  (story canon, names, tone, spending art credits on something big), ask; otherwise pick a sensible default, say so,
  and proceed. He often answers "Go for it" / "Yes, go ahead".
- **Privacy:** never put John's email or personal details into external services (including art prompts).
- **Canon order when documents disagree:** `docs/STORY.md` (story bible) > `docs/RETRO_JRPG_PLAN.md` (retro JRPG
  direction) > `docs/EPISODIC_DIRECTION.md` (older systems doc, partly superseded) > `STORY_HANDOFF.md` (narrative
  snapshot) > everything else. `web-legacy/` is the retired draft: reference only.
- **Git:** currently on branch `main` at `fcc10db` (synced with `origin/main`). CI (`.github/workflows/pages.yml`)
  triggers on `main` and `ccr-d444c2c4-76rlh3`, stamps `godot/data/build.json`, runs the play-time estimate and
  smoke tests, then exports Web + Linux and deploys the Web build to GitHub Pages. Don't open PRs unless John asks.

## 2. What the game is now

A **retro HD-2D JRPG** (John's pivot, away from the earlier Telltale/comic style; the painted art style stays for
key moments and title keyart):
- **HyperFrames opening movie & HD-2D title screen** (`intro-video/`, `godot/scripts/main.gd`): a 36 s, 1080p,
  80 BPM Final Fantasy-style opening movie (`godot/assets/clips/balete_intro.ogv`) auto-plays on fresh boot (when no
  run save exists), after 24 s idle attract mode, via **WATCH INTRO**, or via `?intro=1`. The redesigned title screen
  features breathing `title_keyart.webp`, directional midnight scrim, floating gold/cyan spirit motes, cobalt JRPG
  command menu, and an in-game **CHAPTER & FIGHT SELECT** overlay (jump to any chapter/act or test showcase
  boss/team-combo fights directly, including Act 3 `aswang_finale`).
- **Walkable HD-2D maps, 12-frame character walks, 3D dioramas & SectorMap routes** (`explore_map.gd`, `sector_map.gd`):
  9 maps in `godot/data/maps.json` (`parlor`, `parlor_flood`, `hidalgo`, `estero`, `lola_room`, `pumphouse`, `morgue`,
  plus walkable hub transit corridors `quiapo_alley` and `service_alley` with companion following, zone banter, and
  ambient murmurs). Both Teo (`teo_walk.png`, 1008×132) and Kardo (`kardo_walk.png`, 1128×132) use 12-frame walk strips
  with zero synthetic bobbing and cleanly revert to idle frames on stop. Maps include 3D diorama `boxes`, rain/mist/dust
  particle weather, and 4 **SectorMap** `route` transitions between hubs (`route_to_estero`, `route_to_pumphouse`,
  `route_back_hidalgo`, `route_to_morgue`).
- **SNES-style blue text boxes** (`dialogue.gd`, `art.gd`, `sfx.gd`): HD-polished pixel portraits (`assets/portraits_px/`,
  264×264) with expression lookup (`Art.portrait(id, expr)`, auto-`tense` on `shake` lines, falling back to base bust),
  portrait pop-in, FF7-style overhead animations/emotes (`!`, `?`, `sweat`, `...`), 16-bit speaker blips and UI SFX,
  blank-choice guard, punchy Taglish Manila buddy humor, and three line types (`say`, `think`, `narr`).
- **Comic panels only for big moments:** 13 panels in Episode 1 (plus `title_keyart.webp` and `ep1_c02_pido_rewind.ogv`;
  `smoke.gd` asserts `all_panels.size() <= 13`).
- **One unified side-view HD-2D ATB battle system** (`stage_battle.gd`): every fight runs on its map with party (1–3),
  ATB bars, parry/dodge rings, `REWIND?` reaction, specials, **Stagger bar mechanic** (`1.5x` damage while
  `STAGGERED`, interrupts enemy charge and resets `foe_atb`), **Team Combos** (`HATID SA KURYENTE` and `DASAL NG DALAWA`
  with dual-portrait cut-ins), **boss phase-gate clamping & escalations** (Berto Phase II, Hound Phase II, Act 2 Aswang
  scripted-death awakening + 50% escape, Act 3 Parlor finale `aswang_finale` 380 HP 3-phase boss with flight and
  `SAKMAL: OVERLOAD`), **battle bystander reactions** (including escape reactions), dynamic 3D battle camera, hitstop,
  procedural `FxBurst` VFX, and Scale2x/Scale3x HD-2D sprites scaled via `data/sprite_scales.json`.
- **Visible enemies on the map** (e.g. Mang Andoy on Hidalgo Street: walk into him to fight).

Episode 1, *Ang Lumang Orasan*: ~73 min estimated (range 62–87 min; Act 1: 31.4 min, Act 2: 20.2 min, Act 3: 21.0 min;
530 scene steps across 49 scenes, 22 choices/QTEs, longest unprompted stretch 10.6 min), 55 flow beats across 3 acts,
**7 fights** (`lunod`, `lunod_tide`, `ligaw_berto`, `unsent`, `aswang`, `hiraya_hound`, `aswang_finale`). Story beats
and choices are listed in `STORY_HANDOFF.md`.

## 3. What recent sessions built (newest first)

| Commit | What |
|---|---|
| `fcc10db` | Added **Kardo 12-frame walk cycle** (`kardo_walk.png`, companion/cast non-gliding walk in `explore_map.gd`), reworked **Act 2 Aswang** into a grounded stalker with **scripted death -> Watch Awakening** (`_scripted_ambush_kill`, revive at 100% HP + HASTE + `+5` hit) that **flees at 50% HP** (`outcome = "fled"`), added **Act 3 Parlor Finale** (`aswang_return` + `aswang_finale`, 380 HP, 160 Stagger, 3-phase Teo+Kardo boss + Showcase menu button), comedic Taglish timing rewrite across Acts 1–3 (`build_episode1.py`), and **HD-2D asset polish** (`tools/hd_polish.py`, `sprite_scales.json`, Scale2x/3x sprites, 264×264 portraits, `van.png`, `truck.png`). |
| `0fb956d` | Fixed 3-phase boss transitions (phase-gate HP clamping so single heavy hits cannot skip Awakening / Phase II / Phase III) and added the **Stagger bar mechanic** (`STAGGERED! 1.5x`, ATB reset, `send_home` 1 HP safety clamp while staggered). |
| `69c56d9` | Refreshed `HANDOFF.md` for Episode 1 build. |
| `df8e427` | Fixed enemy sprite idle-height jitter (`_idle` / `_idle_b` aligned), upgraded HD-2D mob combat animations (coiled windups, arcs, afterimages, impact FX, stagger recoil, clean `_foe_moving` reset), and added 3-phase boss escalation. |
| `7298313` | HD-2D upgrade: dynamic 3D battle camera (`battle_cam_shot`/`focus`), expanded `FxBurst` VFX (`cross_slash`, `lightning`, `prayer_motes`, `shockwave`), 3D diorama `boxes` across maps, **SectorMap** (`sector_map.gd`) with 4 Quiapo district `route` beats, and expression portrait lookup (`Art.portrait(id, expr)`). |
| `2faa155` | Integrated HyperFrames opening intro movie (`balete_intro.ogv`) into Godot (`main.gd`): auto-plays on fresh boot, 24 s title attract mode, **WATCH INTRO** button, `?intro=1`, skip controls, and web audio unmute toggle. |
| `bb48480` | Created `intro-video/` HyperFrames project (36 s, 1920x1080, 30 fps, 80 BPM *Aphelion* + Quiapo SFX) and rendered `balete_echoes_intro.mp4`. |
| `6dda893` | Added **battle bystander reactions** (map NPCs react with anims, emotes, and barks), **decision reactivity** (`loob_min`, `utang_min`, `bond_min` in `story.gd`, `has_white_streak` auto-flag), and walkable **hub transit corridors** (`quiapo_alley`, `service_alley` with companion following & ambient banter). |
| `d0b8114` | Fixed title screen lockup and added battle camera focus, hitstop (`_hitstop`), utang aging polish, and rain/mist particle weather (`_rain`, `_mist`). |
| `0423a99` | Episode 1 UX/mobile audit, 16-bit SNES UI ticks & emote SFX (`sfx.gd`), redrew `ep1_03_lola_packing`, and **removed legacy combat system** (`combat.gd`, `battle_model.gd`, `battle_actor.gd`, `silhouette.gd`, `data/enemies.json`, `assets/battle/`). |
| `24eceab` | Redesigned HD-2D title screen (`title_keyart.webp`, motes, midnight scrim, cobalt menu) and added in-game **Chapter & Fight Select** overlay. |
| `48c2a9a` | Added FF7-style overhead character animations & emotes in maps, typewriter speaker blips, dual-portrait team-combo cut-ins, and Pinoy humor polish in `build_episode1.py`. |
| `141a139` | Episode 1 AAA polish: **Team Combos** (`HATID SA KURYENTE`, `DASAL NG DALAWA`), **2-phase bosses** (Berto, Hound), repositioned `REWIND?` box (`REACT_BOX`), updated 4 comic panels (`ep1_15`, `ep1_31`, `ep1_35`, `ep1_c03`), and blank-choice guard in `dialogue.gd`. |

## 4. Systems reference

All game paths under `godot/` unless noted:

- **`scripts/main.gd`**: flow driver (`card`, `act_card`, `chapter`, `scene`, `hub`, `transit`, `route`, `fight`, `end`),
  HyperFrames intro player (`_play_intro`, `_watch_intro`, `ATTRACT_IDLE = 24.0`), HD-2D title screen (`_TitleMotes`,
  `title_keyart`), **Chapter & Fight Select** (`_open_chapter_select`, `_start_from_chapter`, `_quick_fight`, includes
  `aswang_finale`), and URL / env review hooks (`?scene=`, `?map=`, `?panel=`, `?fight=`, `?intro=`, `?auto=`,
  `?demo=`, `?miss=`).
- **`scripts/stage_battle.gd`**: the sole battle system. Party `MEMBERS` (`teo`, `pido`, `kardo`, `ising`), `PRAYERS`
  (`paalam`, `uwi`, `tawid`), `ANCESTORS` (summons).
  - **Stagger & Phase Gates**: `_add_stagger_pct`, `_enter_stagger` (`STAGGER_MULT = 1.5`, clears ATB, interrupts
    charge), `_next_gate_hp` / `_has_pending_gate` / `_check_gates` (clamps single-hit bursts at awakening/phase
    thresholds and `flee_below` escape floor; `send_home` safety clamp holds staggered ghosts at 1 HP).
  - **Scripted Death Awakening & Flee** (`aswang` Act 2): `foe_floor` prevents pre-awakening kills; lethal blow or
    Turn-2 `_scripted_ambush_kill()` intercepts `_lose()` (`_pending_scripted_awaken`), runs
    `_trigger_scripted_death_awakening()` (full heal, `HASTE` 1.5×, `+5` hit mod on duplicate `Unit.d`), then drives
    `aswang` to `flee_below: 0.5` → `_win("fled")`.
  - REWIND: `_strike` / `_special` call `_offer_rewind` on a miss; `_bearer`, `_rewind_ready`, `_charge_watch` (up to 3).
    Teo pays +1 `utang`, Pido doesn't. Would-be wipes wait (`_pending_loss`).
  - Costs & specials: `candles` (Teo 4, Pido 5), Kardo `heat`, Lola `tired`, `_discharge` (KONTRA), `_orasyon`,
    `_pray`/`_sequence` (HATID), `_summon` + `_summon_card`.
  - **Team Combos** (cost 1 `utang na loob` / `Story.gratitude`, dual-portrait cut-in `_cut_in_dual`): `_combo_kuryente`
    (Teo + Kardo *HATID SA KURYENTE*) and `_combo_dalawa` (Teo + Lola *DASAL NG DALAWA*).
  - **Multi-phase bosses**: `_phase`, `_phase2`, `_phase3`, `_enter_phase`, `_active_attacks`, `_active_special`, `_foe_every`.
  - **Bystanders & HD-2D feel**: `_init_bystanders`, `_react_bystanders` (incl. `win_fled`), `_hitstop`, `_windup`,
    `_foe_lunge`, `_foe_impact_fx`, `_dodge_evade`, `_foe_stagger_recoil`, `_foe_combo_reposition`, `_lunge`,
    `_afterimage`, `_tally`. Uses `data/sprite_scales.json` (`_px_for`) so Scale2x/3x sprites preserve exact world height.
  - Test hooks: `fast`, `demo`, `test_miss`, `auto_react`, `auto_charge`, `auto_rhythm`.
- **`scripts/special_gauge.gd`**: special inputs `charge` (KONTRA), `rhythm` (ORASYON), `react` (REWIND? at `REACT_BOX`
  `Rect2(660, 365, 580, 185)`, `REACT_SECS = 1.85`, `REACT_HOLD = 0.30`), `wind`.
- **`scripts/fx_burst.gd`**: procedural drawn battle VFX (`spark`, `slash`, `cross_slash`, `lightning`, `prayer_motes`,
  `shockwave`, `ring`, `clock`).
- **`scripts/sector_map.gd`**: Quiapo district route-traversal overlay (`route` beats) showing Teo walking between lit
  district nodes (`parlor`, `hidalgo`, `quiapo_alley`, `estero`, `pumphouse`, `service_alley`, `morgue`).
- **`scripts/explore_map.gd`**: walkable 3D/HD-2D maps, 12-frame walk strips (`teo_walk`, `kardo_walk` via
  `_update_companion` & cast walking with `bob = 0`), 3D diorama `boxes`, weather (`_rain`, `_mist`, `_dust`), scene
  staging (`act()`), FF7-style anims & overhead emotes (`_trigger_anim`, `_trigger_emote`), `transit_mode` corridors with
  companion following & zone/murmur banter, battle bystanders (`spawn_bystanders`, `bystander_react`,
  `bystander_bark`), and dynamic battle camera (`battle_cam_focus`, `battle_cam_shot`, `battle_cam_reset`).
- **`scripts/dialogue.gd` & `scripts/art.gd`**: dialogue windows, choices (blank-choice guard), QTEs, typewriter
  speaker blips, greyed Teo portrait, comic panel + `.ogv` clip lookup, and `Art.portrait(id, expr)`.
- **`scripts/sfx.gd`**: BGM crossfading (`data/music.json`), plus synthesized 16-bit SNES UI ticks (`ui_move`,
  `ui_confirm`), emote stingers (`emote`), speaker blips (`blip`), `watch_tick`, `phase_shift`, `sent_home`.
- **`scripts/levels.gd`, `scripts/case_closed.gd`, `scripts/progress.gd`**: CASE CLOSED level-ups/perks and persistent
  season save (`user://balete_save.json`).
- **`scripts/story.gd`**: run state (`utang`, `gratitude`, `loob`, `bonds`, `flags`, `has_white_streak` auto-flag,
  `loob_min`/`utang_min`/`bond_min` checks in `cond_ok`, checkpoints in `user://balete_run.json`).
- **Data:** `data/stage_enemies.json` (enemies, stagger caps, specials, `phase2`, `aswang_finale` `phase3`),
  `data/sprite_scales.json` (Scale2x/3x scale multipliers), `data/maps.json` (9 maps + diorama `boxes` + transit
  zones/banter), `data/episode1.json` + `data/episode1_flow.json` (**generated**, don't edit by hand).
- **Scripts & Tools:**
  - `tools/build_episode1.py`: all 49 scenes (`S[...]`), `FLOW`, staging (`STAGES`, `direct()`, `big()`), recap lines.
  - `tools/hd_polish.py`: pure-numpy AdvMAME Scale2x/Scale3x pixel upscaler, `kardo_walk.png` cutter, `sprite_scales.json`
    writer, portrait upscaling.
- **Opening intro movie (`../intro-video/`):** standalone HyperFrames project (`SPEC.md`, `REVIEW.md`, `index.html`,
  `compositions/`, `renders/balete_echoes_intro.mp4`) producing `godot/assets/clips/balete_intro.ogv`.

## 5. Commands and workflow

```bash
# Godot 4.3 (install 4.3-stable + export templates per .github/workflows/pages.yml if not in container)
G=godot

python3 tools/build_episode1.py          # regenerate episode JSON after any script/flow/staging edit
python3 tools/estimate_playtime.py       # per-act minutes, longest stretch without input

cd godot
$G --headless --import                   # after adding art, or after a container restart
$G --headless --path . res://tests/Smoke.tscn 2>&1 | grep -E "FAIL|SCRIPT ERROR|failures:"
#   must end "== done, failures: 0 ==" (~2–5 min). Expected noise: "Parse JSON failed" (corrupt-save test),
#   and headless renderer 'Parameter "m" is null' / mesh_get_surface_count lines.
```

- **Intro video (`intro-video/`):** `npm run check` (`npx --yes hyperframes@0.9.65 check`) and `npm run render`; convert
  rendered MP4 to Ogg Theora (`godot/assets/clips/balete_intro.ogv`) with `ffmpeg` if updated.
- **Screenshots / recordings** (what John sees): `xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver
  opengl3 --resolution 1280x720 --write-movie OUT/f.png --fixed-fps 10 --quit-after N` with env vars
  `BALETE_SCENE=<scene id> BALETE_AUTO=1`, `BALETE_MAP=<hub id>`, `BALETE_INTRO=1`, or
  `BALETE_FIGHT=<enemy> BALETE_DEMO=1 [BALETE_MISS=1]`. Run long captures in the background and wait for completion;
  contact-sheet frames with PIL.
- **Review links for John** (append to the Pages URL): `?scene=<id>&auto=1`, `?map=<hub_id>`, `?panel=<panel_id>`,
  `?fight=<enemy>&demo=1` (`&miss=1` forces a missed ring to show REWIND), `?intro=1`.
- **Before committing:** `rm -rf tools/__pycache__`; delete untracked `.import` files
  (`find godot -name "*.import" -delete`); avoid committing untracked `graphify-out/` unless intended.

## 6. Gotchas (learned the hard way)

- **Dozens of "missing art" test failures** at once = stale import cache (usually after a container restart).
  Re-run `--import`; it's not your change.
- **Guided first parry** (the Pido tutorial) retries until hit, so `miss=1` skips it and misses a later ring.
- **Staging:** on the estero map keep staged characters at `z <= ~8` or the text box covers them; give a `focus` in
  front of them. On the parlor map avoid placing stage cast inside furniture `solids` bounds (`x=6..12, z=6.4..7.2` is clear).
  A `big()` panel needs an explicit panel id if the step has none.
- **No Baybayin glyphs in game fonts:** `godot/assets/fonts/` and system fonts lack `U+1700–U+171F`, so Baybayin
  strings render as missing-glyph boxes (`▯`).
- **Shell:** `rm` on a variable path must be written `"${S:?}"/...` (a safety check blocks bare `$S/*`); a plain
  foreground `sleep` is blocked: use background tasks or `NotificationTimeoutSeconds`.
- **Smoke tests encode design numbers** (7 fights, survive turns, candle counts, panel count <= 13, Act 2 `aswang`
  scripted-death + `"fled"`, Act 3 `aswang_finale` 380 HP 3-phase gates / `SAKMAL: OVERLOAD`, Kardo 12-frame walk,
  3× HD sprite idle-height diff <= 9 px). When you change a design number, update `tests/smoke.gd` in the same commit.
- **Art:** never put real brands in generated art (a "Singer" sewing machine was dropped for this).

## 7. Art pipeline

- **OpenArt / `generate_image` + `tools/hd_polish.py`:** `hd_polish.py` provides pure-numpy AdvMAME `scale2x_rgba` /
  `scale3x_rgba` upscaling, strict magenta edge despill (`despill_magenta_edges`), `build_kardo_walk` 4×3 sheet cutter,
  and `godot/data/sprite_scales.json` generation so sprites stay sharp at 2×/3× without shrinking/growing in 3D space.
- Cut legacy sprite sheets with `python3 tools/pixel_sprites.py cells SHEET COLS ROWS OUTDIR name1 name2 ... --height H`
  ("-" skips a cell); check for bleed from neighbouring cells; keep battle `_idle` and `_idle_b` sprite heights aligned
  within `<= 3` source pixels (`<= 9 px` after `scale3x_rgba`) to prevent vertical jitter.

## 8. Open items and next steps

**Recently completed:**
- Stagger bar mechanic (`1.5x` multiplier, ATB reset, `send_home` safety clamp) and 3-phase boss gate clamping (`0fb956d`).
- Kardo 12-frame non-gliding walk strip (`kardo_walk.png`), Act 2 Aswang scripted-death Watch Awakening + roof escape
  (`outcome = "fled"`), Act 3 Parlor Big-Bad finale (`aswang_return` + `aswang_finale` 3-phase), comedic Taglish banter
  rewrite, and HD-2D Scale2x/Scale3x sprite + `264×264` portrait polish (`fcc10db`).

**Offered, waiting on John:**
- Playtest feedback on the deployed `fcc10db` build (Kardo's walk cycle, comedic timing, Act 2 Aswang scripted defeat
  into Act 3 Parlor finale difficulty curve, HD-2D sprite sharpness on mobile).
- Trim Act 1 pacing if needed (currently ~31.4 min; Episode 1 total ~73 min); ask John which scenes drag before cutting his writing.
- Extend `intro-video/` from 36 s to 42 s if desired (`scene-02a-flood.html` currently runs 1.3 s — see `intro-video/REVIEW.md`).

**Known, unresolved / ready for next work:**
- **Expression portraits (`assets/portraits_px/<id>_<expr>.png`):** `Art.portrait(id, expr)` and `Dialogue` (`expr` /
  auto-`tense` on `shake`) are wired, but no `<id>_<expr>.png` files exist in `assets/portraits_px/` yet (all currently
  fall back to base portraits).
- **Audio live check on `intro-video/`:** mix and loudness were measured via FFmpeg / `hyperframes check`, not heard
  live in the headless environment.
- **Balance numbers are first guesses:** candles (Teo 4, Pido 5), REWIND cap 3, heat step 10%, HATID II at Loob 2,
  summon power 38 / heal 28, boss phase thresholds & Stagger caps (`aswang` 220/100, `aswang_finale` 380/160).
- **The watch's true rule** (why the flood went to Santa Ana) is deliberately undecided: John's call, don't invent it.
- **Sol Agbayani (Episode 2)** (Baybayin-glyph mechanic, reads the heartwood names) isn't built; Teo's TAWAG is gated on
  the `heartwood_read` flag, waiting for him. Episode 2 content doesn't exist yet.
- **Party roster for the season (`docs/STORY.md`):** Teo; Kardo (joins Ep 2); Sol (Ep 2); Celeste (guest, then turns);
  Mayari (Ep 7). Lola is an Episode 1 guest and summoner; she may return late (John liked "both").
