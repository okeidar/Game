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
const Checkpoint = preload("res://src/world/checkpoint.gd")
const DeathPenalty = preload("res://src/combat/death_penalty.gd")
const Progression = preload("res://src/combat/progression.gd")
const Shell = preload("res://src/ui/shell.gd")

var sim_root: Node3D
var arena
var player
var effigy          # the one real enemy (DEFEND room)
var effigies: Array = []
var cam
var hud
var build_id := "dev"
var progression
var shell
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
	for spec in arena.enemy_specs:
		var e = Effigy.new()
		e.position = spec.pos
		e.ai_enabled = spec.ai
		e.display_name = spec.name
		sim_root.add_child(e)
		effigies.append(e)
		e.died.connect(_on_effigy_died.bind(e))
		if spec.ai:
			effigy = e
	cam = CameraRig.new()
	cam.player = player
	add_child(cam)
	player.cam = cam
	hud = Hud.new()
	hud.player = player
	hud.effigy = effigy
	hud.build_id = build_id
	add_child(hud)
	progression = Progression.new()
	var cp = Checkpoint.new()
	cp.position = Vector3(-31.0, 0.05, 1.5)  # MOVE room, beside the slab
	sim_root.add_child(cp)
	player.facing = Vector3(1, 0, 0)  # face down the hall, toward the rooms
	player.rotation.y = atan2(player.facing.x, player.facing.z)
	player.died.connect(_on_player_died)
	shell = Shell.new()
	shell.player = player
	shell.on_begin = func(): shell.close()
	shell.on_respawn = func(): _respawn(); shell.close()
	shell.on_quit_to_title = func(): shell.open("title")
	add_child(shell)
	if not ("--self-test" in OS.get_cmdline_user_args()):
		shell.open("title")  # shell machinery: boot lands on the title menu

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
	# room banner + enemy bar follows the relevant effigy
	if hud != null and player != null and arena != null:
		hud.set_room(arena.room_at(player.position))
		var shown = null
		if player.lock_target != null:
			shown = player.lock_target
		else:
			var best_d := 10.0
			for e in effigies:
				if e.dead:
					continue
				var d: float = e.global_position.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					shown = e
		hud.effigy = shown
	if shell != null and shell.state == "hidden":
		if Input.is_action_just_pressed("menu_inventory"):
			shell.open("inventory")
		elif Input.is_action_just_pressed("menu_equipment"):
			shell.open("equipment")
		elif Input.is_action_just_pressed("ui_cancel"):
			shell.open("pause")
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_died() -> void:
	DeathPenalty.drop(player, sim_root)
	deaths += 1
	hud.set_banner("YOU DIED")
	Sim.log_event("YOU DIED x%d" % deaths)
	death_timer = 0.0
	shell.open("death")  # death screen: rise on confirm, genre shape

func _on_effigy_died(e) -> void:
	player.add_feathers(Tuning.KILL_FEATHERS)
	Sim.log_event("%s FELLED +%d feathers" % [e.display_name, int(Tuning.KILL_FEATHERS)])

func _respawn() -> void:
	var rsp: Vector3 = Checkpoint.respawn_position(arena.player_spawn)
	if Sim.active_checkpoint != null:
		Sim.log_event("RESPAWN AT CHECKPOINT")
	player.reset_run(rsp)
	for e in effigies:
		e.reset_run(e.spawn_pos)
	hud.set_banner("")
	Sim.log_event("WAKE AT THE SLAB")

func _self_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var ok := player != null and effigy != null and cam != null
	print("SELF_TEST_OK built=", ok, " renderer=", RenderingServer.get_current_rendering_method())
	get_tree().quit(0 if ok else 1)
