@tool
class_name Mannequin
extends Node3D

@onready var _mannequin_mesh: MeshInstance3D = %MannequinMesh

var gender: Mesh = preload("res://player/mannequin/m_mannequin.mesh"):
	set = set_mannequin_gender


func set_mannequin_gender(new_gender: Mesh) -> void:
	gender = new_gender
	if is_node_ready() and _mannequin_mesh:
		_mannequin_mesh.mesh = gender


func _ready() -> void:
	if _mannequin_mesh and gender:
		_mannequin_mesh.mesh = gender
