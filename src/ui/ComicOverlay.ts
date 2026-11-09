import { gsap } from "gsap";
import type { Engine } from "../core/Engine";
import { COMIC_ART } from "./ComicArt";
import { placeholder, resolveReal } from "../assets/ArtRegistry";

export type PanelLayout = "left-split" | "right-split" | "banner";

/** A decision with a countdown: if it runs out, `defaultIndex` is chosen for the player. */
export interface TimedChoice {
  options: string[];
  /** Seconds before the default is taken. */
  seconds: number;
  defaultIndex: number;
  /** Called once with the picked index; `expired` is true when the clock chose it. */
  onResolve: (index: number, expired: boolean) => void;
}

/** A quick-time beat: press confirm / tap inside the window or the scene plays out worse. */
export interface QteBeat {
  prompt: string;
  /** Seconds the player has to hit it. */
  seconds: number;
  /** Called once; `success` is false on a miss. */
  onResult: (success: boolean) => void;
}

/**
 * Panel-motion language. Motion lives in the arrival or a single earned beat, never a loop:
 *  - pushIn: slow zoom on the art while dialogue lands (no shake).
 *  - tilt:   panel leans a couple of degrees as it "speeds"; levels when the next panel arrives.
 *  - impact: one sharp jolt after the snap entrance, then dead still. Always fires `onImpact`.
 */
export type PanelMotion = "pushIn" | "tilt" | "impact";
export type ImpactStrength = "small" | "full";

export interface CutsceneStep {
  speaker: string;
  text: string;
  /** Portrait: an art-manifest id ("portrait_renzo") or an image path. A lettered badge shows until a real image loads. */
  portrait?: string;
  /** Art-manifest id for this step's comic panel (see src/assets/artManifest.ts). Placeholder until the file exists. */
  panel?: string;
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
  /** Onomatopoeia stamped over the panel as it lands (e.g. "KRAAASH!"). */
  sfx?: string;
  /** Advance automatically this many seconds after the line finishes typing (comic cut-ins). */
  autoAdvance?: number;
  /** Motion for this panel (entrance becomes a no-overshoot snap). */
  motion?: PanelMotion;
  /** Fired the instant an `impact` panel jolts: pair the SFX here (a shake without a sound feels broken). */
  onImpact?: (strength: ImpactStrength) => void;
  /** Timed choice shown over this step; the cutscene waits for it to resolve. */
  choice?: TimedChoice;
  /** Quick-time beat shown over this step; the cutscene waits for it to resolve. */
  qte?: QteBeat;
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

/**
 * Slanted graphic-novel polygons per layout. `banner` is the GDD 7 panel mask verbatim; the two
 * split layouts are half-screen variants of the same slanted-edge language.
 */
const CLIP: Record<PanelLayout, string> = {
  "left-split": "polygon(0 0, 66% 0, 50% 100%, 0 100%)",
  "right-split": "polygon(34% 0, 100% 0, 100% 100%, 50% 100%)",
  banner: "polygon(0 0, 100% 4%, 96% 100%, 0% 96%)",
};
const SLIDE_FROM: Record<PanelLayout, number> = { "left-split": -110, "right-split": 110, banner: -110 };
const CHARS_PER_SECOND = 38;
/** Ignore advances this soon after the previous one (touch fires several events per tap). */
const ADVANCE_DEBOUNCE_MS = 140;
/** A QTE ignores presses this soon after it appears, so a mashed dialogue advance cannot pass it. */
const QTE_ARM_MS = 200;

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
  private sfxEl: HTMLElement | null = null;
  private lastAdvance = 0;
  private autoTimer: gsap.core.Tween | null = null;
  private panelTl: gsap.core.Timeline | null = null;
  /** The interactive beat (timed choice or QTE) currently blocking the cutscene, if any. */
  private pending: {
    kind: "choice" | "qte";
    el: HTMLElement;
    tween: gsap.core.Tween;
    armedAt: number;
    settle: (picked?: number) => void;
  } | null = null;

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
    // Number keys pick timed-choice options.
    window.addEventListener("keydown", (e) => {
      if (this.pending?.kind !== "choice" || e.repeat) return;
      const n = Number(e.key);
      if (n >= 1 && n <= 9) this.pending.settle(n - 1);
    });
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
   * with alternating rust/amber flashes. `onHit(i)` runs per burst, `onFinish`
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
          void resolveReal("portrait_dante").then((url) => {
            if (url) img.src = url;
          });
          const label = document.createElement("div");
          label.className = "strike-name";
          label.textContent = "Dante";
          // Generated Dante cut-in art behind the banner (gradient shows if the file is absent).
          banner.style.backgroundImage =
            `linear-gradient(100deg, rgba(11,42,58,0.7), rgba(196,125,16,0.25)), ` +
            `url("${import.meta.env.BASE_URL}assets/comics/dante_panel1_wheel.jpg")`;
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
                this.flashEl.style.background = i % 2 === 0 ? "#c8452e" : "#ffb43a";
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
    if (this.pending) {
      // A QTE is answered by the confirm press itself; a choice ignores advances (must pick or expire).
      if (this.pending.kind === "qte" && performance.now() - this.pending.armedAt > QTE_ARM_MS) {
        this.pending.settle(1); // any value: a press is a hit
      }
      return;
    }
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
    if (step.choice) this.startChoice(step.choice);
    if (step.qte) this.startQte(step.qte);
  }

  /** Timed choice: option buttons with a draining bar; expiry resolves to the default. */
  private startChoice(choice: TimedChoice): void {
    const el = document.createElement("div");
    el.className = "comic-choice";
    const bar = document.createElement("div");
    bar.className = "comic-choice-bar";
    const fill = document.createElement("i");
    bar.appendChild(fill);
    el.appendChild(bar);
    const settle = (picked?: number) => {
      if (this.pending?.el !== el) return;
      const expired = picked === undefined;
      const index = picked ?? choice.defaultIndex;
      this.clearPending();
      choice.onResolve(index, expired);
      this.next();
    };
    choice.options.forEach((label, i) => {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = `${i + 1}. ${label}`;
      b.classList.toggle("default", i === choice.defaultIndex);
      b.addEventListener("pointerdown", (e) => e.stopPropagation());
      b.addEventListener("click", () => settle(i));
      el.insertBefore(b, bar);
    });
    this.root.appendChild(el);
    const state = { k: 1 };
    const tween = gsap.to(state, {
      k: 0,
      duration: choice.seconds,
      ease: "none",
      onUpdate: () => {
        fill.style.transform = `scaleX(${state.k})`;
      },
      onComplete: () => settle(),
    });
    this.pending = { kind: "choice", el, tween, armedAt: performance.now(), settle };
  }

  /** QTE: a shrinking ring and prompt; confirm / tap in time = success, otherwise a miss. */
  private startQte(qte: QteBeat): void {
    const el = document.createElement("div");
    el.className = "comic-qte";
    const ring = document.createElement("div");
    ring.className = "qte-ring";
    const prompt = document.createElement("div");
    prompt.className = "qte-prompt";
    prompt.textContent = qte.prompt;
    el.append(ring, prompt);
    this.root.appendChild(el);
    const settle = (picked?: number) => {
      if (this.pending?.el !== el) return;
      const hit = picked !== undefined; // the expiry tween calls with no argument
      this.clearPending();
      this.flashEl.style.background = hit ? "#ffb43a" : "#c8452e";
      gsap.fromTo(this.flashEl, { opacity: 0.5 }, { opacity: 0, duration: 0.3 });
      if (!hit) this.shake();
      qte.onResult(hit);
      this.next();
    };
    const state = { k: 1 };
    const tween = gsap.to(state, {
      k: 0,
      duration: qte.seconds,
      ease: "none",
      onUpdate: () => {
        ring.style.transform = `scale(${0.25 + state.k * 0.75})`;
      },
      onComplete: () => settle(),
    });
    this.pending = { kind: "qte", el, tween, armedAt: performance.now(), settle };
  }

  private clearPending(): void {
    if (!this.pending) return;
    this.pending.tween.kill();
    this.pending.el.remove();
    this.pending = null;
  }

  private showPanel(step: CutsceneStep): void {
    const old = this.panelEl;
    this.panelTl?.kill();
    this.panelTl = null;
    if (old) {
      // A tilted panel levels out as the next one lands.
      gsap.killTweensOf(old);
      gsap.to(old, { rotation: 0, x: 0, y: 0, opacity: 0, duration: 0.15, onComplete: () => old.remove() });
    }
    this.panelEl = null;
    this.clearSfx();
    if (!step.layout) return;

    const panel = document.createElement("div");
    panel.className = "comic-panel";
    panel.style.clipPath = CLIP[step.layout];
    // Art lives in a child so a push-in scales the picture inside the panel frame, not the frame.
    const art = document.createElement("div");
    art.className = "comic-panel-art";
    // Generated panel on top; procedural art underneath as the fallback if the file is missing.
    const bg = [step.panelImage ? `url("${step.panelImage}")` : "", step.art ? COMIC_ART[step.art] : ""]
      .filter(Boolean)
      .join(", ");
    if (bg) art.style.backgroundImage = bg;
    if (step.panel) {
      // Placeholder now; the real file swaps in as soon as it is found on disk (plug and play).
      const id = step.panel;
      art.style.backgroundImage = `url("${placeholder(id)}")`;
      void resolveReal(id).then((url) => {
        if (url) art.style.backgroundImage = `url("${url}")`;
      });
    }
    panel.appendChild(art);
    this.stage.appendChild(panel);
    this.panelEl = panel;

    const land = (): void => {
      if (step.sfx) this.stampSfx(step.sfx, step.layout);
      if (step.motion === "impact") {
        this.impactShake("full");
        step.onImpact?.("full");
      } else if (step.shake) {
        this.shake();
      }
    };
    const tl = gsap.timeline();
    this.panelTl = tl;
    if (step.motion) {
      // Snap entrance: fast slide, hard stop, no overshoot wobble.
      tl.fromTo(panel, { xPercent: SLIDE_FROM[step.layout], opacity: 1, rotation: 0 }, { xPercent: 0, duration: 0.32, ease: "expo.out" });
      tl.call(land);
      if (step.motion === "pushIn") {
        tl.fromTo(art, { scale: 1 }, { scale: 1.1, duration: 8, ease: "none" }, ">");
      } else if (step.motion === "tilt") {
        tl.fromTo(panel, { rotation: 0 }, { rotation: -2.5, duration: 1.4, ease: "power1.in" }, ">-0.1");
      }
    } else {
      tl.fromTo(panel, { xPercent: SLIDE_FROM[step.layout], opacity: 1 }, { xPercent: 0, duration: 0.55, ease: "back.out(1.6)" });
      tl.call(land);
    }
  }

  /**
   * One sharp jolt on the current panel, then dead still. "full" is the KRASH hit; "small" is the
   * dull-thud miss for the QTE (Issue #22). Callers pair it with the matching SFX.
   */
  impactShake(strength: ImpactStrength = "full"): void {
    const panel = this.panelEl;
    if (!panel) return;
    const amp = strength === "full" ? 18 : 6;
    const hops = strength === "full" ? 5 : 3;
    gsap.killTweensOf(panel, "x,y");
    const tl = gsap.timeline({ onComplete: () => void gsap.set(panel, { x: 0, y: 0 }) });
    for (let i = 0; i < hops; i++) {
      const k = 1 - i / hops;
      const sign = i % 2 === 0 ? 1 : -1;
      tl.to(panel, { x: sign * amp * k, y: -sign * amp * 0.5 * k, duration: 0.035, ease: "power2.out" });
    }
    tl.to(panel, { x: 0, y: 0, duration: 0.05 });
    if (strength === "full") gsap.fromTo(this.flashEl, { opacity: 0.55 }, { opacity: 0, duration: 0.25, ease: "power2.out" });
  }

  /** Onomatopoeia pop (easeOutBack) that lives and dies with the current panel. */
  private stampSfx(text: string, layout: PanelLayout | undefined): void {
    const panel = this.panelEl;
    if (!panel) return;
    const el = document.createElement("div");
    el.className = "comic-sfx";
    el.textContent = text;
    el.dataset.layout = layout ?? "banner";
    this.stage.appendChild(el);
    gsap.fromTo(
      el,
      { scale: 0.2, rotation: -16, opacity: 0 },
      { scale: 1, rotation: -7, opacity: 1, duration: 0.32, ease: "back.out(3)" }
    );
    // Fades out with the panel: removed when the next step replaces it.
    this.sfxEl?.remove();
    this.sfxEl = el;
  }

  private showDialog(step: CutsceneStep): void {
    this.dialog.replaceChildren();
    const portrait = document.createElement("div");
    portrait.className = "comic-portrait";
    const badge = document.createElement("span");
    badge.textContent = step.speaker.charAt(0).toUpperCase();
    portrait.appendChild(badge);
    if (step.portrait) {
      const show = (src: string): void => {
        const img = new Image();
        img.alt = step.speaker;
        img.onload = () => {
          badge.remove();
          portrait.appendChild(img);
        };
        img.src = src; // missing file -> badge stays
      };
      if (step.portrait.includes("/")) show(step.portrait);
      else void resolveReal(step.portrait).then((url) => url && show(url));
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

  private clearSfx(): void {
    if (!this.sfxEl) return;
    gsap.killTweensOf(this.sfxEl);
    this.sfxEl.remove();
    this.sfxEl = null;
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
    this.clearPending();
    this.autoTimer?.kill();
    this.autoTimer = null;
    this.typing?.kill();
    this.typing = null;
    this.root.classList.remove("active");
    this.panelTl?.kill();
    this.panelTl = null;
    if (this.panelEl) gsap.killTweensOf(this.panelEl);
    this.panelEl?.remove();
    this.panelEl = null;
    this.clearSfx();
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
