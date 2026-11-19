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

## Done (round 4): a dozen panels, and some Pinoy humor

- The cold open is acted in the flooded parlor: Lolo Pido (his battle poses) against the drowned, young Kardo and
  Ising off-screen on the stairs. The water rises wave by wave and the rewind drains it on the map (`{"water": y}`).
  The opening of the wake, Mang Berto's ghost, his turning and the hatid are acted in the parlor.
- **13 comic panels** in the whole episode (from about 40): the flood, the rewind, Santa Ana, Berto's ghost, the hatid
  boat, the watch's verdict (2:40, then Laho), the dead sundô, the white streak, the gate crash, Lola taken, the photo
  of Liwayway, Celeste on TV, and the inside of Kardo's truck (the one scene with no map).
- Humor, Bleach-style: light beats in the lulls, never on the tragic ones. Young Kardo's "clean briefs" in the flood;
  the Titas asking about a girlfriend; Kap Obet's two ensaymada; Mang Berto on Quiapo traffic ("nothing arrives on
  schedule, not even the dead"); Lola has always known about the balisong behind the patis (a running gag); the
  contractual guard ("endo na po ako next week"); Kardo's un-retired truck, the glued-down Santo Niño and the radio
  drama; 3-in-1 made 5-in-1; "same customers, eventually"; the Eraserheads tape; "Ay, bumaha ba?"; Kardo snoring in
  sync with the radio static.

## Done (round 5): a special for everyone, each with its own input

- **Kardo, KONTRA** (was DISCHARGE): hold Space / A / touch and let go. Green is a clean circuit; red OVERCHARGES
  (x1.5) and the current comes back up the wire into Kardo ("I'm fine. I can taste colours."); held at the top too
  long the breaker trips (weak hit, full shock). The shock never drops him. Still shorts the hound's charge.
- **Lola Ising, ORASYON**: beads slide into a ring, tap on each beat (6 beats, PERFECT / GOOD / MISS). Heals everyone,
  breaks a spell, hurts a spirit; every beat kept stops a charging spell. She now fights beside Teo against Mang Berto
  (she comes down the stairs in her slippers), with ABANIKO, HILOT and ROSARY.
- **The watch, REWIND**: tap fast to wind the crown back (10 turns in 2.6 s). Wound part way gives back that share of
  the last enemy turn's damage; wound all the way also cancels a charge. Lolo Pido has it once a fight in 1998 (no
  utang); Teo's still costs utang.
- **HATID II, TAWID** ("Cross over"): seven arrows, power 46, sends a spirit home from 15% above the gold line. Pido
  knows it; Teo's shows locked until Loob 2.
- Art: one 4x3 sheet (12 credits): Lola's 8 battle poses, Kardo bracing and overcharged, Pido winding the watch, Teo's
  HATID II aura. Input lives in `scripts/special_gauge.gd`; smoke tests cover each gauge by hand and in a fight.

## Done (round 6): REWIND as a reaction, costs, summons, levels

- **REWIND is a reaction, not a menu command.** When a missed parry (or a missed dodge of a special) lands, the moment
  freezes and REWIND? opens: HOLD Space / A / touch before the light runs out and the blow plays backward (the enemy
  slides back, the HP climbs back, the fallen stand) and the same ring comes again. The watch holds one REWIND to start
  and a perfect parry winds one more (up to 3). Teo's costs +1 utang; Lolo Pido's in 1998 is free. A fall that the
  watch could still undo waits for the answer before the fight is lost.
- **Candles** (Teo 4, Pido 5, lit fresh each fight): every prayer burns one, TAWID two, a fizzled prayer too.
- **Utang na loob** (`Story.gratitude`, what the dead owe Teo): +1 for each soul sent home (Mang Andoy, Mang Berto's
  hatid, Mang Ambo). Teo's TAWAG spends it. Shown on the battle HUD and the end card.
- **Kardo's line heat**: each KONTRA moves the green and red 10% lower for the next one; it cools a step a turn.
- **Lola's pagod**: after ORASYON she sits a turn out ("Wait lang, apo. My knees.").
- **Summons (TAWAG)**, once a fight: the hatid-boat painting fills the screen with the ancestor's whole name, then his
  ghost crosses the stage and strikes (heavier on spirits), stops a charge, and heals the party. A sundô never scatters
  a soul that can still be sent home. Episode 1: Lola calls Pido Dimaculangan, free. Episode 2+: Teo speaks a name Sol
  reads off the heartwood (`heartwood_read` flag) for one utang na loob. More names: `ANCESTORS` in stage_battle.gd.
- **CASE CLOSED level-up** (`scripts/case_closed.gd`, `scripts/levels.gd`): at the end of each case Teo and Kardo
  (and Sol from Episode 2) go up a level (HP and damage) and each picks one of two upgrades (TIBAY / LINAW,
  MAKAPAL / DAGDAG KAWAD, then KANDILA / TALIM, GROUNDED / BILIS). An episode uses only what was earned before it,
  so replaying Episode 1 plays the same.
- Review: `?fight=lunod&demo=1&miss=1` shows REWIND; `?fight=ligaw_berto&demo=1` shows Lola.

## Done (round 7): tightened

Measured first (play-time estimate and an autoplay of every fight), then cut and tuned:
- **Story.** The cold open was three back-to-back fights (about 15 minutes before the title). Now two: the drowned,
  then the tide (hold the stairs three turns, down from four); the two in-between scenes are one (`co_wave`).
  Episode 1: 68 to 64 minutes; the longest stretch with no input 15.3 to 10.6 minutes. The new systems now have
  story setup: Mang Domeng gives Teo a bundle of candles ("A prayer without a candle is just talking"), and Lola says
  who she will call before the Berto fight ("He never once said no to me in forty years").
- **Fights.** The aswang went from 17 enemy turns to 9 (HP 210 to 170, the watch wakes at 60%, and once it wakes Teo's
  time bar runs 1.5x faster for the rest of the fight: borrowed time). Mang Berto with Lola went from 2 enemy turns
  to 3 (HP 125 to 165, a step faster). Lola's summon hits a little softer (32, not 42). The rest sit at 3 to 6.
- **Loop.** Every victory shows a tally under the banner: perfect parries, rewinds, candles left, overcharges.
- **Animation.** Everyone standing breathes (a slow squash and stretch); attacks crouch back, dash stretched with
  afterimages, and squash on landing; every hit blinks the sprite white (a `flash` uniform in the sprite shader) and
  knocks party members back; enemies draw back while the parry ring closes, so the timing reads on the body too; the
  party hops on a win.

## Next, in order

1. ~~**One battle system.**~~ Done (above). The cold-open flood fights, Berto's fight, the aswang and the hound still use the older
   full-screen battle (`combat.gd`) with painted fighters. They move to the side-view pixel battle
   (`stage_battle.gd`) on the map where they happen, with a party of up to three (Lolo Pido in 1998; Teo and Kardo
   later). Needs pixel battle poses for Pido, Kardo, the drowned, the aswang and the hound (about 5 sheets, 60 credits).
2. ~~**Maps for the scenes that still use panels as backdrops**~~ Done (above).: the parlor upstairs (Lola's room), the street to the
   estero, Kardo's morgue. Then each scene there is acted with sprites, and its panels are trimmed to the big moments.
3. ~~**Which panels stay**~~ Done (above). (proposal, about 12): the 1998 flood and the rewind, Berto's ghost, the watch going
   backward, the hatid boat, the dead sundo, the white streak, Lola taken, Kardo's truck at the gate, the morgue
   reveal, the photo of Liwayway, Celeste on TV.
4. ~~**Specials for everyone**~~ Done (round 5, above). (FF6-style, each with its own input):
   - Teo, HATID: arrow prayers (done). Power-ups: SWIFT now; later, Loob unlocks longer prayers (HATID II).
   - Kardo, KONTRA (circuit): hold and release to charge the wire; overcharge for more damage but he takes a shock.
   - Lola Ising, ORASYON: a rhythm of taps (she is a story guest, then a summon).
   - Lolo Pido (1998 only), the watch: REWIND one enemy turn.
5. ~~**Summon-style big moves**~~ Done (round 6).: the ancestors. Lola calls on the sundô before her (a full-screen painted sequence,
   reusing the boat panel style). One per fight, refilled by sending souls home.
6. **Team combos** (dual techs): Teo + Kardo "Hatid sa Kuryente" (a prayer carried down the wire, hits all);
   Teo + Lola "Dasal ng Dalawa" (their prayers in unison, heals and sends home).
7. **Enemy and boss specials**: every enemy gets a telegraphed signature move (as Tawag); bosses get two phases and a
   cut-in.
