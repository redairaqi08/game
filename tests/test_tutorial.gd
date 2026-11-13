extends SceneTree
## Integration regression: uses the real match, actors, perception and devices.
## Stages are selected programmatically; this is not a claim of human usability.
var game
var director
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS tutorial · ", label)
	else:
		failures += 1
		push_error("FAIL tutorial · " + label)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func select_stage(index: int) -> void:
	game.ui.tutorial_step = index
	game.tutorial_step = index
	await frames(12)

func valid_placement(kind: String) -> Dictionary:
	for direction: Vector3 in [Vector3(0,-0.35,-1),Vector3(1,-0.35,0),Vector3(-1,-0.35,0),Vector3(0,-0.35,1)]:
		game.human.aim_direction = direction.normalized()
		var placement: Dictionary = game.gadgets.placement_for(game.human, kind)
		if bool(placement.get("valid", false)):
			return placement
	return {}

func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_match({"mode":"tutorial", "team_size":1, "difficulty":0, "initial_role":"attack", "primary_gadget":"decoy", "secondary_gadget":"thorn"})
	await frames(24)
	director = game.tutorial_director
	expect("director created only in guided tutorial", is_instance_valid(director))
	if not is_instance_valid(director):
		quit(1)
		return
	# Freeze the human controller rather than injecting desktop mouse input.
	# The physical body stays present for real occlusion, hits and triggers.
	game.human.set_physics_process(false)
	game.ui.set_process(false)
	var target = director.target
	for stage_index in range(5):
		await select_stage(stage_index)
		expect("stage %d positions a living, reachable target" % stage_index, target.alive and game.navigation.is_walkable(target.global_position))
	var shooting_contact: Dictionary = game.acoustics.contact_for(game.human,target.actor_id)
	expect("shooting exercise acoustically reconstructs its target", int(shooting_contact.get("state",0))>=3)
	expect("guided target never fires", int(target.stats.shots) == 0)
	expect("human remains unharmed in all first exercises", is_equal_approx(float(game.human.health),100.0))

	await select_stage(3)
	game.human.ping_cooldown = 0.0
	expect("ping triggers against stationary tutorial target", game.acoustics.ping(game.human))
	await frames(42)
	var contact: Dictionary = game.acoustics.contact_for(game.human, target.actor_id)
	expect("stationary training target receives a real acoustic contact", not contact.is_empty() and int(contact.get("state",0)) >= 3)
	target.take_damage(1000.0,game.human)
	expect("training target survives at 25 HP", target.alive and is_equal_approx(float(target.health),25.0))
	expect("training target damage cannot create a kill or objective score", int(game.human.stats.kills)==0 and int(game.scores[0])==0 and int(game.scores[1])==0)

	await select_stage(5)
	var decoy_placement: Dictionary = valid_placement("decoy")
	expect("real decoy has a valid tutorial placement", not decoy_placement.is_empty())
	if not decoy_placement.is_empty():
		expect("decoy deployment consumes actual slot", game.gadgets.deploy(game.human,0))
		# Place the harmless trainer near the emitter in a reproducible exercise.
		# It must still learn the false trajectory through its acoustic records.
		director._place_target(game.navigation.nearest_walkable(Vector3(decoy_placement.position)+Vector3(3,0,0)))
		var start: Vector3 = target.global_position
		await frames(145)
		expect("trainer investigates a perceived false sound", director._decoy_wait_started >= 0.0)
		expect("false signal causes actual target movement", target.global_position.distance_to(start)>0.5)

	await select_stage(6)
	var thorn_placement: Dictionary = valid_placement("thorn")
	expect("real thorn has a valid tutorial placement", not thorn_placement.is_empty())
	if not thorn_placement.is_empty():
		expect("thorn deployment consumes actual secondary slot", game.gadgets.deploy(game.human,1))
		var triggered: bool = false
		for frame_index in range(420):
			await physics_frame
			for event in game.acoustics.event_log:
				if str(event.get("category",""))=="trap":
					triggered = true
			if triggered:
				break
		expect("director walks the target into a real triggered trap", triggered)

	await select_stage(7)
	expect("extraction exercise exposes a depth-tested guide", is_instance_valid(director._extraction_label) and director._extraction_label.visible and not director._extraction_label.no_depth_test)
	var gate: Dictionary = game.active_exits()[0]
	game.human.global_position = gate.position + Vector3.UP * 0.01
	# Drive the same actor with bot-style commands to hold E reproducibly.
	game.human.is_human = false
	game.human.set_physics_process(true)
	game.human.apply_command({"interact":true})
	for frame_index in range(420):
		await physics_frame
		if game.human.extracted:
			break
	expect("guided extraction uses normal match rules", game.human.extracted and int(game.scores[0])==100)
	expect("tutorial completion persists in local profile state", bool(game.profile.tutorial_complete))
	expect("training bot never fired during entire scenario", int(target.stats.shots)==0)
	game.return_to_menu()
	await frames(3)
	expect("return to menu removes director and training entities", game.tutorial_director==null and game.actors.is_empty())
	print("TUTORIAL_TEST_RESULT ",checks-failures,"/",checks," passed")
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
