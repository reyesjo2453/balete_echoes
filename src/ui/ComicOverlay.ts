import { gsap } from "gsap";
import type { Engine } from "../core/Engine";
import { COMIC_ART } from "./ComicArt";

export type PanelLayout = "left-split" | "right-split" | "banner";

export interface CutsceneStep {
  speaker: string;
  text: string;
  /** Portrait image path; a lettered badge is shown if missing or unloadable. */
  portrait?: string;
  /** Comic panel image path (takes priority over `art`). */
  panelImage?: string;
  /** Built-in procedural panel art key (see ComicArt). */
  art?: keyof typeof COMIC_ART;
  /** Slanted panel layout; omit for a dialogue-only beat. */
  layout?: PanelLayout;
  /** White screen flash when the step begins. */
  flash?: boolean;
  /** Screen shake on panel impact. */
  shake?: boolean;
  /** Advance automatically this many seconds after the line finishes typing (comic cut-ins). */
  autoAdvance?: number;
  /** Fired when this step is shown (hook sound / camera effects here). */
  onShow?: () => void;
}

export interface TitleCardOptions {
  act: string;
  title: string;
  subtitle?: string;
  /** Seconds the card holds at full opacity. */
  hold?: number;
}

/** Slanted graphic-novel polygons per layout. */
const CLIP: Record<PanelLayout, string> = {
  "left-split": "polygon(0 0, 66% 0, 50% 100%, 0 100%)",
  "right-split": "polygon(34% 0, 100% 0, 100% 100%, 50% 100%)",
  banner: "polygon(0 7%, 100% 0, 100% 93%, 0 100%)",
};
const SLIDE_FROM: Record<PanelLayout, number> = { "left-split": -110, "right-split": 110, banner: -110 };
const CHARS_PER_SECOND = 38;
/** Ignore advances this soon after the previous one (touch fires several events per tap). */
const ADVANCE_DEBOUNCE_MS = 140;

/**
 * Data-driven visual-novel cutscene engine rendered over the canvas.
 * While playing, the Engine's simulation is frozen (timeDilation 0.0) and the
 * game state is "cutscene"; both are restored when the last step is dismissed.
 * Animation runs on GSAP's real-time ticker, so it is unaffected by the freeze.
 */
export class ComicOverlay {
  private steps: CutsceneStep[] = [];
  private index = -1;
  private resolve: (() => void) | null = null;
  private typing: gsap.core.Tween | null = null;
  private fullText = "";
  private textEl: HTMLElement | null = null;
  private panelEl: HTMLElement | null = null;
  private lastAdvance = 0;
  private autoTimer: gsap.core.Tween | null = null;

  private readonly stage = document.createElement("div");
  private readonly dialog = document.createElement("div");
  private readonly flashEl = document.createElement("div");
  private readonly hint = document.createElement("div");

  constructor(
    private readonly root: HTMLElement,
    private readonly engine: Engine
  ) {
    this.stage.className = "comic-stage";
    this.dialog.className = "comic-dialog";
    this.flashEl.className = "comic-flash";
    this.hint.className = "comic-hint";
    this.hint.textContent = "Space / A / Tap ▸";
    root.append(this.stage, this.dialog, this.flashEl, this.hint);
    root.addEventListener("pointerdown", () => this.advance());
  }

  get active(): boolean {
    return this.resolve !== null;
  }

  /** Play a sequence; resolves after the final step is dismissed. */
  play(steps: CutsceneStep[]): Promise<void> {
    if (this.resolve || steps.length === 0) return Promise.resolve();
    this.steps = steps;
    this.index = -1;
    this.root.classList.add("active");
    this.engine.setFrozen(true);
    this.engine.setTimeDilation(false);
    this.engine.setState("cutscene");
    return new Promise((res) => {
      this.resolve = res;
      this.next();
    });
  }

  /**
   * Bayanihan Strike presentation. Freezes the world (timeDilation 0.0), slides
   * a Dante banner with "SABAY!" across the top third, and fires `hits` bursts
   * with alternating cyan/amber flashes. `onHit(i)` runs per burst, `onFinish`
   * runs after the last one (apply damage there). Time is restored to 1.0 on exit.
   */
  executeBayanihanStrike(opts: {
    onHit: (index: number, total: number) => void;
    onFinish: () => void;
    hits?: number;
  }): Promise<void> {
    if (this.resolve) return Promise.resolve();
    const hits = opts.hits ?? 6;
    return this.engine.runFrozen(
      () =>
        new Promise<void>((done) => {
          this.root.classList.add("strike");
          const banner = document.createElement("div");
          banner.className = "strike-banner";
          const portrait = document.createElement("div");
          portrait.className = "strike-portrait";
          const badge = document.createElement("span");
          badge.textContent = "D";
          portrait.appendChild(badge);
          const img = new Image();
          img.alt = "Dante";
          img.onload = () => {
            badge.remove();
            portrait.appendChild(img);
          };
          img.src = `${import.meta.env.BASE_URL}assets/portraits/dante.png`;
          const label = document.createElement("div");
          label.className = "strike-name";
          label.textContent = "Dante";
          // Generated Dante cut-in art behind the banner (gradient shows if the file is absent).
          banner.style.backgroundImage =
            `linear-gradient(100deg, rgba(11,42,58,0.7), rgba(196,125,16,0.25)), ` +
            `url("${import.meta.env.BASE_URL}assets/comics/dante_assist.webp")`;
          banner.style.backgroundSize = "cover";
          banner.style.backgroundPosition = "center 30%";
          const sfx = document.createElement("div");
          sfx.className = "strike-sfx";
          sfx.textContent = "SABAY!";
          banner.append(portrait, label, sfx);
          this.stage.appendChild(banner);

          const tl = gsap.timeline();
          tl.fromTo(banner, { xPercent: -110 }, { xPercent: 0, duration: 0.45, ease: "back.out(1.7)" });
          tl.fromTo(sfx, { scale: 0.2, rotation: -14, opacity: 0 }, { scale: 1, rotation: -6, opacity: 1, duration: 0.3, ease: "back.out(3)" }, 0.2);
          for (let i = 0; i < hits; i++) {
            tl.call(
              () => {
                this.flashEl.style.background = i % 2 === 0 ? "#4df0ff" : "#ffb43a";
                gsap.fromTo(this.flashEl, { opacity: 0.6 }, { opacity: 0, duration: 0.14 });
                this.shake();
                gsap.fromTo(sfx, { scale: 1.25 }, { scale: 1, duration: 0.12 });
                opts.onHit(i, hits);
              },
              [],
              0.55 + i * 0.17
            );
          }
          const end = 0.55 + hits * 0.17 + 0.2;
          tl.call(() => opts.onFinish(), [], end);
          tl.to(banner, { xPercent: 110, duration: 0.3, ease: "power2.in" }, end + 0.45);
          tl.call(
            () => {
              banner.remove();
              this.flashEl.style.background = "#fff";
              this.root.classList.remove("strike");
              done();
            },
            [],
            end + 0.78
          );
        })
    );
  }

  /**
   * Full-screen ACT title card: fade in from black, hold, fade out. The world
   * stays frozen underneath, so it can bridge a cutscene into free play.
   */
  showTitleCard(opts: TitleCardOptions): Promise<void> {
    const host = this.root.parentElement ?? this.root;
    return this.engine.runFrozen(
      () =>
        new Promise<void>((done) => {
          const card = document.createElement("div");
          card.className = "act-card";
          const num = document.createElement("div");
          num.className = "act-num";
          num.textContent = opts.act.toUpperCase();
          const title = document.createElement("div");
          title.className = "act-title";
          title.textContent = opts.title;
          card.append(num, title);
          if (opts.subtitle) {
            const sub = document.createElement("div");
            sub.className = "act-sub";
            sub.textContent = opts.subtitle;
            card.appendChild(sub);
          }
          host.appendChild(card);
          const tl = gsap.timeline({
            onComplete: () => {
              card.remove();
              done();
            },
          });
          tl.to(card, { opacity: 1, duration: 0.8, ease: "power2.out" });
          tl.fromTo([num, title], { y: 14, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7, stagger: 0.25, ease: "power2.out" }, 0.3);
          if (opts.subtitle) tl.fromTo(card.querySelector(".act-sub"), { opacity: 0 }, { opacity: 0.7, duration: 0.6 }, 1.1);
          tl.to({}, { duration: opts.hold ?? 2.2 });
          tl.to(card, { opacity: 0, duration: 0.9, ease: "power2.in" });
        })
    );
  }

  /** Completes the typewriter if mid-line, otherwise moves to the next step. */
  advance(): void {
    if (!this.resolve) return;
    const now = performance.now();
    if (now - this.lastAdvance < ADVANCE_DEBOUNCE_MS) return;
    this.lastAdvance = now;
    this.autoTimer?.kill();
    this.autoTimer = null;
    if (this.typing) {
      this.typing.kill();
      this.typing = null;
      this.setText(this.fullText);
      return;
    }
    this.next();
  }

  private next(): void {
    this.autoTimer?.kill();
    this.autoTimer = null;
    this.index++;
    if (this.index >= this.steps.length) {
      this.finish();
      return;
    }
    this.showStep(this.steps[this.index]);
  }

  private showStep(step: CutsceneStep): void {
    this.showPanel(step);
    this.showDialog(step);
    if (step.flash) this.flash();
    step.onShow?.();
  }

  private showPanel(step: CutsceneStep): void {
    const old = this.panelEl;
    if (old) gsap.to(old, { opacity: 0, duration: 0.15, onComplete: () => old.remove() });
    this.panelEl = null;
    if (!step.layout) return;

    const panel = document.createElement("div");
    panel.className = "comic-panel";
    panel.style.clipPath = CLIP[step.layout];
    // Generated panel on top; procedural art underneath as the fallback if the file is missing.
    const bg = [step.panelImage ? `url("${step.panelImage}")` : "", step.art ? COMIC_ART[step.art] : ""]
      .filter(Boolean)
      .join(", ");
    if (bg) panel.style.backgroundImage = bg;
    this.stage.appendChild(panel);
    this.panelEl = panel;

    gsap.fromTo(
      panel,
      { xPercent: SLIDE_FROM[step.layout], opacity: 1 },
      {
        xPercent: 0,
        duration: 0.55,
        ease: "back.out(1.6)",
        onComplete: () => {
          if (step.shake) this.shake();
        },
      }
    );
  }

  private showDialog(step: CutsceneStep): void {
    this.dialog.replaceChildren();
    const portrait = document.createElement("div");
    portrait.className = "comic-portrait";
    const badge = document.createElement("span");
    badge.textContent = step.speaker.charAt(0).toUpperCase();
    portrait.appendChild(badge);
    if (step.portrait) {
      const img = new Image();
      img.alt = step.speaker;
      img.onload = () => {
        badge.remove();
        portrait.appendChild(img);
      };
      img.src = step.portrait; // missing file -> badge stays
    }

    const body = document.createElement("div");
    body.className = "comic-body";
    const name = document.createElement("div");
    name.className = "comic-name";
    name.textContent = step.speaker;
    const text = document.createElement("div");
    text.className = "comic-text";
    const narration = /^\*.*\*$/.test(step.text);
    text.classList.toggle("narration", narration);
    body.append(name, text);
    this.dialog.append(portrait, body);
    this.textEl = text;

    this.fullText = narration ? step.text.slice(1, -1) : step.text;
    this.setText("");
    const counter = { n: 0 };
    this.typing?.kill();
    this.typing = gsap.to(counter, {
      n: this.fullText.length,
      duration: this.fullText.length / CHARS_PER_SECOND,
      ease: "none",
      onUpdate: () => this.setText(this.fullText.slice(0, Math.floor(counter.n))),
      onComplete: () => {
        this.typing = null;
        if (step.autoAdvance !== undefined) {
          this.autoTimer = gsap.delayedCall(step.autoAdvance, () => {
            this.autoTimer = null;
            this.next();
          });
        }
      },
    });

    gsap.fromTo(this.dialog, { yPercent: 25, opacity: 0 }, { yPercent: 0, opacity: 1, duration: 0.3, ease: "power2.out" });
  }

  private setText(t: string): void {
    if (this.textEl) this.textEl.textContent = t;
  }

  private flash(): void {
    gsap.fromTo(this.flashEl, { opacity: 0.95 }, { opacity: 0, duration: 0.45, ease: "power2.out" });
  }

  /** Subtle impact shake: decaying random offsets on the whole overlay. */
  private shake(): void {
    const tl = gsap.timeline({ onComplete: () => void gsap.set(this.root, { x: 0, y: 0 }) });
    for (let i = 0; i < 6; i++) {
      const amp = 7 * (1 - i / 6);
      tl.to(this.root, { x: (Math.random() - 0.5) * 2 * amp, y: (Math.random() - 0.5) * 2 * amp, duration: 0.04 });
    }
  }

  private finish(): void {
    this.autoTimer?.kill();
    this.autoTimer = null;
    this.typing?.kill();
    this.typing = null;
    this.root.classList.remove("active");
    this.panelEl?.remove();
    this.panelEl = null;
    this.dialog.replaceChildren();
    gsap.set(this.root, { x: 0, y: 0 });
    this.index = -1;
    this.engine.setFrozen(false);
    this.engine.setState("explore");
    const done = this.resolve;
    this.resolve = null;
    done?.();
  }
}
