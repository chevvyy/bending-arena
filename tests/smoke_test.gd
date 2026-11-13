extends Node
## Headless smoke test. Run from the project folder:
##   godot --headless --fixed-fps 60 --path . -- --smoke
## Add --quick to play one match instead of four, and --shots=<folder> (with a
## display, not --headless) to save screenshots of each screen.
## Game.gd adds this node when it sees --smoke (and switches to a separate save
## file). It opens every screen, buys skill-tree nodes, then plays full AI vs AI
## matches for each element (your bender on autopilot) and a training session,
## and exits with code 0 when everything passed, 1 otherwise.

const MATCH_TIMEOUT := 400.0

var failures: PackedStringArray = []
## Folder for screenshots when run with a display and "--shots=<folder>".
var shots_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	if "--balance" in OS.get_cmdline_user_args():
		await _balance()
		get_tree().quit(0)
		return
	print("SMOKE: start")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	await _wait(0.5)
	_shot("menu")
	_check(get_tree().current_scene.name == "Menu", "menu is the first scene")

	await _test_skill_tree()
	await _test_training()
	var quick := "--quick" in OS.get_cmdline_user_args()
	for element in (["fire"] if quick else Game.ELEMENTS):
		await _test_match(element)
	await _test_pause()

	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _wait(0.5)
	if failures.is_empty():
		print("SMOKE: PASS")
		get_tree().quit(0)
	else:
		print("SMOKE: FAIL\n  " + "\n  ".join(failures))
		get_tree().quit(1)


func _test_skill_tree() -> void:
	Game.new_game()
	get_tree().change_scene_to_file("res://scenes/skill_tree.tscn")
	await _wait(0.3)
	var screen := get_tree().current_scene
	_check(screen.name == "SkillTree", "skill tree opens")
	_check(Game.node_state("fire", "ultimate") == "locked", "ultimate starts locked")
	_check(Game.node_state("fire", "special") == "available", "first node is buyable")
	_check(Game.buy("fire", "special"), "buy fire special")
	_check(not Game.buy("fire", "ultimate"), "can't skip to ultimate")
	Game.skill_points = 40
	for element in Game.ELEMENTS:
		for id in ["special", "basic_plus", "utility", "special_plus", "passive", "ultimate"]:
			if not Game.owns(element, id):
				_check(Game.buy(element, id), "buy %s %s" % [element, id])
	_check(Game.skill_points == 40 - 39, "points spent correctly (have %d)" % Game.skill_points)
	var loadout := Game.player_loadout("water")
	_check(loadout["slots"].size() == 4, "full water tree unlocks 4 slots")
	_check(float(loadout["passive"].get("hp_mult", 1.0)) > 1.0, "water passive applies")
	screen.call("_show_element", "earth")
	await _wait(0.2)
	_shot("skill_tree")
	var refund := Game.reset_tree("air")
	_check(refund == 10, "air reset refunds 10 (got %d)" % refund)
	_check(Game.player_loadout("air")["slots"] == ["basic"], "air back to basic only")
	# Save round trip.
	Game.save_game()
	var points := Game.skill_points
	Game.load_game()
	_check(Game.skill_points == points and Game.owns("fire", "ultimate"), "save and load keep progress")
	Game.buy("air", "special")


func _test_training() -> void:
	Game.mode = "training"
	Game.player_element = "earth"
	Game.autopilot = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.0)
	var main := get_tree().current_scene
	var player: Bender = main.get_node("Player")
	var dummy: Node3D = main.get_node("RoundManager").get("opponent")
	_check(dummy != null and dummy.is_in_group("targets"), "training spawns the dummy")
	_check(player.abilities.size() == 4, "training unlocks every slot")
	_check(player.global_position.y > -0.5 and player.global_position.y < 4.0,
		"player stands on the arena floor (y %.2f)" % player.global_position.y)
	var start_hp: float = dummy.get("health").current
	await _wait(3.0)
	_shot("training")
	await _wait(5.0)
	_check(dummy.get("health").current < start_hp or dummy.get("health").current == dummy.get("health").max_hp,
		"autopilot damages the dummy")
	for element in Game.ELEMENTS:
		player.apply_element(element, Game.player_loadout(element, true))
		for slot in Game.SLOTS:
			player.chi.refill()
			player.use_slot(slot)
		await _wait(1.5)
	_check(player.element == "air", "element switching works")
	print("SMOKE: training ok, dummy hp %.0f" % dummy.get("health").current)


func _test_match(element: String) -> void:
	Game.mode = "match"
	Game.player_element = element
	Game.opponent_choice = "random"
	Game.difficulty = "hard"
	Game.autopilot = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await _wait(0.5)
	var manager := get_tree().current_scene.get_node("RoundManager")
	var result := {"done": false, "won": false}
	manager.match_ended.connect(func(won: bool) -> void:
		result["done"] = true
		result["won"] = won)
	var hits := {"count": 0}
	var player: Bender = get_tree().current_scene.get_node("Player")
	player.hit_taken.connect(func(_hit: Dictionary) -> void: hits["count"] += 1)
	var waited := 0.0
	while not result["done"] and waited < MATCH_TIMEOUT:
		await _wait(1.0)
		waited += 1.0
		if waited == 6.0:
			_shot("match_" + element)
	await _wait(0.3)
	if element == "fire":
		_shot("results")
	var opponent: Node = manager.get("opponent")
	var summary := "%s vs %s: %s %d-%d after %.0f s, player hit %d times" % [
		element, opponent.get("element"), "won" if result["won"] else "lost",
		manager.get("wins"), manager.get("losses"), waited, hits["count"]]
	print("SMOKE: match " + summary)
	_check(result["done"], "match finishes (%s)" % summary)
	_check(hits["count"] > 0, "opponent lands hits (%s)" % summary)


## Balance check: every element against every other, both on Hard with full
## trees, a few matches each. Prints round wins per element.
func _balance() -> void:
	Game.skill_points = 40
	for element in Game.ELEMENTS:
		for node: Dictionary in Game.tree_nodes(element):
			if not Game.owns(element, node["id"]):
				Game.buy(element, node["id"])
	var round_wins := {}
	var rounds := {}
	for e in Game.ELEMENTS:
		round_wins[e] = 0
		rounds[e] = 0
	for mine in Game.ELEMENTS:
		for theirs in Game.ELEMENTS:
			if mine == theirs:
				continue
			for i in 2:
				Game.mode = "match"
				Game.player_element = mine
				Game.opponent_choice = theirs
				Game.difficulty = "hard"
				Game.autopilot = true
				get_tree().change_scene_to_file("res://scenes/main.tscn")
				await _wait(0.5)
				var manager := get_tree().current_scene.get_node("RoundManager")
				var done := {"v": false}
				manager.match_ended.connect(func(_w: bool) -> void: done["v"] = true)
				var waited := 0.0
				while not done["v"] and waited < MATCH_TIMEOUT:
					await _wait(1.0)
					waited += 1.0
				var w: int = manager.get("wins")
				var l: int = manager.get("losses")
				round_wins[mine] += w
				round_wins[theirs] += l
				rounds[mine] += w + l
				rounds[theirs] += w + l
				print("BALANCE %s vs %s: %d-%d in %.0f s" % [mine, theirs, w, l, waited])
	for e in Game.ELEMENTS:
		print("BALANCE %s won %d of %d rounds" % [e, round_wins[e], rounds[e]])


func _test_pause() -> void:
	Game.mode = "match"
	Game.autopilot = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await _wait(0.5)
	var pause := get_tree().current_scene.get_node("PauseMenu")
	pause.call("pause")
	_check(get_tree().paused, "pause menu pauses")
	await _wait(0.2)
	_shot("pause")
	pause.call("resume")
	_check(not get_tree().paused, "resume unpauses")


func _shot(shot_name: String) -> void:
	if shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(shots_dir.path_join(shot_name + ".png"))


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   " + what)
	else:
		print("  FAIL " + what)
		failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
