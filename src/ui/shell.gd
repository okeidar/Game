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
var on_respawn: Callable = Callable()   # game.gd hooks
var on_begin: Callable = Callable()
var on_quit_to_title: Callable = Callable()
var label: RichTextLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.position = Vector2(80, 120)
	label.size = Vector2(700, 500)
	label.add_theme_font_size_override("normal_font_size", 26)
	add_child(label)
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
		"inventory":
			if player != null:
				for i in player.inventory.slots.size():
					var it: Dictionary = player.inventory.slots[i]
					var slot: int = i
					_add("%s x%d" % [it.id, it.qty], func(): _use_item(slot))
			_add("CLOSE", func(): close())
		"equipment":
			_add("weapon: %s" % player.equipment.equipped_id("weapon"), func(): pass)
			for w in Moveset.catalog():
				var wid: String = w.id
				var mark := "*" if player.equipment.equipped_id("weapon") == wid else " "
				_add("%s equip %s (%d-hit chain)" % [mark, wid, w.light_chain.size()], func(): player.equipment.equip("weapon", w, player); Sim.stat("equip", {"weapon": wid}); _build_menu())
			_add("CLOSE", func(): close())
	_render()

func _use_item(slot: int) -> void:
	close()
	if player != null:
		player._try_use_item()   # slot-0 commit machinery; slot routing is OPEN
		Sim.log_event("SHELL used inventory slot %d (routing scaffold)" % slot)

func _add(lbl: String, fn: Callable) -> void:
	menu_items.append({"label": lbl, "action": fn})

func _render() -> void:
	if label == null:
		return
	var title := state.to_upper()
	if state == "death":
		title = "YOU DIED"
	if state == "dialogue" and dialogue != null and not dialogue.ended:
		title = dialogue.node().get("text", "...")
	var txt := "[center][b]%s[/b][/center]\n\n" % title
	for i in menu_items.size():
		var mark := "> " if i == sel else "  "
		txt += "%s%s\n" % [mark, menu_items[i].label]
	label.text = txt

func _unhandled_input(event: InputEvent) -> void:
	if state == "hidden":
		return
	if event.is_action_pressed("ui_down"):
		nav(1)
	elif event.is_action_pressed("ui_up"):
		nav(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate()
	elif event.is_action_pressed("ui_cancel") and state in ["pause", "inventory", "equipment"]:
		close()
