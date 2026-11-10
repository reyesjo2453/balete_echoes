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
    const ticks = Array.from(
      { length: 36 },
      (_, i) => `<line x1="200" y1="6" x2="200" y2="${i % 3 === 0 ? 22 : 14}" transform="rotate(${i * 10} 200 200)"/>`,
    ).join("");
    this.el.innerHTML = `
      <div class="title-stage">
        <div class="title-glow" aria-hidden="true"></div>
        <svg class="title-seal seal-outer" viewBox="0 0 400 400" aria-hidden="true">
          <circle cx="200" cy="200" r="196" class="gold"/><circle cx="200" cy="200" r="186" class="teal"/>
          <g class="gold">${ticks}</g>
          <path class="teal" d="M200 40 L214 186 L360 200 L214 214 L200 360 L186 214 L40 200 L186 186 Z"/>
        </svg>
        <svg class="title-seal seal-inner" viewBox="0 0 400 400" aria-hidden="true">
          <circle cx="200" cy="200" r="150" class="teal dashed"/><circle cx="200" cy="200" r="138" class="gold"/>
        </svg>
        <div class="title-card">
          <div class="title-glyph" aria-hidden="true">ᜊᜎᜒᜆᜒ</div>
          <div class="title-main">BALETE</div>
          <div class="title-rule" aria-hidden="true"><i></i><b></b><i></i></div>
          <div class="title-sub">Echoes of the Sunken Veil</div>
          <div class="title-act">Act I: Quiapo Underground</div>
        </div>
      </div>
      <button type="button" class="title-start"><span>Start</span></button>
      <div class="title-prompt">Press Any Button or Tap to Start</div>
      <div class="title-credits">
        <div>'Aphelion' by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au</div>
        <div>'Undertow' by Scott Buckley — released under CC-BY 4.0. www.scottbuckley.com.au</div>
      </div>`;
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
    add(this.el, "click", start);
    add(this.el, "touchend", start);
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
