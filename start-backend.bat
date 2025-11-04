@echo off
REM Shopizer Backend Startup Script for Windows
REM This script starts the Shopizer e-commerce backend server

echo ======================================
echo Starting Shopizer Backend Server
echo ======================================
echo.

REM Check if Java is available
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Java is not installed or not in PATH
    echo Please install Java 21 or higher
    pause
    exit /b 1
)

echo Java version detected:
java -version 2>&1 | findstr /i "version"
echo.

REM Build all modules first (required for multi-module project)
echo Building project modules (skipping tests for faster startup)...
echo This may take a few moments on first run...
echo.

call mvnw.cmd clean install -DskipTests
if %errorlevel% neq 0 (
    echo Error: Build failed
    pause
    exit /b 1
)

echo.
echo Build successful! Starting the server...
echo.

REM Navigate to sm-shop directory and start the server
cd sm-shop
if %errorlevel% neq 0 (
    echo Error: Could not find sm-shop directory
    pause
    exit /b 1
)

call ..\mvnw.cmd spring-boot:run -DskipTests

REM If the server stops, show this message
echo.
echo ======================================
echo Server has stopped
echo ======================================
pause
