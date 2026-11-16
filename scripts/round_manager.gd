extends Node
## Runs a fight. In a match: spawns the AI opponent, plays best-of-3 rounds with
## a clock, awards skill points and shows the results. In training: spawns the
## dummy, unlocks every move and lets 1-4 switch element, with no clock.

signal round_started(number: int)
signal round_ended(player_won: bool)
signal match_ended(player_won: bool)

const OPPONENT_SCENE := preload("res://scenes/opponent.tscn")
const DUMMY_SCENE := preload("res://scenes/training_dummy.tscn")

@export var player: PlayerBender
@export var hud: CanvasLayer
@export var player_spawn: Marker3D
@export var opponent_spawn: Marker3D

## The AiBender in a match, the training dummy in training.
var opponent
var training := false
var round_number := 0
var wins := 0
var losses := 0
var time_left := 0.0
var round_seconds := 90.0
var rounds_to_win := 2
var intermission := 2.5
var _live := false
var _over := false


func _ready() -> void:
	training = Game.mode == "training"
	round_seconds = float(Balance.get_value("round.seconds", round_seconds))
	rounds_to_win = int(Balance.get_value("round.rounds_to_win", rounds_to_win))
	intermission = float(Balance.get_value("round.intermission", intermission))

	player.set_spawn(player_spawn.global_transform)
	player.apply_element(Game.player_element, Game.player_loadout(Game.player_element, training))
	player.allow_element_switch = training
	if Game.autopilot:
		player.brain = AiBrain.new(player, "hard")

	if training:
		opponent = DUMMY_SCENE.instantiate()
		opponent.position = opponent_spawn.position + Vector3(0, 0, 4)
		player.get_parent().add_child.call_deferred(opponent)
		await opponent.ready
		opponent.broken.connect(_on_dummy_broken)
	else:
		opponent = OPPONENT_SCENE.instantiate()
		player.get_parent().add_child.call_deferred(opponent)
		await opponent.ready
		opponent.set_spawn(opponent_spawn.global_transform)
		opponent.configure(Game.resolve_opponent_element(), Game.difficulty, player)
		opponent.health.died.connect(_end_round.bind(true))
		player.health.died.connect(_end_round.bind(false))

	player.target = opponent
	if player.brain != null:
		player.brain.target = opponent
	hud.bind(player, opponent, training)
	if training:
		hud.set_round_info("Training: every move unlocked, no clock")
		hud.show_banner("Training", 1.5)
	else:
		start_round()


func _process(delta: float) -> void:
	if not _live:
		return
	time_left -= delta
	_update_round_label()
	if time_left <= 0.0:
		# Time up: whoever has more of their HP left takes the round.
		var mine: float = player.health.ratio()
		var theirs: float = opponent.health.ratio()
		if is_equal_approx(mine, theirs):
			_draw_round()
		else:
			_end_round(mine > theirs)


func start_round() -> void:
	round_number += 1
	_clear_arena()
	player.reset_for_round()
	opponent.reset_for_round()
	player.frozen = true
	opponent.frozen = true
	time_left = round_seconds
	_update_round_label()
	hud.show_banner("Round %d" % round_number, 1.2)
	await get_tree().create_timer(1.2, false).timeout
	if _over or not is_inside_tree():
		return
	hud.show_banner("Bend!", 0.6)
	player.frozen = false
	opponent.frozen = false
	_live = true
	round_started.emit(round_number)


func _end_round(player_won: bool) -> void:
	if not _live:
		return
	_live = false
	player.frozen = true
	opponent.frozen = true
	if player_won:
		wins += 1
	else:
		losses += 1
	round_ended.emit(player_won)
	_update_round_label()
	if wins >= rounds_to_win or losses >= rounds_to_win:
		_finish_match(wins > losses)
		return
	hud.show_banner("Round won" if player_won else "Round lost", intermission)
	await get_tree().create_timer(intermission, false).timeout
	if is_inside_tree():
		start_round()


func _draw_round() -> void:
	_live = false
	round_number -= 1
	hud.show_banner("Draw: replay the round", intermission)
	await get_tree().create_timer(intermission, false).timeout
	if is_inside_tree():
		start_round()


func _finish_match(player_won: bool) -> void:
	_over = true
	var earned := Game.record_match(wins, player_won)
	match_ended.emit(player_won)
	var lines := PackedStringArray([
		"You %d - %d %s" % [wins, losses, opponent.get("display_name")],
		"+%d skill point%s (you have %d)" % [earned, "" if earned == 1 else "s", Game.skill_points],
	])
	hud.show_results("Victory!" if player_won else "Defeat", lines, [
		["Rematch", rematch],
		["Skill Trees", func() -> void: _change_scene("res://scenes/skill_tree.tscn")],
		["Main Menu", func() -> void: _change_scene("res://scenes/menu.tscn")],
	])


func rematch() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _update_round_label() -> void:
	hud.set_round_info("Round %d   You %d - %d Them   %d s" % [
		maxi(round_number, 1), wins, losses, ceili(maxf(time_left, 0.0))])


func _clear_arena() -> void:
	for group in ["projectiles", "spawned"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()


func _on_dummy_broken() -> void:
	hud.show_banner("Dummy broken!", 1.0)
	await get_tree().create_timer(1.0, false).timeout
	if is_inside_tree():
		opponent.reset_for_round()
