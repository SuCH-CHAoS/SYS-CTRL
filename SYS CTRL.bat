@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title SYS CTRL v2.0 - Made By SuCH CHAoS

fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator access for SYS CTRL v2.0...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SYSCTRL_SCRIPT=%~dp0SystemControl.ps1"
set "SYSCTRL_BOOT=JABjAG8AZABlACAAPQAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBSAGUAYQBkAEEAbABsAFQA"
set "SYSCTRL_BOOT=%SYSCTRL_BOOT%ZQB4AHQAKAAkAGUAbgB2ADoAUwBZAFMAQwBUAFIATABfAFMAQwBSAEkAUABUACwAIABbAFQA"
set "SYSCTRL_BOOT=%SYSCTRL_BOOT%ZQB4AHQALgBFAG4AYwBvAGQAaQBuAGcAXQA6ADoAVQBUAEYAOAApAAoAJgAgACgAWwBzAGMA"
set "SYSCTRL_BOOT=%SYSCTRL_BOOT%cgBpAHAAdABiAGwAbwBjAGsAXQA6ADoAQwByAGUAYQB0AGUAKAAkAGMAbwBkAGUAKQApAA=="
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand %SYSCTRL_BOOT%
set "SYSCTRL_EXIT=%ERRORLEVEL%"
endlocal & exit /b %SYSCTRL_EXIT%
