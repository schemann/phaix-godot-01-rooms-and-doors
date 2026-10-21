extends Node3D
## A hinged door. It swings away from the player who walks up to it.

signal opened ## Emitted as the door starts to swing open.

const OPEN_ANGLE := -PI / 2.0 ## Away from the player, into the next room.
const SWING_TIME := 0.5 ## Seconds.

var is_open := false

var _tween: Tween
var _close_pending := false

@onready var hinge: AnimatableBody3D = $Hinge
@onready var trigger: Area3D = $Trigger
@onready var swing: Area3D = $Swing ## Where the door sweeps through when it moves.

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)
	# The trigger sleeps (monitoring is off in the scene) for one physics step: a player the level
	# has just teleported is still counted at the old place until then.
	get_tree().physics_frame.connect(_wake_trigger, CONNECT_ONE_SHOT)

func _physics_process(_delta: float) -> void:
	# Never close on somebody: wait until nobody stands in the swing.
	if _close_pending and not swing.has_overlapping_bodies():
		_close_pending = false
		is_open = false
		_swing_to(0.0)

func open() -> void:
	_close_pending = false
	if is_open:
		return
	is_open = true
	_swing_to(OPEN_ANGLE)
	opened.emit()

## Closes as soon as the swing is free.
func close() -> void:
	_close_pending = true

func _swing_to(angle: float) -> void:
	if _tween != null:
		_tween.kill()
	# Physics process mode: the door's collider moves in step with the physics.
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(hinge, "rotation:y", angle, SWING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _wake_trigger() -> void:
	trigger.monitoring = true

func _on_trigger_body_entered(_body: Node3D) -> void:
	open()
