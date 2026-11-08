/**
 * Agimat (amulet) system: elemental damage multipliers and "gear horology" —
 * charms whose potency waxes and wanes with the in-game hour of the night.
 */

export type Element = "none" | "apoy" | "tubig" | "hangin" | "lupa" | "liwanag" | "dilim";

/** attacker element -> defender element -> multiplier */
const ELEMENT_CHART: Partial<Record<Element, Partial<Record<Element, number>>>> = {
  apoy: { hangin: 1.5, tubig: 0.5, apoy: 0.75 },
  tubig: { apoy: 1.5, lupa: 0.5, tubig: 0.75 },
  lupa: { tubig: 1.5, hangin: 0.5, lupa: 0.75 },
  hangin: { lupa: 1.5, apoy: 0.5, hangin: 0.75 },
  liwanag: { dilim: 2.0, liwanag: 0.5 },
  dilim: { liwanag: 2.0, dilim: 0.5 },
};

export interface Agimat {
  id: string;
  name: string;
  element: Element;
  /** Flat damage bonus multiplier at peak potency (e.g. 0.25 = +25%). */
  power: number;
  /** In-game hour (0–24) at which the charm peaks. */
  peakHour: number;
  /** Hours either side of the peak before potency reaches zero. */
  window: number;
}

/** One in-game night lasts this many real seconds (18:00 → 06:00). */
const NIGHT_LENGTH_SECONDS = 20 * 60;
const NIGHT_START_HOUR = 18;
const NIGHT_HOURS = 12;

export class AgimatSystem {
  private readonly equipped: Agimat[] = [];
  private clockSeconds = 0;

  /** Current in-game hour, 0–24. */
  get hour(): number {
    const t = (this.clockSeconds % NIGHT_LENGTH_SECONDS) / NIGHT_LENGTH_SECONDS;
    return (NIGHT_START_HOUR + t * NIGHT_HOURS) % 24;
  }

  update(dt: number): void {
    this.clockSeconds += dt;
  }

  setHour(hour: number): void {
    const rel = (hour - NIGHT_START_HOUR + 24) % 24;
    this.clockSeconds = (rel / NIGHT_HOURS) * NIGHT_LENGTH_SECONDS;
  }

  equip(agimat: Agimat, maxSlots = 3): boolean {
    if (this.equipped.length >= maxSlots) return false;
    this.equipped.push(agimat);
    return true;
  }

  unequip(id: string): void {
    const i = this.equipped.findIndex((a) => a.id === id);
    if (i >= 0) this.equipped.splice(i, 1);
  }

  get loadout(): readonly Agimat[] {
    return this.equipped;
  }

  /** 0–1 potency of a charm at the current hour (triangular falloff, wraps midnight). */
  potency(agimat: Agimat): number {
    const hoursFromPeak = Math.abs(((this.hour - agimat.peakHour + 36) % 24) - 12);
    return Math.max(0, 1 - hoursFromPeak / agimat.window);
  }

  static elementMultiplier(attacker: Element, defender: Element, weakness: Element[] = []): number {
    let m = ELEMENT_CHART[attacker]?.[defender] ?? 1;
    if (attacker !== "none" && weakness.includes(attacker)) m *= 1.25;
    return m;
  }

  /** Final damage for a hit from the player using the current loadout. */
  resolveDamage(base: number, attackElement: Element, defender: Element, weakness: Element[] = []): number {
    let bonus = 1;
    for (const a of this.equipped) {
      if (a.element === attackElement || a.element === "none") bonus += a.power * this.potency(a);
    }
    return Math.round(base * bonus * AgimatSystem.elementMultiplier(attackElement, defender, weakness));
  }
}
