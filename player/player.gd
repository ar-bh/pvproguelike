@tool
class_name Player
extends CharacterBody3D

#region gender
enum Gender { MALE, FEMALE }
@export var gender: Gender = Gender.MALE:
	set(new_gender):
		gender = new_gender
		if is_node_ready():
			_apply_gender()

@onready var genders: Array[PackedScene] = [
	preload("res://assets/mannequin/m_mannequin.glb"),
	preload("res://assets/mannequin/f_mannequin.glb"),
]
#endregion

#region camera
@export_group("Camera")
@export_range(1.0, 20.0) var camera_distance := 3.0
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var gamepad_sensitivity := 2.5
@export var model_turn_speed := 100.0
@export var model_sprint_turn_speed := 15.0

var rotation_lock := true
var _camera_input_direction := Vector2.ZERO
#endregion

#region movement
@export_group("Movement")
@export var move_speed := 6.0
@export var sprint_speed := 8.0
@export var crouch_speed := 3.0
@export var jump_velocity := 4.5
@export var fall_gravity_multiplier := 2.5
@export var slide_speed := 12.0
@export var slide_duration := 0.85
@export var slide_jump_lock := 0.25
@export var slide_speed_curve: Curve
#endregion

#region fists
var _punch_queued := false
#endregion

#region nodes
@onready var _mannequin: Mannequin = $Mannequin
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = %Camera3D
#endregion

#region state
var movement_enabled := true

var _was_crouching := false
var _sliding := false
var _slide_time := 0.0
var _slide_dir := Vector3.ZERO
var _slide_jump_queued := false
var _jump_start_lock := 0.0
var _in_jump := false
var _land_lock := 0.0
var _was_airborne := false
var _walk_octant := 0
var _crouch_octant := 0
var _floor_snap := 0.35
#endregion

#region lifecycle
func _ready() -> void:
	_apply_gender()
	_floor_snap = floor_snap_length
	_spring_arm.add_excluded_object(get_rid())
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_gender() -> void:
	if _mannequin:
		_mannequin.gender = genders[gender]


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var is_camera_motion := (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity
#endregion

#region physics
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_camera_pivot.rotation.y -= look.x * gamepad_sensitivity * delta
	_camera_pivot.rotation.x += look.y * gamepad_sensitivity * delta
	_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -PI / 3.0, PI / 3.0)

	_apply_gravity(delta)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := _get_move_direction(input)
	var crouching := Input.is_action_pressed("crouch")
	var sprinting := (
		Input.is_action_pressed("sprint")
		and not crouching
		and input != Vector2.ZERO
	)

	if (
		movement_enabled
		and not _sliding
		and is_on_floor()
		and Input.is_action_just_pressed("crouch")
		and Input.is_action_pressed("sprint")
		and direction.length_squared() > 0.01
	):
		_start_slide(direction)

	if _sliding:
		_slide_time += delta
		if _slide_time >= slide_duration:
			_stop_slide()

	var punching := _mannequin.is_punching()
	if Input.is_action_just_pressed("attack") and not _sliding:
		if punching and _mannequin.can_chain_punch():
			_punch_queued = true
		elif not punching:
			_mannequin.punch_jab()
			_punch_queued = false
			punching = true

	movement_enabled = not _mannequin.is_knockback()

	if punching:
		_face_camera(delta)
	elif _sliding:
		rotation_lock = false
		_face_vector(delta, _slide_dir)
	elif rotation_lock:
		_face_camera(delta)
	else:
		_face_vector(delta, direction)
	rotation_lock = not sprinting and not _sliding
	_mannequin.set_punch_look(-_camera.global_basis.z)

	var jumping := is_on_floor() and movement_enabled and (
		Input.is_action_just_pressed("jump")
		or (_slide_jump_queued and _sliding and _slide_time >= slide_jump_lock)
	)
	var speed := move_speed
	if punching:
		speed = crouch_speed
	if not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _sliding:
		var t := clampf(_slide_time / slide_duration, 0.0, 1.0)
		var falloff := 1.0
		if slide_speed_curve:
			falloff = slide_speed_curve.sample(t)
		speed = slide_speed * falloff
		velocity.x = _slide_dir.x * speed
		velocity.z = _slide_dir.z * speed
	else:
		if punching:
			speed = crouch_speed
		elif crouching:
			speed = crouch_speed
		elif sprinting:
			speed = sprint_speed
		if is_on_floor() and not jumping:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		elif direction.length_squared() < 0.0001:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var keep := maxf(
				Vector3(velocity.x, 0.0, velocity.z).length(),
				direction.length() * speed
			)
			var dir := direction.normalized()
			velocity.x = dir.x * keep
			velocity.z = dir.z * keep

	if Input.is_action_just_pressed("jump") and is_on_floor() and movement_enabled:
		if _sliding and _slide_time < slide_jump_lock:
			_slide_jump_queued = true
		else:
			velocity.y = jump_velocity
			_jump_start_lock = 0.25
			_in_jump = true
			_mannequin.jump_start()
			if _sliding:
				_stop_slide(false)
	elif _slide_jump_queued and _sliding and is_on_floor() and _slide_time >= slide_jump_lock:
		velocity.y = jump_velocity
		_jump_start_lock = 0.25
		_in_jump = true
		_mannequin.jump_start()
		_stop_slide(false)

	if _jump_start_lock > 0.0 or velocity.y > 0.05:
		floor_snap_length = 0.0
	else:
		floor_snap_length = _floor_snap

	if _land_lock > 0.0:
		_land_lock = maxf(_land_lock - delta, 0.0)

	move_and_slide()
	
	var on_floor := is_on_floor()
	if on_floor and velocity.y <= 0.0 and _jump_start_lock <= 0.0:
		_in_jump = false
	var airborne := _in_jump or not on_floor or _jump_start_lock > 0.0
	var just_landed := _was_airborne and not airborne
	_was_airborne = airborne
	if _jump_start_lock > 0.0:
		_jump_start_lock = maxf(_jump_start_lock - delta, 0.0)

	if _mannequin.is_knockback():
		pass
	elif _mannequin.is_punching():
		if _punch_queued and _mannequin.can_chain_punch():
			_mannequin.punch_cross()
			_punch_queued = false
		if airborne:
			if _jump_start_lock <= 0.0:
				_mannequin.jump()
		elif input == Vector2.ZERO:
			_mannequin.idle()
		else:
			_play_walk(input)
	elif airborne:
		if _jump_start_lock <= 0.0:
			_mannequin.jump()
	elif _sliding:
		if _slide_time >= slide_jump_lock and not _mannequin.is_transition():
			_mannequin.slide()
	elif just_landed and input == Vector2.ZERO:
		_mannequin.jump_land()
		_land_lock = 0.22
	elif _land_lock > 0.0 and input == Vector2.ZERO:
		pass
	elif crouching and not _was_crouching:
		_mannequin.crouch_enter()
	elif not crouching and _was_crouching:
		_mannequin.crouch_exit()
	elif _mannequin.is_transition():
		pass
	elif crouching:
		if input == Vector2.ZERO:
			_mannequin.crouch_idle()
		else:
			_play_crouch(input)
	elif sprinting:
		_mannequin.sprint()
	elif input == Vector2.ZERO:
		_mannequin.idle()
	else:
		_play_walk(input)

	if not _sliding:
		_was_crouching = crouching
#endregion

#region move
func _get_move_direction(input: Vector2) -> Vector3:
	var direction := (_camera.global_basis.x * input.x) + (_camera.global_basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	return direction


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := get_gravity()
	if velocity.y < 0.0:
		gravity *= fall_gravity_multiplier
	velocity += gravity * delta


func _start_slide(direction: Vector3) -> void:
	_sliding = true
	_slide_time = 0.0
	_slide_dir = direction.normalized()
	_was_crouching = true
	_mannequin.slide_start()


func _stop_slide(play_exit: bool = true) -> void:
	if not _sliding:
		return
	_sliding = false
	_slide_jump_queued = false
	if play_exit:
		_mannequin.slide_exit()
	_was_crouching = Input.is_action_pressed("crouch")
#endregion

#region facing
func _face_camera(delta: float) -> void:
	var look := -_camera.global_basis.z
	look.y = 0.0
	if look.length_squared() < 0.0001:
		return
	look = look.normalized()
	var target_yaw := atan2(look.x, look.z)
	_mannequin.rotation.y = lerp_angle(
		_mannequin.rotation.y,
		target_yaw,
		clampf(model_turn_speed * delta, 0.0, 1.0)
	)


func _face_vector(delta: float, look: Vector3) -> void:
	look.y = 0.0
	if look.length_squared() < 0.0001:
		return
	look = look.normalized()
	var target_yaw := atan2(look.x, look.z)
	_mannequin.rotation.y = lerp_angle(
		_mannequin.rotation.y,
		target_yaw,
		clampf(model_sprint_turn_speed * delta, 0.0, 1.0)
	)
#endregion

#region anims
func _stick_octant(input: Vector2, current: int) -> int:
	var stick := Vector2(input.x, -input.y)
	if stick.length_squared() < 0.0001:
		return current
	var ang := atan2(stick.x, stick.y)
	var raw := wrapi(int(round(ang / TAU * 8.0)), 0, 8)
	if raw == current:
		return current
	var center := float(current) / 8.0 * TAU
	if absf(angle_difference(ang, center)) < deg_to_rad(28.0):
		return current
	return raw


func _play_walk(input: Vector2) -> void:
	_walk_octant = _stick_octant(input, _walk_octant)
	match _walk_octant:
		0:
			_mannequin.walk_fwd()
		1:
			_mannequin.walk_fwd_r()
		2:
			_mannequin.walk_r()
		3:
			_mannequin.walk_bwd_r()
		4:
			_mannequin.walk_bwd()
		5:
			_mannequin.walk_bwd_l()
		6:
			_mannequin.walk_l()
		7:
			_mannequin.walk_fwd_l()


func _play_crouch(input: Vector2) -> void:
	_crouch_octant = _stick_octant(input, _crouch_octant)
	match _crouch_octant:
		0:
			_mannequin.crouch_fwd()
		1:
			_mannequin.crouch_fwd_r()
		2:
			_mannequin.crouch_right()
		3:
			_mannequin.crouch_bwd_r()
		4:
			_mannequin.crouch_bwd()
		5:
			_mannequin.crouch_bwd_l()
		6:
			_mannequin.crouch_left()
		7:
			_mannequin.crouch_fwd_l()
#endregion
