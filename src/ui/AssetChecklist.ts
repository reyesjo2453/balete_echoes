import { placeholder, status } from "../assets/ArtRegistry";
import { ART_SPECS } from "../assets/artManifest";

/** `?assets` — full-screen checklist of every manifest slot: real art or placeholder, and the file to drop in. */
export async function showAssetChecklist(): Promise<void> {
  const root = document.createElement("div");
  root.style.cssText = "position:fixed;inset:0;z-index:9999;overflow:auto;background:#0b0d14;color:#e8e0cc;font:14px/1.4 system-ui,sans-serif;padding:16px";
  document.body.appendChild(root);
  root.textContent = "Checking art…";
  const rows = await status();
  const done = rows.filter((r) => r.url).length;
  root.replaceChildren();
  const h = document.createElement("h1");
  h.style.cssText = "margin:0 0 4px;font-size:20px;color:#c9a24a";
  h.textContent = `Art checklist: ${done}/${rows.length} delivered`;
  const sub = document.createElement("p");
  sub.style.cssText = "margin:0 0 16px;opacity:.8";
  sub.textContent = "Drop a file at the path shown (webp/png/jpg). Reload: the placeholder is replaced automatically. Spec: docs/ASSET_PIPELINE.md";
  const grid = document.createElement("div");
  grid.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px";
  for (const { entry, url } of rows) {
    const card = document.createElement("div");
    card.style.cssText = `border:2px solid ${url ? "#3c9a5f" : "#8a5a1c"};border-radius:6px;overflow:hidden;background:#141826`;
    const img = document.createElement("img");
    img.src = url ?? placeholder(entry.id);
    img.style.cssText = `width:100%;aspect-ratio:${entry.kind === "portrait" ? "1/1" : "16/9"};object-fit:cover;display:block`;
    const cap = document.createElement("div");
    cap.style.cssText = "padding:8px;font-size:12px";
    const s = ART_SPECS[entry.kind];
    cap.innerHTML = `<b>${url ? "✓" : "○"} ${entry.id}</b><br><code>public/assets/${entry.dir}/${entry.name}.*</code><br>${s.width}×${s.height} · ${entry.scene}`;
    card.append(img, cap);
    grid.appendChild(card);
  }
  root.append(h, sub, grid);
}
