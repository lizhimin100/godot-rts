@echo off
echo 安装 Claude Code Vision Skill...
copy /Y "E:\类魔兽\类魔兽\vision.py" "%USERPROFILE%\.claude\skills\vision\vision.py"
echo 已复制 vision.py 到技能目录
echo.
echo 请手动编辑 %USERPROFILE%\.claude\settings.json
echo 在 env 中添加以下三行：
echo   "DOUBAO_API_KEY": "b27676a8-ef9d-4a29-b942-fc0b5b9ec452"
echo   "VISION_PROVIDER": "doubao"
echo   "VISION_MODEL": "ep-m-20260425110124-hxkwj"
echo.
echo 安装完成！
pause
