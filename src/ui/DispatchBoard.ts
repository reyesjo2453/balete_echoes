import { REWIND_LEDGER_COST, type DispatchState } from "../narrative/DispatchState";

/**
 * Dispatch board overlay: jobs, debts, time and ledger. Purely presentational over a DispatchState;
 * `open()` resolves when the player ends the day.
 */
export class DispatchBoard {
  private readonly el = document.createElement("div");
  private readonly chip = document.createElement("div");
  private resolve: (() => void) | null = null;

  constructor(parent: HTMLElement, hudParent: HTMLElement) {
    this.el.className = "dispatch-board";
    // Keep the touch stick from spawning under the board.
    this.el.addEventListener("touchstart", (e) => e.stopPropagation(), { passive: true });
    parent.appendChild(this.el);
    this.chip.className = "ledger-chip";
    hudParent.appendChild(this.chip);
  }

  get active(): boolean {
    return this.resolve !== null;
  }

  /** Persistent HUD readout of the ledger (shown after the board closes). */
  showChip(state: DispatchState | null): void {
    if (!state) {
      this.chip.classList.remove("show");
      return;
    }
    this.chip.textContent = `Ledger ${state.ledger} · ₱${state.money} · ${state.hoursLeft}h left`;
    this.chip.classList.add("show");
  }

  open(state: DispatchState, title = "Dispatch Board"): Promise<void> {
    if (this.resolve) return Promise.resolve();
    this.el.classList.add("open");
    this.render(state, title);
    return new Promise((res) => {
      this.resolve = res;
    });
  }

  private close(): void {
    this.el.classList.remove("open");
    this.el.replaceChildren();
    const done = this.resolve;
    this.resolve = null;
    done?.();
  }

  private render(state: DispatchState, title: string): void {
    const card = document.createElement("div");
    card.className = "board-card";
    const h = document.createElement("div");
    h.className = "board-title";
    h.textContent = title;

    const stats = document.createElement("div");
    stats.className = "board-stats";
    const stat = (label: string, value: string, cls = "") => {
      const s = document.createElement("div");
      s.className = `board-stat ${cls}`;
      s.innerHTML = `<span>${label}</span><b>${value}</b>`;
      return s;
    };
    stats.append(
      stat("Time", `${state.hoursLeft}h left`, state.hoursLeft <= 2 ? "warn" : ""),
      stat("Money", `₱${state.money}`),
      stat("Ledger (family debt)", String(state.ledger), "ledger"),
      stat("Rewinds", String(state.rewinds))
    );

    const cols = document.createElement("div");
    cols.className = "board-cols";

    const jobs = document.createElement("section");
    jobs.innerHTML = "<h3>Jobs</h3>";
    for (const job of state.jobs) {
      const taken = state.taken.includes(job.id);
      const b = document.createElement("button");
      b.type = "button";
      b.className = "board-item";
      b.disabled = taken || !state.canTake(job);
      b.classList.toggle("done", taken);
      b.innerHTML =
        `<strong>${job.title}</strong><em>${job.client}</em><p>${job.blurb}</p>` +
        `<small>${job.hours}h · +₱${job.pay} · risk ${"▲".repeat(job.risk) || "–"}</small>`;
      b.addEventListener("click", () => {
        if (state.take(job.id)) this.render(state, title);
      });
      jobs.appendChild(b);
    }

    const debts = document.createElement("section");
    debts.innerHTML = "<h3>Debts</h3>";
    for (const debt of state.debts) {
      const paid = state.paid.includes(debt.id);
      const b = document.createElement("button");
      b.type = "button";
      b.className = "board-item";
      b.disabled = paid || !state.canPay(debt);
      b.classList.toggle("done", paid);
      b.innerHTML =
        `<strong>${debt.creditor}</strong><em>₱${debt.amount}</em>` +
        `<small>${paid ? "Paid" : `Unpaid at dusk: +${debt.penalty} ledger`}</small>`;
      b.addEventListener("click", () => {
        if (state.pay(debt.id)) this.render(state, title);
      });
      debts.appendChild(b);
    }
    cols.append(jobs, debts);

    const actions = document.createElement("div");
    actions.className = "board-actions";
    const rewind = document.createElement("button");
    rewind.type = "button";
    rewind.className = "board-rewind";
    rewind.textContent = `Rewind last choice (+${REWIND_LEDGER_COST} ledger)`;
    rewind.disabled = !state.canRewind;
    rewind.addEventListener("click", () => {
      if (state.rewind()) this.render(state, title);
    });
    const go = document.createElement("button");
    go.type = "button";
    go.className = "board-go";
    go.textContent = "Start the day ▸";
    go.addEventListener("click", () => this.close());
    actions.append(rewind, go);

    card.append(h, stats, cols, actions);
    this.el.replaceChildren(card);
  }
}
