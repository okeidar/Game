extends RefCounted
## Save/load scaffolding (round 4): capture and restore game state as a plain
## Dictionary, with a JSON file path on top. Format, scope, and slot rules are
## all OPEN decisions.

const Sim = preload("res://src/combat/combat_sim.gd")
const Checkpoint = preload("res://src/world/checkpoint.gd")

const SAVE_PATH := "user://shell_save_scaffold.json"  # SCAFFOLD - format/slots undecided

static func capture(player, deaths: int) -> Dictionary:
	var cp = null
	if Sim.active_checkpoint != null:
		var p: Vector3 = Sim.active_checkpoint.global_position
		cp = [p.x, p.y, p.z]
	var inv := []
	for it in player.inventory.slots:
		inv.append({"id": it.id, "qty": it.qty})
	return {
		"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		"hp": player.hp, "stamina": player.stamina, "feathers": player.feathers,
		"essence": (player.progression.essence if player.progression != null else 0.0),
		"heal_charges": player.heal_charges, "deaths": deaths,
		"attributes": player.attrs.attrs.duplicate(),
		"inventory": inv, "checkpoint": cp,
	}

static func restore(data: Dictionary, player) -> void:
	var pp: Array = data.pos
	player.position = Vector3(pp[0], pp[1], pp[2])
	player.hp = data.hp
	player.stamina = data.stamina
	player.feathers = data.feathers
	if player.progression != null:
		player.progression.essence = data.get("essence", 0.0)
	player.heal_charges = data.heal_charges
	player.attrs.attrs = data.get("attributes", {}).duplicate()
	player.inventory.slots.clear()
	for it in data.get("inventory", []):
		player.inventory.slots.append({"id": it.id, "qty": it.qty})
	Sim.active_checkpoint = null   # checkpoint node relink is world-side (open)
	Sim.log_event("SAVE RESTORED (scaffold)")

static func save_to_file(player, deaths: int, path: String = SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(capture(player, deaths)))
	f.close()
	Sim.log_event("SAVE WRITTEN %s" % path)
	return true

static func load_from_file(player, path: String = SAVE_PATH) -> int:
	## returns deaths count restored, -1 on failure
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null:
		return -1
	restore(data, player)
	return data.get("deaths", 0)
