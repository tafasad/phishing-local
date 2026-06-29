#!/bin/bash
# 🎣 PHISHING LOCAL - Atualização rápida
# Atualiza do GitHub e sobe o phish
# Uso: bash phish-update.sh

set -e

echo -e "\033[0;36m  🎣 Atualizando PHISHING LOCAL...\033[0m"

# Ir ao diretorio do script
cd "$(dirname "$0")"

# Tentar pull (com timeout)
echo -n "  Verificando atualizações..."
timeout 60 git pull --quiet 2>/dev/null && echo -e " \033[0;32mOK\033[0m" || echo -e " \033[1;33mSem mudanças ou rede indisponivel\033[0m"

# Garantir permissão
chmod +x phish start.sh

# Subir o menu
echo ""
echo -e "  \033[0;32mIniciando... (Ctrl+C para cancelar)\033[0m"
sleep 1
exec ./phish
