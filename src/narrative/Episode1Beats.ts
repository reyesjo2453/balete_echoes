import type { CutsceneStep } from "../ui/ComicOverlay";
import type { EpisodeContext } from "./Episodes";

/**
 * Episode 1 scene scripts for Beats 2, 3 and 5.2-5.3, verbatim from the approved beats (issue #26).
 * Beat 1 lives in Episodes.ts; Beat 4 and 5.1 are the playable field scene (TutorialScene.ts).
 */

const PORTRAIT = (name: string): string => `${import.meta.env.BASE_URL}assets/portraits/${name}.png`;
const RENZO = { speaker: "Renzo", portrait: PORTRAIT("renzo") } as const;
const LOLA = { speaker: "Lola Rosa" } as const;
const ADMIN = { speaker: "Church administrator" } as const;
const NARRATION = { speaker: "Narration" } as const;

/** Beat 2, scene 2.1: the registry delivery in the church courtyard (late morning). */
export const CHURCH_COURTYARD: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*Late morning. The courtyard of the Minor Basilica of the Black Nazarene. Devotees press between vendors selling candles, anting-anting and sliced mangoes. Renzo weaves through with a heavy brown manila envelope.*",
    layout: "banner",
    art: "seal",
  },
  { ...RENZO, text: "Registry delivery from the Binondo district office. Sign here.", layout: "left-split", art: "claws" },
  {
    ...ADMIN,
    text: "You're late, Reyes. The second collection started five minutes ago. Did you take the coastal road through Tondo again?",
    layout: "right-split",
    art: "silhouette",
  },
  { ...RENZO, text: "Traffic on Recto is permanently locked. Be grateful it made it through the flood wall." },
];

/** Beat 2, scene 2.2: a lender's envelope slips onto the wet flagstones. */
export const LENDERS_ENVELOPE: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*A smaller envelope slips from Renzo's clipboard onto the wet flagstones. No return address. Stamped: ASIAN HOUSING & CREDIT CORP — FINAL NOTICE.*",
    layout: "banner",
    art: "claws",
    sfx: "SPLAT",
  },
  {
    ...ADMIN,
    text: "Careful with your mail, boy. Though... if that's who I think it is, dropping it won't make the balance go away. They're seizing commercial lease titles on Carriedo by the end of the month. Even your grandmother's shop is sitting on land they've already rezoned.",
    layout: "right-split",
    art: "silhouette",
  },
  { ...RENZO, text: "My family's business isn't your concern, Father. Just take the delivery.", layout: "left-split", art: "claws" },
];

/** Beat 2, scene 2.3: the watch ticks wrong for the first time. */
export const FIRST_TICK: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*Renzo's thumb brushes the brass pocket watch Lola Rosa gave him that morning. The escapement stutters. The second hand snaps backward three ticks, then freezes.*",
    layout: "banner",
    art: "seal",
    motion: "pushIn",
    sfx: "tk-tk-tk",
  },
  { ...RENZO, text: "What kind of junk did she give me to haul... The mainspring shouldn't bind like that. It's fully wound." },
];

/** Beat 3, scene 3.1: Lola Rosa packs and avoids his eyes (mid-afternoon). */
export const LOLA_PACKING: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*Mid-afternoon, the back room of the shop. Incense and eucalyptus. Waist-high cardboard boxes. Lola Rosa wraps brass apothecary scales in newspaper and will not meet his eyes.*",
    layout: "banner",
    art: "seal",
  },
  {
    ...RENZO,
    text: "The watch wound itself backward outside the basilica. And the administrator says Carriedo's been rezoned. Lola. Look at me.",
    layout: "left-split",
    art: "claws",
  },
  {
    ...LOLA,
    text: "I gave you an old timepiece. Metal wears out, Renzo. Gears slip when the oil dries up.",
    layout: "right-split",
    art: "silhouette",
  },
];

/** Beat 3, scene 3.2: the episode's choice point (Loob resolve metric). */
export const lolaChoice = (ctx: EpisodeContext): CutsceneStep[] => [
  {
    ...RENZO,
    text: "She's lying, and she's good at it. Do I press her, or help her pack?",
    layout: "banner",
    art: "seal",
    choice: {
      options: ['Press her: "Stop lying to me. Who is coming for this shop?"', 'Back off: "Fine. If we\'re leaving, we\'re leaving."'],
      seconds: 10,
      defaultIndex: 1,
      onResolve: (index, expired) => {
        ctx.state.flags.pressedLola = index === 0;
        if (expired) {
          // Hesitating costs: the clock chose for him.
          ctx.state.flags.hesitated = true;
          ctx.state.charge(1);
          ctx.hud.showToast("Time ran out: +1 ledger", 2);
        } else if (index === 0) {
          ctx.state.loob += 1;
          ctx.hud.showToast("Loob +1: Preservation pressure rises. You pressed Lola.", 2.6);
        } else {
          ctx.hud.showToast("Harmony kept. But you are blind to what's coming.", 2.6);
        }
      },
    },
  },
];

export const PRESS_REPLY: CutsceneStep[] = [
  {
    ...RENZO,
    text: "Stop lying to me. Who is coming for this shop, and what does it have to do with the bloodline debt?",
    layout: "left-split",
    art: "claws",
  },
  {
    ...LOLA,
    text: "You want the truth, Renzo? You think your debt to the motorcycle shop is the only thing hanging over your head? Your grandfather signed a lease with the land sixty years ago. Every generation pays rent — some in cash, some in blood. I am packing because my lease just expired.",
    layout: "right-split",
    art: "silhouette",
  },
];

export const BACK_OFF_REPLY: CutsceneStep[] = [
  {
    ...RENZO,
    text: "Fine. If we're leaving, we're leaving. I'll load the spare parts onto the scooter.",
    layout: "left-split",
    art: "claws",
  },
  {
    ...LOLA,
    text: "You are a good boy, Renzo. Too practical for your own good. Just... keep the watch buttoned inside your vest. Don't let the rain touch it.",
    layout: "right-split",
    art: "silhouette",
  },
];

/** Beat 5, scene 5.2: the extraction, seen through the van's rear window. */
export const EXTRACTION: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*Renzo scrambles, bleeding and breathless, into the passenger footwell. Dante slams the van into reverse, tearing away as the beast dissolves into thick, oily black smoke. The van turns onto the wet asphalt of Carriedo Street.*",
    layout: "banner",
    art: "blade",
    shake: true,
  },
  {
    ...NARRATION,
    text: "*Through the rain-smeared rear window, under the amber beacons of an unmarked Aevum tactical truck: the shop's front gate hydraulically forced, hinges snapped, glass and broken ceramic apothecary jars across the pavement.*",
    layout: "banner",
    art: "claws",
    motion: "pushIn",
  },
  {
    ...NARRATION,
    text: "*Two men in corporate hazmat gear carry Lola Rosa's heavy, leather-bound financial and ancestral ledger box out of the doorway and slide it into the truck.*",
    layout: "banner",
    art: "silhouette",
  },
  {
    ...NARRATION,
    text: "*Lola Rosa is marched out between two armed guards, wrists zip-tied, head held high despite her shallow breathing. She is put into the back of the vehicle.*",
    layout: "banner",
    art: "silhouette",
    motion: "impact",
  },
  {
    ...RENZO,
    text: "Stop the van! Dante, stop the vehicle! They've got her! They took her books, they tore the shop apart—they're taking her!",
    layout: "left-split",
    art: "claws",
    shake: true,
  },
  {
    speaker: "Dante",
    portrait: PORTRAIT("dante"),
    text: "We can't take an Aevum tactical squad with a wrench and a battery pack, kid. If we stop now, you're in the back of that truck with her.",
    layout: "right-split",
    art: "blade",
  },
];

/** Beat 5, scene 5.3: the cliffhanger. */
export const CLIFFHANGER: CutsceneStep[] = [
  {
    ...NARRATION,
    text: "*Renzo slumps back, staring blankly at the dashboard lights. He pulls the heavy brass pocket watch from his ruined jacket pocket to steady his shaking hands. The casing steams slightly from the spiritual discharge.*",
    layout: "banner",
    art: "seal",
  },
  {
    ...NARRATION,
    text: "*The hands are no longer spinning backward. They have stopped entirely, pointing past XII to strange, impossible glyphs that match no known hour on earth.*",
    layout: "banner",
    art: "seal",
    motion: "pushIn",
  },
  {
    ...NARRATION,
    text: "*Beneath the glass, a microscopic gear shifts with a sharp click, etching a name into the backing plate that Renzo has never seen before:*  AGUSAN, 1898.",
    layout: "banner",
    art: "seal",
    motion: "impact",
    sfx: "CLICK.",
    flash: true,
  },
];
