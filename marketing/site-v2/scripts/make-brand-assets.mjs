/**
 * Generates the favicon and the social share card.
 *
 *   node scripts/make-brand-assets.mjs
 *
 * Outputs (all committed — they are build inputs, not build products):
 *   public/favicon.svg          tab icon, vector
 *   public/apple-touch-icon.png 180×180, iOS home screen
 *   public/og.png               1200×630, link previews
 *
 * Why a script rather than hand-authored files: the OG card restates the hero —
 * same dial, same fill, same floor tick, same headline. When the hero changes,
 * this needs to change with it, and a script makes that a one-line edit instead
 * of redrawing an image. Text is rasterised with real Inter (installed
 * system-wide), so the card matches the site rather than approximating it.
 */
import sharp from 'sharp'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'public')
mkdirSync(OUT, { recursive: true })

const INDIGO = '#6366F1'
const VIOLET = '#8B5CF6'
const SUBGRADE = '#07070F'
const ON_DARK = '#F6F5FC'

/** Fraction of the dial that's filled, and where the protein floor sits.
 *  Mirrors TRACK[0].fill and FLOOR_AT in src/hero/Rings.tsx. */
const FILL = 0.34
const FLOOR = 0.76

/** Point on a circle at `t` (0–1) clockwise from twelve o'clock. */
const at = (cx, cy, r, t) => {
  const a = t * Math.PI * 2
  return [cx + r * Math.sin(a), cy - r * Math.cos(a)]
}

/* ── The mark ───────────────────────────────────────────────────────────
   Same geometry as orbit-exports/export/footing-mark.svg. `inset` controls how
   much of the tile the ring occupies: the source art uses 0.38, which leaves
   generous padding that reads as empty at favicon sizes, so small renders push
   it wider and thicken the stroke to survive 16px. */
const mark = ({ inset = 0.38, stroke = 6, ids = '' } = {}) => {
  const off = (64 - 100 * inset) / 2
  return `
  <defs>
    <linearGradient id="bg${ids}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${INDIGO}"/><stop offset="100%" stop-color="${VIOLET}"/>
    </linearGradient>
    <radialGradient id="gl${ids}" cx="0.28" cy="0.12" r="0.9">
      <stop offset="0%" stop-color="#fff" stop-opacity="0.30"/>
      <stop offset="58%" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="64" height="64" rx="14.32" fill="url(#bg${ids})"/>
  <rect width="64" height="64" rx="14.32" fill="url(#gl${ids})"/>
  <g transform="translate(${off}, ${off}) scale(${inset})">
    <circle cx="50" cy="50" r="33" stroke="#fff" stroke-width="${stroke}" fill="none" opacity="0.24"/>
    <path d="M 50 17 A 33 33 0 1 1 18.99 61.29" stroke="#fff" stroke-width="${stroke}"
          stroke-linecap="round" fill="none"/>
    <circle cx="18.99" cy="61.29" r="${stroke * 1.25}" fill="#fff"/>
  </g>`
}

/* ── favicon.svg ─────────────────────────────────────────────────────────
   Wider inset and a heavier stroke than the source mark. At 16px the original
   0.38/6 combination renders the ring at roughly half a pixel and turns to
   mush; 0.50/7 keeps it readable while still reading as the same logo. */
const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">${mark(
  { inset: 0.5, stroke: 7, ids: 'f' },
)}
</svg>`
writeFileSync(join(OUT, 'favicon.svg'), favicon + '\n')

/* ── apple-touch-icon.png ────────────────────────────────────────────────
   iOS ignores SVG favicons for home-screen icons and it also ignores the
   rounded corners — it applies its own mask — but a square-cornered source
   would show colour bleeding past the mask, so the radius stays. */
const touch = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="180" height="180">${mark(
  { inset: 0.46, stroke: 6.5, ids: 't' },
)}
</svg>`
await sharp(Buffer.from(touch)).png().toFile(join(OUT, 'apple-touch-icon.png'))

/* ── og.png ──────────────────────────────────────────────────────────────
   1200×630 — the ratio every major platform crops to. Deliberately restates
   the hero: same dial at the same fill, the floor tick, and the headline, so a
   shared link and the site read as one thing. */
const W = 1200
const H = 630
const CX = 895
const CY = 315
const R = 158
const BAND = 34

const [fx, fy] = at(CX, CY, R, FILL)
const [tx1, ty1] = at(CX, CY, R - BAND / 2 - 9, FLOOR)
const [tx2, ty2] = at(CX, CY, R + BAND / 2 + 9, FLOOR)

const og = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="arc" gradientUnits="userSpaceOnUse" x1="${CX}" y1="${CY - R}" x2="${fx}" y2="${fy}">
      <stop offset="0%" stop-color="${INDIGO}"/><stop offset="100%" stop-color="${VIOLET}"/>
    </linearGradient>
    <radialGradient id="bloom" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="${VIOLET}" stop-opacity="0.30"/>
      <stop offset="100%" stop-color="${VIOLET}" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="${W}" height="${H}" fill="${SUBGRADE}"/>
  <ellipse cx="${CX}" cy="${CY + 60}" rx="430" ry="330" fill="url(#bloom)"/>

  <!-- lockup -->
  <g transform="translate(80, 68) scale(0.78)">${mark({ ids: 'o' })}</g>
  <text x="136" y="108" font-family="Inter" font-size="33" font-weight="600"
        letter-spacing="-1.3" fill="${ON_DARK}">Footing</text>

  <!-- the promise -->
  <text x="80" y="300" font-family="Inter" font-size="78" font-weight="600"
        letter-spacing="-3.4" fill="${ON_DARK}">Coached,</text>
  <text x="80" y="382" font-family="Inter" font-size="78" font-weight="600"
        letter-spacing="-3.4" fill="${ON_DARK}">not scolded.</text>
  <text x="82" y="443" font-family="Inter" font-size="25" font-weight="400"
        letter-spacing="-0.4" fill="${ON_DARK}" opacity="0.62">Protein-first GLP-1 coaching</text>
  <text x="82" y="556" font-family="Inter" font-size="21" font-weight="500"
        letter-spacing="-0.2" fill="${ON_DARK}" opacity="0.40">tryfooting.app</text>

  <!-- the dial -->
  <!-- Track kept visible enough that the unfilled arc reads as part of the dial.
       Any dimmer and the floor tick looks like a stray dash floating in space
       rather than a threshold marked on the ring. -->
  <circle cx="${CX}" cy="${CY}" r="${R}" fill="none" stroke="${INDIGO}"
          stroke-opacity="0.34" stroke-width="${BAND}"/>
  <path d="M ${CX} ${CY - R} A ${R} ${R} 0 0 1 ${fx.toFixed(1)} ${fy.toFixed(1)}"
        fill="none" stroke="url(#arc)" stroke-width="${BAND}" stroke-linecap="round"/>
  <!-- the floor tick: the one mark that makes this Footing's dial -->
  <line x1="${tx1.toFixed(1)}" y1="${ty1.toFixed(1)}" x2="${tx2.toFixed(1)}" y2="${ty2.toFixed(1)}"
        stroke="#fff" stroke-width="5" stroke-linecap="round"/>

  <text x="${CX}" y="${CY + 6}" text-anchor="middle" font-family="Inter" font-size="72"
        font-weight="600" letter-spacing="-3" fill="${ON_DARK}">63</text>
  <text x="${CX}" y="${CY + 44}" text-anchor="middle" font-family="Inter" font-size="21"
        font-weight="500" letter-spacing="0.2" fill="${ON_DARK}" opacity="0.5">of 185g protein</text>
</svg>`

await sharp(Buffer.from(og)).png({ compressionLevel: 9 }).toFile(join(OUT, 'og.png'))

console.log('wrote favicon.svg, apple-touch-icon.png, og.png')
