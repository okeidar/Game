extends RefCounted
## Audio bus: an SFX/music event bus. Game systems emit semantic audio events.
## Juice pass (Omer directive 2026-09-19): the hooks now PLAY real procedural
## wav assets through a small round-robin player pool bound by game.gd.
## [overnight proposal - awaiting Omer review] the assets are synthesized
## placeholders (python-generated), not final mix.

const Sim = preload("res://src/combat/combat_sim.gd")

static var sfx_log: Array = []   # recent emissions, newest last
static var music_now := ""
static var _pool: Array = []   # AudioStreamPlayer nodes, round-robin
static var _next := 0

const STREAMS := {
	"swing": "res://assets/audio/swing.wav",
	"hit": "res://assets/audio/hit.wav",
	"block": "res://assets/audio/block.wav",
	"parry": "res://assets/audio/parry.wav",
	"death": "res://assets/audio/death.wav",
	"rest": "res://assets/audio/rest.wav",
}

static func bind_pool(players: Array) -> void:
	_pool = players

static func sfx(id: String) -> void:
	sfx_log.append(id)
	if sfx_log.size() > 100:
		sfx_log.pop_front()
	Sim.log_event("AUDIO sfx:%s" % id)
	if not STREAMS.has(id) or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	if p.stream == null:
		p.stream = load(STREAMS[id])
	p.play()

static func music(id: String) -> void:
	if music_now == id:
		return
	music_now = id
	Sim.log_event("AUDIO music:%s (hook, no assets)" % id)
