extends CanvasLayer
## Game shell scaffolding (round 4): title / pause / death / inventory /
## equipment menu machinery. Navigation, selection, and action hooks are real;
## layout, art, wording, and every rule are OPEN decisions. Bindings are
## provisional scaffolding (ui_* defaults + I inventory + O equipment).

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")
const Moveset = preload("res://src/combat/moveset.gd")

var state := "hidden"          # hidden | title | pause | death | inventory | equipment
var menu_items: Array = []     # each: {"label": String, "action": Callable}
var sel := 0
var player = null
var settings = null   # Settings registry (game.gd injects)
var map_data = null   # MapData registry (game.gd injects)
var dialogue = null   # active Dialogue engine while state == "dialogue"
var checkpoint_ctx: Dictionary = {}   # game.gd injects {progression, effigies} for the checkpoint menu
var _death_menu: RichTextLabel = null
var on_respawn: Callable = Callable()   # game.gd hooks
var on_begin: Callable = Callable()
var on_quit_to_title: Callable = Callable()
var label: RichTextLabel
var dimmer: ColorRect
var panel: Panel

# --- Iteration 3 presentation (overnight, 2026-09-19) -----------------------
# [overnight proposals - awaiting Omer review] Genre-reference feel: dark
# dimmer over the world, a panel the menu lives in, a highlighted selection
# row, quiet footer hints. Machinery (items/actions/nav) unchanged.
const COL_TEXT := "#d8dce6"
const COL_DIM := "#8a93a6"
const COL_SEL_BG := "#31435f"
const COL_ACCENT := "#c9a86a"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	dimmer = ColorRect.new()
	dimmer.color = Color(0.02, 0.03, 0.06, 0.62)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	sb.border_color = Color(0.35, 0.42, 0.55, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(330, 84)
	panel.size = Vector2(620, 552)
	add_child(panel)
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.position = Vector2(28, 18)
	label.size = Vector2(564, 516)
	label.add_theme_font_size_override("normal_font_size", 24)
	panel.add_child(label)
	_death_menu = RichTextLabel.new()
	_death_menu.bbcode_enabled = true
	_death_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_menu.visible = false
	add_child(_death_menu)
	visible = false

func open(kind: String, pause_tree := true) -> void:
	state = kind
	sel = 0
	_build_menu()
	visible = true
	if pause_tree and get_tree() != null:
		get_tree().paused = true

func close() -> void:
	state = "hidden"
	visible = false
	if get_tree() != null:
		get_tree().paused = false

func nav(d: int) -> void:
	if menu_items.is_empty():
		return
	sel = (sel + d + menu_items.size()) % menu_items.size()
	_render()

func activate() -> void:
	if menu_items.is_empty():
		return
	menu_items[sel].action.call()
	_render()

func _build_menu() -> void:
	menu_items.clear()
	match state:
		"title":
			_add("BEGIN", func(): if on_begin.is_valid(): on_begin.call())
			_add("QUIT (hook only)", func(): Sim.log_event("SHELL QUIT hook"))
		"pause":
			_add("RESUME", func(): close())
			_add("SETTINGS", func(): open("settings"))
			_add("QUIT TO TITLE (hook)", func(): if on_quit_to_title.is_valid(): on_quit_to_title.call())
		"settings":
			if settings != null:
				for id in settings.order:
					var sid: String = id
					_add(settings.label_for(sid), func(): settings.adjust(sid, 1); _build_menu())
			_add("BACK", func(): open("pause"))
		"map":
			if map_data != null:
				for rid in map_data.regions.keys():
					var mark := " (here)" if rid == map_data.current else (" (visited)" if map_data.is_visited(rid) else "")
					_add("%s%s" % [rid, mark], func(): pass)
			_add("CLOSE", func(): close())
		"dialogue":
			if dialogue != null and not dialogue.ended:
				for i in dialogue.choices().size():
					var ci: int = i
					_add(dialogue.choices()[ci].get("label", "..."), func(): dialogue.choose(ci); _build_menu())
			if dialogue == null or dialogue.ended or dialogue.choices().is_empty():
				_add("LEAVE", func(): close())
		"gestures":
			if player != null:
				for gid in player.gestures.order:
					var g: String = gid
					_add(g, func(): player.gestures.perform(g, player))
			_add("CLOSE", func(): close())
		"death":
			_add("RISE AT THE LAST CHECKPOINT", func(): if on_respawn.is_valid(): on_respawn.call())
		"checkpoint":
			# [overnight proposals - awaiting Omer review] rest effects + first feather spends; prices are SCAFFOLD
			_add("REST - wounds close, heals refill, the fallen rise again", func(): _rest_at_checkpoint())
			_add("HARDEN +10 max hp - 20 feathers (scaffold price)", func(): _buy_upgrade("harden", 20.0))
			_add("MEND +1 heal charge - 30 feathers (scaffold price)", func(): _buy_upgrade("mend", 30.0))
			_add("LEAVE", func(): close())
		"inventory":
			if player != null:
				for i in player.inventory.slots.size():
					var it: Dictionary = player.inventory.slots[i]
					var slot: int = i
					_add("%s x%d - %s" % [it.id, it.qty, player.inventory.describe(it.id)], func(): _use_item(slot))
			_add("CLOSE", func(): close())
		"equipment":
			for w in Moveset.catalog():
				var wid: String = w.id
				var mark := "*" if player.equipment.equipped_id("weapon") == wid else " "
				var l0: Dictionary = w.light_chain[0]
				var chain_total := 0.0
				for a in w.light_chain:
					chain_total += a.damage
				_add("%s %s - %s · %d-hit %d dmg · reach %.1f · stamina x%.1f" % [mark, wid, w.get("desc", "an unwritten weapon (scaffold)"), w.light_chain.size(), int(chain_total), l0.reach, w.get("cost_mult", 1.0)], func(): player.equipment.equip("weapon", w, player); Sim.stat("equip", {"weapon": wid}); _build_menu())
			_add("CLOSE", func(): close())
	_render()

func _use_item(slot: int) -> void:
	close()
	if player != null:
		player._try_use_item(slot)   # [overnight fix] the row you picked is the item you use

func _rest_at_checkpoint() -> void:
	# genre shape: resting refills you AND brings the world back - the cost of comfort is the fight resetting
	if player != null:
		player.hp = player.max_hp
		player.stamina = T.STAMINA_MAX
		player.heal_charges = player.max_heal_charges
	var risen := 0
	for e in checkpoint_ctx.get("effigies", []):
		if e.dead:
			e.reset_run(e.spawn_pos)
			risen += 1
	Sim.log_event("RESTED - wounds close, heals refill, %d rise again" % risen)
	Sim.toast("Rested - heals refilled; %d rise again" % risen)
	close()

func _buy_upgrade(what: String, price: float) -> void:
	var prog = checkpoint_ctx.get("progression")
	if prog == null or player == null:
		return
	if not prog.spend({"feathers": price}, player):
		Sim.toast("Not enough feathers")
		_build_menu()
		return
	# spending feathers on power means not wearing them as coat/resist - the tension is the design
	if what == "harden":
		player.max_hp += 10.0
		player.hp += 10.0
	elif what == "mend":
		player.max_heal_charges += 1
		player.heal_charges += 1
	prog.apply_upgrade(what, player)
	Sim.toast("%s - yours (%d feathers left)" % [what.to_upper(), int(player.feathers)])
	_build_menu()

func _add(lbl: String, fn: Callable) -> void:
	menu_items.append({"label": lbl, "action": fn})

func _render() -> void:
	if label == null:
		return
	# death fills the screen; every other kind is a panel over a dimmed world
	var is_death := state == "death"
	dimmer.color = Color(0.02, 0.02, 0.04, 0.85) if is_death else Color(0.02, 0.03, 0.06, 0.62)
	panel.visible = not is_death
	_death_menu.visible = is_death
	if is_death:
		_render_death()
		return
	var txt := ""
	if state == "title":
		txt += "[center][font_size=64][b][color=%s]FEATHER[/color][/b][/font_size][/center]\n" % COL_ACCENT
		txt += "[center][color=%s][font_size=16]a phase 0a greybox[/font_size][/color][/center]\n\n" % COL_DIM
	else:
		txt += "[color=%s][font_size=30][b]%s[/b][/font_size][/color]\n" % [COL_ACCENT, _kind_title()]
		txt += "[color=%s][font_size=13]%s[/font_size][/color]\n\n" % [COL_DIM, _kind_subtitle()]
	for i in menu_items.size():
		if i == sel:
			txt += "[bgcolor=%s][color=#ffffff]> %s[/color][/bgcolor]\n" % [COL_SEL_BG, menu_items[i].label]
		else:
			txt += "[color=%s]  %s[/color]\n" % [COL_TEXT, menu_items[i].label]
	txt += "\n[color=%s][font_size=14]%s[/font_size][/color]" % [COL_DIM, _footer_hint()]
	label.text = txt

func _render_death() -> void:
	# full-screen takeover; the genre's most important screen [overnight feel]
	var txt := "\n\n[center][font_size=72][b][color=#a03028]YOU DIED[/color][/b][/font_size][/center]\n\n"
	for i in menu_items.size():
		if i == sel:
			txt += "[center][bgcolor=%s][color=#ffffff][font_size=24]> %s[/font_size][/color][/bgcolor][/center]\n" % [COL_SEL_BG, menu_items[i].label]
		else:
			txt += "[center][color=%s][font_size=24]  %s[/font_size][/color][/center]\n" % [COL_TEXT, menu_items[i].label]
	txt += "\n[center][color=%s][font_size=14]%s[/font_size][/color]" % [COL_DIM, _footer_hint()]
	_death_menu.text = txt

func _kind_title() -> String:
	if state == "dialogue" and dialogue != null and not dialogue.ended:
		return dialogue.node().get("text", "...")
	return state.to_upper()

func _kind_subtitle() -> String:
	match state:
		"pause": return "the world waits"
		"inventory": return "what you carry is all you have"
		"equipment": return "a weapon is a choice of risks - carrying %s" % (player.equipment.equipped_id("weapon") if player != null else "?")
		"settings": return "scaffold entries - more land with the real game"
		"map": return "where your feet have been"
		"gestures": return "say it with the body"
		"checkpoint": return "a breath before the road again"
	return ""

func _footer_hint() -> String:
	match state:
		"title": return "enter - begin"
		"death": return "enter - rise"
		"dialogue": return "enter - choose"
	return "arrows - choose · enter - confirm · esc - back"

func _unhandled_input(event: InputEvent) -> void:
	if state == "hidden":
		return
	if event.is_action_pressed("ui_down"):
		nav(1)
	elif event.is_action_pressed("ui_up"):
		nav(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate()
	elif event.is_action_pressed("ui_cancel") and state in ["pause", "inventory", "equipment", "checkpoint"]:
		close()
