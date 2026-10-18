---
name: react-zustand-3d-assets
description: Use when preparing 3D models or textures for a web app — exporting from Blender/CAD to glTF/GLB, a model that is too large or slow to load, compressing geometry (Draco, Meshopt) or textures (KTX2, WebP), generating a React component from a GLB with gltfjsx, or setting up decoders and caching for models. Trigger on "glb", "gltf", "3D model too big", "Draco", "Meshopt", "KTX2", "gltf-transform", "gltfjsx", "Blender export".
---

# 3D Assets for the Web

A model exported straight from Blender or a CAD tool is built for offline
rendering: 4K textures, millions of triangles, hundreds of separate meshes. On the
web every megabyte is load time and every texture lives in GPU memory, so the
asset — not the code — usually decides whether a 3D view feels fast.

Rule: **no model reaches `public/models/` without going through this pipeline**,
and the original never ships.

## The pipeline

```
assets-src/chair.blend ──export──► assets-src/chair.glb   (original, kept, never shipped)
        │
        ▼  gltf-transform inspect          find the dominant cost
        ▼  targeted commands               textures → geometry → structure
        ▼  gltf-transform validate         spec errors
        ▼  look at it                      a viewer or the app
        │
public/models/chair.glb  +  src/three/models/Chair.jsx  (gltfjsx)
```

Tools: `npm install --global @gltf-transform/cli` (4.5.x) and `npx gltfjsx`
(6.5.x). Run `gltf-transform <command> -h` for exact flags — they change between
releases.

## 1. Export

- glTF 2.0 binary (`.glb`), meters, Y-up, transforms applied.
- Name the nodes the app needs to address (`Seat`, `Leg_FL`) — picking and
  configuration find them by name.
- Bake lighting and ambient occlusion into textures where the scene is static;
  baked light costs nothing at runtime.
- Keep the source file and the raw export in `assets-src/` (git LFS if large).
  Optimization is lossy and cannot be undone.

## 2. Inspect before optimizing

```bash
gltf-transform inspect assets-src/chair.glb
```

The report shows meshes, triangle counts, materials, textures with sizes, and
draw calls. Decide what dominates:

| Report says | Fix first |
|---|---|
| Textures are most of the file | resize, then compress textures |
| Millions of vertices | simplify / weld, then geometry compression |
| Hundreds of meshes | `instance` repeated meshes, `join` static ones |

The `optimize` command bundles many steps, but its own docs say its defaults "may
not be ideal for all scenes" — it can merge and rename nodes the app relies on.
Prefer targeted commands; use `optimize` only for assets the code never
addresses by node name.

## 3. Targeted commands, in order

```bash
# textures: size to what is actually displayed, then compress
gltf-transform resize   in.glb step1.glb --width 2048 --height 2048
gltf-transform webp     step1.glb step2.glb            # simple, universal
#   or KTX2 for lower GPU memory:  etc1s (colour maps, smaller)  /  uastc (normal maps, higher quality)

# geometry: pick ONE compressor
gltf-transform meshopt  step2.glb step3.glb            # good default, fast decode
#   or: gltf-transform draco step2.glb step3.glb       # often smaller static meshes

# structure
gltf-transform dedup    step3.glb step4.glb
gltf-transform prune    step4.glb step5.glb
gltf-transform instance step5.glb out.glb              # repeated meshes → GPU instancing

gltf-transform validate out.glb
```

- Resize first: textures are usually most of the bytes and all of the GPU memory.
  A 4096² texture on a thumbnail-sized object wastes 64 MB of VRAM uncompressed.
- Draco and Meshopt are alternatives — never both on one file.
- KTX2: ETC1S for colour/albedo maps, UASTC where quality matters (normal maps).
- Script the sequence in `scripts/optimize-models.sh` so every asset gets the same
  treatment and the step is repeatable after the artist re-exports.

## 4. Look at the result

Open `out.glb` in a glTF viewer or the app and compare with the original:
texture banding, normal-map artefacts, holes from over-simplification, missing
animations. Then record the before/after size in the PR description.

## 5. Generate the component

```bash
npx gltfjsx public/models/chair.glb --output src/three/models/Chair.jsx
```

- Produces a JSX scene graph with named meshes, ready for props, events, and
  material overrides. Commit the component; regenerate it when the asset changes.
- `--transform` makes gltfjsx run its own compression pass and emit a
  `*-transformed.glb`. Use it **or** the manual pipeline above, not both stacked.
- Keep `useGLTF.preload('/models/chair.glb')` at the bottom of the component so
  the model starts downloading when the route chunk loads.

## 6. Decoders and caching

- drei's `useGLTF` decodes Draco and Meshopt. For KTX2 textures configure the
  Basis transcoder (drei `useKTX2`, or `KTX2Loader.setTranscoderPath`).
- Self-host decoder files (`/draco/`, `/basis/`) when the app runs offline, behind
  a strict CSP, or must not depend on a third-party CDN.
- Serve `/models/` with long-lived `Cache-Control` and content-hashed file names
  (`chair.4f2a9c.glb`) so a re-export busts the cache.

## Budgets

Agree budgets in the project's FOUNDATION per target device. Starting points, not
sourced figures: total model + textures under ~5 MB for mobile views, textures at
or below the on-screen size, a draw-call count well under the R3F guidance of "a
few hundred or less".

## Pitfalls

- **Shipping the raw export** — tens of MB, long first paint, phones run out of
  GPU memory.
- **Running `optimize` on a configurator model** — `join`/`flatten` merge the
  named nodes the code selects, and picking silently breaks.
- **Draco on animated or morph-target models without checking** — verify the
  animation still plays after compression; Meshopt is the safer default there.
- **Compressing twice** (manual pipeline + `gltfjsx --transform`) — quality loss
  with no size gain.
- **Losing the original** — the next change means asking the artist to re-export
  from scratch.
- **Decoder files from a CDN in an offline or CSP-locked app** — models fail to
  load with an opaque network error.

## Related skills

- `react-zustand-3d-scenes` — using the generated components in a scene.
- `react-zustand-assets-media` — static asset paths and caching in Vite.
- `react-zustand-performance` — measuring load time and bundle impact.
