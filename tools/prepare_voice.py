"""Turn the author's voice-over recordings (MP3) into game audio for the opening tagline.

Each recording is levelled to the same loudness as the game's own sound (rain ~-19.5 LUFS, like the
intro video): measured once with loudnorm, then encoded with the measured values (two-pass, linear,
so the voice keeps its natural rise and fall). Mono Ogg Vorbis.
  --end S       cut off the tail from S seconds (a word the voice got wrong), fading out over the
                last 0.1 s so the word before it does not end abruptly
  --gap A-B     take out the stretch A..B seconds (a pause that drags), short crossfade at the join

Usage:
  python3 tools/prepare_voice.py IN.mp3 OUT.ogg [--end S] [--gap A-B]
"""
import argparse
import json
import subprocess

TARGET = "I=-19.5:TP=-1.5:LRA=11"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--end", type=float)
    ap.add_argument("--gap")
    args = ap.parse_args()
    src, out = args.src, args.out
    cut = []
    if args.gap:
        a, b = (float(v) for v in args.gap.split("-"))
        cut = [f"asplit[x][y];[x]atrim=0:{a + 0.02}[p];[y]atrim={b - 0.02},asetpts=PTS-STARTPTS[q];"
               "[p][q]acrossfade=d=0.04"]
    if args.end is not None:
        cut += [f"atrim=0:{args.end}", f"afade=t=out:st={args.end - 0.1:.3f}:d=0.1", "apad=pad_dur=0.3"]
    first = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", src, "-af", ",".join(cut + [f"loudnorm={TARGET}:print_format=json"]),
         "-f", "null", "-"], capture_output=True, text=True).stderr
    m = json.loads(first[first.rindex("{"):first.rindex("}") + 1])
    norm = (f"loudnorm={TARGET}:linear=true:measured_I={m['input_i']}:measured_TP={m['input_tp']}"
            f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", ",".join(cut + [norm]), "-ac", "1", "-ar", "44100",
                    "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    print(f"{src} ({m['input_i']} LUFS) -> {out}")


if __name__ == "__main__":
    main()
