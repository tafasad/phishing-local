#!/bin/bash
# 🎣 PHISHING LOCAL - Atualização rápida
# Atualiza do GitHub e sobe o phish
# Uso: bash phish-update.sh

set -e

echo -e "\033[0;36m  🎣 Atualizando PHISHING LOCAL...\033[0m"

# Ir ao diretorio do script
cd "$(dirname "$0")"

# Tentar pull (com timeout)
echo - "  Verificando atualizações..."
timeout 60 git pull --quiet 2>/dev/null && echo - "  Código atualizado." || echo - "  Sem mudanças (ou rede indisponivel)."

# Garantir permissão
chmod +x phish start.sh

# Subir o menu
echo ""
echo - "  Iniciando... (Ctrl+C para cancelar)"
sleep 1
exec ./phish
