@echo off
chcp 65001 >nul
title 安装 Claude Code Vision Skill
echo ====================================
echo  安装 Claude Code Vision Skill
echo ====================================
echo.

:: 1. 复制 vision.py
echo [1/2] 复制 vision.py...
mkdir "%USERPROFILE%\.claude\skills\vision" 2>nul
copy /Y "%~dp0vision.py" "%USERPROFILE%\.claude\skills\vision\vision.py"
echo     ✅ 已完成
echo.

:: 2. 配置 settings.json
echo [2/2] 配置环境变量...
powershell -NoProfile -Command ^
"$path = [Environment]::GetFolderPath('UserProfile') + '\.claude\settings.json'; ^
$json = Get-Content $path -Raw | ConvertFrom-Json; ^
if (-not $json.env) { $json | Add-Member -NotePropertyName 'env' -NotePropertyValue @{} }; ^
$json.env.DOUBAO_API_KEY = 'b27676a8-ef9d-4a29-b942-fc0b5b9ec452'; ^
$json.env.VISION_PROVIDER = 'doubao'; ^
$json.env.VISION_MODEL = 'ep-m-20260425110124-hxkwj'; ^
$json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8; ^
Write-Host '    ✅ 已完成'"
echo.
echo ====================================
echo  安装完成！请重启 Claude Code
echo ====================================
echo.
pause
