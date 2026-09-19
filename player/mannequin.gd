@tool
class_name Mannequin extends Node3D

@onready var _mannequin_mesh: MeshInstance3D = %MannequinMesh

@onready var mannequins: Dictionary = {
	"m": preload("res://assets/mannequin/m_mannequin/m_mannequin.mesh"),
	"f": preload("res://assets/mannequin/f_mannequin/f_mannequin.mesh"),
}

## The gender of the mannequin model
@export var gender: Mesh:
	set = set_mannequin_gender

func set_mannequin_gender(new_gender: Mesh) -> void:
	gender = new_gender
	_mannequin_mesh.mesh = gender
