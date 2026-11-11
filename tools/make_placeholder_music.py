"""Synthesizes the two placeholder music cues that no licensed track covers yet:

  godot/assets/bgm/ph_boss.ogg         boss loop: taiko-style drums, a gong ostinato, a low drone (seamless loop)
  godot/assets/bgm/ph_cliffhanger.ogg  cliffhanger sting: a boom, a rising cluster, one clock tick (one-shot)

Run:  python3 tools/make_placeholder_music.py   (needs numpy and ffmpeg with libvorbis)
Made from scratch for this project and dedicated to the public domain (CC0 1.0). Replace them by dropping real
tracks in and pointing the cue at them in godot/data/music.json (see godot/assets/bgm/CREDITS.md).
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "godot", "assets", "bgm")
rng = np.random.default_rng(7)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def drum(length, f0, f1, decay, noise=0.25):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env(n, 0.002, decay)
    hit = rng.standard_normal(n) * env(n, 0.001, 0.02) * noise
    return body + hit


def gong(length, f, decay):
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp in [(1.0, 1.0), (2.01, 0.5), (2.76, 0.35), (4.07, 0.2), (5.4, 0.1)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t + rng.random() * 6)
    return out * env(n, 0.004, decay)


def place(buf, clip, at):
    i = int(at * SR) % len(buf)
    end = i + len(clip)
    if end <= len(buf):
        buf[i:end] += clip
    else: # wrap around so the loop stays seamless
        k = len(buf) - i
        buf[i:] += clip[:k]
        buf[: len(clip) - k] += clip[k:]


def write_ogg(name, stereo, quality=5):
    stereo = stereo / max(1e-9, np.max(np.abs(stereo))) * 0.89
    pcm = (stereo * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality),
                        "-metadata", "title=" + name, "-metadata", "copyright=CC0 1.0 (Balete placeholder)",
                        os.path.join(OUT, name + ".ogg")], check=True)


def boss():
    bpm = 138.0
    beat = 60.0 / bpm
    bars = 24
    total = bars * 4 * beat
    n = int(total * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    t = np.arange(n) / SR
    # Low drone: A1 and E2, slowly beating.
    drone = 0.22 * (np.sin(2 * np.pi * 55.0 * t) + 0.6 * np.sin(2 * np.pi * 82.6 * t) + 0.25 * np.sin(2 * np.pi * 110.3 * t))
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * t / total * 4) # 4 swells per loop, so it wraps cleanly
    left += drone
    right += drone
    big = drum(1.2, 120, 48, 0.42)
    mid = drum(0.6, 220, 110, 0.18, 0.4)
    rim = drum(0.15, 900, 600, 0.03, 0.8) * 0.35
    pattern_big = [0, 1.5, 2.5]
    pattern_mid = [1, 3, 3.5]
    for bar in range(bars):
        b0 = bar * 4 * beat
        for x in pattern_big:
            place(left, big * 0.9, b0 + x * beat)
            place(right, big * 0.9, b0 + x * beat)
        if bar >= 4:
            for x in pattern_mid:
                place(left, mid * 0.55, b0 + x * beat)
                place(right, mid * 0.7, b0 + x * beat + 0.004)
        if bar >= 8:
            for k in range(8):
                pan = 0.6 if k % 2 else 0.3
                place(left, rim * (1 - pan), b0 + k * 0.5 * beat)
                place(right, rim * pan, b0 + k * 0.5 * beat)
    # Gong ostinato (A minor pentatonic-ish, kulintang-like), from bar 4.
    notes = [220.0, 261.6, 293.7, 329.6, 392.0, 440.0]
    figure = [0, 2, 1, 3, 2, 4, 3, 5, 4, 2, 3, 1, 2, 0, 1, 2]
    for bar in range(4, bars):
        b0 = bar * 4 * beat
        for k in range(8):
            f = notes[figure[(bar * 8 + k) % len(figure)]]
            g = gong(0.9, f, 0.35) * 0.16
            place(left, g * 0.8, b0 + k * 0.5 * beat)
            place(right, g * 1.0, b0 + k * 0.5 * beat + 0.006)
    return np.stack([left, right], axis=1)


def sting():
    total = 7.0
    n = int(total * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    out[: int(1.6 * SR)] += drum(1.6, 90, 38, 0.7, 0.5) * 1.2
    # A rising, dissonant cluster that swells and is cut off.
    swell = np.clip((t - 0.4) / 4.2, 0, 1) ** 2
    cut = np.where(t < 4.8, 1.0, np.exp(-(t - 4.8) * 9))
    for f in [146.8, 155.6, 207.7, 220.0, 311.1]:
        rise = f * (1 + 0.06 * swell)
        ph = 2 * np.pi * np.cumsum(rise) / SR
        out += 0.12 * (np.sin(ph) + 0.3 * np.sin(2 * ph)) * swell * cut
    # One clock tick in the silence after the cut.
    tick = drum(0.08, 2600, 1800, 0.012, 1.0) * 0.6
    i = int(5.6 * SR)
    out[i : i + len(tick)] += tick
    tail = np.exp(-np.clip(t - 6.4, 0, None) * 12)
    out *= tail
    return np.stack([out, out * 0.96], axis=1)


if __name__ == "__main__":
    write_ogg("ph_boss", boss())
    write_ogg("ph_cliffhanger", sting())
    print("wrote ph_boss.ogg and ph_cliffhanger.ogg to", os.path.normpath(OUT))
