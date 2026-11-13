extends Node3D
## Original first-person mineral resonance weapon and Vesperid hands.
var rifle: Node3D
var pistol: Node3D
var hands: Array[Node3D] = []
var muzzle: MeshInstance3D
var muzzle_light: OmniLight3D
var resonator_material: StandardMaterial3D
var animation_time: float = 0.0
var recoil: float = 0.0
var flash_left: float = 0.0
var ability_left: float = 0.0
var swap_left: float = 0.0
var current_weapon: int = 0
var rifle_position: Vector3 = Vector3(0.24, -0.25, -0.43)
var ads_blend: float = 0.0
var sway: Vector2 = Vector2.ZERO
var materials: Dictionary = {}

func build(team: int) -> void:
	materials.dark = _material(Color("22373c"), 0.75, 0.32)
	materials.ivory = _material(Color("b6c6bd"), 0.38, 0.36)
	materials.copper = _material(Color("a88652"), 0.85, 0.24)
	materials.skin = _material(Color("738b8b"), 0.1, 0.55)
	materials.cloth = _material(Color("1c313b"), 0.05, 0.8)
	resonator_material = _material(Color("7bf3eb") if team == 0 else Color("ffd487"), 0.65, 0.2)
	resonator_material.emission_enabled = true
	resonator_material.emission = Color("35d2dd") if team == 0 else Color("edae51")
	resonator_material.emission_energy_multiplier = 1.5
	rifle = Node3D.new()
	add_child(rifle)
	rifle.position = rifle_position
	_make_rifle(rifle)
	pistol = Node3D.new()
	add_child(pistol)
	pistol.position = rifle_position
	_make_pistol(pistol)
	pistol.visible = false
	for side in [-1.0, 1.0]:
		var hand: Node3D = Node3D.new()
		add_child(hand)
		hand.position = Vector3(0.11, -0.32, -0.70) if side < 0 else Vector3(0.28, -0.31, -0.23)
		hand.rotation.z = side * -0.14
		_segment(hand, Vector3(0, 0, 0.15), Vector3(0, 0, 0), 0.048, materials.cloth)
		_segment(hand, Vector3(0, 0, 0.04), Vector3(0, 0.035, -0.06), 0.042, materials.skin)
		for finger in range(3):
			var x: float = (finger - 1) * 0.025
			_segment(hand, Vector3(x, 0.025, -0.02), Vector3(x, 0.058, -0.075), 0.012, materials.skin)
			_segment(hand, Vector3(x, 0.058, -0.075), Vector3(x, 0.026, -0.10), 0.009, materials.ivory)
		_segment(hand, Vector3(-0.04 * side, 0.02, 0), Vector3(-0.062 * side, 0.058, -0.045), 0.014, materials.skin)
		for band in range(3):
			_ring(hand, Vector3(0, 0, 0.06 + band * 0.025), 0.049, 0.006, materials.copper)
		hands.append(hand)
	muzzle = _crystal(rifle, Vector3(0, 0.01, -0.60), Vector3(0.06, 0.06, 0.14), resonator_material)
	muzzle.visible = false
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = resonator_material.emission
	muzzle_light.omni_range = 2.8
	muzzle_light.light_energy = 0.0
	muzzle_light.shadow_enabled = false
	add_child(muzzle_light)
	muzzle_light.position = Vector3(0.23, -0.22, -0.95)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = geometry
	item.material_override = mat
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.layers = 8
	parent.add_child(item)
	item.position = at
	return item

func _segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var geometry: CylinderMesh = CylinderMesh.new()
	geometry.top_radius = radius * 0.83
	geometry.bottom_radius = radius
	geometry.height = a.distance_to(b)
	geometry.radial_segments = 8
	var item: MeshInstance3D = _mesh(parent, geometry, (a + b) * 0.5, mat)
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return item

func _ring(parent: Node3D, at: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var geometry: TorusMesh = TorusMesh.new()
	geometry.inner_radius = radius - thickness
	geometry.outer_radius = radius + thickness
	geometry.rings = 16
	geometry.ring_segments = 6
	var item: MeshInstance3D = _mesh(parent, geometry, at, mat)
	item.rotation.x = PI * 0.5
	return item

func _crystal(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var prism: CylinderMesh = CylinderMesh.new()
	prism.top_radius = 0.15
	prism.bottom_radius = 1.0
	prism.height = 2.0
	prism.radial_segments = 5
	var item: MeshInstance3D = _mesh(parent, prism, at, mat)
	item.scale = dimensions
	return item

func _make_rifle(root: Node3D) -> void:
	_segment(root, Vector3(0, -0.015, 0.17), Vector3(0, -0.015, -0.38), 0.058, materials.dark)
	_segment(root, Vector3(0.0, -0.07, 0.03), Vector3(0.005, -0.20, 0.13), 0.032, materials.ivory)
	_segment(root, Vector3(0, -0.02, 0.20), Vector3(0, -0.02, 0.30), 0.07, materials.cloth)
	for side in [-1.0, 1.0]:
		# Two asymmetrically etched mineral rails produce the weapon's tuning fork silhouette.
		_segment(root, Vector3(side * 0.064, 0.0, -0.17), Vector3(side * 0.045, 0.015, -0.58), 0.021, materials.ivory)
		_segment(root, Vector3(side * 0.045, 0.015, -0.58), Vector3(side * 0.06, 0.045, -0.62), 0.014, materials.copper)
		_segment(root, Vector3(side * 0.060, -0.02, -0.02), Vector3(side * 0.062, -0.01, -0.24), 0.011, materials.copper)
		for vent in range(4):
			_segment(root, Vector3(side * 0.057, -0.035, -0.04 - vent * 0.035), Vector3(side * 0.073, 0.025, -0.06 - vent * 0.035), 0.006, materials.ivory)
	for ring_index in range(4):
		_ring(root, Vector3(0, 0, -0.16 - ring_index * 0.073), 0.058 - ring_index * 0.004, 0.008, materials.copper)
	_crystal(root, Vector3(0, 0.015, -0.29), Vector3(0.022, 0.10, 0.025), resonator_material)
	_segment(root, Vector3(0, 0.055, -0.02), Vector3(0, 0.085, -0.02), 0.015, materials.copper)
	_ring(root, Vector3(0, 0.095, -0.02), 0.027, 0.005, materials.ivory)
	_segment(root, Vector3(0, 0.045, -0.53), Vector3(0, 0.09, -0.53), 0.009, resonator_material)
	# A visible piezoelectric magazine houses small articulated plates.
	for plate in range(4):
		_segment(root, Vector3(-0.038, -0.08 - plate * 0.025, -0.10), Vector3(0.038, -0.08 - plate * 0.025, -0.10), 0.016, materials.copper)

func _make_pistol(root: Node3D) -> void:
	_segment(root, Vector3(0, 0, 0.04), Vector3(0, 0, -0.24), 0.055, materials.dark)
	_segment(root, Vector3(0, -0.04, 0.06), Vector3(0, -0.18, 0.11), 0.04, materials.ivory)
	for side in [-1.0, 1.0]:
		_segment(root, Vector3(side * 0.055, 0, -0.10), Vector3(side * 0.048, 0, -0.31), 0.019, materials.copper)
	_ring(root, Vector3(0, 0, -0.16), 0.06, 0.009, materials.ivory)
	_crystal(root, Vector3(0, 0.025, -0.12), Vector3(0.026, 0.065, 0.025), resonator_material)
	_segment(root, Vector3(0, 0.05, -0.23), Vector3(0, 0.08, -0.23), 0.008, resonator_material)

func fire() -> void:
	recoil = minf(1.0, recoil + 0.75)
	flash_left = 0.055

func ability() -> void:
	ability_left = 0.55

func switch_weapon(index: int) -> void:
	current_weapon = index
	rifle.visible = index == 0
	pistol.visible = index == 1
	swap_left = 0.3

func add_sway(relative: Vector2) -> void:
	sway += relative * 0.00011
	sway = sway.limit_length(0.025)

func animate(delta: float, speed: float, stance: String, aiming: bool, reload_ratio: float, interacting: bool, camera_motion: float) -> void:
	animation_time += delta
	recoil = move_toward(recoil, 0.0, delta * 5.0)
	flash_left = maxf(0.0, flash_left - delta)
	ability_left = maxf(0.0, ability_left - delta)
	swap_left = maxf(0.0, swap_left - delta)
	ads_blend = move_toward(ads_blend, 1.0 if aiming else 0.0, delta * 8.0)
	sway = sway.lerp(Vector2.ZERO, minf(delta * 7.0, 1.0))
	var moving: float = minf(speed / 4.5, 1.5)
	var phase: float = animation_time * (14.0 if stance == "sprint" else 9.0)
	var bob: Vector3 = Vector3(sin(phase) * 0.011, absf(cos(phase)) * 0.009, 0.0) * moving * camera_motion * (1.0 - ads_blend * 0.7)
	var reload_angle: float = sin(reload_ratio * PI) if reload_ratio > 0.0 else 0.0
	var base_position: Vector3 = rifle_position.lerp(Vector3(0, -0.17, -0.43), ads_blend)
	base_position += bob + Vector3(-sway.x, sway.y, recoil * 0.055)
	base_position.y -= reload_angle * 0.16 + swap_left * 0.65
	if interacting:
		base_position += Vector3(0.0, -0.18, 0.05)
	base_position.y -= sin(ability_left * PI / 0.55) * 0.11
	for weapon in [rifle, pistol]:
		weapon.position = base_position
		weapon.rotation = Vector3(recoil * 0.13 - reload_angle * 0.25, reload_angle * -0.45, -reload_angle * 0.6 + bob.x * 1.4)
	hands[0].position = Vector3(0.11 - ads_blend * 0.20, -0.32 - reload_angle * 0.16, -0.70 + reload_angle * 0.24) + bob
	hands[0].rotation.z = 0.14 - reload_angle * 1.1
	hands[1].position = Vector3(0.28 - ads_blend * 0.24, -0.31 - reload_angle * 0.12, -0.23) + bob + Vector3(0, 0, recoil * 0.045)
	if interacting:
		hands[0].position = Vector3(-0.17, -0.24, -0.60)
		hands[0].rotation.x = -0.3
	else:
		hands[0].rotation.x = 0.0
	muzzle.visible = flash_left > 0.0 and current_weapon == 0
	muzzle_light.light_energy = 1.5 if flash_left > 0.0 else 0.0
	resonator_material.emission_energy_multiplier = 1.1 + recoil * 3.0 + sin(animation_time * 3.0) * 0.12
