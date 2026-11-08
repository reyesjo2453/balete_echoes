import * as THREE from "three";

const GAMEPAD_DEADZONE = 0.15;
const TOUCH_STICK_RADIUS = 50; // px, max drag distance

/**
 * attack  = A/Cross, Space/Enter, touch Attack button
 * dodge   = B/Circle, Shift, touch Dodge button
 * command = X/Square or L1, Q, touch Command button (hold = tactical time dilation)
 * confirm/cancel are UI aliases fired together with attack/dodge.
 */
export type InputAction = "confirm" | "cancel" | "attack" | "dodge" | "command" | "pause";

const ALIASES: Partial<Record<InputAction, InputAction>> = { attack: "confirm", dodge: "cancel" };
const TOUCH_BUTTONS: Array<{ action: InputAction; label: string }> = [
  { action: "command", label: "Cmd" },
  { action: "dodge", label: "Dodge" },
  { action: "attack", label: "Atk" },
];
// Standard mapping: 0 = A/Cross, 1 = B/Circle, 2 = X/Square, 4 = L1, 9 = Start
const PAD_BUTTONS: Array<[number, InputAction]> = [
  [0, "attack"],
  [1, "dodge"],
  [2, "command"],
  [4, "command"],
  [9, "pause"],
];

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
  private readonly padHeld = new Set<InputAction>();
  private readonly touchHeld = new Set<InputAction>();
  private readonly touchVec = new THREE.Vector2();
  private touchId: number | null = null;
  private touchOrigin = { x: 0, y: 0 };
  private stickEl: HTMLDivElement | null = null;
  private knobEl: HTMLDivElement | null = null;
  private prevPadButtons: boolean[] = [];
  private padActive = false;
  private controlsEl: HTMLDivElement | null = null;
  private readonly listeners: Array<() => void> = [];

  constructor(surface: HTMLElement) {
    this.on(window, "keydown", (e) => this.onKeyDown(e as KeyboardEvent));
    this.on(window, "keyup", (e) => this.keys.delete((e as KeyboardEvent).code));
    this.on(window, "blur", () => this.keys.clear());
    this.on(window, "gamepadconnected", () => this.setPadActive(this.firstGamepad() !== null));
    this.on(window, "gamepaddisconnected", () => this.setPadActive(this.firstGamepad() !== null));

    // Block pinch-zoom, double-tap zoom and browser scrolling / rubber-banding.
    const block = (e: Event) => e.preventDefault();
    this.on(document, "gesturestart", block, { passive: false });
    this.on(document, "gesturechange", block, { passive: false });
    this.on(document, "contextmenu", block);
    this.on(document, "touchmove", (e) => {
      if ((e as TouchEvent).touches.length > 1 || e.cancelable) e.preventDefault();
    }, { passive: false });
    this.on(window, "wheel", (e) => {
      if ((e as WheelEvent).ctrlKey) e.preventDefault();
    }, { passive: false });

    this.buildTouchControls(surface);
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
    this.setPadActive(pad !== null);
    if (pad) {
      const ax = applyDeadzone(pad.axes[0] ?? 0, GAMEPAD_DEADZONE);
      const ay = applyDeadzone(pad.axes[1] ?? 0, GAMEPAD_DEADZONE);
      x += ax;
      y -= ay; // stick up is negative
      this.pollPadButtons(pad);
    } else if (this.prevPadButtons.length) {
      this.prevPadButtons = [];
      this.padHeld.clear();
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
    return this.padHeld.has(action) || this.touchHeld.has(action) || this.keyHeld(action);
  }

  /** Clear edge-triggered actions at the end of the frame. */
  endFrame(): void {
    this.pressed.clear();
  }

  dispose(): void {
    this.listeners.forEach((off) => off());
    this.listeners.length = 0;
    this.stickEl?.remove();
    this.controlsEl?.remove();
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
    this.padHeld.clear();
    for (const [index, action] of PAD_BUTTONS) {
      const down = pad.buttons[index]?.pressed ?? false;
      if (down) this.padHeld.add(action);
      // Edge-trigger once per physical button (not per mapped action).
      if (down && !this.prevPadButtons[index]) this.press(action);
    }
    for (const [index] of PAD_BUTTONS) this.prevPadButtons[index] = pad.buttons[index]?.pressed ?? false;
  }

  /** Queue an edge-triggered action along with its UI alias (confirm/cancel). */
  private press(action: InputAction): void {
    this.pressed.add(action);
    const alias = ALIASES[action];
    if (alias) this.pressed.add(alias);
  }

  private keyHeld(action: InputAction): boolean {
    for (const [code, a] of Object.entries(KEY_ACTIONS)) {
      if (a === action && this.keys.has(code)) return true;
    }
    return false;
  }

  /** Auto-hide the virtual touch overlay while a physical gamepad is connected. */
  private setPadActive(active: boolean): void {
    if (active === this.padActive) return;
    this.padActive = active;
    this.controlsEl?.classList.toggle("pad-active", active);
    if (this.stickEl && active) this.stickEl.hidden = true;
    if (active) {
      this.touchId = null;
      this.touchVec.set(0, 0);
      this.touchHeld.clear();
    }
  }

  private buildTouchControls(surface: HTMLElement): void {
    const root = document.createElement("div");
    root.className = "touch-controls";
    for (const { action, label } of TOUCH_BUTTONS) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = `touch-btn touch-btn-${action}`;
      btn.textContent = label;
      btn.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        btn.setPointerCapture(e.pointerId);
        btn.classList.add("down");
        this.touchHeld.add(action);
        this.press(action);
      });
      const release = () => {
        btn.classList.remove("down");
        this.touchHeld.delete(action);
      };
      btn.addEventListener("pointerup", release);
      btn.addEventListener("pointercancel", release);
      btn.addEventListener("lostpointercapture", release);
      root.appendChild(btn);
    }
    surface.appendChild(root);
    this.controlsEl = root;
    this.listeners.push(() => root.remove());
  }

  private onKeyDown(e: KeyboardEvent): void {
    if (!e.repeat) {
      const action = KEY_ACTIONS[e.code];
      if (action) this.press(action);
    }
    this.keys.add(e.code);
  }

  private onTouchStart(e: TouchEvent): void {
    this.controlsEl?.classList.add("touch-seen");
    const t = e.changedTouches[0];
    // Touches on the on-screen buttons are handled by their pointer events.
    if ((e.target as Element | null)?.closest(".touch-btn")) return;
    if (this.touchId !== null) return;
    // Left half of the screen drives movement; right-half taps only confirm
    // (comic advance etc.) — Attack lives on its own button.
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
  Space: "attack",
  Enter: "attack",
  Escape: "pause",
  Backspace: "cancel",
  ShiftLeft: "dodge",
  KeyQ: "command",
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
