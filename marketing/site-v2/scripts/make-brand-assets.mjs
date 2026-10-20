/** Regenerate product icons and social preview from the approved Cove brand masters. */
import sharp from 'sharp'
import { copyFileSync, mkdtempSync, rmSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { pathToFileURL, fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
const DIR = dirname(fileURLToPath(import.meta.url))
const OUT = join(DIR, '..', 'public')
copyFileSync(join(OUT, 'brand/footing-app-icon.svg'), join(OUT, 'favicon.svg'))
await sharp(join(OUT, 'brand/footing-app-icon.png')).resize(180, 180).png().toFile(join(OUT, 'apple-touch-icon.png'))
const temp = mkdtempSync(join(tmpdir(), 'footing-og-'))
try {
  const shot = join(temp, 'og.png')
  const chrome = process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
  execFileSync(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1200,630', '--virtual-time-budget=3000', '--screenshot=' + shot, pathToFileURL(join(DIR, 'og.html')).href], { stdio: 'ignore' })
  await sharp(shot).resize(1200, 630).png({ compressionLevel: 9 }).toFile(join(OUT, 'og.png'))
} finally { rmSync(temp, { recursive: true, force: true }) }
console.log('wrote approved Cove favicon.svg, apple-touch-icon.png, og.png')
