export interface DemoStats {
  /** Seconds of play since the demo (re)started. */
  timeElapsed: number;
  /** Most hits landed during a single stagger break. */
  maxStaggerCombo: number;
  gitingStrikes: number;
  /** Card heading; defaults to the vertical-slice title. */
  title?: string;
  /** Extra label/value rows (episode ledger readout). */
  extras?: Array<[string, string]>;
}

/** "VERTICAL SLICE COMPLETE" card with Restart / Free Roam choices. */
export class DemoSummary {
  private readonly el = document.createElement("div");
  private readonly buttons: HTMLButtonElement[] = [];
  private selected = 0;
  onRestart: (() => void) | null = null;
  onFreeRoam: (() => void) | null = null;

  constructor(parent: HTMLElement) {
    this.el.className = "demo-summary";
    parent.appendChild(this.el);
  }

  get open(): boolean {
    return this.el.classList.contains("open");
  }

  show(stats: DemoStats): void {
    this.el.replaceChildren();
    const card = document.createElement("div");
    card.className = "demo-card";
    const title = document.createElement("div");
    title.className = "demo-title";
    title.textContent = stats.title ?? "VERTICAL SLICE COMPLETE";
    card.appendChild(title);

    const rows: Array<[string, string]> = [
      ["Time Elapsed", formatTime(stats.timeElapsed)],
      ["Max Stagger Combo", `${stats.maxStaggerCombo} hit${stats.maxStaggerCombo === 1 ? "" : "s"}`],
      ["Giting Strikes Executed", String(stats.gitingStrikes)],
      ...(stats.extras ?? []),
    ];
    for (const [label, value] of rows) {
      const row = document.createElement("div");
      row.className = "demo-row";
      const l = document.createElement("span");
      l.textContent = label;
      const v = document.createElement("b");
      v.textContent = value;
      row.append(l, v);
      card.appendChild(row);
    }

    const actions = document.createElement("div");
    actions.className = "demo-actions";
    this.buttons.length = 0;
    const make = (label: string, fn: () => void) => {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = label;
      b.addEventListener("click", () => {
        this.hide();
        fn();
      });
      actions.appendChild(b);
      this.buttons.push(b);
    };
    make("[Restart Demo]", () => this.onRestart?.());
    make("[Free Roam]", () => this.onFreeRoam?.());
    card.appendChild(actions);
    this.el.appendChild(card);
    this.select(1);
    this.el.classList.add("open");
  }

  hide(): void {
    this.el.classList.remove("open");
  }

  /** Move the highlight with left/right (-1 / 1). */
  move(dir: number): void {
    this.select(Math.min(this.buttons.length - 1, Math.max(0, this.selected + dir)));
  }

  /** Activate the highlighted button (keyboard / gamepad confirm). */
  confirm(): void {
    this.buttons[this.selected]?.click();
  }

  private select(i: number): void {
    this.selected = i;
    this.buttons.forEach((b, j) => b.classList.toggle("selected", i === j));
  }
}

function formatTime(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}
