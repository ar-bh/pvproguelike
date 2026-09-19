@tool
class_name Player
extends CharacterBody3D

#region gender
@export var gender: Mesh = preload("res://player/mannequin/m_mannequin.mesh"):
	set(new_gender):
		gender = new_gender
		if is_node_ready():
			_apply_gender()
#endregion

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

@export_group("Movement")
@export var move_speed := 6.0
@export var jump_velocity := 4.5

var _camera_input_direction := Vector2.ZERO

@onready var _mannequin: Mannequin = $Mannequin
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = %Camera3D


func _ready() -> void:
	_apply_gender()
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_gender() -> void:
	if _mannequin:
		_mannequin.gender = gender


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
	_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (_camera.global_basis.x * input.x) + (_camera.global_basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if direction != Vector3.ZERO:
		var target_yaw := atan2(direction.x, direction.z)
		_mannequin.rotation.y = lerp_angle(_mannequin.rotation.y, target_yaw, 12.0 * delta)

	move_and_slide()
