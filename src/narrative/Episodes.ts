import type { Player } from "../entities/Player";
import type { ComicOverlay } from "../ui/ComicOverlay";
import type { DispatchBoard } from "../ui/DispatchBoard";
import type { HUD } from "../ui/HUD";
import { DispatchState } from "./DispatchState";
import { BOARD_INTRO, CLIFFHANGER, ENVELOPE, LENDER_RUNNER, LOLA_LET_GO, LOLA_PRESSED, lolaSilence, SHOP_MORNING, STEP_OUT, TONDO_SAFEHOUSE } from "./Episode1Script";

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
    { id: "lenders-runner", run: (ctx) => ctx.comics.play(LENDER_RUNNER) },
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
    { id: "envelope", run: (ctx) => ctx.comics.play(ENVELOPE) },
    {
      id: "lola-silence",
      run: async (ctx) => {
        await ctx.comics.play(lolaSilence(ctx));
        await ctx.comics.play(ctx.state.flags.pressedLola ? LOLA_PRESSED : LOLA_LET_GO);
      },
    },
    { id: "quiapo-alley", run: (ctx) => ctx.field() },
    { id: "tondo-safehouse", run: (ctx) => ctx.comics.play(TONDO_SAFEHOUSE) },
    { id: "cliffhanger-watch", run: (ctx) => ctx.comics.play(CLIFFHANGER) },
    {
      id: "cliffhanger",
      run: (ctx) =>
        ctx.comics.showTitleCard({
          act: "To be continued",
          title: "The watch shows a time that hasn't happened yet",
          subtitle: "Episode 2: Fort Santiago",
          hold: 2.6,
        }),
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
