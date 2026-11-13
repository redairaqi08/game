extends CharacterBody3D
## A single physical actor accepts human or bot commands. Presentation never
## disables its hitbox, and actions all pass through the same acoustic service.
const VESPERID = preload("res://scripts/vesperid.gd")
const VIEWMODEL = preload("res://scripts/viewmodel.gd")

var game
var actor_id: int = -1
var team: int = 0
var is_human: bool = false
var alive: bool = true
var extracted: bool = false
var health: float = 100.0
var ammo: int = 20
var reserve: int = 80
var weapon_index: int = 0
var reload_left: float = 0.0
var ping_cooldown: float = 0.0
var camera: Camera3D
var visual: Node3D
var aim_direction: Vector3 = Vector3.FORWARD
var command_interact: bool = false
var extraction_progress: float = 0.0
var stats: Dictionary = {"kills": 0, "damage": 0.0, "pings": 0, "gadgets": 0, "extractions": 0, "shots": 0, "hits": 0}
var gadget_loadout: Array = ["decoy", "thorn"]
var gadget_used: Array = [false, false]
var stance: String = "walk"
var display_name: String = "Vesperide"
var damage_direction: Vector3 = Vector3.ZERO
var damage_flash: float = 0.0
var hitmarker_left: float = 0.0
var last_hit_headshot: bool = false
var last_shot_time: float = -100.0

var _collision: CollisionShape3D
var _shape: CapsuleShape3D
var _camera_pivot: Node3D
var _viewmodel: Node3D
var _command_move: Vector3 = Vector3.ZERO
var _command_look: Vector3 = Vector3.FORWARD
var _command_fire: bool = false
var _command_aim: bool = false
var _command_sprint: bool = false
var _command_crouch: bool = false
var _command_jump: bool = false
var _command_reload: bool = false
var _command_ping: bool = false
var _command_gadget: int = -1
var _fire_left: float = 0.0
var _reload_duration: float = 1.8
var _step_left: float = 0.35
var _slide_left: float = 0.0
var _slide_cooldown: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var _previous_crouch: bool = false
var _previous_grounded: bool = true
var _airtime: float = 0.0
var _jump_cooldown: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _camera_recoil: float = 0.0
var _eye_height: float = 1.58
var _bob_phase: float = 0.0
var _spectating: bool = false
var _weapon_magazines: Array[int] = [20, 10]
var _weapon_reserves: Array[int] = [80, 40]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shot_effects: Array = []
var _mantle_points: Array[Vector3] = []
var _mantle_cooldown: float = 0.0

func setup(game_ref, id: int, team_id: int, human_controlled: bool, spawn: Vector3) -> void:
	game = game_ref
	actor_id = id
	team = team_id
	is_human = human_controlled
	name = "Vesperid_%d" % actor_id
	display_name = "VOUS" if is_human else ["AËL", "SILEX", "ORIN", "NACRE", "VAEL", "IRIS"][posmod(actor_id, 6)]
	_rng.seed = actor_id * 1051 + 74
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(48.0)
	max_slides = 6
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.32
	_shape.height = 1.8
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)
	_collision.position.y = 0.9
	global_position = spawn + Vector3(0, 0.04, 0)
	visual = VESPERID.new()
	add_child(visual)
	visual.build(team)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "Eye"
	add_child(_camera_pivot)
	_camera_pivot.position.y = _eye_height
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.035
	camera.far = 260.0
	camera.fov = float(game.settings.get("fov", 86.0))
	camera.cull_mask = 0xFFFFFFFF if is_human else (0xFFFFFFFF & ~8)
	_camera_pivot.add_child(camera)
	camera.current = is_human
	if is_human:
		_viewmodel = VIEWMODEL.new()
		camera.add_child(_viewmodel)
		_viewmodel.build(team)
		visual.visible = false
	else:
		visual.set_reconstruction(0.0, true)
	var toward_center: Vector3 = Vector3(-spawn.x, 0.0, -spawn.z).normalized()
	_yaw = atan2(-toward_center.x, -toward_center.z)
	rotation.y = _yaw
	aim_direction = -global_basis.z
	_command_look = aim_direction
	var rifle: Dictionary = _weapon_data(0)
	var pistol: Dictionary = _weapon_data(1)
	_weapon_magazines = [int(rifle.mag), int(pistol.mag)]
	_weapon_reserves = [int(rifle.reserve), int(pistol.reserve)]
	ammo = _weapon_magazines[0]
	reserve = _weapon_reserves[0]

func _movement_value(key: String, fallback: float) -> float:
	if game != null and "balance" in game:
		var movement: Dictionary = game.balance.get("movement", {})
		var aliases: Dictionary = {"walk_speed": "walk", "sprint_speed": "sprint", "crouch_speed": "crouch", "slide_speed": "slide", "aim_speed": "aim", "jump_velocity": "jump"}
		return float(movement.get(key, movement.get(aliases.get(key, key), fallback)))
	return fallback

func _weapon_data(index: int = -1) -> Dictionary:
	var selected: int = weapon_index if index < 0 else index
	var defaults: Dictionary = {"damage": 25.0, "mag": 20, "reserve": 80, "rate": 5.5, "reload": 1.8, "range": 45.0, "head_multiplier": 1.5}
	if selected == 1:
		defaults = {"damage": 20.0, "mag": 10, "reserve": 40, "rate": 4.0, "reload": 1.25, "range": 30.0, "head_multiplier": 1.5}
	if game != null and "balance" in game:
		var configured: Dictionary = game.balance.get("weapons", {}).get("rifle" if selected == 0 else "pistol", {})
		for key in configured:
			defaults[key] = configured[key]
		if configured.has("magazine"):
			defaults.mag = configured.magazine
	return defaults

func apply_command(command: Dictionary) -> void:
	_command_move = command.get("move", Vector3.ZERO)
	_command_move.y = 0.0
	_command_move = _command_move.limit_length(1.0)
	_command_look = command.get("look", aim_direction)
	_command_fire = bool(command.get("fire", false))
	_command_aim = bool(command.get("aim", false))
	_command_sprint = bool(command.get("sprint", false))
	_command_crouch = bool(command.get("crouch", false))
	_command_jump = bool(command.get("jump", false))
	_command_reload = bool(command.get("reload", false))
	_command_ping = bool(command.get("ping", false))
	command_interact = bool(command.get("interact", false))
	_command_gadget = int(command.get("gadget", -1))

func _unhandled_input(event: InputEvent) -> void:
	if not is_human or not alive or extracted or game == null:
		return
	if game.phase != "playing" or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sensitivity: float = float(game.settings.get("mouse_sensitivity", 0.0023))
		# Settings accept radians/pixel or the menu's human readable multiplier.
		if sensitivity > 0.05:
			sensitivity *= 0.0020
		var factor: float = 0.65 if _command_aim else 1.0
		_yaw -= event.relative.x * sensitivity * factor
		_pitch = clampf(_pitch - event.relative.y * sensitivity * factor, -1.42, 1.42)
		if _viewmodel != null:
			_viewmodel.add_sway(event.relative)

func _read_input() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		apply_command({})
		return
	var planar: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement: Vector3 = global_basis * Vector3(planar.x, 0, planar.y)
	_command_move = movement.limit_length(1.0)
	_command_sprint = Input.is_action_pressed("sprint")
	_command_crouch = Input.is_action_pressed("crouch")
	_command_jump = Input.is_action_just_pressed("jump")
	_command_reload = Input.is_action_just_pressed("reload")
	_command_ping = Input.is_action_just_pressed("ping")
	_command_aim = Input.is_action_pressed("aim")
	_command_fire = Input.is_action_pressed("fire") if weapon_index == 0 else Input.is_action_just_pressed("fire")
	command_interact = Input.is_action_pressed("interact")
	_command_gadget = -1
	if Input.is_action_just_released("gadget_primary"):
		_command_gadget = 0
	elif Input.is_action_just_released("gadget_secondary"):
		_command_gadget = 1
	if Input.is_action_just_pressed("weapon_1"):
		_switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_switch_weapon(1)

func _physics_process(delta: float) -> void:
	if game == null or _collision == null:
		return
	_fire_left = maxf(_fire_left - delta, 0.0)
	_slide_cooldown = maxf(_slide_cooldown - delta, 0.0)
	_jump_cooldown = maxf(_jump_cooldown - delta, 0.0)
	_mantle_cooldown = maxf(_mantle_cooldown - delta, 0.0)
	hitmarker_left = maxf(hitmarker_left - delta, 0.0)
	damage_flash = maxf(damage_flash - delta * 1.8, 0.0)
	_camera_recoil = move_toward(_camera_recoil, 0.0, delta * 0.13)
	if game.phase != "playing" or not alive or extracted:
		command_interact = false
		_command_fire = false
		velocity = Vector3.ZERO
		return
	if is_human:
		_read_input()
		rotation.y = _yaw
		camera.rotation.x = _pitch + _camera_recoil
		aim_direction = -camera.global_basis.z
	else:
		if _command_look.length_squared() > 0.01:
			aim_direction = _command_look.normalized()
			var horizontal: Vector3 = Vector3(aim_direction.x, 0.0, aim_direction.z)
			if horizontal.length_squared() > 0.01:
				rotation.y = atan2(-horizontal.x, -horizontal.z)
			camera.rotation.x = asin(clampf(aim_direction.y, -1.0, 1.0))
	if "preparation_left" in game and game.preparation_left > 0.0:
		velocity = Vector3.ZERO
		command_interact = false
		return
	_update_reload(delta)
	_move(delta)
	if _command_reload and _mantle_points.is_empty():
		_start_reload()
	if _command_ping and _mantle_points.is_empty() and game.acoustics != null:
		if game.acoustics.ping(self):
			visual.ping_flash = 1.0
			if _viewmodel != null:
				_viewmodel.ability()
	if _command_gadget >= 0 and _mantle_points.is_empty() and game.gadgets != null:
		if game.gadgets.deploy(self, _command_gadget) and _viewmodel != null:
			_viewmodel.ability()
	if _command_fire and _mantle_points.is_empty() and not command_interact and reload_left <= 0.0:
		_fire()
	_command_jump = false
	_command_reload = false
	_command_ping = false
	_command_gadget = -1

func _move(delta: float) -> void:
	if not _mantle_points.is_empty():
		_step_mantle(delta)
		return
	if is_on_floor() and _command_jump and not _command_crouch and not command_interact and _mantle_cooldown <= 0.0 and _try_mantle():
		_step_mantle(delta)
		return
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var grounded: bool = is_on_floor()
	var wants_crouch: bool = _command_crouch
	var sprinting: bool = _command_sprint and _command_move.length_squared() > 0.1 and not _command_aim and not command_interact
	if grounded and sprinting and _command_crouch and not _previous_crouch and horizontal_velocity.length() > 4.8 and _slide_cooldown <= 0.0:
		_slide_left = _movement_value("slide_duration", 0.75)
		_slide_cooldown = _movement_value("slide_recovery", 1.5)
		_slide_direction = horizontal_velocity.normalized()
		horizontal_velocity = _slide_direction * _movement_value("slide_speed", 9.5)
		_emit("slide")
	_previous_crouch = _command_crouch
	if _slide_left > 0.0:
		_slide_left = maxf(0.0, _slide_left - delta)
		wants_crouch = true
		stance = "slide"
		var steering: Vector3 = _command_move * 1.8 * delta
		_slide_direction = (_slide_direction + steering).normalized()
		var slide_speed: float = lerpf(3.8, _movement_value("slide_speed", 9.5), _slide_left / _movement_value("slide_duration", 0.75))
		horizontal_velocity = _slide_direction * slide_speed
	else:
		if not wants_crouch and _shape.height < 1.7:
			wants_crouch = not _can_stand()
		stance = "crouch" if wants_crouch else ("sprint" if sprinting else "walk")
		var desired_speed: float = _movement_value("walk_speed", 4.5)
		if wants_crouch:
			desired_speed = _movement_value("crouch_speed", 2.3)
		elif sprinting:
			desired_speed = _movement_value("sprint_speed", 7.5)
		elif _command_aim:
			desired_speed = _movement_value("aim_speed", 3.0)
		if command_interact:
			desired_speed *= 0.18
		var target: Vector3 = _command_move * desired_speed
		var acceleration: float = 32.0 if grounded else 10.0
		if _command_move.length_squared() < 0.01:
			acceleration = 36.0 if grounded else 3.0
		horizontal_velocity = horizontal_velocity.move_toward(target, acceleration * delta)
	var height: float = 1.28 if wants_crouch else 1.8
	_shape.height = height
	_collision.position.y = height * 0.5
	_eye_height = move_toward(_eye_height, 1.10 if wants_crouch else 1.58, delta * 5.2)
	if grounded:
		if not _previous_grounded and _airtime > 0.15:
			_emit("land", {"intensity": clampf(_airtime * 1.1, 0.5, 1.5)})
		_airtime = 0.0
		if _command_jump and _jump_cooldown <= 0.0 and not command_interact and _can_stand():
			velocity.y = _movement_value("jump_velocity", 5.6)
			_jump_cooldown = 0.5
			_slide_left = 0.0
			_emit("jump")
		else:
			velocity.y = -0.5
	else:
		_airtime += delta
		velocity.y -= _movement_value("gravity", 19.0) * delta
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	_previous_grounded = grounded
	move_and_slide()
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.9 and _slide_left <= 0.0:
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = 0.76 if stance == "crouch" else (0.30 if stance == "sprint" else 0.52)
			_emit(stance)
	else:
		_step_left = minf(_step_left, 0.22)

func _try_mantle() -> bool:
	# Validate an actual low ledge and both swept body motions before starting.
	# Moving collision bodies can still abort the action safely during the climb.
	if _shape.height < 1.7:
		return false
	var forward: Vector3 = Vector3(aim_direction.x, 0.0, aim_direction.z).normalized()
	if forward.length_squared() < 0.5:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var face_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.45, global_position + Vector3.UP * 0.45 + forward * 0.95, 1, [get_rid()])
	var face: Dictionary = space.intersect_ray(face_query)
	if face.is_empty() or absf(Vector3(face.normal).y) > 0.3:
		return false
	var landing_xz: Vector3 = global_position + forward * 1.10
	var top_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(landing_xz + Vector3.UP * 1.30, landing_xz + Vector3.UP * 0.24, 1, [get_rid()])
	var top: Dictionary = space.intersect_ray(top_query)
	if top.is_empty() or Vector3(top.normal).y < 0.85:
		return false
	var height: float = float(top.position.y) - global_position.y
	if height < 0.30 or height > 1.12:
		return false
	var destination: Vector3 = Vector3(top.position) + Vector3.UP * 0.07
	var above: Vector3 = global_position + Vector3.UP * (height + 0.07)
	var occupied: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	occupied.shape = _shape
	occupied.transform = Transform3D(global_basis, destination + Vector3.UP * 0.9)
	occupied.collision_mask = 3
	occupied.exclude = [get_rid()]
	if not space.intersect_shape(occupied, 1).is_empty():
		return false
	if test_move(global_transform, above - global_position):
		return false
	var elevated: Transform3D = global_transform
	elevated.origin = above
	if test_move(elevated, destination - above):
		return false
	_mantle_points.assign([above, destination])
	_mantle_cooldown = 1.0
	_slide_left = 0.0
	command_interact = false
	velocity = Vector3.ZERO
	stance = "mantle"
	_emit("jump", {"range": 12.0})
	if _viewmodel != null:
		_viewmodel.ability()
	return true

func _step_mantle(delta: float) -> void:
	if _mantle_points.is_empty():
		return
	stance = "mantle"
	command_interact = false
	velocity = Vector3.ZERO
	var motion: Vector3 = (_mantle_points[0] - global_position).limit_length(7.0 * delta)
	var collision: KinematicCollision3D = move_and_collide(motion)
	if collision != null:
		_mantle_points.clear()
		stance = "walk"
		return
	if global_position.distance_squared_to(_mantle_points[0]) < 0.0004:
		_mantle_points.pop_front()
		if _mantle_points.is_empty():
			_emit("land", {"intensity": 0.65})
			stance = "walk"

func _can_stand() -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var probe: CapsuleShape3D = CapsuleShape3D.new()
	probe.radius = 0.30
	probe.height = 1.76
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.91, 0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func eye_position() -> Vector3:
	if camera != null:
		return camera.global_position
	return global_position + Vector3(0, 1.58, 0)

func _emit(category: String, overrides: Dictionary = {}) -> void:
	if game != null and game.acoustics != null:
		game.acoustics.emit_sound(self, category, Vector3.INF, overrides)

func _start_reload() -> void:
	if reload_left > 0.0 or reserve <= 0 or ammo >= int(_weapon_data().mag):
		return
	_reload_duration = float(_weapon_data().reload)
	reload_left = _reload_duration
	command_interact = false
	_emit("reload")

func _update_reload(delta: float) -> void:
	if reload_left <= 0.0:
		return
	reload_left -= delta
	if reload_left <= 0.0:
		reload_left = 0.0
		var needed: int = int(_weapon_data().mag) - ammo
		var transfer: int = mini(needed, reserve)
		ammo += transfer
		reserve -= transfer
		_weapon_magazines[weapon_index] = ammo
		_weapon_reserves[weapon_index] = reserve

func _switch_weapon(index: int) -> void:
	if index == weapon_index or index < 0 or index > 1:
		return
	_weapon_magazines[weapon_index] = ammo
	_weapon_reserves[weapon_index] = reserve
	weapon_index = index
	ammo = _weapon_magazines[index]
	reserve = _weapon_reserves[index]
	reload_left = 0.0
	_fire_left = maxf(_fire_left, 0.28)
	if _viewmodel != null:
		_viewmodel.switch_weapon(index)

func _fire() -> void:
	if _fire_left > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	var weapon: Dictionary = _weapon_data()
	_fire_left = 1.0 / float(weapon.rate)
	ammo -= 1
	_weapon_magazines[weapon_index] = ammo
	stats.shots = int(stats.shots) + 1
	last_shot_time = float(game.elapsed)
	_emit("shot" if weapon_index == 0 else "pistol")
	visual.shot_flash = 1.0
	if _viewmodel != null:
		_viewmodel.fire()
		_camera_recoil = minf(0.055, _camera_recoil + (0.012 if _command_aim else 0.019))
	var origin: Vector3 = eye_position()
	var direction: Vector3 = aim_direction.normalized()
	var speed: float = Vector2(velocity.x, velocity.z).length()
	# Human skill controls the shot; a small moving hip-fire cone is bounded.
	var spread: float = (0.0025 if _command_aim else 0.008) + (0.007 if speed > 5.0 else 0.0)
	if stance == "crouch":
		spread *= 0.6
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(direction).normalized()
	direction = (direction + right * _rng.randf_range(-spread, spread) + up * _rng.randf_range(-spread, spread)).normalized()
	var destination: Vector3 = origin + direction * float(weapon.range)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination, 7, [get_rid()])
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var hit: Vector3 = destination
	if not result.is_empty():
		hit = result.position
		var collider = result.collider
		if collider != null and collider.has_method("take_damage"):
			var headshot: bool = false
			if "actor_id" in collider:
				headshot = hit.y - collider.global_position.y > collider._shape.height * 0.78
				# Friendly actors block a shot, but cannot damage their own team.
				if collider.team != team and collider.alive and not collider.extracted:
					var dealt: float = float(weapon.damage) * (float(weapon.head_multiplier) if headshot else 1.0)
					collider.take_damage(dealt, self, headshot)
					stats.hits = int(stats.hits) + 1
					hitmarker_left = 0.18
					last_hit_headshot = headshot
			else:
				collider.take_damage(float(weapon.damage), self)
		game.acoustics.emit_sound(null, "impact", hit, {"range": 12.0, "intensity": 0.6})
	_draw_shot(origin + direction * 0.7, hit, not result.is_empty())

func _draw_shot(from: Vector3, to: Vector3, impact: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var effect_root: Node3D = Node3D.new()
	game.add_child(effect_root)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("6edcdd") if team == 0 else Color("ffc473")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.007
	mesh.bottom_radius = 0.007
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 4
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.material_override = material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect_root.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	if from.distance_squared_to(to) > 0.01:
		tracer.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	if impact:
		var spark: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.06
		sphere.height = 0.12
		sphere.radial_segments = 6
		sphere.rings = 3
		spark.mesh = sphere
		spark.material_override = material
		effect_root.add_child(spark)
		spark.global_position = to
	var tween: Tween = effect_root.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.09)
	tween.tween_callback(effect_root.queue_free)

func take_damage(amount: float, source, headshot: bool = false) -> void:
	if not alive or extracted or amount <= 0.0:
		return
	if source != null and "team" in source and source.team == team:
		return
	var minimum_health: float = 25.0 if str(game.settings.get("mode", "")) == "tutorial" and not is_human else 0.0
	var previous_health: float = health
	health = maxf(minimum_health, health - amount)
	var applied: float = previous_health - health
	damage_flash = 1.0
	visual.damage_flash = 1.0
	if source != null and is_instance_valid(source):
		damage_direction = source.global_position - global_position
		if "stats" in source:
			source.stats.damage = float(source.stats.damage) + applied
	if game != null:
		game.on_actor_hit(source, self, applied, headshot)
		if game.audio != null:
			game.audio.play_event("hit", global_position, 0.8)
	if health <= 0.0:
		alive = false
		command_interact = false
		reload_left = 0.0
		velocity = Vector3.ZERO
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		if _viewmodel != null:
			_viewmodel.visible = false
		if source != null and is_instance_valid(source) and "stats" in source:
			source.stats.kills = int(source.stats.kills) + 1
		game.on_actor_died(self, source)

func set_reconstruction(confidence: float) -> void:
	if visual == null:
		return
	if is_human and not _spectating:
		visual.visible = false
		return
	var observer = game.get_observer() if game != null and game.has_method("get_observer") else null
	var allied: bool = observer != null and observer.team == team
	visual.set_contrast(float(game.settings.get("silhouette_contrast", 1.0)))
	visual.set_reconstruction(1.0 if allied else confidence, not allied)
	if extracted or _spectating:
		visual.visible = false

func set_spectating(value: bool) -> void:
	_spectating = value
	if camera != null:
		camera.current = value
		camera.cull_mask = 0xFFFFFFFF
	if value and _viewmodel == null:
		_viewmodel = VIEWMODEL.new()
		camera.add_child(_viewmodel)
		_viewmodel.build(team)
		_viewmodel.switch_weapon(weapon_index)
	if _viewmodel != null:
		_viewmodel.visible = value and alive and not extracted
	if visual != null:
		visual.visible = not value

func _process(delta: float) -> void:
	if game == null or visual == null:
		return
	var speed: float = Vector2(velocity.x, velocity.z).length()
	visual.animate(delta, velocity, stance, _command_aim or _command_fire, reload_left > 0.0, command_interact or stance == "mantle", alive)
	if extracted:
		visual.visible = false
	var motion_setting = game.settings.get("camera_motion", 1.0)
	var camera_motion: float = 1.0 if motion_setting is bool and motion_setting else float(motion_setting)
	if _viewmodel != null:
		var reload_ratio: float = (1.0 - reload_left / _reload_duration) if reload_left > 0.0 else 0.0
		_viewmodel.animate(delta, speed, stance, _command_aim, reload_ratio, command_interact or stance == "mantle", camera_motion)
	if camera != null and (is_human or _spectating):
		_bob_phase += delta * speed * 1.8
		var bob: float = sin(_bob_phase * 2.0) * 0.012 * minf(speed / 4.5, 1.5) * camera_motion
		_camera_pivot.position.y = _eye_height + bob
		var desired_fov: float = float(game.settings.get("fov", 86.0))
		if _command_aim:
			desired_fov -= 15.0
		elif stance == "sprint":
			desired_fov += 5.0 * camera_motion
		camera.fov = lerpf(camera.fov, desired_fov, minf(delta * 9.0, 1.0))
		camera.rotation.z = lerpf(camera.rotation.z, (-0.035 if stance == "slide" else 0.0) * camera_motion, minf(delta * 6.0, 1.0))
