"""Turn the author's voice-over recordings (MP3) into game audio for the opening tagline.

Each recording is levelled to the same loudness as the game's own sound (rain ~-19.5 LUFS, like the
intro video): measured once with loudnorm, then encoded with the measured values (two-pass, linear,
so the voice keeps its natural rise and fall). Mono Ogg Vorbis. An optional end time cuts off the
tail (a word the voice got wrong), with a short fade so the cut does not click.

Usage:
  python3 tools/prepare_voice.py IN.mp3 OUT.ogg [END_SECONDS]
"""
import json
import subprocess
import sys

TARGET = "I=-19.5:TP=-1.5:LRA=11"


def main():
    src, out = sys.argv[1], sys.argv[2]
    cut = []
    if len(sys.argv) > 3:
        end = float(sys.argv[3])
        cut = [f"atrim=0:{end}", f"afade=t=out:st={end - 0.07:.3f}:d=0.07", "apad=pad_dur=0.3"]
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
