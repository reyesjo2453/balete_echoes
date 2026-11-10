# Balete (Godot 4)

Episode 1 vertical slice, ported from the web build in `../web-legacy` (kept for reference).

**Engine:** Godot 4.3, GDScript, GL Compatibility renderer, 1280x720 (scales; Steam Deck 1280x800 letterboxes slightly).

**Flow:** "Previously on Balete" → Act 1 "4:17" (6 AM stakes, the shop with its first timing-ring lesson, the Honda kick-start, the rain courier run, Dante's call, Renzo takes the shortcut) → Act 2 "The Alley" (the Aswang, a turn-based fight with enemy intents and a timed parry, Dante sees the rewind) → end card with "Next time on Balete".

**Controls:** keyboard (arrows or WASD, Space/Enter), gamepad (d-pad or left stick, A to accept), mouse or touch. Everything uses Godot's built-in `ui_*` actions, so Steam Input on the Deck works without extra bindings.

**Run it:** open `godot/project.godot` in Godot 4.3, press F5. Headless smoke test:
`godot --headless --path godot res://tests/Smoke.tscn`

**Structure**
- `scripts/story.gd` (autoload `Story`): run state (utang, Loob, money), scene data, choice and QTE effects
- `scripts/dialogue.gd`: comic panel + three bars (spoken, thought, narration), timed choices, QTEs
- `scripts/timing_ring.gd`: the ring used for story QTEs and for the parry
- `scripts/courier_run.gd`: the rain courier run
- `scripts/combat.gd`: turn-based combat
- `data/episode1.json`: the whole Episode 1 script, generated from the web script by `tools/export_story.ts`
- `data/slice_opening.json`: hand-authored slice scenes (stakes, Dante's call, alley, after the fight)
- `assets/`: panels, portraits, fonts, sfx, music (placeholders until the final art lands)

**Adding the rest of Episode 1:** every scene in `data/episode1.json` already plays through `Dialogue`
(`Story.scene("envelope")`, `"lola_silence"`, `"tondo_safehouse"`, `"cliffhanger"`...). Chain them in
`scripts/main.gd`.

**Deploy:** `.github/workflows/pages.yml` imports the project, runs the smoke test, exports a single-threaded
Web build (no SharedArrayBuffer, works on plain GitHub Pages) and a Linux x86_64 build, and publishes the Web
build to GitHub Pages.

**Season progression (data-driven, nothing past Episode 1 is built)**
- `data/skills.json`: watch powers, one per episode (Rewind, Slow, Echo, the 4:17 finale), each with base, protective and aggressive forms. The Loob score at unlock picks the form (`loob_threshold`). `variants_enabled: false` keeps Episode 1's Rewind exactly as built.
- Watch energy: perfect parries fill it (`BattleModel.energy`, max 6); Skills and team moves spend it. The meter only appears once an energy skill is unlocked.
- `data/amulets.json`: anting-anting, one equipped at a time, each with a perk and a small cost. The first is chosen from two in Episode 2.
- `data/party.json`: members, their command menus, and team moves (Dante joins in Episode 3, with Taser and Bayanihan).
- `scripts/progress.gd` (autoload `Progress`): save data in `user://balete_save.json` (versioned, migrates old saves, ignores corrupt ones). Tracks unlocked skills and their form, amulets and the equipped one, episodes done and the Loob path. `new_season()` carries over the Loob path and the amulets.
