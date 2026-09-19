@tool
class_name Player
extends CharacterBody3D

@export var gender: Mesh = preload("res://player/mannequin/m_mannequin.mesh"):
	set(new_gender):
		gender = new_gender
		if is_node_ready():
			_mannequin.gender = gender

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25

var _camera_input_direction := Vector2.ZERO

@onready var _mannequin: Mannequin = $Mannequin
@onready var _camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	_mannequin.gender = gender


func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -PI / 6.0, PI / 3.0)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO
