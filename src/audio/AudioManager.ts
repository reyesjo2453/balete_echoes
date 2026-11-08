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

  // --- Procedural SFX (Web Audio, no files). No-ops until unlock() has run. ---

  private noiseBuffer: AudioBuffer | null = null;

  private noise(): AudioBufferSourceNode {
    const ctx = this.ctx!;
    if (!this.noiseBuffer) {
      this.noiseBuffer = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
      const d = this.noiseBuffer.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    }
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    src.loop = true;
    return src;
  }

  /** Gain node with attack/exp-decay envelope, routed to master. */
  private env(peak: number, attack: number, duration: number): GainNode {
    const ctx = this.ctx!;
    const g = ctx.createGain();
    const t = ctx.currentTime;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + duration);
    g.connect(this.master!);
    return g;
  }

  /** 0.08s amplitude-modulated noise sweep (weapon swing). */
  playSlash(): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const dur = 0.08;
    const src = this.noise();
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.Q.value = 2.5;
    bp.frequency.setValueAtTime(700, t);
    bp.frequency.exponentialRampToValueAtTime(5200, t + dur);
    // Tremolo-style modulation for a "whoosh" texture.
    const mod = ctx.createGain();
    mod.gain.value = 0.6;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 70;
    const lfoDepth = ctx.createGain();
    lfoDepth.gain.value = 0.4;
    lfo.connect(lfoDepth).connect(mod.gain);
    src.connect(bp).connect(mod).connect(this.env(0.5, 0.01, dur));
    src.start(t);
    lfo.start(t);
    src.stop(t + dur + 0.02);
    lfo.stop(t + dur + 0.02);
  }

  /** 0.12s dual-frequency impact thud. */
  playHit(): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const dur = 0.12;
    const out = this.env(0.9, 0.004, dur);
    const sweep = (type: OscillatorType, from: number, to: number, level: number) => {
      const o = ctx.createOscillator();
      o.type = type;
      o.frequency.setValueAtTime(from, t);
      o.frequency.exponentialRampToValueAtTime(to, t + dur);
      const g = ctx.createGain();
      g.gain.value = level;
      o.connect(g).connect(out);
      o.start(t);
      o.stop(t + dur + 0.02);
    };
    sweep("sine", 150, 45, 0.8); // low body
    sweep("triangle", 340, 110, 0.5); // upper crack
  }

  /** Resonant metallic 3-tone chord (stagger break). */
  playStaggerBreak(): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const dur = 1.1;
    const out = this.env(0.45, 0.005, dur);
    const res = ctx.createBiquadFilter();
    res.type = "peaking";
    res.frequency.value = 2400;
    res.Q.value = 14;
    res.gain.value = 10;
    res.connect(out);
    // Slightly inharmonic stack reads as struck metal.
    for (const f of [523.25, 784.0, 1174.7]) {
      const o = ctx.createOscillator();
      o.type = "square";
      o.frequency.value = f;
      o.detune.value = (Math.random() - 0.5) * 14;
      const g = ctx.createGain();
      g.gain.value = 0.22;
      o.connect(g).connect(res);
      o.start(t);
      o.stop(t + dur + 0.05);
    }
  }

  private commandSweep(fromHz: number, toHz: number, pitchFrom: number, pitchTo: number): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const dur = 0.35;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.Q.value = 6;
    lp.frequency.setValueAtTime(fromHz, t);
    lp.frequency.exponentialRampToValueAtTime(toHz, t + dur);
    lp.connect(this.env(0.35, 0.03, dur));
    const o = ctx.createOscillator();
    o.type = "sawtooth";
    o.frequency.setValueAtTime(pitchFrom, t);
    o.frequency.exponentialRampToValueAtTime(pitchTo, t + dur);
    o.connect(lp);
    const n = this.noise();
    const ng = ctx.createGain();
    ng.gain.value = 0.25;
    n.connect(ng).connect(lp);
    for (const node of [o, n]) {
      node.start(t);
      node.stop(t + dur + 0.02);
    }
  }

  /** Time dilation engages: filter closes, pitch sinks. */
  playCommandEnter(): void {
    this.commandSweep(6000, 300, 440, 110);
  }

  /** Time dilation releases: filter opens, pitch rises. */
  playCommandExit(): void {
    this.commandSweep(300, 6000, 110, 440);
  }

  /** Triumphant 4-note fanfare (C5 E5 G5 C6) with a sustained final chord. */
  playVictoryJingle(): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t0 = ctx.currentTime;
    const notes = [523.25, 659.25, 783.99, 1046.5];
    notes.forEach((f, i) => {
      const t = t0 + i * 0.16;
      const last = i === notes.length - 1;
      const dur = last ? 1.3 : 0.22;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.3, t + 0.015);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      g.connect(this.master!);
      const voices: Array<[OscillatorType, number, number]> = [["square", f, 0.35], ["triangle", f * 2, 0.4]];
      if (last) voices.push(["triangle", f * 0.75, 0.3], ["triangle", f * 1.25, 0.3]); // fuller final chord
      for (const [type, freq, level] of voices) {
        const o = ctx.createOscillator();
        o.type = type;
        o.frequency.value = freq;
        const vg = ctx.createGain();
        vg.gain.value = level;
        o.connect(vg).connect(g);
        o.start(t);
        o.stop(t + dur + 0.05);
      }
    });
  }

  /** Heavy sub-bass drop with a noise impact (Bayanihan finisher). */
  playBassDrop(): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const dur = 1.2;
    const out = this.env(1, 0.01, dur);
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(140, t);
    o.frequency.exponentialRampToValueAtTime(28, t + 0.6);
    const og = ctx.createGain();
    og.gain.value = 1;
    o.connect(og).connect(out);
    o.start(t);
    o.stop(t + dur + 0.05);
    const n = this.noise();
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.setValueAtTime(2500, t);
    lp.frequency.exponentialRampToValueAtTime(80, t + 0.4);
    const ng = ctx.createGain();
    ng.gain.value = 0.6;
    n.connect(lp).connect(ng).connect(out);
    n.start(t);
    n.stop(t + 0.5);
  }

  registerSfx(name: string, src: string | string[], volume = 1): void {
    this.sfx.set(name, new Howl({ src: Array.isArray(src) ? src : [src], volume, preload: true }));
  }

  playSfx(name: string): void {
    this.sfx.get(name)?.play();
  }
}
