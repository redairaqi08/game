extends Node
## Deliberately noncompetitive teaching scenario. This director may position a
## labelled training target; competitive bot decisions never use this service.
## The target never fires. It shares the real actor, acoustic and gadget rules.

var game
var target
var stage: int = -1
var stage_time: float = 0.0
var clock: float = 0.0
var _anchor: Vector3 = Vector3.ZERO
var _goal: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_at: float = 0.0
var _cue_at: float = 0.0
var _label: Label3D
var _extraction_label: Label3D
var _decoy_wait_started: float = -1.0
var _trap_wait_started: float = -1.0
var _exit_position: Vector3 = Vector3.ZERO
var _reached_gate: bool = false

func setup(game_ref) -> void:
	game = game_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for candidate in game.actors:
		if not candidate.is_human and candidate.team != game.human.team:
			target = candidate
			break
	if not is_instance_valid(target):
		return
	_label = _make_label("CIBLE D'ENTRAÎNEMENT · INOFFENSIVE")
	game.add_child(_label)
	_extraction_label = _make_label("")
	game.add_child(_extraction_label)
	_extraction_label.visible = false
	game.notify("EXERCICES GUIDÉS · cible inoffensive, sans score compétitif")

func _exit_tree() -> void:
	if is_instance_valid(_label):
		_label.queue_free()
	if is_instance_valid(_extraction_label):
		_extraction_label.queue_free()

func _physics_process(delta: float) -> void:
	if game == null or game.phase != "playing" or str(game.settings.get("mode", "")) != "tutorial":
		return
	if not is_instance_valid(game.human) or not is_instance_valid(target):
		return
	clock += delta
	stage_time += delta
	var requested_stage: int = int(game.ui.tutorial_step)
	if requested_stage != stage:
		_enter_stage(requested_stage)
	if not target.alive:
		return
	var human = game.human
	var command: Dictionary = {"move": Vector3.ZERO, "look": (human.eye_position() - target.eye_position()).normalized(), "fire": false, "aim": false}
	match stage:
		0:
			_label.text = "CIBLE INOFFENSIVE · EXERCEZ VOS DÉPLACEMENTS"
		1:
			var segment: int = int(stage_time / 2.4) % 3
			var lateral: Vector3 = Vector3(cos(clock), 0, sin(clock))
			_goal = _anchor + lateral * 3.0
			command.move = _path_direction(_goal)
			command.sprint = segment == 1
			command.crouch = segment == 2
			_label.text = ["DÉMONSTRATION · MARCHE", "DÉMONSTRATION · COURSE", "DÉMONSTRATION · ACCROUPI"][segment]
		2:
			_goal = _anchor + Vector3(sin(clock) * 2.0, 0, 0)
			command.move = _path_direction(_goal)
			_label.text = "ÉCOUTEZ · LES ONDES INDIQUENT UNE PRÉSENCE"
		3:
			_label.text = "CIBLE IMMOBILE · UTILISEZ F POUR LA RECONSTRUIRE"
		4:
			_label.text = "CIBLE DE TIR · SIGNAL AMPLIFIÉ · RECHARGE R"
			# A real acoustic event maintains a visible target while aiming is taught.
			if clock >= _cue_at:
				_cue_at = clock + 0.85
				game.acoustics.emit_sound(target, "reload", target.global_position, {"range": 12.0, "intensity": 1.8, "hold": 1.2})
		5:
			_label.text = "UTILISEZ G · LE BRUIT PEUT TROMPER"
			# Inspect only perceived records to demonstrate a real false contact.
			var best: Dictionary = {}
			for contact in game.acoustics.contacts_for(target):
				if int(contact.get("target_id", 0)) < 0 and float(contact.get("confidence", 0)) > 0.17:
					best = contact
					break
			if not best.is_empty():
				_goal = best.position
				command.move = _path_direction(_goal)
				command.sprint = true
				_label.text = "ENQUÊTE · LE DÉFENSEUR SUIT LE SIGNAL"
				if _decoy_wait_started < 0.0:
					_decoy_wait_started = clock
					game.notify("Le défenseur enquête sur le faux déplacement.")
		6:
			_label.text = "UTILISEZ T · POSEZ UNE ÉPINE SUR LE PASSAGE"
			var device = _player_thorn()
			if is_instance_valid(device):
				_goal = device.global_position
				if _trap_wait_started < 0.0:
					_trap_wait_started = clock
					game.notify("Le défenseur approche du piège. Observez son déclenchement.")
				if clock - _trap_wait_started > 0.8:
					command.move = _path_direction(_goal)
				_label.text = "DÉMONSTRATION · APPROCHE DU CAPTEUR"
		7:
			_label.text = "DÉFENSEUR D'EXERCICE · INOFFENSIF"
			_update_gate_exercise(command)
	target.apply_command(command)
	if is_instance_valid(_label):
		_label.global_position = target.global_position + Vector3.UP * 2.4

func _enter_stage(value: int) -> void:
	stage = value
	stage_time = 0.0
	_path.clear()
	_repath_at = 0.0
	_cue_at = 0.0
	var human = game.human
	match stage:
		0:
			_place_target(_visible_location(14.0))
		1:
			_place_target(_visible_location(8.0))
			game.notify("Écoutez les rythmes : marche, course, puis accroupissement.")
		2:
			_place_target(_visible_location(7.0))
			game.notify("Un signal localise ; une ligne de vue permet la reconstruction.")
		3:
			_place_target(_visible_location(8.0))
			game.notify("La cible est parfaitement immobile. Le ping la détecte aussi.")
		4:
			_place_target(_visible_location(6.5))
			game.notify("Cette cible ne peut pas mourir. Testez tir, visée et recharge.")
		5:
			_place_target(_visible_location(9.0))
			game.notify("Lancez l'Écho errant avec G. Les mêmes pas trompent le défenseur.")
		6:
			_place_target(_visible_location(8.0))
			game.notify("Maintenez puis relâchez T pour poser le piège devant vous.")
		7:
			var best_distance: float = INF
			for gate in game.active_exits():
				var distance: float = human.global_position.distance_to(gate.position)
				if distance < best_distance:
					best_distance = distance
					_exit_position = gate.position
					_extraction_label.text = "EXTRACTION · " + str(gate.name).to_upper() + "\nMAINTENIR E DANS LE CERCLE"
			_extraction_label.global_position = _exit_position + Vector3.UP * 3.8
			_extraction_label.visible = true
			game.notify("Suivez le repère d'extraction. La porte alertera les défenseurs.")

func _place_target(position: Vector3) -> void:
	target.apply_command({})
	target.velocity = Vector3.ZERO
	target.global_position = position + Vector3.UP * 0.05
	_anchor = position
	_goal = position

func _visible_location(distance: float) -> Vector3:
	var human = game.human
	var forward: Vector3 = human.aim_direction
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var selected: Vector3 = game.navigation.nearest_walkable(human.global_position + forward * distance)
	for angle: float in [0.0, 0.30, -0.30, 0.65, -0.65, 1.2, -1.2, PI]:
		var direction: Vector3 = forward.rotated(Vector3.UP, angle)
		var candidate: Vector3 = game.navigation.nearest_walkable(human.global_position + direction * distance)
		if candidate.distance_to(human.global_position) < 4.0:
			continue
		if game.acoustics.has_line_of_sight(human.eye_position(), candidate + Vector3.UP * 1.3):
			return candidate
	return selected

func _path_direction(destination: Vector3) -> Vector3:
	if clock >= _repath_at:
		_repath_at = clock + 0.4
		_path = game.navigation.find_path(target.global_position, destination)
		_path_index = 0
	while _path_index < _path.size() and _horizontal_distance(target.global_position, _path[_path_index]) < 0.7:
		_path_index += 1
	if _path_index >= _path.size():
		return Vector3.ZERO
	var movement: Vector3 = _path[_path_index] - target.global_position
	movement.y = 0
	return movement.normalized()

func _player_thorn():
	for device in game.gadgets.devices:
		if is_instance_valid(device) and device.alive and device.kind == "thorn" and device.team == game.human.team:
			return device
	return null

func _update_gate_exercise(command: Dictionary) -> void:
	var human = game.human
	if human.global_position.distance_to(_exit_position) < 15.0 and not _reached_gate:
		var position: Vector3 = game.navigation.nearest_walkable(_exit_position + Vector3(6, 0, 6))
		_place_target(position)
		_reached_gate = true
	if _reached_gate and game.extraction_alerts.size() > 0 and target.ping_cooldown <= 0.0:
		command.ping = true
		game.notify("La porte a donné l'alerte : un défenseur peut vous localiser par ping.")

func _make_label(text: String) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 34
	label.outline_size = 7
	label.pixel_size = 0.004
	label.modulate = Color(0.76, 0.96, 0.84)
	label.outline_modulate = Color(0.025, 0.045, 0.05, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	return label

func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()
