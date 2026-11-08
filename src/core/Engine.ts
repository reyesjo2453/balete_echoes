export type GameState = "boot" | "title" | "explore" | "combat" | "cutscene" | "paused";

export interface System {
  /**
   * Called every tick.
   * @param simulationDelta clamped frame delta scaled by time dilation (AI, movement, cooldowns)
   * @param state current game state
   * @param unscaledDelta clamped raw frame delta (camera, input, UI, particles)
   */
  update(simulationDelta: number, state: GameState, unscaledDelta: number): void;
}

type DilationListener = (active: boolean) => void;
type StateListener = (next: GameState, prev: GameState) => void;

const MAX_DT = 1 / 20; // clamp large frame gaps (tab switches, breakpoints)
/** Delta-time multiplier while the Command button is held (active pause). */
export const COMMAND_TIME_SCALE = 0.05;

/**
 * Main requestAnimationFrame loop and top-level game state machine.
 * Systems are updated in registration order; `render` runs last.
 */
export class Engine {
  private readonly systems: System[] = [];
  private readonly listeners = new Set<StateListener>();
  private readonly dilationListeners = new Set<DilationListener>();
  private rafId = 0;
  private lastTime = 0;
  private _state: GameState = "boot";
  private _elapsed = 0;
  private resumeState: GameState = "explore";
  private _timeScale = 1;
  private _dilated = false;
  private _frozen = false;

  constructor(private readonly render: () => void) {}

  get state(): GameState {
    return this._state;
  }

  /** Total unpaused seconds since start. */
  get elapsed(): number {
    return this._elapsed;
  }

  /**
   * The GDD's `timeDilation`: 0.0 while frozen (cutscenes), COMMAND_TIME_SCALE (0.05x) during Reflex
   * Mode, else 1.0. Only `simulationDelta` is multiplied by it; `unscaledDelta` never is.
   */
  get timeDilation(): number {
    return this._timeScale;
  }

  /** Alias of `timeDilation`. */
  get timeScale(): number {
    return this._timeScale;
  }

  /** True while the tactical-command time dilation is engaged. */
  get timeDilated(): boolean {
    return this._dilated;
  }

  get frozen(): boolean {
    return this._frozen;
  }

  /** Enter/leave the time-dilation (tactical command) state. */
  setTimeDilation(active: boolean): void {
    if (active === this._dilated) return;
    this._dilated = active;
    this.refreshTimeScale();
    this.dilationListeners.forEach((fn) => fn(active));
  }

  /** Freeze the world simulation completely (timeDilation 0.0), e.g. during cutscenes. */
  setFrozen(frozen: boolean): void {
    if (frozen === this._frozen) return;
    this._frozen = frozen;
    this.refreshTimeScale();
  }

  /**
   * Run `task` with the world frozen (timeDilation 0.0). Time dilation is
   * restored to 1.0 when it settles, even if it throws.
   */
  async runFrozen<T>(task: () => Promise<T>): Promise<T> {
    const wasFrozen = this._frozen;
    this.setTimeDilation(false);
    this.setFrozen(true);
    try {
      return await task();
    } finally {
      this.setFrozen(wasFrozen);
    }
  }

  private refreshTimeScale(): void {
    this._timeScale = this._frozen ? 0 : this._dilated ? COMMAND_TIME_SCALE : 1;
  }

  /** Fires only when dilation actually engages (true) or disengages (false). */
  onTimeDilationChange(fn: DilationListener): () => void {
    this.dilationListeners.add(fn);
    return () => this.dilationListeners.delete(fn);
  }

  add(system: System): this {
    this.systems.push(system);
    return this;
  }

  onStateChange(fn: StateListener): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  setState(next: GameState): void {
    if (next === this._state) return;
    const prev = this._state;
    this._state = next;
    this.listeners.forEach((fn) => fn(next, prev));
  }

  togglePause(): void {
    if (this._state === "paused") {
      this.setState(this.resumeState);
    } else {
      this.resumeState = this._state;
      this.setState("paused");
    }
  }

  /** Begin the loop; the first state is `initial` ("title" shows the title screen first). */
  start(initial: GameState = "explore"): void {
    if (this.rafId) return;
    this.lastTime = performance.now();
    if (this._state === "boot") this.setState(initial);
    this.rafId = requestAnimationFrame(this.tick);
  }

  stop(): void {
    cancelAnimationFrame(this.rafId);
    this.rafId = 0;
  }

  private readonly tick = (now: number): void => {
    this.rafId = requestAnimationFrame(this.tick);
    // Dual-delta clock: the sim clock is dilated, the raw clock (camera, input, UI, particles) never is.
    const unscaledDelta = Math.min((now - this.lastTime) / 1000, MAX_DT);
    const simulationDelta = unscaledDelta * this.timeDilation;
    this.lastTime = now;
    if (this._state !== "paused") this._elapsed += simulationDelta;

    for (const system of this.systems) system.update(simulationDelta, this._state, unscaledDelta);
    this.render();
  };
}
