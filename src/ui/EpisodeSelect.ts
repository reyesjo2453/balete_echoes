import type { Episode } from "../narrative/Episodes";

/** Episode selector shown after the title card. Unreleased episodes are listed but locked. */
export class EpisodeSelect {
  private readonly el = document.createElement("div");
  onSelect: ((episode: Episode) => void) | null = null;

  constructor(parent: HTMLElement) {
    this.el.className = "episode-select";
    this.el.addEventListener("touchstart", (e) => e.stopPropagation(), { passive: true });
    parent.appendChild(this.el);
  }

  get open(): boolean {
    return this.el.classList.contains("open");
  }

  show(episodes: Episode[]): void {
    this.el.replaceChildren();
    const h = document.createElement("div");
    h.className = "episode-heading";
    h.textContent = "Select Episode";
    const list = document.createElement("div");
    list.className = "episode-list";
    let first: HTMLButtonElement | null = null;
    for (const ep of episodes) {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "episode-card";
      b.disabled = !ep.released;
      const num = document.createElement("span");
      num.textContent = `Episode ${ep.id}`;
      const title = document.createElement("strong");
      title.textContent = ep.title;
      const sub = document.createElement("em");
      sub.textContent = ep.released ? ep.subtitle : `${ep.subtitle} · Coming soon`;
      b.append(num, title, sub);
      b.addEventListener("click", () => {
        this.hide();
        this.onSelect?.(ep);
      });
      list.appendChild(b);
      if (ep.released && !first) first = b;
    }
    this.el.append(h, list);
    this.el.classList.add("open");
    first?.focus();
  }

  hide(): void {
    this.el.classList.remove("open");
    this.el.replaceChildren();
  }
}
