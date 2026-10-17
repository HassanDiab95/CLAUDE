"""Render the OO ABAP explainer video.

1. Write one HTML page per (scene, step, fade frame).
2. Screenshot them with Playwright (render_frames.js).
3. Synthesize narration with Kokoro TTS.
4. Assemble with ffmpeg (concat demuxer for images + one audio track).

Usage: python3 build_video.py <work_dir> <kokoro_model.onnx> <voices.bin> <out.mp4>
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from storyboard import SCENES

WORK, MODEL, VOICES, OUT = (Path(a) for a in sys.argv[1:5])
HERE = Path(__file__).parent
FADE = [0.0, 0.25, 0.5, 0.75, 1.0]   # opacity of newly revealed elements
FADE_FRAME = 0.08                     # seconds per fade frame
PAD_STEP, PAD_SCENE = 0.55, 0.6       # silence after each step / extra at scene end
VOICE, SPEED = "am_michael", 1.08

SAY_FIX = [
    (r"\bABAP\b", "ah-bap"), (r"\bBAdIs\b", "bad-eyes"), (r"\bALV\b", "A L V"),
    (r"\bOData\b", "oh-data"), (r"\bRAP\b", "rap"), (r"\bSMS\b", "S M S"),
    (r"question mark equals", "question-mark equals"),
]

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { width: 1920px; height: 1080px; font-family: 'Liberation Sans', Arial, sans-serif;
  background: #FFFFFF; color: #1B2430; padding: 70px 120px; position: relative; overflow: hidden; }
body.dark { background: #0A2540; color: #FFFFFF; }
body.dark.nocircle::before, body.dark.nocircle::after { display: none; }
body.dark::before { content: ''; position: absolute; width: 900px; height: 900px; border-radius: 50%;
  background: #0B5394; right: -260px; top: -380px; }
body.dark::after { content: ''; position: absolute; width: 190px; height: 190px; border-radius: 50%;
  background: #F0AB00; right: 260px; bottom: 150px; }
h2 { font-size: 64px; color: #0A2540; margin-bottom: 40px; font-family: 'DejaVu Serif', Georgia, serif; }
h3 { font-size: 36px; color: #0A2540; margin-bottom: 14px; }
.title-wrap { position: relative; z-index: 2; margin-top: 120px; }
.kicker { font-size: 30px; letter-spacing: 6px; color: #F0AB00; font-weight: bold; margin-bottom: 30px; }
.big { font-size: 110px; font-family: 'DejaVu Serif', Georgia, serif; line-height: 1.1; }
.sub { font-size: 40px; color: #C9D6E8; margin-top: 30px; }
.chips { margin-top: 70px; display: flex; flex-wrap: wrap; gap: 18px; max-width: 1300px; }
.chips span { background: rgba(255,255,255,0.12); border: 2px solid #F0AB00; border-radius: 40px;
  padding: 14px 30px; font-size: 32px; }
.cols { display: flex; gap: 50px; align-items: stretch; }
.cols > * { flex: 1; }
.stack { display: flex; flex-direction: column; gap: 26px; flex: 1; }
.card { background: #EEF2F7; border-radius: 22px; padding: 36px 40px; font-size: 32px; line-height: 1.4; }
.card.accent { background: #FFF4D6; }
.card ul { padding-left: 34px; } .card li { margin-bottom: 14px; }
.card p { color: #33404F; }
.banner { margin-top: 50px; background: #0B5394; color: #fff; border-radius: 18px; padding: 26px 40px;
  font-size: 34px; font-weight: bold; }
pre.code { background: #0A2540; color: #E6EDF5; border-radius: 22px; padding: 36px 42px;
  font-family: 'DejaVu Sans Mono', 'Liberation Mono', monospace; font-size: 30px; line-height: 1.45;
  white-space: pre; }
pre.code.wide { font-size: 27px; line-height: 1.38; padding: 30px 42px; }
pre.code + .cols { margin-top: 40px; }
.banner.tight { margin-top: 30px; }
pre.code.small { font-size: 26px; margin-top: 26px; }
.hl { color: #F0AB00; }
.tag { display: inline-block; background: #F0AB00; color: #0A2540; font-weight: bold; font-size: 30px;
  border-radius: 12px; padding: 10px 22px; margin-bottom: 24px; }
.objrow { display: flex; gap: 26px; }
.objects .obj { flex: 1; background: #EEF2F7; border-radius: 20px;
  padding: 26px; font-size: 32px; text-align: center; font-family: 'DejaVu Sans Mono', monospace; }
.objects .obj:nth-of-type(1) b { color: #B4232A; } .objects .obj:nth-of-type(2) b { color: #0B5394; }
.tree { text-align: center; margin-bottom: 44px; }
.node { display: inline-block; background: #0B5394; color: #fff; border-radius: 18px; padding: 20px 40px;
  font-size: 34px; font-weight: bold; font-family: 'DejaVu Sans Mono', monospace; }
.node small { font-size: 24px; font-weight: normal; }
.node.accentnode { background: #F0AB00; color: #0A2540; }
.branches { display: flex; justify-content: center; gap: 140px; margin-top: 50px; position: relative; }
.branches::before { content: ''; position: absolute; top: -50px; left: 50%; width: 3px; height: 30px; background: #5F6B7A; }
.steps4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 30px; }
.steps4 .card { min-height: 360px; }
.num { width: 76px; height: 76px; border-radius: 50%; background: #5B3FA3; color: #fff; font-size: 40px;
  font-weight: bold; display: flex; align-items: center; justify-content: center; margin-bottom: 20px; }
.steps4 p { font-family: 'DejaVu Sans Mono', monospace; font-size: 26px; }
.recap { margin-top: 50px; display: grid; grid-template-columns: 1fr 1fr; gap: 22px 60px; font-size: 38px;
  max-width: 1500px; color: #E6EDF5; }
.recap b { color: #F0AB00; }
.footer { position: absolute; left: 120px; bottom: 40px; font-size: 22px; color: #5F6B7A; z-index: 3; }
body.dark .footer { color: #8FA3BF; }
.progress { position: absolute; left: 0; bottom: 0; height: 10px; background: #F0AB00; z-index: 3; }
"""


def page(scene_idx, step, alpha):
    sc = SCENES[scene_idx]
    rules = []
    for k in range(10):
        if k < step:
            op = 1
        elif k == step:
            op = alpha
        else:
            op = 0
        rules.append(f".s{k} {{ opacity: {op}; }}")
    progress = 1920 * (scene_idx + 1) / len(SCENES)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}
{' '.join(rules)}</style></head>
<body class="{'dark' if sc.get('dark') else ''} {sc.get('cls', '')}">{sc['html']}
<div class="footer">Object-Oriented ABAP · {scene_idx + 1}/{len(SCENES)}</div>
<div class="progress" style="width:{progress:.0f}px"></div></body></html>"""


def say(text):
    for pat, rep in SAY_FIX:
        text = re.sub(pat, rep, text)
    return text


def main():
    frames_dir = WORK / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    jobs, timeline = [], []      # timeline: (png, duration)

    from kokoro_onnx import Kokoro
    tts = Kokoro(str(MODEL), str(VOICES))
    audio_parts, sr = [], 24000

    for si, sc in enumerate(SCENES):
        for st, text in enumerate(sc["steps"]):
            samples, sr = tts.create(say(text), voice=VOICE, speed=SPEED, lang="en-us")
            pad = PAD_STEP + (PAD_SCENE if st == len(sc["steps"]) - 1 else 0)
            lead = 0.25
            seg = np.concatenate([np.zeros(int(lead * sr)), samples, np.zeros(int(pad * sr))])
            audio_parts.append(seg)
            total = len(seg) / sr
            # fade frames (fade only on step > 0 or first scene step after a cut)
            names = []
            for fi, a in enumerate(FADE):
                name = f"f_{si:02d}_{st}_{fi}.png"
                (frames_dir / name.replace(".png", ".html")).write_text(page(si, st, a), encoding="utf-8")
                jobs.append(name)
                names.append(name)
            for name in names[:-1]:
                timeline.append((name, FADE_FRAME))
            timeline.append((names[-1], total - FADE_FRAME * (len(names) - 1)))

    (WORK / "jobs.json").write_text(json.dumps({"dir": str(frames_dir), "files": jobs}))
    subprocess.run(["node", str(HERE / "render_frames.js"), str(WORK / "jobs.json")], check=True)

    audio = np.concatenate(audio_parts)
    sf.write(WORK / "narration.wav", audio, sr)

    concat = WORK / "concat.txt"
    lines = []
    for name, dur in timeline:
        lines.append(f"file '{frames_dir / name}'\nduration {dur:.4f}")
    lines.append(f"file '{frames_dir / timeline[-1][0]}'")   # concat demuxer quirk
    concat.write_text("\n".join(lines))

    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(concat),
                    "-i", str(WORK / "narration.wav"), "-vf", "fps=30,format=yuv420p",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "160k",
                    "-shortest", "-movflags", "+faststart", str(OUT)], check=True)
    print("video:", OUT, "duration %.1fs" % (len(audio) / sr))


if __name__ == "__main__":
    main()
