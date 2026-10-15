"""Synthesize the ambient sounds of the sunset railway scene (no recorded samples).

Outputs (assets/audio/, Ogg Vorbis):
  ambience_evening.ogg  24 s seamless loop: city hum, breeze, crickets, a cicada swell
                        (only things you hear but don't see; birds and the train make
                        their sounds when they are on screen)
  train_pass.ogg        3.2 s seamless loop of a train on a viaduct: rumble, motor
                        whine and the clack-clack of the wheels over rail joints
  car_pass.ogg          2 s seamless loop of a car on the wet road: tyre hiss on water,
                        low engine hum (the game fades it in/out and bends the pitch)
  step_1..3.ogg         footsteps on wet asphalt (soft scuff + tiny splash)
  bird_1..3.ogg         short calls of a small bird (2-4 tweets), played by the flocks

Everything that loops is built circularly (noise shaped in the frequency domain,
events wrapped around the end), so the loops have no seam.

Usage: python3 tools/make_audio.py   (needs ffmpeg with libvorbis)
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
SR = 22050
rng = np.random.default_rng(21)


def shaped_noise(n, lo, hi, tilt=0.0):
    """Circular noise with energy between lo and hi Hz (soft edges); tilt < 0 = darker.
    Being built from whole-period sinusoids, it loops perfectly over n samples."""
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    band = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    band *= np.maximum(f, 20) ** tilt
    x = np.fft.irfft(spec * band, n)
    return x / (np.abs(x).max() + 1e-9)


def slow_lfo(n, cycles, depth, phase=0.0):
    """Periodic slow wobble (whole number of cycles per loop)."""
    t = np.arange(n) / n
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * cycles * t + phase))


def place(buf, event, at, loop=True):
    """Add an event at sample `at`, wrapping round the end of a loop."""
    n = len(event)
    idx = (np.arange(n) + at) % len(buf) if loop else np.arange(at, min(at + n, len(buf)))
    buf[idx] += event[:len(idx)]


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def ambience(seconds=24):
    n = SR * seconds
    t = np.arange(n) / SR
    out = np.zeros(n)
    out += 0.16 * shaped_noise(n, 25, 180, -0.6) * slow_lfo(n, 2, 0.3)          # city hum
    out += 0.05 * shaped_noise(n, 250, 1400) * slow_lfo(n, 3, 0.8, 1.3)         # breeze
    for f0, amp, period in ((4300, 0.022, 0.62), (4750, 0.016, 0.83), (3900, 0.012, 1.07)):
        chirp_len = int(0.11 * SR)                                               # crickets
        tt = np.arange(chirp_len) / SR
        pulses = (np.sin(2 * np.pi * 28 * tt) > 0.2).astype(float)               # 3 pulses
        chirp = np.sin(2 * np.pi * f0 * tt) * pulses * env(chirp_len, 0.005, 0.02)
        k = 0.0
        while k < seconds:
            place(out, amp * chirp * rng.uniform(0.6, 1.0), int(k * SR))
            k += period * rng.uniform(0.85, 1.15)
    cic_len = int(7 * SR)                                                        # cicada swell
    tt = np.arange(cic_len) / SR
    buzz = np.sin(2 * np.pi * 5400 * tt + 3 * np.sin(2 * np.pi * 110 * tt))
    buzz *= 0.5 * (1 + np.sin(2 * np.pi * 95 * tt))
    swell = np.sin(np.pi * tt / 7) ** 2
    place(out, 0.014 * buzz * swell, int(9 * SR))
    return out * 0.9


def train_loop(seconds=3.2):
    n = int(SR * seconds)
    out = 0.32 * shaped_noise(n, 30, 420, -0.4)                                  # rumble
    t = np.arange(n) / SR
    whine = np.sin(2 * np.pi * 620 * t) + 0.4 * np.sin(2 * np.pi * 1240 * t)
    out += 0.025 * whine * slow_lfo(n, 4, 0.5)
    ln = int(0.09 * SR)                                                          # one clack
    tt = np.arange(ln) / SR
    clack = shaped_noise(ln, 300, 2600) * np.exp(-tt * 55)
    clack += 0.6 * np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 40)
    for car_start in (0.0, 1.6):            # a car every 1.6 s: two bogies, two axles each
        for bogie in (0.0, 1.15):
            for axle in (0.0, 0.13):
                place(out, 0.35 * clack * rng.uniform(0.8, 1.0), int((car_start + bogie + axle) * SR))
    return out


def car_loop(seconds=2.0):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    out = 0.5 * shaped_noise(n, 900, 6000, -0.2) * slow_lfo(n, 6, 0.25)        # tyres on water
    out += 0.3 * shaped_noise(n, 40, 260, -0.5)                                # road rumble
    hum = np.sin(2 * np.pi * 75 * t) + 0.5 * np.sin(2 * np.pi * 150 * t) + 0.2 * np.sin(2 * np.pi * 225 * t)
    out += 0.12 * hum * slow_lfo(n, 2, 0.3)                                    # engine
    return out


def bird_call(seed):
    """A few quick rising tweets, like a small bird calling to the flock."""
    r = np.random.default_rng(seed)
    out = np.zeros(int(0.6 * SR))
    at = 0.0
    for _ in range(r.integers(2, 5)):
        ln = int(r.uniform(0.05, 0.09) * SR)
        f = np.linspace(r.uniform(2600, 3200), r.uniform(3900, 4700), ln)
        f += 300 * np.sin(np.linspace(0, np.pi, ln))
        tweet = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(ln, 0.006, 0.03)
        place(out, tweet * r.uniform(0.7, 1.0), int(at * SR), loop=False)
        at += ln / SR + r.uniform(0.03, 0.08)
    return out[: int((at + 0.05) * SR)]


def step(seed):
    r = np.random.default_rng(seed)
    ln = int(0.16 * SR)
    tt = np.arange(ln) / SR
    global rng
    keep, rng = rng, r
    scuff = shaped_noise(ln, 120, 1800, -0.3) * np.exp(-tt * 38)
    splash = shaped_noise(ln, 2500, 7000) * np.exp(-np.maximum(tt - 0.015, 0) * 70) * (tt > 0.012)
    rng = keep
    out = 0.55 * scuff + 0.22 * splash
    out[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    return out


def save_ogg(name, x, peak=0.8):
    x = x / (np.abs(x).max() + 1e-9) * peak
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "a.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        str(OUT / name)], check=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save_ogg("ambience_evening.ogg", ambience(), 0.7)
    save_ogg("train_pass.ogg", train_loop(), 0.8)
    save_ogg("car_pass.ogg", car_loop(), 0.8)
    for i in range(3):
        save_ogg(f"step_{i + 1}.ogg", step(100 + i), 0.6)
        save_ogg(f"bird_{i + 1}.ogg", bird_call(200 + i), 0.6)
    print("audio written to", OUT)
