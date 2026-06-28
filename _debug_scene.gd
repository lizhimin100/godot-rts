extends Node

var exists = ResourceLoader.exists("res://场景/平面.tscn")
_custom_print("e:" + str(exists))
var scene = ResourceLoader.load("res://场景/平面.tscn")
_custom_print("l:" + str(scene != null))
