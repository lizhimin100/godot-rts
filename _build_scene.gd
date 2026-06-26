# 1) Read the backup scene
var f = FileAccess.open("res://场景/平面.tscn.bak", FileAccess.READ)
var txt = f.get_as_text(true)
f.close()

# 2) Write a minimal test version - just header + one ext_resource
var minimal_txt = "[gd_scene format=3]\n\n"
minimal_txt += '[ext_resource type="TileSet" path="res://设置好的图层/草地.tres" id="1"]\n\n'
minimal_txt += '[node name="Test" type="Node2D"]\n'

var f2 = FileAccess.open("res://场景/_minimal.tscn", FileAccess.WRITE)
f2.store_string(minimal_txt)
f2.close()

var s = ResourceLoader.load("res://场景/_minimal.tscn")
_custom_print("min:" + str(s != null))

# 3) Write with format=4 + uid
var format4_txt = "[gd_scene format=4 uid=\"uid://test12345\"]\n\n"
format4_txt += '[ext_resource type="TileSet" uid="uid://b5hj8m718ipyb" path="res://设置好的图层/草地.tres" id="1_e2ydd"]\n\n'
format4_txt += '[node name="Test" type="Node2D"]\n'

var f3 = FileAccess.open("res://场景/_format4.tscn", FileAccess.WRITE)
f3.store_string(format4_txt)
f3.close()

var s2 = ResourceLoader.load("res://场景/_format4.tscn")
_custom_print("f4:" + str(s2 != null))
