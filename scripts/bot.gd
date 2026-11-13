extends RefCounted
## Tactical controller: receives percepts, chooses an objective, then sends the
## same world-space commands as the human controller. No enemy transforms enter
## the decision layer. Physics alone validates hits.

var game
var actor
var index: int = 0
var state: String = "INFILTRATE"
var goal: Vector3 = Vector3.ZERO
var last_path: PackedVector3Array = PackedVector3Array()
var stuck_count: int = 0
var profile: String = "scout"
var telemetry: Dictionary = {"repaths": 0, "unstucks": 0, "intercepts": 0, "investigations": 0, "searches_abandoned": 0, "engagements": 0, "fire_commands": 0, "speculative_shots": 0, "ping_commands": 0, "gadget_commands": 0}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _difficulty: int = 1
var _clock: float = 0.0
var _decision_left: float = 0.0
var _route_left: float = 0.0
var _repath_left: float = 0.0
var _path_index: int = 0
var _look: Vector3 = Vector3.FORWARD
var _desired_look: Vector3 = Vector3.FORWARD
var _best_contact: Dictionary = {}
var _target_key: int = -2147483648
var _reaction_left: float = 0.0
var _contact_selected_at: float = 0.0
var _last_confirmed_at: float = -99.0
var _ignored_until: Dictionary = {}
var _search_until: float = -1.0
var _objective_exit: Dictionary = {}
var _alarm_exit: Dictionary = {}
var _patrol_phase: int = 0
var _patrol_until: float = 0.0
var _order: String = ""
var _order_position: Vector3 = Vector3.ZERO
var _order_until: float = 0.0
var _cover_until: float = 0.0
var _cover_retry_at: float = 0.0
var _last_message_at: float = -99.0
var _last_health: float = 100.0
var _watch_position: Vector3 = Vector3.ZERO
var _watch_left: float = 1.2
var _last_move: Vector3 = Vector3.ZERO
var _unstuck_until: float = 0.0
var _unstuck_move: Vector3 = Vector3.ZERO
var _aim_noise: Vector3 = Vector3.ZERO
var _noise_left: float = 0.0
var _next_patrol_ping: float = 15.0
var _gadget_left: float = 3.0
var _speculation_left: int = 0
var _pending_ping: bool = false
var _pending_gadget: int = -1


func setup(game_ref, actor_ref, bot_index: int) -> void:
	game = game_ref
	actor = actor_ref
	index = bot_index
	_difficulty = clampi(int(game.settings.get("difficulty", 1)), 0, 3)
	_rng.seed = int(game.metrics.get("seed", game.settings.get("seed", 1739))) + int(actor.actor_id) * 9817 + int(game.round_index) * 103
	profile = ["scout", "tracker", "sentinel", "support", "opportunist"][posmod(index + int(game.round_index), 5)]
	goal = actor.global_position
	_watch_position = goal
	_last_health = float(actor.health)
	_decision_left = _rng.randf_range(0.04, 0.2)
	_next_patrol_ping = _rng.randf_range(12.0, 22.0)
	_gadget_left = _rng.randf_range(2.0, 5.0)
	var exits: Array = game.active_exits()
	if not exits.is_empty():
		_objective_exit = exits[posmod(index + int(game.round_index), exits.size())]
		_desired_look = (_objective_exit.position - actor.global_position).normalized()
		_look = _desired_look
	state = "INFILTRATE" if _is_attacker() else "DEFEND_EXIT"


func set_order(order: String, position: Vector3 = Vector3.ZERO) -> void:
	var aliases: Dictionary = {"suivez": "follow", "suivez-moi": "follow", "wait": "hold", "attendez": "hold", "cover": "cover", "avancez": "advance", "defend": "cover", "repliez": "retreat", "prepare_extract": "extract"}
	_order = str(aliases.get(order.to_lower(), order.to_lower()))
	_order_position = position
	if position == Vector3.ZERO:
		if is_instance_valid(game.human) and game.human.alive and not game.human.extracted:
			_order_position = game.human.global_position
		else:
			_order_position = actor.global_position
	_order_until = _clock + (28.0 if _order == "follow" else 18.0)
	if _order == "advance":
		_order = ""
		_order_until = 0.0
		_route_left = 0.0
	elif _order == "extract":
		_objective_exit = _choose_exit(true)
	_decision_left = 0.0
	_repath_left = 0.0
	_say("Ordre reçu.")


func tick(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.alive or actor.extracted or game.phase != "playing":
		return
	_clock += delta
	_decision_left -= delta
	_repath_left -= delta
	_route_left -= delta
	_reaction_left = maxf(0.0, _reaction_left - delta)
	_gadget_left -= delta
	_noise_left -= delta
	if _decision_left <= 0.0:
		_decision_left = _rng.randf_range(0.13, 0.22)
		_decide()
	var command: Dictionary = _make_command(delta)
	actor.apply_command(command)
	_watch_for_stuck(delta, command.move)
	_last_health = float(actor.health)


func _is_attacker() -> bool:
	return int(actor.team) == int(game.attacker_team)


func _decide() -> void:
	_pending_ping = false
	_pending_gadget = -1
	_read_perception()
	_alarm_exit = _choose_alarm() if not _is_attacker() else {}
	if _order_until < _clock:
		_order = ""
	var confirmed: bool = not _best_contact.is_empty() and bool(_best_contact.get("confirmed", false)) and bool(_best_contact.get("visible", true)) and float(_best_contact.get("age", 99.0)) < 1.5
	if confirmed:
		_last_confirmed_at = _clock
		_speculation_left = 2
		if state != "ENGAGE" and state != "TAKE_COVER":
			telemetry.engagements += 1
			_say("Contact confirmé · " + _zone(_best_contact.position))
		if (float(actor.health) < 32.0 or int(actor.ammo) == 0) and _clock > _cover_retry_at:
			var cover: Vector3 = _find_cover(_best_contact.position)
			if cover.distance_to(actor.global_position) > 1.2:
				_cover_until = _clock + 1.8
				_cover_retry_at = _clock + 6.0
				_set_goal(cover)
		if _clock < _cover_until:
			state = "TAKE_COVER"
		else:
			state = "ENGAGE"
			_set_goal(_best_contact.position)
		_plan_combat_gadget()
		return
	if not _alarm_exit.is_empty():
		if state != "INTERCEPT":
			telemetry.intercepts += 1
			_say("J'intercepte · " + str(_alarm_exit.get("name", "sortie")))
		state = "INTERCEPT"
		_set_goal(_alarm_exit.position)
		if _horizontal_distance(actor.global_position, _alarm_exit.position) < 21.0 and float(actor.ping_cooldown) <= 0.0:
			_pending_ping = true
		_plan_combat_gadget()
		return
	if _apply_order():
		return
	if not _best_contact.is_empty() and _may_investigate(_best_contact):
		var contact_position: Vector3 = _best_contact.position
		if _horizontal_distance(actor.global_position, contact_position) < 2.2:
			if state != "SEARCH":
				_search_until = _clock + _rng.randf_range(1.8, 3.2)
			state = "SEARCH"
			_set_goal(actor.global_position)
			if float(actor.ping_cooldown) <= 0.0:
				_pending_ping = true
			if _clock >= _search_until:
				_abandon_contact()
				_choose_objective()
		else:
			if state != "INVESTIGATE":
				telemetry.investigations += 1
				_say("Bruit suspect · " + _zone(contact_position))
			state = "INVESTIGATE"
			_set_goal(contact_position)
			if _horizontal_distance(actor.global_position, contact_position) < 16.0 and float(actor.ping_cooldown) <= 0.0:
				_pending_ping = true
		return
	_choose_objective()


func _read_perception() -> void:
	var records: Array = game.acoustics.contacts_for(actor)
	var chosen: Dictionary = {}
	var best_value: float = -INF
	for value in records:
		var contact: Dictionary = value
		var key: int = int(contact.get("target_id", -2147483648))
		if int(contact.get("team", -1)) == int(actor.team):
			continue
		if float(_ignored_until.get(key, -1.0)) > _clock:
			continue
		var age: float = float(contact.get("age", 99.0))
		var confidence: float = float(contact.get("confidence", 0.0))
		if age > 5.0 or confidence < 0.17 or not contact.has("position"):
			continue
		var distance: float = _horizontal_distance(actor.global_position, contact.position)
		var utility: float = confidence * 4.0 + float(contact.get("state", 0)) * 0.2 - distance * 0.035 - age * 0.18
		if bool(contact.get("confirmed", false)):
			utility += 3.0
		if key == _target_key:
			utility += 0.35
		if utility > best_value:
			best_value = utility
			chosen = contact.duplicate(true)
	if chosen.is_empty():
		_best_contact = {}
		if _clock - _last_confirmed_at > 2.0:
			_target_key = -2147483648
		return
	var key: int = int(chosen.get("target_id", -2147483648))
	if key != _target_key:
		_target_key = key
		_contact_selected_at = _clock
		var reaction_ranges: Array = [Vector2(0.7, 1.0), Vector2(0.36, 0.58), Vector2(0.27, 0.43), Vector2(0.2, 0.34)]
		var interval: Vector2 = reaction_ranges[_difficulty]
		_reaction_left = _rng.randf_range(interval.x, interval.y)
		_search_until = -1.0
	_best_contact = chosen
	if _clock - _contact_selected_at > 7.0 and not bool(chosen.get("confirmed", false)):
		_abandon_contact()


func _abandon_contact() -> void:
	_ignored_until[_target_key] = _clock + 6.0
	_best_contact = {}
	_target_key = -2147483648
	_search_until = -1.0
	telemetry.searches_abandoned += 1
	_say("Contact perdu. Je reprends mon secteur.")


func _may_investigate(contact: Dictionary) -> bool:
	var distance: float = _horizontal_distance(actor.global_position, contact.position)
	if _is_attacker():
		# The extraction objective takes priority over weak, faraway distractions.
		return distance < (14.0 if profile == "support" else 19.0) and float(contact.get("confidence", 0.0)) > 0.34 and float(game.time_left) > 22.0
	if profile == "sentinel" and distance > 17.0:
		return false
	if distance > 31.0:
		return false
	for teammate in game.bots:
		if teammate == self or not is_instance_valid(teammate.actor):
			continue
		var friend = teammate.actor
		if int(friend.team) != int(actor.team) or not friend.alive or friend.extracted:
			continue
		if teammate.state == "INTERCEPT":
			continue
		var other_distance: float = _horizontal_distance(friend.global_position, contact.position)
		if other_distance + 1.0 < distance:
			return false
		if absf(other_distance - distance) < 1.0 and int(friend.actor_id) < int(actor.actor_id):
			return false
	return true


func _choose_alarm() -> Dictionary:
	var selected: Dictionary = {}
	var best: float = INF
	for exit_data in game.active_exits():
		if float(game.extraction_alerts.get(str(exit_data.id), 0.0)) <= 0.0:
			continue
		var distance: float = _horizontal_distance(actor.global_position, exit_data.position)
		var is_responder: bool = true
		for teammate in game.bots:
			if teammate == self or not is_instance_valid(teammate.actor):
				continue
			var friend = teammate.actor
			if int(friend.team) != int(actor.team) or not friend.alive or friend.extracted:
				continue
			var other_distance: float = _horizontal_distance(friend.global_position, exit_data.position)
			if other_distance + 0.7 < distance or (absf(other_distance - distance) <= 0.7 and int(friend.actor_id) < int(actor.actor_id)):
				is_responder = false
				break
		# Defenders physically at an activated gate always investigate their own
		# immediate area, even when another teammate is marginally closer.
		if (is_responder or distance < 6.0) and distance < best:
			best = distance
			selected = exit_data
	return selected


func _apply_order() -> bool:
	match _order:
		"follow":
			if not is_instance_valid(game.human) or not game.human.alive or game.human.extracted:
				_order = ""
				return false
			state = "SUPPORT_ALLY"
			var forward: Vector3 = game.human.aim_direction
			forward.y = 0.0
			forward = forward.normalized()
			var side: Vector3 = Vector3(-forward.z, 0.0, forward.x)
			var formation: Vector3 = game.human.global_position - forward * 2.5 + side * (1.6 if index % 2 == 0 else -1.6)
			_set_goal(game.navigation.nearest_walkable(formation))
			return true
		"hold", "cover":
			state = "DEFEND_EXIT" if _order == "cover" else "HOLD"
			_set_goal(game.navigation.nearest_walkable(_order_position))
			return true
		"retreat":
			state = "RETREAT"
			var spawn_key: String = "attack" if _is_attacker() else "defend"
			var spawns: Array = game.level.spawns.get(spawn_key, [])
			if not spawns.is_empty():
				_set_goal(spawns[posmod(index, spawns.size())])
			return true
		"extract":
			if _is_attacker():
				_attack_objective()
				return true
	return false


func _choose_objective() -> void:
	if _is_attacker():
		_attack_objective()
	else:
		_defend_objective()


func _attack_objective() -> void:
	if _objective_exit.is_empty() or _route_left <= 0.0:
		_objective_exit = _choose_exit(float(game.time_left) < 25.0)
		_route_left = _rng.randf_range(12.0, 19.0)
	if _objective_exit.is_empty():
		state = "INFILTRATE"
		return
	var distance: float = _horizontal_distance(actor.global_position, _objective_exit.position)
	if distance <= maxf(0.8, float(_objective_exit.get("radius", 2.8)) - 0.65):
		state = "EXTRACT"
		_set_goal(actor.global_position)
		if float(actor.ping_cooldown) <= 0.0 and not _best_contact.is_empty():
			_pending_ping = true
	else:
		state = "INFILTRATE"
		_set_goal(_objective_exit.position)
	if _gadget_left <= 0.0 and float(game.elapsed) > 5.0:
		if distance < 13.0 or not _best_contact.is_empty() or _rng.randf() < 0.22:
			_pending_gadget = _unused_gadget()
			_gadget_left = _rng.randf_range(4.0, 9.0)


func _choose_exit(nearest_only: bool) -> Dictionary:
	var exits: Array = game.active_exits()
	var chosen: Dictionary = {}
	var best: float = INF
	for exit_data in exits:
		var distance: float = _horizontal_distance(actor.global_position, exit_data.position)
		var utility: float = distance
		if not nearest_only:
			if not _objective_exit.is_empty() and str(exit_data.id) == str(_objective_exit.id):
				utility -= 12.0
			for teammate in game.bots:
				if teammate == self or not is_instance_valid(teammate.actor):
					continue
				if int(teammate.actor.team) == int(actor.team) and teammate.actor.alive and not teammate.actor.extracted and not teammate._objective_exit.is_empty() and str(teammate._objective_exit.id) == str(exit_data.id):
					utility += 8.0 if profile == "scout" else 3.0
			if not _best_contact.is_empty():
				var threat_distance: float = _horizontal_distance(_best_contact.position, exit_data.position)
				utility += maxf(0.0, 20.0 - threat_distance) * float(_best_contact.get("confidence", 0.0)) * 1.6
		if utility < best:
			best = utility
			chosen = exit_data
	return chosen


func _defend_objective() -> void:
	state = "DEFEND_EXIT"
	if _objective_exit.is_empty():
		var exits: Array = game.active_exits()
		if exits.is_empty():
			return
		_objective_exit = exits[posmod(index, exits.size())]
	if _clock > _patrol_until:
		_patrol_until = _clock + _rng.randf_range(4.5, 7.0)
		_patrol_phase = (_patrol_phase + 1) % 3
		var exit_position: Vector3 = _objective_exit.position
		var toward_center: Vector3 = -Vector3(exit_position.x, 0.0, exit_position.z).normalized()
		var tangent: Vector3 = Vector3(-toward_center.z, 0.0, toward_center.x)
		var patrol: Vector3 = exit_position + toward_center * (5.0 + _patrol_phase * 2.0) + tangent * (float(_patrol_phase - 1) * 3.0)
		_set_goal(game.navigation.nearest_walkable(patrol))
	if _gadget_left <= 0.0 and _horizontal_distance(actor.global_position, _objective_exit.position) < 15.0:
		_pending_gadget = _unused_gadget()
		_gadget_left = _rng.randf_range(9.0, 17.0)
	if _clock > _next_patrol_ping:
		_next_patrol_ping = _clock + _rng.randf_range(18.0, 30.0)
		if float(actor.ping_cooldown) <= 0.0:
			_pending_ping = true


func _plan_combat_gadget() -> void:
	if _gadget_left <= 0.0:
		_pending_gadget = _unused_gadget()
		_gadget_left = _rng.randf_range(4.5, 7.5)


func _unused_gadget() -> int:
	if _difficulty == 0 and _rng.randf() < 0.5:
		return -1
	for slot in range(mini(actor.gadget_loadout.size(), actor.gadget_used.size())):
		if not bool(actor.gadget_used[slot]):
			return slot
	return -1


func _make_command(delta: float) -> Dictionary:
	var command: Dictionary = {"move": Vector3.ZERO, "look": _look, "fire": false, "aim": false, "sprint": false, "crouch": false, "jump": false, "reload": false, "ping": false, "interact": false, "gadget": -1}
	var move: Vector3 = Vector3.ZERO
	var position: Vector3 = actor.global_position
	if state == "ENGAGE" and not _best_contact.is_empty():
		var aim_point: Vector3 = _best_contact.position + Vector3(0.0, 1.12, 0.0)
		var distance: float = _horizontal_distance(position, _best_contact.position)
		if _noise_left <= 0.0:
			_noise_left = _rng.randf_range(0.16, 0.3)
			var aim_error: float = [0.115, 0.064, 0.043, 0.028][_difficulty]
			_aim_noise = Vector3(_rng.randf_range(-aim_error, aim_error), _rng.randf_range(-aim_error * 0.7, aim_error * 0.7), _rng.randf_range(-aim_error, aim_error))
		_desired_look = ((aim_point - actor.eye_position()).normalized() + _aim_noise).normalized()
		command.aim = true
		if distance > 27.0:
			move = _path_move()
		elif distance < 5.0:
			move = -Vector3(_desired_look.x, 0.0, _desired_look.z).normalized() * 0.6
		else:
			var tangent: Vector3 = Vector3(-_desired_look.z, 0.0, _desired_look.x).normalized()
			move = tangent * sin(_clock * 1.1 + float(index) * 2.0) * 0.62
			if not game.navigation.is_walkable(position + move * 1.3):
				move = -move
			if not game.navigation.is_walkable(position + move * 1.3):
				move = Vector3.ZERO
		var clear: bool = game.acoustics.has_line_of_sight(actor.eye_position(), aim_point)
		var aligned: bool = _look.dot(_desired_look) > 0.975
		command.fire = clear and aligned and _reaction_left <= 0.0 and bool(_best_contact.get("confirmed", false)) and float(actor.reload_left) <= 0.0
		if command.fire:
			telemetry.fire_commands += 1
	elif state == "EXTRACT":
		command.interact = true
		_desired_look = Vector3(sin(_clock * 0.45), 0.0, cos(_clock * 0.45))
	elif state == "SEARCH" or state == "HOLD":
		move = _path_move() if state == "HOLD" else Vector3.ZERO
		_desired_look = Vector3(sin(_clock * 1.0 + index), -0.03, cos(_clock * 1.0 + index)).normalized()
	else:
		move = _path_move()
		if not _best_contact.is_empty():
			_desired_look = (_best_contact.position + Vector3(0.0, 1.1, 0.0) - actor.eye_position()).normalized()
		elif move.length_squared() > 0.05:
			_desired_look = move.normalized()
		elif state == "DEFEND_EXIT":
			_desired_look = Vector3(sin(_clock * 0.35 + index), 0.0, cos(_clock * 0.35 + index)).normalized()
		if state == "TAKE_COVER":
			command.reload = int(actor.ammo) < 12
			command.sprint = true
		elif state == "INTERCEPT" or state == "RETREAT":
			command.sprint = true
		elif state == "INFILTRATE":
			command.sprint = _best_contact.is_empty() and sin(_clock * 0.36 + index) > -0.25 and float(game.time_left) > 12.0
			command.crouch = not _best_contact.is_empty() and float(_best_contact.get("confidence", 0.0)) < 0.52
		# Two bounded speculative bursts use only the memorized estimated point.
		if not _best_contact.is_empty() and _speculation_left > 0 and _clock - _last_confirmed_at < 0.6 and float(_best_contact.get("confidence", 0.0)) > 0.45:
			var estimated: Vector3 = _best_contact.position + Vector3(0.0, 1.1, 0.0)
			if _look.dot(_desired_look) > 0.98 and game.acoustics.has_line_of_sight(actor.eye_position(), estimated):
				command.fire = true
				_speculation_left -= 1
				telemetry.speculative_shots += 1
	if int(actor.ammo) <= 0 or (int(actor.ammo) < 7 and state != "ENGAGE" and state != "EXTRACT"):
		command.reload = true
		command.fire = false
	if _pending_ping and float(actor.ping_cooldown) <= 0.0 and state != "EXTRACT":
		command.ping = true
		_pending_ping = false
		telemetry.ping_commands += 1
	if _pending_gadget >= 0 and state != "EXTRACT" and float(actor.reload_left) <= 0.0:
		command.gadget = _pending_gadget
		_pending_gadget = -1
		telemetry.gadget_commands += 1
	if _unstuck_until > _clock:
		move = _unstuck_move
		command.sprint = false
	move = _avoid_allies(move)
	var max_turn: float = [2.2, 3.0, 3.8, 4.5][_difficulty] * delta
	_look = _rotate_toward(_look, _desired_look, max_turn)
	command.look = _look
	command.move = move.limit_length(1.0)
	_last_move = command.move
	return command


func _set_goal(position: Vector3) -> void:
	position.y = 0.0
	if _horizontal_distance(goal, position) > 2.0:
		goal = position
		_repath_left = 0.0
	else:
		goal = position


func _path_move() -> Vector3:
	var position: Vector3 = actor.global_position
	if _horizontal_distance(position, goal) < 0.75:
		return Vector3.ZERO
	if _repath_left <= 0.0 or last_path.is_empty():
		last_path = game.navigation.find_path(position, goal)
		_path_index = 0
		_repath_left = _rng.randf_range(1.0, 1.8)
		telemetry.repaths += 1
	while _path_index < last_path.size() and _horizontal_distance(position, last_path[_path_index]) < 0.65:
		_path_index += 1
	if _path_index >= last_path.size():
		return Vector3.ZERO
	var direction: Vector3 = last_path[_path_index] - position
	direction.y = 0.0
	return direction.normalized()


func _avoid_allies(move: Vector3) -> Vector3:
	if move.length_squared() < 0.01:
		return move
	var separation: Vector3 = Vector3.ZERO
	for friend in game.actors:
		if friend == actor or not is_instance_valid(friend) or int(friend.team) != int(actor.team) or not friend.alive or friend.extracted:
			continue
		var away: Vector3 = actor.global_position - friend.global_position
		away.y = 0.0
		var distance: float = away.length()
		if distance < 1.65 and distance > 0.02:
			separation += away.normalized() * (1.65 - distance) * 0.85
	var adjusted: Vector3 = (move + separation).limit_length(1.0)
	if game.navigation.is_walkable(actor.global_position + adjusted * 0.8):
		return adjusted
	return move


func _watch_for_stuck(delta: float, move: Vector3) -> void:
	_watch_left -= delta
	if _watch_left > 0.0:
		return
	_watch_left = 1.2
	var distance: float = _horizontal_distance(actor.global_position, _watch_position)
	_watch_position = actor.global_position
	if move.length_squared() < 0.12 or state == "EXTRACT" or state == "SEARCH" or state == "ENGAGE":
		return
	if distance >= 0.65:
		return
	stuck_count += 1
	telemetry.unstucks += 1
	_repath_left = 0.0
	last_path.clear()
	# Local sidesteps do not change transforms. If unavailable, choose another
	# navigable intermediate position and then retry the original objective.
	var preferred: Vector3 = Vector3(-move.z, 0.0, move.x).normalized()
	if stuck_count % 2 == 0:
		preferred = -preferred
	if not game.navigation.is_walkable(actor.global_position + preferred * 1.4):
		preferred = -preferred
	if game.navigation.is_walkable(actor.global_position + preferred * 1.4):
		_unstuck_move = preferred
		_unstuck_until = _clock + 0.65
	else:
		_unstuck_move = -move.normalized()
		_unstuck_until = _clock + 0.5
	if stuck_count % 4 == 0:
		if _is_attacker():
			_objective_exit = _choose_exit(true)
			_route_left = 0.0
		else:
			_patrol_until = 0.0


func _find_cover(threat: Vector3) -> Vector3:
	var best: Vector3 = actor.global_position
	var utility: float = -INF
	for value in game.level.cover_points:
		var point: Vector3 = value
		var distance: float = _horizontal_distance(actor.global_position, point)
		if distance > 13.0 or distance < 1.2 or not game.navigation.is_walkable(point):
			continue
		var hidden: bool = not game.acoustics.has_line_of_sight(threat + Vector3.UP * 1.2, point + Vector3.UP * 1.2)
		var score: float = (12.0 if hidden else 0.0) - distance + _horizontal_distance(threat, point) * 0.08
		if score > utility:
			utility = score
			best = point
	return best


func _rotate_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	if to.length_squared() < 0.001:
		return from
	if from.length_squared() < 0.001:
		return to.normalized()
	var angle: float = from.angle_to(to)
	if angle < 0.001:
		return to.normalized()
	var axis: Vector3 = from.cross(to)
	if axis.length_squared() < 0.0001:
		axis = Vector3.UP
	return from.rotated(axis.normalized(), minf(angle, max_angle)).normalized()


func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()


func _zone(position: Vector3) -> String:
	return str(game.level.get_zone(position))


func _say(message: String) -> void:
	if _clock - _last_message_at < 7.0:
		return
	_last_message_at = _clock
	game.notify("Équipier " + str(index + 1) + " · " + message, int(actor.team))
