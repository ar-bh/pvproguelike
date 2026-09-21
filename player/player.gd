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

@onready var genders: Array[Mesh] = [
	preload("res://player/mannequin/m_mannequin.mesh"),
	preload("res://player/mannequin/f_mannequin.mesh"),
]
#endregion

#region camera
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var turn_speed := 15.0

var _camera_input_direction := Vector2.ZERO
#endregion

#region movement
@export_group("Movement")
@export var move_speed := 10.0
@export var jump_velocity := 4.5
@export var fall_gravity_multiplier := 2.5
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

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -PI / 3.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	_apply_gravity(delta)
	var direction := _get_move_direction()
	_face_camera(delta)

	# move in direction
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (_camera.global_basis.x * input.x) + (_camera.global_basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3.ZERO

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
		clampf(turn_speed * delta, 0.0, 1.0)
	)
