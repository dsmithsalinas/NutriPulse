const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { createRenderServer } = require('./render-server.cjs');

function request(server, target) {
  return new Promise((resolve, reject) => {
    http.get({ hostname: '127.0.0.1', port: server.address().port, path: target }, res => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, type: res.headers['content-type'], body }));
    }).on('error', reject);
  });
}

for (const mode of ['social', 'video']) {
  test(`${mode}: confines HTTP reads and preserves renderer assets`, async t => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'render-server-test-'));
    t.after(() => fs.rm(dir, { recursive: true, force: true }));
    const root = path.join(dir, 'assets');
    await fs.mkdir(path.join(root, 'fonts'), { recursive: true });
    await fs.mkdir(path.join(dir, 'assets-sibling'));
    await fs.writeFile(path.join(dir, 'private.txt'), 'OUTSIDE_FIXTURE');
    await fs.writeFile(path.join(dir, 'assets-sibling', 'private.txt'), 'OUTSIDE_FIXTURE');
    await fs.writeFile(path.join(root, 'posts.html'), 'POSTS');
    await fs.writeFile(path.join(root, 'index.html'), 'VIDEO');
    await fs.writeFile(path.join(root, 'fonts', 'sample font.ttf'), 'FONT');
    await fs.writeFile(path.join(root, 'data.json'), '{}');
    await fs.symlink(path.join(dir, 'private.txt'), path.join(root, 'escape.txt'));
    await fs.symlink(path.join(dir, 'assets-sibling'), path.join(root, 'escape-dir'));
    const server = createRenderServer(root, { '.html': 'text/html', '.ttf': 'font/ttf', '.json': 'application/json' }, mode === 'video' ? 'index.html' : undefined);
    t.after(() => new Promise(resolve => server.close(resolve)));
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

    // Use raw HTTP paths so URL normalization cannot conceal the attack.
    for (const target of ['/../private.txt', '/%2e%2e/private.txt', '/..%2fprivate.txt', '/%2e%2e%2fassets-sibling/private.txt', '/fonts/../../private.txt', '/escape.txt', '/escape-dir/private.txt', '//../private.txt']) {
      const result = await request(server, target);
      assert.equal(result.status, 403, target);
      assert.equal(result.body, '', target);
    }
    for (const target of ['/%', '/%E0%A4%A', '/%00', '/..%5cprivate.txt']) {
      assert.equal((await request(server, target)).status, 400, target);
    }
    for (const target of ['/missing.txt', '/%252e%252e/private.txt']) {
      assert.equal((await request(server, target)).status, 404, target);
    }
    assert.deepEqual(await request(server, '/posts.html?p=p01-coached'), { status: 200, type: 'text/html', body: 'POSTS' });
    assert.deepEqual(await request(server, '/fonts/sample%20font.ttf?cache=1'), { status: 200, type: 'font/ttf', body: 'FONT' });
    assert.deepEqual(await request(server, '/data.json'), { status: 200, type: 'application/json', body: '{}' });
    if (mode === 'video') assert.deepEqual(await request(server, '/?frame=1'), { status: 200, type: 'text/html', body: 'VIDEO' });
    else assert.equal((await request(server, '/')).status, 403);
  });
}
