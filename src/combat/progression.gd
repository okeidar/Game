extends RefCounted
## Progression machinery: the spend/sink path and an upgrade application hook.
## Omer ruling 2026-09-19: feathers are NOT currency - never enemy-dropped,
## never spent, never death-dropped. ESSENCE (canon - Omer 2026-09-19:
## "Essence is good. I want it in the world of vamora") is the enemy-drop
## currency: earned from felled enemies, spent here, dropped on death.
## Prices and the upgrade catalog remain SCAFFOLD, not design.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")

var applied_upgrades: Array = []
var essence := 0.0   # the enemy-drop currency (canon name - Omer 2026-09-19)

func add_essence(n: float) -> void:
	essence += n

func can_afford(cost: Dictionary, _player) -> bool:
	return essence >= cost.get("essence", 0.0)

func spend(cost: Dictionary, player) -> bool:
	if not can_afford(cost, player):
		Sim.log_event("PROGRESSION SPEND DENIED %s" % str(cost))
		return false
	essence -= cost.get("essence", 0.0)
	Sim.log_event("PROGRESSION SPEND %s" % str(cost))
	return true

## Upgrade application hook. No catalog exists yet (undecided): the hook
## records and acknowledges, nothing more.
func apply_upgrade(upgrade_id: String, _player) -> bool:
	applied_upgrades.append(upgrade_id)
	Sim.log_event("UPGRADE APPLIED (stub, no catalog yet): %s" % upgrade_id)
	return true
