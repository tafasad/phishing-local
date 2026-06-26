@echo off
:: Setup hosts para phishing local
:: Modo de uso: setup-hosts.bat [IP] [NOME]
:: Exemplo: setup-hosts.bat 192.168.18.6 autocarlocadora

set IP=%1
set NAME=%2

if "%IP%"=="" (
    echo Uso: setup-hosts.bat [IP] [NOME]
    echo Exemplo: setup-hosts.bat 192.168.18.6 autocarlocadora
    exit /b 1
)

if "%NAME%"=="" (
    echo Uso: setup-hosts.bat [IP] [NOME]
    echo Exemplo: setup-hosts.bat 192.168.18.6 autocarlocadora
    exit /b 1
)

:: Fazer backup
copy C:\Windows\System32\drivers\etc\hosts C:\Windows\System32\drivers\etc\hosts.bak >nul 2>&1

:: Remover entrada anterior se existir
findstr /v "%NAME%" C:\Windows\System32\drivers\etc\hosts > hosts_temp.txt
move hosts_temp.txt C:\Windows\System32\drivers\etc\hosts >nul 2>&1

:: Adicionar nova entrada
echo %IP%  %NAME% >> C:\Windows\System32\drivers\etc\hosts

echo.
echo [OK] Adicionado: %IP%  %NAME%
echo [OK] Agora acesse: http://%NAME%:8080
echo.
echo Para reverter: copy C:\Windows\System32\drivers\etc\hosts.bak C:\Windows\System32\drivers\etc\hosts
