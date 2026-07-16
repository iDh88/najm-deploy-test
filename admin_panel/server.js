const http = require('http');
const fs = require('fs');
const path = require('path');

const HOST = process.env.HOST || '127.0.0.1';
const PORT = Number(process.env.PORT || 3000);
const API_URL = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:8080';

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(status, {
    'content-type': type,
    'cache-control': 'no-store',
  });
  res.end(body);
}

async function proxyHealth(res) {
  try {
    const upstream = await fetch(`${API_URL}/health`);
    const data = await upstream.json();
    send(res, upstream.status, JSON.stringify({ ...data, upstream: API_URL }), 'application/json; charset=utf-8');
  } catch (error) {
    send(res, 503, JSON.stringify({ status: 'unhealthy', upstream: API_URL, error: error.message }), 'application/json; charset=utf-8');
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname === '/api/health') {
    await proxyHealth(res);
    return;
  }

  const filePath = path.join(__dirname, url.pathname === '/' ? 'index.html' : url.pathname);
  if (!filePath.startsWith(__dirname)) {
    send(res, 403, 'Forbidden');
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      fs.readFile(path.join(__dirname, 'index.html'), (fallbackError, fallbackData) => {
        if (fallbackError) send(res, 404, 'Not found');
        else send(res, 200, fallbackData, 'text/html; charset=utf-8');
      });
      return;
    }

    const ext = path.extname(filePath);
    const types = {
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
    };
    send(res, 200, data, types[ext] || 'application/octet-stream');
  });
});

server.listen(PORT, HOST, () => {
  console.log(`Najm Admin Panel running at http://${HOST}:${PORT}`);
  console.log(`Python health proxy using ${API_URL}/health`);
});
