extends SceneTree
## Headless tests for tutorial 01. From the repository root:
##   godot --headless --path godot/01-rooms-and-doors -s res://tests/run_tests.gd
## Prints PASS or FAIL per test and exits with 0 only if every test passed.

const Chain := preload("res://steps/step_09_debug_map/room_chain.gd")
const Autopilot := preload("res://tools/autopilot.gd")

const STEPS: Array[String] = [
	"step_01_one_room",
	"step_02_snap_rooms",
	"step_03_seeded_types",
	"step_04_overlap_check",
	"step_05_walking_player",
	"step_06_mouse_look",
	"step_07_door",
	"step_08_on_the_fly",
	"step_09_debug_map",
]
const CHAIN_STEPS: Array[String] = [
	"step_04_overlap_check", "step_05_walking_player", "step_06_mouse_look",
	"step_07_door", "step_08_on_the_fly", "step_09_debug_map",
]
const PLAYER_STEPS: Array[String] = [
	"step_05_walking_player", "step_06_mouse_look", "step_07_door", "step_08_on_the_fly", "step_09_debug_map",
]
const LOOK_STEPS: Array[String] = ["step_06_mouse_look", "step_07_door", "step_08_on_the_fly", "step_09_debug_map"]
const DOOR_STEPS: Array[String] = ["step_07_door", "step_08_on_the_fly", "step_09_debug_map"]
const FLY_STEPS: Array[String] = ["step_08_on_the_fly", "step_09_debug_map"]
const ROOM_TYPES: Array[String] = ["straight", "long", "turn_left", "turn_right", "wide"]

const RAY_HEIGHT := 1.2 ## Metres above the floor: through the middle of a doorway.
const CEILING_LAYER := 2 ## VisualInstance3D.layers of the ceilings and lamp blocks: layer 2 only.
const ALL_LAYERS := 1048575 ## Camera3D.cull_mask default: all 20 layers.
const CUTAWAY_MASK := ALL_LAYERS - CEILING_LAYER ## The overview cameras: every layer but 2.
const WALL_THICKNESS := 0.2 ## Studio graybox standard: interior wall 0.1-0.25 x 3.0 m.
const WALL_HEIGHT := 3.0
const SLAB_THICKNESS := 0.2 ## Floor and ceiling.
const DOORWAY_WIDTH := 1.6
const DOORWAY_HEIGHT := 2.4
const MATERIAL_DIR := "res://materials/"
const OVERVIEW_STEPS: Array[String] = ["step_01_one_room", "step_02_snap_rooms", "step_03_seeded_types", "step_04_overlap_check"]
const SEED_COUNT := 1000
const ROOMS_PER_SEED := 300
const STREAM_ROOMS := 10 ## How many rooms the streaming test walks through.
const SPEED_UP := 4 ## The walking tests run this many times faster than real time.

var _passed := 0
var _failed := 0
var _skipped := 0

func _initialize() -> void:
	await process_frame
	var started := Time.get_ticks_msec()

	await _run("code rules: no class_name, no global random, input only through named actions", test_code_rules)
	await _run("chain: same seed gives the same plans 0-99, another seed another ones", test_determinism)
	await _run("chain: seeds 1-%d x %d rooms, no overlap, no fallback, never backwards" % [SEED_COUNT, ROOMS_PER_SEED], test_no_overlap)
	await _run("materials: shared graybox materials, 1 m grid, orange door, emissive fixture, no private materials", test_materials)
	for room_type in ROOM_TYPES:
		await _run("room_%s: entrance, exit, doorway size, bounds" % room_type, test_room_module.bind(room_type))
	for step in STEPS:
		await _run("%s: every room is closed (0.2 m floor, walls and ceiling), lamp and fixture, shared materials" % step, test_graybox_rooms.bind(step))
		await _run("%s: ambient fill reads inside closed rooms, the sun casts shadows" % step, test_lighting.bind(step))
	for step: String in ["step_02_snap_rooms", "step_03_seeded_types"] + CHAIN_STEPS:
		await _run("%s: every Entrance is on the previous Exit" % step, test_snapping.bind(step))
	await _run("step_03_seeded_types: the default seed runs into itself", test_overlap_bug.bind("step_03_seeded_types", true))
	await _run("step_04_overlap_check: the same seed gives a clean chain", test_overlap_bug.bind("step_04_overlap_check", false))
	for step in OVERVIEW_STEPS:
		await _run("%s: the overview camera frames every room and cuts the ceilings away" % step, test_overview_camera.bind(step))
	for step in PLAYER_STEPS:
		await _run("%s: walks on the floor, relative to its facing" % step, test_walk.bind(step))
		await _run("%s: jumps about 1 m, stays below the ceiling and lands" % step, test_jump.bind(step))
		await _run("%s: the player's camera sees the ceiling" % step, test_player_camera.bind(step))
		await _run("%s: the sealed entrance of room 0 holds" % step, test_sealed_entrance.bind(step))
	for step in LOOK_STEPS:
		await _run("%s: right stick turns the body and tilts the head, clamped at 89 deg" % step, test_stick_look.bind(step))
		await _run("%s: mouse look maths (0.002 rad per pixel, clamped)" % step, test_mouse_math.bind(step))
	if DisplayServer.get_name() == "headless":
		_skip("mouse capture: Esc releases, a click recaptures", "the headless display server never reports a captured mouse; tools/capture.gd checks it in a window")
	for step in DOOR_STEPS:
		await _run("%s: a door in the accent material opens on approach, lets a ray pass when open and blocks when closed" % step, test_door.bind(step))
	for step in FLY_STEPS:
		await _run("%s: a door never closes on the player" % step, test_door_waits_for_the_swing.bind(step))
	for step in DOOR_STEPS:
		await _run("%s: a player sliding past the free end of an open door leaf keeps moving" % step, test_open_leaf_end.bind(step))
	for step in FLY_STEPS:
		await _run("%s: rooms stream in and out through %d rooms" % [step, STREAM_ROOMS], test_streaming.bind(step))
	await _run("step_09_debug_map: the plans do not depend on when the player walks", test_timing_independence)
	await _run("step_09_debug_map: the map starts visible, Tab toggles it", test_toggle_map)
	await _run("step_09_debug_map: the map reads data only", test_map_reads_data_only)
	await _run("step_09_debug_map: R restarts with seed + 1", test_regenerate)
	for step in STEPS:
		await _run("%s: main scene runs 30 frames" % step, test_scene_runs.bind(step))

	print("\n%d passed, %d failed, %d skipped in %.1f s" % [_passed, _failed, _skipped, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if _failed > 0 else 0)

## Runs one test unless a `-- --only=text` argument asks for other tests only.
func _run(test_name: String, test: Callable) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only=") and not test_name.contains(argument.trim_prefix("--only=")):
			return
	var failures: Array[String] = await test.call()
	_report(test_name, failures)

#region Source rules

func test_code_rules() -> Array[String]:
	var failures: Array[String] = []
	var global_random := RegEx.create_from_string("(^|[^.\\w])(randi|randf|randi_range|randf_range|randomize|pick_random)\\(")
	var scripts := _scripts_in("res://steps")
	_expect(failures, scripts.size() >= 30, "found only %d scripts under steps" % scripts.size())
	for path in scripts:
		var source := FileAccess.get_file_as_string(path)
		var lines := source.split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("##") or line.begins_with("#"):
				continue
			var where := "%s:%d" % [path.trim_prefix("res://"), i + 1]
			_expect(failures, not line.begins_with("class_name"), "%s: class_name" % where)
			_expect(failures, global_random.search(line) == null, "%s: global random call" % where)
			_expect(failures, not line.contains(".shuffle("), "%s: Array.shuffle() uses the global generator" % where)
			_expect(failures, not line.contains("Input.is_key_pressed") and not line.contains("Input.is_physical_key_pressed"), "%s: reads a key directly" % where)
			_expect(failures, not line.contains("Input.is_mouse_button_pressed") and not line.contains("get_joy_axis") and not line.contains("is_joy_button_pressed"), "%s: reads a device directly" % where)
			_expect(failures, not line.contains("event is InputEventKey") and not line.contains("event is InputEventJoypad"), "%s: reads a key or button event directly" % where)
	return failures

func _scripts_in(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	for sub in dir.get_directories():
		found.append_array(_scripts_in(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	return found

#endregion

#region Chain (pure data, no scene)

func test_determinism() -> Array[String]:
	var failures: Array[String] = []
	var first := _plans(42, 100)
	var second := _plans(42, 100)
	var other := _plans(43, 100)
	_expect(failures, first.size() == 100, "made %d plans, expected 100" % first.size())
	_expect(failures, _same_plans(first, second), "seed 42 twice: the plans differ")
	_expect(failures, not _same_plans(first, other), "seed 43 gives the same plans as seed 42")
	for i in first.size():
		_expect(failures, first[i].index == i, "plan %d has index %d" % [i, first[i].index])
	return failures

func test_no_overlap() -> Array[String]:
	var failures: Array[String] = []
	var types_seen := {}
	for chain_seed in range(1, SEED_COUNT + 1):
		var plans := _plans(chain_seed, ROOMS_PER_SEED)
		for plan in plans:
			types_seen[plan.type] = true
		failures.append_array(_chain_problems(plans, "seed %d" % chain_seed))
		if failures.size() > 8:
			break
	_expect(failures, types_seen.size() == Chain.SCENES.size(), "only %d of %d room types were ever chosen" % [types_seen.size(), Chain.SCENES.size()])
	return failures

## Overlaps with any earlier plan, headings that turn back, and snaps that do not meet.
func _chain_problems(plans: Array[Chain.Plan], label: String) -> Array[String]:
	var problems: Array[String] = []
	# Sweep over x: a room can only overlap rooms whose x range reaches it.
	var by_x := plans.duplicate()
	by_x.sort_custom(func(a: Chain.Plan, b: Chain.Plan) -> bool: return a.bounds.position.x < b.bounds.position.x)
	for i in by_x.size():
		var a: Chain.Plan = by_x[i]
		var inner := a.bounds.grow(-Chain.SHRINK)
		for j in range(i + 1, by_x.size()):
			var b: Chain.Plan = by_x[j]
			if b.bounds.position.x > a.bounds.end.x:
				break
			if inner.intersects(b.bounds) or b.bounds.grow(-Chain.SHRINK).intersects(a.bounds):
				problems.append("%s: rooms %d and %d overlap" % [label, a.index, b.index])
	var start := plans[0].transform.origin
	for k in range(1, plans.size() - 1):
		# The next room's entrance has no rotation, so its basis is the heading of this exit.
		var heading := -plans[k + 1].transform.basis.z
		var to_start := (start - plans[k].transform.origin).normalized()
		if heading.dot(Chain.START_HEADING) < -Chain.BACK_LIMIT or heading.dot(to_start) > Chain.BACK_LIMIT + 0.001:
			problems.append("%s: room %d heads back (heading %s)" % [label, k, heading.snapped(Vector3.ONE * 0.01)])
	return problems

func _plans(chain_seed: int, count: int) -> Array[Chain.Plan]:
	var chain := Chain.new(chain_seed)
	for i in count:
		chain.next_plan()
	return chain.plans

func _same_plans(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].index != b[i].index or a[i].type != b[i].type or a[i].transform != b[i].transform or a[i].bounds != b[i].bounds:
			return false
	return true

#endregion

#region Rooms and snapping (scene + physics)

func test_room_module(room_type: String) -> Array[String]:
	var failures: Array[String] = []
	var room: Node3D = (load("res://steps/step_04_overlap_check/room_%s.tscn" % room_type) as PackedScene).instantiate()
	root.add_child(room)
	await _wait_physics(5)
	var entrance: Marker3D = room.get_node("Entrance")
	var exit_point: Marker3D = room.get_node("Exit")
	var inside_shape: CollisionShape3D = room.get_node("Inside/CollisionShape3D")
	var bounds: AABB = inside_shape.transform * AABB(-(inside_shape.shape as BoxShape3D).size / 2.0, (inside_shape.shape as BoxShape3D).size)
	var centre := bounds.get_center()
	centre.y = 0.0

	_expect(failures, is_zero_approx(entrance.position.y) and is_zero_approx(exit_point.position.y), "markers are not at floor level")
	_expect(failures, (centre - entrance.position).dot(-entrance.global_basis.z) > 1.0, "Entrance -Z does not point into the room")
	_expect(failures, (exit_point.position - centre).dot(-exit_point.global_basis.z) > 1.0, "Exit -Z does not point out of the room")
	_expect(failures, entrance.transform.basis.is_equal_approx(Basis.IDENTITY), "Entrance is rotated")
	# The Inside box covers the footprint including the walls (the CSG shell).
	var floor_box: CSGBox3D = room.get_node("Shell/Floor")
	var floor_aabb := floor_box.transform * AABB(-floor_box.size / 2.0, floor_box.size)
	_expect(failures, bounds.size.x == floor_aabb.size.x and bounds.size.z == floor_aabb.size.z, "Inside box %s does not match the floor %s" % [bounds.size, floor_aabb.size])
	_expect(failures, is_equal_approx(bounds.size.y, WALL_HEIGHT), "Inside box is %.2f m high, walls are 3 m" % bounds.size.y)
	for wall_name: String in ["WallEntrance", "WallFar", "WallLeft", "WallRight"]:
		var wall: CSGBox3D = room.get_node("Shell/" + wall_name)
		_expect(failures, is_equal_approx(wall.size.y, WALL_HEIGHT), "%s is %.2f m high" % [wall_name, wall.size.y])
		_expect(failures, is_equal_approx(minf(wall.size.x, wall.size.z), WALL_THICKNESS), "%s is %.2f m thick" % [wall_name, minf(wall.size.x, wall.size.z)])

	# Doorway: 1.6 m wide, 2.4 m high, in the wall at each marker.
	for point: Marker3D in [entrance, exit_point]:
		var label := point.name
		for sideways: float in [0.0, 0.7, -0.7]:
			_expect(failures, not _ray_hits(room, point, Vector3(sideways, RAY_HEIGHT, 1.0), Vector3(sideways, RAY_HEIGHT, -1.0)), "%s: a ray %.1f m off the middle hits the wall" % [label, sideways])
		for sideways: float in [0.9, -0.9]:
			_expect(failures, _ray_hits(room, point, Vector3(sideways, RAY_HEIGHT, 1.0), Vector3(sideways, RAY_HEIGHT, -1.0)), "%s: a ray %.1f m off the middle passes the wall" % [label, sideways])
		_expect(failures, not _ray_hits(room, point, Vector3(0.0, 2.3, 1.0), Vector3(0.0, 2.3, -1.0)), "%s: the doorway is lower than 2.3 m" % label)
		_expect(failures, _ray_hits(room, point, Vector3(0.0, 2.5, 1.0), Vector3(0.0, 2.5, -1.0)), "%s: the doorway is higher than 2.5 m" % label)
	root.remove_child(room)
	room.free()
	return failures

## Casts a ray in a marker's own space (x sideways, y up, -z the way through the wall).
func _ray_hits(room: Node3D, point: Marker3D, from_local: Vector3, to_local: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point.global_transform * from_local, point.global_transform * to_local)
	return not room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func test_snapping(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var rooms := _rooms_of(main.get_node("Level"))
	_expect(failures, rooms.size() >= (8 if step == "step_02_snap_rooms" else 1), "%d rooms" % rooms.size())
	for i in range(rooms.size() - 1):
		var exit_point: Transform3D = (rooms[i].get("exit") as Marker3D).global_transform
		var entrance: Transform3D = (rooms[i + 1].get("entrance") as Marker3D).global_transform
		_expect(failures, exit_point.origin.distance_to(entrance.origin) < 1e-4, "room %d Entrance is %.5f m from room %d Exit" % [i + 1, exit_point.origin.distance_to(entrance.origin), i])
		_expect(failures, exit_point.basis.is_equal_approx(entrance.basis), "room %d Entrance faces another way than room %d Exit" % [i + 1, i])
	await _unload(main)
	return failures

## Floors of the rooms in a step, as world boxes.
func _floor_boxes(level: Node3D) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for room in _rooms_of(level):
		var floor_box: CSGBox3D = room.get_node("Shell/Floor")
		boxes.append(floor_box.global_transform * AABB(-floor_box.size / 2.0, floor_box.size))
	return boxes

func test_overlap_bug(step: String, expect_overlap: bool) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var boxes := _floor_boxes(main.get_node("Level"))
	var overlaps := 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].grow(-Chain.SHRINK).intersects(boxes[j]):
				overlaps += 1
	_expect(failures, boxes.size() == 25, "%d rooms, expected 25" % boxes.size())
	if expect_overlap:
		_expect(failures, overlaps >= 3, "only %d overlapping floor pairs, the bug should be visible" % overlaps)
	else:
		_expect(failures, overlaps == 0, "%d overlapping floor pairs" % overlaps)
	await _unload(main)
	return failures

func test_overview_camera(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var camera: Camera3D = main.find_child("OverviewCamera", true, false)
	_expect(failures, camera != null and camera.current, "no current OverviewCamera")
	# Cutaway: it renders every layer but 2, so ceilings and lamp blocks are not drawn.
	_expect(failures, camera.cull_mask == CUTAWAY_MASK, "cull_mask is %d, expected %d (all layers but 2)" % [camera.cull_mask, CUTAWAY_MASK])
	_expect(failures, (camera.cull_mask & CEILING_LAYER) == 0 and (camera.cull_mask & 1) == 1, "the overview camera must skip layer 2 and still draw layer 1")
	_expect(failures, not camera.is_position_in_frustum(Vector3(0.0, 0.0, 100000.0)), "the frustum test accepts a point 100 km away")
	var level: Node3D = main.get_node_or_null("Level")
	var boxes: Array[AABB] = [AABB(Vector3(-5, -0.2, -5), Vector3(10, 0.2, 10))] # step 1: the one room
	if level != null:
		boxes = _floor_boxes(level)
	for box in boxes:
		for corner in 8:
			var point := box.get_endpoint(corner)
			point.y = 0.0 if point.y < 0.0 else 3.0
			_expect(failures, camera.is_position_in_frustum(point), "%s is outside the camera view" % point)
	await _unload(main)
	return failures

## All rooms of a level in order: its children that have an Entrance and an Exit.
func _rooms_of(level: Node3D) -> Array[Node3D]:
	var rooms: Array[Node3D] = []
	for child in level.get_children():
		if child is Node3D and child.get("entrance") != null and not child.is_queued_for_deletion():
			rooms.append(child)
	return rooms

#endregion

#region Player

func test_walk(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var player: CharacterBody3D = main.get_node("Level").player
	var start := player.global_position
	_expect(failures, player.is_on_floor(), "player is not on the floor at the start")
	_expect(failures, start.distance_to(Vector3(0.0, 0.0, 3.5)) < 0.05, "player starts at %s, expected 1.5 m inside room 0 at (0, 0, 3.5)" % start)
	_expect(failures, (-player.global_basis.z).is_equal_approx(Vector3.FORWARD), "player does not face the way the chain starts")

	# 45 frames at 5 m/s: 3.75 m, still short of the first door's trigger.
	Input.action_press("move_forward")
	await _wait_physics(45)
	Input.action_release("move_forward")
	var moved := player.global_position - start
	_expect(failures, moved.dot(-player.global_basis.z) > 3.5, "moved only %.2f m forward" % moved.dot(-player.global_basis.z))
	_expect(failures, absf(moved.x) < 0.1, "drifted %.2f m sideways" % moved.x)
	_expect(failures, absf(player.global_position.y) < 0.05, "left the floor (y = %.3f)" % player.global_position.y)

	# Relative to the facing: turned right by a quarter, forward now goes along +x.
	player.rotation.y = -PI / 2.0
	var before := player.global_position
	Input.action_press("move_forward")
	await _wait_physics(30)
	Input.action_release("move_forward")
	var turned := player.global_position - before
	_expect(failures, turned.x > 2.0 and absf(turned.z) < 0.1, "facing right, forward moved %s" % turned)
	await _unload(main)
	return failures

func test_jump(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var player: CharacterBody3D = main.get_node("Level").player
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var ceiling_bottom := _ceiling_bottom(_rooms_of(main.get_node("Level"))[0])
	Input.action_press("jump")
	await _wait_physics(2)
	Input.action_release("jump")
	var highest := 0.0
	var highest_eye := 0.0
	for i in 30:
		await physics_frame
		highest = maxf(highest, player.global_position.y)
		highest_eye = maxf(highest_eye, camera.global_position.y)
	_expect(failures, highest > 0.8 and highest < 1.2, "highest point %.2f m, expected about 1.03" % highest)
	_expect(failures, highest + capsule.height < ceiling_bottom, "the head reaches %.2f m at the top of the jump, the ceiling is at %.2f m" % [highest + capsule.height, ceiling_bottom])
	_expect(failures, highest_eye < ceiling_bottom - 0.2, "the eye reaches %.2f m at the top of the jump, the ceiling is at %.2f m (0.2 m for the near plane)" % [highest_eye, ceiling_bottom])
	await _wait_physics(60)
	_expect(failures, player.is_on_floor(), "player did not land")
	_expect(failures, absf(player.global_position.y) < 0.05, "landed at y = %.3f" % player.global_position.y)
	await _unload(main)
	return failures

func test_sealed_entrance(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var player: CharacterBody3D = main.get_node("Level").player
	player.rotation.y = PI # look at the entrance wall
	Input.action_press("move_forward")
	await _wait_physics(90)
	Input.action_release("move_forward")
	# The wall's inner face is at z = 4.8 (0.2 m thick, flush with the footprint) and the capsule radius is 0.4 m.
	_expect(failures, player.global_position.z > 4.2 and player.global_position.z < 4.55, "stopped at z = %.2f, expected about 4.4" % player.global_position.z)
	_expect(failures, absf(player.global_position.y) < 0.05, "left the floor (y = %.3f)" % player.global_position.y)
	await _unload(main)
	return failures

func test_stick_look(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var player: CharacterBody3D = main.get_node("Level").player
	var head: Node3D = player.get_node("Head")

	# 3 rad/s for one second turns the body by about 3 rad (right is negative yaw).
	Input.action_press("look_right")
	await _wait_physics(60)
	Input.action_release("look_right")
	var turned := wrapf(-player.rotation.y, -PI, PI)
	_expect(failures, absf(turned - 3.0) < 0.15, "the stick turned the body by %.2f rad in 1 s" % turned)
	_expect(failures, is_zero_approx(head.rotation.x), "yaw moved the head pitch")

	Input.action_press("look_down")
	await _wait_physics(60)
	Input.action_release("look_down")
	_expect(failures, is_equal_approx(head.rotation.x, -deg_to_rad(89.0)), "looking down: pitch %.1f deg" % rad_to_deg(head.rotation.x))
	Input.action_press("look_up")
	await _wait_physics(120)
	Input.action_release("look_up")
	_expect(failures, is_equal_approx(head.rotation.x, deg_to_rad(89.0)), "looking up: pitch %.1f deg" % rad_to_deg(head.rotation.x))
	_expect(failures, is_zero_approx(player.rotation.x) and is_zero_approx(player.rotation.z), "pitch tilted the body")
	await _unload(main)
	return failures

func test_mouse_math(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var player: CharacterBody3D = main.get_node("Level").player
	var head: Node3D = player.get_node("Head")
	var sensitivity: float = player.get("mouse_sensitivity")
	_expect(failures, is_equal_approx(sensitivity, 0.002), "sensitivity is %f rad per pixel" % sensitivity)
	var yaw := player.rotation.y
	player.call("rotate_view", Vector2(100.0, 0.0) * sensitivity)
	_expect(failures, is_equal_approx(player.rotation.y - yaw, -0.2), "100 px right turned the body by %.3f rad, expected -0.2" % (player.rotation.y - yaw))
	_expect(failures, is_zero_approx(head.rotation.x), "yaw moved the head pitch")
	player.call("rotate_view", Vector2(0.0, 100000.0) * sensitivity)
	_expect(failures, is_equal_approx(head.rotation.x, -deg_to_rad(89.0)), "mouse down: pitch %.1f deg" % rad_to_deg(head.rotation.x))
	player.call("rotate_view", Vector2(0.0, -200000.0) * sensitivity)
	_expect(failures, is_equal_approx(head.rotation.x, deg_to_rad(89.0)), "mouse up: pitch %.1f deg" % rad_to_deg(head.rotation.x))
	_expect(failures, is_zero_approx(player.rotation.x), "pitch tilted the body")
	await _unload(main)
	return failures

#endregion

#region Doors

func test_door(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var level: Node3D = main.get_node("Level")
	var player: CharacterBody3D = level.player
	var room: Node3D = level.rooms[0]
	var door: Node3D = room.get("door")
	var door_point := (room.get("exit") as Marker3D).global_transform
	var opened_at: Array[float] = []
	door.connect("opened", func() -> void: opened_at.append(_depth(player, door_point)))

	var slab := door.get_node("Hinge/MeshInstance3D") as MeshInstance3D
	var slab_material := (slab.mesh as BoxMesh).material
	_expect(failures, slab_material != null and slab_material.resource_path == MATERIAL_DIR + "door.tres", "the door panel is not the accent material res://materials/door.tres")
	_expect(failures, not door.get("is_open"), "the door starts open")
	_expect(failures, _door_blocks(level, door_point), "the closed door lets a ray pass")
	await _wait_physics(10)
	_expect(failures, not door.get("is_open"), "the door opened by itself")

	# Walk up to it: it opens while the player is still a few metres away.
	Input.action_press("move_forward")
	for i in 150:
		await physics_frame
		if door.get("is_open"):
			break
	Input.action_release("move_forward")
	_expect(failures, door.get("is_open"), "the door did not open on approach")
	_expect(failures, opened_at.size() == 1, "`opened` was emitted %d times" % opened_at.size())
	if opened_at.size() == 1:
		_expect(failures, opened_at[0] < -2.5 and opened_at[0] > -4.2, "the door opened when the player was %.2f m away" % -opened_at[0])

	# Open: the hinge is turned 90 degrees and a ray passes through the doorway.
	await _wait_physics(40)
	var hinge: Node3D = door.get("hinge")
	_expect(failures, absf(hinge.rotation.y - (-PI / 2.0)) < 0.02, "the open door is at %.1f deg" % rad_to_deg(hinge.rotation.y))
	_expect(failures, not _door_blocks(level, door_point), "the open doorway blocks a ray")
	_expect(failures, not _door_blocks(level, door_point, 0.5), "the open doorway blocks a ray 0.5 m off the middle")

	# Closed again: it blocks the ray and the player.
	door.call("close")
	await _wait_physics(40)
	_expect(failures, not door.get("is_open"), "the door is still open after close()")
	_expect(failures, absf(hinge.rotation.y) < 0.02, "the closed door is at %.1f deg" % rad_to_deg(hinge.rotation.y))
	_expect(failures, _door_blocks(level, door_point), "the closed door lets a ray pass")
	Input.action_press("move_forward")
	await _wait_physics(90)
	Input.action_release("move_forward")
	var depth := _depth(player, door_point)
	_expect(failures, depth < -0.3 and depth > -0.65, "walking into the closed door stopped %.2f m before it" % -depth)
	await _unload(main)
	return failures

## True if a ray through the doorway at the exit is stopped by the door. sideways moves it off the middle.
func _door_blocks(level: Node3D, door_point: Transform3D, sideways := -0.3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(door_point * Vector3(sideways, RAY_HEIGHT, 1.0), door_point * Vector3(sideways, RAY_HEIGHT, -2.0))
	query.exclude = [(level.player as CollisionObject3D).get_rid()]
	return not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## How far the player is in front of the exit plane; negative before it.
func _depth(player: Node3D, door_point: Transform3D) -> float:
	return (player.global_position - door_point.origin).dot(-door_point.basis.z)

func test_door_waits_for_the_swing(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var level: Node3D = main.get_node("Level")
	var player: CharacterBody3D = level.player
	var room: Node3D = level.rooms[0]
	var door: Node3D = room.get("door")
	var door_point := (room.get("exit") as Marker3D).global_transform
	var hinge: Node3D = door.get("hinge")

	# Walk into the doorway, the door opening on the way.
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
		if _depth(player, door_point) > 0.5:
			break
	Input.action_release("move_forward")
	_expect(failures, _depth(player, door_point) > 0.5, "the player did not get through the doorway")
	await _wait_physics(20)

	# Asked to close while the player is in the swing: nothing happens.
	door.call("close")
	await _wait_physics(45)
	_expect(failures, door.get("is_open") and absf(hinge.rotation.y + PI / 2.0) < 0.02, "the door closed on the player (hinge at %.1f deg)" % rad_to_deg(hinge.rotation.y))

	# Out of the swing: it closes, and the player was not touched.
	Input.action_press("move_forward")
	await _wait_physics(60)
	Input.action_release("move_forward")
	var before := player.global_position
	await _wait_physics(60)
	_expect(failures, not door.get("is_open") and absf(hinge.rotation.y) < 0.02, "the door did not close after the player left (hinge at %.1f deg)" % rad_to_deg(hinge.rotation.y))
	_expect(failures, player.global_position.distance_to(before) < 0.01, "the closing door moved the player by %.3f m" % player.global_position.distance_to(before))
	await _unload(main)
	return failures

## The open leaf stands in the next room, 1.6 m long, right where the way leads on. A player pressed against its face who slides
## past its free end must keep moving. On GodotPhysics3D a capsule whose axis stood a tenth of a millimetre past the end of the
## leaf's box was held in place for good (the box has a blind spot at its end edge, the one contact that is still reported is
## the floor's, and every move has zero travel). The projects run Jolt, which has no such blind spot; this guards the setting.
func test_open_leaf_end(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step)
	var level: Node3D = main.get_node("Level")
	var player: CharacterBody3D = level.player
	var door: Node3D = level.rooms[0].get("door")
	door.call("open")
	await _wait_physics(45) # the swing takes half a second
	door.set_physics_process(false) # the leaf stays open, whatever the probes do
	var hinge: Node3D = door.get("hinge")
	_expect(failures, absf(hinge.rotation.y + PI / 2.0) < 0.02, "the leaf is not open (%.1f deg)" % rad_to_deg(hinge.rotation.y))
	var radius := ((player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).radius
	var face_x := 0.8 - 0.05 # the door's frame: the hinge sits at x = 0.8, the leaf is 0.1 thick and runs 1.6 m into the room (-z)
	var end_z := -1.6
	var yaw := atan2(-0.8, 0.6) # facing +x and on into the room, as the autopilot does when the exit is on the right
	var held: Array[String] = []
	var probes := 0
	for beyond_mm: float in [0.0, 0.05, 0.1]: # how far the capsule's axis stands past the end of the leaf
		for apart_mm: float in [0.0, 0.1, 0.2]: # how far its side is from the face
			var spot := Vector3(face_x - radius - apart_mm / 1000.0, 0.0, end_z - beyond_mm / 1000.0)
			player.global_transform = door.global_transform * Transform3D(Basis(Vector3.UP, yaw), spot)
			player.velocity = Vector3.ZERO
			await _wait_physics(2)
			var before := player.global_position
			Input.action_press("move_forward")
			await _wait_physics(10)
			Input.action_release("move_forward")
			probes += 1
			var moved := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
			if moved < 0.3:
				held.append("%.2f mm past the end, %.1f mm from the face: moved %.4f m" % [beyond_mm, apart_mm, moved])
	_expect(failures, held.is_empty(), "the player was held in place in %d of %d probes: %s" % [held.size(), probes, held.slice(0, 3)])
	await _unload(main)
	return failures

#endregion

#region Streaming with the real player

## Per-frame checks while the autopilot walks through the chain.
class Watcher extends RefCounted:
	var level: Node3D
	var pilot: RefCounted
	var failures: Array[String] = []
	var frame := 0
	var max_live := 0
	var max_step := 0.0
	var passed := {} ## Door index -> true once the player crossed its plane.
	var clear_since := {} ## Door index -> frame when the player was clear of the swing.
	var verified_closed := {} ## Door index -> true once checked closed and blocking.
	var checked_current := 0
	var current_since := 0 ## Frame when the player entered the room the player is in.
	var _last_position := Vector3.ZERO

	func _init(watched_level: Node3D, watched_pilot: RefCounted) -> void:
		level = watched_level
		pilot = watched_pilot
		_last_position = (watched_level.player as Node3D).global_position

	func fail(message: String) -> void:
		if failures.size() < 12:
			failures.append("frame %d: %s" % [frame, message])

	func check() -> void:
		frame += 1
		var player: CharacterBody3D = level.player
		var rooms: Dictionary = level.rooms
		var plans: Array = level.chain.plans ## Plans of the step under test, a class of its own.
		max_live = maxi(max_live, rooms.size())
		if rooms.size() > 3:
			fail("%d live rooms" % rooms.size())
		if plans.size() > int(level.current) + 2:
			fail("%d plans made while the player is in room %d" % [plans.size(), level.current])

		# Never pushed through a wall: always inside a live room, on the floor, no jumps in position.
		var inside := false
		for index: int in rooms.keys():
			if plans[index].bounds.grow(0.2).has_point(player.global_position):
				inside = true
		if not inside:
			fail("player at %s is outside every live room" % player.global_position)
		if player.global_position.y < -0.1 or player.global_position.y > 0.3:
			fail("player at height %.2f" % player.global_position.y)
		var step := player.global_position.distance_to(_last_position)
		max_step = maxf(max_step, step)
		if step > 0.2:
			fail("the player moved %.2f m in one physics frame, from %s to %s" % [step, _last_position, player.global_position])
		_last_position = player.global_position

		# The next room exists, and the door is open, before the player passes the door.
		var target: int = pilot.door_index
		if pilot.depth_at(target) >= 0.0 and not passed.has(target):
			passed[target] = true
			if not rooms.has(target + 1):
				fail("room %d did not exist when the player passed door %d" % [target + 1, target])
			elif not rooms[target].door.is_open:
				fail("door %d was closed when the player passed it" % target)

		# The door behind closes once the player is clear of the swing, and then it blocks.
		for index: int in rooms.keys():
			if index >= level.current or verified_closed.has(index):
				continue
			var depth: float = pilot.depth_at(index)
			if depth > 2.6 and not clear_since.has(index):
				clear_since[index] = frame
			if clear_since.has(index) and frame - int(clear_since[index]) > 45:
				verified_closed[index] = true
				var door: Node3D = rooms[index].door
				var door_point := (rooms[index].exit as Marker3D).global_transform
				if door.is_open or absf(door.hinge.rotation.y) > 0.02:
					fail("door %d is still open %d frames after the player cleared it" % [index, frame - int(clear_since[index])])
				var query := PhysicsRayQueryParameters3D.create(door_point * Vector3(-0.3, 1.2, -1.0), door_point * Vector3(-0.3, 1.2, 1.0))
				query.exclude = [player.get_rid()]
				if level.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					fail("door %d is closed but a ray passes it" % index)

		# Rooms behind the previous one are gone: from the dictionary, and, three frames on, from the tree.
		if level.current != checked_current:
			checked_current = level.current
			current_since = frame
		for index: int in rooms.keys():
			if index < level.current - 1:
				fail("room %d still exists while the player is in room %d" % [index, level.current])
		if frame - current_since == 3:
			var in_tree := 0
			for child in level.get_children():
				if child.get("entrance") != null:
					in_tree += 1
			if in_tree != rooms.size():
				fail("%d room nodes in the tree for %d live rooms" % [in_tree, rooms.size()])

func test_streaming(step: String) -> Array[String]:
	var main := await _load_step(step)
	var level: Node3D = main.get_node("Level")
	var pilot := Autopilot.new(level)
	var watcher := Watcher.new(level, pilot)
	_fast_forward(true)

	_expect(watcher.failures, level.rooms.size() == 1, "%d rooms before the player moved" % level.rooms.size())
	var arrived := await _walk(level, pilot, STREAM_ROOMS, 0, watcher.check)
	_expect(watcher.failures, arrived, "the player did not reach room %d (stuck in room %d after %d frames)" % [STREAM_ROOMS, level.current, watcher.frame])
	# Keep walking so the last door can close behind the player.
	var frames_left := [150]
	await _drive(func() -> bool:
		pilot.physics_step()
		watcher.check()
		frames_left[0] -= 1
		return frames_left[0] <= 0)
	pilot.release()
	_fast_forward(false)

	_expect(watcher.failures, watcher.max_live == 3, "at most %d rooms were live at once, expected 3" % watcher.max_live)
	_expect(watcher.failures, watcher.max_step < 0.2, "the player moved %.2f m in one physics frame" % watcher.max_step)
	_expect(watcher.failures, watcher.passed.size() >= STREAM_ROOMS - 1, "the player passed only %d doors" % watcher.passed.size())
	_expect(watcher.failures, watcher.verified_closed.size() >= STREAM_ROOMS - 2, "only %d doors were seen closing behind the player" % watcher.verified_closed.size())
	var live: Array[Node3D] = _rooms_of(level)
	_expect(watcher.failures, live.size() == level.rooms.size() and live.size() <= 3, "%d room nodes in the tree for %d live rooms" % [live.size(), level.rooms.size()])
	for i in range(live.size() - 1):
		var exit_point: Transform3D = (live[i].get("exit") as Marker3D).global_transform
		var entrance: Transform3D = (live[i + 1].get("entrance") as Marker3D).global_transform
		_expect(watcher.failures, exit_point.origin.distance_to(entrance.origin) < 1e-4 and exit_point.basis.is_equal_approx(entrance.basis), "live rooms %d and %d are not snapped" % [i, i + 1])
	# Walking back builds nothing: the door behind is shut and the plans stay as they are.
	var plan_count: int = level.chain.plans.size()
	var seed_plans := _plans(level.chain_seed, plan_count)
	_expect(watcher.failures, _same_plans(level.chain.plans, seed_plans), "the streamed plans differ from the pure-data chain")
	Input.action_press("move_back")
	await _wait_physics(120)
	Input.action_release("move_back")
	_expect(watcher.failures, level.chain.plans.size() == plan_count, "walking back made %d new plans" % (level.chain.plans.size() - plan_count))
	await _unload(main)
	return watcher.failures

## Calls its callback once per physics tick, before the player's own tick.
class Driver extends Node:
	signal finished
	var tick: Callable

	func _physics_process(_delta: float) -> void:
		if tick.is_valid() and tick.call():
			tick = Callable()
			finished.emit()

## Runs tick once per physics tick until it returns true. (With Engine.time_scale above 1
## several ticks happen per frame, and `await physics_frame` would only see one of them.)
func _drive(tick: Callable) -> void:
	var driver := Driver.new()
	driver.process_priority = -100
	driver.tick = tick
	root.add_child(driver)
	await driver.finished
	root.remove_child(driver)
	driver.queue_free()

## Walks until the player is in room `goal`. dawdle: ticks of standing still at the start and at every new door.
func _walk(level: Node3D, pilot: RefCounted, goal: int, dawdle: int, on_tick: Callable) -> bool:
	var state := {"budget": 1500 * goal, "wait": dawdle, "target": pilot.door_index}
	await _drive(func() -> bool:
		if state["wait"] > 0:
			state["wait"] -= 1
		else:
			pilot.physics_step()
			if pilot.door_index != state["target"]:
				state["target"] = pilot.door_index
				state["wait"] = dawdle
				pilot.release()
		if on_tick.is_valid():
			on_tick.call()
		state["budget"] -= 1
		return level.current >= goal or state["budget"] <= 0)
	pilot.release()
	return level.current >= goal

func test_timing_independence() -> Array[String]:
	var failures: Array[String] = []
	_fast_forward(true)
	for dawdle: int in [0, 30, 200]:
		var main := await _load_step("step_09_debug_map")
		var level: Node3D = main.get_node("Level")
		var pilot := Autopilot.new(level)
		var arrived := await _walk(level, pilot, 7, dawdle, Callable())
		_expect(failures, arrived, "dawdle %d: did not reach room 7" % dawdle)
		var made: Array = level.chain.plans
		_expect(failures, made.size() >= 8, "dawdle %d: only %d plans" % [dawdle, made.size()])
		_expect(failures, _same_plans(made, _plans(level.chain_seed, made.size())), "dawdle %d: the streamed plans differ from the pure-data chain" % dawdle)
		await _unload(main)
	_fast_forward(false)
	return failures

#endregion

#region Debug map and restart

func test_toggle_map() -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step("step_09_debug_map")
	var map: Control = main.get_node("HUD/DebugMap")
	_expect(failures, map.get_parent() is CanvasLayer, "the map is not under a CanvasLayer")
	_expect(failures, map.visible, "the map does not start visible")
	_expect(failures, map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the map takes mouse input")
	_expect(failures, map.position.is_equal_approx(Vector2(16.0, 16.0)) and map.size.is_equal_approx(Vector2(300.0, 300.0)), "the map is %s at %s, expected 300x300 at the top left" % [map.size, map.position])
	await _action("toggle_debug")
	_expect(failures, not map.visible, "Tab did not hide the map")
	await _action("toggle_debug")
	_expect(failures, map.visible, "Tab did not show the map again")
	await _unload(main)
	return failures

func test_map_reads_data_only() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://steps/step_09_debug_map/debug_map.gd")
	for forbidden: String in ["get_node", "get_tree", "find_child", "get_children", "$", "Physics"]:
		_expect(failures, not source.contains(forbidden), "debug_map.gd uses `%s`" % forbidden)
	_expect(failures, source.contains("level.chain.plans") and source.contains("level.rooms"), "debug_map.gd does not draw the plan history")
	return failures

func test_regenerate() -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step("step_09_debug_map")
	var level: Node3D = main.get_node("Level")
	var player: CharacterBody3D = level.player
	_expect(failures, level.chain_seed == 42, "the default seed is %d, expected 42" % level.chain_seed)
	_expect(failures, _same_plans(level.chain.plans, _plans(42, 1)), "room 0 differs from the pure-data chain")

	# Open the first door so there is something to throw away.
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
		if level.rooms.size() == 2:
			break
	Input.action_release("move_forward")
	_expect(failures, level.rooms.size() == 2, "the first door did not build room 1")
	await _wait_physics(30)

	await _action("regenerate")
	await _wait_physics(10)
	_expect(failures, level.chain_seed == 43, "seed is %d after R, expected 43" % level.chain_seed)
	_expect(failures, _same_plans(level.chain.plans, _plans(43, 1)), "the new chain is not seed 43")
	_expect(failures, level.rooms.size() == 1 and level.rooms.has(0) and level.current == 0, "%d live rooms, current %d after R" % [level.rooms.size(), level.current])
	_expect(failures, _rooms_of(level).size() == 1, "%d room nodes in the tree after R" % _rooms_of(level).size())
	_expect(failures, player.global_position.distance_to(Vector3(0.0, 0.0, 3.5)) < 0.05, "player is at %s after R, expected the start of room 0" % player.global_position)
	_expect(failures, player.is_on_floor(), "player is not on the floor after R")
	_expect(failures, not level.rooms[0].door.is_open, "door 0 is open after R")

	await _action("regenerate")
	await _wait_physics(10)
	_expect(failures, level.chain_seed == 44, "second R: seed is %d, expected 44" % level.chain_seed)
	_expect(failures, _rooms_of(level).size() == 1, "%d room nodes after the second R" % _rooms_of(level).size())
	await _unload(main)
	return failures

#endregion

#region Graybox standard: closed rooms, materials, lighting (gamekb: grayboxing-and-metrics)

func test_materials() -> Array[String]:
	var failures: Array[String] = []
	var grid := load(MATERIAL_DIR + "grid_1m.png") as Texture2D
	_expect(failures, grid != null and grid.get_size() == Vector2(256.0, 256.0), "grid_1m.png is not a 256x256 texture")
	if grid == null:
		return failures

	# One tile is 1 m: a dark line on the tile border, a fainter one at 0.5 m, the same on both axes.
	var image := grid.get_image()
	var fill := image.get_pixel(100, 100)
	var half_line := image.get_pixel(127, 100)
	var tile_line := image.get_pixel(0, 100)
	_expect(failures, tile_line.r < half_line.r and half_line.r < fill.r, "grid lines: tile %.2f, half %.2f, fill %.2f" % [tile_line.r, half_line.r, fill.r])
	_expect(failures, image.get_pixel(255, 100) == tile_line and image.get_pixel(100, 0) == tile_line and image.get_pixel(100, 255) == tile_line, "the tile border line is not centred on the border")
	_expect(failures, image.get_pixel(100, 127) == half_line and image.get_pixel(100, 128) == half_line and image.get_pixel(128, 100) == half_line, "the 0.5 m line is not the same on both axes")
	_expect(failures, image.has_mipmaps(), "the grid is imported without mipmaps: it would shimmer at a distance")

	# Neutral gray floor, walls and ceiling in the midtone range (50-100 percent), floor lighter than walls.
	var targets: Dictionary[String, float] = {"floor": 0.70, "wall": 0.55, "ceiling": 0.60}
	var fills: Dictionary[String, Color] = {}
	for material_name: String in targets:
		var material := load(MATERIAL_DIR + material_name + ".tres") as StandardMaterial3D
		_expect(failures, material != null, "%s.tres is not a StandardMaterial3D" % material_name)
		if material == null:
			continue
		var shown := (material.albedo_color.srgb_to_linear() * fill.srgb_to_linear()).linear_to_srgb()
		fills[material_name] = shown
		_expect(failures, material.albedo_texture != null and material.albedo_texture.resource_path == grid.resource_path, "%s.tres does not use the shared grid" % material_name)
		_expect(failures, material.uv1_triplanar and material.uv1_world_triplanar, "%s.tres is not world triplanar" % material_name)
		_expect(failures, material.uv1_scale.is_equal_approx(Vector3.ONE), "%s.tres: uv1_scale %s, one tile must be 1 m (scale 1)" % [material_name, material.uv1_scale])
		_expect(failures, material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "%s.tres is unlit" % material_name)
		_expect(failures, material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "%s.tres: texture_filter %d" % [material_name, material.texture_filter])
		_expect(failures, shown.r >= 0.5 and shown.r <= 1.0, "%s.tres: albedo %.2f is outside 50-100 percent" % [material_name, shown.r])
		_expect(failures, absf(shown.r - targets[material_name]) < 0.02, "%s.tres: albedo %.3f, expected about %.2f" % [material_name, shown.r, targets[material_name]])
		_expect(failures, absf(shown.r - shown.g) < 0.01 and absf(shown.r - shown.b) < 0.01, "%s.tres is not neutral gray" % material_name)
	if fills.size() == 3:
		_expect(failures, fills["floor"].r > fills["wall"].r + 0.1, "the floor must be clearly lighter than the walls (%.2f vs %.2f)" % [fills["floor"].r, fills["wall"].r])

	# The door is the warm accent, and the brightest large surface in a gray room (squint test).
	var door := load(MATERIAL_DIR + "door.tres") as StandardMaterial3D
	_expect(failures, door != null, "door.tres is not a StandardMaterial3D")
	if door != null and fills.has("wall"):
		_expect(failures, door.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "door.tres is unlit")
		_expect(failures, door.albedo_color.h > 0.04 and door.albedo_color.h < 0.13 and door.albedo_color.s > 0.7 and door.albedo_color.v > 0.9, "door.tres %s is not a saturated warm orange" % door.albedo_color)
		var door_light := door.albedo_color.srgb_to_linear().get_luminance()
		var wall_light := (load(MATERIAL_DIR + "wall.tres") as StandardMaterial3D).albedo_color.srgb_to_linear().get_luminance() * fill.srgb_to_linear().r
		_expect(failures, door_light > 1.5 * wall_light, "door luminance %.3f is only %.2fx the wall's %.3f" % [door_light, door_light / wall_light, wall_light])

	# The lamp block glows but is still a lit material.
	var fixture := load(MATERIAL_DIR + "fixture.tres") as StandardMaterial3D
	_expect(failures, fixture != null and fixture.emission_enabled and fixture.emission_energy_multiplier >= 1.0, "fixture.tres is not emissive")
	_expect(failures, fixture != null and fixture.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "fixture.tres is unlit")

	# No scene brings its own material: floors, walls, ceilings, lamps and doors all come from res://materials.
	var scenes := 0
	for step in STEPS:
		for file in DirAccess.get_files_at("res://steps/" + step):
			if file.ends_with(".tscn"):
				scenes += 1
				var text := FileAccess.get_file_as_string("res://steps/%s/%s" % [step, file])
				_expect(failures, not text.contains('[sub_resource type="StandardMaterial3D"') and not text.contains("albedo_color"), "%s/%s defines a material of its own" % [step, file])
	_expect(failures, scenes >= 50, "found only %d scenes" % scenes)
	return failures

func test_graybox_rooms(step: String) -> Array[String]:
	var failures: Array[String] = []
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://steps/" + step):
		if file.begins_with("room_") and file.ends_with(".tscn"):
			files.append(file)
	files.sort()
	var expected := 1 if step in ["step_01_one_room", "step_02_snap_rooms"] else ROOM_TYPES.size()
	_expect(failures, files.size() == expected, "%d room scenes, expected %d" % [files.size(), expected])

	# Far apart, so that a ray only ever sees the room it starts in.
	var holder := Node3D.new()
	root.add_child(holder)
	for i in files.size():
		var room := (load("res://steps/%s/%s" % [step, files[i]]) as PackedScene).instantiate() as Node3D
		room.position = Vector3(i * 40.0, 0.0, 0.0)
		holder.add_child(room)
	await _wait_physics(5) # the CSG shapes build their collision
	for room in holder.get_children():
		failures.append_array(_graybox_problems(room as Node3D))
	root.remove_child(holder)
	holder.free()
	return failures

## Everything the graybox standard asks of one room module, as problems (empty = fine).
func _graybox_problems(room: Node3D) -> Array[String]:
	var problems: Array[String] = []
	var label := room.scene_file_path.trim_prefix("res://steps/")
	var player := (load("res://steps/step_05_walking_player/player.tscn") as PackedScene).instantiate()
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	player.free()

	# Floor: 0.2 m thick, its top at y = 0.
	var floor_box := room.get_node("Shell/Floor") as CSGBox3D
	var footprint := Vector2(floor_box.size.x, floor_box.size.z)
	_expect(problems, is_equal_approx(floor_box.size.y, SLAB_THICKNESS) and is_zero_approx(floor_box.position.y + floor_box.size.y / 2.0), "%s: the floor is %.2f m thick with its top at y = %.2f" % [label, floor_box.size.y, floor_box.position.y + floor_box.size.y / 2.0])
	_expect(problems, floor_box.material != null and floor_box.material.resource_path == MATERIAL_DIR + "floor.tres", "%s: the floor does not use floor.tres" % label)

	# Walls: 0.2 x 3.0 m, standing on the floor, flush with the footprint edge; cutters 1.6 x 2.4 m and deeper than the wall.
	for wall_name: String in ["WallEntrance", "WallFar", "WallLeft", "WallRight"]:
		var wall := room.get_node("Shell/" + wall_name) as CSGBox3D
		var along_z := wall_name.begins_with("WallE") or wall_name == "WallFar"
		var thickness := wall.size.z if along_z else wall.size.x
		var centre := absf(wall.position.z) if along_z else absf(wall.position.x)
		var half := footprint.y / 2.0 if along_z else footprint.x / 2.0
		_expect(problems, is_equal_approx(thickness, WALL_THICKNESS) and is_equal_approx(wall.size.y, WALL_HEIGHT), "%s: %s is %.2f m thick and %.2f m high" % [label, wall_name, thickness, wall.size.y])
		_expect(problems, is_zero_approx(wall.position.y - wall.size.y / 2.0), "%s: %s does not stand on the floor" % [label, wall_name])
		_expect(problems, is_equal_approx(centre + thickness / 2.0, half), "%s: %s is not flush with the footprint edge" % [label, wall_name])
		_expect(problems, wall.material != null and wall.material.resource_path == MATERIAL_DIR + "wall.tres", "%s: %s does not use wall.tres" % [label, wall_name])
		for cutter in wall.get_children():
			var hole := cutter as CSGBox3D
			var width := maxf(hole.size.x, hole.size.z)
			var depth := minf(hole.size.x, hole.size.z)
			_expect(problems, hole.operation == CSGShape3D.OPERATION_SUBTRACTION, "%s: %s/%s does not subtract" % [label, wall_name, hole.name])
			_expect(problems, is_equal_approx(width, DOORWAY_WIDTH) and is_equal_approx(hole.size.y, DOORWAY_HEIGHT), "%s: %s is %.2f x %.2f m, expected 1.6 x 2.4" % [label, hole.name, width, hole.size.y])
			_expect(problems, depth >= thickness + 0.1, "%s: %s is only %.2f m deep for a %.2f m wall" % [label, hole.name, depth, thickness])
			_expect(problems, is_zero_approx(wall.position.y + hole.position.y - hole.size.y / 2.0), "%s: %s does not start at the floor" % [label, hole.name])
			_expect(problems, hole.material != null and hole.material.resource_path == MATERIAL_DIR + "wall.tres", "%s: %s does not use wall.tres" % [label, hole.name])
			_expect(problems, width >= 2.0 * capsule.radius * 2.0 and hole.size.y >= capsule.height + 0.6, "%s: %s is too small for the player (2x width, 0.6 m head room)" % [label, hole.name])

	# Ceiling: its own CSG shape beside the Shell, 0.2 m thick on top of the walls, collision, layer 2 only.
	var ceiling := room.get_node("Ceiling") as CSGBox3D
	_expect(problems, ceiling.get_parent() == room and not ceiling.is_class("CSGCombiner3D"), "%s: the Ceiling is not a direct child of the room" % label)
	_expect(problems, ceiling.use_collision, "%s: the Ceiling has no collision" % label)
	_expect(problems, ceiling.layers == CEILING_LAYER, "%s: the Ceiling is on layers %d, expected only layer 2" % [label, ceiling.layers])
	_expect(problems, is_equal_approx(ceiling.size.y, SLAB_THICKNESS) and is_equal_approx(ceiling.position.y - ceiling.size.y / 2.0, WALL_HEIGHT), "%s: the Ceiling is %.2f m thick with its bottom at y = %.2f, expected 0.2 m at 3.0" % [label, ceiling.size.y, ceiling.position.y - ceiling.size.y / 2.0])
	_expect(problems, is_equal_approx(ceiling.size.x, footprint.x) and is_equal_approx(ceiling.size.z, footprint.y), "%s: the Ceiling does not cover the footprint" % label)
	_expect(problems, ceiling.material != null and ceiling.material.resource_path == MATERIAL_DIR + "ceiling.tres", "%s: the Ceiling does not use ceiling.tres" % label)

	# The lamp: one warm omni light near the ceiling centre without shadows, range over the whole room, paired with a visible block on layer 2.
	var light := room.get_node("RoomLight") as OmniLight3D
	var farthest := Vector3(footprint.x / 2.0, light.position.y, footprint.y / 2.0).length()
	_expect(problems, not light.shadow_enabled, "%s: RoomLight casts shadows" % label)
	_expect(problems, light.light_color.r >= light.light_color.g and light.light_color.g >= light.light_color.b and light.light_color.b < 0.95, "%s: RoomLight is not warm white" % label)
	_expect(problems, light.omni_range >= farthest, "%s: RoomLight range %.1f does not reach the far corner (%.1f m)" % [label, light.omni_range, farthest])
	_expect(problems, light.position.y > 2.2 and light.position.y < WALL_HEIGHT and absf(light.position.x) < 0.01 and absf(light.position.z) < 0.01, "%s: RoomLight is not near the ceiling centre (%s)" % [label, light.position])
	var fixture := room.get_node("Fixture") as MeshInstance3D
	var block := (fixture.mesh as BoxMesh)
	_expect(problems, fixture.layers == CEILING_LAYER, "%s: the Fixture is on layers %d, expected only layer 2" % [label, fixture.layers])
	_expect(problems, block.material != null and block.material.resource_path == MATERIAL_DIR + "fixture.tres", "%s: the Fixture does not use fixture.tres" % label)
	_expect(problems, is_equal_approx(fixture.position.y + block.size.y / 2.0, WALL_HEIGHT) and Vector2(fixture.position.x - light.position.x, fixture.position.z - light.position.z).length() < 0.01, "%s: the Fixture does not hang under the ceiling above the light" % label)

	# Closed: straight up from anywhere in the room hits the ceiling at 3.0 m, straight down the floor.
	var space := room.get_world_3d().direct_space_state
	var spots: Array[Vector2] = [Vector2.ZERO, footprint / 4.0, footprint * Vector2(-0.25, 0.25), footprint * Vector2(0.25, -0.25), -footprint / 4.0]
	for spot in spots:
		var from := room.global_position + Vector3(spot.x, 1.0, spot.y)
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, 2.5, 0.0)))
		if up.is_empty():
			problems.append("%s: a ray straight up from (%.1f, 1, %.1f) does not hit the ceiling" % [label, spot.x, spot.y])
		else:
			var hit_y: float = up["position"].y
			_expect(problems, absf(hit_y - WALL_HEIGHT) < 0.01, "%s: the ray up from (%.1f, 1, %.1f) hits at y = %.2f, expected 3.0" % [label, spot.x, spot.y, hit_y])
			_expect(problems, up["collider"] == ceiling, "%s: the ray up hit %s, not the Ceiling" % [label, up["collider"]])
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -2.0, 0.0)))
		_expect(problems, not down.is_empty() and absf((down["position"] as Vector3).y) < 0.01, "%s: a ray straight down from (%.1f, 1, %.1f) misses the floor" % [label, spot.x, spot.y])
	return problems

func test_lighting(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step, false)
	var environment := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	_expect(failures, environment.background_mode == Environment.BG_SKY and environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial, "the ProceduralSky is gone")
	_expect(failures, environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR or environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "ambient light source %d: the closed rooms get no fill" % environment.ambient_light_source)
	# Ambient light alone must not leave the darkest surface (the walls) black: at least 0.35 displayed.
	var fill := environment.ambient_light_energy * environment.ambient_light_color.srgb_to_linear().get_luminance()
	if environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY:
		fill = environment.ambient_light_energy * 0.3 ## The darkest part of the procedural sky.
	var wall := load(MATERIAL_DIR + "wall.tres") as StandardMaterial3D
	var wall_albedo := wall.albedo_color.srgb_to_linear().r * (load(MATERIAL_DIR + "grid_1m.png") as Texture2D).get_image().get_pixel(100, 100).srgb_to_linear().r
	var shown := (wall_albedo * fill)
	var shown_srgb := Color(shown, shown, shown).linear_to_srgb().r
	_expect(failures, shown_srgb >= 0.35, "ambient fill %.2f lights the walls to only %.2f (displayed); unlit corners must not be black" % [fill, shown_srgb])
	var sun := main.get_node("DirectionalLight3D") as DirectionalLight3D
	_expect(failures, sun.shadow_enabled, "the sun has no shadows: it would light the rooms through the ceilings")
	await _unload(main)
	return failures

func test_player_camera(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step, false)
	var player: CharacterBody3D = main.get_node("Level").player
	var camera: Camera3D = player.get_node("Head/Camera3D")
	_expect(failures, camera.cull_mask == ALL_LAYERS, "the player's cull_mask is %d, expected all %d layers" % [camera.cull_mask, ALL_LAYERS])
	_expect(failures, (camera.cull_mask & CEILING_LAYER) != 0, "the player's camera does not draw layer 2: no ceiling, no lamp")
	_expect(failures, main.find_child("OverviewCamera", true, false) == null, "a cutaway camera is left in a player step")
	await _unload(main)
	return failures

## The underside of a room's ceiling, in world space.
func _ceiling_bottom(room: Node3D) -> float:
	var ceiling := room.get_node("Ceiling") as CSGBox3D
	return ceiling.global_position.y - ceiling.size.y / 2.0

#endregion

func test_scene_runs(step: String) -> Array[String]:
	var failures: Array[String] = []
	var main := await _load_step(step, false)
	for i in 30:
		await process_frame
	_expect(failures, is_instance_valid(main) and main.is_inside_tree(), "scene left the tree")
	await _unload(main)
	return failures

#region Helpers

func _report(test_name: String, failures: Array[String]) -> void:
	if failures.is_empty():
		_passed += 1
		print("PASS  ", test_name)
		return
	_failed += 1
	print("FAIL  ", test_name)
	for message: String in failures.slice(0, 8):
		print("        ", message)
	if failures.size() > 8:
		print("        ... and %d more" % (failures.size() - 8))

func _skip(test_name: String, reason: String) -> void:
	_skipped += 1
	print("SKIP  ", test_name)
	print("        ", reason)

func _expect(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

## Instances a step's main scene. By default it waits until the CSG shapes have built their collision.
func _load_step(step: String, settle := true) -> Node:
	var scene: PackedScene = load("res://steps/%s/main.tscn" % step)
	var main := scene.instantiate()
	root.add_child(main)
	if settle:
		await _wait_physics(10)
	return main

func _unload(main: Node) -> void:
	for action: String in ["move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "jump"]:
		Input.action_release(action)
	root.remove_child(main)
	main.free()
	await process_frame

## Runs the simulation faster than real time with the same 1/60 s steps: the engine ticks
## SPEED_UP times as often and hands out SPEED_UP times the delta of each (smaller) tick.
func _fast_forward(on: bool) -> void:
	Engine.physics_ticks_per_second = 60 * (SPEED_UP if on else 1)
	Engine.time_scale = float(SPEED_UP) if on else 1.0

func _wait_physics(frames: int) -> void:
	for i in frames:
		await physics_frame

func _action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame

#endregion
