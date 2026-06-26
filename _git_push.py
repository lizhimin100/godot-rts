import subprocess, os, sys
os.chdir("e:/类魔兽/类魔兽")
steps = [
    ["git", "add", "-A"],
    ["git", "commit", "-m", "修复平面.tscn缺失节点 + 战争迷雾多单位视野"],
    ["git", "push", "origin", "master"]
]
for s in steps:
    r = subprocess.run(s, capture_output=True, text=True, timeout=120)
    print(f"CMD: {' '.join(s)}")
    print(f"OUT: {r.stdout}")
    print(f"ERR: {r.stderr}")
    print(f"EXIT: {r.returncode}")
    if r.returncode != 0:
        sys.exit(r.returncode)
print("ALL OK")
