# Art pipeline: story → code → Merlin → plug and play

**Split of work**
- **Claude (code):** writes the story into playable scenes and registers every image the scene needs in
  `src/assets/artManifest.ts`. Each slot has an id, a file path, a size, and a generation brief.
- **Merlin (art):** generates the images, saves them at the listed path, commits. That's it.
- **The game:** asks for art by id. File exists → it's used. File missing → a labelled placeholder is drawn
  that names the exact file to drop in. No code change is ever needed to swap placeholder → final art.

## For Merlin

0. **Fastest path:** `docs/MERLIN_PROMPTS.md` has a ready-to-paste Gemini prompt for every missing slot (with which portraits to attach as references).
1. Open `docs/ASSET_MANIFEST.md` (the shot list, generated from the manifest) or run the game with
   `?assets` (e.g. `http://localhost:5173/?assets`) for a visual checklist: green = delivered, amber = placeholder.
2. For each row: generate to the stated size using the brief + the style rules below.
3. Save to **exactly** `public/assets/<dir>/<name>.<ext>` (`webp` preferred; `png`/`jpg` also found).
   Same file name as the row. Don't rename, don't add folders.
4. Commit and push (any branch; the placeholder swaps automatically on reload).
5. `npm run assets:check` lists what's still missing (`npm run assets:report` refreshes the shot list).

### Sizes
| Kind | Size | Notes |
|---|---|---|
| Portrait | 512×512, png w/ transparent bg or webp | Shown at 72px in the dialogue box: bold silhouette, strong ink lines, face centered. |
| Panel | 1600×900 (16:9), webp | Slanted mask crops the edges; keep subject centered with ~12% margin. Bottom ~28% sits under the dialogue box, so no key detail there. |
| Background | 1920×1080 | Full-bleed, empty lower third. |

### Style (from `docs/EPISODIC_DIRECTION.md`)
- Comic book: ink outlines, flat cel color, halftone shading. Dispatch-inspired.
- Palette: ink black, warm grey, brown, **warm gold** lit windows. Teal `#00ffcc` is an **accent only**
  (neon signs, Baybayin glyphs, watch glow). Never a teal wash.
- Quiapo specifics: rain, wet pavement, jeepney lights, candle stalls, the church twin towers.
- Keep Renzo, Lola Rosa, Dante consistent across panels: generate the portraits first and use them as references.
- No text/lettering baked into panels. Speech and SFX are drawn by the game.

### Already delivered (keep names)
`comics/renzo_cornered`, `comics/dante_panel1_wheel`, `comics/dante_panel2_approach`, `comics/dante_panel3_krash`.

## For whoever adds a scene (Claude)

1. Write the scene in `src/narrative/` as `CutsceneStep[]`; reference art with `panel: "<id>"` and
   `portrait: "portrait_<name>"`.
2. Add each new id to `src/assets/artManifest.ts` with a `brief` and `scene`.
3. `npm run assets:report` to refresh `docs/ASSET_MANIFEST.md`, commit it so Merlin has the new shot list.
4. Ids are a contract: renaming one orphans delivered art. Add, don't rename.

## Episode 1 coverage
Episode 1 now follows `docs/STORY.md`: Morning (shop, runner, corkboard) → The Envelope (Mang Domeng, church
undercroft, watch runs backward) → Lola Rosa's Silence (timed choice) → Dusk (alley, Aswang, gate ram) →
Aftermath (Tondo safehouse, Lola's detention, watch cliffhanger). Not yet written: Scene 1.2 Pawnshop and
1.3 Debt Collector (the collector's visit is folded into the morning notice), Chapter 2 onward.
