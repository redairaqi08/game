extends Node3D
## Six faction devices. Their sounds pass through the same acoustic service as actors.

const NAMES: Dictionary = {"decoy": "Écho errant", "veil": "Voile muet", "thorn": "Épine d’écoute", "ear": "Oreille de pierre", "bell": "Cloche brisée", "choir": "Chœur de cristal"}
const TRIGGER_RADIUS: Dictionary = {"thorn": 3.0, "ear": 4.0, "bell": 2.5}
var game
var devices: Array = []
var device_sequence: int = 0
var _clock: float = 0.0
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
var _preview_slot: int = -1
var _preview_position: Vector3 = Vector3.ZERO
var _preview_valid: bool = false

class Device:
	extends StaticBody3D
	var manager
	var owner_actor
	var actor_id: int = -1
	var team: int = -1
	var kind: String = ""
	var health: float = 35.0
	var age: float = 0.0
	var life: float = 1200.0
	var next_pulse: float = 0.6
	var direction: Vector3 = Vector3.FORWARD
	var alive: bool = true
	var extracted: bool = false
	var visual: Node3D
	var glow_material: StandardMaterial3D
	var route: Array = []
	var trigger_radius: float = 0.0
	func take_damage(amount: float, _source, _headshot: bool = false) -> void:
		if not alive:
			return
		health -= amount
		if health <= 0.0:
			manager.destroy_device(self, true)
	func eye_position() -> Vector3:
		return global_position + Vector3.UP * 0.25

func setup(game_ref) -> void:
	game = game_ref
	_create_preview()

func clear() -> void:
	for device in devices:
		if is_instance_valid(device):
			device.alive = false
			device.queue_free()
	devices.clear()
	device_sequence = 0
	_clock = 0.0
	_preview_slot = -1
	if is_instance_valid(_preview):
		_preview.visible = false

func deploy(actor, slot: int) -> bool:
	if not _active(actor) or game.phase != "playing" or slot < 0 or slot >= actor.gadget_loadout.size():
		return false
	if slot >= actor.gadget_used.size() or bool(actor.gadget_used[slot]):
		if actor.is_human:
			game.notify("Dispositif déjà utilisé cette manche")
		return false
	var kind: String = str(actor.gadget_loadout[slot])
	if not NAMES.has(kind):
		return false
	var attack: bool = actor.team == game.attacker_team
	if (kind in ["decoy", "veil", "thorn"]) != attack:
		return false
	var placement: Dictionary = placement_for(actor, kind)
	if not bool(placement.valid):
		if actor.is_human:
			game.notify("Placement impossible · visez un sol libre")
		return false
	if devices.size() >= 18:
		return false
	var origin: Vector3 = placement.position
	for existing in devices:
		if is_instance_valid(existing) and existing.global_position.distance_to(origin) < 0.75:
			if actor.is_human:
				game.notify("Un dispositif occupe déjà cet emplacement")
			return false
	var device: Device = Device.new()
	device_sequence += 1
	device.name = "AcousticDevice_%d" % device_sequence
	device.manager = self
	device.owner_actor = actor
	device.actor_id = -1000 - device_sequence
	device.team = actor.team
	device.kind = kind
	device.direction = actor.aim_direction
	device.direction.y = 0.0
	if device.direction.length_squared() < 0.01:
		device.direction = Vector3.FORWARD
	device.direction = device.direction.normalized()
	device.trigger_radius = float(_settings().get(kind + "_radius", TRIGGER_RADIUS.get(kind, 0.0)))
	device.collision_layer = 4
	device.collision_mask = 0
	add_child(device)
	device.global_position = origin + Vector3.UP * 0.035
	_build_device(device)
	match kind:
		"decoy":
			device.life = float(_settings().get("decoy_duration", 6.0)) + 0.2
			device.next_pulse = 0.6
			_build_decoy_route(device)
		"veil":
			device.life = float(_settings().get("veil_duration", 5.0))
			device.next_pulse = 0.1
		"choir":
			device.life = float(_settings().get("choir_duration", 10.0)) + 0.5
			device.next_pulse = 1.0
		_:
			device.life = 1200.0
			device.next_pulse = 0.7
	devices.append(device)
	actor.gadget_used[slot] = true
	actor.stats["gadgets"] = int(actor.stats.get("gadgets", 0)) + 1
	game.acoustics.emit_sound(actor, "gadget", origin)
	if actor.is_human:
		game.notify("%s déployé" % NAMES[kind])
	return true

func placement_for(actor, kind: String) -> Dictionary:
	var start: Vector3 = actor.eye_position()
	var direction: Vector3 = actor.aim_direction.normalized()
	var reach: float = 18.0 if kind == "decoy" else (8.0 if kind == "veil" else 3.0)
	var horizontal: Vector3 = direction
	horizontal.y = 0.0
	if horizontal.length_squared() < 0.01:
		horizontal = Vector3.FORWARD
	horizontal = horizontal.normalized()
	var desired: Vector3 = actor.global_position + horizontal * reach
	# A throw stops on the near side of an obstacle instead of teleporting through it.
	var block: Dictionary = _ray(start, desired + Vector3.UP * 0.65)
	if not block.is_empty():
		desired = block.position - horizontal * 0.55
	var aimed: Dictionary = _ray(start, start + direction * reach)
	if not aimed.is_empty() and aimed.normal.y > 0.7:
		desired = aimed.position
	var ground: Dictionary = _ray(desired + Vector3.UP * 2.0, desired + Vector3.DOWN * 5.0)
	if ground.is_empty() or ground.normal.y < 0.7:
		return {"valid": false, "position": desired}
	var point: Vector3 = ground.position
	if actor.global_position.distance_to(point) > reach + 1.0:
		return {"valid": false, "position": point}
	# Check actual world occupancy; tiny devices never block player navigation.
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.20
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.24)
	query.collision_mask = 1 | 4
	var occupied: bool = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	return {"valid": not occupied, "position": point}

func jam_factor(position: Vector3, observer_team: int) -> float:
	var factor: float = 0.0
	for device in devices:
		if not is_instance_valid(device) or not device.alive or device.kind != "veil" or device.team == observer_team:
			continue
		var distance: float = device.global_position.distance_to(position)
		var radius: float = float(_settings().get("veil_radius", 6.0))
		if distance < radius:
			factor = maxf(factor, clampf((radius - distance) / 2.5, 0.0, 1.0))
	return factor

func destroy_device(device, violent: bool = false) -> void:
	if not is_instance_valid(device) or not device.alive:
		return
	device.alive = false
	if violent and game.acoustics != null:
		game.acoustics.emit_sound(device, "impact", device.global_position, {"range": 12.0})
		if _observer_near(device.global_position, 12.0):
			game.notify("Dispositif brisé")
	devices.erase(device)
	device.queue_free()

func _physics_process(delta: float) -> void:
	if game == null or game.phase != "playing":
		if is_instance_valid(_preview):
			_preview.visible = false
		return
	_clock += delta
	_update_preview()
	for device in devices.duplicate():
		if not is_instance_valid(device) or not device.alive:
			continue
		device.age += delta
		if device.age > device.life:
			destroy_device(device)
			continue
		if is_instance_valid(device.visual):
			device.visual.rotation.y += delta * (0.7 if device.kind == "choir" else 0.18)
		if device.glow_material != null:
			device.glow_material.emission_energy_multiplier = 0.8 + sin(_clock * 4.0) * 0.25
		if device.kind in ["thorn", "ear", "bell"] and device.age >= 0.7:
			_check_trigger(device)
		elif device.kind == "decoy" and device.age >= device.next_pulse:
			device.next_pulse += 0.31
			var progress: float = clampf((device.age - 0.6) / maxf(0.1, device.life - 0.9), 0.0, 1.0)
			var position: Vector3 = _decoy_position(device, progress)
			game.acoustics.emit_sound(device, "sprint", position, {"range": 20.0, "source_id": device.actor_id, "team": device.team})
		elif device.kind == "veil" and device.age >= device.next_pulse:
			device.next_pulse += 1.2
			if _observer_near(device.global_position, 11.0):
				game.audio.play_event("veil", device.global_position, 0.35)
		elif device.kind == "choir" and device.age >= device.next_pulse:
			device.next_pulse += 2.4
			var receiver = device.owner_actor
			if not _active(receiver):
				# Deployed equipment keeps supporting surviving allies after its owner falls.
				var nearest_distance: float = INF
				for ally in game.actors:
					if _active(ally) and ally.team == device.team:
						var distance: float = ally.global_position.distance_to(device.global_position)
						if distance < nearest_distance:
							receiver = ally
							nearest_distance = distance
			if _active(receiver):
				game.acoustics.sensor_ping(receiver, device.global_position, float(_settings().get("choir_radius", 9.0)))

func _check_trigger(device) -> void:
	for target in game.actors:
		if not _active(target) or target.team == device.team:
			continue
		if target.global_position.distance_to(device.global_position) > device.trigger_radius:
			continue
		# Thin walls and floors cannot trigger a trap from another room.
		if not game.acoustics.has_line_of_sight(device.global_position + Vector3.UP * 0.3, target.eye_position()):
			continue
		var duration: float = 2.5 if device.kind == "bell" else 3.0
		game.acoustics.emit_sound(target, "trap", target.global_position, {"range": 26.0, "hold": duration})
		for ally in game.actors:
			if _active(ally) and ally.team == device.team:
				game.acoustics.reveal(ally, target, device.global_position, duration)
		game.notify("%s déclenché · %s" % [NAMES[device.kind], game.level.get_zone(device.global_position)], device.team)
		if target.is_human:
			game.notify("Piège déclenché · votre écho est exposé !")
		destroy_device(device)
		return

func _build_decoy_route(device) -> void:
	var origin: Vector3 = device.global_position
	device.route.append(origin)
	var forward: Vector3 = device.direction
	var side: Vector3 = forward.cross(Vector3.UP)
	var candidate: Vector3 = origin + forward * 7.0 + side * 2.0
	var first: Dictionary = _ray(origin + Vector3.UP * 0.4, candidate + Vector3.UP * 0.4)
	if not first.is_empty():
		candidate = first.position - forward * 0.5
		candidate.y = origin.y
	device.route.append(candidate)
	var second: Vector3 = candidate + side * 5.0 + forward * 2.0
	var block: Dictionary = _ray(candidate + Vector3.UP * 0.4, second + Vector3.UP * 0.4)
	if not block.is_empty():
		second = block.position - side * 0.5
		second.y = origin.y
	device.route.append(second)

func _decoy_position(device, progress: float) -> Vector3:
	if device.route.size() < 3:
		return device.global_position
	if progress <= 0.60:
		return device.route[0].lerp(device.route[1], progress / 0.60)
	return device.route[1].lerp(device.route[2], (progress - 0.60) / 0.40)

func _build_device(device) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 0.38
	collision.shape = shape
	collision.position.y = 0.19
	device.add_child(collision)
	device.visual = Node3D.new()
	device.add_child(device.visual)
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color(0.12, 0.15, 0.17)
	stone.metallic = 0.6
	stone.roughness = 0.35
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.25, 0.78, 0.73) if device.team == 0 else Color(0.85, 0.52, 0.28)
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 1.0
	device.glow_material = glow
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.16
	base_mesh.bottom_radius = 0.25
	base_mesh.height = 0.12
	base_mesh.radial_segments = 6
	base.mesh = base_mesh
	base.material_override = stone
	base.position.y = 0.09
	device.visual.add_child(base)
	var spike_count: int = 5 if device.kind == "choir" else (3 if device.kind in ["thorn", "ear"] else 1)
	for i in range(spike_count):
		var spike: MeshInstance3D = MeshInstance3D.new()
		var crystal: CylinderMesh = CylinderMesh.new()
		crystal.top_radius = 0.0
		crystal.bottom_radius = 0.08 if spike_count > 1 else 0.14
		crystal.height = 0.26 + float(i % 2) * 0.10
		crystal.radial_segments = 5
		spike.mesh = crystal
		spike.material_override = glow
		var angle: float = float(i) / float(spike_count) * TAU
		spike.position = Vector3(cos(angle) * 0.13 if spike_count > 1 else 0.0, 0.26, sin(angle) * 0.13 if spike_count > 1 else 0.0)
		device.visual.add_child(spike)
	if device.kind == "veil":
		var field: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = float(_settings().get("veil_radius", 6.0))
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 32
		sphere.rings = 12
		field.mesh = sphere
		var field_material: ShaderMaterial = ShaderMaterial.new()
		field_material.shader = load("res://shaders/acoustic_veil.gdshader")
		field.material_override = field_material
		field.position.y = -0.8
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		device.add_child(field)

func _create_preview() -> void:
	_preview = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.24
	cylinder.bottom_radius = 0.3
	cylinder.height = 0.10
	cylinder.radial_segments = 24
	_preview.mesh = cylinder
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.no_depth_test = false
	_preview.material_override = _preview_material
	_preview.visible = false
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)

func _update_preview() -> void:
	if not is_instance_valid(_preview):
		return
	_preview.visible = false
	var actor = game.human
	if not _active(actor) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Hold the gadget key for a live validity preview; release/actor input deploys.
	var slot: int = 0 if Input.is_action_pressed("gadget_primary") else (1 if Input.is_action_pressed("gadget_secondary") else -1)
	if slot < 0 or slot >= actor.gadget_loadout.size() or bool(actor.gadget_used[slot]):
		return
	var placement: Dictionary = placement_for(actor, str(actor.gadget_loadout[slot]))
	_preview.global_position = placement.position + Vector3.UP * 0.08
	_preview_material.albedo_color = Color(0.2, 0.95, 0.6, 0.4) if placement.valid else Color(1.0, 0.25, 0.2, 0.4)
	_preview.visible = true

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _observer_near(position: Vector3, radius: float) -> bool:
	var observer = game.get_observer()
	return observer != null and is_instance_valid(observer) and observer.global_position.distance_to(position) <= radius

func _active(actor) -> bool:
	return actor != null and is_instance_valid(actor) and bool(actor.get("alive")) and not bool(actor.get("extracted"))

func _settings() -> Dictionary:
	var balance = game.get("balance") if game != null else null
	return balance.get("gadgets", {}) if balance is Dictionary else {}
