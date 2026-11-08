export type GameState = "boot" | "explore" | "combat" | "cutscene" | "paused";

export interface System {
  /** Called every tick with clamped delta seconds. */
  update(dt: number, state: GameState): void;
}

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
  private rafId = 0;
  private lastTime = 0;
  private _state: GameState = "boot";
  private _elapsed = 0;
  private resumeState: GameState = "explore";
  private _timeScale = 1;

  constructor(private readonly render: () => void) {}

  get state(): GameState {
    return this._state;
  }

  /** Total unpaused seconds since start. */
  get elapsed(): number {
    return this._elapsed;
  }

  /** Current delta-time multiplier (1 normally, COMMAND_TIME_SCALE while dilated). */
  get timeScale(): number {
    return this._timeScale;
  }

  get timeDilated(): boolean {
    return this._timeScale !== 1;
  }

  /** Enter/leave the time-dilation (tactical command) state. */
  setTimeDilation(active: boolean): void {
    this._timeScale = active ? COMMAND_TIME_SCALE : 1;
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

  start(): void {
    if (this.rafId) return;
    this.lastTime = performance.now();
    if (this._state === "boot") this.setState("explore");
    this.rafId = requestAnimationFrame(this.tick);
  }

  stop(): void {
    cancelAnimationFrame(this.rafId);
    this.rafId = 0;
  }

  private readonly tick = (now: number): void => {
    this.rafId = requestAnimationFrame(this.tick);
    const dt = Math.min((now - this.lastTime) / 1000, MAX_DT) * this._timeScale;
    this.lastTime = now;
    if (this._state !== "paused") this._elapsed += dt;

    for (const system of this.systems) system.update(dt, this._state);
    this.render();
  };
}
