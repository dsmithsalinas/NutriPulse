// Renders the motion piece frame by frame.
//   node render.js stills 2.5 9.8 ...      -> stills/t-<time>.png
//   node render.js frames <fps> [from] [to] -> frames/f-000000.jpg ...
const { chromium } = require('/Users/dustinsmith-salinas/Documents/GitHub/admyt/node_modules/playwright');
const fs = require('fs'), path = require('path');

const { createRenderServer } = require('../../render-server.cjs');

const root = path.join(__dirname, 'site');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.ttf': 'font/ttf' };
const server = createRenderServer(root, types, 'index.html');

(async () => {
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => console.error('PAGE ERROR', e.message));
  page.on('console', m => { if (m.type() === 'error') console.error('CONSOLE', m.text()); });
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForFunction(() => window.READY === true, null, { timeout: 30000 });
  // Warm-up: the first screenshot after load can miss a paint.
  await page.evaluate(() => window.seek(0)); await page.screenshot();
  const [mode, ...args] = process.argv.slice(2);
  if (mode === 'stills') {
    fs.mkdirSync(path.join(__dirname, 'stills'), { recursive: true });
    for (const a of args) {
      const t = parseFloat(a);
      await page.evaluate(t => window.seek(t), t);
      await page.screenshot({ path: path.join(__dirname, 'stills', `t-${t.toFixed(2)}.png`) });
    }
  } else {
    const fps = parseInt(args[0] || '60');
    const dur = await page.evaluate(() => window.DURATION);
    const from = parseInt(args[1] || '0'), to = parseInt(args[2] || String(Math.round(dur * fps)));
    const dir = path.join(__dirname, 'frames'); fs.mkdirSync(dir, { recursive: true });
    const t0 = Date.now();
    for (let f = from; f < to; f++) {
      await page.evaluate(t => window.seek(t), f / fps);
      await page.screenshot({ path: path.join(dir, `f-${String(f).padStart(6, '0')}.jpg`), type: 'jpeg', quality: 94 });
      if (f % 300 === 0) console.log(`frame ${f}/${to} ${((Date.now() - t0) / 1000).toFixed(0)}s`);
    }
    console.log('done', to - from, 'frames in', ((Date.now() - t0) / 1000).toFixed(0), 's');
  }
  await browser.close(); server.close();
})().catch(e => { console.error(e); process.exit(1); });
