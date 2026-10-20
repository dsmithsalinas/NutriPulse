const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

// Renderer assets are trusted local files; HTTP clients cannot select files
// outside this root, including through symlinks in the asset tree.
function createRenderServer(root, types, indexFile) {
  const realRoot = fs.realpathSync(root);
  const insideRoot = file => file.startsWith(realRoot + path.sep);
  return http.createServer((req, res) => {
    const reject = status => { res.writeHead(status); res.end(); };
    let pathname;
    try {
      pathname = decodeURIComponent(req.url.split('?')[0]);
    } catch {
      return reject(400);
    }
    if (!pathname.startsWith('/') || pathname.includes('\\') || pathname.includes('\0')) {
      return reject(400);
    }
    if (pathname.split('/').includes('..')) return reject(403);
    if (pathname === '/' && indexFile) pathname = '/' + indexFile;
    const candidate = path.resolve(realRoot, '.' + pathname);
    if (!insideRoot(candidate)) return reject(403);
    fs.realpath(candidate, (error, file) => {
      if (error) return reject(404);
      if (!insideRoot(file)) return reject(403);
      fs.readFile(file, (readError, data) => {
        if (readError) return reject(404);
        res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
        res.end(data);
      });
    });
  });
}

module.exports = { createRenderServer };
