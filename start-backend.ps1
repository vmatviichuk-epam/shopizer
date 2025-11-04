# Shopizer Backend Startup Script for Windows (PowerShell)
# This script starts the Shopizer e-commerce backend server

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Starting Shopizer Backend Server" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if Java is available
try {
    $javaVersion = java -version 2>&1 | Select-String "version" | Select-Object -First 1
    Write-Host "Java version detected: $javaVersion" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "Error: Java is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Java 21 or higher" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Build all modules first (required for multi-module project)
Write-Host "Building project modules (skipping tests for faster startup)..." -ForegroundColor Yellow
Write-Host "This may take a few moments on first run..." -ForegroundColor Yellow
Write-Host ""

& .\mvnw.cmd clean install -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Build successful! Starting the server..." -ForegroundColor Green
Write-Host ""

# Navigate to sm-shop directory and start the server
Push-Location sm-shop

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Could not find sm-shop directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

& ..\mvnw.cmd spring-boot:run -DskipTests

Pop-Location

# If the server stops, show this message
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Server has stopped" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
