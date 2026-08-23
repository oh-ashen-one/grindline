#!/usr/bin/env python3
"""Measure glTF/GLB assets: animation clip durations (ms), mesh bounds (meters).
Writes game/data/asset_metrics.json used by tools/build_asset_manifest.py."""
import json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def glb_json(path: Path):
    data = path.read_bytes()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, f"not glTF-Binary: {path}"
    clen, ctype = struct.unpack_from("<II", data, 12)
    g = json.loads(data[20:20 + clen])
    # locate BIN chunk: follows JSON chunk with its own 8-byte header
    off = 20 + clen
    bin_off = None
    while off < len(data):
        ch_len, ch_type = struct.unpack_from("<II", data, off)
        if ch_type == 0x004E4942:  # 'BIN'
            bin_off = off + 8
            break
        off += 8 + ch_len
    return g, data, (bin_off if bin_off is not None else 20 + clen)

def component_size(t):  # glTF componentType -> bytes
    return {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[t]

def n_comp(t):
    return {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}[t]

def read_accessor(data, g, idx, bin_off):
    acc = g["accessors"][idx]
    bv = g["bufferViews"][acc["bufferView"]]
    off = bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride") or n_comp(acc["type"]) * component_size(acc["componentType"])
    out = []
    fmt = {5126:"f",5123:"H",5125:"I",5122:"h",5121:"B",5120:"b"}[acc["componentType"]]
    for i in range(acc["count"]):
        o = off + i * stride
        vals = struct.unpack_from("<" + fmt * n_comp(acc["type"]), data, o)
        out.append(vals)
    return out

def analyze(path: Path):
    g, data, bin_off = glb_json(path)
    info = {"animations": {}, "boundsMin": None, "boundsMax": None}
    for a in g.get("animations", []):
        dur_s = 0.0
        for ch in a["channels"]:
            samp = a["samplers"][ch["sampler"]]
            times = read_accessor(data, g, samp["input"], bin_off)
            if times:
                dur_s = max(dur_s, times[-1][0])
        info["animations"][a.get("name","?")] = round(dur_s * 1000)
    mn = [1e9]*3; mx = [-1e9]*3
    pos_acc = None
    for m in g.get("meshes", []):
        for prim in m.get("primitives", []):
            pa = prim["attributes"].get("POSITION")
            if pa is None: continue
            acc = g["accessors"][pa]
            if "min" in acc and "max" in acc:
                mn = [min(a,b) for a,b in zip(mn, acc["min"])]
                mx = [max(a,b) for a,b in zip(mx, acc["max"])]
    if mx[0] > mn[0]:
        info["boundsMin"] = [round(v,3) for v in mn]
        info["boundsMax"] = [round(v,3) for v in mx]
    tris = 0
    for m in g.get("meshes", []):
        for prim in m.get("primitives", []):
            idx = prim.get("indices")
            if idx is not None:
                tris += g["accessors"][idx]["count"] // 3
            elif "POSITION" in prim.get("attributes", {}):
                tris += g["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
    info["triangles"] = tris
    return info

def main():
    out = {}
    base = ROOT / "assets"
    for p in sorted(base.rglob("*.glb")):
        rel = str(p.relative_to(ROOT))
        try:
            out[rel] = analyze(p)
        except Exception as e:
            out[rel] = {"error": str(e)}
    dest = ROOT / "game" / "data"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "asset_metrics.json").write_text(json.dumps(out, indent=1))
    print(f"measured {len(out)} glbs")
    for k, v in out.items():
        if "animations" in v and v["animations"]:
            names = ",".join(list(v["animations"])[:8])
            print(f"  {k}: {len(v['animations'])} clips [{names}...] bounds={v['boundsMin']}-{v['boundsMax']}")

if __name__ == "__main__":
    main()
