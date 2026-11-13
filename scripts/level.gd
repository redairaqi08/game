extends Node3D
## Authored, seed-stable Sanctuary of Three Echoes. All gameplay coordinates are meters.
## Static ornament is merged per material at construction time; collision stays explicit.

var spawns: Dictionary = {}
var exits: Array = []
var nav_bounds: Rect2
var nav_obstacles: Array[Rect2] = []
var zones: Array = []
var cover_points: Array = []
var world_size: Vector2 = Vector2(112.0, 88.0)
var team_size: int = 3
var _scale_x: float = 1.0
var _scale_z: float = 1.0
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _gate_materials: Dictionary = {}
var _gate_active: Dictionary = {}
var _collision_body: StaticBody3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _floating_crystal: Node3D

const STONE_SHADER = preload("res://shaders/environment_stone.gdshader")
const CAVERN_SHADER = preload("res://shaders/environment_cavern.gdshader")
const WATER_SHADER = preload("res://shaders/environment_water.gdshader")
const GATE_SHADER = preload("res://shaders/environment_gate.gdshader")

func build(size: int = 3) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	team_size = clampi(size, 1, 3)
	world_size = {1: Vector2(70, 56), 2: Vector2(94, 74), 3: Vector2(112, 88)}[team_size]
	_scale_x = world_size.x / 112.0
	_scale_z = world_size.y / 88.0
	nav_bounds = Rect2(-world_size * 0.5, world_size)
	nav_obstacles.clear()
	cover_points.clear()
	zones.clear()
	exits.clear()
	_batches.clear()
	_gate_materials.clear()
	_gate_active.clear()
	_rng.seed = 816947
	_make_materials()
	_collision_body = StaticBody3D.new()
	_collision_body.name = "SanctuaryCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 2
	add_child(_collision_body)
	_define_layout()
	_build_foundation()
	_build_courtyard()
	_build_cathedral()
	_build_bells()
	_build_workshops()
	_build_garden()
	_build_canals()
	_build_crypts()
	_build_bastion()
	_build_gates()
	_build_cavern()
	_commit_batches()
	_lighting()
	name = "SanctuaryOfThreeEchoes"

func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _scale_x, y, z * _scale_z)

func _size(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _scale_x, y, z * _scale_z)

func _define_layout() -> void:
	spawns = {
		"attack": [_p(-3, 0.1, 36), _p(0, 0.1, 35), _p(3, 0.1, 36)],
		"defend": [_p(-4, 0.1, -26), _p(0, 0.1, -27), _p(4, 0.1, -26)]
	}
	exits.append({"id": "A", "name": "L'Arche Brisée", "position": _p(-37, 0, -35), "radius": 3.0, "duration": 5.0})
	if team_size > 1:
		exits.append({"id": "B", "name": "Le Cœur des Résonances", "position": _p(0, 0, -37), "radius": 3.2, "duration": 7.0})
	exits.append({"id": "C", "name": "La Porte des Veines", "position": _p(37, 0, -35), "radius": 3.0, "duration": 8.0})
	var definitions: Array = [
		["Cour des Passeurs", 0, 32], ["Couloir des Cloches", -36, -4],
		["Cathédrale des Échos", 0, 0], ["Jardin des Cristaux", 36, -6],
		["Canaux du Silence", 35, 24], ["Ateliers Abandonnés", -36, 23],
		["Les Cryptes", 15, 20], ["Les Passerelles", -13, -23],
		["Bastion des Veilleurs", 0, -29]
	]
	for item in definitions:
		zones.append({"name": item[0], "position": _p(float(item[1]), 0, float(item[2]))})

func get_zone(position: Vector3) -> String:
	var nearest: String = "Sanctuaire des Trois Échos"
	var distance: float = INF
	for zone in zones:
		var d: float = position.distance_squared_to(zone.position)
		if d < distance:
			distance = d
			nearest = zone.name
	return nearest

func get_surface(position: Vector3) -> String:
	var zone: String = get_zone(position)
	if zone == "Canaux du Silence":
		return "water"
	if zone == "Couloir des Cloches" or zone == "Ateliers Abandonnés":
		return "metal"
	if zone == "Jardin des Cristaux" or zone == "Les Cryptes":
		return "soft"
	return "stone"

func set_exit_active(exit_id: String, active: bool) -> void:
	_gate_active[exit_id] = active

func _process(delta: float) -> void:
	_time += delta
	for gate_id in _gate_materials:
		var material: ShaderMaterial = _gate_materials[gate_id]
		var target: float = 1.0 if _gate_active.get(gate_id, false) else 0.0
		var value: float = float(material.get_shader_parameter("activation"))
		material.set_shader_parameter("activation", move_toward(value, target, delta * 2.0))
	if is_instance_valid(_floating_crystal):
		_floating_crystal.position.y = 7.4 + sin(_time * 0.6) * 0.12
		_floating_crystal.rotation.y += delta * 0.045

func _stone(color: Color, vein: Color, wetness: float = 0.0) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter("stone_color", color)
	material.set_shader_parameter("vein_color", vein)
	material.set_shader_parameter("wetness", wetness)
	return material

func _standard(color: Color, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72 if emission == 0.0 else 0.3
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _make_materials() -> void:
	_materials = {
		"stone": _stone(Color("414f55"), Color("7b867b")),
		"dark": _stone(Color("232f36"), Color("526763")),
		"ivory": _stone(Color("77817a"), Color("a7ac96")),
		"floor": _stone(Color("3b484b"), Color("69726b"), 0.2),
		"wet": _stone(Color("263f40"), Color("456a62"), 0.7),
		"bronze": _standard(Color("80694c"), 0.68),
		"copper": _standard(Color("8b6d49"), 0.64),
		"black": _standard(Color("131e24")),
		"teal": _standard(Color("428e80"), 0.24, 0.5),
		"mint": _standard(Color("75b9a2"), 0.3, 0.7),
		"amber": _standard(Color("d5a369"), 0.2, 0.6),
		"crystal": _standard(Color("4f9b91"), 0.28, 0.4),
		"moss": _standard(Color("293f35")),
		"cavern": _stone(Color("1c2a30"), Color("3c5051")),
		"water": ShaderMaterial.new()
	}
	_materials.water.shader = WATER_SHADER
	_materials.cavern.shader = CAVERN_SHADER

func _submit(mesh: Mesh, transform: Transform3D, material_name: String) -> void:
	if not _batches.has(material_name):
		_batches[material_name] = []
	_batches[material_name].append([mesh, transform])

func _box(size: Vector3, pos: Vector3, material_name: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_submit(mesh, Transform3D(Basis.from_euler(rotation), pos), material_name)

func _cylinder(bottom: float, top: float, height: float, pos: Vector3, material_name: String, vertices: int = 12, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = vertices
	mesh.rings = 1
	_submit(mesh, Transform3D(Basis.from_euler(rotation), pos), material_name)

func _beam(a: Vector3, b: Vector3, width: float, depth: float, material_name: String) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, a.distance_to(b), depth)
	var basis: Basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_submit(mesh, Transform3D(basis, (a + b) * 0.5), material_name)

func _torus(inner: float, outer: float, pos: Vector3, material_name: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 6
	_submit(mesh, Transform3D(Basis.from_euler(rotation), pos), material_name)

func _collider(shape: Shape3D, pos: Vector3) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	_collision_body.add_child(collision)

func _solid_box(size: Vector3, pos: Vector3, material_name: String, navigation: bool = true) -> void:
	_box(size, pos, material_name)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_collider(shape, pos)
	if navigation:
		nav_obstacles.append(Rect2(Vector2(pos.x - size.x * 0.5, pos.z - size.z * 0.5), Vector2(size.x, size.z)))

func _solid_column(radius: float, height: float, pos: Vector3, material_name: String) -> void:
	_cylinder(radius, radius * 0.94, height, pos, material_name)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_collider(shape, pos)
	nav_obstacles.append(Rect2(Vector2(pos.x - radius, pos.z - radius), Vector2.ONE * radius * 2.0))

func _wall(x: float, z: float, width: float, depth: float, height: float, material_name: String = "stone") -> void:
	var pos: Vector3 = _p(x, height * 0.5, z)
	_solid_box(_size(width, height, depth), pos, material_name)
	_box(_size(width + 0.28, 0.28, depth + 0.28), _p(x, 0.14, z), "dark")
	_box(_size(width + 0.22, 0.25, depth + 0.22), _p(x, height - 0.16, z), "ivory")
	cover_points.append(_p(x, 0, z + depth * 0.5 + 1.8))
	cover_points.append(_p(x, 0, z - depth * 0.5 - 1.8))

func _column(x: float, z: float, height: float = 8.0, radius: float = 0.85, material_name: String = "stone") -> void:
	var r: float = radius * minf(_scale_x, _scale_z)
	_solid_column(r, height, _p(x, height * 0.5, z), material_name)
	_cylinder(r * 1.27, r * 1.05, 0.32, _p(x, 0.16, z), "ivory")
	_cylinder(r * 1.1, r * 1.3, 0.42, _p(x, height - 0.21, z), "ivory")
	_torus(r * 0.98, r * 1.06, _p(x, height * 0.67, z), "bronze")
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		_box(Vector3(0.09, height * 0.56, 0.09), _p(x, height * 0.43, z) + direction * r * 0.96, "bronze")

func _arch(center: Vector3, half_width: float, base_height: float, depth: float, material_name: String = "ivory", segments: int = 14) -> void:
	for index in range(segments):
		var angle_a: float = PI * float(index) / float(segments)
		var angle_b: float = PI * float(index + 1) / float(segments)
		var a: Vector3 = center + Vector3(cos(angle_a) * half_width, base_height + sin(angle_a) * half_width * 0.74, 0)
		var b: Vector3 = center + Vector3(cos(angle_b) * half_width, base_height + sin(angle_b) * half_width * 0.74, 0)
		_beam(a, b, 0.55, depth, material_name)
		if index % 3 == 0:
			_cylinder(0.14, 0.07, 0.3, a, "bronze", 6)

func _crystal(pos: Vector3, radius: float, height: float, material_name: String = "crystal", collision: bool = false, tilt: Vector3 = Vector3.ZERO) -> void:
	_cylinder(radius * 0.68, radius, height * 0.72, pos + Vector3.UP * height * 0.36, material_name, 5, tilt)
	_cylinder(radius, 0.0, height * 0.36, pos + Vector3.UP * height * 0.90, material_name, 5, tilt)
	if collision:
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_collider(shape, pos + Vector3.UP * height * 0.5)
		nav_obstacles.append(Rect2(Vector2(pos.x - radius, pos.z - radius), Vector2.ONE * radius * 2.0))

func _build_foundation() -> void:
	_solid_box(Vector3(world_size.x + 5, 0.7, world_size.y + 5), Vector3(0, -0.35, 0), "floor", false)
	# Visible boundary retaining walls, not an invisible combat fence.
	for side in [-1, 1]:
		_wall(float(side) * 55.5, 0, 1.0, 88, 6.0, "dark")
		_wall(0, float(side) * 43.5, 112, 1.0, 6.0, "dark")
	# Large paving courses and inlaid lanes retain readability at first-person height.
	for x in range(-52, 53, 8):
		_box(_size(0.075, 0.015, 84), _p(x, 0.012, 0), "dark")
	for z in range(-40, 41, 8):
		_box(_size(108, 0.015, 0.075), _p(0, 0.014, z), "dark")
	for x in [-37.0, 0.0, 37.0]:
		for z in range(-30, 31, 6):
			_box(_size(0.075, 0.018, 1.8), _p(x - 1.8, 0.025, z), "bronze")
			_box(_size(0.075, 0.018, 1.8), _p(x + 1.8, 0.025, z), "bronze")
	# Staggered dividers create loops, block spawn-to-gate fire and leave wide rotation gaps.
	_wall(-19, 16, 2.2, 15, 5.4)
	_wall(-19, -10, 2.2, 13, 6.5)
	_wall(19, 10, 2.2, 13, 5.7)
	_wall(19, -17, 2.2, 13, 6.2)
	for x in [-19.0, 19.0]:
		for z in [-3.0, 27.0]:
			_column(x, z, 7.0, 0.85)

func _build_courtyard() -> void:
	_wall(0, 25, 12, 1.8, 4.0, "ivory")
	# The broken civilizational seal is visible over the first courtyard wall.
	_torus(2.4, 2.65, _p(0, 5.1, 25), "bronze", Vector3(PI * 0.5, 0, 0))
	_crystal(_p(0, 4.7, 25), 0.38, 2.5, "mint")
	for side in [-1, 1]:
		_column(float(side) * 12, 34, 6.2, 0.7, "ivory")
		_wall(float(side) * 15, 29, 3.8, 2.3, 1.25)
		_statue(_p(float(side) * 24, 0, 35), float(side) * 0.28, 0.85)
		for z in [30.0, 38.0]:
			_cylinder(1.1, 0.78, 0.18, _p(float(side) * 8, 0.1, z), "dark")
			_torus(0.5, 0.55, _p(float(side) * 8, 0.21, z), "teal")
	_sign("COUR DES PASSEURS", _p(0, 2.6, 25.96), Color("9dc7bb"), 0.035)
	_sign("CE QUI NE RÉSONNE PLUS DOIT ÊTRE RETROUVÉ", _p(0, 1.6, 25.98), Color("a2b2ab"), 0.013)

func _statue(pos: Vector3, facing: float, size: float = 1.0) -> void:
	# Faceted four-eared memory keeper: a recognizable non-human civic silhouette.
	var s: float = size
	_cylinder(1.8 * s, 1.6 * s, 0.9 * s, pos + Vector3.UP * 0.45 * s, "dark", 8)
	for side in [-1, 1]:
		_box(Vector3(0.65, 2.3, 0.75) * s, pos + Vector3(float(side) * 0.65, 1.8, 0) * s, "ivory", Vector3(0, facing, float(side) * -0.07))
		_beam(pos + Vector3(float(side) * 1.0, 4.8, 0) * s, pos + Vector3(float(side) * 1.5, 3.0, 0.1) * s, 0.55 * s, 0.6 * s, "stone")
	_cylinder(1.3 * s, 0.9 * s, 2.1 * s, pos + Vector3.UP * 3.9 * s, "ivory", 6)
	_cylinder(0.68 * s, 0.43 * s, 1.15 * s, pos + Vector3.UP * 5.45 * s, "stone", 5)
	for side in [-1, 1]:
		_crystal(pos + Vector3(float(side) * 0.50, 5.5, 0) * s, 0.26 * s, 1.3 * s, "ivory", false, Vector3(0, 0, float(side) * -0.3))
	_box(Vector3(0.65, 0.08, 0.08) * s, pos + Vector3(0, 5.6, 0.52) * s, "teal")
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.6 * s
	shape.height = 5.8 * s
	_collider(shape, pos + Vector3.UP * 2.9 * s)
	nav_obstacles.append(Rect2(Vector2(pos.x - 1.6 * s, pos.z - 1.6 * s), Vector2.ONE * 3.2 * s))

func _build_cathedral() -> void:
	# Three elevated transverse ribs frame a hanging archive crystal.
	for z in [-15.0, 1.0, 17.0]:
		for x in [-12.0, 12.0]:
			_column(x, z, 7.4, 1.0, "ivory")
		_arch(_p(0, 0, z), 12.0 * _scale_x, 7.4, 0.8, "stone", 18)
		_arch(_p(0, 0, z + 0.1), 11.4 * _scale_x, 7.5, 0.25, "bronze", 18)
	for x in [-12.0, 12.0]:
		_beam(_p(x, 7.0, -15), _p(x, 7.0, 17), 0.55, 0.7, "stone")
	# Raised galleries are scenery in this milestone; there is no misleading collision staircase.
	for x in [-15.4, 15.4]:
		_box(_size(4.2, 0.5, 24), _p(x, 5.7, -1), "dark")
		for z in [-11.0, -5.0, 1.0, 7.0]:
			_column(x, z, 5.5, 0.48)
			_box(_size(0.12, 0.9, 4.7), _p(x + signf(x) * -1.6, 6.3, z), "bronze")
	_solid_column(2.5 * _scale_x, 0.95, _p(0, 0.475, -3), "dark")
	_torus(2.2 * _scale_x, 2.55 * _scale_x, _p(0, 0.96, -3), "bronze")
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0
		_crystal(_p(cos(angle) * 2.4, 1.0, -3 + sin(angle) * 2.4), 0.16, 0.6, "mint")
	_floating_crystal = Node3D.new()
	_floating_crystal.name = "SuspendedArchiveHeart"
	_floating_crystal.position = _p(0, 7.4, -3)
	add_child(_floating_crystal)
	var heart_mesh: CylinderMesh = CylinderMesh.new()
	heart_mesh.bottom_radius = 0.0
	heart_mesh.top_radius = 1.7
	heart_mesh.height = 3.5
	heart_mesh.radial_segments = 6
	var lower: MeshInstance3D = MeshInstance3D.new()
	lower.mesh = heart_mesh
	lower.material_override = _materials.crystal
	_floating_crystal.add_child(lower)
	var upper: MeshInstance3D = MeshInstance3D.new()
	upper.mesh = heart_mesh
	upper.rotation.z = PI
	upper.position.y = 3.0
	upper.material_override = _materials.mint
	_floating_crystal.add_child(upper)
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		_beam(_p(cos(angle) * 7.0, 15.0, -3 + sin(angle) * 7.0), _p(0, 10.0, -3), 0.13, 0.13, "bronze")
	# Arc-shaped cover islands interrupt exact, long central lines.
	for item in [[-6, 7], [6, -11]]:
		_wall(float(item[0]), float(item[1]), 5.0, 1.4, 1.35, "ivory")
		for x in [-1.5, 0.0, 1.5]:
			_cylinder(0.18, 0.18, 0.08, _p(float(item[0]) + x, 1.41, float(item[1])), "bronze", 8)
	_sign("LA TRAME SE SOUVIENT", _p(0, 0.15, 4), Color("7c9b91"), 0.025, Vector3(-PI * 0.5, 0, 0))

func _build_bells() -> void:
	for z in [-22.0, -8.0, 6.0, 18.0]:
		for x in [-45.0, -28.0]:
			_column(x, z, 5.8, 0.75, "dark")
		_arch(_p(-36.5, 0, z), 8.5 * _scale_x, 5.8, 0.55, "bronze", 12)
		_cylinder(0.85, 0.32, 1.6, _p(-36.5, 6.8, z), "copper", 10)
		_cylinder(1.0, 0.9, 0.15, _p(-36.5, 5.98, z), "bronze", 10)
		_beam(_p(-36.5, 8.0, z), _p(-36.5, 7.55, z), 0.12, 0.12, "dark")
	_wall(-43, -15, 4.5, 5.0, 1.45, "dark")
	_wall(-29, 1, 4.6, 3.2, 1.35, "ivory")
	for z in range(-25, 23, 4):
		_box(_size(8, 0.018, 0.14), _p(-36, 0.026, z), "bronze")
	_sign("COULOIR DES CLOCHES", _p(-36.5, 4.6, 18), Color("d1b487"), 0.023)

func _build_workshops() -> void:
	_wall(-44, 26, 2.0, 13, 5.2, "dark")
	_wall(-35, 32, 14, 1.5, 4.0)
	_wall(-28, 23, 1.8, 9, 3.6)
	for item in [[-38, 23], [-32, 26]]:
		var x: float = float(item[0])
		var z: float = float(item[1])
		_wall(x, z, 3.6, 1.7, 1.25, "dark")
		_cylinder(0.55, 0.55, 1.1, _p(x, 1.9, z), "bronze", 10, Vector3(PI * 0.5, 0, 0))
		_torus(0.85, 0.98, _p(x, 1.9, z), "copper", Vector3(PI * 0.5, 0, 0))
		_crystal(_p(x, 1.4, z), 0.22, 0.75, "amber")
	for index in range(9):
		var x: float = -42 + _rng.randf_range(0, 12)
		var z: float = 20 + _rng.randf_range(0, 10)
		_cylinder(0.15, 0.2, 0.2, _p(x, 0.12, z), "copper", 6, Vector3(0.3, 0, 0.4))
	_sign("ATELIERS · MÉMOIRE VII", _p(-35, 2.8, 32.8), Color("b09c7c"), 0.021)

func _build_garden() -> void:
	var rocks: Array = [[28, 7, 1.5, 3.0], [43, 0, 1.8, 4.1], [31, -10, 1.8, 3.8], [44, -16, 1.4, 2.4], [25, -24, 1.35, 3.3], [46, 13, 1.25, 2.5]]
	for item in rocks:
		var center: Vector3 = _p(float(item[0]), 0, float(item[1]))
		var radius: float = float(item[2]) * minf(_scale_x, _scale_z)
		_solid_column(radius, float(item[3]) * 0.6, center + Vector3.UP * float(item[3]) * 0.3, "dark")
		for index in range(4):
			var angle: float = float(index) * 1.7
			_crystal(center + Vector3(cos(angle) * radius * 0.55, 0.4, sin(angle) * radius * 0.55), radius * 0.32, float(item[3]) * _rng.randf_range(0.6, 1.2), "crystal")
		cover_points.append(center + Vector3(radius + 1.5, 0, 0))
	for index in range(42):
		var x: float = _rng.randf_range(23, 49)
		var z: float = _rng.randf_range(-27, 14)
		_cylinder(_rng.randf_range(0.3, 0.65), 0.1, 0.14, _p(x, 0.07, z), "moss", 7)
		_cylinder(0.035, 0.05, 0.35, _p(x, 0.28, z), "dark", 5)
		_cylinder(0.30, 0.06, 0.10, _p(x, 0.48, z), "teal", 7)
	_wall(37, -26, 6.5, 1.5, 1.5, "dark")
	_sign("JARDIN DES CRISTAUX", _p(37, 2.3, -26.85), Color("95c7ac"), 0.022, Vector3(0, PI, 0))

func _build_canals() -> void:
	# Shallow water is traversable; it never turns into a navigational pit.
	_box(_size(17, 0.025, 15), _p(37, 0.035, 24), "water")
	for x in [27.5, 46.5]:
		_box(_size(0.55, 0.10, 17), _p(x, 0.06, 24), "ivory")
	for z in [18.5, 27.5]:
		_box(_size(19, 0.06, 2.3), _p(37, 0.045, z), "stone")
		for x in [28.5, 45.5]:
			_column(x, z, 3.8, 0.36, "wet")
		_arch(_p(37, 0, z), 8.5 * _scale_x, 3.8, 0.45, "wet", 12)
	for x in [31.0, 36.0, 41.0]:
		_torus(0.38, 0.41, _p(x, 0.07, 23.5), "teal")
	_wall(49, 28, 2.5, 8.0, 2.2, "wet")

func _build_crypts() -> void:
	# Broken archive shelves define a low, indirect approach to the east flank.
	for x in [8.0, 15.0]:
		_wall(x, 20, 1.2, 5.5, 2.1, "dark")
		for z in [18.0, 20.0, 22.0]:
			for y in [0.7, 1.5]:
				_crystal(_p(x + 0.65, y, z), 0.13, 0.45, "teal")
	_arch(_p(11.5, 0, 17), 4.1 * _scale_x, 2.3, 0.45, "dark", 10)
	_sign("ARCHIVES · FRAGMENTS PERDUS", _p(12, 2.5, 23.1), Color("83a69b"), 0.015)

func _build_bastion() -> void:
	for side in [-1, 1]:
		_wall(float(side) * 12, -28, 5.2, 2.0, 3.1, "ivory")
		_column(float(side) * 9, -30, 7.0, 0.65, "ivory")
		_statue(_p(float(side) * 19, 0, -36), 0, 0.8)
		_wall(float(side) * 27, -28, 2.0, 5.0, 2.5, "stone")
		_box(_size(5.0, 0.1, 3.0), _p(float(side) * 14, 0.08, -32), "dark")
	# Broken high rotation bridge is an environmental landmark, not a hidden playable route.
	_box(_size(19, 0.65, 3.3), _p(-5.5, 5.2, -22), "stone")
	for x in [-14.0, 3.0]:
		_column(x, -22, 5.0, 0.7)
		_arch(_p(x, 0, -22), 2.4 * _scale_x, 3.3, 0.4, "bronze", 10)
	for x in range(-13, 3, 2):
		_box(_size(0.13, 1.0, 0.13), _p(x, 5.9, -23.5), "bronze")
		_box(_size(0.13, 1.0, 0.13), _p(x, 5.9, -20.5), "bronze")
	_sign("BASTION DES VEILLEURS", _p(0, 3.5, -33), Color("d4b88b"), 0.025)

func _build_gates() -> void:
	for gate in exits:
		var center: Vector3 = gate.position
		var letter: String = gate.id
		var accent: String = "amber" if letter != "C" else "mint"
		var color: Color = Color("dab887") if letter != "C" else Color("96d3b6")
		# The destination remains open and outside every obstacle rectangle.
		for side in [-1, 1]:
			var pos: Vector3 = center + Vector3(float(side) * 4.0, 0, -1.5)
			_solid_column(0.75, 6.5, pos + Vector3.UP * 3.25, "ivory")
			_cylinder(1.0, 0.8, 0.5, pos + Vector3.UP * 0.25, "dark")
			_crystal(pos + Vector3(0, 6.5, 0), 0.30, 1.5, accent)
		_arch(center + Vector3(0, 0, -1.5), 4.0, 6.1, 0.85, "ivory", 14)
		_arch(center + Vector3(0, 0, -1.0), 3.65, 6.0, 0.15, "bronze", 14)
		_torus(2.8, 2.9, center + Vector3(0, 0.055, 0), "bronze")
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2.ONE * 6.6
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = plane
		ring.position = center + Vector3.UP * 0.065
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GATE_SHADER
		material.set_shader_parameter("gate_color", color)
		material.set_shader_parameter("activation", 0.0)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_gate_materials[letter] = material
		_gate_active[letter] = false
		_sign(letter, center + Vector3(0, 7.0, -1), color, 0.12)
		_sign(String(gate.name).to_upper(), center + Vector3(0, 5.4, -1), color, 0.024)
		_sign("MAINTENIR E · %d SECONDES" % int(gate.duration), center + Vector3(0, 4.7, -1), Color("a3b2ac"), 0.017)
		# Embedded archive shards make each exit readable from its approach.
		for index in range(5):
			_crystal(center + Vector3(float(index - 2) * 0.7, 0.0, -2.6), 0.12, 0.5 + float(index % 3) * 0.25, accent)
	if team_size == 1:
		_wall(0, -37, 13.0, 2.0, 6.0, "dark")
		_sign("LE CŒUR EST SILENCIEUX", _p(0, 3.0, -35.8), Color("77847e"), 0.025)

func _build_cavern() -> void:
	_build_cave_canopy()
	# Distant faceted geology frames the city without overhead occluders hiding the arena.
	for side in [-1, 1]:
		for z in range(-40, 42, 10):
			var height: float = _rng.randf_range(10, 22)
			_cylinder(5.5, 1.5, height, _p(float(side) * 59, height * 0.5, z), "dark", 7, Vector3(0, _rng.randf_range(0, 1.5), float(side) * 0.11))
			_crystal(_p(float(side) * 54, 7.5, z), 0.35, 2.0, "teal")
	for x in range(-50, 52, 10):
		var height: float = _rng.randf_range(13, 24)
		_cylinder(5.0, 2.0, height, _p(x, height * 0.5, -48), "dark", 7)
	# Broken lintels on the far roof imply the scale of the buried city.
	for index in range(38):
		var x: float = _rng.randf_range(-51, 51)
		var z: float = _rng.randf_range(-40, 40)
		# Decorative chips stay below foot collision height to avoid invisible snags.
		_cylinder(_rng.randf_range(0.08, 0.22), 0.0, _rng.randf_range(0.06, 0.18), _p(x, 0.07, z), "ivory", 5)


func _build_cave_canopy() -> void:
	# Irregular, inward-facing geology closes the skyline into a true cavern.
	# It is scenery far outside reachable height; navigation and perception walls stay explicit.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = 18
	var rows: int = 14
	var vertices: Array[Vector3] = []
	for z_index in range(rows + 1):
		for x_index in range(columns + 1):
			var x: float = lerpf(-68.0, 68.0, float(x_index) / float(columns))
			var z: float = lerpf(-55.0, 55.0, float(z_index) / float(rows))
			var height: float = 29.5 + sin(x * 0.11) * 2.3 + cos(z * 0.17) * 2.0 + _rng.randf_range(-1.8, 1.8)
			vertices.append(_p(x, height, z))
	for z_index in range(rows):
		for x_index in range(columns):
			var a: int = z_index * (columns + 1) + x_index
			var b: int = a + 1
			var c: int = a + columns + 1
			var d: int = c + 1
			for index in [a, b, c, b, d, c]:
				var point: Vector3 = vertices[index]
				surface.set_uv(Vector2(point.x, point.z) * 0.05)
				surface.add_vertex(point)
	surface.generate_normals()
	_submit(surface.commit(), Transform3D.IDENTITY, "cavern")
	# Jagged rock curtains connect the retaining architecture to the vault.
	for side in [-1, 1]:
		for z in range(-46, 47, 7):
			var x: float = float(side) * _rng.randf_range(56.2, 60.0)
			var height: float = _rng.randf_range(24.0, 31.0)
			_cylinder(4.6, 6.8, height, _p(x, height * 0.5 + 2.0, z), "cavern", 5, Vector3(0, _rng.randf_range(-0.5, 0.5), float(side) * 0.09))
	for x in range(-57, 58, 8):
		_cylinder(4.3, 6.0, _rng.randf_range(25.0, 30.0), _p(x, 15.0, -47.5), "cavern", 5)

func _sign(text: String, position: Vector3, color: Color, pixel_size: float, rotation: Vector3 = Vector3.ZERO) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = position
	label.rotation = rotation
	label.pixel_size = pixel_size * 0.32
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.font_size = 32
	label.modulate = color
	label.outline_size = 3
	label.outline_modulate = Color(0.025, 0.045, 0.05, 0.9)
	label.shaded = false
	label.no_depth_test = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)

func _commit_batches() -> void:
	for material_name in _batches:
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in _batches[material_name]:
			surface.append_from(entry[0], 0, entry[1])
		var mesh: ArrayMesh = surface.commit()
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Architecture_" + String(material_name)
		instance.mesh = mesh
		instance.material_override = _materials[material_name]
		if material_name in ["teal", "mint", "amber", "water", "cavern"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()

func _lighting() -> void:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "MineralVaultKey"
	key.rotation_degrees = Vector3(-54, -27, 0)
	key.light_color = Color("bed4d3")
	key.light_energy = 1.15
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 85.0
	key.shadow_bias = 0.04
	add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "WarmArchiveBounce"
	fill.rotation_degrees = Vector3(-26, 148, 0)
	fill.light_color = Color("a9987c")
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)
	for item in [
		[_p(0, 10, -3), Color("93dccd"), 22.0, 2.8],
		[_p(-36, 6, -6), Color("edb77d"), 18.0, 2.0],
		[_p(36, 5, -8), Color("82cca0"), 19.0, 2.2],
		[_p(36, 4, 24), Color("85bfc5"), 18.0, 1.5],
		[_p(0, 5, 30), Color("86b7b4"), 20.0, 1.7],
		[_p(0, 6, -32), Color("e2b783"), 21.0, 2.0]
	]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = item[0]
		light.light_color = item[1]
		light.omni_range = float(item[2]) * minf(_scale_x, _scale_z)
		light.light_energy = float(item[3])
		light.shadow_enabled = false
		light.omni_attenuation = 1.5
		add_child(light)
