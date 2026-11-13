extends Node
## Autoload "Game": what the player picked in the menu, skill points and
## skill-tree unlocks, and saving all of it to user://save.json.

signal points_changed(points: int)
signal tree_changed(element: String)

const ELEMENTS: Array[String] = ["fire", "water", "earth", "air"]
const SLOTS: Array[String] = ["basic", "special", "utility", "ultimate"]
const TREES_PATH := "res://data/skill_trees.json"
const SAVE_PATH := "user://save.json"
const SMOKE_SAVE_PATH := "user://smoke_save.json"

## "match" fights the AI opponent; "training" is the dummy with every move unlocked.
var mode := "match"
var player_element := "fire"
## "random" or an element name.
var opponent_choice := "random"
var difficulty := "normal"
var skill_points := 3
## element -> Array of owned node ids
var unlocked: Dictionary = {}
var matches_played := 0
var matches_won := 0
## Set by the smoke test: the player bender drives itself with the AI brain.
var autopilot := false

var trees: Dictionary = {}
var _save_path := SAVE_PATH


func _ready() -> void:
	randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREES_PATH))
	if parsed is Dictionary:
		trees = parsed
	else:
		push_error("Could not read %s" % TREES_PATH)
	if "--smoke" in OS.get_cmdline_user_args():
		_save_path = SMOKE_SAVE_PATH
		_reset_progress()
		add_child(load("res://tests/smoke_test.gd").new())
	else:
		load_game()


# --- Skill trees ---------------------------------------------------------

func tree_nodes(element: String) -> Array:
	return trees.get(element, [])


func find_node_def(element: String, id: String) -> Dictionary:
	for node: Dictionary in tree_nodes(element):
		if node.get("id", "") == id:
			return node
	return {}


func owns(element: String, id: String) -> bool:
	return id in unlocked.get(element, [])


## "owned", "available" (can buy now), "expensive" (requirements met, not enough
## points) or "locked" (requirements not met).
func node_state(element: String, id: String) -> String:
	if owns(element, id):
		return "owned"
	var node := find_node_def(element, id)
	if node.is_empty() or not _requirements_met(node, unlocked.get(element, [])):
		return "locked"
	if skill_points < int(node.get("cost", 1)):
		return "expensive"
	return "available"


func buy(element: String, id: String) -> bool:
	if node_state(element, id) != "available":
		return false
	var node := find_node_def(element, id)
	skill_points -= int(node.get("cost", 1))
	var owned: Array = unlocked.get(element, [])
	owned.append(id)
	unlocked[element] = owned
	save_game()
	points_changed.emit(skill_points)
	tree_changed.emit(element)
	return true


## Refunds every point spent in one element's tree.
func reset_tree(element: String) -> int:
	var refund := spent_in(element)
	skill_points += refund
	unlocked[element] = []
	save_game()
	points_changed.emit(skill_points)
	tree_changed.emit(element)
	return refund


func spent_in(element: String) -> int:
	var total := 0
	for id: String in unlocked.get(element, []):
		total += int(find_node_def(element, id).get("cost", 0))
	return total


## What a bender of this element can use: unlocked slots, stat mods and passives.
## unlock_all opens every slot (training mode) but keeps upgrades you bought.
func player_loadout(element: String, unlock_all := false) -> Dictionary:
	var ids: Array = unlocked.get(element, []).duplicate()
	var loadout := _loadout_from_ids(element, ids)
	if unlock_all:
		loadout["slots"] = SLOTS.duplicate()
	return loadout


## The AI's tree for a difficulty, from balance.json "ai.<difficulty>.nodes".
func ai_loadout(element: String, level: String) -> Dictionary:
	var wanted: Array = Balance.get_value("ai.%s.nodes" % level, [])
	var ids: Array = []
	for node: Dictionary in tree_nodes(element):
		if "all" in wanted or node.get("id", "") in wanted:
			ids.append(node.get("id", ""))
	return _loadout_from_ids(element, ids)


func _loadout_from_ids(element: String, ids: Array) -> Dictionary:
	var slots: Array = ["basic"]
	var mods: Array = []
	var passive: Dictionary = {}
	for node: Dictionary in tree_nodes(element):
		if not node.get("id", "") in ids:
			continue
		if node.has("unlock"):
			slots.append(node["unlock"])
		for mod: Dictionary in node.get("mods", []):
			mods.append(mod)
		var p: Dictionary = node.get("passive", {})
		for key: String in p:
			if key.ends_with("_mult"):
				passive[key] = float(passive.get(key, 1.0)) * float(p[key])
			else:
				passive[key] = float(passive.get(key, 0.0)) + float(p[key])
	var ordered: Array = []
	for slot in SLOTS:
		if slot in slots:
			ordered.append(slot)
	return {"slots": ordered, "mods": mods, "passive": passive}


func _requirements_met(node: Dictionary, owned: Array) -> bool:
	var reqs: Array = node.get("requires", [])
	if reqs.is_empty():
		return true
	var met := 0
	for id: String in reqs:
		if id in owned:
			met += 1
	if node.get("requires_any", false):
		return met > 0
	return met == reqs.size()


# --- Match flow ----------------------------------------------------------

func resolve_opponent_element() -> String:
	if opponent_choice in ELEMENTS:
		return opponent_choice
	var others: Array = ELEMENTS.filter(func(e: String) -> bool: return e != player_element)
	return others[randi() % others.size()]


## Called by the round manager when a match ends. Returns points earned.
func record_match(round_wins: int, won: bool) -> int:
	var earned := round_wins * int(Balance.get_value("points.round_win", 1))
	if won:
		earned += int(Balance.get_value("points.match_win", 2))
		matches_won += 1
	matches_played += 1
	skill_points += earned
	save_game()
	points_changed.emit(skill_points)
	return earned


# --- Save and load (class stretch goal) ----------------------------------

func save_game() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % _save_path)
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"skill_points": skill_points,
		"unlocked": unlocked,
		"player_element": player_element,
		"opponent_choice": opponent_choice,
		"difficulty": difficulty,
		"matches_played": matches_played,
		"matches_won": matches_won,
	}, "\t"))


func load_game() -> void:
	_reset_progress()
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not parsed is Dictionary:
		push_warning("Save file unreadable, starting fresh")
		return
	var save: Dictionary = parsed
	skill_points = int(save.get("skill_points", skill_points))
	var saved_unlocks: Dictionary = save.get("unlocked", {})
	for element in ELEMENTS:
		var ids: Array = []
		for id: Variant in saved_unlocks.get(element, []):
			if not find_node_def(element, str(id)).is_empty():
				ids.append(str(id))
		unlocked[element] = ids
	var el := str(save.get("player_element", player_element))
	player_element = el if el in ELEMENTS else "fire"
	opponent_choice = str(save.get("opponent_choice", opponent_choice))
	var diff := str(save.get("difficulty", difficulty))
	difficulty = diff if diff in ["easy", "normal", "hard"] else "normal"
	matches_played = int(save.get("matches_played", 0))
	matches_won = int(save.get("matches_won", 0))


## Wipes skill points and unlocks back to a new game (does not save by itself).
func _reset_progress() -> void:
	skill_points = int(Balance.get_value("points.start", 3))
	unlocked = {}
	for element in ELEMENTS:
		unlocked[element] = []
	matches_played = 0
	matches_won = 0


func new_game() -> void:
	_reset_progress()
	save_game()
	points_changed.emit(skill_points)
	for element in ELEMENTS:
		tree_changed.emit(element)
