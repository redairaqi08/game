extends Node3D
## Authoritative offline match controller. No rendering service decides match rules.

const ActorScript = preload("res://scripts/actor.gd")
const AcousticScript = preload("res://scripts/acoustics.gd")
const GadgetScript = preload("res://scripts/gadgets.gd")
const LevelScript = preload("res://scripts/level.gd")
const BotScript = preload("res://scripts/bot.gd")
const NavigationScript = preload("res://scripts/navigation.gd")
const UIScript = preload("res://scripts/ui.gd")
const AudioScript = preload("res://scripts/audio.gd")
const TutorialScript = preload("res://scripts/tutorial_director.gd")

var actors: Array = []
var bots: Array = []
var human = null
var level = null
var acoustics = null
var gadgets = null
var audio = null
var ui = null
var navigation = null
var phase: String = "menu"
var settings: Dictionary = {
	"team_size": 3, "difficulty": 1, "rounds": 6, "mode": "standard",
	"initial_role": "attack", "primary_gadget": "decoy", "secondary_gadget": "thorn",
	"mouse_sensitivity": 0.0022, "volume": 0.65, "fov": 85.0,
	"camera_motion": true, "graphics": 1, "layout": "azerty", "preparation_seconds": 8.0,
	"silhouette_contrast": 1.0, "wave_intensity": 1.0, "key_bindings": {},
}
var balance: Dictionary = {}
var profile: Dictionary = {"matches": 0, "extractions": 0, "kills": 0, "tutorial_complete": false}
var preparation_left: float = 0.0
var elapsed: float = 0.0
var time_left: float = 240.0
var round_index: int = 0
var attacker_team: int = 0
var scores: Array = [0, 0]
var extraction_alerts: Dictionary = {}
var tutorial_step: int = 0
var round_statistics: Array = []
var metrics: Dictionary = {}
var developer_mode: bool = false
var tutorial_director = null
var paused: bool = false
var _scored: Dictionary = {}
var _extract_state: Dictionary = {}
var _bot_accumulator: float = 0.0
var _spectator_id: int = -1
var _spectator_camera: Camera3D
var _menu_camera: Camera3D
var _world_environment: WorldEnvironment
var _round_started_at: int = 0
var _round_initial_alive: int = 0
var _pending_auto_round: float = -1.0
var _simulation: bool = false
var _report_path: String = "user://last_simulation.json"
var _seed_value: int = 27013
var _test_duration: float = 0.0
var _minimum_fps: float = 10000.0
var _last_config: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_configuration()
	configure_input()
	_create_environment()
	audio = AudioScript.new()
	add_child(audio)
	audio.setup(self)
	acoustics = AcousticScript.new()
	acoustics.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(acoustics)
	acoustics.setup(self)
	gadgets = GadgetScript.new()
	gadgets.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gadgets)
	gadgets.setup(self)
	_build_level(3)
	ui = UIScript.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.setup(self)
	ui.show_menu()
	_menu_camera.make_current()
	_parse_launch_options()

func _load_configuration() -> void:
	if FileAccess.file_exists("res://config/balance.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://config/balance.json"))
		if parsed is Dictionary:
			balance = parsed
	if FileAccess.file_exists("user://profile.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://profile.json"))
		if data is Dictionary:
			var saved_settings = data.get("settings", {})
			if saved_settings is Dictionary:
				for key in settings:
					if saved_settings.has(key):
						settings[key] = saved_settings[key]
			var saved_profile = data.get("profile", {})
			if saved_profile is Dictionary:
				profile.merge(saved_profile, true)

func save_settings() -> void:
	settings["mouse_sensitivity"] = clampf(float(settings.get("mouse_sensitivity", 0.0022)), 0.0002, 0.02)
	settings["fov"] = clampf(float(settings.get("fov", 85.0)), 65.0, 115.0)
	settings["volume"] = clampf(float(settings.get("volume", 0.65)), 0.0, 1.0)
	configure_input()
	if audio != null:
		audio.set_volume(float(settings["volume"]))
	apply_graphics_settings()
	if is_instance_valid(human) and human.camera != null:
		human.camera.fov = float(settings["fov"])
	if _simulation:
		return
	var file = FileAccess.open("user://profile.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"settings": settings, "profile": profile}, "\t"))

func apply_graphics_settings() -> void:
	var quality: int = clampi(int(settings.get("graphics", 1)), 0, 2)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	if is_instance_valid(_world_environment):
		_world_environment.environment.fog_enabled = quality > 0
	if is_instance_valid(level):
		for light in level.find_children("*", "Light3D", true, false):
			if light is OmniLight3D or light is SpotLight3D:
				light.shadow_enabled = quality >= 2

func configure_input() -> void:
	var azerty: bool = str(settings.get("layout", "azerty")) == "azerty"
	var bindings: Dictionary = {
		"move_forward": KEY_Z if azerty else KEY_W,
		"move_back": KEY_S, "move_left": KEY_Q if azerty else KEY_A,
		"move_right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_CTRL,
		"jump": KEY_SPACE, "reload": KEY_R, "ping": KEY_F,
		"gadget_primary": KEY_G, "gadget_secondary": KEY_T,
		"interact": KEY_E, "weapon_1": KEY_1, "weapon_2": KEY_2,
		"pause": KEY_ESCAPE, "tactical_map": KEY_TAB, "orders": KEY_ALT,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key = InputEventKey.new()
		key.keycode = bindings[action]
		InputMap.action_add_event(action, key)
	var alternate = InputEventKey.new()
	alternate.keycode = KEY_C
	InputMap.action_add_event("crouch", alternate)
	for action in {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mouse)
	# Optional user remapping: physical key codes, saved without requiring an account.
	var overrides: Dictionary = settings.get("key_bindings", {})
	for action in overrides:
		if not InputMap.has_action(action):
			continue
		var key = InputEventKey.new()
		key.physical_keycode = int(overrides[action])
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, key)

func _create_environment() -> void:
	_world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0c171d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8dabc0")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("1d343b")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.0035
	_world_environment.environment = environment
	add_child(_world_environment)
	_menu_camera = Camera3D.new()
	_menu_camera.position = Vector3(18.0, 11.0, 25.0)
	_menu_camera.fov = 66.0
	_menu_camera.far = 220.0
	add_child(_menu_camera)
	_menu_camera.look_at(Vector3(0.0, 3.4, -10.0))
	_spectator_camera = Camera3D.new()
	_spectator_camera.fov = 85.0
	add_child(_spectator_camera)

func _build_level(size: int) -> void:
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = LevelScript.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.build(size)
	navigation = NavigationScript.new()
	navigation.setup(level)
	apply_graphics_settings()

func start_match(options: Dictionary) -> void:
	get_tree().paused = false
	paused = false
	settings.merge(options, true)
	settings["team_size"] = clampi(int(settings.get("team_size", 3)), 1, 3)
	settings["difficulty"] = clampi(int(settings.get("difficulty", 1)), 0, 3)
	var mode: String = str(settings.get("mode", "standard"))
	if mode == "tutorial":
		settings["team_size"] = 1
		settings["initial_role"] = "attack"
		settings["primary_gadget"] = "decoy"
		settings["secondary_gadget"] = "thorn"
	_simulation = mode == "simulation"
	if mode in ["attack", "defend", "training", "tutorial"]:
		settings["rounds"] = 1
	else:
		settings["rounds"] = 4 if int(settings.get("rounds", 6)) <= 4 else 6
	_last_config = settings.duplicate(true)
	seed(_seed_value)
	settings["seed"] = _seed_value
	round_index = 0
	scores = [0, 0]
	round_statistics.clear()
	tutorial_step = 0
	metrics = {"seed": _seed_value, "team_size": settings["team_size"], "difficulty": settings["difficulty"], "rounds": [], "version": "0.1.0"}
	_minimum_fps = 10000.0
	save_settings()
	_build_level(int(settings["team_size"]))
	_begin_round()

func _clear_round() -> void:
	if is_instance_valid(tutorial_director):
		tutorial_director.queue_free()
	tutorial_director = null
	for actor in actors:
		if is_instance_valid(actor):
			actor.set_physics_process(false)
			actor.collision_layer = 0
			remove_child(actor)
			actor.queue_free()
	actors.clear()
	bots.clear()
	human = null
	_spectator_id = -1
	acoustics.clear()
	gadgets.clear()
	extraction_alerts.clear()
	_extract_state.clear()
	_scored.clear()
	for exit in level.exits:
		if level.has_method("set_exit_active"):
			level.set_exit_active(str(exit["id"]), false)

func _begin_round() -> void:
	_clear_round()
	elapsed = 0.0
	attacker_team = round_index % 2
	if str(settings.get("mode")) == "defend" or str(settings.get("initial_role", "attack")) == "defend":
		attacker_team = 1 - attacker_team
	var size: int = int(settings["team_size"])
	time_left = float(balance.get("match", {}).get("duration_%d" % size, 240.0))
	if str(settings.get("mode")) in ["training", "tutorial"]:
		time_left = 900.0
	if _test_duration > 0:
		time_left = _test_duration
	phase = "playing"
	preparation_left = 0.0 if _simulation or str(settings.get("mode")) in ["training", "tutorial"] else clampf(float(settings.get("preparation_seconds", 8.0)), 0.0, 12.0)
	_bot_accumulator = 0.0
	_round_started_at = Time.get_ticks_msec()
	_round_initial_alive = size
	_pending_auto_round = -1.0
	for team_id in range(2):
		var role: String = "attack" if team_id == attacker_team else "defend"
		var positions: Array = level.spawns[role]
		for index in range(size):
			var controlled: bool = team_id == 0 and index == 0 and not _simulation
			var actor = ActorScript.new()
			actor.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(actor)
			actor.setup(self, team_id * 10 + index, team_id, controlled, positions[index % positions.size()])
			var allowed: Array = ["decoy", "veil", "thorn"] if role == "attack" else ["ear", "bell", "choir"]
			if controlled:
				var primary: String = str(settings.get("primary_gadget", allowed[0]))
				var secondary: String = str(settings.get("secondary_gadget", allowed[2]))
				actor.gadget_loadout = [primary if primary in allowed else allowed[0], secondary if secondary in allowed else allowed[2]]
				if actor.gadget_loadout[0] == actor.gadget_loadout[1]:
					actor.gadget_loadout[1] = allowed[1]
				human = actor
			else:
				actor.gadget_loadout = [allowed[index % 3], allowed[(index + 1) % 3]]
			actor.gadget_used = [false, false]
			actors.append(actor)
			if not controlled:
				var bot = BotScript.new()
				bot.setup(self, actor, index)
				bots.append(bot)
			if role == "attack":
				actor.aim_direction = Vector3.FORWARD
			else:
				actor.aim_direction = Vector3.BACK
	if is_instance_valid(human):
		human.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_spectator_camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ui.has_method("show_hud"):
		ui.show_hud()
	elif ui.has_method("hide_menu"):
		ui.hide_menu()
	if str(settings.get("mode")) == "tutorial":
		tutorial_director = TutorialScript.new()
		tutorial_director.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(tutorial_director)
		tutorial_director.setup(self)
	notify("MANCHE %d · %s" % [round_index + 1, "TRAVERSEZ LE SANCTUAIRE" if attacker_team == 0 else "PROTÉGEZ LES TROIS ÉCHOS"])

func next_round() -> void:
	if phase == "finished":
		start_match(_last_config)
		return
	if phase != "between":
		return
	round_index += 1
	_begin_round()

func return_to_menu() -> void:
	get_tree().paused = false
	paused = false
	phase = "menu"
	_clear_round()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_camera.make_current()
	ui.show_menu()

func set_paused(value: bool) -> void:
	if phase != "playing":
		return
	paused = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or not is_instance_valid(human) or not human.alive or human.extracted else Input.MOUSE_MODE_CAPTURED
	ui.set_pause(value)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if phase == "playing":
				set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			developer_mode = not developer_mode
			notify("Diagnostic : %s" % ("actif" if developer_mode else "inactif"))
		elif event.keycode == KEY_F8 and developer_mode and phase == "playing":
			time_left = minf(time_left, 0.5)
		elif event.keycode == KEY_SPACE and phase == "playing" and (not is_instance_valid(human) or not human.alive or human.extracted):
			_cycle_spectator()

func _physics_process(delta: float) -> void:
	if phase != "playing" or paused:
		if _pending_auto_round >= 0.0 and not paused:
			_pending_auto_round -= delta
			if _pending_auto_round < 0.0:
				next_round()
		return
	if preparation_left > 0.0:
		preparation_left = maxf(0.0, preparation_left - delta)
		if preparation_left <= 0.0:
			notify("LES ÉCHOS S’OUVRENT · MANCHE ACTIVE")
		return
	elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	for exit_id in extraction_alerts.keys():
		extraction_alerts[exit_id] = maxf(0.0, float(extraction_alerts[exit_id]) - delta)
		if float(extraction_alerts[exit_id]) <= 0.0:
			extraction_alerts.erase(exit_id)
			if level.has_method("set_exit_active"):
				level.set_exit_active(str(exit_id), false)
	_bot_accumulator += delta
	if _bot_accumulator >= 0.10:
		var decision_delta: float = _bot_accumulator
		_bot_accumulator = 0.0
		if str(settings.get("mode")) != "tutorial":
			for bot in bots:
				bot.tick(decision_delta)
	_update_extractions(delta)
	_update_spectator(delta)
	if time_left <= 0.0:
		_finish_round("Le sanctuaire se referme.")
		return
	var unresolved: int = 0
	for actor in actors:
		if actor.team == attacker_team and actor.alive and not actor.extracted:
			unresolved += 1
	if unresolved == 0:
		_finish_round("Tous les Passeurs ont quitté le combat.")

func _process(delta: float) -> void:
	if phase == "menu":
		var t: float = float(Time.get_ticks_msec()) * 0.00008
		_menu_camera.position = Vector3(18.0 + sin(t) * 4.0, 11.0, 25.0 + cos(t) * 2.0)
		_menu_camera.look_at(Vector3(0.0, 3.4, -10.0))
	elif phase == "playing" and delta > 0:
		_minimum_fps = minf(_minimum_fps, 1.0 / delta)

func active_exits() -> Array:
	return level.exits if is_instance_valid(level) else []

func _update_extractions(delta: float) -> void:
	for actor in actors:
		if not actor.alive or actor.extracted or actor.team != attacker_team:
			continue
		var nearby: Dictionary = {}
		for exit in active_exits():
			var difference: Vector3 = actor.global_position - Vector3(exit["position"])
			difference.y = 0.0
			if difference.length() <= float(exit.get("radius", 3.0)):
				nearby = exit
				break
		var state: Dictionary = _extract_state.get(actor.actor_id, {"exit": "", "idle": 0.0, "sound": 0.0})
		var interacting: bool = actor.command_interact and not nearby.is_empty()
		# Reloading, jumping, sprinting and sliding are incompatible with the ritual.
		if actor.reload_left > 0.0 or actor.stance == "slide" or not actor.is_on_floor():
			interacting = false
		if interacting:
			var exit_id: String = str(nearby["id"])
			if str(state["exit"]) != exit_id:
				actor.extraction_progress = 0.0
				state["exit"] = exit_id
				state["sound"] = 0.0
			state["idle"] = 0.0
			state["sound"] = float(state["sound"]) - delta
			if float(state["sound"]) <= 0.0:
				var first_alert: bool = not extraction_alerts.has(exit_id)
				extraction_alerts[exit_id] = 8.0
				acoustics.emit_sound(actor, "extraction", Vector3(nearby["position"]), {"range": 30.0, "duration": 1.4})
				if first_alert:
					notify("EXTRACTION · %s" % str(nearby["name"]))
				state["sound"] = 0.85
			actor.extraction_progress = minf(1.0, actor.extraction_progress + delta / float(nearby.get("duration", 5.0)))
			if level.has_method("set_exit_active"):
				level.set_exit_active(exit_id, true)
			if actor.extraction_progress >= 1.0:
				_extract_actor(actor, nearby)
		else:
			state["idle"] = float(state["idle"]) + delta
			if float(state["idle"]) > float(balance.get("match", {}).get("extraction_grace", 1.0)):
				actor.extraction_progress = maxf(0.0, actor.extraction_progress - delta * 0.8)
		_extract_state[actor.actor_id] = state

func _extract_actor(actor, exit: Dictionary) -> void:
	if not actor.alive or actor.extracted or _scored.has(actor.actor_id):
		return
	actor.extracted = true
	actor.extraction_progress = 1.0
	actor.velocity = Vector3.ZERO
	actor.collision_layer = 0
	actor.visual.visible = false
	actor.stats["extractions"] = int(actor.stats.get("extractions", 0)) + 1
	_award(actor, actor.team)
	notify("%s a franchi %s." % [_actor_name(actor), str(exit["name"])])
	if actor == human:
		profile["extractions"] = int(profile.get("extractions", 0)) + 1
		if str(settings.get("mode")) == "tutorial":
			profile["tutorial_complete"] = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cycle_spectator()

func _award(actor, team_id: int) -> void:
	if _scored.has(actor.actor_id):
		return
	_scored[actor.actor_id] = team_id
	scores[team_id] += int(balance.get("match", {}).get("objective_points", 100))

func on_actor_hit(shooter, victim, damage: float, headshot: bool) -> void:
	if is_instance_valid(shooter) and shooter == human and victim.team != shooter.team:
		if ui.has_method("hit_feedback"):
			ui.hit_feedback(headshot)
	if victim == human and ui.has_method("damage_feedback"):
		ui.damage_feedback(damage)

func on_actor_died(victim, killer) -> void:
	if phase != "playing":
		return
	if victim.team == attacker_team:
		_award(victim, 1 - attacker_team)
	var killer_name: String = _actor_name(killer) if is_instance_valid(killer) else "Le Creux"
	notify("%s  /  %s" % [killer_name, _actor_name(victim)])
	if killer == human:
		profile["kills"] = int(profile.get("kills", 0)) + 1
	if victim == human:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cycle_spectator()

func _finish_round(reason: String) -> void:
	if phase != "playing":
		return
	for actor in actors:
		if actor.team == attacker_team and not _scored.has(actor.actor_id):
			_award(actor, 1 - attacker_team)
	var extracted: int = 0
	var stopped: int = 0
	var actor_stats: Array = []
	for actor in actors:
		if actor.team == attacker_team:
			if actor.extracted:
				extracted += 1
			else:
				stopped += 1
		actor_stats.append({"id": actor.actor_id, "team": actor.team, "alive": actor.alive, "extracted": actor.extracted, "stats": actor.stats.duplicate(true)})
	var bot_metrics: Array = []
	for bot in bots:
		bot_metrics.append({"state": bot.state, "stuck_count": bot.stuck_count, "telemetry": bot.telemetry.duplicate(true)})
	var record: Dictionary = {"round": round_index + 1, "attacker_team": attacker_team, "duration": elapsed, "extracted": extracted, "stopped": stopped, "actors": actor_stats, "bots": bot_metrics}
	round_statistics.append(record)
	metrics["rounds"] = round_statistics.duplicate(true)
	var final_round: bool = round_index + 1 >= int(settings["rounds"])
	phase = "finished" if final_round else "between"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var summary: Dictionary = {
		"title": "MANCHE TERMINÉE", "subtitle": reason, "scores": scores.duplicate(),
		"round": round_index + 1, "rounds": int(settings["rounds"]),
		"extracted": extracted, "stopped": stopped, "statistics": actor_stats,
	}
	if final_round:
		var limited_mode: bool = str(settings.get("mode")) in ["attack", "defend", "training", "tutorial"]
		summary["title"] = "SESSION TERMINÉE" if limited_mode else ("ÉQUILIBRE DES ÉCHOS" if scores[0] == scores[1] else ("VICTOIRE" if scores[0] > scores[1] else "DÉFAITE"))
		profile["matches"] = int(profile.get("matches", 0)) + 1
		save_settings()
		metrics["scores"] = scores.duplicate()
		metrics["minimum_observed_fps"] = _minimum_fps
		metrics["balanced_roles"] = int(settings["rounds"]) % 2 == 0
		if _simulation:
			_write_simulation_report()
			print("SONAR_SIMULATION ", JSON.stringify(metrics))
			get_tree().quit(0)
		else:
			ui.show_final_result(summary)
	else:
		ui.show_round_result(summary)
		if _simulation:
			_pending_auto_round = 0.1

func _write_simulation_report() -> void:
	var file = FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "\t"))
	else:
		push_warning("Unable to write simulation report: " + _report_path)

func _actor_name(actor) -> String:
	if not is_instance_valid(actor):
		return "Le Creux"
	if actor.is_human:
		return "VOUS"
	var names: Array = ["LYS", "ORIN", "VAEL", "NERA", "KAEL", "SILE"]
	return str(names[(int(actor.team) * 3 + int(actor.actor_id) % 10) % names.size()])

func get_observer():
	if is_instance_valid(human) and human.alive and not human.extracted:
		return human
	for actor in actors:
		if actor.actor_id == _spectator_id and actor.alive and not actor.extracted:
			return actor
	for actor in actors:
		if actor.team == 0 and actor.alive and not actor.extracted:
			_spectator_id = actor.actor_id
			return actor
	if _simulation:
		for actor in actors:
			if actor.alive and not actor.extracted:
				return actor
	return null

func _cycle_spectator() -> void:
	var allowed: Array = []
	for actor in actors:
		if actor.team == 0 and actor.alive and not actor.extracted:
			allowed.append(actor)
	if not allowed.is_empty():
		var current: int = -1
		for i in range(allowed.size()):
			if allowed[i].actor_id == _spectator_id:
				current = i
		_spectator_id = allowed[(current + 1) % allowed.size()].actor_id
	_spectator_camera.make_current()

func _update_spectator(delta: float) -> void:
	if is_instance_valid(human) and human.alive and not human.extracted:
		return
	var observer = get_observer()
	if observer == null:
		return
	_spectator_camera.make_current()
	# First-person allied perspective cannot see around corners or through walls.
	observer.visual.visible = false
	_spectator_camera.global_position = observer.eye_position()
	if observer.aim_direction.length_squared() > 0.01:
		_spectator_camera.look_at(_spectator_camera.global_position + observer.aim_direction)

func command_allies(order: String) -> void:
	var position: Vector3 = human.global_position if is_instance_valid(human) else Vector3.ZERO
	if is_instance_valid(human):
		var ray = PhysicsRayQueryParameters3D.create(human.eye_position(), human.eye_position() + human.aim_direction * 45.0, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			position = Vector3(hit["position"])
	for bot in bots:
		if bot.actor.team == 0:
			bot.set_order(order, position)
	notify("ORDRE · " + order.to_upper(), 0)

func notify(message: String, team: int = -1) -> void:
	if is_instance_valid(ui) and (team == -1 or team == 0):
		ui.push_message(message)

func _parse_launch_options() -> void:
	var options: Dictionary = {}
	var auto_start: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument == "--simulate":
			options["mode"] = "simulation"
			auto_start = true
		elif argument == "--play":
			auto_start = true
		elif argument.begins_with("--seed="):
			_seed_value = int(argument.get_slice("=", 1))
		elif argument.begins_with("--team-size="):
			options["team_size"] = int(argument.get_slice("=", 1))
		elif argument.begins_with("--rounds="):
			options["rounds"] = int(argument.get_slice("=", 1))
		elif argument.begins_with("--difficulty="):
			options["difficulty"] = int(argument.get_slice("=", 1))
		elif argument.begins_with("--duration="):
			_test_duration = float(argument.get_slice("=", 1))
		elif argument.begins_with("--report="):
			_report_path = argument.trim_prefix("--report=")
	if auto_start:
		call_deferred("start_match", options)
