extends Node3D

const Room := preload("room.gd")
const RoomScene := preload("room_straight.tscn")

const ROOM_COUNT := 8

func _ready() -> void:
	var previous: Room = null
	for i in ROOM_COUNT:
		var room := RoomScene.instantiate() as Room
		add_child(room)
		if previous != null:
			# The whole trick: this room's Entrance lands exactly on the previous room's Exit.
			room.global_transform = previous.exit.global_transform * room.entrance.transform.affine_inverse()
		previous = room
