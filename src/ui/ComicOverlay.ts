import { gsap } from "gsap";

export interface ComicPanel {
  /** Image under /assets/comics (optional for text-only beats). */
  image?: string;
  caption?: string;
  /** Panel rect in viewport percentages. */
  rect: { x: number; y: number; w: number; h: number };
  /** Horizontal slant of the left/right edges in percent of panel width. */
  slant?: number;
  /** Direction the panel slides in from. */
  from?: "left" | "right" | "top" | "bottom";
}

export interface ComicPage {
  panels: ComicPanel[];
}

/**
 * DOM-based slanted graphic-novel cutscene manager. Pages of clip-path
 * panels animate in with GSAP; confirm/tap advances, the promise resolves
 * when the final page is dismissed.
 */
export class ComicOverlay {
  private pages: ComicPage[] = [];
  private index = -1;
  private resolve: (() => void) | null = null;
  private busy = false;

  constructor(private readonly root: HTMLElement) {
    root.addEventListener("pointerdown", () => this.advance());
  }

  get active(): boolean {
    return this.index >= 0;
  }

  play(pages: ComicPage[]): Promise<void> {
    this.pages = pages;
    this.index = -1;
    this.root.classList.add("active");
    return new Promise((res) => {
      this.resolve = res;
      void this.advance();
    });
  }

  async advance(): Promise<void> {
    if (this.busy || !this.resolve) return;
    this.busy = true;
    await this.clearPage();
    this.index++;
    if (this.index >= this.pages.length) {
      this.finish();
    } else {
      this.showPage(this.pages[this.index]);
    }
    this.busy = false;
  }

  private showPage(page: ComicPage): void {
    const tl = gsap.timeline();
    page.panels.forEach((p, i) => {
      const panel = document.createElement("div");
      panel.className = "comic-panel";
      const { x, y, w, h } = p.rect;
      Object.assign(panel.style, { left: `${x}%`, top: `${y}%`, width: `${w}%`, height: `${h}%` });
      const s = p.slant ?? 6;
      panel.style.clipPath = `polygon(${s}% 0, 100% 0, ${100 - s}% 100%, 0 100%)`;
      if (p.image) panel.style.backgroundImage = `url("${p.image}")`;
      if (p.caption) {
        const cap = document.createElement("div");
        cap.className = "comic-caption";
        cap.textContent = p.caption;
        panel.appendChild(cap);
      }
      this.root.appendChild(panel);

      const from = p.from ?? (i % 2 === 0 ? "left" : "right");
      const offset = { left: { xPercent: -40 }, right: { xPercent: 40 }, top: { yPercent: -40 }, bottom: { yPercent: 40 } }[from];
      tl.from(panel, { ...offset, opacity: 0, duration: 0.45, ease: "power3.out" }, i * 0.18);
    });
    const hint = document.createElement("div");
    hint.className = "comic-hint";
    hint.textContent = "Tap / Space ▸";
    this.root.appendChild(hint);
    tl.from(hint, { opacity: 0, duration: 0.3 });
  }

  private clearPage(): Promise<void> {
    const children = Array.from(this.root.children);
    if (children.length === 0) return Promise.resolve();
    return new Promise((res) => {
      gsap.to(children, {
        opacity: 0,
        duration: 0.2,
        stagger: 0.03,
        onComplete: () => {
          children.forEach((c) => c.remove());
          res();
        },
      });
    });
  }

  private finish(): void {
    this.root.classList.remove("active");
    this.index = -1;
    const done = this.resolve;
    this.resolve = null;
    done?.();
  }
}
