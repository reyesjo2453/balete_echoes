import * as THREE from "three";

const GAMEPAD_DEADZONE = 0.18;
const TOUCH_STICK_RADIUS = 60; // px

export type InputAction = "confirm" | "cancel" | "wheel" | "pause";

/**
 * Unifies keyboard (WASD/arrows), the HTML5 Gamepad API (left analog stick)
 * and a touch virtual stick into a single normalised movement vector on the
 * X/Z ground plane, plus a small set of edge-triggered actions.
 */
export class InputManager {
  /** Movement intent on the ground plane: x = right, y = forward(-Z). Length ≤ 1. */
  readonly move = new THREE.Vector2();

  private readonly keys = new Set<string>();
  private readonly pressed = new Set<InputAction>();
  private readonly held = new Set<InputAction>();
  private readonly touchVec = new THREE.Vector2();
  private touchId: number | null = null;
  private touchOrigin = { x: 0, y: 0 };
  private stickEl: HTMLDivElement | null = null;
  private knobEl: HTMLDivElement | null = null;
  private prevPadButtons: boolean[] = [];
  private readonly listeners: Array<() => void> = [];

  constructor(surface: HTMLElement) {
    this.on(window, "keydown", (e) => this.onKeyDown(e as KeyboardEvent));
    this.on(window, "keyup", (e) => this.keys.delete((e as KeyboardEvent).code));
    this.on(window, "blur", () => this.keys.clear());
    this.on(surface, "touchstart", (e) => this.onTouchStart(e as TouchEvent), { passive: false });
    this.on(surface, "touchmove", (e) => this.onTouchMove(e as TouchEvent), { passive: false });
    this.on(surface, "touchend", (e) => this.onTouchEnd(e as TouchEvent));
    this.on(surface, "touchcancel", (e) => this.onTouchEnd(e as TouchEvent));
  }

  /** Poll devices. Call once per frame before game logic. */
  update(): void {
    let x = 0;
    let y = 0;

    // Keyboard
    if (this.keys.has("KeyA") || this.keys.has("ArrowLeft")) x -= 1;
    if (this.keys.has("KeyD") || this.keys.has("ArrowRight")) x += 1;
    if (this.keys.has("KeyW") || this.keys.has("ArrowUp")) y += 1;
    if (this.keys.has("KeyS") || this.keys.has("ArrowDown")) y -= 1;

    // Touch stick
    x += this.touchVec.x;
    y += this.touchVec.y;

    // Gamepad (first connected, standard mapping)
    const pad = this.firstGamepad();
    if (pad) {
      const ax = applyDeadzone(pad.axes[0] ?? 0, GAMEPAD_DEADZONE);
      const ay = applyDeadzone(pad.axes[1] ?? 0, GAMEPAD_DEADZONE);
      x += ax;
      y -= ay; // stick up is negative
      this.pollPadButtons(pad);
    }

    this.move.set(x, y);
    if (this.move.lengthSq() > 1) this.move.normalize();
  }

  /** True on the single frame an action was triggered. */
  consume(action: InputAction): boolean {
    const hit = this.pressed.has(action);
    this.pressed.delete(action);
    return hit;
  }

  isHeld(action: InputAction): boolean {
    return this.held.has(action);
  }

  /** Clear edge-triggered actions at the end of the frame. */
  endFrame(): void {
    this.pressed.clear();
  }

  dispose(): void {
    this.listeners.forEach((off) => off());
    this.listeners.length = 0;
    this.stickEl?.remove();
  }

  // ---------------------------------------------------------------------

  private firstGamepad(): Gamepad | null {
    if (typeof navigator.getGamepads !== "function") return null;
    for (const pad of navigator.getGamepads()) {
      if (pad && pad.connected) return pad;
    }
    return null;
  }

  private pollPadButtons(pad: Gamepad): void {
    // Standard mapping: 0 = A/Cross, 1 = B/Circle, 4/5 = bumpers, 9 = Start
    const map: Array<[number, InputAction]> = [
      [0, "confirm"],
      [1, "cancel"],
      [5, "wheel"],
      [9, "pause"],
    ];
    for (const [index, action] of map) {
      const down = pad.buttons[index]?.pressed ?? false;
      const wasDown = this.prevPadButtons[index] ?? false;
      if (down && !wasDown) this.pressed.add(action);
      if (down) this.held.add(action);
      else if (wasDown) this.held.delete(action);
      this.prevPadButtons[index] = down;
    }
  }

  private onKeyDown(e: KeyboardEvent): void {
    if (!e.repeat) {
      const action = KEY_ACTIONS[e.code];
      if (action) this.pressed.add(action);
    }
    this.keys.add(e.code);
  }

  private onTouchStart(e: TouchEvent): void {
    if (this.touchId !== null) return;
    const t = e.changedTouches[0];
    // Left half of the screen drives movement.
    if (t.clientX > window.innerWidth / 2) {
      this.pressed.add("confirm");
      return;
    }
    e.preventDefault();
    this.touchId = t.identifier;
    this.touchOrigin = { x: t.clientX, y: t.clientY };
    this.showStick(t.clientX, t.clientY);
  }

  private onTouchMove(e: TouchEvent): void {
    const t = findTouch(e.changedTouches, this.touchId);
    if (!t) return;
    e.preventDefault();
    let dx = t.clientX - this.touchOrigin.x;
    let dy = t.clientY - this.touchOrigin.y;
    const len = Math.hypot(dx, dy);
    if (len > TOUCH_STICK_RADIUS) {
      dx = (dx / len) * TOUCH_STICK_RADIUS;
      dy = (dy / len) * TOUCH_STICK_RADIUS;
    }
    this.touchVec.set(dx / TOUCH_STICK_RADIUS, -dy / TOUCH_STICK_RADIUS);
    if (this.knobEl) this.knobEl.style.transform = `translate(${dx}px, ${dy}px)`;
  }

  private onTouchEnd(e: TouchEvent): void {
    if (!findTouch(e.changedTouches, this.touchId)) return;
    this.touchId = null;
    this.touchVec.set(0, 0);
    if (this.stickEl) this.stickEl.hidden = true;
  }

  private showStick(x: number, y: number): void {
    if (!this.stickEl) {
      this.stickEl = document.createElement("div");
      this.stickEl.className = "touch-stick";
      this.knobEl = document.createElement("div");
      this.knobEl.className = "touch-stick-knob";
      this.stickEl.appendChild(this.knobEl);
      document.body.appendChild(this.stickEl);
    }
    this.stickEl.hidden = false;
    this.stickEl.style.left = `${x}px`;
    this.stickEl.style.top = `${y}px`;
    if (this.knobEl) this.knobEl.style.transform = "translate(0, 0)";
  }

  private on(
    target: EventTarget,
    type: string,
    fn: EventListener,
    opts?: AddEventListenerOptions
  ): void {
    target.addEventListener(type, fn, opts);
    this.listeners.push(() => target.removeEventListener(type, fn, opts));
  }
}

const KEY_ACTIONS: Record<string, InputAction> = {
  Space: "confirm",
  Enter: "confirm",
  Escape: "pause",
  Backspace: "cancel",
  KeyQ: "wheel",
};

function applyDeadzone(v: number, dz: number): number {
  const a = Math.abs(v);
  if (a < dz) return 0;
  return Math.sign(v) * ((a - dz) / (1 - dz));
}

function findTouch(list: TouchList, id: number | null): Touch | null {
  if (id === null) return null;
  for (let i = 0; i < list.length; i++) {
    if (list[i].identifier === id) return list[i];
  }
  return null;
}
