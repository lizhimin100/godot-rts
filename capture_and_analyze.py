"""Capture Godot screenshot and run vision analysis."""
import os, sys, subprocess, json

project_path = r"e:\自定义游戏\RTS"
screenshot_path = os.path.join(project_path, "screenshot.png")

# Step 1: Try godot-e2e launch capture
try:
    from godot_e2e import GodotE2E
    print("[1/3] Launching Godot via godot-e2e...")
    with GodotE2E.launch(project_path, timeout=20.0) as game:
        game.wait_seconds(2.0)
        result = game.screenshot(save_path=screenshot_path)
        print(f"  Screenshot saved: {result}")
except Exception as e:
    print(f"  godot-e2e failed: {e}")

# Step 2: Verify screenshot exists
if not os.path.exists(screenshot_path):
    print("ERROR: No screenshot captured. Is Godot project set up?")
    sys.exit(1)

print(f"  File size: {os.path.getsize(screenshot_path)} bytes")

# Step 3: Run vision analysis
print("\n[2/3] Running vision analysis...")
vision_py = os.path.expanduser(r"~\.claude\skills\vision\vision.py")

# Load env from settings.json
settings_path = os.path.expanduser(r"~\.claude\settings.json")
with open(settings_path, encoding='utf-8') as f:
    settings = json.load(f)
env_vars = settings.get('env', {})

# Build prompt
prompt = (
    "分析这张Godot游戏截图，重点检查布局问题："
    "1) UI元素是否都在屏幕可见区域内"
    "2) 文字/标签是否有截断或溢出"
    "3) 元素之间的间距、对齐是否均匀"
    "4) 是否有意外的空白区域或重叠"
    "5) 颜色对比度是否可读"
    "6) 整体布局是否合理"
)

cmd = [
    sys.executable, vision_py,
    "--provider", "doubao",
    screenshot_path,
    prompt
]

env = os.environ.copy()
for k, v in env_vars.items():
    env[k] = v

print("\n[3/3] Vision model response:\n")
print("=" * 60)
result = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=60)
if result.returncode == 0:
    print(result.stdout)
else:
    print("STDERR:", result.stderr)
print("=" * 60)
