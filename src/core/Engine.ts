export type GameState = "boot" | "explore" | "combat" | "cutscene" | "paused";

export interface System {
  /** Called every tick with clamped delta seconds. */
  update(dt: number, state: GameState): void;
}

type StateListener = (next: GameState, prev: GameState) => void;

const MAX_DT = 1 / 20; // clamp large frame gaps (tab switches, breakpoints)

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

  constructor(private readonly render: () => void) {}

  get state(): GameState {
    return this._state;
  }

  /** Total unpaused seconds since start. */
  get elapsed(): number {
    return this._elapsed;
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
    const dt = Math.min((now - this.lastTime) / 1000, MAX_DT);
    this.lastTime = now;
    if (this._state !== "paused") this._elapsed += dt;

    for (const system of this.systems) system.update(dt, this._state);
    this.render();
  };
}
