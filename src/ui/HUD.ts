import type { CombatUnit } from "../combat/CombatEngine";

export interface HudUnit {
  id: string;
  name: string;
  hp: number;
  maxHp: number;
  unit?: CombatUnit;
}

export const REFLEX_COMMANDS = [
  { id: "strike", label: "Strike" },
  { id: "agimat", label: "Agimat (Apoy Blade)" },
  { id: "guard", label: "Guard" },
  { id: "item", label: "Kagamitan (Lunas)" },
] as const;
export type ReflexCommand = (typeof REFLEX_COMMANDS)[number];

interface UnitEls {
  hp: HTMLElement;
  atb: HTMLElement;
}

/**
 * DOM HUD: party HP + ATB bars and a radial reflex command wheel.
 * Writes only transforms/classes per frame to avoid layout thrash.
 */
export class HUD {
  private readonly party: HTMLElement;
  private readonly wheel: HTMLElement;
  private readonly debug: HTMLElement;
  private readonly unitEls = new Map<string, UnitEls>();
  private readonly wheelItems: HTMLElement[] = [];
  private selected = 0;
  private readonly toast: HTMLElement;
  private toastTimer = 0;
  private readonly gitingFill: HTMLElement;
  private readonly banner: HTMLElement;
  private readonly quest: HTMLElement;
  private readonly modal: HTMLElement;
  private modalClose: (() => void) | null = null;
  /** Fired when the Bayanihan banner is tapped. */
  onBayanihan: (() => void) | null = null;
  /** Fired when a wheel command is confirmed; handler executes it. */
  onCommand: ((cmd: ReflexCommand) => void) | null = null;

  constructor(private readonly root: HTMLElement) {
    this.party = el("div", "hud-party");
    this.wheel = el("div", "hud-wheel");
    this.debug = el("div", "hud-debug");
    this.toast = el("div", "hud-toast");
    this.quest = el("div", "hud-quest");
    this.banner = el("div", "hud-bayanihan");
    this.banner.textContent = "Bayanihan Strike Ready! [R1]";
    this.banner.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.onBayanihan?.();
    });
    this.modal = el("div", "hud-modal");
    this.modal.addEventListener("pointerdown", () => this.closeModal());
    root.append(this.party, this.wheel, this.debug, this.toast, this.quest, this.banner, this.modal);

    const giting = el("div", "hud-giting");
    const gitingLabel = el("div", "hud-giting-label");
    gitingLabel.textContent = "Giting";
    const gitingBar = el("div", "hud-bar");
    this.gitingFill = el("div", "hud-bar-fill giting");
    gitingBar.appendChild(this.gitingFill);
    giting.append(gitingLabel, gitingBar);
    this.party.appendChild(giting);

    const radius = 62;
    REFLEX_COMMANDS.forEach((cmd, i) => {
      const angle = (i / REFLEX_COMMANDS.length) * Math.PI * 2 - Math.PI / 2;
      const item = el("div", "hud-wheel-item");
      item.textContent = cmd.label;
      item.title = cmd.label;
      item.style.transform = `translate(${Math.cos(angle) * radius}px, ${Math.sin(angle) * radius}px)`;
      this.wheel.appendChild(item);
      this.wheelItems.push(item);
    });
    this.select(0);
  }

  addUnit(u: HudUnit): void {
    const box = el("div", "hud-unit");
    const name = el("div", "hud-name");
    name.textContent = u.name;
    const hpBar = el("div", "hud-bar");
    const hp = el("div", "hud-bar-fill hp");
    hpBar.appendChild(hp);
    const atbBar = el("div", "hud-bar");
    const atb = el("div", "hud-bar-fill atb");
    atbBar.appendChild(atb);
    box.append(name, hpBar, atbBar);
    this.party.appendChild(box);
    this.unitEls.set(u.id, { hp, atb });
  }

  /**
   * Confirm the highlighted command: run the handler, then hide the wheel.
   * Callers restore time dilation to 1.0x afterwards.
   */
  confirmSelection(): ReflexCommand {
    const cmd = this.selectedCommand;
    this.onCommand?.(cmd);
    this.setWheelOpen(false);
    return cmd;
  }

  /** Update the Giting gauge; the gold banner shows (and is tappable) only when `ready`. */
  setGiting(value: number, max: number, ready: boolean): void {
    this.gitingFill.style.transform = `scaleX(${Math.min(1, Math.max(0, value / max))})`;
    this.gitingFill.classList.toggle("full", value >= max);
    this.banner.classList.toggle("show", ready);
  }

  setQuest(text: string): void {
    this.quest.textContent = text;
    this.quest.classList.remove("updated");
    void this.quest.offsetWidth; // restart the highlight animation
    this.quest.classList.add("updated");
  }

  get modalOpen(): boolean {
    return this.modal.classList.contains("open");
  }

  /** Centered reward modal; dismissed by tap or `closeModal()`. */
  showVictory(title: string, lines: string[], onClose?: () => void): void {
    this.modal.replaceChildren();
    const card = el("div", "hud-modal-card");
    const h = el("div", "hud-modal-title");
    h.textContent = title;
    card.appendChild(h);
    for (const line of lines) {
      const row = el("div", "hud-modal-row");
      row.textContent = line;
      card.appendChild(row);
    }
    const hint = el("div", "hud-modal-hint");
    hint.textContent = "Tap / Space to continue";
    card.appendChild(hint);
    this.modal.appendChild(card);
    this.modal.classList.add("open");
    this.modalClose = onClose ?? null;
  }

  closeModal(): void {
    if (!this.modalOpen) return;
    this.modal.classList.remove("open");
    const done = this.modalClose;
    this.modalClose = null;
    done?.();
  }

  /** Brief floating message (e.g. "Not enough SP"). Uses unscaled time. */
  showToast(text: string, seconds = 1.2): void {
    this.toast.textContent = text;
    this.toast.classList.add("show");
    this.toastTimer = seconds;
  }

  /** Per-frame UI animation; pass the unscaled frame delta. */
  tick(unscaledDt: number): void {
    if (this.toastTimer > 0) {
      this.toastTimer -= unscaledDt;
      if (this.toastTimer <= 0) this.toast.classList.remove("show");
    }
  }

  update(units: HudUnit[]): void {
    for (const u of units) {
      const els = this.unitEls.get(u.id);
      if (!els) continue;
      els.hp.style.transform = `scaleX(${u.maxHp > 0 ? Math.min(1, Math.max(0, u.hp / u.maxHp)) : 0})`;
      const atb = u.unit?.atb ?? 0;
      els.atb.style.transform = `scaleX(${atb})`;
      els.atb.classList.toggle("ready", atb >= 1);
    }
  }

  get wheelOpen(): boolean {
    return this.wheel.classList.contains("open");
  }

  setWheelOpen(open: boolean): void {
    this.wheel.classList.toggle("open", open);
    this.root.classList.toggle("command-active", open);
  }

  /** Pick a wheel slot from a direction (e.g. the movement stick). */
  selectByDirection(x: number, y: number): void {
    if (x * x + y * y < 0.25) return;
    const angle = Math.atan2(-y, x) + Math.PI / 2; // 0 = up, clockwise
    const n = REFLEX_COMMANDS.length;
    const idx = Math.round(((angle + Math.PI * 2) % (Math.PI * 2)) / ((Math.PI * 2) / n)) % n;
    this.select(idx);
  }

  get selectedCommand(): ReflexCommand {
    return REFLEX_COMMANDS[this.selected];
  }

  setDebug(text: string): void {
    this.debug.textContent = text;
  }

  dispose(): void {
    this.root.replaceChildren();
  }

  private select(i: number): void {
    this.selected = i;
    this.wheelItems.forEach((item, j) => item.classList.toggle("selected", i === j));
  }
}

function el(tag: string, className: string): HTMLElement {
  const e = document.createElement(tag);
  e.className = className;
  return e;
}
