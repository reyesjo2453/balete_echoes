/**
 * Exports the Episode 1 story script from the web build into JSON for the Godot game.
 *   node --experimental-strip-types tools/export_story.ts
 * Writes godot/data/episode1.json. Functions (effects) are replaced by stable ids that
 * godot/scripts/story_effects.gd implements.
 */
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import * as S from "../web-legacy/src/narrative/Episode1Script.ts";

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, "../godot/data/episode1.json");

const ctx = { state: { charge() {}, flags: {}, money: 0, loob: 0 }, hud: { showToast() {} } } as never;

const CHOICE_IDS: Record<string, string> = { "Slip him": "sacristan", "Press her": "lola_silence" };
const QTE_IDS: Record<string, string> = { "CATCH!": "tin_slip", "KICK!": "honda_kick", "STEADY!": "candles_steady", "BRACE!": "gate_brace" };

function clean(step: Record<string, unknown>): Record<string, unknown> {
  const o: Record<string, unknown> = {};
  for (const k of ["kind", "speaker", "portrait", "text", "layout", "panel", "sfx", "shake", "flash", "autoAdvance"]) {
    if (step[k] !== undefined && step[k] !== "") o[k] = step[k];
  }
  const c = step.choice as { options: string[]; seconds: number; defaultIndex: number } | undefined;
  if (c) {
    const id = Object.entries(CHOICE_IDS).find(([k]) => c.options[0].startsWith(k))?.[1] ?? "choice";
    o.choice = { id, options: c.options, seconds: c.seconds, default: c.defaultIndex };
  }
  const q = step.qte as { prompt: string; seconds: number; level?: string; lesson?: string } | undefined;
  if (q) o.qte = { id: QTE_IDS[q.prompt] ?? "qte", prompt: q.prompt, seconds: q.seconds, level: q.level ?? "assisted", lesson: q.lesson ?? "" };
  return o;
}

const list = (steps: unknown[]): unknown[] => (steps as Record<string, unknown>[]).map(clean);

const data = {
  _generated: "tools/export_story.ts from web-legacy/src/narrative/Episode1Script.ts. Do not edit by hand; edit the source or data/slice_opening.json.",
  scenes: {
    shop_morning: list(S.shopMorning()),
    lender_runner: list(S.LENDER_RUNNER),
    board_intro: list(S.BOARD_INTRO),
    step_out: list(S.stepOut(ctx)),
    envelope: list(S.envelope(ctx)),
    lola_silence: list(S.lolaSilence(ctx)),
    lola_pressed: list(S.LOLA_PRESSED),
    lola_let_go: list(S.LOLA_LET_GO),
    tondo_safehouse: list(S.TONDO_SAFEHOUSE),
    cliffhanger: list(S.CLIFFHANGER),
  },
};
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(data, null, 1));
console.log("wrote", out, Object.entries(data.scenes).map(([k, v]) => `${k}:${(v as unknown[]).length}`).join(" "));
