extends Node3D
## NPC machinery (round 5B): an interactable figure that carries a dialogue
## tree. Which NPCs exist, where they stand, and every word are OPEN.

const T = preload("res://src/combat/tuning.gd")
const Sim = preload("res://src/combat/combat_sim.gd")
const Dialogue = preload("res://src/combat/dialogue.gd")

var display_name := "STRANGER"   # SCAFFOLD placeholder name, no canon
var dialogue_tree := {}          # injected; empty = nothing to say yet
var mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("npcs")
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.7, 0.6)
	body.mesh = bm
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color("6b6252")
	mat.emission_enabled = true
	mat.emission = Color("3a3428")
	mat.emission_energy_multiplier = 0.6
	body.material_override = mat
	body.position.y = 0.85
	add_child(body)

func interactable_by(player) -> bool:
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	return d.length() <= T.CHECKPOINT_RADIUS_SCAFFOLD

func start_dialogue() -> Dialogue:
	var d = Dialogue.new()
	if dialogue_tree.is_empty():
		d.start({"entry": {"text": "(nothing to say - dialogue undecided)", "choices": []}}, "entry")
	else:
		d.start(dialogue_tree, "entry")
	Sim.log_event("NPC %s SPEAKS (scaffold)" % display_name)
	return d
