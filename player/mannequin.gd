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
	_play(&"Idle")


func mannequin_crouch_idle() -> void:
	_play(&"Crouch_Idle")


func mannequin_walk() -> void:
	_play(&"Walk")


func mannequin_walk_fwd() -> void:
	_play(&"Walk_Fwd")


func mannequin_walk_fwd_l() -> void:
	_play(&"Walk_Fwd_L")


func mannequin_walk_fwd_r() -> void:
	_play(&"Walk_Fwd_R")


func mannequin_walk_l() -> void:
	_play(&"Walk_L")


func mannequin_walk_r() -> void:
	_play(&"Walk_R")


func mannequin_walk_bwd() -> void:
	_play(&"Walk_Bwd")


func mannequin_walk_bwd_l() -> void:
	_play(&"Walk_Bwd_L")


func mannequin_walk_bwd_r() -> void:
	_play(&"Walk_Bwd_R")


func mannequin_jog_fwd() -> void:
	_play(&"Jog_Fwd")


func mannequin_sprint() -> void:
	_play(&"Sprint")


func mannequin_crouch_fwd() -> void:
	_play(&"Crouch_Fwd")


func mannequin_jump_start() -> void:
	_play(&"Jump_Start")


func mannequin_jump() -> void:
	_play(&"Jump")


func mannequin_jump_land() -> void:
	_play(&"Jump_Land")


func mannequin_slide_start() -> void:
	_play(&"Slide_Start")


func mannequin_slide() -> void:
	_play(&"Slide")


func mannequin_slide_exit() -> void:
	_play(&"Slide_Exit")
