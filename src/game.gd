extends Node3D
## Composition root: builds the greyfield, the winged one, the effigy, the
## camera and the HUD; owns hitstop (tree pause) and the death/respawn loop.

const Sim = preload("res://src/combat/combat_sim.gd")
const Tuning = preload("res://src/combat/tuning.gd")
const Player = preload("res://src/actors/player.gd")
const Effigy = preload("res://src/actors/effigy.gd")
const Arena = preload("res://src/world/arena.gd")
const CameraRig = preload("res://src/camera/third_person_camera.gd")
const Hud = preload("res://src/ui/hud.gd")

var sim_root: Node3D
var arena
var player
var effigy
var cam
var hud
var build_id := "dev"
var death_timer := 0.0
var deaths := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--run-tests" in OS.get_cmdline_user_args():
		var Harness = preload("res://tests/test_harness.gd")
		add_child(Harness.new())
		return
	_load_build_id()
	_build()
	if "--self-test" in OS.get_cmdline_user_args():
		_self_test()

func _load_build_id() -> void:
	const B = preload("res://src/build_id.gd")
	build_id = B.ID

func _build() -> void:
	Sim.reset()
	sim_root = Node3D.new()
	sim_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sim_root)
	arena = Arena.new()
	sim_root.add_child(arena)
	player = Player.new()
	player.position = arena.player_spawn
	sim_root.add_child(player)
	effigy = Effigy.new()
	effigy.position = arena.effigy_spawn
	sim_root.add_child(effigy)
	cam = CameraRig.new()
	cam.player = player
	add_child(cam)
	player.cam = cam
	hud = Hud.new()
	hud.player = player
	hud.effigy = effigy
	hud.build_id = build_id
	add_child(hud)
	player.facing = (arena.effigy_spawn - arena.player_spawn)
	player.facing.y = 0.0
	player.facing = player.facing.normalized()
	player.rotation.y = atan2(player.facing.x, player.facing.z)
	player.died.connect(_on_player_died)
	effigy.died.connect(_on_effigy_died)

func _process(delta: float) -> void:
	if Sim.hitstop_left > 0.0:
		if not get_tree().paused:
			get_tree().paused = true
		Sim.hitstop_left -= delta
		if Sim.hitstop_left <= 0.0:
			get_tree().paused = false
	if death_timer > 0.0:
		death_timer -= delta
		if death_timer <= 0.0:
			_respawn()
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_died() -> void:
	deaths += 1
	hud.set_banner("YOU DIED")
	Sim.log_event("YOU DIED x%d" % deaths)
	death_timer = 2.5

func _on_effigy_died() -> void:
	player.add_feathers(Tuning.KILL_FEATHERS)
	Sim.log_event("EFFIGY FELLED +%d feathers" % int(Tuning.KILL_FEATHERS))

func _respawn() -> void:
	player.reset_run(arena.player_spawn)
	effigy.reset_run(arena.effigy_spawn)
	hud.set_banner("")
	Sim.log_event("WAKE AT THE SLAB")

func _self_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var ok := player != null and effigy != null and cam != null
	print("SELF_TEST_OK built=", ok, " renderer=", RenderingServer.get_current_rendering_method())
	get_tree().quit(0 if ok else 1)
