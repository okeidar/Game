extends Node3D
## The greyfield, rebuilt as a test hall (Omer directive 2026-09-18):
## one room per unique mechanic. MOVE / STRIKE / VOLLEY rooms hold training
## dummies that never strike back (or nothing at all); DEFEND holds the only
## real enemy. Dusk, fog, cold moonlight, no decoration without a job.

const Pickup = preload("res://src/world/feather_pickup.gd")

const ROOMS := ["MOVE", "STRIKE", "VOLLEY", "DEFEND"]
const ROOM_CENTERS := [-25.5, -8.5, 8.5, 25.5]

var player_spawn := Vector3(-25.5, 0.1, 1.5)
## One entry per enemy: pos, ai (false = training dummy, never strikes), name.
var enemy_specs: Array = [
	{"pos": Vector3(-10.5, 0.05, -3.0), "ai": false, "name": "DUMMY"},
	{"pos": Vector3(-6.5, 0.05, 2.5), "ai": false, "name": "DUMMY2"},
	{"pos": Vector3(5.5, 0.05, -3.5), "ai": false, "name": "DUMMY3"},
	{"pos": Vector3(9.5, 0.05, 1.0), "ai": false, "name": "DUMMY4"},
	{"pos": Vector3(13.5, 0.05, -2.5), "ai": false, "name": "DUMMY5"},
	{"pos": Vector3(25.5, 0.05, -2.0), "ai": true, "name": "EFFIGY"},
]
var pickups: Array = []

func room_at(pos: Vector3) -> String:
	if pos.x < -17.0: return "MOVE"
	if pos.x < 0.0: return "STRIKE"
	if pos.x < 17.0: return "VOLLEY"
	return "DEFEND"

func mesh_instance(mesh: Mesh, color: Color, emission := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if emission:
		mat.emission_enabled = true
		mat.emission = color
	n.material_override = mat
	return n

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	# iter41 visual pass: dusk sky replaces the flat void, ACES + light bloom,
	# fog breathes into the sky. Gameplay numbers untouched.
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("05070e")
	sky_mat.sky_horizon_color = Color("1d2c49")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color("04060a")
	sky_mat.ground_horizon_color = Color("0e1626")
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.05
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("54627e")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color("0d1420")
	env.fog_density = 0.02
	env.fog_sky_affect = 0.55
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -30, 0)
	moon.light_color = Color("a9bedd")
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	add_child(moon)
	# faint warm bounce off the horizon, opposite the moon - lifts the dark sides
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 145, 0)
	fill.light_color = Color("7a6a55")
	fill.light_energy = 0.22
	add_child(fill)

	_static_box(Vector3(68, 0.3, 17), Vector3(0, -0.15, 0), Color("20261f"))   # floor
	# perimeter walls, 3m tall
	_static_box(Vector3(68, 3.0, 0.6), Vector3(0, 1.5, -8.5), Color("1a1f27"))
	_static_box(Vector3(68, 3.0, 0.6), Vector3(0, 1.5, 8.5), Color("1a1f27"))
	_static_box(Vector3(0.6, 3.0, 17), Vector3(-34, 1.5, 0), Color("1a1f27"))
	_static_box(Vector3(0.6, 3.0, 17), Vector3(34, 1.5, 0), Color("1a1f27"))
	# room dividers with a 3m doorway
	for dx in [-17.0, 0.0, 17.0]:
		_static_box(Vector3(0.6, 3.0, 7.0), Vector3(dx, 1.5, -5.0), Color("232933"))
		_static_box(Vector3(0.6, 3.0, 7.0), Vector3(dx, 1.5, 5.0), Color("232933"))
	# doorway lamps: emissive posts that name every pass-through (job: wayfinding)
	for dx in [-17.0, 0.0, 17.0]:
		for dz in [-1.85, 1.85]:
			var lamp := mesh_instance(BoxMesh.new(), Color("9fb4d8"), true)
			(lamp.mesh as BoxMesh).size = Vector3(0.14, 2.2, 0.14)
			lamp.position = Vector3(dx, 1.1, dz)
			add_child(lamp)
	# wayfinding spine: a faint lit strip down the hall's main axis
	var spine := mesh_instance(BoxMesh.new(), Color("3b4a63"), true)
	(spine.mesh as BoxMesh).size = Vector3(67.0, 0.02, 0.16)
	spine.position = Vector3(0, 0.011, 0)
	add_child(spine)
	# MOVE room: pillars to circle and to test the camera against
	for pp in [Vector3(-28, 1.1, -4), Vector3(-22.5, 1.1, 1)]:
		_static_box(Vector3(1.4, 2.2, 1.4), pp, Color("2c313b"))
	# room name markers, floating pale ink
	for i in ROOMS.size():
		var lab := Label3D.new()
		lab.text = ROOMS[i]
		lab.position = Vector3(ROOM_CENTERS[i], 3.4, -6.5)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.font_size = 110
		lab.modulate = Color("8f99a8")
		lab.outline_size = 12
		lab.outline_modulate = Color("0a0d14")
		add_child(lab)
	# spawn marker: a pale slab where the player wakes
	var slab := mesh_instance(BoxMesh.new(), Color("3d4450"))
	(slab.mesh as BoxMesh).size = Vector3(1.6, 0.12, 1.6)
	slab.position = Vector3(player_spawn.x, 0.06, player_spawn.z)
	add_child(slab)
	# DEFEND room: the duel space gets its own marks (jobs: telegraph the
	# fight boundary, light the far room). 24-segment inscribed ring, two
	# ember cressets at its edge.
	var ring_center := Vector3(25.5, 0.02, -2.0)
	for i in 24:
		var a := TAU * float(i) / 24.0
		var seg := mesh_instance(BoxMesh.new(), Color("7f8ea6"), true)
		(seg.mesh as BoxMesh).size = Vector3(1.05, 0.02, 0.14)
		seg.position = ring_center + Vector3(cos(a) * 4.5, 0.0, sin(a) * 4.5)
		seg.rotation.y = -a + PI * 0.5
		add_child(seg)
	for cp in [Vector3(21.4, 0, 2.2), Vector3(29.6, 0, -6.2)]:
		var post := mesh_instance(BoxMesh.new(), Color("2c313b"))
		(post.mesh as BoxMesh).size = Vector3(0.3, 1.5, 0.3)
		post.position = cp + Vector3(0, 0.75, 0)
		add_child(post)
		var flame := mesh_instance(BoxMesh.new(), Color("c98a5a"), true)
		(flame.mesh as BoxMesh).size = Vector3(0.2, 0.3, 0.2)
		flame.position = cp + Vector3(0, 1.65, 0)
		add_child(flame)
		var glow := OmniLight3D.new()
		glow.light_color = Color("c98a5a")
		glow.light_energy = 0.5
		glow.omni_range = 5.0
		glow.omni_attenuation = 1.6
		glow.position = cp + Vector3(0, 1.8, 0)
		add_child(glow)
	# STRIKE/VOLLEY marks (jobs: name the hittable target, draw the eye to ammo)
	for spec in enemy_specs:
		if spec["ai"]: continue
		var pad := mesh_instance(BoxMesh.new(), Color("6d7a90"), true)
		(pad.mesh as BoxMesh).size = Vector3(0.95, 0.02, 0.95)
		pad.position = Vector3(spec["pos"].x, 0.015, spec["pos"].z)
		add_child(pad)
	for fp in [Vector3(4, 0, 3.5), Vector3(8.5, 0, -4.5), Vector3(13, 0, 3.5), Vector3(21.5, 0, 3.0), Vector3(29.5, 0, 0.5)]:
		var mark := mesh_instance(BoxMesh.new(), Color("b8b2a4"), true)
		(mark.mesh as BoxMesh).size = Vector3(0.5, 0.02, 0.5)
		mark.position = Vector3(fp.x, 0.015, fp.z)
		mark.rotation.y = PI * 0.25
		add_child(mark)
	# feathers: VOLLEY room stocks the ammo tests, DEFEND offers recovery mid-fight
	for fp in [Vector3(4, 0, 3.5), Vector3(8.5, 0, -4.5), Vector3(13, 0, 3.5), Vector3(21.5, 0, 3.0), Vector3(29.5, 0, 0.5)]:
		spawn_pickup(fp)

func _static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var vis := mesh_instance(BoxMesh.new(), color)
	(vis.mesh as BoxMesh).size = size
	vis.position = pos
	body.add_child(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)
	add_child(body)

func spawn_pickup(pos: Vector3, value := 0.0) -> void:
	var pk := Pickup.new()
	if value > 0.0:
		pk.value = value
	pk.position = pos
	add_child(pk)
	pickups.append(pk)
