# Balete as a retro JRPG (decided Nov 13, 2026)

John's direction: a retro JRPG (FF6 / Chrono Trigger / Octopath) instead of a Telltale-style comic. The art can stay
storybook-like; the comic panels are kept for the big moments only. Decisions from the Q&A:

| Question | Decision |
| --- | --- |
| Text boxes | Bottom window with the speaker's name and a 16-bit pixel portrait (FF6 style) |
| Comic panels | Big moments only: about 8 to 12 per episode, as full-screen cutscene stills |
| Special moves | All four: cinematic cut-ins, summon-style big moves, moves that power up, team combos |
| Encounters | Visible on the map: walk into an enemy to fight, or walk around it |
| Choices | Kept: choices, Loob, "they will remember that" (the story is still yours) |

## Done (this round)

- **One window style** (`scripts/retro.gd`): the blue SNES window for dialogue, choices, map tags and battle HUD.
- **Text boxes with pixel portraits**: 16 busts in `assets/portraits_px` (Teo, Lola Ising, Kardo, Lolo Pido,
  Kapitan Obet, Mang Domeng, Aling Nena, Mang Berto, Mang Isko, Rudy, Nonoy, Mang Andoy, Aling Tess, Tanod Celso,
  the Hiraya guard, Atty. Benitez). Narration is a window at the top; thoughts are italic, "(thinking)".
- **Talks happen on the map**: talking to someone in a walkable hub plays over that map, Teo beside them, with the
  text boxes. The backdrop comic panels of hub talks are gone (a step can keep one with `big=True`).
- **Visible enemies**: Mang Andoy drifts under the balete on Hidalgo Street. He comes for Teo when Teo gets close
  ("!"), and touching him flashes the screen and starts the fight. No name tag: you see him coming.
- **Cut-ins**: every special move freezes the fight, a band sweeps across, the portrait slides in, the move is named
  (Teo's Hatid prayers and Balisong Ikot, Mang Andoy's Tawag).
- **First power-up**: a prayer entered with half its time left is SWIFT (PAALAM+): ×1.35 power.
- Review links: `&auto=1` advances lines by themselves; `?scene=hid_balut` now plays a hub talk on its map.

## Done (round 2): one battle system

Every Episode 1 fight is now the side-view pixel battle on the map where it happens (`stage_battle.gd`,
`data/stage_enemies.json`): the 1998 flood waves (Lolo Pido alone, wounds carried, the tide outlasted for four
turns) in the flooded parlor, Mang Berto in the wake, the unsent and the aswang at the creek (the aswang wakes the
watch: full heal, +2 utang, and Teo's new WATCH: REWIND), and the hound in Kardo's morgue with Teo and Kardo
(WIRE / DISCHARGE). Every enemy has a telegraphed signature move with a cut-in, and what interrupts it: a prayer
for spirits, a discharge for the hound, a heavy blow for the aswang. Parry and dodge lessons on the first rings.
The morgue map is a placeholder until step 2. The old full-screen battle (`combat.gd`) is no longer used by the
episode; it stays for its tests until it is removed.

## Done (round 3): scenes acted on their maps

- Three new maps (`data/maps.json`): **Lola's room** upstairs (`lola_room`: aparador, bed, altar, her armchair at the
  top of the stairs, a stairwell that drops away), the **pump house** at the estero (`pumphouse`), and **Kardo's
  morgue** rebuilt from real props (steel table, jeepney-seat couch, formaldehyde shelf, sink under the street window,
  cooler).
- 22 story scenes are now acted with sprites on their map, under the text boxes: Lola's room (the watch, her one
  answer, 2:03, 2:40, the photo), the estero (arrival, the creek rising, the aswang dropping, after it, Kardo's truck),
  the pump house (the dead sundô), Hidalgo Street at 2:41 (the van), the wake at dawn, and every morgue scene.
- Staging lives in `tools/build_episode1.py` (STAGING): `STAGES` sets who stands where; `direct(scene, "first words",
  ...)` walks, places, turns or re-poses people on that line; `big(scene, "first words")` keeps a comic panel there.
  Every other panel in an acted scene goes: 11 panels remain in those 22 scenes.
- New stage directions: `{"who", "sprite": pose}` (change pose) and a cast member's `"y"` (sits on a step or a table),
  `"bob": false` (vehicles glide) and `"hidden"` for Teo.
- New art: one sheet of room props, one of morgue and pump-house props, one of poses (Kardo standing and asleep, Lola
  asleep in her chair and on the stairs, Teo kneeling and on the stairs, the dead Salonga, the white van). 36 credits.

## Next, in order

1. ~~**One battle system.**~~ Done (above). The cold-open flood fights, Berto's fight, the aswang and the hound still use the older
   full-screen battle (`combat.gd`) with painted fighters. They move to the side-view pixel battle
   (`stage_battle.gd`) on the map where they happen, with a party of up to three (Lolo Pido in 1998; Teo and Kardo
   later). Needs pixel battle poses for Pido, Kardo, the drowned, the aswang and the hound (about 5 sheets, 60 credits).
2. ~~**Maps for the scenes that still use panels as backdrops**~~ Done (above).: the parlor upstairs (Lola's room), the street to the
   estero, Kardo's morgue. Then each scene there is acted with sprites, and its panels are trimmed to the big moments.
3. **Which panels stay** (proposal, about 12): the 1998 flood and the rewind, Berto's ghost, the watch going
   backward, the hatid boat, the dead sundo, the white streak, Lola taken, Kardo's truck at the gate, the morgue
   reveal, the photo of Liwayway, Celeste on TV.
4. **Specials for everyone** (FF6-style, each with its own input):
   - Teo, HATID: arrow prayers (done). Power-ups: SWIFT now; later, Loob unlocks longer prayers (HATID II).
   - Kardo, KONTRA (circuit): hold and release to charge the wire; overcharge for more damage but he takes a shock.
   - Lola Ising, ORASYON: a rhythm of taps (she is a story guest, then a summon).
   - Lolo Pido (1998 only), the watch: REWIND one enemy turn.
5. **Summon-style big moves**: the ancestors. Lola calls on the sundô before her (a full-screen painted sequence,
   reusing the boat panel style). One per fight, refilled by sending souls home.
6. **Team combos** (dual techs): Teo + Kardo "Hatid sa Kuryente" (a prayer carried down the wire, hits all);
   Teo + Lola "Dasal ng Dalawa" (their prayers in unison, heals and sends home).
7. **Enemy and boss specials**: every enemy gets a telegraphed signature move (as Tawag); bosses get two phases and a
   cut-in.
