# grindline — quality ledger

## Reference lock

- reference-01 (factory-kit mood): mechanism learned = industrial palette
  separation and prop density rhythm; forbidden = copying the preview layout
  as a map or branded machines; approved direction = warm rust/safety-yellow/
  steel dressing around a concrete plaza; canonical evidence = traversal.
- reference-02 (ambientCG Concrete034): mechanism learned = weathered concrete
  value range and stain density; forbidden = reusing photographic textures
  beyond the pinned licensed set; approved direction = tinted PBR concrete for
  all skate floors; canonical evidence = title backdrop ground.
- reference-03 (mini-skate pack preview): mechanism learned = toy-clean
  silhouette language and colormap material separation; forbidden = reusing
  the preview layout or character poses as art; approved direction = kit
  geometry dressed with authored street pieces; canonical evidence =
  primary-action framing.

## Findings

Append-only; each finding: date / id, observed defect, measured cause, chosen
fix, evidence, regression gate.

- 2026-08-23 / F-001: authored park GLBs exported with wrong dimensions
  (half-size boxes, rail along wrong axis). Measured via glTF accessor bounds:
  bank 1.5 m tall instead of 3.0 expected. Cause: primitive_cube_add(size=1)
  scaled by size/2 halves extents; operator rotations ambiguous. Fix: explicit
  mesh construction in strict Blender Z-up with full-dimension helpers and an
  extents assertion pass in tools/measure_assets.py consumers. Regression gate:
  game/data/asset_metrics.json extents must match contract targetSizeMeters
  within 6 percent; asserted by tests_staged/test_q03_asset_integration.sh.
- 2026-08-23 / F-002: manifest audio rows failed preflight path regex because
  the directory "8-Bit jingles" contains a space. Fix: renamed to
  8-bit-jingles; gate regex only accepts [A-Za-z0-9._/-]. Regression gate:
  preflight_assets.sh green is part of Phase 0 exit.

## Honest limitations

Proven environments: headless import/parse on this Mac Studio; headless sim
bridge with offscreen rendering and JSON metrics; deterministic seeds.
Unproven targets: physical touch devices (viewport emulation only), rumble,
any online service (none shipped), thermals under sustained GPU load.
Known compromises: single music track at Phase 0 (more may be added during
asset integration); AI skaters are scripted loops, not opponents.
Next highest-leverage improvement after vertical slice: look-lock lighting
pass to lock the dusk mood before content multiplication.
