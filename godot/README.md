# Balete (Godot 4)

Episode 1, "Ang Lumang Orasan". Ported from the web build in `../web-legacy` (kept for reference only; the story there is the old draft).

**Engine:** Godot 4.3, GDScript, GL Compatibility renderer, 1280x720 (scales; Steam Deck 1280x800 letterboxes slightly).

**Flow:** cold open (Quiapo, 1998: Lolo Pido's fight against the drowned, the parry tutorial, the 4:17 rewind) → Act 1 "Lamay" (the wake as a hub, Mang Berto's ghost, the watch, the first send-off) → Act 2 "Ang Sundô" (the estero hub, the creek's unsent, the dead sundô, the tagged aswang and the watch's awakening, Kardo's truck, Lola taken) → Act 3 "Utang" (Kardo's morgue, Lola's tape, Hiraya's offer, the hound with Kardo, dawn, the photograph, the cliffhanger) → end card ("Abangan...").
Canon: `docs/STORY.md`. Shape and systems: `docs/EPISODIC_DIRECTION.md`.

**Controls:** keyboard (arrows or WASD, Space/Enter), gamepad (d-pad or left stick, A to accept), mouse or touch. Everything uses Godot's built-in `ui_*` actions, so Steam Input on the Deck works without extra bindings.

**Run it:** open `godot/project.godot` in Godot 4.3, press F5. Headless smoke test:
`godot --headless --path godot res://tests/Smoke.tscn`

**Structure**
- `scripts/story.gd` (autoload `Story`): run state (utang = borrowed time and Teo's aging, Loob, bonds, flags, remembered), scene data, choice and QTE effects
- `scripts/main.gd`: the flow driver: cards, scenes, hubs, fights, end card
- `scripts/dialogue.gd`: comic panel + three bars (spoken, thought, narration), choices (untimed unless `seconds` > 0), QTEs; greys Teo's portrait as he borrows time
- `scripts/timing_ring.gd`: the one ring for story QTEs, parries and dodges
- `scripts/battle_model.gd` + `scripts/combat.gd`: turn-based combat with a timed parry, dodge-only attacks, watch powers, Kardo's wire/discharge circuit
- `data/episode1.json` + `data/episode1_flow.json`: every scene and the beat order, **generated** by `tools/build_episode1.py` (edit the script, not the JSON)
- `data/enemies.json`, `data/party.json`, `data/skills.json`, `data/amulets.json`, `data/structure.json`
- `assets/`: panels, portraits, fonts, sfx, music. Missing panels show a labelled art slot (see `docs/ASSET_MANIFEST.md`)

**Deploy:** `.github/workflows/pages.yml` imports the project, runs the smoke test, exports a single-threaded
Web build (no SharedArrayBuffer, works on plain GitHub Pages) and a Linux x86_64 build, and publishes the Web
build to GitHub Pages.

**Season progression (data-driven, nothing past Episode 1 is built)**
- `data/skills.json`: watch powers, one per episode (Rewind, Slow, Echo, the 4:17 finale), each with base, protective and aggressive forms. The Loob score at unlock picks the form (`loob_threshold`). `variants_enabled: false` keeps Episode 1's Rewind exactly as built.
- Watch energy: attacks and perfect parries fill it (`BattleModel.energy`, max 6); Skills and team moves spend it. The meter only appears once an energy skill is unlocked.
- `data/amulets.json`: anting-anting, one equipped at a time, each with a perk and a small cost. The first is chosen from two in Episode 2.
- `data/party.json`: members, their command menus, and team moves. Kardo joins in Episode 2 (Wire, Discharge, Bayanihan); he fights as a guest in Episode 1's hound fight. Lolo Pido is a guest for the cold open only. A flow beat can name the party (`"party": [...]`).
- `scripts/progress.gd` (autoload `Progress`): save data in `user://balete_save.json` (versioned, migrates old saves, ignores corrupt ones). Tracks unlocked skills and their form, amulets and the equipped one, episodes done and the Loob path. `new_season()` carries over the Loob path and the amulets.
