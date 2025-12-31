@echo off
REM ############################################
REM  Arcana HarmonyOS Test Runner (Windows)
REM  Wrapper script for PowerShell
REM ############################################

setlocal EnableDelayedExpansion

echo.
echo ========================================
echo    Arcana HarmonyOS Test Runner
echo    Windows Edition
echo ========================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell is not available.
    echo Please install PowerShell or run the .ps1 script directly.
    pause
    exit /b 1
)

REM Get the script directory
set "SCRIPT_DIR=%~dp0"

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-tests.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo [WARNING] Script completed with warnings.
)

echo.
echo Press any key to exit...
pause >nul
