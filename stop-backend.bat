@echo off
REM Shopizer Backend Stop Script for Windows
REM This script stops the running Shopizer backend server

echo ======================================
echo Stopping Shopizer Backend Server
echo ======================================
echo.

REM Find and kill Java processes running Spring Boot
tasklist /FI "IMAGENAME eq java.exe" /FO CSV | find /I "java.exe" >nul
if %errorlevel% equ 0 (
    echo Found Java processes. Attempting to stop Shopizer server...

    REM Kill Java processes that contain spring-boot in command line
    for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST ^| find "PID:"') do (
        wmic process where "ProcessId=%%a AND CommandLine like '%%spring-boot%%'" delete 2>nul
    )

    echo Server stopped.
    echo.
) else (
    echo No running Java processes found.
    echo.
)

echo ======================================
echo Done
echo ======================================
pause
