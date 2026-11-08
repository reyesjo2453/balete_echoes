/**
 * Fetch game art from fal.ai: sprites (flux/dev -> rembg), comic panels (flux-pro) and GLB props (flux -> trellis).
 *
 *   FAL_KEY=... npm run fetch-assets            # fetch missing sprites
 *   FAL_KEY=... npm run fetch-assets -- --force # regenerate everything
 *
 * Never fails the build: on a missing key, rate limit or network error the
 * sprite is skipped and the game falls back to procedural canvas textures
 * (see src/entities/ProceduralSprites.ts). No dependencies; Node 22+.
 */
import { mkdir, writeFile, access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const FAL_KEY = process.env.FAL_KEY;
const FORCE = process.argv.includes("--force");
const MAX_RETRIES = 3;

type Job =
  | { kind: "sprite"; file: string; prompt: string }
  | { kind: "panel"; file: string; prompt: string }
  | { kind: "model"; file: string; prompt: string };

const JOBS: Job[] = [
  {
    kind: "sprite",
    file: "public/assets/sprites/renzo_idle.png",
    prompt:
      "full body 2.5D JRPG character sprite of Renzo, 22-year-old Filipino youth, short messy dark hair, " +
      "tactical denim vest over dark shirt, athletic build, holding folding balisong knife, dynamic ready stance, " +
      "cel-shaded anime aesthetic, clean white background",
  },
  {
    kind: "sprite",
    file: "public/assets/sprites/aswang_idle.png",
    prompt:
      "full body mythological Filipino aswang monster, feral shadow creature, glowing red slit eyes, " +
      "hunched predatory posture, elongated claws, smoke wisps emanating from skin, " +
      "cel-shaded anime JRPG aesthetic, clean white background",
  },
  {
    kind: "panel",
    file: "public/assets/comics/renzo_draws_blade.webp",
    prompt:
      "anime manga graphic novel panel of Renzo igniting a glowing runic balisong blade in a rain-slicked " +
      "Quiapo alley, dynamic angled framing, halftones, speed lines, high contrast",
  },
  {
    kind: "panel",
    file: "public/assets/comics/dante_assist.webp",
    prompt:
      "anime manga action cut-in panel of Dante swinging electrified rattan arnis sticks, sparks flying, " +
      "bold dynamic composition, comic book speedlines",
  },
  {
    kind: "model",
    file: "public/assets/models/sari_sari_stall.glb",
    prompt:
      "low poly 3d diorama asset of a Filipino sari-sari wooden store booth with corrugated tin roof, " +
      "hanging chip bags, weathered wood, PBR textures, game ready, single object, white background",
  },
  {
    kind: "model",
    file: "public/assets/models/street_lamp.glb",
    prompt:
      "low poly urban concrete street lamppost with tangled overhead electrical wires, dark metal, " +
      "game ready, single object, white background",
  },
];

class FalError extends Error {
  readonly retryable: boolean;
  constructor(message: string, retryable: boolean) {
    super(message);
    this.retryable = retryable;
  }
}

async function fal<T>(model: string, body: unknown): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      const res = await fetch(`https://fal.run/${model}`, {
        method: "POST",
        headers: { Authorization: `Key ${FAL_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const retryable = res.status === 429 || res.status >= 500;
        throw new FalError(`${model} -> ${res.status} ${(await res.text()).slice(0, 200)}`, retryable);
      }
      return (await res.json()) as T;
    } catch (err) {
      const retryable = err instanceof FalError ? err.retryable : true; // network errors retry
      if (!retryable || attempt >= MAX_RETRIES) throw err;
      const wait = 2000 * 2 ** attempt;
      console.warn(`  retry ${attempt + 1}/${MAX_RETRIES} in ${wait}ms (${(err as Error).message})`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
}

async function download(url: string): Promise<Buffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download failed: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

async function flux(prompt: string, size: { width: number; height: number }): Promise<string> {
  const gen = await fal<{ images: Array<{ url: string }> }>("fal-ai/flux/dev", {
    prompt,
    image_size: size,
    num_images: 1,
    enable_safety_checker: true,
  });
  const src = gen.images?.[0]?.url;
  if (!src) throw new Error("flux/dev returned no image");
  return src;
}

/** flux/dev -> rembg: transparent PNG. */
async function sprite(job: Job): Promise<Buffer> {
  const src = await flux(job.prompt, { width: 768, height: 1024 });
  const cut = await fal<{ image: { url: string } }>("fal-ai/imageutils/rembg", { image_url: src });
  if (!cut.image?.url) throw new Error("rembg returned no image");
  return download(cut.image.url);
}

/** flux-pro panel, converted to WebP when `sharp` is available. */
async function panel(job: Job): Promise<{ data: Buffer; file: string }> {
  const gen = await fal<{ images: Array<{ url: string }> }>("fal-ai/flux-pro/v1.1", {
    prompt: job.prompt,
    image_size: { width: 1024, height: 576 },
    num_images: 1,
    output_format: "png",
  });
  const url = gen.images?.[0]?.url;
  if (!url) throw new Error("flux-pro returned no image");
  const raw = await download(url);
  try {
    const sharp = (await import("sharp")).default;
    return { data: await sharp(raw).webp({ quality: 85 }).toBuffer(), file: job.file };
  } catch {
    console.warn("  sharp unavailable; saving PNG instead of WebP");
    return { data: raw, file: job.file.replace(/\.webp$/, ".png") };
  }
}

/** flux concept image -> Trellis image-to-3D: GLB. */
async function model(job: Job): Promise<Buffer> {
  const concept = await flux(job.prompt, { width: 1024, height: 1024 });
  const res = await fal<{ model_mesh?: { url: string } }>("fal-ai/trellis", {
    image_url: concept,
    texture_size: 1024,
    mesh_simplify: 0.95,
  });
  if (!res.model_mesh?.url) throw new Error("trellis returned no mesh");
  return download(res.model_mesh.url);
}

const exists = (p: string) => access(p).then(() => true, () => false);

async function main(): Promise<void> {
  if (!FAL_KEY) {
    console.warn("[fetch-assets] FAL_KEY not set — skipping. Procedural fallback textures will be used.");
    return;
  }
  for (const job of JOBS) {
    const dest = resolve(ROOT, job.file);
    if (!FORCE && (await exists(dest))) {
      console.log(`[fetch-assets] ${job.file} exists (use --force to regenerate)`);
      continue;
    }
    console.log(`[fetch-assets] generating ${job.file} ...`);
    try {
      let data: Buffer;
      let out = dest;
      if (job.kind === "sprite") data = await sprite(job);
      else if (job.kind === "panel") {
        const p = await panel(job);
        data = p.data;
        out = resolve(ROOT, p.file);
      } else data = await model(job);
      await mkdir(dirname(out), { recursive: true });
      await writeFile(out, data);
      console.log(`  saved ${out.replace(ROOT + "/", "")} (${data.length} bytes)`);
    } catch (err) {
      console.warn(`  failed: ${(err as Error).message}\n  -> falling back to procedural placeholder at runtime`);
    }
  }
}

main().catch((err) => {
  console.warn("[fetch-assets] unexpected error:", err);
}); // always exit 0
