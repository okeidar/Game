extends RefCounted
## Equipment scaffolding (round 4): named slots holding moveset tables;
## equipping a weapon swaps the player's moveset. Slot rules, what else is
## equippable, and the weapon catalog are OPEN.

const Sim = preload("res://src/combat/combat_sim.gd")

var slots := {"weapon": null}   # slot name -> moveset Dictionary

func equip(slot: String, moveset: Dictionary, player) -> bool:
	if not slots.has(slot):
		return false
	slots[slot] = moveset
	if slot == "weapon":
		player.moveset = moveset
		player.chain_index = 0
		player.chain_window_t = 0.0
	Sim.log_event("EQUIPPED %s -> %s" % [moveset.get("id", "?"), slot])
	return true

func unequip(slot: String, player, fallback: Dictionary) -> void:
	slots[slot] = null
	if slot == "weapon":
		player.moveset = fallback
	Sim.log_event("UNEQUIPPED %s" % slot)

func equipped_id(slot: String) -> String:
	var m = slots.get(slot)
	return m.get("id", "?") if m != null else "(empty)"
