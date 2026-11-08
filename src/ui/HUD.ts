import type { CombatUnit } from "../combat/CombatEngine";

export interface HudUnit {
  id: string;
  name: string;
  hp: number;
  maxHp: number;
  unit?: CombatUnit;
}

export const REFLEX_COMMANDS = ["Strike", "Agimat", "Guard", "Item"] as const;
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

  constructor(private readonly root: HTMLElement) {
    this.party = el("div", "hud-party");
    this.wheel = el("div", "hud-wheel");
    this.debug = el("div", "hud-debug");
    root.append(this.party, this.wheel, this.debug);

    const radius = 62;
    REFLEX_COMMANDS.forEach((cmd, i) => {
      const angle = (i / REFLEX_COMMANDS.length) * Math.PI * 2 - Math.PI / 2;
      const item = el("div", "hud-wheel-item");
      item.textContent = cmd;
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

  update(units: HudUnit[]): void {
    for (const u of units) {
      const els = this.unitEls.get(u.id);
      if (!els) continue;
      els.hp.style.transform = `scaleX(${u.maxHp > 0 ? u.hp / u.maxHp : 0})`;
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
