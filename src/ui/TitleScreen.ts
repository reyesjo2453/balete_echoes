import { gsap } from "gsap";

/**
 * Title card (brass and rust, Baybayin glyph line) shown before gameplay. Any key, gamepad button or tap
 * fires `onStart` exactly once (a valid user gesture, so callers can unlock
 * the AudioContext there), then the card fades out.
 */
export class TitleScreen {
  private readonly el = document.createElement("div");
  private started = false;
  private prevPad = false;
  private readonly cleanup: Array<() => void> = [];
  /** Called once on the first input; return when it is safe to fade the card. */
  onStart: (() => void) | null = null;

  constructor(parent: HTMLElement) {
    this.el.className = "title-screen";
    this.el.innerHTML = `
      <div class="title-card">
        <div class="title-glyph" aria-hidden="true">ᜊᜎᜒᜆᜒ</div>
        <div class="title-main">BALETE</div>
        <div class="title-sub">Echoes of the Sunken Veil</div>
        <div class="title-act">Act I: Quiapo Underground</div>
      </div>
      <div class="title-prompt">Press Any Button or Tap to Start</div>`;
    parent.appendChild(this.el);
    document.body.classList.add("in-title");

    const start = () => this.start();
    const add = (target: EventTarget, type: string, fn: EventListener) => {
      target.addEventListener(type, fn);
      this.cleanup.push(() => target.removeEventListener(type, fn));
    };
    add(window, "keydown", (e) => {
      if (!(e as KeyboardEvent).repeat) start();
    });
    add(this.el, "pointerdown", start);
    // Keep the touch stick from spawning under the title card.
    this.el.addEventListener("touchstart", (e) => e.stopPropagation(), { passive: true });
  }

  get active(): boolean {
    return !this.started;
  }

  /** Poll gamepads (no event exists for button presses); call each frame while active. */
  poll(): void {
    if (this.started || typeof navigator.getGamepads !== "function") return;
    let down = false;
    for (const pad of navigator.getGamepads()) {
      if (pad?.connected && pad.buttons.some((b) => b.pressed)) down = true;
    }
    if (down && !this.prevPad) this.start();
    this.prevPad = down;
  }

  private start(): void {
    if (this.started) return;
    this.started = true;
    this.cleanup.forEach((off) => off());
    this.el.classList.add("leaving");
    this.onStart?.();
    gsap.to(this.el, {
      opacity: 0,
      duration: 1.0,
      delay: 0.15,
      ease: "power2.inOut",
      onComplete: () => {
        this.el.remove();
        document.body.classList.remove("in-title");
      },
    });
  }
}
