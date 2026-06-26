#!/usr/bin/env python3
"""一键安装 Claude Code Vision Skill"""
import shutil, os

src = r"E:\类魔兽\类魔兽\vision.py"
dst = os.path.expanduser(r"~\.claude\skills\vision\vision.py")

os.makedirs(os.path.dirname(dst), exist_ok=True)
shutil.copy2(src, dst)
print(f"✅ 已复制到: {dst}")

# 配置环境变量
import json
settings_path = os.path.expanduser(r"~\.claude\settings.json")
with open(settings_path, 'r', encoding='utf-8') as f:
    settings = json.load(f)

settings.setdefault("env", {})
settings["env"]["DOUBAO_API_KEY"] = "b27676a8-ef9d-4a29-b942-fc0b5b9ec452"
settings["env"]["VISION_PROVIDER"] = "doubao"
settings["env"]["VISION_MODEL"] = "ep-m-20260425110124-hxkwj"

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("✅ 环境变量已配置")
print("✅ 安装完成！")
