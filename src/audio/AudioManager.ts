import { Howl } from "howler";

export type StemName = "ambient" | "rhythm" | "climax";

interface Stem {
  buffer: AudioBuffer | null;
  source: AudioBufferSourceNode | null;
  gain: GainNode;
}

/** Stem mix presets keyed by intensity tier. */
const MIXES: Record<"explore" | "combat" | "climax", Record<StemName, number>> = {
  explore: { ambient: 1, rhythm: 0, climax: 0 },
  combat: { ambient: 0.6, rhythm: 1, climax: 0 },
  climax: { ambient: 0.3, rhythm: 1, climax: 1 },
};

/**
 * Multi-stem BGM via the Web Audio API: all stems start on the same
 * AudioContext timestamp so they stay sample-locked, and intensity changes
 * crossfade per-stem gain. One-shot SFX go through Howler.
 */
export class AudioManager {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private readonly stems = new Map<StemName, Stem>();
  private readonly sfx = new Map<string, Howl>();
  private playing = false;

  /**
   * Must be called from a user gesture (browser autoplay policy).
   * Safe to call repeatedly.
   */
  async unlock(): Promise<void> {
    if (!this.ctx) {
      this.ctx = new AudioContext();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.8;
      this.master.connect(this.ctx.destination);
    }
    if (this.ctx.state === "suspended") await this.ctx.resume();
  }

  /** Fetch + decode loopable stems. Missing files are skipped with a warning. */
  async loadStems(urls: Partial<Record<StemName, string>>): Promise<void> {
    await this.unlock();
    const ctx = this.ctx!;
    await Promise.all(
      (Object.entries(urls) as Array<[StemName, string]>).map(async ([name, url]) => {
        const gain = ctx.createGain();
        gain.gain.value = 0;
        gain.connect(this.master!);
        const stem: Stem = { buffer: null, source: null, gain };
        this.stems.set(name, stem);
        try {
          const res = await fetch(url);
          if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
          stem.buffer = await ctx.decodeAudioData(await res.arrayBuffer());
        } catch (err) {
          console.warn(`[AudioManager] stem "${name}" unavailable (${url}):`, err);
        }
      })
    );
  }

  /** Start every loaded stem on one shared timestamp. */
  play(mix: keyof typeof MIXES = "explore"): void {
    if (!this.ctx || this.playing) return;
    const startAt = this.ctx.currentTime + 0.1;
    for (const stem of this.stems.values()) {
      if (!stem.buffer) continue;
      const src = this.ctx.createBufferSource();
      src.buffer = stem.buffer;
      src.loop = true;
      src.connect(stem.gain);
      src.start(startAt);
      stem.source = src;
    }
    this.playing = true;
    this.setMix(mix, 0.05);
  }

  stop(): void {
    for (const stem of this.stems.values()) {
      stem.source?.stop();
      stem.source?.disconnect();
      stem.source = null;
    }
    this.playing = false;
  }

  /** Crossfade stem gains to a preset over `seconds`. */
  setMix(mix: keyof typeof MIXES, seconds = 1.5): void {
    const levels = MIXES[mix];
    for (const [name, level] of Object.entries(levels) as Array<[StemName, number]>) {
      this.fadeStem(name, level, seconds);
    }
  }

  fadeStem(name: StemName, level: number, seconds = 1.5): void {
    const stem = this.stems.get(name);
    if (!stem || !this.ctx) return;
    const now = this.ctx.currentTime;
    const g = stem.gain.gain;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value, now);
    // Equal-power-ish curve: ramp in linear space over a short time constant.
    g.setTargetAtTime(level, now, Math.max(0.01, seconds / 4));
  }

  setMasterVolume(v: number): void {
    if (this.master && this.ctx) this.master.gain.setTargetAtTime(v, this.ctx.currentTime, 0.05);
  }

  registerSfx(name: string, src: string | string[], volume = 1): void {
    this.sfx.set(name, new Howl({ src: Array.isArray(src) ? src : [src], volume, preload: true }));
  }

  playSfx(name: string): void {
    this.sfx.get(name)?.play();
  }
}
