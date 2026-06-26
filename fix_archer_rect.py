import subprocess
with open('e:/类魔兽/类魔兽/单位/弓箭手/弓箭手.tscn','r',encoding='utf-8') as f:
    lines = f.readlines()
# Fix line 25 (index 24): RESET animation -> 1536
if 'Rect2(0, 0, 1152, 192)' in lines[24]:
    lines[24] = lines[24].replace('Rect2(0, 0, 1152, 192)', 'Rect2(0, 0, 1536, 192)')
    print('Fixed line 25 (RESET)')
# Fix line 198 (index 197): Sprite2D region_rect -> 1536
if 'Rect2(0, 0, 1152, 192)' in lines[197]:
    lines[197] = lines[197].replace('Rect2(0, 0, 1152, 192)', 'Rect2(0, 0, 1536, 192)')
    print('Fixed line 198 (Sprite2D region_rect)')
with open('e:/类魔兽/类魔兽/单位/弓箭手/弓箭手.tscn','w',encoding='utf-8') as f:
    f.writelines(lines)
result = subprocess.run(['grep','-n','Rect2','e:/类魔兽/类魔兽/单位/弓箭手/弓箭手.tscn'],capture_output=True,text=True)
print(result.stdout)
