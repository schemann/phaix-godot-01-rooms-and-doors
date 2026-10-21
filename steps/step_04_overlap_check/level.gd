extends Node3D

const Chain := preload("room_chain.gd")
const Room := preload("room.gd")

const ROOM_COUNT := 25

@export var chain_seed := 42

var chain: Chain

@onready var camera: Camera3D = $OverviewCamera

func _ready() -> void:
	chain = Chain.new(chain_seed)
	var area := AABB()
	for i in ROOM_COUNT:
		var plan := chain.next_plan()
		var room := Chain.SCENES[plan.type].instantiate() as Room
		room.transform = plan.transform
		add_child(room)
		area = area.merge(plan.bounds)
	frame_overview(area)

## Hangs the camera above the middle of the chain, high enough to see all of it.
func frame_overview(area: AABB) -> void:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half := Vector2(area.size.x / aspect, area.size.z) / 2.0
	var height := maxf(half.x, half.y) / tan(deg_to_rad(camera.fov) / 2.0) * 1.2
	var center := area.get_center()
	camera.look_at_from_position(center + Vector3(0.0, height, height * 0.3), center)
