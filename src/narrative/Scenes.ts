import type { CutsceneStep } from "../ui/ComicOverlay";

const PORTRAIT = (name: string): string => `${import.meta.env.BASE_URL}assets/portraits/${name}.png`;

/** Opening beat at the sari-sari stall; the Corrupted Aswang is released when it ends. */
export const QUIAPO_AMBUSH_SCENE: CutsceneStep[] = [
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "Lola's protective seal... it's broken. The wax hasn't even cooled yet.",
    layout: "banner",
    art: "seal",
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "These aren't knife marks. Something tore through the ironwood frame from the inside.",
    layout: "left-split",
    art: "claws",
    shake: true,
  },
  {
    speaker: "???",
    text: "*A guttural hiss echoes from the rain-slicked alley behind the stalls.*",
    layout: "right-split",
    art: "silhouette",
    flash: true,
    shake: true,
  },
  {
    speaker: "Renzo",
    portrait: PORTRAIT("renzo"),
    text: "Walang atrasan. Show yourself!",
    layout: "left-split",
    art: "blade",
    shake: true,
  },
];

export const QUEST_ACT_I = "Act I: Examine the broken seal at the Quiapo stall";
export const QUEST_ACT_II = "Act II: Investigate the Subterranean Bastion under Fort Santiago";
