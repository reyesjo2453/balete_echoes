# HANDOFF.md: start here

Engineering + design handoff for a fresh Claude Code session taking over *Balete: Echoes of the Sunken Veil*
(Godot 4.3). Written Nov 17, 2026 at commit `6fd549a`. Read this whole file before touching anything; then read
`docs/RETRO_JRPG_PLAN.md` (what was built, round by round, and what is next).

---

## 1. The project and the person

- **John (repo owner, creative director).** He makes the creative calls; you build, test and report. He reviews on
  his phone through the deployed web build and the screenshots you send. He likes short, concrete reports
  (what changed, how to try it, what you were unsure about), Pinoy humor in the writing, and uses *Bleach* as a
  tone touchstone (humor sprinkled into quiet moments, never in the tragic beats). When a choice is genuinely his
  (story canon, names, tone, spending art credits on something big), ask; otherwise pick a sensible default, say so,
  and proceed. He often answers "Go for it" / "Yes, go ahead".
- **Privacy:** never put John's email or personal details into external services (including art prompts).
- **Canon order when documents disagree:** `docs/STORY.md` (story bible) > `docs/RETRO_JRPG_PLAN.md` (current game
  shape) > `docs/EPISODIC_DIRECTION.md` (older systems doc, partly superseded) > `STORY_HANDOFF.md` (narrative
  snapshot) > everything else. `web-legacy/` is the retired draft: reference only.
- **Git:** work on branch `ccr-d444c2c4-76rlh3`; push with `git push -u origin ccr-d444c2c4-76rlh3`. Never push to
  another branch; don't open PRs unless John asks. CI (`.github/workflows/pages.yml`) runs the play-time estimate
  and the smoke tests, then exports Web + Linux and deploys to GitHub Pages on every push. Commit messages end with
  the attribution lines your harness gives you.

## 2. What the game is now

A **retro JRPG** (John's pivot, away from the earlier Telltale/comic style; the painted art style stays):
- **Walkable HD-2D maps** (3D floors and props, pixel sprites as billboards) for every location; story scenes are
  *acted* on the map (characters walk, face, change pose, water rises).
- **SNES-style blue text boxes** with small pixel portraits; three line types: `say`, `think`, `narr`.
- **Comic panels only for big moments** (13 left in Episode 1; see `big()` calls in the generator).
- **Side-view ATB battles fought on the map itself** (`stage_battle.gd`): enemy left, party (1–3) right, time bars,
  the parry/dodge timing ring, special-move cut-ins, and each character's own special input.
- **Visible enemies on the map** (e.g. Mang Andoy on Hidalgo Street: walk into him to fight).

Episode 1, *Ang Lumang Orasan*: ~65 min estimated, 6 fights, 3 acts plus a 1998 cold open. Story beats and
choices are listed in `STORY_HANDOFF.md`.

## 3. What this session built (newest first)

| Commit | What |
|---|---|
| (Nov 19) | **Round 8, from a "grill-me" review with John** (decisions in `docs/RETRO_JRPG_PLAN.md`, round 8): the watch's rule stated; Celeste's streak decided (canon, Ep 4 reveal); Hidalgo Street folded into the walk in; Mang Ambo's death explained; the roof hand in 1998; Kardo's "they want the hand on it"; every story flag now read; systems staged by episode (`FROM_EPISODE`); aswang phase 2 (ANG GUTOM); three panels redrawn, the gate panel renamed. |
| `6fd549a` | Story fix: how Villacorta traced the 1998 flood. The ninth coffin washes up on his roof (brass plate); Pido at the same Santa Ana grave every 3 June; Benitez hints at the motive. The rewind's mechanism stays a deliberate mystery. Santa Ana is never called "downriver" (it is upriver on the Pasig). |
| `4102af3` | Tightening: cold open 3 fights → 2 (`co_wave` merged scene); aswang 17 → 9 enemy turns (the woken watch gives Teo 1.5× haste); Berto/Lola fight a little longer; victory tally; battle animation (breathing, anticipation, afterimages, white hit-flash, knockback, enemy wind-up during the ring, win hop). |
| `65ae632` | REWIND became a **reaction** (miss a parry → REWIND? → hold to undo the blow and retry); candles; utang na loob; Kardo's line heat; Lola tires; **TAWAG** summons; **CASE CLOSED** level-ups. |
| `78404da` | Specials: Kardo **KONTRA** (hold/release, overcharge shocks him), Lola **ORASYON** (rhythm taps; she fights beside Teo vs Mang Berto), **HATID II / TAWID** (7-arrow prayer, Loob 2). |
| `ea3b609` | Panels cut to 13; cold open and wake acted on maps; Pinoy humor pass. |
| `3869e1f` | Maps for Lola's room, the pump house, the morgue; 22 scenes acted. |
| `535aca0` | One battle system: every Episode 1 fight is a side-view battle on its map. |

## 4. Systems reference

All paths under `godot/`.

- **`scripts/stage_battle.gd`**: the battle. Party data `MEMBERS` (teo, pido, kardo, ising), `PRAYERS` (paalam,
  uwi, tawid), `ANCESTORS` (summons). Turn flow `_process` → `_member_turn` / `_foe_turn`; `_auto_pick` is the
  autoplay used by tests (`fast`) and review recordings (`demo`).
  - REWIND: `_strike` / `_special` call `_offer_rewind` on a miss; `_bearer`, `_rewind_ready`, `_charge_watch`
    (perfect parry +1, max 3). Teo pays +1 utang, Pido doesn't. A would-be party wipe waits (`_pending_loss`).
  - Costs: `candles` (`_fresh_candles`, `_candle_cost`, `_can_pray`), Kardo `heat`, Lola `tired`.
  - **Staged systems:** `FROM_EPISODE` + `uses(system)`. Candles, heat, pagod, SWIFT and Teo's HATID II turn on in
    Episode 2; Episode 1 teaches the core. Tests check each system with `"episode": 2` (`_play_stage` clears levels
    and perks for those runs) and that Episode 1 hides them.
  - **Phase two:** an enemy's `phase2` block in `stage_enemies.json` (below, name, gloss, say, tint, size, attacks,
    special) → `_check_phase` (cut-in, tint, bigger, new moves). An enemy that `awakens` the watch turns only after it.
  - Specials: `_discharge` (KONTRA), `_orasyon`, `_pray`/`_sequence` (HATID arrows), `_summon` + `_summon_card`.
  - Feel: `_lunge`, `_step_back`, `_afterimage`, `_blink`, `_breathe`, `_windup`, `_tally`.
  - Test hooks: `fast`, `demo`, `test_miss`, `auto_react`, `auto_charge`, `auto_rhythm`.
- **`scripts/special_gauge.gd`**: the special inputs: `charge` (KONTRA), `rhythm` (ORASYON), `react` (REWIND?),
  `wind` (kept for later watch powers).
- **`scripts/levels.gd`, `scripts/case_closed.gd`, `scripts/progress.gd`**: CASE CLOSED at the end of an episode
  (`main.gd` `_show_end`): level up + one of two perks each, saved per episode in `Progress.perks`. An episode only
  uses levels/perks earned *before* it, so replays play the same.
- **`scripts/story.gd`**: run state: `utang` (borrowed time; greys Teo's hair), `gratitude` (utang na loob: +1 per
  soul sent home, spent by Teo's TAWAG), `loob`, `bonds`, `flags`, checkpoints.
- **`scripts/explore_map.gd`**: walkable maps and scene staging (`act()` directions: walk, at, face, hide, sprite,
  focus, water). Sprite shader `SPRITE_SHADER` (uniforms `alpha`, `fill`, `flash`).
- **Data:** `data/stage_enemies.json` (battle enemies: hp, speed, attacks, `special` with tell/interrupt,
  `send_home`, `survive_turns`, `awakens`, `party`), `data/maps.json` (maps, props, `battle` placement),
  `data/episode1.json` + `data/episode1_flow.json` (**generated**, don't edit by hand).
- **Script source:** `tools/build_episode1.py`: all scenes (`S[...]`), the flow (`FLOW`), staging (`STAGES`,
  `direct()`, `big()`), recap lines. Edit here, then regenerate.
- **Legacy (unused by Episode 1):** `scripts/combat.gd`, `scripts/battle_model.gd`, `data/enemies.json`,
  `data/party.json`, `skills.json`, `amulets.json` (the old full-screen battle). Still covered by tests; `main.gd`
  falls back to it only for an enemy missing from `stage_enemies.json`. Removal was offered, not approved yet.

## 5. Commands and workflow

```bash
# Godot 4.3 (this container had it at /tmp/claude-0/godot43; a new container may not: CI installs 4.3
# stable in pages.yml, copy those steps)
G=/tmp/claude-0/godot43

python3 tools/build_episode1.py          # regenerate episode JSON after any script/flow/staging edit
python3 tools/estimate_playtime.py       # per-act minutes, longest stretch without input

cd godot
$G --headless --import                   # after adding art, or after a container restart
$G --headless --path . res://tests/Smoke.tscn 2>&1 | grep -E "FAIL|SCRIPT ERROR|failures:"
#   must end "== done, failures: 0 ==" (~15 min). Expected noise: "Parse JSON failed" (corrupt-save test),
#   thousands of 'Parameter "m" is null' / mesh_get_surface_count lines (headless renderer).
```

- **Screenshots / recordings** (what John sees): `xvfb-run -a -s "-screen 0 1280x720x24" $G --path . --rendering-driver
  opengl3 --resolution 1280x720 --write-movie OUT/f.png --fixed-fps 10 --quit-after N` with env vars
  `BALETE_SCENE=<scene id> BALETE_AUTO=1`, or `BALETE_FIGHT=<enemy> BALETE_DEMO=1 [BALETE_MISS=1]`. Run long
  captures in the background and poll for a done-file; contact-sheet frames with PIL.
- **Review links for John** (append to the Pages URL): `?scene=<id>&auto=1`, `?fight=<enemy>&demo=1`,
  `&miss=1` (forces a missed ring to show REWIND).
- **Before committing:** `rm -rf tools/__pycache__`; delete untracked `.import` files
  (`git ls-files --others --exclude-standard | grep '\.import$'`); then `git add -A`.

## 6. Gotchas (learned the hard way)

- **Dozens of "missing art" test failures** at once = stale import cache (usually after a container restart).
  Re-run `--import`; it's not your change.
- **Guided first parry** (the Pido tutorial) retries until hit, so `miss=1` skips it and misses a later ring.
- **Staging:** on the estero map keep staged characters at z ≤ ~8 or the text box covers them; give a `focus` in
  front of them. A `big()` panel needs an explicit panel id if the step has none.
- **Shell:** `rm` on a variable path must be written `"${S:?}"/...` (a safety check blocks bare `$S/*`); a plain
  foreground `sleep` is blocked: poll with `until [ -f file ]; do sleep 5; done`.
- **Smoke tests encode design numbers** (fight counts, survive turns, candle counts, panel count ≤ 13). When you
  change a design number, update the matching test in `tests/smoke.gd` in the same commit.
- **Art:** never put real brands in generated art (a "Singer" sewing machine was dropped for this).

## 7. Art pipeline

- OpenArt connector (it drops out at times; if its tools are missing, tell John and continue without art).
  Model `gpt-image-2-5-sunburst`, mode `image2image`, ~12 credits a sheet, ~1,750 credits left (Nov 19).
- Reference uploads (pass as `visualReferences` with these ids): `ref_battle` `kA6lE6YOVzZ072zb875g` (battle poses),
  `ref_cast2` `MvtSAjs1AvuKVbP3yXKi` (overworld cast), `ref_teoA` `QauO2UCYBF48S38XQ78u`, `ref_estero`
  `4vTSZUWYWmaQERajOZak` (props). Their CDN URLs are in `godot/assets/explore/CREDITS.md` history and the
  OpenArt upload list.
- Prompt pattern: "Retro 16-bit JRPG ... same pixel style as the reference ... strict grid of C columns by R rows
  ... solid flat pure magenta background (#FF00FF), no text, no grid lines"; battle poses face left, enemies right.
- Cut with `python3 tools/pixel_sprites.py cells SHEET COLS ROWS OUTDIR name1 name2 ... --height H` ("-" skips a
  cell); check for bleed from neighbouring cells; record each sheet in `godot/assets/explore/CREDITS.md`.

## 8. Open items and next steps

**Next in the plan** (`docs/RETRO_JRPG_PLAN.md`):
- Pose art for phase two (the aswang uses a tint and a bigger scale today) and for each enemy's wind-up (~24 credits).
- Episode 1 is still ~65 min by the estimate; the next cut needs John to name the scenes that drag.
6. Team combos: Teo + Kardo "Hatid sa Kuryente" (a prayer carried down the wire, hits all); Teo + Lola "Dasal ng
   Dalawa" (prayers in unison: heal and send home). Pay with utang na loob.
7. Enemy and boss specials: every enemy a telegraphed signature move; bosses two phases with a cut-in.

**Offered, waiting on John:**
- Remove the legacy battle system (section 4) to slim the codebase.

**Known, unresolved:**
- John's panel notes 03, 31 and 35 are redrawn (Nov 19). Panel 15 (the knife) is no longer shown: the aswang scenes are
  acted on the map.
- A blank decision card was reported once; never reproduced.
- Balance numbers are first guesses: candles (Teo 4, Pido 5), REWIND cap 3, heat step 10%, HATID II at Loob 2,
  summon power 32, the REWIND? box sits mid-screen over the action.
- **The watch's true rule** (why the flood went to Santa Ana) is deliberately undecided: John's call, don't invent it.
  (Decided Nov 19, and different: what the *dial* shows. See `docs/STORY.md` world rule 3.)
- Sol Agbayani (Episode 2, Baybayin-glyph mechanic, reads the heartwood names) isn't built; Teo's TAWAG is gated on
  the `heartwood_read` flag, waiting for him. Episode 2 content doesn't exist yet.
- Party roster for the season (STORY.md): Teo; Kardo (joins Ep 2); Sol (Ep 2); Celeste (guest, then turns); Mayari
  (Ep 7). Lola is an Episode 1 guest and summoner; she may return late (John liked "both").
