extends SceneTree
## Integration regressions against the complete scene, real actor and level.
var game
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await frames()
	game.settings["preparation_seconds"] = 0.0
	check(game.phase == "menu", "full application opens its main menu")
	check(game.level.exits.size() == 3, "main menu sanctuary initialized")
	for size in [1, 2, 3]:
		game.start_match({"team_size": size, "mode": "attack", "difficulty": 1})
		game.bots.clear()
		await frames()
		check(game.actors.size() == size * 2, "%dv%d creates both complete teams" % [size, size])
		check(game.human != null and game.human.team == 0, "exactly one local human")
		check(game.scores == [0, 0], "new match resets scores")
		check(game.active_exits().size() == (2 if size == 1 else 3), "mode has adapted exits")
		game.set_paused(true)
		var before: float = game.time_left
		await frames()
		check(is_equal_approx(before, game.time_left), "pause freezes authoritative match time")
		game.set_paused(false)
	# Preparation freezes combat and match clock without freezing the interface.
	game.start_match({"team_size": 1, "mode": "attack", "preparation_seconds": 0.4})
	game.bots.clear()
	var preparation_clock: float = game.time_left
	var preparation_actor = game.actors[1]
	preparation_actor.apply_command({"move": Vector3.FORWARD, "fire": true})
	await frames(4)
	check(game.preparation_left > 0.0, "preparation countdown starts before combat")
	check(is_equal_approx(game.time_left, preparation_clock), "preparation does not consume match time")
	check(preparation_actor.stats.shots == 0 and preparation_actor.velocity == Vector3.ZERO, "preparation locks movement and fire")
	await frames(30)
	check(game.preparation_left <= 0.0 and game.elapsed > 0.0, "combat starts after preparation")
	game.settings["preparation_seconds"] = 0.0
	# Three simultaneous attackers use independent progress, and a dead one cannot extract.
	game.start_match({"team_size": 3, "mode": "attack"})
	game.bots.clear()
	var attackers: Array = []
	var defenders: Array = []
	for actor in game.actors:
		actor.is_human = false
		actor.apply_command({})
		if actor.team == game.attacker_team:
			attackers.append(actor)
		else:
			defenders.append(actor)
	var gate: Dictionary = game.active_exits()[0]
	for index in range(attackers.size()):
		attackers[index].global_position = Vector3(gate.position) + Vector3(float(index) * 0.8 - 0.8, 0.05, 0.5)
	await frames(12)
	for actor in attackers:
		actor.set_physics_process(false)
		actor.command_interact = true
	game._update_extractions(0.5)
	check(attackers[0].extraction_progress > 0.0, "holding interact starts extraction")
	check(game.extraction_alerts.has(str(gate.id)), "extraction raises reliable public objective alert")
	var progress: float = attackers[0].extraction_progress
	attackers[0].command_interact = false
	game._update_extractions(0.4)
	check(is_equal_approx(attackers[0].extraction_progress, progress), "brief interruption preserves own progression")
	game._update_extractions(1.1)
	check(attackers[0].extraction_progress < progress, "progress decays after interruption grace")
	check(attackers[1].extraction_progress > attackers[0].extraction_progress, "one interruption does not reset teammate")
	attackers[0].command_interact = true
	attackers[2].take_damage(1000.0, defenders[0])
	game._update_extractions(float(gate.duration) + 0.1)
	check(attackers[0].extracted and attackers[1].extracted, "two surviving attackers independently finish same exit")
	check(not attackers[2].extracted, "dead attacker never extracts")
	check(attackers[0].collision_layer == 0, "extracted attacker leaves physical combat")
	check(game.scores == [200, 100], "objective scoring200 extracted vs100 stopped")
	game._finish_round("test")
	game._finish_round("test duplicate")
	check(game.scores == [200, 100], "resolution never awards points twice")
	check(game.phase == "finished", "single attack session has a final result")
	# Four-round role balance and fresh transient services.
	game.start_match({"team_size": 2, "mode": "standard", "rounds": 4, "initial_role": "attack"})
	game.bots.clear()
	for index in range(4):
		check(game.attacker_team == index % 2, "roles alternate at round%d" % (index + 1))
		for actor in game.actors:
			actor.ping_cooldown = 7.0
		game._finish_round("test timeout")
		if index < 3:
			game.next_round()
			game.bots.clear()
			check(game.acoustics.memories.is_empty(), "new round clears every contact")
			check(game.extraction_alerts.is_empty(), "new round clears extraction alerts")
			check(game.actors[0].ping_cooldown == 0.0, "new round restores abilities")
	check(game.phase == "finished", "standard match finishes after configured round count")
	check(game.scores == [400, 400], "balanced defended rounds total exactly800 points")
	check(game.round_statistics.size() == 4, "all round records retained")
	game.return_to_menu()
	await frames()
	check(game.actors.is_empty() and game.bots.is_empty(), "return to menu removes combat actors and brains")
	check(game.phase == "menu" and not paused, "return to menu unpauses cleanly")
	print("MATCH_TESTS: ", checks, " checks, ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
