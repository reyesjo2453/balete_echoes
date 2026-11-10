/**
 * Renzo animation pipeline (fal.ai). See scripts/lib/sheet-pipeline.ts.
 *
 *   FAL_KEY=... npm run animate-renzo -- clips | preview | sheet
 *
 * `.cache/renzo/side.png` is the armed side-view base (facing right); `unarmed.png` holds the pocket watch.
 */
import { runCli, type CharacterSpec, type ClipSpec } from "./lib/sheet-pipeline.ts";

const COMMON =
  "side view facing right, static locked camera, no camera movement, no zoom, character stays in the same place in the frame, " +
  "full body always fully visible from hair to boots, plain white background, same anime cel-shaded art style, same character";


const clips: ClipSpec[] = [
  { name: "idle", loop: true, pingpong: true, fps: 5, from: 0.0, to: 1.6, frames: 8,
    prompt: "stands in place breathing slowly, chest rising and falling, shifting his weight nervously, the knife in his hand trembling slightly" },
  { name: "walk", loop: true, fps: 8.2, from: 0.83, to: 2.29, frames: 12,
    prompt: "walks in place on a treadmill in a smooth looping walk cycle, arms swinging, knees lifting, heels striking, always centered in the same spot" },
  { name: "idle_u", base: "unarmed", loop: true, pingpong: true, fps: 3, from: 0.0, to: 1.6, frames: 5,
    prompt: "stands in place breathing slowly, glancing down at the pocket watch in his hand then looking ahead, relaxed and unaware of danger" },
  { name: "walk_u", base: "unarmed", loop: true, fps: 4.6, from: 2.08, to: 3.83, frames: 8,
    prompt: "walks in place on a treadmill in a smooth looping walk cycle, the pocket watch held loosely in his hand, arms swinging, always centered in the same spot" },
  { name: "slash", loop: false, fps: 28, from: 1.3, to: 3.0, frames: 8,
    prompt: "performs one fast desperate knife slash: winds the knife arm back, swings it forward in a quick wide arc with a lunging step, then returns to a ready stance" },
  { name: "hurt", loop: false, fps: 12, from: 1.0, to: 2.4, frames: 6, wide: true,
    prompt: "flinches violently as if struck by an unseen force: head snaps back, body recoils, stumbles back one step, grimacing in pain, then steadies himself. He is completely alone in the frame, nobody else" },
  { name: "dodge", loop: false, fps: 14, from: 0.2, to: 1.4, frames: 7,
    prompt: "quickly leaps backward away from danger in a fast evasive hop, ducking low, landing in a crouch with the knife ready" },
  { name: "down", loop: false, fps: 10, from: 0.2, to: 1.6, frames: 8, wide: true,
    prompt: "is knocked off his feet: falls backward to the ground and lies flat on his back, the knife dropped beside him, then lies still. He is completely alone in the frame, nobody else" },
];


const spec: CharacterSpec = {
  key: "renzo",
  bases: ["side", "unarmed"],
  common: COMMON,
  negative: "other people, second person, hands from off-screen, camera movement, zoom, crop, turning around, background change, extra limbs, blur, text, motion blur trails",
  clips,
  cols: 7,
  cellW: 320,
  halfK: 0.62,
};

await runCli(spec);
