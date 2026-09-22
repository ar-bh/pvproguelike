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


func _play(anim_name: StringName, sync_phase: bool = true, speed: float = 1.0) -> void:
	if _anim == null or _anim.current_animation == anim_name:
		return
	var t := _anim.current_animation_position
	var old_len := _anim.current_animation_length
	_anim.play(anim_name, 0.15, speed)
	if not sync_phase or old_len <= 0.001:
		return
	var new_len := _anim.current_animation_length
	if new_len <= 0.001:
		return
	_anim.seek(fposmod(t / old_len * new_len, new_len), true)


func idle() -> void:
	_play(&"Idle", false)


func crouch_idle() -> void:
	_play(&"Crouch_Idle", false)


func walk() -> void:
	_play(&"Walk")


func walk_fwd() -> void:
	_play(&"Walk_Fwd")


func walk_fwd_l() -> void:
	_play(&"Walk_Fwd_L")


func walk_fwd_r() -> void:
	_play(&"Walk_Fwd_R")


func walk_l() -> void:
	_play(&"Walk_L")


func walk_r() -> void:
	_play(&"Walk_R")


func walk_bwd() -> void:
	_play(&"Walk_Bwd")


func walk_bwd_l() -> void:
	_play(&"Walk_Bwd_L")


func walk_bwd_r() -> void:
	_play(&"Walk_Bwd_R")


func jog_fwd() -> void:
	_play(&"Jog_Fwd")


func sprint() -> void:
	_play(&"Sprint")


func crouch_enter() -> void:
	_play(&"Crouch_Enter", false, 4.0)


func crouch_exit() -> void:
	_play(&"Crouch_Exit", false, 4.0)


func crouch_fwd() -> void:
	_play(&"Crouch_Fwd")


func crouch_fwd_l() -> void:
	_play(&"Crouch_Fwd_L")


func crouch_fwd_r() -> void:
	_play(&"Crouch_Fwd_R")


func crouch_left() -> void:
	_play(&"Crouch_Left")


func crouch_right() -> void:
	_play(&"Crouch_Right")


func crouch_bwd() -> void:
	_play(&"Crouch_Bwd")


func crouch_bwd_l() -> void:
	_play(&"Crouch_Bwd_L")


func crouch_bwd_r() -> void:
	_play(&"Crouch_Bwd_R")


func jump_start() -> void:
	_play(&"Jump_Start", false)


func jump() -> void:
	_play(&"Jump", false)


func jump_land() -> void:
	_play(&"Jump_Land", false)


func slide_start() -> void:
	_play(&"Slide_Start", false)


func slide() -> void:
	_play(&"Slide", false)


func slide_exit() -> void:
	_play(&"Slide_Exit", false)


func is_transition() -> bool:
	if _anim == null or not _anim.is_playing():
		return false
	match _anim.current_animation:
		&"Crouch_Enter", &"Crouch_Exit", &"Slide_Start", &"Slide_Exit":
			return true
		_:
			return false

func is_slide_start() -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation == &"Slide_Start"
