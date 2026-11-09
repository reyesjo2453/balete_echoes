import * as THREE from "three";

const GAMEPAD_DEADZONE = 0.15;
const TOUCH_STICK_RADIUS = 50; // px, max drag distance
/** A key tap counts as held for at least this long so it can't fall between frames. */
const TAP_LATCH_MS = 120;

/**
 * attack  = A/Cross, Space/Enter, touch Attack button
 * dodge   = B/Circle, Shift, touch Dodge button
 * command = X/Square or L1, Q, touch Command button (hold = tactical time dilation)
 * confirm/cancel are UI aliases fired together with attack/dodge.
 */
export type InputAction = "confirm" | "cancel" | "attack" | "dodge" | "command" | "pause" | "bayanihan";

const ALIASES: Partial<Record<InputAction, InputAction>> = { attack: "confirm", dodge: "cancel" };
const ICON = (name: string): string => `${import.meta.env.BASE_URL}assets/ui/command-wheel/${name}`;
/** Simple drawn evade glyph (three speed chevrons); no dodge art exists yet. */
const DODGE_GLYPH_SVG =
  '<svg viewBox="0 0 48 48" aria-hidden="true" focusable="false"><path d="M8 12l12 12-12 12M20 12l12 12-12 12M32 12l12 12-12 12" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const TOUCH_BUTTONS: Array<{ action: InputAction; label: string; iconUrl?: string; glyph?: string }> = [
  { action: "command", label: "Cmd", iconUrl: ICON("command-wheel-dial.png") },
  { action: "dodge", label: "Dodge", glyph: DODGE_GLYPH_SVG },
  { action: "attack", label: "Atk", iconUrl: ICON("icon-strike.png") },
];
// Standard mapping: 0 = A/Cross, 1 = B/Circle, 2 = X/Square, 4 = L1, 9 = Start
const PAD_BUTTONS: Array<[number, InputAction]> = [
  [0, "attack"],
  [1, "dodge"],
  [2, "command"],
  [4, "command"],
  [5, "bayanihan"], // R1
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
  /** Key code -> time (ms) until which it counts as held, even if already released. */
  private readonly latched = new Map<string, number>();
  private mouseDrag = false;
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
    this.on(window, "blur", () => {
      this.keys.clear();
      this.latched.clear();
    });
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

    // Mouse drag drives the same floating stick (desktop / emulated devices).
    this.on(surface, "pointerdown", (e) => this.onMouseDown(e as PointerEvent));
    this.on(window, "pointermove", (e) => this.onMouseMove(e as PointerEvent));
    this.on(window, "pointerup", (e) => this.onMouseUp(e as PointerEvent));
    this.on(window, "pointercancel", (e) => this.onMouseUp(e as PointerEvent));
  }

  /** Poll devices. Call once per frame before game logic. */
  update(): void {
    let x = 0;
    let y = 0;

    // Keyboard (key down, or tapped within the latch window)
    const now = performance.now();
    const down = (code: string) => this.keys.has(code) || (this.latched.get(code) ?? 0) > now;
    if (down("KeyA") || down("ArrowLeft")) x -= 1;
    if (down("KeyD") || down("ArrowRight")) x += 1;
    if (down("KeyW") || down("ArrowUp")) y += 1;
    if (down("KeyS") || down("ArrowDown")) y -= 1;

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
    for (const { action, label, iconUrl, glyph } of TOUCH_BUTTONS) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = `touch-btn touch-btn-${action}`;
      btn.setAttribute("aria-label", label);
      btn.title = label;
      if (iconUrl) {
        const img = document.createElement("img");
        img.className = "touch-btn-icon";
        img.src = iconUrl;
        img.alt = "";
        img.draggable = false;
        btn.appendChild(img);
      } else if (glyph) {
        btn.insertAdjacentHTML("beforeend", glyph);
      } else {
        btn.textContent = label;
      }
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
      // Q doubles as Command (hold) and Bayanihan (tap when Giting is full); the game decides.
      if (e.code === "KeyQ" || e.code === "KeyR") this.pressed.add("bayanihan");
    }
    this.keys.add(e.code);
    this.latched.set(e.code, performance.now() + TAP_LATCH_MS);
  }

  private onMouseDown(e: PointerEvent): void {
    if (e.pointerType !== "mouse" || e.button !== 0 || this.padActive) return;
    if ((e.target as Element | null)?.closest(".touch-btn, .title-screen, .hud-modal, .hud-bayanihan")) return;
    this.mouseDrag = true;
    this.touchOrigin = { x: e.clientX, y: e.clientY };
    this.showStick(e.clientX, e.clientY);
  }

  private onMouseMove(e: PointerEvent): void {
    if (!this.mouseDrag || e.pointerType !== "mouse") return;
    this.dragTo(e.clientX, e.clientY);
  }

  private onMouseUp(e: PointerEvent): void {
    if (!this.mouseDrag || e.pointerType !== "mouse") return;
    this.mouseDrag = false;
    this.touchVec.set(0, 0);
    if (this.stickEl) this.stickEl.hidden = true;
  }

  private dragTo(cx: number, cy: number): void {
    let dx = cx - this.touchOrigin.x;
    let dy = cy - this.touchOrigin.y;
    const len = Math.hypot(dx, dy);
    if (len > TOUCH_STICK_RADIUS) {
      dx = (dx / len) * TOUCH_STICK_RADIUS;
      dy = (dy / len) * TOUCH_STICK_RADIUS;
    }
    this.touchVec.set(dx / TOUCH_STICK_RADIUS, -dy / TOUCH_STICK_RADIUS);
    if (this.knobEl) this.knobEl.style.transform = `translate(${dx}px, ${dy}px)`;
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
    this.dragTo(t.clientX, t.clientY);
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
