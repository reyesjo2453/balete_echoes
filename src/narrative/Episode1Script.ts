import type { CutsceneStep } from "../ui/ComicOverlay";
import type { EpisodeContext } from "./Episodes";

/**
 * Episode 1 script, written from docs/STORY.md (Prologue Expansion P.1 / P.2, Scene 1.1 and the
 * Chapter 1 closing beat) and docs/EPISODIC_DIRECTION.md (Episode 1 shape).
 *
 * Every panel is an art-manifest id (src/assets/artManifest.ts): placeholders draw themselves until
 * the real file is dropped into public/assets. Portraits are `portrait_<name>` ids the same way.
 */

const FORMAT_PESO = (n: number): string => `₱${n.toLocaleString("en-US")}`;

const RENZO = { speaker: "Renzo", portrait: "portrait_renzo" } as const;
const LOLA = { speaker: "Lola Rosa", portrait: "portrait_lola" } as const;
const DANTE = { speaker: "Dante", portrait: "portrait_dante" } as const;
const DOMENG = { speaker: "Mang Domeng", portrait: "portrait_mang_domeng" } as const;
const SACRISTAN = { speaker: "Sacristan", portrait: "portrait_sacristan" } as const;

/**
 * Story scenes keep the current panel on screen across dialogue-only lines: a step with no layout
 * inherits the previous step's layout and panel, so a beat reads as one picture, not a flash of alley.
 */
function scene(steps: CutsceneStep[]): CutsceneStep[] {
  let layout: CutsceneStep["layout"];
  let panel: string | undefined;
  return steps.map((step) => {
    if (step.layout) layout = step.layout;
    if (step.panel) panel = step.panel;
    return { ...step, layout: step.layout ?? layout, panel: step.panel ?? panel };
  });
}

// ---------------------------------------------------------------------------
// Morning: the shop (why Renzo is running courier jobs at all)
// ---------------------------------------------------------------------------

export const SHOP_MORNING: CutsceneStep[] = scene([
  { ...RENZO, text: "Six in the morning. Quiapo bells, wet pavement, vendors dragging tarps over the candle stalls.", layout: "banner", panel: "ep1_01_quiapo_dawn" },
  { ...RENZO, text: `Under the tweezers: a final notice. Honda Beat repayment, ${FORMAT_PESO(3450)}, two months delinquent.`, layout: "left-split", panel: "ep1_02_workbench_notice" },
  { ...LOLA, text: "That is the third notice this week, anak. And the rent on this shop is no better. Do not look at me like that. I am only counting.", layout: "right-split", panel: "ep1_03_lola_packing" },
  { ...RENZO, text: "If I don't clear something by noon, they tow the Honda. No Honda, no runs. No runs, no money for the rent or the coil." },
  { ...RENZO, text: "Jars of coconut oil wrapped in newspaper. Dried roots in a flour sack. Half the shelf is already in crates. She hasn't said why." },
  { ...RENZO, text: "Lola. Are you going somewhere?" },
  { ...LOLA, text: "Tea is on the stove. Go and look at the corkboard. The cooperative pins the day's work there, and the lenders will not wait because you are curious." },
]);

export const LENDER_RUNNER: CutsceneStep[] = scene([
  { speaker: "Lender's runner", portrait: "portrait_runner", text: "*A boy in a rain poncho knocks twice, drops a taped parcel and a folded note on the counter, and is gone.*", layout: "banner", panel: "ep1_04_runner_parcel" },
  { ...RENZO, text: `The note: "Quiapo Church undercroft. Deliver by noon. ${FORMAT_PESO(2000)}, and your name stays quiet in the 5-6 book." Quiet. That is what he is selling.` },
]);

export const BOARD_INTRO: CutsceneStep[] = scene([
  { ...RENZO, text: "The corkboard. Three cards pinned under the cooperative stamp, and the ledger notebook hanging on its string.", layout: "banner", panel: "ep1_05_corkboard" },
  { ...RENZO, text: `Avenida textiles: ${FORMAT_PESO(800)}, safe, 45 minutes. Pandacan cold-storage parts: ${FORMAT_PESO(1500)}, middling, 90 minutes. Church undercroft parcel: ${FORMAT_PESO(2000)}, dangerous, 60 minutes.` },
  { ...RENZO, text: "I can't do all three before the flood. Every job spends time. Every debt unpaid at noon goes in the ledger, and the ledger is family. I pick, then I live with it." },
]);

export const STEP_OUT: CutsceneStep[] = scene([
  { ...RENZO, text: "Helmet, gloves, the Honda coughing awake. Rain on the visor.", layout: "banner", panel: "ep1_06_honda_ride" },
  { ...RENZO, text: "Kick, and it's alive. Ahead of the flood, hopefully. Let's go.", layout: "left-split", panel: "ep1_06_honda_ride", shake: true },
]);

// ---------------------------------------------------------------------------
// The Envelope (Scene P.1)
// ---------------------------------------------------------------------------

export const ENVELOPE: CutsceneStep[] = scene([
  { ...DOMENG, text: "Ang hirap naman ng buhay, Renzo... Your Lola is late on the shop rent again, hindi ba? The lenders are talking.", layout: "banner", panel: "ep1_07_mang_domeng" },
  { ...RENZO, text: "Di bale, Mang Domeng. Kaya ko 'to." },
  { ...RENZO, text: "He carried my family through the lean months. I can't refuse anyone who did that, so I take the church parcel too. Utang na loob doesn't come with an interest rate. It's worse." },
  { ...SACRISTAN, text: "*In the undercroft the sacristan takes the parcel without meeting Renzo's eyes, and slides a lender's envelope across the stone.*", layout: "left-split", panel: "ep1_08_church_undercroft" },
  { ...SACRISTAN, text: "The shop is on lease, hijo. You are next. That is what I was asked to say." },
  { ...RENZO, text: "In my pocket the watch ticks once, wrong. Then again. It is running backward.", layout: "banner", panel: "ep1_09_watch_backward", flash: true },
]);

// ---------------------------------------------------------------------------
// Lola Rosa's Silence (Scene P.2): choice with a Loob consequence
// ---------------------------------------------------------------------------

export function lolaSilence(ctx: EpisodeContext): CutsceneStep[] {
  return scene([
    { ...RENZO, text: "Lola. The watch just ran backward in my pocket.", layout: "banner", panel: "ep1_10_lola_tea" },
    { ...LOLA, text: "Tea, Renzo. Chamomile and tanglad. Sit. And tonight, take the watch to Gat. Dizon, Bodega 9. The invoice is in the cloth. Do not open it on the way." },
    {
      ...RENZO,
      text: "She won't look at the watch. She is looking at everything else. Do I press her?",
      panel: "ep1_10_lola_tea",
      choice: {
        options: ["Press her about the watch", "Let it go"],
        seconds: 8,
        defaultIndex: 1,
        onResolve: (index, expired) => {
          ctx.state.flags.pressedLola = index === 0;
          if (expired) {
            ctx.state.flags.hesitated = true;
            ctx.state.charge(1);
            ctx.hud.showToast("Time ran out: +1 ledger", 2);
          } else if (index === 0) {
            ctx.hud.showToast("You pressed Lola. She won't forget it.", 2);
          }
        },
      },
    },
  ]);
}

export const LOLA_PRESSED: CutsceneStep[] = scene([
  { ...RENZO, text: "Why is it running backward, Lola? Why are the crates packed?", layout: "banner", panel: "ep1_11_lola_pressed" },
  { ...LOLA, text: "Drink your tea. Some answers cost more than the question, apo. Go. Before dark." },
]);

export const LOLA_LET_GO: CutsceneStep[] = scene([
  { ...RENZO, text: "I let it go. She pours the tea like nothing happened. Her hands are not quite steady.", layout: "banner", panel: "ep1_10_lola_tea" },
]);

// ---------------------------------------------------------------------------
// Aftermath (Scene 1.1 and the Chapter 1 closing beat): Tondo safehouse
// ---------------------------------------------------------------------------

export const TONDO_SAFEHOUSE: CutsceneStep[] = scene([
  { speaker: "", text: "*Tondo. The van slides to a halt inside a cavernous workshop, steam hissing from the radiator.*", layout: "banner", panel: "ep1_20_tondo_arrival", shake: true },
  { ...DANTE, text: "Drink the gin. Don't pour it on the cuts unless you want to pass out. The claws carry corpse-rot.", layout: "left-split", panel: "ep1_21_dante_gin" },
  { ...RENZO, text: "What was that thing? That wasn't a stray. It didn't have bones. It was made of oil and smoke." },
  { ...DANTE, text: "That was an Aswang, kid. A real one. Not the bedtime story your lola told you to keep you off Carriedo at night. And it wasn't wild. It had a corporate telemetry tag clamped to its ear." },
  { ...RENZO, text: "A tag? Who tags a demon?" },
  { ...DANTE, text: "Aevum Filipinas. Private security for the port and half the power grid. They don't kill spirits anymore, Renzo. They harvest them. Now show me the watch." },
  { ...DANTE, text: "Petrified balete wood and cold-cast iron. Spinning backward, no mainspring. Kid, this was never meant to be sold. Your grandmother routed it to you the long way because she knew they were closing in.", layout: "right-split", panel: "ep1_22_watch_gears" },
  { ...RENZO, text: "She was already packing. The crates. She knew." },
  { ...DANTE, text: "*His scanner crackles. Aevum chatter, Quiapo sector.* Renzo... while I was pulling you out, they hit Rosa's workshop.", layout: "banner", panel: "ep1_23_aevum_chatter", flash: true },
  { speaker: "Scanner", text: "*...ledger secured. Subject in custody. Transport to Taguig medical, ETA twenty minutes...*", layout: "banner", panel: "ep1_24_workshop_raid", shake: true },
  { ...RENZO, text: "Lola." },
]);

export const CLIFFHANGER: CutsceneStep[] = scene([
  { ...RENZO, text: "The watch jumps in my hand. The hands stop on a time that hasn't happened yet. And scratched into the glass, a name I never told anyone.", layout: "banner", panel: "ep1_25_watch_future", flash: true, shake: true },
]);
