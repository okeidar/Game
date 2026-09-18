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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("54627e")
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color("0d1420")
	env.fog_density = 0.025
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -30, 0)
	moon.light_color = Color("a9bedd")
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	add_child(moon)

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
