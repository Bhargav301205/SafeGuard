# SafeGuard LAN Fix Script - Run as Administrator
# This script fixes Windows Firewall blocking and sets the network profile to Private

Write-Host "=== SafeGuard LAN Access Fix ===" -ForegroundColor Cyan

# 1. Set Wi-Fi to Private
Write-Host "`n[1/5] Setting Wi-Fi network to Private..." -ForegroundColor Yellow
try {
    Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
    Write-Host "  Done: Wi-Fi is now Private" -ForegroundColor Green
} catch {
    Write-Host "  Note: $_" -ForegroundColor Red
}

# 2. Remove blocking Python rule
Write-Host "`n[2/5] Removing blocking Python firewall rules..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="Python" | Out-Null
Write-Host "  Done: Python block rules removed" -ForegroundColor Green

# 3. Allow port 3000
Write-Host "`n[3/5] Opening port 3000 (Flutter Web Frontend)..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="SafeGuard Port 3000" | Out-Null
netsh advfirewall firewall add rule name="SafeGuard Port 3000" dir=in action=allow protocol=TCP localport=3000
Write-Host "  Done: Port 3000 allowed" -ForegroundColor Green

# 4. Allow port 8000
Write-Host "`n[4/5] Opening port 8000 (FastAPI Backend)..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="SafeGuard Port 8000" | Out-Null
netsh advfirewall firewall add rule name="SafeGuard Port 8000" dir=in action=allow protocol=TCP localport=8000
Write-Host "  Done: Port 8000 allowed" -ForegroundColor Green

# 5. Allow python.exe explicitly 
Write-Host "`n[5/5] Allowing Python executable through firewall..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="SafeGuard Python Allow" | Out-Null
netsh advfirewall firewall add rule name="SafeGuard Python Allow" dir=in action=allow program="C:\Program Files\Python314\python.exe" enable=yes
Write-Host "  Done: python.exe allowed" -ForegroundColor Green

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
netsh advfirewall firewall show rule name="SafeGuard Port 3000" | Select-String "Action"
netsh advfirewall firewall show rule name="SafeGuard Port 8000" | Select-String "Action"

$profile = Get-NetConnectionProfile | Where-Object { $_.InterfaceAlias -eq "Wi-Fi" }
Write-Host "`nWi-Fi profile: $($profile.NetworkCategory)" -ForegroundColor White

Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
Write-Host "Open on your phone: http://192.168.0.101:3000" -ForegroundColor Cyan
Write-Host "Backend health:     http://192.168.0.101:8000/health" -ForegroundColor Cyan
Read-Host "`nPress Enter to close"
