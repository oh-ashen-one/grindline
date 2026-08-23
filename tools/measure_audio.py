#!/usr/bin/env python3
"""Measure curated audio: duration, LUFS-I, peak dB. -> game/data/audio_metrics.json"""
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CURATED = {
    "assets/impact-sounds/Audio": [
        "impactSoft_heavy_000.ogg", "impactWood_medium_000.ogg", "impactMetal_light_000.ogg",
        "impactPlate_medium_000.ogg", "impactGeneric_light_000.ogg", "impactMining_002.ogg",
    ],
    "assets/interface-sounds/Audio": [
        "select_004.ogg", "back_004.ogg", "confirmation_001.ogg", "error_004.ogg",
        "toggle_001.ogg", "scroll_002.ogg", "click_002.ogg",
    ],
    "assets/music-jingles/Audio/8-bit-jingles": ["jingles_NES00.ogg", "jingles_NES08.ogg"],
    "assets/music": ["music_fight.ogg"],
}

def measure(p: Path) -> dict:
    dur = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(p)],
        capture_output=True, text=True).stdout.strip())
    r = subprocess.run(
        ["ffmpeg", "-nostats", "-i", str(p), "-af", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True)
    lufs = peak = None
    for line in r.stderr.splitlines():
        if "I:" in line and "LUFS" in line:
            try: lufs = float(line.split("I:")[1].split("LUFS")[0].strip())
            except ValueError: pass
        if "Peak:" in line and "dBFS" in line:
            try: peak = float(line.split("Peak:")[1].split("dBFS")[0].strip())
            except ValueError: pass
    return {"path": str(p.relative_to(ROOT)), "durationMs": round(dur*1000),
            "lufs": (lufs if lufs is not None else -70.0),
            "peakDb": (peak if peak is not None else -90.0),
            "maxFileMB": round(p.stat().st_size/1048576, 3) + 0.001}

def main():
    out = {}
    for d, files in CURATED.items():
        for f in files:
            p = ROOT / d / f
            if not p.is_file():
                print(f"MISSING {p}", file=sys.stderr); continue
            m = measure(p)
            out[m["path"]] = m
            print(f"{m['path']:60s} {m['durationMs']:6d}ms {m['lufs']:7.1f} LUFS peak {m['peakDb']:6.1f} dB")
    dest = ROOT / "game" / "data" / "audio_metrics.json"
    dest.write_text(json.dumps(out, indent=1))
    print(f"measured {len(out)}")

if __name__ == "__main__":
    main()
