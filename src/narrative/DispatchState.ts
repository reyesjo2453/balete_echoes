/**
 * Dispatch-board model: the day's jobs, debts, time and the family-debt ledger.
 * Pure data + rules (no DOM) so real story data can replace the placeholders in `PLACEHOLDER_BOARD`.
 */

export interface Job {
  id: string;
  title: string;
  client: string;
  blurb: string;
  /** Hours of the day this job consumes. */
  hours: number;
  /** Pesos earned. */
  pay: number;
  /** 0-3: how likely the job goes wrong in the field. Risky jobs cost injury at the start of the field scene. */
  risk: number;
}

export interface Debt {
  id: string;
  creditor: string;
  amount: number;
  /** Ledger debt added if this is left unpaid when the day ends. */
  penalty: number;
}

export interface BoardData {
  hours: number;
  money: number;
  ledger: number;
  jobs: Job[];
  debts: Debt[];
}

/** Ledger cost of each watch rewind (the watch is a debt ledger). */
export const REWIND_LEDGER_COST = 2;
/** Max HP fraction lost per risk point of jobs taken (applied when the field scene starts). */
export const INJURY_PER_RISK = 0.08;

/** Placeholder Episode 1 morning board. TODO: replace with authored story data. */
export const PLACEHOLDER_BOARD: BoardData = {
  hours: 8,
  money: 40,
  ledger: 10,
  jobs: [
    { id: "church-envelope", title: "The Envelope", client: "Quiapo Church sacristan", blurb: "A lender's envelope, hand-delivered.", hours: 2, pay: 60, risk: 0 },
    { id: "bodega-rush", title: "Bodega 9 Rush", client: "Gat. Dizon", blurb: "Pay is double. Nobody says why.", hours: 3, pay: 140, risk: 2 },
    { id: "lola-medicine", title: "Lola's Medicine", client: "Botica sa Plaza", blurb: "Cheap, slow, and the right thing.", hours: 1, pay: 25, risk: 0 },
    { id: "night-parcel", title: "Night Parcel", client: "No return address", blurb: "Past curfew. The watch ticks wrong near it.", hours: 4, pay: 200, risk: 3 },
  ],
  debts: [
    { id: "kuya-lender", creditor: "Kuya Mando (lender)", amount: 80, penalty: 3 },
    { id: "rent", creditor: "Rent to Aling Perla", amount: 50, penalty: 2 },
  ],
};

interface Snapshot {
  hoursLeft: number;
  money: number;
  ledger: number;
  taken: string[];
  paid: string[];
}

export class DispatchState {
  hoursLeft: number;
  money: number;
  ledger: number;
  readonly jobs: Job[];
  readonly debts: Debt[];
  taken: string[] = [];
  paid: string[] = [];
  /** Rewinds used this run (each already charged to the ledger). */
  rewinds = 0;
  /** Free-form story flags (timed-choice outcomes etc.). */
  readonly flags: Record<string, string | boolean> = {};
  private readonly history: Snapshot[] = [];

  constructor(data: BoardData = PLACEHOLDER_BOARD) {
    this.hoursLeft = data.hours;
    this.money = data.money;
    this.ledger = data.ledger;
    this.jobs = data.jobs;
    this.debts = data.debts;
  }

  canTake(job: Job): boolean {
    return !this.taken.includes(job.id) && job.hours <= this.hoursLeft;
  }

  canPay(debt: Debt): boolean {
    return !this.paid.includes(debt.id) && debt.amount <= this.money;
  }

  take(id: string): boolean {
    const job = this.jobs.find((j) => j.id === id);
    if (!job || !this.canTake(job)) return false;
    this.push();
    this.hoursLeft -= job.hours;
    this.money += job.pay;
    this.taken.push(job.id);
    return true;
  }

  pay(id: string): boolean {
    const debt = this.debts.find((d) => d.id === id);
    if (!debt || !this.canPay(debt)) return false;
    this.push();
    this.money -= debt.amount;
    this.paid.push(debt.id);
    return true;
  }

  get canRewind(): boolean {
    return this.history.length > 0;
  }

  /** Undo the last board choice. The watch charges the ledger for it, and the charge is not undone. */
  rewind(): boolean {
    const snap = this.history.pop();
    if (!snap) return false;
    this.hoursLeft = snap.hoursLeft;
    this.money = snap.money;
    this.taken = snap.taken;
    this.paid = snap.paid;
    this.ledger = snap.ledger + REWIND_LEDGER_COST;
    this.rewinds++;
    return true;
  }

  /** Add (or remove) ledger debt directly: heals, Agimat use, expired timed choices. */
  charge(amount: number): void {
    this.ledger = Math.max(0, this.ledger + amount);
  }

  /** Close the day: unpaid debts add their penalty to the ledger. Returns the penalty added. */
  settle(): number {
    const penalty = this.debts.filter((d) => !this.paid.includes(d.id)).reduce((s, d) => s + d.penalty, 0);
    this.ledger += penalty;
    this.history.length = 0;
    return penalty;
  }

  /** Total risk of the jobs taken. */
  get risk(): number {
    return this.jobs.filter((j) => this.taken.includes(j.id)).reduce((s, j) => s + j.risk, 0);
  }

  /** Fraction of max HP Renzo starts the field scene without. */
  get injury(): number {
    return Math.min(0.6, this.risk * INJURY_PER_RISK);
  }

  private push(): void {
    this.history.push({
      hoursLeft: this.hoursLeft,
      money: this.money,
      ledger: this.ledger,
      taken: [...this.taken],
      paid: [...this.paid],
    });
  }
}
