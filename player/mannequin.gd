@tool
class_name Mannequin
extends Node3D

var _visual: Node3D
var _anim: AnimationPlayer

var gender: PackedScene:
	set = set_mannequin_gender


func set_mannequin_gender(new_gender: PackedScene) -> void:
	gender = new_gender
	if not is_node_ready() or gender == null:
		return
	
	if _visual:
		_visual.free()
		_visual = null
	_visual = gender.instantiate()
	add_child(_visual)
	_anim = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	if gender:
		set_mannequin_gender(gender)
		
func _play(anim_name: StringName, blend_time: float = 0.15) -> void:
	if _anim == null or _anim.current_animation == anim_name:
		return
	_anim.play(anim_name, blend_time)

func mannequin_idle() -> void:
	pass
