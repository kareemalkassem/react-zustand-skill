---
name: react-zustand-3d-scenes
description: Use when adding or fixing any 3D view in a React app — Three.js, React Three Fiber (R3F), drei, a product viewer, configurator, room/floor-plan or digital-twin view, 3D data visualization, hero scene, WebGL or WebGPU renderer, camera controls, picking objects, or a 3D scene that is slow, blank, or janky. Trigger on "three.js", "3D", "R3F", "react-three-fiber", "drei", "WebGL", "WebGPU", "canvas scene", "useFrame", "OrbitControls".
---

# 3D Scenes (Three.js + React Three Fiber)

3D breaks React's habits. A scene redraws 60 times a second, so a `setState` per
frame re-renders the tree 60 times a second; objects created per frame flood the
garbage collector; and three.js adds several hundred KB (minified) to whatever
bundle imports it. Most
slow or janky 3D views are React patterns applied inside a render loop.

This skill keeps the four boundaries and adds one rule: **React describes the
scene; the frame loop mutates it through refs.**

Versions checked 2026-10-18: `three` 0.186.1 (r186), `@react-three/fiber` 9.8.2
(React ≥19 <19.4), `@react-three/drei` 10.7.9, `@react-three/postprocessing`
3.2.0, `@react-three/test-renderer` 9.1.1. Re-check with `npm view <pkg> version`.

## Choose the tool

| Need | Use |
|---|---|
| 3D inside this React app | `@react-three/fiber` + `@react-three/drei` (default) |
| Only "spin a product, AR button" | `<model-viewer>` web component — no scene code |
| A standalone engine-heavy page | Vanilla `three` in one component's `useEffect`, same layering |

## The shape

```
src/
├── three/
│   ├── SceneCanvas.jsx        <Canvas>, renderer, Suspense, controls, perf
│   ├── scenes/ProductScene.jsx lights, environment, composition
│   └── models/Chair.jsx       gltfjsx output, one per asset
├── store/sceneStore.js        selection, configuration, camera target (Zustand)
├── pages/ProductViewer.jsx    DOM UI + lazy <SceneCanvas>
└── styles/ProductViewer.module.css   canvas container + overlay panels
public/models/chair.glb        optimized asset (react-zustand-3d-assets)
```

| Layer | Owns | Never |
|---|---|---|
| `pages/` | DOM controls, layout, lazy-loading the canvas | three.js imports |
| `three/` | Scene graph, frame loop, pointer events on meshes | fetching, `toast`, axios |
| `store/sceneStore.js` | What is selected/configured | per-frame values (positions, time) |
| `services/` | Product/config data from the API | anything 3D |

## The canvas

```jsx
// src/three/SceneCanvas.jsx
import { Canvas } from '@react-three/fiber';
import { AdaptiveDpr, Bvh, CameraControls, Environment, Html, PerformanceMonitor, useProgress } from '@react-three/drei';
import { Suspense, useState } from 'react';

const Progress = () => {
  const { progress } = useProgress();
  return <Html center>{progress.toFixed(0)}%</Html>;
};

const SceneCanvas = ({ children, poster }) => {
  const [dpr, setDpr] = useState(1.5);
  return (
    <Canvas
      frameloop="demand"
      dpr={dpr}
      camera={{ position: [3, 2, 5], fov: 45 }}
      fallback={<img src={poster} alt="" />}
    >
      <PerformanceMonitor onIncline={() => setDpr(2)} onDecline={() => setDpr(1)} />
      <AdaptiveDpr pixelated />
      <Suspense fallback={<Progress />}>
        <Bvh firstHitOnly>{children}</Bvh>
        <Environment preset="city" />
      </Suspense>
      <CameraControls makeDefault />
    </Canvas>
  );
};

export default SceneCanvas;
```

```jsx
// src/pages/ProductViewer.jsx — three.js lands in its own chunk
const SceneCanvas = lazy(() => import('../three/SceneCanvas'));
const ProductScene = lazy(() => import('../three/scenes/ProductScene'));

<div className={styles.viewer} role="img" aria-label={t('viewer.label', { name: product.name })}>
  <Suspense fallback={<img className={styles.poster} src={product.poster_url} alt="" />}>
    <SceneCanvas poster={product.poster_url}><ProductScene /></SceneCanvas>
  </Suspense>
  <aside className={styles.panel}>{/* DOM controls: colour, material, reset view */}</aside>
</div>
```

- `frameloop="demand"` renders only when something changes. drei controls call
  `invalidate()` themselves; call it after any imperative change of your own.
- The `fallback` prop renders when WebGL cannot start — a poster image, never a
  blank box.
- DOM panels sit **outside** the canvas, positioned over it with CSS Modules. Use
  drei `<Html>` only for labels pinned to a 3D point.
- One `<Canvas>` per page. For several viewports use drei `<View>`; each Canvas is
  a separate WebGL context and browsers cap how many can exist.

## State: the store says what, the frame says how

```js
// src/store/sceneStore.js
export const useSceneStore = create((set) => ({
  selectedPartId: null,
  finish: 'oak',
  select: (id) => set({ selectedPartId: id }),
  setFinish: (finish) => set({ finish }),
}));
```

```jsx
// inside the scene — React subscription for things that change rarely
const finish = useSceneStore((s) => s.finish);

// frame loop — read fast-changing values without subscribing, mutate refs
const ref = useRef();
useFrame((state, delta) => {
  ref.current.rotation.y += delta * 0.2;
  const target = useSceneStore.getState().cameraTarget;   // no re-render
});
```

Pointer events on meshes write intent to the store
(`onClick={(e) => { e.stopPropagation(); select(e.object.name); }}`); the DOM
panel reads the same store. Data from the API still flows service → store; scene
components never fetch.

## Performance rules

From the official R3F pitfalls and scaling-performance pages:

| Do | Because |
|---|---|
| Mutate refs in `useFrame`, using `delta` | `setState` per frame re-renders the tree 60×/s; `delta` keeps speed refresh-rate independent |
| Preallocate (`const v = new Vector3()` outside the callback, `v.set(...)` inside) | `new Vector3()` per frame floods GC and stutters |
| Share geometries and materials (module scope or `useMemo`) | Each new material is a shader compile and more GPU memory |
| `instancedMesh` / drei `<Instances>` for many similar objects | Each mesh is a draw call; R3F docs: "no more than 1000 as the very maximum, and optimally a few hundred or less" |
| `useGLTF` / `useLoader` | Cached per URL; a loader in `useEffect` refetches per mount |
| Toggle `visible` instead of conditional mounting; `startTransition` for heavy swaps | Mount/unmount recompiles and re-uploads to the GPU |
| `<Detailed distances={[0, 10, 20]}>` LOD; nested `Suspense` with a low-poly fallback | Full-detail models at every distance waste the triangle budget |
| `PerformanceMonitor`, `performance={{ min: 0.5 }}` + `regress()` while moving | Drops resolution under load instead of dropping frames |
| Baked lighting/AO, `ContactShadows`, `BakeShadows` | Real-time shadow maps per light are the most expensive default |

Cached GLTF scenes take `dispose={null}` so remounts reuse them; R3F disposes
everything else on unmount. In vanilla three, dispose geometries, materials,
textures, and the renderer on teardown.

## Renderer: WebGL by default, WebGPU when needed

WebGL (R3F default) has the widest support and works with all of drei and
`@react-three/postprocessing`. Choose WebGPU only for GPU compute (huge particle
counts, simulation) or TSL node materials:

```jsx
import * as THREE from 'three/webgpu';

<Canvas gl={async (props) => { const r = new THREE.WebGPURenderer(props); await r.init(); return r; }}>
```

- `WebGPURenderer` falls back to a WebGL 2 backend automatically when WebGPU is
  unavailable; `forceWebGL: true` forces that path so you can test it.
- It is "not fully backward-compatible with all of Three's features":
  `ShaderMaterial`/`onBeforeCompile` code and `EffectComposer`-based effects
  (including `@react-three/postprocessing`) belong to the WebGL path. On WebGPU,
  use node materials and `THREE.RenderPipeline` (named `PostProcessing` before
  r183; the old name is deprecated).
- R3F v9 no longer converts texture props to sRGB automatically; set
  `colorSpace = THREE.SRGBColorSpace` on colour textures used in custom shaders.

## Accessibility and fallback

- Every action possible in 3D is also possible from DOM controls (keyboard and
  screen-reader reachable).
- The canvas container has `role="img"` and an `aria-label` describing the view.
- `prefers-reduced-motion`: no auto-rotate, no camera fly-through.
- Mobile: `touch-action: none` on the container, cap DPR at 2.

## Verifying

- Dev overlay: drei `<Stats>` or `r3f-perf` on the **target device** — watch fps,
  draw calls, triangles, texture memory.
- Unit: `@react-three/test-renderer` asserts the scene graph and fires pointer
  events without a GPU.
- E2E: screenshot the viewer in the smoke run. If the headless canvas is blank,
  launch Chromium with `args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader"]`
  for software WebGL.
- `vite build` output shows three.js in a lazy chunk, not the entry chunk.

## Pitfalls

- **`setState` inside `useFrame` or `onPointerMove`** — 60 renders a second; the
  page janks and fans spin.
- **Subscribing to fast store values with a selector** — same re-render storm; use
  `getState()` in the frame loop.
- **Importing three.js in the router or a shared component** — every
  route's first load pays for the engine, 3D or not.
- **Thousands of separate meshes** — draw calls, not triangles, cap the frame rate.
- **Rendering continuously for a static viewer** — battery drain on laptops and
  phones for an image that does not change.
- **No WebGL fallback** — older devices and some locked-down browsers show an
  empty rectangle.
- **Unoptimized GLB straight from the modeling tool** — tens of MB and slow first
  paint; run it through `react-zustand-3d-assets` first.

## Related skills

- `react-zustand-3d-assets` — the GLB pipeline every model goes through first.
- `react-zustand-state` — the scene store and selector scoping.
- `react-zustand-performance` — chunking three.js and measuring.
- `react-zustand-routing` — lazy-loading the viewer route.
- `react-zustand-e2e-playwright` — screenshotting the canvas headless.
- `react-zustand-i18n-rtl` — localized labels for DOM controls and `aria-label`.
