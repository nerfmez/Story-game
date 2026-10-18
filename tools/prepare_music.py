"""Turn a music track (MP3) into a looping game track: plays from the start once, then loops a section.

The end of the loop is crossfaded with the music just before the loop start, so the jump from
LOOP_END back to LOOP_START (Godot's loop_offset) is seamless even when the two passages are not
sample-identical (AI-made music never repeats exactly). Levelled with loudnorm (two-pass, linear)
to TARGET LUFS, stereo Ogg Vorbis. Set loop = true and loop_offset = LOOP_START in the .import file.

Usage:
  python3 tools/prepare_music.py IN.mp3 OUT.ogg LOOP_START LOOP_END [TARGET_LUFS]
"""
import json
import subprocess
import sys
import tempfile

import numpy as np

SR = 44100
CROSSFADE = 2.0


def main():
    src, out = sys.argv[1], sys.argv[2]
    start, end = float(sys.argv[3]), float(sys.argv[4])
    target = f"I={sys.argv[5] if len(sys.argv) > 5 else -20.0}:TP=-1.5:LRA=11"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    a = np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
    s, e, x = int(start * SR), int(end * SR), int(CROSSFADE * SR)
    track = a[:e].copy()
    ramp = np.sin(np.linspace(0, np.pi / 2, x))[:, None] ** 2          # equal-power-ish fade
    track[e - x:e] = a[e - x:e] * (1 - ramp) + a[s - x:s] * ramp
    with tempfile.NamedTemporaryFile(suffix=".f32") as tmp:
        tmp.write(track.astype(np.float32).tobytes())
        tmp.flush()
        pcm = ["-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", tmp.name]
        first = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", *pcm, "-af", f"loudnorm={target}:print_format=json",
                                "-f", "null", "-"], capture_output=True, text=True).stderr
        m = json.loads(first[first.rindex("{"):first.rindex("}") + 1])
        norm = (f"loudnorm={target}:linear=true:measured_I={m['input_i']}:measured_TP={m['input_tp']}"
                f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}")
        # loudnorm resamples internally; force back to 44.1 kHz so loop_offset stays in seconds of the source
        subprocess.run(["ffmpeg", "-v", "error", "-y", *pcm, "-af", norm, "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "6", out],
                       check=True)
    print(f"{src} ({m['input_i']} LUFS) -> {out}: {end:.2f} s, loop {start:.2f}-{end:.2f}")


if __name__ == "__main__":
    main()
