#!/usr/bin/env python3
"""Build assets/asset-manifest.json + ASSET-MANIFEST.md with SHA-256 pins,
measured bounds/durations/loudness from game/data/*.json. Deterministic."""
import hashlib, json, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"
M3D = json.loads((ROOT / "game/data/asset_metrics.json").read_text())
AUD = json.loads((ROOT / "game/data/audio_metrics.json").read_text())

def sha(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def rel(p: Path) -> str:
    return str(p.resolve().relative_to(ROOT.resolve()))

def ext_of(glb_key):
    v = M3D[glb_key]
    mn, mx = v["boundsMin"], v["boundsMax"]
    return [round(max(mx[i]-mn[i], 0.05), 3) for i in range(3)]

def tri_budget(glb_key):
    t = M3D[glb_key]["triangles"]
    return int(t * 1.3) + 16

def entry(id_, role, cat, src, lic, path, fallback, **kw):
    p = A / path if not str(path).startswith("assets/") else ROOT / path
    e = {"id": id_, "role": role, "category": cat, "sourceUrl": src,
         "license": lic, "shipApproved": True, "path": rel(p),
         "sha256": sha(p), "fallback": fallback}
    e.update(kw)
    return e

def glb_entry(id_, role, cat, src, lic, apath, fallback, ingame=None, motion="none", front="-Z", importScale=None):
    key = f"assets/{apath}"
    size = ingame or ext_of(key)
    return entry(id_, role, cat, src, lic, apath, fallback,
                 targetSizeMeters=size, frontAxis=front, upAxis="+Y",
                 rootMotion=motion, maxTriangles=tri_budget(key), maxTextureMB=8,
                 **({"importScale": importScale} if importScale else {}))

K = "https://kenney.nl/assets/mini-skate"
FK = "https://kenney.nl/assets/factory-kit"
IS = "https://kenney.nl/assets/input-prompts"
AC = "https://ambientcg.com"
PH = "https://polyhaven.com/a/industrial-sunset-puresky"
OGA_FIGHT = "https://opengameart.org/content/fight-them-until-we-cant"

CHAR_SCALE = 0.526          # slim UAC: 3.325 u -> 1.75 m hero
BOY = "assets/models/characters/skater_slim_boy.glb"
GIRL = "assets/models/characters/skater_slim_girl.glb"

def anim_entries(prefix, path, src):
    # slim heroes: measure clip durations from the GLB directly
    key = f"assets/{Path(path).name}"
    anims = {a.split("|")[-1]: d for a, d in M3D[key]["animations"].items()} if key in M3D else {}
    def a(name, cid, dur, **kw):
        return entry(f"anim-{prefix}-{cid}", "hero", "animation", src, "CC0-1.0",
                     path, "hold last pose",
                     durationMs=dur, upAxis="+Y", rootMotion="none", **kw)
    g = lambda n, d: int(anims.get(n, d))
    out = [
        a("idle", "idle", g("Idle", 1300)),
        a("ride", "ride", g("Run", 700), gaitCycleMs=g("Run", 700)),
        a("ollie", "ollie", g("Jump", 1000), contactFrameMs=int(g("Jump", 1000)*0.15)),
        a("bail", "bail", g("Roll", 800), contactFrameMs=int(g("Roll", 800)*0.2)),
        a("walk", "walk", g("Walk", 1000), gaitCycleMs=g("Walk", 1000)),
        a("bail-death", "death", g("Death", 1200), contactFrameMs=0),
    ]
    return out

assets = []

# ---- heroes -------------------------------------------------------------
assets += [
    glb_entry("hero-boy", "hero", "character",
              "https://quaternius.com/packs/ultimateanimatedcharacter.html", "CC0-1.0",
              "models/characters/skater_slim_boy.glb", "debug capsule (non-shipping)",
              ingame=[round(x*CHAR_SCALE,3) for x in ext_of(BOY)], front="+Z",
              importScale=CHAR_SCALE),
    glb_entry("hero-girl", "hero", "character",
              "https://quaternius.com/packs/ultimateanimatedcharacter.html", "CC0-1.0",
              "models/characters/skater_slim_girl.glb", "debug capsule (non-shipping)",
              ingame=[round(x*CHAR_SCALE,3) for x in ext_of(GIRL)], front="+Z",
              importScale=CHAR_SCALE),
    glb_entry("board", "primary-interactable", "prop", K, "CC0-1.0",
              "models/board/skateboard.glb", "debug box (non-shipping)", front="+Z"),
]
assets += anim_entries("boy", BOY, "https://quaternius.com/packs/ultimateanimatedcharacter.html")
assets += anim_entries("girl", GIRL, "https://quaternius.com/packs/ultimateanimatedcharacter.html")

CLIPS = lambda p: {"idle": f"anim-{p}-idle", "locomotion": f"anim-{p}-ride",
                   "primaryAction": f"anim-{p}-ollie", "hitOrFail": f"anim-{p}-bail"}  # slim: Idle/Run/Jump/Roll
for c in assets:
    if c["id"] == "hero-boy": c["clips"] = CLIPS("boy")
    if c["id"] == "hero-girl": c["clips"] = CLIPS("girl")

# ---- authored street pieces ---------------------------------------------
for n in ["quarter_pipe", "bank", "funbox", "ledge", "rail", "kicker", "spine", "warehouse_wall", "skyline"]:
    assets.append(glb_entry(f"park-{n}", "environment-kit", "environment",
                            "authored://tools/make_park.py", "CC0-1.0",
                            f"park/{n}.glb", "flat floor tile"))

# ---- Kenney Mini Skate park kit -----------------------------------------
for n in ["bowl-corner-inner", "bowl-corner-outer", "bowl-side", "floor-concrete",
          "floor-wood", "half-pipe", "obstacle-box", "obstacle-end", "obstacle-middle",
          "pallet", "rail-curve", "rail-high", "rail-low", "rail-slope", "steps",
          "structure-platform", "structure-wood"]:
    assets.append(glb_entry(f"k-{n}", "environment-kit", "environment", K, "CC0-1.0",
                            f"park/kenney/{n}.glb", "flat floor tile"))
assets.append(entry("k-colormap", "environment-kit", "texture", K, "CC0-1.0",
                    "park/kenney/colormap.png", "flat gray", maxTextureMB=4))

# ---- factory dressing props ----------------------------------------------
for n in ["box-large", "box-long", "box-small", "box-wide", "cone", "door-wide-open",
          "hopper-round", "machine-fortified", "machine", "pipe-large-curve",
          "piston-round", "structure-wall", "structure-yellow-high", "warning-traffic"]:
    assets.append(glb_entry(f"prop-{n}", "environment-kit", "prop", FK, "CC0-1.0",
                            f"props/{n}.glb", "hidden"))

# ---- mid-ground buildings (arched-window facades, authored) ---------------
BLD = "authored://tools (Blender-authored mid-ground buildings)"
for n in ["bldg_sandstone", "bldg_brick_tall", "bldg_plaster", "bldg_sandstone2"]:
    assets.append(glb_entry(n, "environment-kit", "environment", BLD, "CC0-1.0",
                            f"buildings/{n}.glb", "flat floor tile"))

# ---- street fabric (Blender-authored for the THPS-reference overhaul) -----
STREET = "authored://tools (Blender-authored street kit)"
for n, nid in [("lamp", "street-lamp"), ("palm", "street-palm"),
               ("planter", "street-planter"), ("bench", "street-bench"),
               ("drain", "street-drain"), ("curb", "street-curb"),
               ("tramtrack", "street-tramtrack"), ("mural", "mural-panel"),
               ("paint_red", "paint-red"), ("paint_teal", "paint-teal"),
               ("paint_yellow", "paint-yellow"), ("cone_red", "cone-red"),
               ("cone_teal", "cone-teal")]:
    assets.append(glb_entry(nid, "environment-kit", "environment", STREET, "CC0-1.0",
                            f"props/street/{n}.glb", "flat floor tile"))

# ---- PBR texture sets -----------------------------------------------------
for n, nid in [("Concrete034","concrete"), ("Asphalt009","asphalt"), ("Metal032","metal"),
               ("Bricks060","bricks"), ("Planks039","planks")]:
    p = f"textures/{n}/{n}_1K-JPG_Color.jpg"
    assets.append(entry(f"tex-{nid}", "environment-kit", "texture", AC, "CC0-1.0",
                        p, "flat gray", maxTextureMB=4))
    np = f"textures/{n}/{n}_1K-JPG_NormalGL.jpg"
    assets.append(entry(f"tex-{nid}-normal", "environment-kit", "texture", AC, "CC0-1.0",
                        np, "flat normal", maxTextureMB=4))

assets.append(entry("hdri-dusk", "environment-kit", "sky", PH, "CC0-1.0",
                    "env/industrial_sunset_puresky_1k.hdr", "procedural sky", maxTextureMB=8))

# ---- UI -------------------------------------------------------------------
assets.append(entry("font-bebas", "ui", "font",
                    "https://fonts.google.com/specimen/Bebas+Neue", "OFL-1.1",
                    "ui/fonts/BebasNeue-Regular.ttf", "system font"))
for p in sorted((A/"ui/prompts/keys").glob("*.png")):
    assets.append(entry(f"prompt-keys-{p.stem}", "ui", "icon", IS, "CC0-1.0",
                        str(p.relative_to(A)), "text label", maxTextureMB=2))
for p in sorted((A/"ui/prompts/gamepad").glob("*.png")):
    assets.append(entry(f"prompt-pad-{p.stem}", "ui", "icon", IS, "CC0-1.0",
                        str(p.relative_to(A)), "text label", maxTextureMB=2))

# ---- audio -----------------------------------------------------------------
SFX_MAP = {
    "impactSoft_heavy_000.ogg": "bail-thud", "impactWood_medium_000.ogg": "wall-splat",
    "impactMetal_light_000.ogg": "grind-clank", "impactPlate_medium_000.ogg": "land-hard",
    "impactGeneric_light_000.ogg": "tick-pickup", "impactMining_002.ogg": "crash-big",
}
for f, sid in SFX_MAP.items():
    p = f"impact-sounds/Audio/{f}"
    m = AUD[f"assets/{p}"]
    assets.append(entry(f"sfx-{sid}", "audio", "audio",
                        "https://kenney.nl/assets/impact-sounds", "CC0-1.0", p, "silence",
                        durationMs=m["durationMs"], lufs=m["lufs"], peakDb=m["peakDb"],
                        maxFileMB=m["maxFileMB"], loop=False))
UI_MAP = {"select_004.ogg":"select", "back_004.ogg":"back", "confirmation_001.ogg":"confirm",
          "error_004.ogg":"error", "toggle_001.ogg":"toggle", "scroll_002.ogg":"scroll",
          "click_002.ogg":"click"}
for f, sid in UI_MAP.items():
    p = f"interface-sounds/Audio/{f}"
    m = AUD[f"assets/{p}"]
    assets.append(entry(f"ui-{sid}", "audio", "audio",
                        "https://kenney.nl/assets/interface-sounds", "CC0-1.0", p, "silence",
                        durationMs=m["durationMs"], lufs=m["lufs"], peakDb=m["peakDb"],
                        maxFileMB=m["maxFileMB"], loop=False))
for j, sid in [("jingles_NES00.ogg","win"), ("jingles_NES08.ogg","lose")]:
    p = A / "music-jingles/Audio/8-bit-jingles" / j
    rp = str(p.relative_to(A))
    m = AUD[f"assets/{rp}"]
    assets.append(entry(f"jingle-{sid}", "audio", "audio",
                        "https://kenney.nl/assets/music-jingles", "CC0-1.0", rp, "silence",
                        durationMs=m["durationMs"], lufs=m["lufs"], peakDb=m["peakDb"],
                        maxFileMB=m["maxFileMB"], loop=False))
mm = AUD["assets/music/music_fight.ogg"]
assets.append(entry("music-run", "audio", "audio", OGA_FIGHT, "CC-BY-3.0",
                    "music/music_fight.ogg", "menu silence", durationMs=mm["durationMs"],
                    lufs=-14.0, peakDb=mm["peakDb"], maxFileMB=mm["maxFileMB"], loop=True))

manifest = {"schemaVersion": 1, "assets": assets}
(ROOT/"assets"/"asset-manifest.json").write_text(json.dumps(manifest, indent=1)+"\n")

use_by = {"hero-boy":"roster A/C (palette variants)","hero-girl":"roster B/D (palette variants)",
          "board":"all skaters","music-run":"gameplay loop"}
lines = ["# ASSET MANIFEST — grindline","",
         "Required by law 16. Machine truth: `asset-manifest.json`.","",]
roles_rows=[]
for a in assets:
    abs_path = str((ROOT / a["path"]).resolve())
    roles_rows.append(f"| {a['id']} | {a['sourceUrl']} | {a['license']} | `{abs_path}` | {use_by.get(a['id'], a['role'])} |")
lines += ["| Asset | Source URL | License | Local path | Used by |","|---|---|---|---|---|"] + roles_rows
lines += ["","Character clips resolve to `anim-*` entries inside the same GLB.",
          "Programmer art is never a shipping target.",""]
(ROOT/"assets"/"ASSET-MANIFEST.md").write_text("\n".join(lines))
print(f"manifest: {len(assets)} entries")
