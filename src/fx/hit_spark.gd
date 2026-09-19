extends Node3D
## Juice pass (Omer directive 2026-09-19 "audio, effects, models"): a spark
## burst at the hit contact point. Procedural unshaded shards - no art assets.
## [overnight proposal - awaiting Omer review] shard count, speed, lifetime
## and the feel numbers are first-pass juice (iter37 tune: longer life,
## bigger shards after footage showed the 0.22s/0.2m burst unreadable),
## not realism. Holds its first beat through hitstop because the tree pause
## freezes it mid-burst - that is the intended punch.

static var spawned := 0   # test-visible: how many bursts ever spawned

const SHARD_COUNT := 9
const LIFETIME := 0.45
const SPEED := 4.2
const GRAVITY := 6.0

var spark_color := Color(1.0, 0.72, 0.32)   # warm contact flash by default

var _t := 0.0
var _dirs: Array[Vector3] = []
var _shards: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D

static func burst(parent: Node, pos: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var b = new()
	b.spark_color = color
	parent.add_child(b)
	b.global_position = pos
	spawned += 1

func _ready() -> void:
	add_to_group("hit_sparks")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = spark_color
	_mat.emission_enabled = true
	_mat.emission = spark_color
	_mat.emission_energy_multiplier = 3.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 0.32)
	for i in SHARD_COUNT:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.25, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = _mat
		m.basis = Basis.looking_at(dir, Vector3.UP, true)   # long axis (model front) along the flight direction
		add_child(m)
		_dirs.append(dir)
		_shards.append(m)

func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / LIFETIME, 0.0, 1.0)
	for i in _shards.size():
		var d: Vector3 = _dirs[i]
		_shards[i].position = d * SPEED * _t + Vector3(0, -GRAVITY * _t * _t * 0.5, 0)
		_shards[i].scale = Vector3.ONE * (1.0 - 0.75 * k)
	_mat.emission_energy_multiplier = 3.0 * (1.0 - k)
	if _t >= LIFETIME:
		queue_free()
