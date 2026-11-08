/**
 * Corrupted Aswang animation pipeline (fal.ai). See scripts/lib/sheet-pipeline.ts.
 *
 *   FAL_KEY=... npm run animate-aswang -- clips | preview | sheet
 *
 * `.cache/aswang/side.png` is the side-view base pose (facing right). Clips map onto the Mob state machine:
 * idle, walk (chase), telegraph (wind-up), attack, recover (recovery), stagger, die (dying) and leap
 * (the fire-escape drop and the retreat in the tutorial).
 */
import { runCli, type CharacterSpec, type ClipSpec } from "./lib/sheet-pipeline.ts";

const COMMON =
  "side view facing right, static locked camera, no camera movement, no zoom, the creature stays in the same place in the frame, " +
  "entire body always fully visible from hair to claws and feet, plain white background, same graphic novel cel-shaded art style, " +
  "same creature: gaunt slate-grey skin, pale skull face, long matted black hair, glowing red eyes, glowing ember-red cracks. It is completely alone in the frame";

const clips: ClipSpec[] = [
  { name: "idle", loop: true, pingpong: true, fps: 6, from: 0.0, to: 2.0, frames: 8,
    prompt: "breathes slowly in a hunched stalking stance, ribcage heaving, long arms hanging and twitching, matted hair swaying, head tilting, jaw trembling" },
  // Third take: the one whose first and last frames match, so the loop is seamless.
  { name: "walk", source: "walk_c", loop: true, fps: 6, from: 1.79, to: 4.21, frames: 12,
    prompt: "(reuses the walk_c footage)" },
  { name: "telegraph", loop: false, fps: 8, from: 0.8, to: 2.4, frames: 9,
    prompt: "rears up to full height, throws its arms wide with claws spread and screams with its jaws gaping, hair whipping, winding up for a huge strike, then holds the pose" },
  { name: "attack", loop: false, fps: 30, from: 1.2, to: 2.4, frames: 8, wide: true,
    prompt: "lunges forward explosively and rakes both long arms in a vicious wide claw swipe in front of it, then follows through" },
  { name: "recover", loop: false, fps: 8, from: 0.2, to: 2.0, frames: 8,
    prompt: "is overextended after a failed attack: stumbles, hunched over panting with its long claws dragging on the ground, then slowly regains its footing" },
  // The crouched, head-hanging second half of the recover footage doubles as the stunned (guard broken) loop.
  { name: "stagger", source: "recover", loop: true, pingpong: true, fps: 5, from: 2.2, to: 4.0, frames: 8,
    prompt: "(reuses the recover footage)" },
  { name: "die", loop: false, fps: 9, from: 0.8, to: 2.2, frames: 8, wide: true,
    prompt: "is mortally wounded: shrieks, convulses, then collapses onto the ground and lies still, hair splayed" },
  { name: "leap", loop: false, fps: 14, from: 2.4, to: 4.6, frames: 8, wide: true, trackX: true,
    prompt: "crouches low then pounces, leaping high into the air with its long arms and claws stretched forward" },
];

const spec: CharacterSpec = {
  key: "aswang",
  bases: ["side"],
  common: COMMON,
  negative:
    "other creatures, other people, camera movement, zoom, crop, turning around, background change, extra heads, extra limbs, blur, text, motion blur trails, smoke, fire",
  clips,
  cols: 7,
  // Footage is on pure white: key it locally (free) so the sheet never depends on API credit.
  cutout: "local",
  cellW: 288,
  halfK: 0.75,
};

await runCli(spec);
