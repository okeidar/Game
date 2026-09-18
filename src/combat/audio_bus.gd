extends RefCounted
## Audio hooks scaffolding (round 5A): an SFX/music event bus. Game systems
## emit semantic audio events; what actually PLAYS (assets, mixing, volume)
## is entirely OPEN. No audio assets exist - hooks only.

const Sim = preload("res://src/combat/combat_sim.gd")

static var sfx_log: Array = []   # recent emissions, newest last
static var music_now := ""

static func sfx(id: String) -> void:
	sfx_log.append(id)
	if sfx_log.size() > 100:
		sfx_log.pop_front()
	Sim.log_event("AUDIO sfx:%s (hook, no assets)" % id)

static func music(id: String) -> void:
	if music_now == id:
		return
	music_now = id
	Sim.log_event("AUDIO music:%s (hook, no assets)" % id)
