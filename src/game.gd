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
const Settings = preload("res://src/combat/settings.gd")
const NGPlus = preload("res://src/combat/ngplus.gd")
const Audio = preload("res://src/combat/audio_bus.gd")
const MapData = preload("res://src/combat/map_data.gd")
const Tutorial = preload("res://src/combat/tutorial.gd")
const Npc = preload("res://src/world/npc.gd")
var map_data
var tutorial
var settings

var sim_root: Node3D
var arena
var player
var _dbg_pos := false
var _dbg_acc := 0.0
var _dbg_kill := false  # debug hook (?killme=1): forces one death after begin so the death loop can be exercised headlessly
var _dbg_hud := false   # debug hook (?hudcheck=1): applies one non-lethal hit, low stamina, and effigy damage so HUD feedback can be screenshot-verified
var effigy          # the one real enemy (DEFEND room)
var effigies: Array = []
var cam
var hud
var build_id := "dev"
var progression
var shell
var lock_marker: MeshInstance3D = null
var death_timer := 0.0
var death_menu_t := -1.0   # counts down after death; YOU DIED screen waits its genre beat
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
	if OS.has_feature("web"):
		var qp = JavaScriptBridge.eval("location.search", true)
		_dbg_pos = qp != null and str(qp).find("debugpos") >= 0
		_dbg_kill = qp != null and str(qp).find("killme") >= 0
		_dbg_hud = qp != null and str(qp).find("hudcheck") >= 0

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
		e.max_hp = NGPlus.scaled("enemy_hp", e.max_hp)   # NG+ scaling hook (identity at cycle 0)
		e.hp = e.max_hp
		e.died.connect(_on_effigy_died.bind(e))
		if spec.ai:
			effigy = e
	cam = CameraRig.new()
	cam.player = player
	add_child(cam)
	player.cam = cam
	# [overnight proposal] lock-on marker: a gold spark floating over the locked enemy
	lock_marker = MeshInstance3D.new()
	var lm_mesh := SphereMesh.new()
	lm_mesh.radius = 0.10
	lm_mesh.height = 0.20
	lock_marker.mesh = lm_mesh
	var lm_mat := StandardMaterial3D.new()
	lm_mat.albedo_color = Color("e8c96a")
	lm_mat.emission_enabled = true
	lm_mat.emission = Color("e8c96a")
	lm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lock_marker.material_override = lm_mat
	lock_marker.visible = false
	sim_root.add_child(lock_marker)
	hud = Hud.new()
	hud.player = player
	hud.effigy = effigy
	hud.build_id = build_id
	add_child(hud)
	progression = Progression.new()
	player.progression = progression   # one shared currency ledger (essence - canon name)
	var cp = Checkpoint.new()
	cp.position = Vector3(-31.0, 0.05, 1.5)  # MOVE room, beside the slab
	sim_root.add_child(cp)
	player.facing = Vector3(1, 0, 0)  # face down the hall, toward the rooms
	player.rotation.y = atan2(player.facing.x, player.facing.z)
	player.died.connect(_on_player_died)
	# greybox item seed (iteration 3, overnight): two scaffold consumables so the
	# inventory UI has something real to show. Effects ride existing machinery;
	# names/quantities/effects all SCAFFOLD - the item catalog is Omer's.
	player.inventory.register_item_def("ember draught", func(u): u.hp = minf(u.max_hp, u.hp + 30.0); Sim.stat("item", {"id": "ember draught"}))
	player.inventory.register_item_def("smoke pellet", func(u): _calm_nearby(u.global_position, 8.0); Sim.stat("item", {"id": "smoke pellet"}))
	player.inventory.register_item_desc("ember draught", "closes wounds +30 hp - the drink holds you still, exposed")
	player.inventory.register_item_desc("smoke pellet", "they lose your trail within 8m - one breath of cover, then gone")
	player.inventory.add_item("ember draught", 2)
	player.inventory.add_item("smoke pellet", 3)
	# Juice pass: a small round-robin SFX player pool; the audio bus plays through it.
	var sfx_pool: Array = []
	for i in 4:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		add_child(ap)
		sfx_pool.append(ap)
	Audio.bind_pool(sfx_pool)
	shell = Shell.new()
	shell.player = player
	shell.on_begin = func(): shell.close()
	shell.on_respawn = func(): _respawn(); shell.close()
	shell.on_quit_to_title = func(): shell.open("title")
	add_child(shell)
	cp.on_activate = func(): shell.open("checkpoint")
	shell.checkpoint_ctx = {"progression": progression, "effigies": effigies}
	settings = Settings.new()
	settings.register_setting("master_volume", {"label": "master volume", "min": 0.0, "max": 1.0, "step": 0.1, "value": 1.0})  # SCAFFOLD entry
	settings.register_setting("camera_fov", {"label": "camera fov", "min": 60.0, "max": 100.0, "step": 5.0, "value": 62.0, "on_change": func(v): cam.cam.fov = v})  # SCAFFOLD entry
	shell.settings = settings
	map_data = MapData.new()
	for r in arena.ROOMS:
		map_data.register_region(r)
	for i in range(arena.ROOMS.size() - 1):
		map_data.link(arena.ROOMS[i], arena.ROOMS[i + 1])
	shell.map_data = map_data
	tutorial = Tutorial.new()
	tutorial.register_rule("first_low_stamina", func(c): return c.player.stamina < 20.0, "Stamina runs everything - watch the green bar (SCAFFOLD hint)")
	tutorial.ctx = {"player": player}
	player.npc_spoke.connect(func(n): shell.dialogue = n.start_dialogue(); shell.open("dialogue"))
	var npc = Npc.new()
	npc.position = Vector3(-23.5, 0.05, -3.0)  # MOVE room - scaffold placement
	sim_root.add_child(npc)
	Audio.music("title")
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
	if death_menu_t >= 0.0:
		death_menu_t -= delta
		if death_menu_t < 0.0 and shell != null and shell.state != "death":
			shell.open("death")  # the banner lands first; the screen takes over after its beat
	if _dbg_kill and player != null and not player.dead and shell != null and shell.state == "hidden":
		_dbg_kill = false
		player.apply_hit(99999.0, player.global_position + Vector3(0, 0, 1), 0.0)
	if _dbg_hud and player != null and not player.dead and shell != null and shell.state == "hidden":
		_dbg_hud = false
		player.apply_hit(35.0, player.global_position + Vector3(0, 0, 1), 0.0)
		player.stamina = 10.0
		if effigy != null:
			effigy.apply_hit(20.0, player.global_position, 0.0)
	if _dbg_pos and player != null:
		_dbg_acc += delta
		if _dbg_acc >= 0.5:
			_dbg_acc = 0.0
			print("POS %.3f %.3f hp=%.0f st=%.0f" % [player.global_position.x, player.global_position.z, player.hp, player.stamina])
			for e in get_tree().get_nodes_in_group("enemies"):
				print("EPOS %s %.3f %.3f hp=%.0f dead=%d" % [e.display_name, e.global_position.x, e.global_position.z, e.hp, 1 if e.dead else 0])
	if lock_marker != null:
		if player != null and player.lock_target != null and is_instance_valid(player.lock_target) and not player.lock_target.dead:
			lock_marker.visible = true
			lock_marker.global_position = player.lock_target.global_position + Vector3(0, 2.25 + sin(Time.get_ticks_msec() / 350.0) * 0.06, 0)
		else:
			lock_marker.visible = false
	# room banner + enemy bar follows the relevant effigy
	if hud != null and player != null and arena != null:
		hud.set_room(arena.room_at(player.position))
		if map_data != null:
			map_data.set_current(arena.room_at(player.position))
		if tutorial != null:
			tutorial.tick()
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
		elif Input.is_action_just_pressed("menu_gestures"):
			shell.open("gestures")
		elif Input.is_action_just_pressed("menu_map"):
			shell.open("map")
		elif Input.is_action_just_pressed("ui_cancel"):
			shell.open("pause")
	if Input.is_action_just_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_player_died() -> void:
	Sim.stat("death", {"deaths": deaths + 1})
	DeathPenalty.drop(player, sim_root)
	deaths += 1
	hud.set_banner("YOU DIED")
	Audio.sfx("death")
	Audio.music("death")
	Sim.log_event("YOU DIED x%d" % deaths)
	death_timer = 0.0
	death_menu_t = Tuning.DEATH_SCREEN_DELAY  # death screen: rise on confirm, after the genre beat

func _on_effigy_died(e) -> void:
	var reward: float = e.kill_reward()
	progression.add_essence(reward)
	if reward < Tuning.KILL_ESSENCE:
		Sim.log_event("%s FELLED +%d essence (risen - worth less until the world resets)" % [e.display_name, int(reward)])
	else:
		Sim.log_event("%s FELLED +%d essence" % [e.display_name, int(reward)])

func _calm_nearby(pos: Vector3, radius: float) -> void:
	# smoke pellet effect (scaffold): enemies in radius lose the trail
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pos) <= radius and e.awareness != null:
			e.awareness.suspicion = 0.0
			if e.awareness.state != "calm":
				e.awareness.state = "calm"
	Sim.toast("smoke - they lose the trail (scaffold)")

func _respawn() -> void:
	Sim.stat("respawn")
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
