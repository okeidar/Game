extends Node3D
## Checkpoint machinery (Omer directive 2026-09-18): a checkpoint exists, can
## be registered, can be interacted with. What resting DOES is undecided -
## stubbed and marked open. No lore, no design values.

const T = preload("res://src/combat/tuning.gd")
const Sim = preload("res://src/combat/combat_sim.gd")
const Audio = preload("res://src/combat/audio_bus.gd")

var registered := false
var marker: MeshInstance3D
var mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("checkpoints")
	marker = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 1.9, 0.7)
	marker.mesh = bm
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color("4a5468")
	mat.emission_enabled = true
	mat.emission = Color("2a3242")
	mat.emission_energy_multiplier = 0.8
	marker.material_override = mat
	marker.position.y = 0.95
	add_child(marker)

func activate(_player) -> void:
	if not registered:
		registered = true
		Sim.active_checkpoint = self
		mat.emission = Color("cfc8b8")
		mat.emission_energy_multiplier = 2.2
		Sim.log_event("CHECKPOINT REGISTERED")
	# Resting effect: UNDECIDED (open decision for Omer). Machinery stub only.
	Audio.sfx("rest")
	Sim.toast("Rested at the checkpoint (effect undecided)")
	Sim.log_event("CHECKPOINT REST (stub: what rest does is undecided)")

## Respawn linkage machinery: where the player rises after death.
## (Rest effects themselves remain undecided.)
static func respawn_position(fallback: Vector3) -> Vector3:
	if Sim.active_checkpoint != null:
		return Sim.active_checkpoint.global_position + Vector3(0, 0.1, 0)
	return fallback

func _physics_process(_dt: float) -> void:
	pass
