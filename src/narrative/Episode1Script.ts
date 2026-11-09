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

type Extra = Partial<CutsceneStep>;
/** Spoken aloud: the dark dialogue bar with a portrait and name tag. */
const say = (who: { speaker: string; portrait: string }, text: string, extra: Extra = {}): CutsceneStep => ({ ...who, text, kind: "say", ...extra });
/** Renzo's inner voice: the violet thought bar. Nobody in the scene hears it. */
const think = (text: string, extra: Extra = {}): CutsceneStep => ({ ...RENZO, text, kind: "think", ...extra });
/** The story itself: the yellow caption box. No speaker. */
const narr = (text: string, extra: Extra = {}): CutsceneStep => ({ speaker: "", text, kind: "narr", ...extra });

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

/**
 * The QTE is taught in four beats, each with less hand-holding than the last:
 *   1. The slipping tin (shop)    guided:   lesson card, no penalty, the ring resets until it is hit.
 *   2. The Honda kick-start       assisted: key cap and ring, a miss costs ten minutes (+1 ledger).
 *   3. The undercroft candles     free:     ring and a small key cap only, a miss costs +1 ledger.
 *   4. The gate brace (field)     free:     same as 3, with the world on the line.
 */

// ---------------------------------------------------------------------------
// Morning: the shop (why Renzo is running courier jobs, and the first hint of the watch)
// ---------------------------------------------------------------------------

export function shopMorning(): CutsceneStep[] {
  return scene([
    narr("Quiapo. Six in the morning. Rain on the tarps, the church bells, candle vendors dragging their stalls out of the wet.", { layout: "banner", panel: "ep1_01_quiapo_dawn" }),
    think("Same bells. Same wax and wet cardboard. Same shop, same debts. Another day of outrunning them."),
    narr("Reyes Watch Repair & Herbs, one room above the herb sellers. Half a bench, half a pharmacy, all of it behind on the rent.", { layout: "left-split", panel: "ep1_02b_stopped_clocks" }),
    narr("On the wall above the bench: nine clocks. Every one of them stopped at 4:17."),
    think("Nine clocks, one time. I fixed them all when I was fourteen. Lola stopped them again, one by one, and never said why."),
    narr("On the bench: a loupe, tweezers, and a lender's final notice. Honda Beat, ₱3,450, two months behind.", { layout: "banner", panel: "ep1_02_workbench_notice" }),
    think("Noon. Then they tow the Honda. No Honda, no runs. No runs, no rent, no coil for the shop."),
    narr("And under the loupe, where it has sat for three weeks: a pocket watch. Lola's."),
    think("Balete-wood case. No maker's mark. No mainspring I can find, and I have looked. Three weeks on my bench and it has never ticked once. Lola says that's how it should be."),
    say(LOLA, "That is the third notice this week, anak. And the rent on this shop is no better. Do not look at me like that. I am only counting.", { layout: "right-split", panel: "ep1_03_lola_packing" }),
    think("Jars of coconut oil wrapped in newspaper. Dried roots in a flour sack. Half the shelf is already in crates. She hasn't said why."),
    say(RENZO, "Lola. Are you going somewhere?"),
    say(LOLA, "Somewhere. At my age. To the market, to the church, one day to the grave. Eat something."),
    say(RENZO, "The crates, 'La."),
    say(LOLA, "...The watch, Renzo. Give it to me."),
    narr("She lifts it off the bench, wrapped in its square of black cloth. For the first time in his life, Renzo sees her hands shake."),
    narr("The cloth slides. The watch falls.", {
      layout: "banner",
      panel: "ep1_03b_tin_slip",
      shake: true,
      sfx: "CLATTER!",
      qte: {
        level: "guided",
        prompt: "CATCH!",
        seconds: 3.4,
        lesson: "Watch the big ring close on the white circle. When it glows green, tap SPACE (or A, or tap the screen).",
        onResult: () => {
          /* guided: no penalty, the ring resets until it is hit */
        },
      },
    }),
    narr("He catches it a hand's width from the floor.", { layout: "banner", panel: "ep1_03c_watch_warm" }),
    think("It's warm. Warm like something that's been held. And then, once, against my palm... tick."),
    say(LOLA, "...Did you hear it?"),
    say(RENZO, "Three weeks, nothing. And it ticked, 'La."),
    say(LOLA, "Then it has decided. Keep it on you today. Not in the bag, not on the bench. In your pocket, against your body. And whatever it does, Renzo, you do not open it."),
    say(RENZO, "Open it? Lola, what is it?"),
    say(LOLA, "Tea is on the stove. Go and look at the corkboard. The cooperative pins the day's work there, and the lenders will not wait because you are curious."),
    think("She has never once told me not to do something I couldn't already do."),
  ]);
}

export const LENDER_RUNNER: CutsceneStep[] = scene([
  narr("A boy in a rain poncho knocks twice, drops a taped parcel and a folded note on the counter, and is gone.", { layout: "banner", panel: "ep1_04_runner_parcel" }),
  think(`The note: "Quiapo Church undercroft. Deliver by noon. ${FORMAT_PESO(2000)}, and your name stays quiet in the 5-6 book." Quiet. That is what he is selling.`),
]);

export const BOARD_INTRO: CutsceneStep[] = scene([
  narr("The corkboard. Three cards pinned under the cooperative stamp, and the ledger notebook hanging on its string.", { layout: "banner", panel: "ep1_05_corkboard" }),
  narr(`Avenida textiles: ${FORMAT_PESO(800)}, safe, 45 minutes. Pandacan cold-storage parts: ${FORMAT_PESO(1500)}, middling, 90 minutes. Church undercroft parcel: ${FORMAT_PESO(2000)}, dangerous, 60 minutes.`),
  think("I can't do all three before the flood. Every job spends time. Every debt unpaid at noon goes in the ledger, and the ledger is family. I pick, then I live with it."),
]);

export function stepOut(ctx: EpisodeContext): CutsceneStep[] {
  return scene([
    narr("Helmet. Gloves. The watch goes in the inside pocket, against his ribs.", { layout: "banner", panel: "ep1_06_honda_ride" }),
    think("Still warm. It shouldn't be. Nothing in my pocket is ever warm."),
    narr("The Honda coughs. Coughs again. Dies. Rain is already in the plug.", { layout: "left-split", panel: "ep1_06_honda_ride" }),
    narr("Kick it, Renzo.", {
      shake: true,
      sfx: "KICK!",
      qte: {
        level: "assisted",
        prompt: "KICK!",
        seconds: 2.4,
        onResult: (ok) => {
          if (ok) return;
          ctx.state.charge(1);
          ctx.hud.showToast("Flooded plug: ten minutes lost, +1 ledger", 2.4);
        },
      },
    }),
    narr("The engine catches and the whole street shakes awake.", { layout: "banner", panel: "ep1_06b_ride_ticking" }),
    think("Tick. Tick. Tick. It doesn't match the engine. It doesn't match my pulse. It ticks like it's counting down to something I haven't done yet."),
    narr("Behind him the Quiapo bells ring the hour, a heartbeat late."),
  ]);
}

// ---------------------------------------------------------------------------
// The Envelope (Scene P.1)
// ---------------------------------------------------------------------------

export function envelope(ctx: EpisodeContext): CutsceneStep[] {
  return scene([
    say(DOMENG, "Ang hirap naman ng buhay, Renzo... Your Lola is late on the shop rent again, hindi ba? The lenders are talking.", { layout: "banner", panel: "ep1_07_mang_domeng" }),
    say(RENZO, "Di bale, Mang Domeng. Kaya ko 'to."),
    think("He carried my family through the lean months. I can't refuse anyone who did that, so I take the church parcel too. Utang na loob doesn't come with an interest rate. It's worse."),
    narr("In the undercroft the sacristan takes the parcel without meeting Renzo's eyes, and slides a lender's envelope across the stone.", { layout: "left-split", panel: "ep1_08_church_undercroft" }),
    narr("Every candle flame in the undercroft leans the same way: toward Renzo's jacket.", {
      layout: "banner",
      panel: "ep1_08b_candles_lean",
      flash: true,
      qte: {
        level: "free",
        prompt: "STEADY!",
        seconds: 2.0,
        onResult: (ok) => {
          if (ok) return;
          ctx.state.charge(1);
          ctx.hud.showToast("The sacristan heard it ticking: +1 ledger", 2.4);
        },
      },
    }),
    think("Palm flat over the pocket. It keeps ticking against my hand like a second pulse. If he heard, he isn't saying."),
    say(SACRISTAN, "The shop is on lease, hijo. You are next. That is what I was asked to say.", { layout: "left-split", panel: "ep1_08_church_undercroft" }),
    narr("In his pocket the ticking stops. Then starts again, wrong. Slower.", { layout: "banner", panel: "ep1_09_watch_backward", flash: true }),
    think("It's running backward. Not broken. Backward, like something unwinding that was wound a very long time ago."),
  ]);
}

// ---------------------------------------------------------------------------
// Lola Rosa's Silence (Scene P.2): choice with a Loob consequence
// ---------------------------------------------------------------------------

export function lolaSilence(ctx: EpisodeContext): CutsceneStep[] {
  return scene([
    say(RENZO, "Lola. This morning it ticked. Now it's running backward.", { layout: "banner", panel: "ep1_10_lola_tea" }),
    say(LOLA, "Tea, Renzo. Chamomile and tanglad. Sit. And tonight, take the watch to Gat. Dizon, Bodega 9. The invoice is in the cloth. Do not open it on the way."),
    think("She won't look at the watch. She is looking at everything else. Do I press her?", {
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
            ctx.state.loob += 1;
            ctx.hud.showToast("Loob +1: you pressed Lola. She won't forget it.", 2.4);
          } else {
            ctx.hud.showToast("Harmony kept. But you are blind to what's coming.", 2.4);
          }
        },
      },
    }),
  ]);
}

export const LOLA_PRESSED: CutsceneStep[] = scene([
  say(RENZO, "Why is it running backward, Lola? Why are the crates packed?", { layout: "banner", panel: "ep1_11_lola_pressed" }),
  say(LOLA, "You want the truth, Renzo? You think the motorcycle is the only debt over your head? Your grandfather signed a lease with the land sixty years ago. Every generation pays rent, some in cash, some in blood. I am packing because my lease just expired."),
  say(LOLA, "Now drink your tea. Some answers cost more than the question, apo. Go. Before dark."),
]);

export const LOLA_LET_GO: CutsceneStep[] = scene([
  think("I let it go. She pours the tea like nothing happened. Her hands are not quite steady.", { layout: "banner", panel: "ep1_10_lola_tea" }),
  say(LOLA, "You are a good boy, Renzo. Too practical for your own good. Just keep the watch buttoned inside your vest. Don't let the rain touch it."),
]);

// ---------------------------------------------------------------------------
// Aftermath (Scene 1.1 and the Chapter 1 closing beat): Tondo safehouse
// ---------------------------------------------------------------------------

export const TONDO_SAFEHOUSE: CutsceneStep[] = scene([
  narr("Tondo. The van slides to a halt inside a cavernous workshop, steam hissing from the radiator.", { layout: "banner", panel: "ep1_20_tondo_arrival", shake: true }),
  say(DANTE, "Drink the gin. Don't pour it on the cuts unless you want to pass out. The claws carry corpse-rot.", { layout: "left-split", panel: "ep1_21_dante_gin" }),
  say(RENZO, "What was that thing? That wasn't a stray. It didn't have bones. It was made of oil and smoke."),
  say(DANTE, "That was an Aswang, kid. A real one. Not the bedtime story your lola told you to keep you off Carriedo at night. And it wasn't wild. It had a corporate telemetry tag clamped to its ear."),
  say(RENZO, "A tag? Who tags a demon?"),
  say(DANTE, "Aevum Filipinas. Private security for the port and half the power grid. They don't kill spirits anymore, Renzo. They harvest them. Now show me the watch."),
  say(DANTE, "Petrified balete wood and cold-cast iron. Spinning backward, no mainspring. Kid, this was never meant to be sold. Your grandmother routed it to you the long way because she knew they were closing in.", { layout: "right-split", panel: "ep1_22_watch_gears" }),
  think("She was already packing. The crates. The stopped clocks. The tea. She knew."),
  narr("Dante's scanner crackles. Aevum chatter, Quiapo sector.", { layout: "banner", panel: "ep1_23_aevum_chatter", flash: true }),
  say(DANTE, "Renzo... while I was pulling you out, they hit Rosa's workshop."),
  say({ speaker: "Scanner", portrait: "" }, "...ledger secured. Subject in custody. Transport to Taguig medical, ETA twenty minutes...", { layout: "banner", panel: "ep1_24_workshop_raid", shake: true }),
  say(RENZO, "Lola."),
]);

export const CLIFFHANGER: CutsceneStep[] = scene([
  narr("The watch jumps in his hand. The hands stop on a time that hasn't happened yet.", { layout: "banner", panel: "ep1_25_watch_future", flash: true, shake: true }),
  narr("Beneath the glass a microscopic gear shifts with a sharp click, etching a name into the backing plate that Renzo has never seen before: AGUSAN, 1898.", { sfx: "CLICK." }),
  think("Agusan. 1898. Whatever this thing is, it was old before Lola was born."),
]);
