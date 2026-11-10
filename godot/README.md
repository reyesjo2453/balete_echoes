# Balete (Godot 4)

Episode 1 vertical slice, ported from the web build in `../web-legacy` (kept for reference).

**Engine:** Godot 4.3, GDScript, GL Compatibility renderer, 1280x720 (scales; Steam Deck 1280x800 letterboxes slightly).

**Flow:** title → 6 AM stakes → shop (teaches the timing ring) → Honda kick-start → rain courier run → Dante's call → the alley → turn-based fight with a timed parry → end card.

**Controls:** keyboard (arrows or WASD, Space/Enter), gamepad (d-pad or left stick, A to accept), mouse or touch. Everything uses Godot's built-in `ui_*` actions, so Steam Input on the Deck works without extra bindings.

**Run it:** open `godot/project.godot` in Godot 4.3, press F5. Headless smoke test:
`godot --headless --path godot --script res://tests/smoke.gd`

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
