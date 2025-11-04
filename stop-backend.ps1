# Shopizer Backend Stop Script for Windows (PowerShell)
# This script stops the running Shopizer backend server

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Stopping Shopizer Backend Server" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Find and stop Java processes running Spring Boot
$javaProcesses = Get-Process -Name java -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*spring-boot*" -or $_.CommandLine -like "*sm-shop*"
}

if ($javaProcesses) {
    Write-Host "Found Shopizer server running. Stopping..." -ForegroundColor Yellow
    $javaProcesses | ForEach-Object {
        Write-Host "Stopping process with PID: $($_.Id)" -ForegroundColor Yellow
        Stop-Process -Id $_.Id -Force
    }
    Write-Host "Server stopped successfully." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "No running Shopizer server found." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Done" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
