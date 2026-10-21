extends Node3D

const Chain := preload("room_chain.gd")
const PlayerScene := preload("player.tscn")
const Room := preload("room.gd")

const ROOM_COUNT := 25
const SPAWN_DEPTH := 1.5 ## Metres inside room 0, so the capsule starts clear of the wall.

@export var chain_seed := 42

var chain: Chain
var rooms: Array[Room] = []
var player: CharacterBody3D

func _ready() -> void:
	chain = Chain.new(chain_seed)
	for i in ROOM_COUNT:
		var plan := chain.next_plan()
		var room := Chain.SCENES[plan.type].instantiate() as Room
		room.transform = plan.transform
		add_child(room)
		rooms.append(room)
	rooms[0].seal_entrance()

	player = PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	# Just inside room 0, facing into the room: the Entrance marker already points that way.
	player.global_transform = rooms[0].entrance.global_transform.translated_local(Vector3(0.0, 0.0, -SPAWN_DEPTH))
