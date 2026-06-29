#!/bin/bash
# Push automatico sem interacao
# Uso: bash push.sh "mensagem do commit"

MSG="${1:-auto update $(date '+%Y-%m-%d %H:%M')}"

cd "$(dirname "$0")"

git add start.sh phish phish-update.sh push.sh 2>/dev/null
git commit -m "$MSG" --quiet 2>/dev/null || echo "Sem mudancas para commit"
git push origin main 2>&1
echo "EXIT:$?"
