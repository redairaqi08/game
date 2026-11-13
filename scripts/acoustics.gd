extends Node
## Authoritative acoustic events -> individual memories -> observer-only presentation.
## World truth is read only here. Consumers receive immutable estimated records.

const RingShader = preload("res://shaders/acoustic_ring.gdshader")
const SOUND_RANGES: Dictionary = {
	"walk": 8.0, "sprint": 20.0, "crouch": 2.7, "slide": 22.0,
	"jump": 5.0, "land": 18.0, "shot": 35.0, "pistol": 27.0,
	"impact": 12.0, "reload": 7.0, "ping": 22.0, "gadget": 8.0,
	"trap": 26.0, "extraction": 30.0, "ambient": 8.0
}
const SPEED_OF_RECOGNITION: float = 44.0
const MAX_EFFECTS: int = 28
var game
var memories: Dictionary = {}
var pending: Array = []
var effects: Array = []
var event_sequence: int = 0
var clock: float = 0.0
var ping_feedback: Dictionary = {}
var event_log: Array = []
var _share_stamps: Dictionary = {}
var _ring_mesh: PlaneMesh

func setup(game_ref) -> void:
	game = game_ref
	_ring_mesh = PlaneMesh.new()
	_ring_mesh.size = Vector2(2.0, 2.0)

func clear() -> void:
	memories.clear()
	pending.clear()
	ping_feedback.clear()
	_share_stamps.clear()
	event_log.clear()
	for effect in effects:
		if is_instance_valid(effect.node):
			effect.node.queue_free()
	effects.clear()
	clock = 0.0
	event_sequence = 0

func _physics_process(delta: float) -> void:
	if game == null or game.phase != "playing":
		return
	clock += delta
	for actor in game.actors:
		if is_instance_valid(actor):
			var old_cooldown: float = float(actor.ping_cooldown)
			actor.ping_cooldown = maxf(0.0, old_cooldown - delta)
			if old_cooldown > 0.0 and actor.ping_cooldown <= 0.0 and actor.is_human:
				game.notify("Impulsion prête · F")
	var due: Array = []
	for i in range(pending.size() - 1, -1, -1):
		if float(pending[i].due) <= clock:
			due.append(pending[i])
			pending.remove_at(i)
	for packet in due:
		if packet.kind == "sound":
			_deliver_sound(packet)
		elif packet.kind == "scan":
			_deliver_scan(packet)
		elif packet.kind == "feedback":
			_finish_ping(packet)
	_decay_memories(delta)
	_update_reconstructions()
	_update_effects(delta)

func emit_sound(source, category: String, origin: Vector3 = Vector3.INF, overrides: Dictionary = {}) -> void:
	if game == null:
		return
	category = _normalize_category(category)
	var source_id: int = int(overrides.get("source_id", _source_id(source)))
	var source_team: int = int(overrides.get("team", _source_team(source)))
	var ground_origin: Vector3 = _source_position(source) if origin == Vector3.INF else origin
	if source != null and is_instance_valid(source) and source is CharacterBody3D and not overrides.has("source_id"):
		var body_origin: Vector3 = source.global_position
		var planar_delta: Vector2 = Vector2(ground_origin.x - body_origin.x, ground_origin.z - body_origin.z)
		if planar_delta.length() > 1.5:
			# A remote impact/device is a sound at that point, never a free reveal of its shooter.
			source_id = -200000 - event_sequence
	# Positions exposed to brains are always grounded, including gunshots.
	ground_origin.y = maxf(0.0, ground_origin.y - float(overrides.get("height_offset", 0.0)))
	if source != null and is_instance_valid(source) and source is CharacterBody3D:
		ground_origin.y = source.global_position.y
	var ranges: Dictionary = _settings().get("ranges", {})
	var nominal_range: float = float(overrides.get("range", ranges.get(category, SOUND_RANGES.get(category, 12.0))))
	var intensity: float = float(overrides.get("intensity", 1.0))
	event_sequence += 1
	var event: Dictionary = {
		"id": event_sequence, "created": clock, "category": category,
		"position": ground_origin, "range": nominal_range, "intensity": intensity,
		"source_id": source_id, "team": source_team,
		"family": "resonant" if category in ["ping", "shot", "trap"] else "movement",
		"duration": float(overrides.get("duration", 0.65)),
		"uncertainty": float(overrides.get("uncertainty", 1.0)),
		"propagation": "world_occlusion", "hold": float(overrides.get("hold", 0.65))
	}
	event_log.append(event.duplicate())
	if event_log.size() > 160:
		event_log.pop_front()
	for observer in game.actors:
		if not _is_active(observer):
			continue
		if observer.actor_id == source_id:
			if observer == game.get_observer():
				_play_audio(category, ground_origin, intensity * 0.75)
				_spawn_ring(ground_origin, category, minf(nominal_range * 0.12, 2.8), 0.42, 0.32)
			continue
		var distance: float = observer.global_position.distance_to(ground_origin)
		if distance > nominal_range:
			continue
		pending.append({"kind": "sound", "due": clock + minf(distance / _wave_speed(), 0.20), "event": event, "observer": observer})

func ping(source) -> bool:
	if not _is_active(source) or game.phase != "playing" or source.ping_cooldown > 0.0:
		return false
	source.ping_cooldown = float(_settings().get("ping_cooldown", 8.0))
	source.stats["pings"] = int(source.stats.get("pings", 0)) + 1
	var scan_id: int = event_sequence + 1
	var radius: float = float(_settings().get("ping_range", 22.0))
	var hold: float = float(_settings().get("confirmed_duration", 1.25))
	ping_feedback[scan_id] = {"source": source, "contacts": 0}
	# The outgoing signature uses exactly the same pipeline as movement and fire.
	emit_sound(source, "ping", source.global_position, {"range": radius, "intensity": 1.2})
	if source == game.get_observer():
		game.notify("Impulsion envoyée…")
		_spawn_ring(source.global_position, "ping", radius, radius / _wave_speed() + 0.15, 0.75)
	_schedule_scan(source, source.global_position, radius, scan_id, hold, 0.15)
	pending.append({"kind": "feedback", "due": clock + 0.22 + radius / _wave_speed(), "scan_id": scan_id})
	return true

func sensor_ping(owner, origin: Vector3, radius: float = 9.0) -> void:
	if not _is_active(owner):
		return
	emit_sound(owner, "ping", origin, {"range": radius + 5.0, "source_id": -9000 - event_sequence})
	_schedule_scan(owner, origin, radius, -1, 1.1, 0.05)
	if _observer_near(origin, radius + 8.0):
		_spawn_ring(origin, "ping", radius, radius / _wave_speed() + 0.22, 0.60)

func reveal(observer, target, origin: Vector3, duration: float = 3.0) -> void:
	if not _is_active(observer) or not _is_active(target) or observer.team == target.team:
		return
	var visible: bool = has_line_of_sight(observer.eye_position(), target.eye_position())
	var estimate: Vector3 = target.global_position
	var confidence: float = 0.98 if visible else 0.47
	if not visible:
		estimate = _uncertain_position(estimate, observer.actor_id, event_sequence, 3.0)
	_record(observer, target.actor_id, target.team, estimate, confidence, "trap", visible, duration)
	if observer == game.get_observer():
		_spawn_ring(estimate, "trap", 3.0, 0.7, 0.8)

func contact_for(observer, target_id: int) -> Dictionary:
	if observer == null or not is_instance_valid(observer):
		return {}
	var collection: Dictionary = memories.get(observer.actor_id, {})
	if not collection.has(target_id):
		return {}
	return collection[target_id].duplicate(true)

func contacts_for(observer) -> Array:
	if observer == null or not is_instance_valid(observer):
		return []
	var collection: Dictionary = memories.get(observer.actor_id, {})
	var result: Array = []
	for record in collection.values():
		if float(record.confidence) > 0.06:
			result.append(record.duplicate(true))
	return result

func has_line_of_sight(from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	if game == null or not game.is_inside_tree():
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var excluded: Array[RID] = []
	for object in exclude:
		if object is RID:
			excluded.append(object)
		elif is_instance_valid(object) and object is CollisionObject3D:
			excluded.append(object.get_rid())
	query.exclude = excluded
	query.hit_from_inside = true
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _schedule_scan(source, origin: Vector3, radius: float, scan_id: int, hold: float, preparation: float) -> void:
	for target in game.actors:
		if not _is_active(target) or target.team == source.team:
			continue
		var distance: float = origin.distance_to(target.global_position)
		if distance <= radius + 1.0:
			pending.append({"kind": "scan", "due": clock + preparation + distance / _wave_speed(), "source": source, "target": target, "origin": origin, "radius": radius, "scan_id": scan_id, "hold": hold})

func _deliver_scan(packet: Dictionary) -> void:
	var source = packet.source
	var target = packet.target
	if not _is_active(source) or not _is_active(target):
		return
	var origin: Vector3 = packet.origin
	var distance: float = origin.distance_to(target.global_position)
	if distance > float(packet.radius):
		return
	var visible: bool = has_line_of_sight(source.eye_position(), target.eye_position())
	var wave_visible: bool = has_line_of_sight(origin + Vector3.UP * 0.9, target.eye_position())
	# A beacon cannot grant the owner a silhouette through the owner's own wall.
	visible = visible and wave_visible
	var jam: float = _jam_factor(target.global_position, source.team)
	var confidence: float = 0.99 - jam * 0.13 if visible else 0.46
	var estimate: Vector3 = target.global_position
	if not visible:
		if distance > float(packet.radius) * 0.60:
			return
		estimate = _uncertain_position(estimate, source.actor_id, event_sequence, 3.2 + jam * 2.5)
	_record(source, target.actor_id, target.team, estimate, confidence, "ping", visible, float(packet.hold))
	if int(packet.scan_id) >= 0 and ping_feedback.has(packet.scan_id):
		ping_feedback[packet.scan_id].contacts += 1
	if source == game.get_observer():
		_spawn_ring(estimate, "contact", 1.6, 0.5, 0.65)
		_play_audio("contact", estimate, 0.55)

func _finish_ping(packet: Dictionary) -> void:
	var scan_id: int = int(packet.scan_id)
	if not ping_feedback.has(scan_id):
		return
	var feedback: Dictionary = ping_feedback[scan_id]
	if is_instance_valid(feedback.source) and feedback.source == game.get_observer():
		var count: int = int(feedback.contacts)
		game.notify("Aucun contact dans la portée" if count == 0 else "%d contact%s acoustique%s" % [count, "s" if count > 1 else "", "s" if count > 1 else ""])
	ping_feedback.erase(scan_id)

func _deliver_sound(packet: Dictionary) -> void:
	var observer = packet.observer
	if not _is_active(observer):
		return
	var event: Dictionary = packet.event
	var distance: float = observer.global_position.distance_to(event.position)
	var visible: bool = has_line_of_sight(observer.eye_position(), event.position + Vector3.UP * 1.15)
	var attenuation: float = 1.0
	if not visible:
		# Two offset samples soften edges around doorways without granting vision.
		var side: Vector3 = (event.position - observer.global_position).cross(Vector3.UP).normalized() * 0.65
		var samples: int = int(has_line_of_sight(observer.eye_position() + side, event.position + Vector3.UP)) + int(has_line_of_sight(observer.eye_position() - side, event.position + Vector3.UP))
		attenuation = 0.47 + float(samples) * 0.08
	var effective_range: float = float(event.range) * attenuation
	if distance > effective_range:
		return
	var jam: float = _jam_factor(event.position, observer.team)
	var strength: float = clampf(1.0 - distance / maxf(0.1, effective_range), 0.0, 1.0)
	var confidence: float = clampf((0.24 + strength * 0.68) * float(event.intensity), 0.12, 0.98)
	confidence *= 1.0 - jam * 0.40
	if distance < 3.5 and visible:
		confidence = maxf(confidence, 0.91 - jam * 0.1)
	if event.category in ["shot", "trap", "extraction"] and visible:
		confidence = maxf(confidence, 0.71)
	if not visible:
		confidence = minf(confidence, 0.46)
	var uncertainty: float = maxf(0.08, (1.0 - confidence) * 3.4) * float(event.uncertainty)
	if not visible:
		uncertainty += 2.8
	var estimate: Vector3 = event.position if visible and confidence >= 0.60 else _uncertain_position(event.position, observer.actor_id, int(event.id), uncertainty)
	if observer == game.get_observer():
		_play_audio(event.category, estimate, float(event.intensity) * (0.35 + strength * 0.65) * attenuation)
		_spawn_ring(estimate, event.category, clampf(float(event.range) * 0.16, 0.55, 4.0), 0.52, (0.25 + confidence * 0.55) if visible else 0.22)
	if int(event.team) == observer.team or int(event.source_id) == observer.actor_id or int(event.team) < 0:
		return
	_record(observer, int(event.source_id), int(event.team), estimate, confidence, event.category, visible, float(event.hold))

func _record(observer, target_id: int, target_team: int, estimate: Vector3, strength: float, category: String, visible: bool, hold: float) -> void:
	if not memories.has(observer.actor_id):
		memories[observer.actor_id] = {}
	var collection: Dictionary = memories[observer.actor_id]
	var previous: Dictionary = collection.get(target_id, {})
	var previous_confidence: float = float(previous.get("confidence", 0.0))
	var confidence: float = maxf(strength, previous_confidence * 0.7 + strength * 0.38)
	if not visible:
		confidence = minf(confidence, 0.49)
	confidence = clampf(confidence, 0.0, 1.0)
	var record: Dictionary = {
		"target_id": target_id, "position": estimate, "confidence": confidence,
		"state": _state(confidence, visible), "age": 0.0,
		"category": category, "confirmed": visible and confidence >= 0.84,
		"team": target_team, "visible": visible and confidence >= 0.60,
		"updated_at": clock, "hold_until": clock + hold, "shared": false
	}
	collection[target_id] = record
	memories[observer.actor_id] = collection
	# Approximate radio callouts have their own reduced confidence and frozen point.
	var share_key: String = "%d:%d" % [observer.actor_id, target_id]
	if confidence >= 0.55 and clock - float(_share_stamps.get(share_key, -10.0)) > 1.1:
		_share_stamps[share_key] = clock
		for ally in game.actors:
			if not _is_active(ally) or ally == observer or ally.team != observer.team:
				continue
			if not memories.has(ally.actor_id):
				memories[ally.actor_id] = {}
			var ally_memories: Dictionary = memories[ally.actor_id]
			var existing: Dictionary = ally_memories.get(target_id, {})
			if float(existing.get("confidence", 0.0)) >= 0.48:
				continue
			var shared: Dictionary = record.duplicate(true)
			shared.position = Vector3(snappedf(estimate.x, 2.5), estimate.y, snappedf(estimate.z, 2.5))
			shared.confidence = minf(0.48, confidence * 0.55)
			shared.state = 2 if shared.confidence >= 0.30 else 1
			shared.confirmed = false
			shared.visible = false
			shared.shared = true
			shared.hold_until = clock
			ally_memories[target_id] = shared
			memories[ally.actor_id] = ally_memories

func _decay_memories(delta: float) -> void:
	for observer in game.actors:
		if not is_instance_valid(observer) or not memories.has(observer.actor_id):
			continue
		var collection: Dictionary = memories[observer.actor_id]
		for target_id in collection.keys():
			var record: Dictionary = collection[target_id]
			record.age = clock - float(record.updated_at)
			var within_hold: bool = clock <= float(record.hold_until)
			var decay: float = 0.11 if within_hold else float(_settings().get("decay", 0.30))
			if bool(record.shared):
				decay = 0.16
			record.confidence = maxf(0.0, float(record.confidence) - delta * decay)
			var target = _actor_by_id(int(target_id))
			var can_reconstruct: bool = false
			if _is_active(target) and within_hold and not bool(record.shared) and float(record.confidence) >= 0.60:
				can_reconstruct = has_line_of_sight(observer.eye_position(), target.eye_position())
				if can_reconstruct:
					record.position = target.global_position
			record.visible = can_reconstruct
			record.confirmed = can_reconstruct and float(record.confidence) >= 0.84
			record.state = _state(float(record.confidence), can_reconstruct)
			if float(record.confidence) <= 0.035 or float(record.age) > 6.0:
				collection.erase(target_id)
			else:
				collection[target_id] = record

func _update_reconstructions() -> void:
	var observer = game.get_observer()
	if observer == null or not is_instance_valid(observer):
		return
	for target in game.actors:
		if not is_instance_valid(target) or target == observer:
			continue
		if target.team == observer.team:
			target.set_reconstruction(1.0)
			continue
		var contact: Dictionary = contact_for(observer, target.actor_id)
		var visibility: float = 0.0
		if not contact.is_empty() and bool(contact.get("visible", false)):
			visibility = float(contact.confidence)
		target.set_reconstruction(visibility)

func _state(confidence: float, visible: bool) -> int:
	if visible and confidence >= 0.84:
		return 4
	if visible and confidence >= 0.60:
		return 3
	if confidence >= 0.30:
		return 2
	if confidence >= 0.06:
		return 1
	return 0

func _uncertain_position(origin: Vector3, observer_id: int, event_id: int, uncertainty: float) -> Vector3:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = absi(observer_id * 73856093 + event_id * 19349663)
	var angle: float = generator.randf_range(0.0, TAU)
	var distance: float = generator.randf_range(uncertainty * 0.45, uncertainty)
	return origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

func _spawn_ring(origin: Vector3, category: String, radius: float, duration: float, opacity: float) -> void:
	if DisplayServer.get_name() == "headless" or radius < 0.01:
		return
	if effects.size() >= MAX_EFFECTS:
		var oldest: Dictionary = effects.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _occluded_wave_mesh(origin, radius)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = RingShader
	var color: Color = Color(0.2, 0.95, 0.84, 1.0)
	if category in ["shot", "trap", "extraction"]:
		color = Color(1.0, 0.65, 0.35, 1.0)
	elif category == "ping":
		color = Color(0.55, 0.88, 1.0, 1.0)
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("width", 0.09 if category == "ping" else 0.07)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = origin + Vector3.UP * 0.035
	mesh.scale = Vector3.ONE * (radius + 0.3)
	effects.append({"node": mesh, "material": material, "age": 0.0, "duration": maxf(duration, 0.1), "radius": radius, "opacity": opacity * clampf(float(game.settings.get("wave_intensity", 1.0)), 0.3, 1.5), "origin": origin})

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.age += delta
		if float(effect.age) >= float(effect.duration) or not is_instance_valid(effect.node):
			if is_instance_valid(effect.node):
				effect.node.queue_free()
			effects.remove_at(i)
			continue
		var progress: float = float(effect.age) / float(effect.duration)
		effect.material.set_shader_parameter("radius", lerpf(0.06, 0.94, progress))
		effect.material.set_shader_parameter("opacity", float(effect.opacity) * pow(1.0 - progress, 0.7))

func _play_audio(category: String, origin: Vector3, intensity: float) -> void:
	if game.audio != null:
		game.audio.play_event(category, origin, intensity)

func _observer_near(origin: Vector3, radius: float) -> bool:
	var observer = game.get_observer()
	return observer != null and is_instance_valid(observer) and observer.global_position.distance_to(origin) <= radius

func _jam_factor(position: Vector3, team: int) -> float:
	if game.gadgets != null:
		return float(game.gadgets.jam_factor(position, team))
	return 0.0

func _source_id(source) -> int:
	if source == null or not is_instance_valid(source):
		return -100000 - event_sequence
	var id = source.get("actor_id")
	return int(id) if id != null else -int(source.get_instance_id())

func _source_team(source) -> int:
	if source == null or not is_instance_valid(source):
		return -1
	var team = source.get("team")
	return int(team) if team != null else -1

func _source_position(source) -> Vector3:
	if source != null and is_instance_valid(source) and source is Node3D:
		return source.global_position
	return Vector3.ZERO

func _is_active(actor) -> bool:
	return actor != null and is_instance_valid(actor) and bool(actor.get("alive")) and not bool(actor.get("extracted"))

func _actor_by_id(actor_id: int):
	for actor in game.actors:
		if is_instance_valid(actor) and actor.actor_id == actor_id:
			return actor
	return null

func _normalize_category(category: String) -> String:
	match category:
		"fire", "shoot", "rifle", "gunshot": return "shot"
		"run", "running", "footstep_sprint": return "sprint"
		"step", "footstep", "footstep_walk": return "walk"
		"crouched", "footstep_crouch": return "crouch"
		"landing", "reception": return "land"
		"deploy", "placement": return "gadget"
	return category

func _settings() -> Dictionary:
	var balance = game.get("balance") if game != null else null
	return balance.get("acoustics", {}) if balance is Dictionary else {}

func _wave_speed() -> float:
	return maxf(5.0, float(_settings().get("ping_speed", SPEED_OF_RECOGNITION)))

func _occluded_wave_mesh(origin: Vector3, radius: float) -> ArrayMesh:
	# A clipped radial fan prevents wave fragments appearing beyond opaque walls.
	# Shader coordinates stay normalized so one ring material handles every size.
	var count: int = 64 if radius > 10.0 else 32
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var rim: PackedVector3Array = PackedVector3Array()
	var sample_origin: Vector3 = origin + Vector3.UP * 0.18
	for i in range(count + 1):
		var angle: float = TAU * float(i) / float(count)
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(sample_origin, sample_origin + direction * radius, 1)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
		var distance: float = radius
		if not hit.is_empty():
			distance = maxf(0.01, sample_origin.distance_to(hit.position) - 0.08)
		rim.append(direction * minf(1.0, distance / maxf(radius, 0.01)))
	for i in range(count):
		vertices.append(Vector3.ZERO)
		vertices.append(rim[i + 1])
		vertices.append(rim[i])
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
