extends Node3D
## The greyfield: a walled yard at dusk. Fog, cold moonlight, no decoration
## that does not serve readability. Walls exist so the camera must prove itself.

const Pickup = preload("res://src/world/feather_pickup.gd")

var player_spawn := Vector3(0, 0.1, 6.0)
var effigy_spawn := Vector3(0, 0.1, -4.0)
var pickups: Array = []

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
	env.fog_density = 0.035
	world.environment = env
	add_child(world)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58, -30, 0)
	moon.light_color = Color("a9bedd")
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	add_child(moon)

	_static_box(Vector3(34, 0.3, 34), Vector3(0, -0.15, 0), Color("20261f"))   # floor
	# perimeter walls, 3m tall
	_static_box(Vector3(34, 3.0, 0.6), Vector3(0, 1.5, -17), Color("1a1f27"))
	_static_box(Vector3(34, 3.0, 0.6), Vector3(0, 1.5, 17), Color("1a1f27"))
	_static_box(Vector3(0.6, 3.0, 34), Vector3(-17, 1.5, 0), Color("1a1f27"))
	_static_box(Vector3(0.6, 3.0, 34), Vector3(17, 1.5, 0), Color("1a1f27"))
	# broken pillars to circle and to test the camera against
	for p in [Vector3(-6, 1.1, -6), Vector3(6.5, 1.1, -7), Vector3(-7, 1.1, 5), Vector3(7, 1.1, 6)]:
		_static_box(Vector3(1.4, 2.2, 1.4), p, Color("2c313b"))
	# spawn marker: a pale slab where the player wakes
	var slab := mesh_instance(BoxMesh.new(), Color("3d4450"))
	(slab.mesh as BoxMesh).size = Vector3(1.6, 0.12, 1.6)
	slab.position = Vector3(player_spawn.x, 0.06, player_spawn.z)
	add_child(slab)
	# scattered feathers to gather
	for pp in [Vector3(-8, 0, -2), Vector3(8, 0, 0), Vector3(-3, 0, -10), Vector3(4, 0, 10), Vector3(0, 0, -13)]:
		spawn_pickup(pp)

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
