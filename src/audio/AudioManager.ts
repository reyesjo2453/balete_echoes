import { Howl } from "howler";

export type StemName = "ambient" | "rhythm" | "climax";

interface Stem {
  buffer: AudioBuffer | null;
  source: AudioBufferSourceNode | null;
  gain: GainNode;
}

/** Which file-based BGM track should be sounding. */
export type BgmScene = "title" | "exploration" | "combat";

interface BgmTrack {
  url: string;
  /** Seamless loop (combat) vs composed arc that gets a crossfaded restart. */
  loop: boolean;
  volume: number;
  howl: Howl | null;
  failed: boolean;
}

/** BGM sits well under SFX (procedural SFX peak ~0.5-1.0 of master). */
const BGM_TRACKS: Record<BgmScene, { url: string; loop: boolean; volume: number }> = {
  title: { url: "/assets/audio/bgm/aphelion.mp3", loop: false, volume: 0.3 },
  exploration: { url: "/assets/audio/bgm/undertow.mp3", loop: false, volume: 0.3 },
  combat: { url: "/assets/audio/bgm/determined-pursuit.mp3", loop: true, volume: 0.35 },
};
const BGM_SWITCH_FADE = 1.5; // seconds, track-to-track crossfade
const BGM_WRAP_FADE = 4; // seconds, crossfaded restart for non-loop arcs

/** Game-state driven mix for the procedural BGM. */
export type BgmState = "EXPLORATION" | "COMBAT" | "STAGGERED" | "BAYANIHAN";

const BGM_LEVELS: Record<BgmState, Record<StemName, number>> = {
  EXPLORATION: { ambient: 1, rhythm: 0, climax: 0 },
  COMBAT: { ambient: 1, rhythm: 1, climax: 0 },
  STAGGERED: { ambient: 1, rhythm: 1, climax: 1 },
  BAYANIHAN: { ambient: 1, rhythm: 1, climax: 1 },
};
const BGM_FADE = 0.6;
const BPM = 92;
const STEP = 60 / BPM / 4; // 16th note, seconds
const LOOP_STEPS = 64; // 4 bars; the loop is generated, so the seam is sample-accurate
const LOOKAHEAD = 0.2;
// Am | F | C | G
const CHORDS = [
  [220, 261.63, 329.63, 440],
  [174.61, 220, 261.63, 349.23],
  [261.63, 329.63, 392, 523.25],
  [196, 246.94, 293.66, 392],
];
const ROOTS = [55, 43.65, 65.41, 49];
const ARP = [0, 1, 2, 3, 2, 1, 2, 1];
const KULINTANG_STEPS = [0, 3, 6, 8, 11, 14];
const SUB_STEPS = [0, 6, 10];
const OSTINATO = [0, 0, 12, 0, 0, 7, 0, 5, 0, 0, 12, 0, 3, 0, 7, 0];

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
  private bgmGains: Record<StemName, GainNode> | null = null;
  private bgmTimer = 0;
  private bgmStep = 0;
  private bgmNext = 0;
  private bgmState: BgmState = "EXPLORATION";
  private bgmBus: GainNode | null = null;
  private readonly bgmFiles = new Map<BgmScene, BgmTrack>();
  private bgmFileScene: BgmScene | null = null;
  private bgmWanted: BgmScene | null = null;
  private bgmCurrent: { scene: BgmScene; id: number } | null = null;
  private bgmWrapTimer = 0;
  private bgmVolume = 1;

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
    this.bgmVolume = v / 0.8; // file BGM is Howler-routed, so track the master level here
    const cur = this.bgmCurrent;
    const track = cur && this.bgmFiles.get(cur.scene);
    if (cur && track?.howl) track.howl.volume(track.volume * this.bgmVolume, cur.id);
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

  // --- Procedural adaptive BGM: ambient / combat rhythm / climax stems ---

  /** Start the generated 3-stem loop (needs unlock() first). Ambient is always audible. */
  startBgm(): void {
    if (!this.ctx || !this.master || this.bgmTimer) return;
    const ctx = this.ctx;
    const mk = (level: number): GainNode => {
      const g = ctx.createGain();
      g.gain.value = level;
      g.connect(this.procBus());
      return g;
    };
    const gains = { ambient: mk(1), rhythm: mk(0), climax: mk(0) };
    this.bgmGains = gains;

    // Soft rain: filtered noise bed living in the ambient stem.
    const rain = this.noise();
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 1200;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = 7000;
    const rg = ctx.createGain();
    rg.gain.value = 0.05;
    rain.connect(hp).connect(lp).connect(rg).connect(gains.ambient);
    rain.start();

    this.bgmStep = 0;
    this.bgmNext = ctx.currentTime + 0.1;
    this.setBgmState(this.bgmState, 0.01);
    this.bgmTimer = window.setInterval(() => this.scheduleBgm(), 25);
  }

  /** Crossfade stems to match the game state (gain ramps, 0.6s). */
  setBgmState(state: BgmState, seconds = BGM_FADE): void {
    this.bgmState = state;
    if (!this.ctx || !this.bgmGains) return;
    const now = this.ctx.currentTime;
    for (const [name, level] of Object.entries(BGM_LEVELS[state]) as Array<[StemName, number]>) {
      const g = this.bgmGains[name].gain;
      g.cancelScheduledValues(now);
      g.setValueAtTime(g.value, now);
      g.linearRampToValueAtTime(level, now + seconds);
    }
  }

  get bgmMix(): BgmState {
    return this.bgmState;
  }

  private scheduleBgm(): void {
    const ctx = this.ctx;
    if (!ctx) return;
    // After a throttled/backgrounded tab, resume from "now" instead of bursting old steps.
    if (this.bgmNext < ctx.currentTime - 0.25) this.bgmNext = ctx.currentTime + 0.05;
    while (this.bgmNext < ctx.currentTime + LOOKAHEAD) {
      this.bgmStepAt(this.bgmStep, this.bgmNext);
      this.bgmStep = (this.bgmStep + 1) % LOOP_STEPS;
      this.bgmNext += STEP;
    }
  }

  private bgmStepAt(step: number, t: number): void {
    const bar = Math.floor(step / 16) % 4;
    const inBar = step % 16;
    const g = this.bgmGains!;

    // Ambient: bandurria-like pluck arpeggio on every 8th.
    if (inBar % 2 === 0) {
      const f = CHORDS[bar][ARP[inBar / 2]] * (inBar === 0 ? 1 : 2);
      this.pluck(f, t, g.ambient, 0.14);
    }

    // Combat: syncopated kulintang bells + sub-bass pulse.
    if (KULINTANG_STEPS.includes(inBar)) {
      const chord = CHORDS[bar];
      this.bell(chord[(inBar + bar) % 4] * 2, t, g.rhythm);
    }
    if (SUB_STEPS.includes(inBar)) this.subPulse(ROOTS[bar], t, g.rhythm);

    // Climax: sawtooth string ostinato through a resonant low-pass.
    this.stringHit(ROOTS[bar] * 4 * 2 ** (OSTINATO[inBar] / 12), t, g.climax, inBar % 4 === 0);
  }

  /** Fast-decay triangle pluck. */
  private pluck(freq: number, t: number, out: AudioNode, level: number): void {
    const ctx = this.ctx!;
    const o = ctx.createOscillator();
    o.type = "triangle";
    o.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(level, t);
    g.gain.exponentialRampToValueAtTime(0.0005, t + 0.45);
    o.connect(g).connect(out);
    o.start(t);
    o.stop(t + 0.5);
  }

  /** Tuned bell: fundamental + inharmonic partial. */
  private bell(freq: number, t: number, out: AudioNode): void {
    const ctx = this.ctx!;
    for (const [mult, level, dur] of [[1, 0.16, 0.5], [2.76, 0.07, 0.25]] as const) {
      const o = ctx.createOscillator();
      o.type = "sine";
      o.frequency.value = freq * mult;
      const g = ctx.createGain();
      g.gain.setValueAtTime(level, t);
      g.gain.exponentialRampToValueAtTime(0.0005, t + dur);
      o.connect(g).connect(out);
      o.start(t);
      o.stop(t + dur + 0.02);
    }
  }

  private subPulse(freq: number, t: number, out: AudioNode): void {
    const ctx = this.ctx!;
    for (const [mult, level] of [[1, 0.5], [2, 0.18]] as const) {
      const o = ctx.createOscillator();
      o.type = mult === 1 ? "sine" : "triangle";
      o.frequency.setValueAtTime(freq * mult * 1.5, t);
      o.frequency.exponentialRampToValueAtTime(freq * mult, t + 0.06);
      const g = ctx.createGain();
      g.gain.setValueAtTime(level, t);
      g.gain.exponentialRampToValueAtTime(0.0005, t + 0.22);
      o.connect(g).connect(out);
      o.start(t);
      o.stop(t + 0.25);
    }
  }

  private stringHit(freq: number, t: number, out: AudioNode, accent: boolean): void {
    const ctx = this.ctx!;
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.Q.value = 9;
    lp.frequency.setValueAtTime(accent ? 1800 : 900, t);
    lp.frequency.exponentialRampToValueAtTime(500, t + 0.14);
    const g = ctx.createGain();
    g.gain.setValueAtTime(accent ? 0.11 : 0.07, t);
    g.gain.exponentialRampToValueAtTime(0.0005, t + STEP * 1.6);
    lp.connect(g).connect(out);
    for (const detune of [-8, 8]) {
      const o = ctx.createOscillator();
      o.type = "sawtooth";
      o.frequency.value = freq;
      o.detune.value = detune;
      o.connect(lp);
      o.start(t);
      o.stop(t + STEP * 1.7);
    }
  }

  // --- File-based BGM: one complete song at a time (Howler, streamed), crossfaded by scene. ---

  private procBus(): GainNode {
    if (!this.bgmBus) {
      this.bgmBus = this.ctx!.createGain();
      this.bgmBus.connect(this.master!);
    }
    return this.bgmBus;
  }

  private fadeProcedural(level: number, seconds: number): void {
    if (!this.ctx) return;
    const g = this.procBus().gain;
    const now = this.ctx.currentTime;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value, now);
    g.linearRampToValueAtTime(level, now + seconds);
  }

  /** Begin streaming the BGM files. Failures only warn; the procedural stems cover for them. */
  loadBgmFiles(): void {
    for (const [scene, def] of Object.entries(BGM_TRACKS) as Array<[BgmScene, (typeof BGM_TRACKS)[BgmScene]]>) {
      if (this.bgmFiles.has(scene)) continue;
      const track: BgmTrack = { ...def, howl: null, failed: false };
      this.bgmFiles.set(scene, track);
      const fail = (what: string, err: unknown) => {
        console.warn(`[AudioManager] BGM "${scene}" ${what} (${def.url}); using procedural fallback:`, err);
        track.failed = true;
        this.applyBgmScene();
      };
      try {
        track.howl = new Howl({
          src: [def.url],
          html5: true, // stream: the files are minutes long, decoding to PCM would cost 100+ MB
          preload: true,
          volume: 0,
          onload: () => this.applyBgmScene(),
          onloaderror: (_id, err) => fail("failed to load", err),
          onplayerror: (_id, err) => fail("failed to play", err),
        });
      } catch (err) {
        fail("failed to initialise", err);
      }
    }
    if (!this.bgmWrapTimer) this.bgmWrapTimer = window.setInterval(() => this.checkBgmWrap(), 250);
  }

  private trackReady(scene: BgmScene): BgmTrack | null {
    const t = this.bgmFiles.get(scene);
    return t && t.howl && !t.failed && t.howl.state() === "loaded" ? t : null;
  }

  /**
   * Select the song for the current game scene. Plays exactly one file track at a time;
   * if that track is unavailable the procedural stems play instead. Needs unlock() first.
   */
  setBgmScene(scene: BgmScene): void {
    this.bgmWanted = scene;
    this.applyBgmScene();
  }

  private applyBgmScene(): void {
    const scene = this.bgmWanted;
    if (!scene || !this.ctx) return;
    if (this.trackReady(scene)) {
      if (this.bgmFileScene === scene) return;
      this.bgmFileScene = scene;
      this.fadeProcedural(0, BGM_SWITCH_FADE);
      this.startFileTrack(scene, BGM_SWITCH_FADE);
    } else {
      // Fallback: procedural stems (their own state machine handles exploration vs. combat).
      if (this.bgmFileScene === null && this.bgmTimer) return;
      this.bgmFileScene = null;
      this.fadeOutFileTrack(BGM_SWITCH_FADE);
      if (!this.bgmTimer) this.startBgm();
      this.fadeProcedural(1, BGM_SWITCH_FADE);
    }
  }

  private startFileTrack(scene: BgmScene, fade: number): void {
    const track = this.trackReady(scene);
    if (!track?.howl) return;
    this.fadeOutFileTrack(fade);
    const howl = track.howl;
    const id = howl.play();
    howl.loop(track.loop, id);
    howl.volume(0, id);
    howl.fade(0, track.volume * this.bgmVolume, fade * 1000, id);
    this.bgmCurrent = { scene, id };
  }

  private fadeOutFileTrack(fade: number): void {
    const cur = this.bgmCurrent;
    if (!cur) return;
    this.bgmCurrent = null;
    const howl = this.bgmFiles.get(cur.scene)?.howl;
    if (!howl) return;
    howl.fade(howl.volume(cur.id) as number, 0, fade * 1000, cur.id);
    window.setTimeout(() => howl.stop(cur.id), fade * 1000 + 100);
  }

  /** Non-looping arcs: restart with an overlapping crossfade shortly before the end. */
  private checkBgmWrap(): void {
    const cur = this.bgmCurrent;
    if (!cur) return;
    const track = this.bgmFiles.get(cur.scene);
    if (!track?.howl || track.loop) return;
    const dur = track.howl.duration();
    const pos = track.howl.seek(cur.id);
    if (typeof pos !== "number" || !dur) return;
    if (dur - pos <= BGM_WRAP_FADE) this.startFileTrack(cur.scene, BGM_WRAP_FADE);
  }

  registerSfx(name: string, src: string | string[], volume = 1): void {
    this.sfx.set(name, new Howl({ src: Array.isArray(src) ? src : [src], volume, preload: true }));
  }

  playSfx(name: string): void {
    this.sfx.get(name)?.play();
  }
}
