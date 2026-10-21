extends Node3D

const Room := preload("room.gd")

const ROOM_SCENES: Array[PackedScene] = [
	preload("room_straight.tscn"),
	preload("room_long.tscn"),
	preload("room_turn_left.tscn"),
	preload("room_turn_right.tscn"),
	preload("room_wide.tscn"),
]
const ROOM_COUNT := 25

@export var chain_seed := 42

@onready var camera: Camera3D = $OverviewCamera

func _ready() -> void:
	# One generator, seeded once: the same seed always picks the same rooms.
	var rng := RandomNumberGenerator.new()
	rng.seed = chain_seed

	var previous: Room = null
	var area := AABB()
	for i in ROOM_COUNT:
		var scene := ROOM_SCENES[rng.randi_range(0, ROOM_SCENES.size() - 1)]
		var room := scene.instantiate() as Room
		add_child(room)
		if previous != null:
			room.global_transform = previous.exit.global_transform * room.entrance.transform.affine_inverse()
		previous = room
		area = area.merge(AABB(room.position - Vector3(10.0, 0.0, 10.0), Vector3(20.0, 3.0, 20.0)))
	frame_overview(area)

## Hangs the camera above the middle of the chain, high enough to see all of it.
func frame_overview(area: AABB) -> void:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half := Vector2(area.size.x / aspect, area.size.z) / 2.0
	var height := maxf(half.x, half.y) / tan(deg_to_rad(camera.fov) / 2.0) * 1.2
	var center := area.get_center()
	camera.look_at_from_position(center + Vector3(0.0, height, height * 0.3), center)
