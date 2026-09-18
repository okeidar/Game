extends RefCounted
## Moveset machinery (Omer directive 2026-09-18, round 2): per-weapon attack
## tables - light chain, heavy, running attack, rolling attack, jump attack
## slots. The weapon/moveset CATALOG is Omer's later decision; this file holds
## the table shape and one scaffold moveset proving the machinery runs.
## Explicitly NOT included (Omer's exclusions): equip load, poise/hyperarmor,
## charged heavies, weapon arts, guard counters.

const T = preload("res://src/combat/tuning.gd")

## The single scaffold moveset: every slot reuses the existing proven attack
## data so current playtest behavior stays stable. All OPEN: weapons, chains,
## frame data.
static func scaffold_moveset() -> Dictionary:
	return {
		"id": "scaffold_blade",                    # SCAFFOLD - catalog undecided
		"light_chain": [T.PLAYER_ATTACK, T.PLAYER_ATTACK],  # SCAFFOLD - chain undecided
		"heavy": T.HEAVY_ATTACK,
		"running_attack": T.PLAYER_ATTACK,         # SCAFFOLD - properties undecided
		"rolling_attack": T.PLAYER_ATTACK,         # SCAFFOLD
		"jump_attack": T.PLAYER_ATTACK,            # SCAFFOLD
	}
