# Episode 1 polish roadmap (from the Nov 10 playtest)

Goal: polished, sellable quality. Status as of commit `f0f5787`.

## Done in wave 1
- Watch story: findable reason for the 4:17 clocks (Lola's note inside the pendulum clock), Lola's hands burn on the watch (the drop), the catch is the first rewind (nine clocks tick once), the watch ticks only for Renzo, the "easy money" line is gone.
- Sacristan beat is now a timed choice (slip him ₱200 or hold his stare); a miss only matters if he heard.
- Feedback: consequence banners show above the comic pages and cannot stick; "Lola will remember that".
- Bugs: HUD readout updates on every change and hides at episode end; "End of Act I" no longer fires mid-story; no black void beside slanted panels; HUD text no longer stacks; a visible error screen replaces silent black screens.
- "Ledger" is now "Utang" in player-facing text.

## Still to do (biggest lift first)
1. **Stakes up front.** Open at 6 AM with a named lender, the tow truck and the noon deadline, then a short playable courier run in the rain.
2. **Playable jobs.** Each corkboard job becomes a short scene with later fallout. The church parcel is the one required job (it is currently forced even if not picked).
3. **Turn-based combat with a timed parry or dodge** on the aswang's turn (own look, not a copy). Replaces the real-time slash, kick and gate prompts. Teach the parry first. Foreshadow the aswang and give the alley its own art.
4. **Introduce Dante early;** seed the flood, Lola's seal, the Veil and Aevum before they are named.
5. **Visible timer bars** on timed choices (the QTE already has the ring).
6. **Rewinds after the first** show an effect and a cost.
7. **Phone-first panels:** a focus point per panel or vertical scroll, dialogue kept off faces.
8. **Polish:** the 4 placeholder panels (held for now), consistent Renzo across panels, rain, bells and engine audio.

## Known open items
- The stopped-clocks panel does not show 4:17 on every clock yet (image models do not draw exact times; needs a retouch or a hand-drawn overlay).
- End-of-episode stats still show a combat combo of 0 until the combat rewrite lands.
- Ride art vs caption (`ep1_06b` is a placeholder until its panel exists).
- "Black screen with no error" could not be reproduced here; it now shows an error screen with the message if it happens again. Send the message if you see it.
