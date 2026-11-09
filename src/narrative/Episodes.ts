import type { Player } from "../entities/Player";
import type { ComicOverlay, CutsceneStep } from "../ui/ComicOverlay";
import type { DispatchBoard } from "../ui/DispatchBoard";
import type { HUD } from "../ui/HUD";
import { DispatchState } from "./DispatchState";
import {
  BACK_OFF_REPLY,
  CHURCH_COURTYARD,
  CLIFFHANGER,
  EXTRACTION,
  FIRST_TICK,
  LENDERS_ENVELOPE,
  LOLA_PACKING,
  lolaChoice,
  PRESS_REPLY,
} from "./Episode1Beats";

const PORTRAIT = (name: string): string => `${import.meta.env.BASE_URL}assets/portraits/${name}.png`;

/** Everything a scene may touch while an episode runs. */
export interface EpisodeContext {
  comics: ComicOverlay;
  board: DispatchBoard;
  state: DispatchState;
  /** Starts the playable field scene; resolves when the field scene reports completion. */
  field: () => Promise<void>;
  hud: HUD;
}

export interface EpisodeScene {
  id: string;
  run: (ctx: EpisodeContext) => Promise<void>;
}

export interface Episode {
  id: number;
  title: string;
  subtitle: string;
  /** Unreleased episodes show as "coming soon" in the selector. */
  released: boolean;
  /** Ordered scene list: cold open -> shop story -> corkboard -> field scenes -> set-piece -> cliffhanger. */
  scenes: EpisodeScene[];
}

const RENZO = { speaker: "Renzo", portrait: PORTRAIT("renzo") } as const;
const LOLA = { speaker: "Lola Rosa" } as const;
const FORMAT_PESO = (n: number): string => `₱${n.toLocaleString("en-US")}`;

/**
 * Beat 1, scenes 1.1 and 1.2: why Renzo is working courier runs at all. Dialogue follows the
 * approved Beat 1 outline (see issue #26 / #34).
 */
const SHOP_MORNING: CutsceneStep[] = [
  {
    ...RENZO,
    text: "Quiapo bells, six in the morning. A dead man's pocket watch, a loupe, and the stator coil I still can't afford for the Honda.",
    layout: "banner",
    art: "seal",
  },
  {
    ...RENZO,
    text: `Under the tweezers: a final notice from the lender. Honda Beat repayment, ${FORMAT_PESO(3450)}, delinquent. Two missed months.`,
    layout: "left-split",
    art: "claws",
  },
  {
    ...LOLA,
    text: "That is the third notice this week, anak. Back rent on this shop is no better. Do not look at me like that, I am only counting.",
    layout: "right-split",
    art: "silhouette",
  },
  {
    ...RENZO,
    text: "If I don't clear something by noon, they tow the Honda. No Honda, no runs. No runs, no money for the shop or the coil.",
  },
  {
    ...LOLA,
    text: "Mm. Then go and see the ledger. The cooperative pins the day's work on my corkboard.",
    layout: "banner",
    art: "seal",
  },
  {
    ...RENZO,
    text: "Lola Rosa is wrapping jars of coconut oil in newspaper. Dried roots in a flour sack. Half the shelf is already in crates. She hasn't said why.",
    layout: "left-split",
    art: "claws",
  },
  {
    ...RENZO,
    text: "Lola. Are you going somewhere?",
  },
  {
    ...LOLA,
    text: "Tea is on the stove. Fix your watch, Renzo. The corkboard is behind you, and the lenders will not wait because you are curious.",
    layout: "right-split",
    art: "silhouette",
  },
];

/** Beat 1, scene 1.3: the corkboard as a moment in the shop, with the system explained in dialogue. */
const BOARD_INTRO: CutsceneStep[] = [
  {
    ...RENZO,
    text: "The corkboard. Three cards pinned under the cooperative stamp, and the ledger notebook hanging on its string.",
    layout: "banner",
    art: "seal",
  },
  {
    ...RENZO,
    text: `Avenida textiles: ${FORMAT_PESO(800)}, safe, 45 minutes. Pandacan cold-storage parts: ${FORMAT_PESO(1500)}, middling, 90 minutes. Church undercroft parcel: ${FORMAT_PESO(2000)}, dangerous, 60 minutes.`,
  },
  {
    ...RENZO,
    text: "I can't do all three before the flood. Every job spends time. Every unpaid debt at noon goes in the ledger, and the ledger is family. I pick, then I live with it.",
  },
];

/** Beat 1, scene 1.4: out the door and into the gameplay loop. */
const STEP_OUT: CutsceneStep[] = [
  {
    ...RENZO,
    text: "Helmet, gloves, the watch still ticking in my pocket. The Honda coughs, catches, and coughs again.",
    layout: "banner",
    art: "blade",
  },
  {
    ...RENZO,
    text: "Kick, and it's alive. Rain on the visor. Ahead of the afternoon flood, hopefully. Let's go.",
    layout: "left-split",
    art: "blade",
    shake: true,
  },
];

/** Episode 1: Prologue + Chapter 1. The Quiapo alley slice is the `field` scene, unchanged. */
export const EPISODE_1: Episode = {
  id: 1,
  title: "Ang Lumang Orasan",
  subtitle: "Prologue · Chapter 1 · Quiapo",
  released: true,
  scenes: [
    {
      id: "cold-open",
      run: (ctx) => ctx.comics.showTitleCard({ act: "Episode 1", title: "Ang Lumang Orasan", subtitle: "Quiapo · Morning", hold: 1.6 }),
    },
    { id: "shop-morning", run: (ctx) => ctx.comics.play(SHOP_MORNING) },
    {
      id: "dispatch-board",
      run: async (ctx) => {
        await ctx.comics.play(BOARD_INTRO);
        await ctx.board.open(ctx.state, {
          title: "Lola's Corkboard · Cooperative Dispatch Ledger",
          note: "Pinned by the cooperative. Take work to cover what you owe before noon; whatever is unpaid when the flood comes is added to the family ledger.",
          goLabel: "Out the door ▸",
        });
        const penalty = ctx.state.settle();
        if (penalty > 0) ctx.hud.showToast(`Unpaid debts: +${penalty} ledger`, 2.2);
      },
    },
    { id: "step-out", run: (ctx) => ctx.comics.play(STEP_OUT) },
    { id: "church-courtyard", run: (ctx) => ctx.comics.play(CHURCH_COURTYARD) },
    { id: "lenders-envelope", run: (ctx) => ctx.comics.play(LENDERS_ENVELOPE) },
    { id: "first-tick", run: (ctx) => ctx.comics.play(FIRST_TICK) },
    { id: "lola-packing", run: (ctx) => ctx.comics.play(LOLA_PACKING) },
    {
      id: "lola-choice",
      run: async (ctx) => {
        await ctx.comics.play(lolaChoice(ctx));
        await ctx.comics.play(ctx.state.flags.pressedLola ? PRESS_REPLY : BACK_OFF_REPLY);
      },
    },
    // Beat 4 (dusk) and Beat 5.1 (van and gate ram) are the playable field scene.
    { id: "quiapo-alley", run: (ctx) => ctx.field() },
    { id: "extraction", run: (ctx) => ctx.comics.play(EXTRACTION) },
    { id: "cliffhanger", run: (ctx) => ctx.comics.play(CLIFFHANGER) },
    {
      id: "episode-card",
      run: (ctx) =>
        ctx.comics.showTitleCard({ act: "Episode 1", title: "The Quiapo Underground", subtitle: "Complete", hold: 2.6 }),
    },
  ],
};

export const EPISODES: Episode[] = [
  EPISODE_1,
  { id: 2, title: "Fort Santiago", subtitle: "Chapter 2", released: false, scenes: [] },
];

export interface EpisodeDirectorDeps {
  comics: ComicOverlay;
  board: DispatchBoard;
  hud: HUD;
  player: Player;
  /** Starts the playable field scene (the Quiapo slice). */
  beginField: () => void;
  /** Called after the last scene with the board state, for the summary card. */
  onEpisodeEnd: (episode: Episode, state: DispatchState) => void;
}

/** Runs an episode's scenes in order and owns the dispatch state for the run. */
export class EpisodeDirector {
  current: Episode | null = null;
  state = new DispatchState();
  private fieldDone: (() => void) | null = null;
  private runId = 0;

  constructor(private readonly d: EpisodeDirectorDeps) {}

  async start(episode: Episode): Promise<void> {
    const run = ++this.runId;
    this.current = episode;
    this.state = new DispatchState();
    this.fieldDone = null;
    this.d.board.showChip(null);
    const ctx: EpisodeContext = {
      comics: this.d.comics,
      board: this.d.board,
      state: this.state,
      hud: this.d.hud,
      field: () => this.runField(),
    };
    for (const scene of episode.scenes) {
      if (run !== this.runId) return; // restarted underneath us
      await scene.run(ctx);
      this.d.board.showChip(this.state);
    }
    if (run === this.runId) this.d.onEpisodeEnd(episode, this.state);
  }

  /** The field scene (tutorial director) reports it is finished. */
  notifyFieldComplete(): void {
    const done = this.fieldDone;
    this.fieldDone = null;
    done?.();
  }

  /** Gate-ram QTE outcome: a miss costs injury and ledger, not a game over. */
  gateQte(success: boolean): void {
    const { player, hud, board } = this.d;
    if (success) {
      hud.showToast("Braced! Renzo takes the impact standing.", 2);
      return;
    }
    player.hp = Math.max(1, player.hp - player.maxHp * 0.2);
    this.state.charge(2);
    board.showChip(this.state);
    hud.showToast("Too slow: Renzo is thrown. -20% HP, +2 ledger", 2.4);
  }

  private runField(): Promise<void> {
    return new Promise((resolve) => {
      this.fieldDone = resolve;
      this.d.beginField();
      // The day's risky jobs follow Renzo into the alley: he starts injured.
      const injury = this.state.injury;
      if (injury > 0) {
        this.d.player.hp = Math.max(1, Math.round(this.d.player.maxHp * (1 - injury)));
        this.d.hud.showToast(`Rough day: Renzo starts at ${Math.round((1 - injury) * 100)}% HP`, 2.6);
      }
    });
  }
}
