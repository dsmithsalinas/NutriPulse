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
 * of redrawing an image. The card is scripts/og.html, rendered by headless
 * Chrome with the site's own fonts.
 */
import sharp from 'sharp'
import { writeFileSync, mkdirSync, rmSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { pathToFileURL } from 'node:url'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'public')
mkdirSync(OUT, { recursive: true })

const INDIGO = '#6366F1'
const VIOLET = '#8B5CF6'

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
   1200×630, the ratio every platform crops to. Restates the hero in Daylight:
   the headline beside the protein tile at "Floor cleared". Rendered from
   scripts/og.html by headless Chrome, so it uses the site's real fonts without
   installing anything system-wide. Set CHROME to another binary if needed. */
const CHROME = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const shot = join(tmpdir(), `footing-og-${process.pid}.png`)
execFileSync(CHROME, [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
  '--window-size=1200,630', '--virtual-time-budget=3000', `--screenshot=${shot}`,
  pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), 'og.html')).href,
], { stdio: 'ignore' })
await sharp(shot).resize(1200, 630).png({ compressionLevel: 9 }).toFile(join(OUT, 'og.png'))
rmSync(shot, { force: true })

console.log('wrote favicon.svg, apple-touch-icon.png, og.png')
