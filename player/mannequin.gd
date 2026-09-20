@tool
class_name Mannequin
extends Node3D

@onready var _mannequin_mesh: MeshInstance3D = %MannequinMesh
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _player: Player
var _last_state: Player.State

var gender: Mesh = preload("res://player/mannequin/m_mannequin.mesh"):
	set = set_mannequin_gender


func set_mannequin_gender(new_gender: Mesh) -> void:
	gender = new_gender
	if is_node_ready() and _mannequin_mesh:
		_mannequin_mesh.mesh = gender


func _ready() -> void:
	if _mannequin_mesh and gender:
		_mannequin_mesh.mesh = gender
		
	_player = get_parent() as Player
	
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return
	_update_animation()

func _play(anim_name: StringName, blend_time: float) -> void:
	if _anim == null or _anim.current_animation == anim_name:
		return
	_anim.play(anim_name, blend_time)

func _update_animation() -> void:
	var state := _player.state

	if (
		(_last_state == Player.State.JUMP or _last_state == Player.State.FALL)
		and state != Player.State.JUMP
		and state != Player.State.FALL
	):
		_play(&"Jump_Land", 0.08)
		_last_state = state
		return

	match state:
		Player.State.IDLE:
			_play(&"Idle", 0.2)
		Player.State.WALK:
			_play(&"Sprint", 0.12)
		Player.State.JUMP:
			_play(&"Jump_Start" if _player.velocity.y > 0.0 else &"Jump_Loop", 0.05)
		Player.State.FALL:
			_play(&"Jump_Loop", 0.05)

	_last_state = state
