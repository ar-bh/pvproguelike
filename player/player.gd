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
@export var move_speed := 10.0
@export var sprint_speed := 8.0
@export var crouch_speed := 3.0
@export var jump_velocity := 4.5
@export var fall_gravity_multiplier := 2.5
@export var slide_speed := 12.0
@export var slide_duration := 0.85
@export var slide_jump_lock := 0.25
@export var slide_speed_curve: Curve
#endregion

#region node variables
@onready var _mannequin: Mannequin = $Mannequin
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = %Camera3D
#endregion

func _ready() -> void:
	_apply_gender()
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

var _was_crouching := false

var _sliding := false
var _slide_time := 0.0
var _slide_dir := Vector3.ZERO
var _slide_jump_queued := false
var _bhop_time := 0.0

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
	
	if rotation_lock:
		_face_camera(delta)
	else:
		_face_vector(delta, direction)

	var crouching := Input.is_action_pressed("crouch")
	var sprinting := (
		Input.is_action_pressed("sprint")
		and not crouching
		and input != Vector2.ZERO
	)

	if (
		not _sliding
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

	if _sliding:
		rotation_lock = false
		_face_vector(delta, _slide_dir)
	elif rotation_lock:
		_face_camera(delta)
	else:
		_face_vector(delta, direction)

	rotation_lock = not sprinting and not _sliding

	var jumping := is_on_floor() and (
		Input.is_action_just_pressed("jump")
		or (_slide_jump_queued and _sliding and _slide_time >= slide_jump_lock)
	)

	var speed := move_speed
	if _sliding:
		var t := clampf(_slide_time / slide_duration, 0.0, 1.0)
		var falloff := 1.0
		if slide_speed_curve:
			falloff = slide_speed_curve.sample(t)
		speed = slide_speed * falloff
		velocity.x = _slide_dir.x * speed
		velocity.z = _slide_dir.z * speed
	else:
		if crouching:
			speed = crouch_speed
		elif sprinting:
			speed = sprint_speed
		if is_on_floor() and not jumping and _bhop_time <= 0.0:
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

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if _sliding and _slide_time < slide_jump_lock:
			_slide_jump_queued = true
		else:
			velocity.y = jump_velocity
			_mannequin.jump_start()
			_stop_slide(false)
			if _sliding:
				_stop_slide(false)
	elif _slide_jump_queued and _sliding and is_on_floor() and _slide_time >= slide_jump_lock:
		velocity.y = jump_velocity
		_mannequin.jump_start()
		_stop_slide(false)

	var was_on_floor := is_on_floor()
	move_and_slide()

	var on_floor := is_on_floor()
	var just_landed := not was_on_floor and on_floor
	if just_landed:
		_bhop_time = 0.08
	elif on_floor:
		_bhop_time = maxf(_bhop_time - delta, 0.0)
	else:
		_bhop_time = 0.0

	if _sliding:
		if _slide_time >= slide_jump_lock and not _mannequin.is_transition():
			_mannequin.slide()
	elif just_landed:
		_mannequin.jump_land()
	elif not on_floor or velocity.y > 0.0:
		if not _mannequin.is_transition():
			_mannequin.jump()
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
		

func _get_move_direction(input: Vector2) -> Vector3:
	var direction := (_camera.global_basis.x * input.x) + (_camera.global_basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	return direction

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

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := get_gravity()
	if velocity.y < 0.0:
		gravity *= fall_gravity_multiplier
	velocity += gravity * delta

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

func _play_walk(input: Vector2) -> void:
	var stick := Vector2(input.x, -input.y)  # W = up
	var octant := wrapi(int(round(atan2(stick.x, stick.y) / TAU * 8.0)), 0, 8)
	match octant:
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
	var stick := Vector2(input.x, -input.y)
	var octant := wrapi(int(round(atan2(stick.x, stick.y) / TAU * 8.0)), 0, 8)
	match octant:
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
