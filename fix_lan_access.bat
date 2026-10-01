@echo off
cd /d "%~dp0"
:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting administrator permissions...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================================
echo      SafeGuard LAN Network ^& Firewall Configuration
echo ============================================================
echo.

echo [1/4] Setting network profiles to Private...
powershell -Command "Set-NetConnectionProfile -InterfaceAlias 'Wi-Fi' -NetworkCategory Private -ErrorAction SilentlyContinue"
powershell -Command "Set-NetConnectionProfile -InterfaceAlias 'Local Area Connection* 2' -NetworkCategory Private -ErrorAction SilentlyContinue"

echo.
echo [2/4] Removing blocking rules and allowing Python...
netsh advfirewall firewall delete rule name="Python" >nul 2>&1
netsh advfirewall firewall add rule name="Python" dir=in action=allow program="C:\Program Files\Python314\python.exe" enable=yes

echo.
echo [3/4] Adding inbound allow rule for Port 3000 (Flutter Web)...
netsh advfirewall firewall add rule name="SafeGuard Dev Frontend 3000" dir=in action=allow protocol=TCP localport=3000

echo.
echo [4/4] Adding inbound allow rule for Port 8000 (FastAPI Backend)...
netsh advfirewall firewall add rule name="SafeGuard Dev Backend 8000" dir=in action=allow protocol=TCP localport=8000

echo.
echo ============================================================
echo   SUCCESS: Ports 3000 and 8000 are now open on the LAN!
echo.
echo   You can now open on your phone:
echo   -- Frontend: http://192.168.0.101:3000
echo   -- Backend:  http://192.168.0.101:8000/health
echo ============================================================
echo.
pause
