@echo off
echo ========================================
echo  SafeGuard - Fix Firewall + Start Servers
echo  Run as Administrator for firewall rules
echo ========================================
echo.

:: Remove old rules and add fresh ones
netsh advfirewall firewall delete rule name="SafeGuard-3000" >nul 2>&1
netsh advfirewall firewall delete rule name="SafeGuard-3443" >nul 2>&1
netsh advfirewall firewall delete rule name="SafeGuard-8000" >nul 2>&1
netsh advfirewall firewall delete rule name="Python" >nul 2>&1
netsh advfirewall firewall add rule name="Python" dir=in action=allow program="C:\Program Files\Python314\python.exe" enable=yes
netsh advfirewall firewall add rule name="SafeGuard-3000" dir=in action=allow protocol=TCP localport=3000
netsh advfirewall firewall add rule name="SafeGuard-3443" dir=in action=allow protocol=TCP localport=3443
netsh advfirewall firewall add rule name="SafeGuard-8000" dir=in action=allow protocol=TCP localport=8000

echo [OK] Firewall rules updated for Python, ports 3000, 3443, and 8000
echo.

:: Show current Wi-Fi IP
echo Your current Wi-Fi IP is:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4" ^| findstr /V "169\|137"') do (
    set MYIP=%%a
)
set MYIP=%MYIP: =%
echo   %MYIP%
echo.

:: Kill any old servers on these ports
echo [0/3] Clearing old servers...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":8000\|:3443\|:3000" ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 1 /nobreak >nul

:: Regenerate cert (in case IP changed)
echo [1/3] Regenerating SSL certificate for %MYIP%...
cd /d d:\rasana
python gen_cert.py

:: Start backend
echo [2/3] Starting FastAPI backend on port 8000...
start "SafeGuard-Backend" cmd /k "cd /d d:\rasana\backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
timeout /t 2 /nobreak >nul

:: Start HTTPS frontend
echo [3/3] Starting HTTPS frontend on port 3443...
start "SafeGuard-HTTPS-Frontend" cmd /k "cd /d d:\rasana && python https_server.py"
timeout /t 2 /nobreak >nul

echo.
echo ========================================
echo  DONE! Both servers are starting...
echo.
echo  Open on your PHONE (HTTPS - GPS works):
echo  https://%MYIP%:3443
echo.
echo  On phone: tap Advanced then Proceed to
echo  accept the self-signed certificate once.
echo  After that GPS and location will work!
echo ========================================
pause
