import { useMemo, useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { T } from './tokens'
import { actProgress } from '../scroll'

/**
 * The set: Footing's protein ring.
 *
 * Built from the product's own vocabulary rather than from the name's metaphor.
 * A slab or a terrain has to be decoded before it says anything, and what it
 * says once decoded is only "solid ground" — true of any wellness brand. The
 * dial says "this is a nutrition tracker" instantly, and the floor tick says the
 * one thing that makes Footing different from every other one, before a word of
 * copy is read.
 *
 * The Apple-Activity-rings risk is handled by the floor. Apple's rings are a
 * score with no threshold; a dial carrying a marked minimum you rise *to* is a
 * different idea wearing a similar shape. One arc, not four — the supporting
 * macros were tried and cut, because two dim rings behind the subject read as
 * decoration and cost the frame its clarity.
 *
 * The fill is the page's spine: it walks from 34% toward the floor as the
 * argument builds and clears it at "Why Footing?", where the metaphor pays off.
 * The colour going warm at that moment *is* the celebration — no badge, no
 * confetti, which is the whole brand in one transition.
 */

export const RINGS_CAM_KEYS = [
  // The camera barely moves. What changes across the page is the fill, not the
  // framing — a dolly would read as a camera move, holding still reads as
  // attention. The dial itself does the travelling, in world space.
  { y: 0.4, z: 17.2, look: 0.3 },
  { y: 0.2, z: 16.4, look: 0.15 },
  { y: 0.0, z: 15.8, look: 0.0 },
]

/** Where the protein floor sits on the dial, as a fraction of the full circle. */
const FLOOR_AT = 0.76

/**
 * Per-act keyframes. Index = act from src/scroll.ts (0 hero, 1 pin end, 2 s01 …
 * 10 s09). Every track is lerped, so intermediate scroll positions interpolate.
 *
 *   fill  fraction of the circle filled
 *   dim   overall opacity — 1 foreground, ~0.26 backdrop
 *   x     world x; 4.4 parks it in the right-hand third, 0.4 centres it
 *   scale grows as it dims, so it becomes the room the copy sits in
 */
const TRACK = [
  /* 0  hero        */ { fill: 0.34, dim: 1.0, x: 4.4, scale: 1.0 },
  /* 1  pin end     */ { fill: 0.34, dim: 0.92, x: 4.0, scale: 1.06 },
  /* 2  s01 problem */ { fill: 0.34, dim: 0.19, x: 0.4, scale: 1.55 },
  /* 3  s02 Pulse   */ { fill: 0.44, dim: 0.21, x: 0.4, scale: 1.55 },
  /* 4  s03 floor   */ { fill: 0.54, dim: 0.23, x: 0.4, scale: 1.5 },
  /* 5  s04 how     */ { fill: 0.62, dim: 0.2, x: 0.4, scale: 1.5 },
  /* 6  s05 cycle   */ { fill: 0.71, dim: 0.22, x: 0.4, scale: 1.48 },
  // The reward. Brightens, clears the floor, and opens up — scaled so the band
  // sits *outside* the copy block and "Why Footing?" is framed inside the
  // completed ring. 1.75 is the ceiling: outer radius 2.72 × 1.75 ≈ 4.76 world
  // units against a 4.9 half-frame, so any larger and the dial crops.
  /* 7  s06 why     */ { fill: 0.94, dim: 1.0, x: 0.4, scale: 1.75 },
  // Daylight arrives; the dial has said everything it has to say.
  /* 8  s07 offer   */ { fill: 1.0, dim: 0.42, x: 0.4, scale: 1.9 },
  /* 9  s08 faq     */ { fill: 1.0, dim: 0.0, x: 0.4, scale: 2.0 },
  /* 10 s09 cta     */ { fill: 1.0, dim: 0.0, x: 0.4, scale: 2.0 },
]

function sample(key: keyof (typeof TRACK)[number], t: number) {
  const i = Math.max(0, Math.min(TRACK.length - 1, Math.floor(t)))
  const j = Math.min(TRACK.length - 1, i + 1)
  return THREE.MathUtils.lerp(TRACK[i][key], TRACK[j][key], t - i)
}

const VERT = /* glsl */ `
  varying vec2 vP;
  void main() {
    vP = position.xy;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`

const FRAG = /* glsl */ `
  uniform float uProgress;
  uniform float uFloor;
  uniform float uRIn;
  uniform float uROut;
  uniform vec3 uA;
  uniform vec3 uB;
  uniform vec3 uWarm;
  uniform float uPast;
  uniform float uDim;
  uniform float uHover;

  varying vec2 vP;

  const float TAU = 6.28318530718;

  void main() {
    float r = length(vP);

    // 0 at twelve o'clock, increasing clockwise — the direction every progress
    // dial on a phone already reads in.
    float ang = atan(vP.x, vP.y) / TAU;
    float t = ang < 0.0 ? ang + 1.0 : ang;

    // Feather the inner and outer edges so the band reads as light rather than
    // as a cut-out annulus.
    float mid = (uRIn + uROut) * 0.5;
    float halfW = (uROut - uRIn) * 0.5;
    float radial = 1.0 - smoothstep(halfW * 0.5, halfW, abs(r - mid));

    // Clamped: fwidth blows up across the seam at twelve o'clock, and an
    // unclamped value there paints a bright wedge over the start of the arc.
    float aa = min(fwidth(t) * 1.5, 0.008);
    float fill = 1.0 - smoothstep(uProgress - aa, uProgress + aa, t);

    vec3 fillCol = mix(uA, uB, clamp(t / max(uProgress, 0.001), 0.0, 1.0));
    // Warms once the floor is cleared. The colour shift is the celebration.
    fillCol = mix(fillCol, uWarm, uPast);

    vec3 col = uA * 0.22;
    float a = 0.28 * radial;

    col = mix(col, fillCol, fill);
    a = mix(a, 0.95 * radial, fill);

    // Leading edge. Gives the arc a direction of travel even when static, and
    // brightens on hover so the dial answers the cursor.
    float head = 1.0 - smoothstep(0.0, 0.05, abs(t - uProgress));
    col += fillCol * head * (0.8 + uHover * 0.9);
    a += head * radial * 0.45;

    // The floor tick — the one mark that makes this Footing's ring and not a
    // generic dial.
    float tick = 1.0 - smoothstep(0.0, 0.0045, abs(t - uFloor));
    col = mix(col, vec3(1.0), tick * 0.9);
    a = max(a, tick * radial);

    gl_FragColor = vec4(col, clamp(a, 0.0, 1.0) * uDim);
  }
`

const R_IN = 2.35
const R_OUT = 2.72

function Arc({ hover }: { hover: React.RefObject<number> }) {
  const mat = useRef<THREE.ShaderMaterial>(null)

  const geo = useMemo(() => new THREE.RingGeometry(R_IN, R_OUT, 220, 1), [])

  const uniforms = useMemo(
    () => ({
      uProgress: { value: TRACK[0].fill },
      uFloor: { value: FLOOR_AT },
      uRIn: { value: R_IN },
      uROut: { value: R_OUT },
      uA: { value: new THREE.Color(T.indigo) },
      uB: { value: new THREE.Color(T.violet) },
      uWarm: { value: new THREE.Color(T.warm) },
      uPast: { value: 0 },
      uDim: { value: 1 },
      uHover: { value: 0 },
    }),
    [],
  )

  useFrame(() => {
    if (!mat.current) return
    const u = mat.current.uniforms
    const t = actProgress()

    // Lerped toward, never snapped: scroll position is a step function at the
    // frame level, and driving uniforms straight off it visibly stutters.
    u.uProgress.value = THREE.MathUtils.lerp(
      u.uProgress.value as number,
      sample('fill', t),
      0.07,
    )
    u.uDim.value = THREE.MathUtils.lerp(u.uDim.value as number, sample('dim', t), 0.07)
    u.uPast.value = THREE.MathUtils.lerp(
      u.uPast.value as number,
      (u.uProgress.value as number) > FLOOR_AT ? 1 : 0,
      0.05,
    )
    u.uHover.value = THREE.MathUtils.lerp(u.uHover.value as number, hover.current ?? 0, 0.1)
  })

  return (
    <mesh geometry={geo}>
      <shaderMaterial
        ref={mat}
        vertexShader={VERT}
        fragmentShader={FRAG}
        uniforms={uniforms}
        transparent
        depthWrite={false}
        side={THREE.DoubleSide}
      />
    </mesh>
  )
}

/** Live protein readout at the centre of the dial. DOM, so it stays crisp and
 *  is real text rather than pixels in a canvas. */
function Readout() {
  const num = useRef<HTMLDivElement>(null)
  const box = useRef<HTMLDivElement>(null)

  useFrame(() => {
    const t = actProgress()
    const g = sample('fill', t)

    if (num.current) num.current.textContent = String(Math.round(g * 185))
    if (box.current) {
      // Goes before the arc does. A crisp readout floating over body copy reads
      // as an overlay bug, not as atmosphere.
      box.current.style.opacity = String(Math.max(0, 1 - t * 1.5))
    }
  })

  return (
    <Html center style={{ pointerEvents: 'none' }} zIndexRange={[3, 3]}>
      <div className="ring-readout" ref={box}>
        <div className="ring-readout-n" ref={num}>
          63
        </div>
        <div className="ring-readout-l">of 185g protein</div>
      </div>
    </Html>
  )
}

export function Rings() {
  const group = useRef<THREE.Group>(null)
  const hover = useRef(0)
  const { size } = useThree()

  useFrame(({ clock, pointer }) => {
    if (!group.current) return
    const t = actProgress()

    // Barely-there drift. A dial that is perfectly static reads as a screenshot;
    // one that spins reads as a loader. This is neither.
    const idleY = Math.sin(clock.elapsedTime / 14) * 0.035
    const idleX = Math.sin(clock.elapsedTime / 19) * 0.018

    // Parallax. Tiny on purpose — the dial should feel like it occupies space,
    // not like it's being dragged around by the cursor.
    group.current.rotation.y = 0.2 + idleY + pointer.x * 0.07
    group.current.rotation.x = -0.28 + idleX - pointer.y * 0.05

    group.current.position.x = THREE.MathUtils.lerp(
      group.current.position.x,
      sample('x', t),
      0.07,
    )
    group.current.scale.setScalar(
      THREE.MathUtils.lerp(group.current.scale.x, sample('scale', t), 0.07),
    )

    // Proximity rather than raycast: the dial is a thin ring, so a hit test
    // would only fire on the band itself and the response would feel broken
    // everywhere inside it. Screen-space distance to the dial's centre is what
    // "the cursor is near the ring" actually means.
    const cx = (sample('x', t) / 8.1) * 0.5
    const d = Math.hypot(pointer.x - cx, pointer.y * (size.height / size.width))
    hover.current = Math.max(0, 1 - d / 0.5)
  })

  return (
    <group ref={group} position={[TRACK[0].x, 0.3, 0]}>
      <Arc hover={hover} />
      <Readout />
    </group>
  )
}
