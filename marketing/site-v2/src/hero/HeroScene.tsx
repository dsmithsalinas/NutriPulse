import { Suspense, useMemo, useState } from 'react'
import { Canvas, useFrame, useThree } from '@react-three/fiber'
import { PerformanceMonitor } from '@react-three/drei'
import { Bloom, EffectComposer, Noise, Vignette } from '@react-three/postprocessing'
import { BlendFunction } from 'postprocessing'
import * as THREE from 'three'
import { Rings, RINGS_CAM_KEYS } from './Rings'
import { actProgress } from '../scroll'

/**
 * The page's 3D layer: one persistent canvas behind the whole document, holding
 * Footing's protein dial. See marketing/site-v2-webgl.md for the full spec and
 * marketing/site-v2-blueprint.md §Addendum for why this set beat the abstract
 * ones it replaced.
 */

function Rig() {
  const { camera, scene } = useThree()
  const look = useMemo(() => new THREE.Vector3(), [])

  // Dev handle for tuning from the console — far faster than a rebuild per nudge.
  if (import.meta.env.DEV) {
    ;(window as unknown as Record<string, unknown>).__footing = { camera, scene }
  }

  useFrame(() => {
    const t = actProgress()
    const i = Math.min(RINGS_CAM_KEYS.length - 1, Math.floor(t))
    const j = Math.min(RINGS_CAM_KEYS.length - 1, i + 1)
    const f = t - i

    const a = RINGS_CAM_KEYS[i]
    const b = RINGS_CAM_KEYS[j]

    camera.position.x = 0
    camera.position.y = THREE.MathUtils.lerp(a.y, b.y, f)
    camera.position.z = THREE.MathUtils.lerp(a.z, b.z, f)
    look.set(0, THREE.MathUtils.lerp(a.look, b.look, f), -34)
    camera.lookAt(look)
  })

  return null
}

export function HeroScene() {
  const [dpr, setDpr] = useState(1.5)

  return (
    /*
     * The fixed positioning MUST live on a plain div that owns its own layout,
     * not on <Canvas className>. That class lands on R3F's internal wrapper,
     * which it measures with a ResizeObserver before creating the renderer —
     * and a wrapper that is itself the fixed element intermittently measures
     * 0×0 on first pass. R3F then waits forever for a resize that never comes:
     * canvas element present, drawing buffer stuck at 300×150, no children
     * mounted, and no error anywhere. Give it a sized parent to fill.
     */
    <div className="hero-canvas">
      <Canvas
        dpr={dpr}
        gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }}
        camera={{
          position: [0, RINGS_CAM_KEYS[0].y, RINGS_CAM_KEYS[0].z],
          fov: 34,
          near: 0.1,
          far: 420,
        }}
        onCreated={({ gl }) => {
          gl.toneMapping = THREE.ACESFilmicToneMapping
          gl.toneMappingExposure = 1.15
          /*
           * No scene.background, and alpha above, on purpose. The dial
           * composites over the CSS background layers, and the page's
           * subgrade→daylight arc lives entirely in those. An opaque scene
           * background paints straight over them and silently kills it.
           */
        }}
      >
        <PerformanceMonitor onDecline={() => setDpr(1)} onIncline={() => setDpr(1.75)} />

        {/* The arc is emissive by construction, so a key, a fill, and a sweep
            would all cost frames to change nothing. */}
        <ambientLight intensity={0.4} />
        <Rings />
        <Rig />

        <Suspense fallback={null}>
          <EffectComposer>
            {/* Bloom is what makes the arc read as light rather than as a
                coloured shape. No depth of field: the dial is the subject, and
                softening the one thing the frame is about is self-defeating. */}
            <Bloom
              intensity={0.7}
              luminanceThreshold={0.5}
              luminanceSmoothing={0.45}
              mipmapBlur
            />
            <Noise opacity={0.035} blendFunction={BlendFunction.OVERLAY} />
            <Vignette offset={0.28} darkness={0.72} />
          </EffectComposer>
        </Suspense>
      </Canvas>
    </div>
  )
}
