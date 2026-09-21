@tool
class_name Mannequin
extends Node3D

var _visual: Node3D
var _anim: AnimationPlayer

var gender: PackedScene:
	set = set_mannequin_gender

const ANIMS := preload("res://assets/mannequin/mannequin_anims.res")

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
	if _anim == null:
		_anim = AnimationPlayer.new()
		_visual.add_child(_anim)
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", ANIMS)


func _ready() -> void:
	if gender:
		set_mannequin_gender(gender)


func _play(anim_name: StringName, blend_time: float = 0.15) -> void:
	if _anim == null or _anim.current_animation == anim_name:
		return
	_anim.play(anim_name, blend_time)


func idle() -> void:
	_play(&"Idle", 0.2)


func crouch_idle() -> void:
	_play(&"Crouch_Idle", 0.2)


func walk() -> void:
	_play(&"Walk", 0.15)


func walk_fwd() -> void:
	_play(&"Walk_Fwd", 0.15)


func walk_fwd_l() -> void:
	_play(&"Walk_Fwd_L", 0.15)


func walk_fwd_r() -> void:
	_play(&"Walk_Fwd_R", 0.15)


func walk_l() -> void:
	_play(&"Walk_L", 0.15)


func walk_r() -> void:
	_play(&"Walk_R", 0.15)


func walk_bwd() -> void:
	_play(&"Walk_Bwd", 0.15)


func walk_bwd_l() -> void:
	_play(&"Walk_Bwd_L", 0.15)


func walk_bwd_r() -> void:
	_play(&"Walk_Bwd_R", 0.15)


func jog_fwd() -> void:
	_play(&"Jog_Fwd", 0.15)


func sprint() -> void:
	_play(&"Sprint", 0.12)


func crouch_fwd() -> void:
	_play(&"Crouch_Fwd", 0.3)


func crouch_fwd_l() -> void:
	_play(&"Crouch_Fwd_L", 0.3)


func crouch_fwd_r() -> void:
	_play(&"Crouch_Fwd_R", 0.3)


func crouch_left() -> void:
	_play(&"Crouch_Left", 0.3)


func crouch_right() -> void:
	_play(&"Crouch_Right", 0.3)


func crouch_bwd() -> void:
	_play(&"Crouch_Bwd", 0.3)


func crouch_bwd_l() -> void:
	_play(&"Crouch_Bwd_L", 0.3)


func crouch_bwd_r() -> void:
	_play(&"Crouch_Bwd_R", 0.3)


func jump_start() -> void:
	_play(&"Jump_Start", 0.0)


func jump() -> void:
	_play(&"Jump", 0.05)


func jump_land() -> void:
	_play(&"Jump_Land", 0.08)


func slide_start() -> void:
	_play(&"Slide_Start", 0.05)


func slide() -> void:
	_play(&"Slide", 0.1)


func slide_exit() -> void:
	_play(&"Slide_Exit", 0.12)
