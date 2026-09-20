@tool
class_name Mannequin
extends Node3D

@onready var _mannequin_mesh: MeshInstance3D = %MannequinMesh
@onready var _anim: AnimationPlayer = $AnimationPlayer

var gender: Mesh = preload("res://player/mannequin/m_mannequin.mesh"):
	set = set_mannequin_gender


func set_mannequin_gender(new_gender: Mesh) -> void:
	gender = new_gender
	if is_node_ready() and _mannequin_mesh:
		_mannequin_mesh.mesh = gender


func _ready() -> void:
	if _mannequin_mesh and gender:
		_mannequin_mesh.mesh = gender


func mannequin_idle() -> void:
	_play(&"Idle", 0.12)


func mannequin_sprint() -> void:
	_play(&"Sprint", 0.1)


func mannequin_jump_start() -> void:
	_play(&"Jump_Start", 0.0)


func mannequin_jump_loop() -> void:
	_play(&"Jump_Loop", 0.0)


func mannequin_jump_land() -> void:
	_play(&"Jump_Land", 0.05)


func _play(anim_name: StringName, blend_time: float) -> void:
	if _anim == null or _anim.current_animation == anim_name:
		return
	_anim.play(anim_name, blend_time)
