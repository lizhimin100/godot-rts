"""Run this to install Claude Code Vision Skill"""
import shutil, os, json

src = os.path.join(os.path.dirname(__file__), "vision.py")
dst = os.path.expanduser("~/.claude/skills/vision/vision.py")

os.makedirs(os.path.dirname(dst), exist_ok=True)
shutil.copy2(src, dst)
print("✅ Copied:", dst)

sp = os.path.expanduser("~/.claude/settings.json")
with open(sp, "r", encoding="utf-8") as f:
    s = json.load(f)
s.setdefault("env", {})
s["env"]["DOUBAO_API_KEY"] = "b27676a8-ef9d-4a29-b942-fc0b5b9ec452"
s["env"]["VISION_PROVIDER"] = "doubao"
s["env"]["VISION_MODEL"] = "ep-m-20260425110124-hxkwj"
with open(sp, "w", encoding="utf-8") as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
print("✅ Settings updated")
print("✅ Vision Skill installed!")
