extends Node3D
## Authored articulated Vesperid: resonator mask, sensory ears, mineral armour,
## woven mantle and digitigrade legs. Animation acts on a joint hierarchy.

var team: int = 0
var joints: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var echo_material: ShaderMaterial
var original_materials: Dictionary = {}
var animation_time: float = 0.0
var walk_phase: float = 0.0
var damage_flash: float = 0.0
var shot_flash: float = 0.0
var ping_flash: float = 0.0
var death_blend: float = 0.0
var reconstruction: float = 1.0
var acoustic_mode: bool = false
var body_root: Node3D
var gun_root: Node3D
var mask_root: Node3D
var crystal_material: StandardMaterial3D

func build(team_id: int) -> void:
	team = team_id
	var dark: StandardMaterial3D = _mat(Color("253d45") if team == 0 else Color("484139"), 0.55, 0.43)
	var skin: StandardMaterial3D = _mat(Color("607778") if team == 0 else Color("777367"), 0.18, 0.6)
	var bone: StandardMaterial3D = _mat(Color("b7c6bc") if team == 0 else Color("c7bca1"), 0.45, 0.38)
	var cloth: StandardMaterial3D = _mat(Color("182c35") if team == 0 else Color("362c31"), 0.05, 0.9)
	var copper: StandardMaterial3D = _mat(Color("596765") if team == 0 else Color("a88350"), 0.8, 0.32)
	crystal_material = _mat(Color("63e1db") if team == 0 else Color("f6be69"), 0.5, 0.21)
	crystal_material.emission_enabled = true
	crystal_material.emission = Color("49c2d5") if team == 0 else Color("e4a74a")
	crystal_material.emission_energy_multiplier = 0.9
	echo_material = ShaderMaterial.new()
	echo_material.shader = preload("res://shaders/actor_reconstruction.gdshader")
	echo_material.set_shader_parameter("echo_color", Color("62e5fa") if team == 0 else Color("ffb76c"))
	body_root = _joint(self, "body", Vector3.ZERO)
	var hips: Node3D = _joint(body_root, "hips", Vector3(0, 0.94, 0))
	_ellipsoid(hips, Vector3(0, 0, 0), Vector3(0.28, 0.16, 0.15), dark)
	var chest: Node3D = _joint(hips, "chest", Vector3(0, 0.28, 0))
	_ellipsoid(chest, Vector3(0, 0.02, 0), Vector3(0.31, 0.25, 0.17), dark)
	# Split breastplate and central resonator rather than a human tactical vest.
	for side in [-1.0, 1.0]:
		var plate: MeshInstance3D = _taper(chest, Vector3(side * 0.13, 0.10, -0.10), 0.14, 0.09, 0.29, bone)
		plate.rotation.z = side * 0.15
		_taper(chest, Vector3(side * 0.17, -0.12, -0.09), 0.065, 0.12, 0.14, copper)
	_taper(chest, Vector3(0, 0.11, -0.175), 0.041, 0.025, 0.24, crystal_material)
	for n in range(4):
		_taper(chest, Vector3(0, -0.13 - n * 0.035, -0.148), 0.105 - n * 0.01, 0.10 - n * 0.01, 0.025, copper)
	# Mantle blades hang behind shoulders and move with torso.
	for side in [-1.0, 1.0]:
		var mantle: MeshInstance3D = _taper(chest, Vector3(side * 0.21, -0.15, 0.14), 0.14, 0.21, 0.64, cloth)
		mantle.scale.z = 0.18
		mantle.rotation.z = side * 0.12
		for rivet in range(3):
			_ellipsoid(chest, Vector3(side * 0.27, 0.22 - rivet * 0.075, 0.08), Vector3(0.023, 0.023, 0.022), copper)
	var neck: Node3D = _joint(chest, "neck", Vector3(0, 0.28, 0))
	_taper(neck, Vector3(0, 0.02, 0), 0.08, 0.075, 0.16, skin)
	mask_root = _joint(neck, "head", Vector3(0, 0.17, 0))
	_ellipsoid(mask_root, Vector3(0, 0.01, 0.005), Vector3(0.155, 0.17, 0.13), skin)
	# Eyes are vestigial: the face is dominated by a sculpted listening mask.
	_taper(mask_root, Vector3(0, -0.01, -0.12), 0.105, 0.145, 0.245, bone)
	for side in [-1.0, 1.0]:
		var ear: MeshInstance3D = _taper(mask_root, Vector3(side * 0.15, 0.19, 0.025), 0.025, 0.095, 0.34, skin)
		ear.scale.z = 0.38
		ear.rotation.z = -side * 0.26
		var rim: MeshInstance3D = _taper(mask_root, Vector3(side * 0.16, 0.19, 0.01), 0.012, 0.060, 0.27, copper)
		rim.scale.z = 0.15
		rim.rotation.z = -side * 0.26
		_ellipsoid(mask_root, Vector3(side * 0.08, 0.026, -0.144), Vector3(0.038, 0.018, 0.022), crystal_material)
		# Curved mask vents form two symmetric tuning fans.
		for vent in range(3):
			var strip: MeshInstance3D = _taper(mask_root, Vector3(side * (0.06 + vent * 0.021), -0.055 - vent * 0.012, -0.153), 0.009, 0.012, 0.09, dark)
			strip.rotation.z = side * (0.12 + vent * 0.16)
	for side in [-1.0, 1.0]:
		var suffix: String = "left" if side < 0 else "right"
		var shoulder: Node3D = _joint(chest, "arm_" + suffix, Vector3(side * 0.33, 0.15, 0))
		_ellipsoid(shoulder, Vector3(side * 0.025, 0, 0), Vector3(0.15, 0.12, 0.13), bone)
		_segment(shoulder, Vector3.ZERO, Vector3(side * 0.04, -0.28, -0.025), 0.077, skin)
		var elbow: Node3D = _joint(shoulder, "elbow_" + suffix, Vector3(side * 0.04, -0.28, -0.025))
		_ellipsoid(elbow, Vector3.ZERO, Vector3(0.075, 0.07, 0.075), copper)
		_segment(elbow, Vector3.ZERO, Vector3(0, -0.25, -0.025), 0.064, dark)
		_taper(elbow, Vector3(0, -0.12, -0.055), 0.075, 0.06, 0.20, bone)
		var hand: Node3D = _joint(elbow, "hand_" + suffix, Vector3(0, -0.27, -0.025))
		_ellipsoid(hand, Vector3.ZERO, Vector3(0.067, 0.075, 0.045), skin)
		for finger in range(3):
			_segment(hand, Vector3(-0.04 + finger * 0.035, -0.04, -0.012), Vector3(-0.04 + finger * 0.035, -0.12, -0.025), 0.012, bone)
		var thigh: Node3D = _joint(hips, "leg_" + suffix, Vector3(side * 0.15, -0.05, 0))
		_segment(thigh, Vector3.ZERO, Vector3(side * 0.012, -0.37, 0.025), 0.105, dark)
		_taper(thigh, Vector3(side * 0.035, -0.17, -0.06), 0.085, 0.11, 0.28, bone)
		var knee: Node3D = _joint(thigh, "knee_" + suffix, Vector3(side * 0.012, -0.37, 0.025))
		_ellipsoid(knee, Vector3.ZERO, Vector3(0.09, 0.075, 0.08), copper)
		_segment(knee, Vector3.ZERO, Vector3(0, -0.35, 0.09), 0.065, skin)
		_taper(knee, Vector3(0, -0.15, 0.08), 0.05, 0.07, 0.23, dark)
		var foot: Node3D = _joint(knee, "foot_" + suffix, Vector3(0, -0.35, 0.09))
		_segment(foot, Vector3(0, 0, 0), Vector3(0, -0.075, -0.16), 0.068, dark)
		for toe in range(2):
			_segment(foot, Vector3((toe - 0.5) * 0.065, -0.04, -0.1), Vector3((toe - 0.5) * 0.07, -0.09, -0.22), 0.022, bone)
	# Compact third person resonance rifle; parented to torso for an aiming stance.
	gun_root = _joint(chest, "gun", Vector3(0.17, -0.04, -0.27))
	_segment(gun_root, Vector3(0, 0, 0.12), Vector3(0, 0, -0.45), 0.065, dark)
	for side in [-1.0, 1.0]:
		_segment(gun_root, Vector3(side * 0.085, 0, -0.18), Vector3(side * 0.065, 0, -0.62), 0.026, copper)
	_taper(gun_root, Vector3(0, 0.02, -0.25), 0.05, 0.025, 0.17, crystal_material)
	for mesh in meshes:
		original_materials[mesh.get_instance_id()] = mesh.material_override

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _joint(parent: Node3D, joint_name: String, at: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	parent.add_child(joint)
	joint.position = at
	joints[joint_name] = joint
	return joint

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	instance.position = at
	meshes.append(instance)
	return instance

func _ellipsoid(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var item: MeshInstance3D = _mesh(parent, sphere, at, material)
	item.scale = size
	return item

func _taper(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 6
	shape.rings = 1
	return _mesh(parent, shape, at, material)

func _segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var item: MeshInstance3D = _taper(parent, (a + b) * 0.5, radius * 0.8, radius, a.distance_to(b), material)
	var direction: Vector3 = (b - a).normalized()
	item.quaternion = Quaternion(Vector3.UP, direction)
	return item

func set_reconstruction(value: float, use_acoustic: bool = true) -> void:
	reconstruction = clampf(value, 0.0, 1.0)
	if use_acoustic != acoustic_mode:
		acoustic_mode = use_acoustic
		for item in meshes:
			item.material_override = echo_material if acoustic_mode else original_materials.get(item.get_instance_id())
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if acoustic_mode else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if acoustic_mode:
		echo_material.set_shader_parameter("confidence", reconstruction)
	visible = reconstruction > 0.025 or not acoustic_mode

func set_contrast(value: float) -> void:
	if echo_material != null:
		echo_material.set_shader_parameter("silhouette_contrast", clampf(value, 0.7, 1.5))

func animate(delta: float, velocity: Vector3, stance: String, aiming: bool, reloading: bool, interacting: bool, alive: bool) -> void:
	animation_time += delta
	damage_flash = move_toward(damage_flash, 0.0, delta * 5.0)
	shot_flash = move_toward(shot_flash, 0.0, delta * 9.0)
	ping_flash = move_toward(ping_flash, 0.0, delta * 1.8)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: float = clampf(speed / 4.5, 0.0, 1.5)
	walk_phase += delta * speed * 1.9
	var crouch: bool = stance == "crouch" or stance == "slide"
	var crouch_amount: float = 0.42 if crouch else 0.0
	scale.y = lerpf(scale.y, 0.9 if crouch else 1.0, minf(delta * 12.0, 1.0))
	death_blend = move_toward(death_blend, 0.0 if alive else 1.0, delta * 2.7)
	body_root.position.y = -crouch_amount + sin(walk_phase * 2.0) * 0.022 * moving - death_blend * 0.63
	body_root.rotation.z = damage_flash * 0.08 + death_blend * 1.2
	body_root.rotation.x = 0.06 * moving + (0.34 if stance == "slide" else 0.0)
	var chest: Node3D = joints.chest
	chest.rotation.y = sin(walk_phase) * 0.055 * moving
	chest.rotation.x = sin(animation_time * 1.5) * 0.012 + (0.12 if crouch else 0.0)
	mask_root.rotation.x = -0.06 + ping_flash * -0.16
	mask_root.rotation.y = sin(animation_time * 0.4) * 0.045
	for side in [-1.0, 1.0]:
		var suffix: String = "left" if side < 0 else "right"
		var phase: float = walk_phase + (0.0 if side < 0 else PI)
		var leg: Node3D = joints["leg_" + suffix]
		var knee: Node3D = joints["knee_" + suffix]
		leg.rotation.x = sin(phase) * 0.6 * moving - (0.7 if crouch else 0.0)
		knee.rotation.x = maxf(0.0, -sin(phase)) * 0.75 * moving + (1.25 if crouch else 0.12)
		var arm: Node3D = joints["arm_" + suffix]
		var elbow: Node3D = joints["elbow_" + suffix]
		arm.rotation.x = -0.65 if aiming else sin(phase + PI) * 0.35 * moving - 0.25
		arm.rotation.z = side * (0.15 + (0.2 if reloading else 0.0))
		elbow.rotation.x = -0.85 if aiming else -0.42
		if interacting:
			arm.rotation.x = -1.1 + sin(animation_time * 3.0) * 0.05
			elbow.rotation.x = -0.35
	gun_root.position.z = -0.27 + shot_flash * 0.06
	gun_root.rotation.x = -shot_flash * 0.18 + (0.6 if reloading else 0.0)
	if acoustic_mode:
		echo_material.set_shader_parameter("pulse", damage_flash + ping_flash)
