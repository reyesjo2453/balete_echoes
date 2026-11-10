import { REWIND_LEDGER_COST, formatDuration, type DispatchState } from "../narrative/DispatchState";

const RISK_LABEL = ["No", "Low", "Medium", "High"];

export interface BoardOptions {
  /** Heading pinned at the top of the corkboard. */
  title?: string;
  /** In-world note pinned above the jobs (what this board is and why Renzo has to clear it). */
  note?: string;
  /** Label of the button that leaves the board. */
  goLabel?: string;
}

/**
 * The corkboard in Lola Rosa's shop: pinned job cards, the debt ledger notebook, time and rewinds.
 * It is only ever opened from inside a story scene (see Episodes.ts), never as the first screen.
 * Purely presentational over a DispatchState; `open()` resolves when the player leaves the board.
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
    this.chip.textContent = `Utang ${state.ledger} · ₱${state.money} · ${formatDuration(state.hoursLeft)} left`;
    this.chip.classList.add("show");
  }

  open(state: DispatchState, opts: BoardOptions = {}): Promise<void> {
    if (this.resolve) return Promise.resolve();
    this.el.classList.add("open");
    this.render(state, opts);
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

  private render(state: DispatchState, opts: BoardOptions): void {
    const card = document.createElement("div");
    card.className = "board-card";
    const h = document.createElement("div");
    h.className = "board-title";
    h.textContent = opts.title ?? "Cooperative Dispatch Ledger";

    const stats = document.createElement("div");
    stats.className = "board-stats";
    const stat = (label: string, value: string, cls = "") => {
      const s = document.createElement("div");
      s.className = `board-stat ${cls}`;
      s.innerHTML = `<span>${label}</span><b>${value}</b>`;
      return s;
    };
    stats.append(
      stat("Until the flood", formatDuration(state.hoursLeft), state.hoursLeft <= 1 ? "warn" : ""),
      stat("Money", `₱${state.money.toLocaleString("en-US")}`),
      stat("Utang (family debt)", String(state.ledger), "ledger"),
      stat("Rewinds", String(state.rewinds))
    );

    const cols = document.createElement("div");
    cols.className = "board-cols";

    const jobs = document.createElement("section");
    jobs.innerHTML = "<h3>Pinned jobs</h3>";
    for (const job of state.jobs) {
      const taken = state.taken.includes(job.id);
      const b = document.createElement("button");
      b.type = "button";
      b.className = "board-item board-job";
      b.disabled = taken || !state.canTake(job);
      b.classList.toggle("done", taken);
      b.innerHTML =
        `<strong>${job.title}</strong><em>${job.client}</em><p>${job.blurb}</p>` +
        `<small>${formatDuration(job.hours)} · +₱${job.pay.toLocaleString("en-US")} · ${RISK_LABEL[job.risk] ?? "?"} risk</small>`;
      b.addEventListener("click", () => {
        if (state.take(job.id)) this.render(state, opts);
      });
      jobs.appendChild(b);
    }

    const debts = document.createElement("section");
    debts.innerHTML = "<h3>Utang book</h3>";
    for (const debt of state.debts) {
      const paid = state.paid.includes(debt.id);
      const b = document.createElement("button");
      b.type = "button";
      b.className = "board-item board-debt";
      b.disabled = paid || !state.canPay(debt);
      b.classList.toggle("done", paid);
      b.innerHTML =
        `<strong>${debt.creditor}</strong><em>₱${debt.amount.toLocaleString("en-US")}</em>` +
        `<small>${paid ? "Paid" : `Unpaid by noon: +${debt.penalty} utang`}</small>`;
      b.addEventListener("click", () => {
        if (state.pay(debt.id)) this.render(state, opts);
      });
      debts.appendChild(b);
    }
    cols.append(jobs, debts);

    const actions = document.createElement("div");
    actions.className = "board-actions";
    const rewind = document.createElement("button");
    rewind.type = "button";
    rewind.className = "board-rewind";
    rewind.textContent = `Turn the watch back (+${REWIND_LEDGER_COST} utang)`;
    rewind.disabled = !state.canRewind;
    rewind.addEventListener("click", () => {
      if (state.rewind()) this.render(state, opts);
    });
    const go = document.createElement("button");
    go.type = "button";
    go.className = "board-go";
    go.textContent = opts.goLabel ?? "Head out ▸";
    go.addEventListener("click", () => this.close());
    actions.append(rewind, go);

    const body = document.createElement("div");
    body.className = "board-body";
    body.dataset.scroll = "1";
    body.append(h);
    if (opts.note) {
      const note = document.createElement("p");
      note.className = "board-note";
      note.textContent = opts.note;
      body.append(note);
    }
    body.append(stats, cols);
    card.append(body, actions);
    this.el.replaceChildren(card);
  }
}
