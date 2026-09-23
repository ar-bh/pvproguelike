@tool
class_name Mannequin
extends Node3D

var _visual: Node3D
var _anim: AnimationPlayer
var _tree: AnimationTree
var _locomo: AnimationNodeAnimation
var _locomo_a: AnimationNodeAnimation
var _locomo_b: AnimationNodeAnimation
var _locomo_xfade: AnimationNodeTransition
var _overlay: AnimationNodeAnimation
var _aim: PunchAimModifier
var _use_b := false
var _upper_age := 0.0
var _current := &""

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
	_tree = null
	_locomo = null
	_locomo_a = null
	_locomo_b = null
	_locomo_xfade = null
	_overlay = null
	_aim = null
	_current = &""
	_visual = gender.instantiate()
	add_child(_visual)
	_anim = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_visual.add_child(_anim)
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", ANIMS)
	_anim.autoplay = ""
	if Engine.is_editor_hint():
		_anim.active = false
		_anim.stop()
		return
	_configure_clip_modes()
	_setup_upper()


func _ready() -> void:
	if gender:
		set_mannequin_gender(gender)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_punching():
		_upper_age += delta
	if _aim:
		_aim.influence = move_toward(_aim.influence, 1.0 if _wants_look() else 0.0, delta / 0.25)


func _configure_clip_modes() -> void:
	for name in ANIMS.get_animation_list():
		var anim := ANIMS.get_animation(name)
		if anim == null:
			continue
		var n := String(name)
		var oneshot := (
			n == "Jump"
			or "Start" in n or "Land" in n or "Enter" in n or "Exit" in n
			or "Punch" in n or "Hit" in n
		)
		anim.loop_mode = Animation.LOOP_NONE if oneshot else Animation.LOOP_LINEAR


func _setup_upper() -> void:
	var skel := _visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	_tree = AnimationTree.new()
	_visual.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	_locomo_a = AnimationNodeAnimation.new()
	_locomo_a.animation = &"Idle"
	_locomo_b = AnimationNodeAnimation.new()
	_locomo_b.animation = &"Idle"
	_overlay = AnimationNodeAnimation.new()
	_overlay.animation = &"Punch_Jab"
	_locomo_xfade = AnimationNodeTransition.new()
	_locomo_xfade.xfade_time = 0.12
	_locomo_xfade.add_input("a")
	_locomo_xfade.add_input("b")
	var scale_a := AnimationNodeTimeScale.new()
	var scale_b := AnimationNodeTimeScale.new()

	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.25
	shot.fadeout_time = 0.3
	shot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
	shot.filter_enabled = true
	var prefix := _anim_track_prefix()
	for b in skel.get_bone_count():
		var bone := skel.get_bone_name(b)
		var n := bone.to_lower()
		if n == "root" or "pelvis" in n or "hip" in n or "thigh" in n or "calf" in n or "foot" in n or "ball" in n or "toe" in n:
			continue
		if (
			"spine" in n or "chest" in n or "neck" in n or "head" in n
			or "shoulder" in n or "clavicle" in n or "arm" in n or "hand" in n
			or "finger" in n or "thumb" in n or "index" in n or "middle" in n
			or "ring" in n or "pinky" in n
		):
			shot.set_filter_path(NodePath(prefix + bone), true)

	var blend := AnimationNodeBlendTree.new()
	blend.add_node("locomo_a", _locomo_a, Vector2(0, 0))
	blend.add_node("locomo_b", _locomo_b, Vector2(0, 80))
	blend.add_node("scale_a", scale_a, Vector2(90, 0))
	blend.add_node("scale_b", scale_b, Vector2(90, 80))
	blend.add_node("locomo_xfade", _locomo_xfade, Vector2(180, 40))
	blend.add_node("overlay", _overlay, Vector2(0, 180))
	blend.add_node("shot", shot, Vector2(380, 80))
	blend.connect_node("scale_a", 0, "locomo_a")
	blend.connect_node("scale_b", 0, "locomo_b")
	blend.connect_node("locomo_xfade", 0, "scale_a")
	blend.connect_node("locomo_xfade", 1, "scale_b")
	blend.connect_node("shot", 0, "locomo_xfade")
	blend.connect_node("shot", 1, "overlay")
	blend.connect_node("output", 0, "shot")
	_tree.tree_root = blend
	_tree.active = true
	_locomo = _locomo_a
	_use_b = false
	_current = &"Idle"
	_aim = PunchAimModifier.new()
	_aim.influence = 0.0
	skel.add_child(_aim)
	_aim.cache_bones(skel)


func _anim_track_prefix() -> String:
	if ANIMS.has_animation(&"Punch_Jab"):
		var jab := ANIMS.get_animation(&"Punch_Jab")
		if jab.get_track_count() > 0:
			var p := String(jab.track_get_path(0))
			var i := p.rfind(":")
			if i >= 0:
				return p.substr(0, i + 1)
	return "Armature/Skeleton3D:"


func _play(anim_name: StringName, sync_phase: bool = true, speed: float = 1.0) -> void:
	if Engine.is_editor_hint():
		return
	if anim_name == _current:
		return
	if _locomo_xfade == null or _tree == null:
		if _anim and _anim.current_animation != anim_name:
			_anim.play(anim_name, 0.12, speed)
			_current = anim_name
		return
	_locomo_xfade.xfade_time = _xfade_time(_current, anim_name)
	_use_b = not _use_b
	if _use_b:
		_locomo_b.animation = anim_name
		_locomo = _locomo_b
		_tree.set("parameters/scale_b/scale", speed)
		_tree.set("parameters/locomo_xfade/transition_request", "b")
	else:
		_locomo_a.animation = anim_name
		_locomo = _locomo_a
		_tree.set("parameters/scale_a/scale", speed)
		_tree.set("parameters/locomo_xfade/transition_request", "a")
	_current = anim_name


func _xfade_time(from: StringName, to: StringName) -> float:
	if to == &"Jump_Start" or to == &"Jump" or to == &"Jump_Loop":
		return 0.08
	if to == &"Jump_Land":
		return 0.12
	if _is_jump_clip(from):
		return 0.2
	if to == &"Idle" or to == &"Crouch_Idle":
		return 0.2
	return 0.12


func _is_jump_clip(anim_name: StringName) -> bool:
	match anim_name:
		&"Jump", &"Jump_Start", &"Jump_Loop", &"Jump_Land":
			return true
		_:
			return false


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
	_stop_upper()
	_play(&"Slide_Start", false)


func slide() -> void:
	_stop_upper()
	_play(&"Slide", false)


func slide_exit() -> void:
	_stop_upper()
	_play(&"Slide_Exit", false)


#region fists
func set_punch_look(world_dir: Vector3) -> void:
	if _aim == null or world_dir.length_squared() < 0.0001:
		return
	var local := global_transform.basis.inverse() * world_dir.normalized()
	_aim.target_pitch = atan2(-local.y, local.z)


func punch_jab() -> void:
	_play_upper(&"Punch_Jab")


func punch_cross() -> void:
	_play_upper(&"Punch_Cross")


func knockback() -> void:
	_stop_upper()
	_play(&"Hit_From_Front", false)


func _play_upper(anim_name: StringName) -> void:
	if _tree == null or _overlay == null:
		_play(anim_name, false)
		return
	_overlay.animation = anim_name
	_tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_upper_age = 0.0


func _stop_upper() -> void:
	if _tree:
		_tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_upper_age = 0.0
#endregion


func is_transition() -> bool:
	match _current:
		&"Crouch_Enter", &"Crouch_Exit", &"Slide_Start", &"Slide_Exit", &"Hit_From_Front":
			return true
		_:
			return false


func is_slide_start() -> bool:
	return _current == &"Slide_Start"


func is_punching() -> bool:
	return _tree != null and bool(_tree.get("parameters/shot/active"))


func can_chain_punch() -> bool:
	return is_punching() and _upper_age >= 0.2


func is_knockback() -> bool:
	return _current == &"Hit_From_Front"


func _wants_look() -> bool:
	if is_punching():
		return true
	match _current:
		&"Idle", &"Crouch_Idle":
			return true
		_:
			return false


class PunchAimModifier extends SkeletonModifier3D:
	var pitch := 0.0
	var target_pitch := 0.0
	var _spine: PackedInt32Array
	var _weights: PackedFloat32Array

	func cache_bones(skel: Skeleton3D) -> void:
		var idxs: Array[int] = []
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().begins_with("spine"):
				idxs.append(i)
		_spine = PackedInt32Array(idxs)
		var n := _spine.size()
		_weights.resize(n)
		var total := 0.0
		for i in n:
			var w := float(n - i)
			_weights[i] = w
			total += w
		if total > 0.0:
			for i in n:
				_weights[i] /= total

	func _process_modification_with_delta(delta: float) -> void:
		var skel := get_skeleton()
		if skel == null or _spine.is_empty():
			return
		if delta > 0.0:
			pitch = lerpf(pitch, target_pitch, 1.0 - exp(-14.0 * delta))
		if is_zero_approx(pitch):
			return
		for i in _spine.size():
			var idx := _spine[i]
			var extra := Quaternion(Vector3.RIGHT, pitch * _weights[i])
			skel.set_bone_pose_rotation(idx, skel.get_bone_pose_rotation(idx) * extra)
