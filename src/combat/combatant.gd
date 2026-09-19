extends CharacterBody3D
## Greybox combatant: hp, hurt profile, stagger, hit flash. No art, all signal.

signal took_hit(amount: float, from_pos: Vector3)
signal died

const Sim = preload("res://src/combat/combat_sim.gd")
const HitSpark = preload("res://src/fx/hit_spark.gd")
const Audio = preload("res://src/combat/audio_bus.gd")

var display_name := "COMBATANT"
var team := "neutral"
var hp := 100.0
var max_hp := 100.0
var hurt_radius := 0.55
var dead := false
var stagger_t := 0.0
var hit_flash_t := 0.0
var since_hit := 99.0
var crit_open_t := 0.0  # riposte machinery: >0 means hits on this combatant crit
const StatusSystem = preload("res://src/combat/status_effects.gd")
var statuses = StatusSystem.new()  # status scaffolding: build-up/trigger/tick/expiry
var visual: MeshInstance3D
var base_color := Color.WHITE

const HIT_RESULT_MISS := 0
const HIT_RESULT_HIT := 1
const HIT_RESULT_DODGED := 2
const HIT_RESULT_BLOCKED := 3
const HIT_RESULT_PARRIED := 4

func is_invulnerable() -> bool:
	return false

func damage_after_defense(damage: float) -> float:
	return damage

func apply_hit(damage: float, from_pos: Vector3, stagger: float, flags := {}) -> int:
	if dead:
		return HIT_RESULT_MISS
	if is_invulnerable():
		return HIT_RESULT_DODGED
	var final := damage_after_defense(damage)
	hp = maxf(0.0, hp - final)
	hit_flash_t = 0.12
	# Juice pass (Omer directive 2026-09-19): spark burst at the contact point.
	# [overnight proposal - awaiting Omer review] warm by default; the block
	# path passes the cold guard color so a held guard never reads as a wound.
	var spark_col: Color = flags.get("spark_color", Color(1.0, 0.72, 0.32))
	var toward: Vector3 = global_position - from_pos
	toward.y = 0.0
	toward = toward.normalized() * hurt_radius * 0.8 if toward.length_squared() > 0.0001 else Vector3.ZERO
	HitSpark.burst(get_parent(), global_position + Vector3(0, 1.0, 0) + toward, spark_col)
	Audio.sfx("hit")
	since_hit = 0.0
	stagger_t = maxf(stagger_t, stagger)
	took_hit.emit(final, from_pos)
	if hp <= 0.0:
		dead = true
		died.emit()
	return HIT_RESULT_HIT

func tick_common(dt: float) -> void:
	stagger_t = maxf(0.0, stagger_t - dt)
	crit_open_t = maxf(0.0, crit_open_t - dt)
	statuses.tick(dt, display_name)
	hit_flash_t = maxf(0.0, hit_flash_t - dt)
	since_hit += dt
	_update_flash()

func _update_flash() -> void:
	if visual == null:
		return
	var mat := visual.material_override as StandardMaterial3D
	if mat == null:
		return
	if dead:
		mat.albedo_color = base_color.darkened(0.75)
	elif hit_flash_t > 0.0:
		mat.albedo_color = Color(1.0, 0.28, 0.22)
	else:
		mat.albedo_color = base_color
