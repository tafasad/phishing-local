@echo off
echo.
echo ========================================
echo    Desligando o PC em 10 segundos...
echo    Pressione Ctrl+C para cancelar.
echo ========================================
echo.
timeout /t 10 /nobreak >nul
shutdown /s /f /t 0
