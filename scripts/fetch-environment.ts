/**
 * Environment art for the Quiapo alley (fal.ai): tenement facades, wet asphalt, rusted metal, and prop models.
 *
 *   FAL_KEY=... npm run fetch-environment             # generate whatever is missing
 *   FAL_KEY=... npm run fetch-environment -- --force  # regenerate everything
 *
 * Art direction (matches the comic panels and sprites): rain-soaked noir, graphic-novel cel shading,
 * deep teal-indigo shadows, rust red accents, warm amber sodium light. No cyan neon wash.
 *
 * Textures are written to public/assets/env as <name>.webp (albedo), <name>_n.webp (normal, derived from
 * luminance relief) and, for facades, <name>_e.webp (emissive: only the lit windows). Models go to
 * public/assets/models. Everything is cached, so re-runs only pay for missing files.
 */
import { createRequire } from "node:module";
import { mkdir, writeFile, access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { download, falQueue, hasKey } from "./lib/fal.ts";

const require = createRequire(import.meta.url);
const sharp = require("sharp") as typeof import("sharp");
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ENV_DIR = resolve(ROOT, "public/assets/env");
const MODEL_DIR = resolve(ROOT, "public/assets/models");
const FORCE = process.argv.includes("--force");
const exists = (p: string) => access(p).then(() => true, () => false);

const STYLE =
  "graphic novel cel-shaded illustration, bold ink linework, painterly textures, rain-soaked noir night, " +
  "deep teal and indigo shadows, rust red accents, warm amber sodium light, desaturated, no neon, no text";

interface TexJob {
  name: string;
  prompt: string;
  w: number;
  h: number;
  /** Make the image tile by mirroring (ground, metal). */
  mirrorTile?: boolean;
  /** Emit an emissive map of the lit windows. */
  emissive?: boolean;
  /** Relief strength for the derived normal map. */
  relief: number;
}

const FACADE =
  "flat orthographic front elevation of a weathered multi-storey Filipino tenement building facade in Quiapo Manila, " +
  "straight-on view with no perspective, filling the whole frame edge to edge, no sky, no street, ";

const TEXTURES: TexJob[] = [
  {
    name: "facade_a", w: 832, h: 1440, emissive: true, relief: 2.2,
    prompt: FACADE + "peeling teal-green plaster over grimy concrete, shuttered wooden windows, a few windows lit warm amber from inside, rusty iron grilles, window air conditioners, tangled electrical cables, " + STYLE,
  },
  {
    name: "facade_b", w: 832, h: 1440, emissive: true, relief: 2.2,
    prompt: FACADE + "faded rust-red painted concrete with water stains, narrow balconies with hanging laundry, louvered windows, a couple lit warm amber, rooftop water tank, pipes and cables, " + STYLE,
  },
  {
    name: "facade_c", w: 832, h: 1440, emissive: true, relief: 2.2,
    prompt: FACADE + "dark blue-grey stained concrete with crumbling brick patches, barred windows, corrugated metal awnings, faded painted signage panels, one or two windows lit amber, " + STYLE,
  },
  {
    name: "facade_d", w: 832, h: 1440, emissive: true, relief: 2.2,
    prompt: FACADE + "old Spanish-colonial style tenement with sagging capiz-shell windows, mossy damp plaster in muted olive and ochre, wooden shutters, ironwork balcony rails, a lit amber window, " + STYLE,
  },
  {
    name: "asphalt", w: 1024, h: 1024, mirrorTile: true, relief: 1.6,
    prompt: "top-down seamless texture of uniform dark wet asphalt, evenly lit, fine hairline cracks, tiny pebbles, subtle damp sheen, NO large puddles, NO debris, NO curb, no lighting hotspots, flat overhead view, " + STYLE,
  },
  {
    name: "metal", w: 1024, h: 1024, mirrorTile: true, relief: 2.6,
    prompt: "seamless texture of rusted corrugated iron roofing sheet with vertical ridges, peeling dark red paint, streaks of rust and rain, flat front view, " + STYLE,
  },
];

async function flux(prompt: string, w: number, h: number): Promise<Buffer> {
  const r = await falQueue<{ images: Array<{ url: string }> }>("fal-ai/flux-pro/v1.1", {
    prompt, image_size: { width: w, height: h }, num_images: 1, output_format: "png", safety_tolerance: "5",
  });
  const url = r.images?.[0]?.url;
  if (!url) throw new Error("flux-pro returned no image");
  return download(url);
}

/** Mirror the image 2x2 so it tiles without seams (the price is visible symmetry, fine for ground and metal). */
async function mirrorTile(img: Buffer): Promise<Buffer> {
  const { width: w, height: h } = await sharp(img).metadata();
  const a = await sharp(img).toBuffer();
  const fx = await sharp(img).flop().toBuffer();
  const fy = await sharp(img).flip().toBuffer();
  const fxy = await sharp(img).flip().flop().toBuffer();
  return sharp({ create: { width: w! * 2, height: h! * 2, channels: 3, background: "#000" } })
    .composite([{ input: a, left: 0, top: 0 }, { input: fx, left: w!, top: 0 }, { input: fy, left: 0, top: h! }, { input: fxy, left: w!, top: h! }])
    .resize(w!, h!)
    .png()
    .toBuffer();
}

/** Tangent-space normal map from the luminance relief of an albedo (Sobel on a lightly blurred height). */
async function normalFromLuma(img: Buffer, strength: number): Promise<Buffer> {
  const { data, info } = await sharp(img).greyscale().blur(1.2).raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const out = Buffer.alloc(w * h * 3);
  const px = (x: number, y: number) => data[Math.min(h - 1, Math.max(0, y)) * w + Math.min(w - 1, Math.max(0, x))] / 255;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const dx = (px(x + 1, y - 1) + 2 * px(x + 1, y) + px(x + 1, y + 1)) - (px(x - 1, y - 1) + 2 * px(x - 1, y) + px(x - 1, y + 1));
    const dy = (px(x - 1, y + 1) + 2 * px(x, y + 1) + px(x + 1, y + 1)) - (px(x - 1, y - 1) + 2 * px(x, y - 1) + px(x + 1, y - 1));
    let nx = -dx * strength, ny = -dy * strength, nz = 1;
    const l = Math.hypot(nx, ny, nz);
    nx /= l; ny /= l; nz /= l;
    const i = (y * w + x) * 3;
    out[i] = Math.round((nx * 0.5 + 0.5) * 255);
    out[i + 1] = Math.round((ny * 0.5 + 0.5) * 255);
    out[i + 2] = Math.round((nz * 0.5 + 0.5) * 255);
  }
  return sharp(out, { raw: { width: w, height: h, channels: 3 } }).png().toBuffer();
}

/** Only the warmly lit parts of a facade survive (lit windows); everything else is black. */
async function emissiveFromWindows(img: Buffer): Promise<Buffer> {
  const { data, info } = await sharp(img).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const out = Buffer.alloc(data.length);
  for (let i = 0; i < data.length; i += 3) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const lum = (r * 0.3 + g * 0.59 + b * 0.11) / 255;
    const warm = (r - b) / 255;
    if (lum > 0.55 && warm > 0.18) {
      const k = Math.min(1, (lum - 0.55) / 0.2);
      out[i] = r * k; out[i + 1] = g * k; out[i + 2] = b * k;
    }
  }
  return sharp(out, { raw: { width: info.width, height: info.height, channels: 3 } }).png().toBuffer();
}

async function textures(): Promise<void> {
  await mkdir(ENV_DIR, { recursive: true });
  await Promise.all(
    TEXTURES.map(async (t) => {
      const albedoPath = resolve(ENV_DIR, `${t.name}.webp`);
      if (!FORCE && (await exists(albedoPath))) return console.log(`[env] ${t.name} exists`);
      console.log(`[env] generating ${t.name}...`);
      try {
        let img = await flux(t.prompt, t.w, t.h);
        if (t.mirrorTile) img = await mirrorTile(img);
        await sharp(img).webp({ quality: 90 }).toFile(albedoPath);
        await sharp(await normalFromLuma(img, t.relief)).webp({ quality: 90 }).toFile(resolve(ENV_DIR, `${t.name}_n.webp`));
        if (t.emissive) await sharp(await emissiveFromWindows(img)).webp({ quality: 90 }).toFile(resolve(ENV_DIR, `${t.name}_e.webp`));
        console.log(`[env] ${t.name} done`);
      } catch (err) {
        console.warn(`[env] ${t.name} failed: ${(err as Error).message}`);
      }
    })
  );
}

interface ModelJob { name: string; prompt: string }
const MODELS: ModelJob[] = [
  { name: "delivery_van", prompt: "stylized game asset, battered Filipino delivery panel van, boxy cream-white body with a rust red lower stripe, dented panels, caged headlights, roof rack, side sliding door, three-quarter front view, cel-shaded graphic novel style, single object, plain white background" },
  { name: "tricycle", prompt: "stylized game asset, Philippine tricycle: a small motorcycle with a welded passenger sidecar cab, faded green paint, rusty, dented, three-quarter view, cel-shaded graphic novel style, single object, plain white background" },
  { name: "crates_barrels", prompt: "stylized game asset, cluster of wooden fruit crates, a rusty oil drum and two blue plastic water drums stacked together, weathered, cel-shaded graphic novel style, single object group, plain white background" },
  { name: "trash_pile", prompt: "stylized game asset, pile of black garbage bags, a dented metal trash can and a cardboard box, wet and grimy, cel-shaded graphic novel style, single object group, plain white background" },
];

async function models(): Promise<void> {
  await mkdir(MODEL_DIR, { recursive: true });
  await Promise.all(
    MODELS.map(async (m) => {
      const dest = resolve(MODEL_DIR, `${m.name}.glb`);
      if (!FORCE && (await exists(dest))) return console.log(`[models] ${m.name} exists`);
      console.log(`[models] generating ${m.name}...`);
      try {
        const concept = await flux(m.prompt, 1024, 1024);
        const dataUrl = `data:image/png;base64,${concept.toString("base64")}`;
        const res = await falQueue<{ model_mesh?: { url: string } }>("fal-ai/trellis", { image_url: dataUrl, texture_size: 1024, mesh_simplify: 0.95 });
        if (!res.model_mesh?.url) throw new Error("trellis returned no mesh");
        await writeFile(dest, await download(res.model_mesh.url));
        await writeFile(resolve(ROOT, ".cache", `${m.name}_concept.png`), concept).catch(() => undefined);
        console.log(`[models] ${m.name} done`);
      } catch (err) {
        console.warn(`[models] ${m.name} failed: ${(err as Error).message}`);
      }
    })
  );
}

if (!hasKey()) {
  console.warn("[fetch-environment] FAL_KEY not set — skipping.");
} else {
  await mkdir(resolve(ROOT, ".cache"), { recursive: true });
  const which = process.argv.find((a) => a === "textures" || a === "models");
  if (which !== "models") await textures();
  if (which !== "textures") await models();
}
