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
@export var max_step_up := 0.4
@export var slide_speed := 12.0
@export var slide_duration := 0.85
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

	var speed := move_speed
	if _sliding:
		var t := clampf(_slide_time / slide_duration, 0.0, 1.0)
		var falloff := 1.0
		if slide_speed_curve:
			falloff = slide_speed_curve.sample(t)
		speed = slide_speed * falloff
		velocity.x = _slide_dir.x * speed
		velocity.z = _slide_dir.z * speed
	elif is_on_floor():
		if crouching:
			speed = crouch_speed
		elif sprinting:
			speed = sprint_speed
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if _sliding and _slide_time < 0.075:
			pass
		else:
			velocity.y = jump_velocity
			if _sliding:
				_stop_slide(false)

	var wish_horiz := Vector3(velocity.x, 0.0, velocity.z)
	var was_on_floor := is_on_floor()
	var pos_before := global_position
	move_and_slide()
	if was_on_floor and velocity.y <= 0.0:
		_try_step_up(wish_horiz, pos_before, delta)

	if _sliding:
		if not _mannequin.is_transition():
			_mannequin.slide()
	elif not is_on_floor():
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

func _try_step_up(wish_horiz: Vector3, pos_before: Vector3, delta: float) -> void:
	if wish_horiz.length_squared() < 0.01:
		return
	var hit_lip := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_normal().y < 0.3:
			hit_lip = true
			break
	if not hit_lip:
		return

	var dir := Vector3(wish_horiz.x, 0.0, wish_horiz.z).normalized()
	var from := global_transform
	var up := Vector3(0.0, max_step_up, 0.0)
	if test_move(from, up):
		return

	# Only leftover motion for this frame so stairs aren't teleported.
	var intended := wish_horiz.length() * delta
	var used := Vector3(global_position.x - pos_before.x, 0.0, global_position.z - pos_before.z).length()
	var leftover := maxf(intended - used, 0.04)
	var forward := dir * leftover
	var raised := from.translated(up)
	var hit := KinematicCollision3D.new()
	if test_move(raised, forward, hit):
		forward = hit.get_travel()
		if forward.length() < 0.02:
			return

	var stepped := raised.translated(forward)
	var down := Vector3(0.0, -(max_step_up + 0.2), 0.0)
	var floor_hit := KinematicCollision3D.new()
	if not test_move(stepped, down, floor_hit):
		return
	if floor_hit.get_normal().y < 0.6:
		return
	var dest := stepped.translated(floor_hit.get_travel())
	if dest.origin.y <= from.origin.y + 0.02:
		return

	global_transform = dest
	velocity.x = wish_horiz.x
	velocity.z = wish_horiz.z
	velocity.y = 0.0

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
