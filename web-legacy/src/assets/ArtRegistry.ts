import { ART_BY_ID, ART_EXTENSIONS, ART_MANIFEST, ART_SPECS, type ArtEntry } from "./artManifest";

/**
 * Resolves art ids to image URLs. A real file in public/assets wins; otherwise a labelled
 * placeholder is returned. Resolution is async-upgrade: callers get the placeholder immediately via
 * `placeholder(id)` and swap in the real URL when `resolve(id)` settles.
 */

const BASE = (): string => import.meta.env.BASE_URL;
const found = new Map<string, Promise<string | null>>();

const loads = (url: string): Promise<boolean> =>
  new Promise((ok) => {
    const img = new Image();
    img.onload = () => ok(img.naturalWidth > 0);
    img.onerror = () => ok(false); // dev-server SPA fallback serves HTML for missing files: that fails to decode, as intended
    img.src = url;
  });

/** Real image URL for an id, or null if no file is on disk yet. Cached. */
export function resolveReal(id: string): Promise<string | null> {
  const hit = found.get(id);
  if (hit) return hit;
  const entry = ART_BY_ID[id];
  const p = (async () => {
    if (!entry) return null;
    for (const ext of ART_EXTENSIONS) {
      const url = `${BASE()}assets/${entry.dir}/${entry.name}.${ext}`;
      if (await loads(url)) return url;
    }
    return null;
  })();
  found.set(id, p);
  return p;
}

const esc = (s: string): string => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function wrap(text: string, max: number, maxLines: number): string[] {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    if ((cur + " " + w).trim().length > max) {
      lines.push(cur);
      cur = w;
    } else cur = (cur + " " + w).trim();
  }
  if (cur) lines.push(cur);
  if (lines.length > maxLines) {
    lines.length = maxLines;
    lines[maxLines - 1] += "…";
  }
  return lines;
}

const cache = new Map<string, string>();

/** A comic-styled placeholder that says exactly which file to drop in and what to draw. */
export function placeholder(id: string): string {
  const hit = cache.get(id);
  if (hit) return hit;
  const e: ArtEntry | undefined = ART_BY_ID[id];
  const spec = e ? ART_SPECS[e.kind] : ART_SPECS.panel;
  const file = e ? `public/assets/${e.dir}/${e.name}.webp` : id;
  const hue = [...id].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
  const w = e?.kind === "portrait" ? 512 : 1600;
  const h = e?.kind === "portrait" ? 512 : 900;
  let body: string;
  if (e?.kind === "portrait") {
    const initial = esc(e.name.charAt(0).toUpperCase());
    body = `<circle cx='256' cy='210' r='96' fill='hsl(${hue} 18% 26%)'/><path d='M96 480 C110 340 190 316 256 316 C322 316 402 340 416 480Z' fill='hsl(${hue} 18% 22%)'/>
      <text x='256' y='246' font-size='120' font-weight='800' text-anchor='middle' fill='#c9a24a' font-family='sans-serif'>${initial}</text>
      <text x='256' y='500' font-size='26' text-anchor='middle' fill='#e8e0cc' font-family='monospace'>${esc(e.name)}</text>`;
  } else {
    // Slanted panel masks crop the left/right edges: keep everything in the centre column.
    const lines = wrap(e?.brief ?? "", 34, 7)
      .map((l, i) => `<text x='800' y='${470 + i * 34}' font-size='27' text-anchor='middle' fill='#d8d0bc' font-family='sans-serif'>${esc(l)}</text>`)
      .join("");
    body = `<g stroke='#ffffff' stroke-opacity='.05' stroke-width='3'>${Array.from({ length: 30 }, (_, i) => `<line x1='${i * 60 - 200}' y1='900' x2='${i * 60 + 500}' y2='0'/>`).join("")}</g>
      <rect x='60' y='60' width='1480' height='780' fill='none' stroke='#c9a24a' stroke-width='6' stroke-dasharray='28 16'/>
      <text x='800' y='250' font-size='84' font-weight='900' text-anchor='middle' fill='#c9a24a' fill-opacity='.9' font-family='Impact,sans-serif' transform='rotate(-4 800 250)'>PLACEHOLDER</text>
      <text x='800' y='340' font-size='34' font-weight='700' text-anchor='middle' fill='#fff' font-family='monospace'>${esc(id)}</text>
      <text x='800' y='392' font-size='22' text-anchor='middle' fill='#c9a24a' font-family='monospace'>${esc(file)}</text>
      <text x='800' y='424' font-size='22' text-anchor='middle' fill='#c9a24a' font-family='monospace'>${spec.width}×${spec.height}</text>${lines}`;
  }
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 ${w} ${h}' preserveAspectRatio='xMidYMid slice'>
    <defs><radialGradient id='g' cx='.5' cy='.4' r='.8'><stop offset='0' stop-color='hsl(${hue} 22% 20%)'/><stop offset='1' stop-color='#07080d'/></radialGradient></defs>
    <rect width='${w}' height='${h}' fill='url(#g)'/>${body}</svg>`;
  const url = `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  cache.set(id, url);
  return url;
}

/** Fire-and-forget warm-up so panels are decided before a cutscene reaches them. */
export function preload(ids: string[]): void {
  for (const id of ids) void resolveReal(id);
}

/** Status of every manifest entry (for the ?assets checklist). */
export async function status(): Promise<{ entry: ArtEntry; url: string | null }[]> {
  return Promise.all(ART_MANIFEST.map(async (entry) => ({ entry, url: await resolveReal(entry.id) })));
}
