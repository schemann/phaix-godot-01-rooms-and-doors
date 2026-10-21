extends Node3D
## A room module: a CSG shell with two connection points.

@onready var entrance: Marker3D = $Entrance
@onready var exit: Marker3D = $Exit

## Room 0 has nothing behind it, so its entrance becomes a plain wall.
## A hidden cutter is ignored by the CSG shape, which closes the hole.
func seal_entrance() -> void:
	$Shell/WallEntrance/Opening.visible = false
