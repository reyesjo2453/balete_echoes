# Roadmap (Nov 11, 2026, after the reboot)

Canon: `docs/STORY.md`. Shape: `docs/EPISODIC_DIRECTION.md`. Episode 1 script: `tools/build_episode1.py`.

## Done in the reboot
- New premise and cast: the Dimaculangan funeral parlor, the sundô, Lolo Pido's watch as borrowed time; Teo,
  Lola Ising, Kardo, Kapitan Obet, Hiraya Energy (Villacorta, Benitez), Celeste / Liwayway.
- Episode 1 rewritten from scratch: 1998 cold open plus three acts, 36 scenes, 2 hubs, 5 fights, 3 story QTEs,
  3 big choices, cliffhanger and "Abangan" card. Estimated ~54 min (CI prints it).
- Removed: courier runs, the job board, the noon settle, money and time meters, chore QTEs.
- Added: hubs, untimed choices (timed only in danger), data-driven QTE outcomes, "will remember that", bonds,
  Teo greying with borrowed time, dodge-only attacks, attacks charge the watch, Kardo's wire/discharge circuit,
  story beats that name the party (Lolo Pido, Kardo as guests).
- Smoke test and two full automatic playthroughs updated; CI green.

## Next (biggest lift first)
1. **Art for the new panels** (17 slots in `docs/ASSET_MANIFEST.md`) and portrait redraws for Teo, Lola Ising, Kardo.
   Until then the game shows labelled art slots.
2. **Playtest Episode 1** for feel: the dodge lesson, Kardo's circuit in the hound fight, the hub pacing, and whether
   the grey portrait reads.
3. **Grow Episode 1 toward 65–70 min** if the playtest wants it: an optional side case at the wake, a longer Act 3 rest.
4. **Battle art** for Teo, Kardo, Lolo Pido and the ghosts (code silhouettes now).
5. **Voices** for Teo, Lola Ising, Kardo (generated once, stored in the repo).
6. **Episode 2, "Ang Tagapag-ingat"**: Sol, the museum, the Salongas, Kardo joins, first anting-anting choice (the
   data and save fields exist; needs UI).

## Known open items
- `web-legacy/` still holds the old story (Renzo, Dante); reference only, not shipped.
- `docs/MERLIN_PROMPTS.md` prompts describe the old panels; write prompts for the new slots when art starts.
- End-of-episode stats show the combat combo as 0 until combo tracking lands.
