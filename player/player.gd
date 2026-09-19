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

#region camera
@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

var _camera_input_direction := Vector2.ZERO
#endregion

#region movement
@export_group("Movement")
@export var walk_speed := 6.0
@export var sprint_speed := 10.0
@export var jump_velocity := 4.5
#endregion

enum State {
	IDLE,
	WALK,
	JUMP_START,
	JUMP,
	FALL,
}
var _state: State = State.IDLE
var _is_sprinting: bool = false

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
	_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -PI / 3.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO

	_apply_gravity(delta)
	var direction := _get_move_direction()
	_face_move_direction(direction, delta)

	_is_sprinting = Input.is_action_pressed("sprint")

	match _state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
		State.WALK:
			_move(direction, sprint_speed if _is_sprinting else walk_speed)
		State.JUMP, State.FALL:
			_move(direction, sprint_speed if _is_sprinting else walk_speed)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	if not is_on_floor():
		_state = State.JUMP if velocity.y > 0.0 else State.FALL
	elif direction == Vector3.ZERO:
		_state = State.IDLE
	else:
		_state = State.WALK

func _move(direction: Vector3, move_speed: float) -> void:
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func _get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (_camera.global_basis.x * input.x) + (_camera.global_basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3.ZERO

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _face_move_direction(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var target_yaw := atan2(direction.x, direction.z)
	_mannequin.rotation.y = lerp_angle(_mannequin.rotation.y, target_yaw, 12.0 * delta)
