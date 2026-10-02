// Renders every post in posts.html to out/<id>.png.
// Each post is drawn at 2x and downsampled, so type is supersampled (same approach as ../build.py).
//   node render.js            -> all posts
//   node render.js p01-coached -> one post
const { chromium } = require(process.env.PLAYWRIGHT || '/Users/dustinsmith-salinas/Documents/GitHub/admyt/node_modules/playwright');
const http = require('http'), fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const root = __dirname;
const types = { '.html': 'text/html', '.png': 'image/png', '.jpg': 'image/jpeg', '.ttf': 'font/ttf' };
const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(p, (e, d) => { if (e) { res.writeHead(404); return res.end(); } res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' }); res.end(d); });
});

(async () => {
  await new Promise(r => server.listen(0, r));
  const base = `http://localhost:${server.address().port}/posts.html`;
  const browser = await chromium.launch();
  const probe = await browser.newPage();
  await probe.goto(`${base}?p=p01-coached`);
  await probe.waitForFunction(() => window.READY === true);
  const ids = process.argv[2] ? process.argv.slice(2) : await probe.evaluate(() => window.POST_IDS);
  fs.mkdirSync(path.join(root, 'out'), { recursive: true });
  for (const id of ids) {
    await probe.goto(`${base}?p=${id}`);
    await probe.waitForFunction(() => window.READY === true);
    const [w, h] = await probe.evaluate(() => window.POST_SIZE);
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
    page.on('pageerror', e => console.error(id, 'PAGE ERROR', e.message));
    await page.goto(`${base}?p=${id}`);
    await page.waitForFunction(() => window.READY === true);
    await page.screenshot(); // warm-up paint
    // A carousel is one panorama; each slide is the panorama shifted under a 1080-wide window.
    const slides = await page.evaluate(() => window.POST_SLIDES);
    for (let i = 0; i < Math.max(slides, 1); i++) {
      if (slides) await page.evaluate(i => window.SLIDE(i), i);
      const name = slides ? `${id}-${i + 1}` : id;
      const big = path.join(root, 'out', `${name}@2x.png`), out = path.join(root, 'out', `${name}.png`);
      await page.screenshot({ path: big, clip: { x: 0, y: 0, width: w, height: h } });
      execFileSync('sips', ['-z', String(h), String(w), big, '--out', out], { stdio: 'ignore' });
      fs.unlinkSync(big);
    }
    await page.close();
    console.log('rendered', id, `${w}x${h}`, slides ? `${slides} slides` : '');
  }
  await browser.close(); server.close();
})().catch(e => { console.error(e); process.exit(1); });
