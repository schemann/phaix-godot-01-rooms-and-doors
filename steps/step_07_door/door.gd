extends Node3D
## A hinged door. It swings away from the player who walks up to it.

signal opened ## Emitted as the door starts to swing open.

const OPEN_ANGLE := -PI / 2.0 ## Away from the player, into the next room.
const SWING_TIME := 0.5 ## Seconds.

var is_open := false

var _tween: Tween

@onready var hinge: AnimatableBody3D = $Hinge
@onready var trigger: Area3D = $Trigger

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)

func open() -> void:
	if is_open:
		return
	is_open = true
	_swing_to(OPEN_ANGLE)
	opened.emit()

func close() -> void:
	is_open = false
	_swing_to(0.0)

func _swing_to(angle: float) -> void:
	if _tween != null:
		_tween.kill()
	# Physics process mode: the door's collider moves in step with the physics.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(hinge, "rotation:y", angle, SWING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_trigger_body_entered(_body: Node3D) -> void:
	open()
