extends SceneTree
## Headless acoustic/gadget regressions using the public contracts, real physics rays.
const AcousticScript = preload("res://scripts/acoustics.gd")
const GadgetScript = preload("res://scripts/gadgets.gd")
var failures: int = 0
var assertions: int = 0
var world

class TestActor:
	extends CharacterBody3D
	var actor_id: int = 0
	var team: int = 0
	var is_human: bool = false
	var alive: bool = true
	var extracted: bool = false
	var ping_cooldown: float = 0.0
	var stats: Dictionary = {"pings": 0, "gadgets": 0}
	var gadget_loadout: Array = ["decoy", "thorn"]
	var gadget_used: Array = [false, false]
	var aim_direction: Vector3 = Vector3(1, 0, 0)
	var reconstruction: float = 0.0
	func eye_position() -> Vector3:
		return global_position + Vector3.UP * 1.5
	func set_reconstruction(value: float) -> void:
		reconstruction = value

class TestAudio:
	extends Node
	var heard: Array = []
	func play_event(category: String, origin: Vector3, intensity: float = 1.0) -> void:
		heard.append({"category": category, "position": origin, "intensity": intensity})

class TestLevel:
	extends Node3D
	func get_zone(_position: Vector3) -> String:
		return "Zone de test"

class TestGame:
	extends Node3D
	var actors: Array = []
	var human
	var acoustics
	var gadgets
	var audio
	var level
	var phase: String = "playing"
	var attacker_team: int = 0
	var balance: Dictionary = {}
	var settings: Dictionary = {"wave_intensity": 1.0}
	var messages: Array = []
	func get_observer():
		return human
	func notify(message: String, _team: int = -1) -> void:
		messages.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = TestGame.new()
	root.add_child(world)
	world.audio = TestAudio.new()
	world.add_child(world.audio)
	world.level = TestLevel.new()
	world.add_child(world.level)
	world.acoustics = AcousticScript.new()
	world.add_child(world.acoustics)
	world.acoustics.setup(world)
	world.acoustics.set_physics_process(false)
	world.gadgets = GadgetScript.new()
	world.add_child(world.gadgets)
	world.gadgets.setup(world)
	world.gadgets.set_physics_process(false)
	_add_box(Vector3(0, -0.5, 0), Vector3(100, 1, 100))
	var observer = _actor(1, 0, Vector3.ZERO)
	var target = _actor(2, 1, Vector3(6, 0, 0))
	world.human = observer
	await physics_frame
	await physics_frame
	_check(world.acoustics.contact_for(observer, target.actor_id).is_empty(), "A silent stationary enemy starts unknown")
	_check(world.acoustics.ping(observer), "Ping accepts an available source")
	_check(not world.acoustics.ping(observer), "Cooldown rejects repeated ping")
	_advance(0.75)
	var contact: Dictionary = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.is_empty() and contact.confirmed, "LOS ping confirms an immobile enemy")
	_check(not contact.is_empty() and contact.position.distance_to(target.global_position) < 0.05, "Confirmed position is the body origin")
	_check(not world.acoustics.contact_for(target, observer.actor_id).is_empty(), "Ping exposes its emitter symmetrically")
	_check(target.reconstruction > 0.8, "Confirmed observer drives enemy reconstruction")
	_advance(1.3)
	contact = world.acoustics.contact_for(observer, target.actor_id)
	var frozen: Vector3 = contact.get("position", Vector3.ZERO)
	target.position = Vector3(10, 0, 0)
	_advance(0.1)
	contact = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.confirmed and not contact.visible, "Expired signal stops live tracking")
	_check(contact.position.distance_to(frozen) < 0.05, "Old acoustic footprints remain frozen")
	_advance(7.0)
	_check(world.acoustics.contacts_for(observer).is_empty(), "Old memories expire")
	_reset()
	target.position = Vector3(6, 0, 0)
	var wall: StaticBody3D = _add_box(Vector3(3, 2, 0), Vector3(0.35, 4, 10))
	await physics_frame
	await physics_frame
	world.acoustics.ping(observer)
	_advance(0.75)
	contact = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.is_empty() and contact.state <= 2, "A nearby occluded ping produces approximate evidence")
	_check(not contact.is_empty() and not contact.confirmed and not contact.visible, "An opaque wall never grants a silhouette")
	_check(not contact.is_empty() and contact.position.distance_to(target.global_position) > 0.5, "An occluded estimate has stable uncertainty")
	wall.queue_free()
	await physics_frame
	await physics_frame
	_reset()
	world.acoustics.emit_sound(target, "sprint")
	_advance(0.3)
	contact = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.is_empty(), "Sprint is audible inside its nominal range")
	_reset()
	target.position = Vector3(2, 0, 0)
	world.acoustics.emit_sound(target, "reload")
	_advance(0.2)
	contact = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.is_empty() and contact.confirmed, "Nearby reload cannot remain invisible")
	_reset()
	target.position = Vector3(20, 0, 0)
	world.acoustics.emit_sound(target, "impact", Vector3(2, 0, 0))
	_advance(0.2)
	_check(world.acoustics.contact_for(observer, target.actor_id).is_empty(), "Remote bullet impacts do not reveal the shooter")
	_reset()
	target.position = Vector3(5, 0, 0)
	observer.gadget_loadout = ["decoy", "veil"]
	observer.aim_direction = Vector3(1, 0, 0)
	_check(world.gadgets.deploy(observer, 0), "Decoy can be placed on unobstructed floor")
	_check(not world.gadgets.deploy(observer, 0), "A gadget is limited to one use per slot")
	for i in range(50):
		world.gadgets._physics_process(0.02)
		world.acoustics._physics_process(0.02)
	var decoy_records: Array = world.acoustics.contacts_for(target)
	var ordinary_decoy: bool = false
	for record in decoy_records:
		if int(record.target_id) < -1000 and record.category == "sprint":
			ordinary_decoy = not record.has("decoy") and not record.has("fake")
	_check(ordinary_decoy, "A decoy supplies ordinary sprint evidence, with no fake flag")
	_reset()
	observer.gadget_loadout = ["thorn", "veil"]
	observer.gadget_used = [false, false]
	target.position = Vector3(3, 0, 1)
	_check(world.gadgets.deploy(observer, 0), "Thorn places a reachable trap")
	for i in range(50):
		world.gadgets._physics_process(0.02)
		world.acoustics._physics_process(0.02)
	_check(world.gadgets.devices.is_empty(), "An enemy crossing the armed thorn consumes it")
	contact = world.acoustics.contact_for(observer, target.actor_id)
	_check(not contact.is_empty() and contact.confirmed, "A triggered trap confirms in LOS even for stationary/crouched actors")
	_reset()
	observer.gadget_loadout = ["veil", "thorn"]
	_check(world.gadgets.deploy(observer, 0), "Veil deploys")
	if not world.gadgets.devices.is_empty():
		var device = world.gadgets.devices[0]
		_check(world.gadgets.jam_factor(device.global_position, 1) > 0.9, "Veil jams enemy observations in its radius")
		_check(is_zero_approx(world.gadgets.jam_factor(device.global_position, 0)), "Friendly observations are not jammed")
		device.take_damage(100.0, target)
		_check(world.gadgets.devices.is_empty(), "A device can be destroyed by damage")
	_reset()
	observer.position = Vector3.ZERO
	target.position = Vector3(5, 0, 0)
	target.aim_direction = Vector3(-1, 0, 0)
	target.gadget_loadout = ["ear", "bell"]
	_check(world.gadgets.deploy(target, 0), "A defender can deploy the stone ear")
	_advance_devices(1.0)
	contact = world.acoustics.contact_for(target, observer.actor_id)
	_check(not contact.is_empty() and contact.confirmed and world.gadgets.devices.is_empty(), "The stone ear detects a silent infiltrator")
	_reset()
	_check(world.gadgets.deploy(target, 1), "A defender can deploy the broken bell")
	_advance_devices(1.0)
	contact = world.acoustics.contact_for(target, observer.actor_id)
	_check(not contact.is_empty() and contact.confirmed, "The broken bell marks without damage")
	_reset()
	target.gadget_loadout = ["choir", "ear"]
	_check(world.gadgets.deploy(target, 0), "A defender can deploy the crystal choir")
	_advance_devices(1.5)
	contact = world.acoustics.contact_for(target, observer.actor_id)
	_check(not contact.is_empty() and contact.confirmed, "The choir actively scans silent enemies")
	_reset()
	target.gadget_loadout = ["ear", "bell"]
	wall = _add_box(Vector3(1, 2, 0), Vector3(0.3, 4, 10))
	await physics_frame
	await physics_frame
	_check(world.gadgets.deploy(target, 0), "A trap beside a wall can be placed on valid ground")
	_advance_devices(1.0)
	_check(world.gadgets.devices.size() == 1, "A solid wall blocks trap triggering from another room")
	wall.queue_free()
	await physics_frame
	await physics_frame
	_reset()
	var distant_ally = _actor(3, 0, Vector3(-40, 0, 0))
	world.acoustics.emit_sound(target, "shot")
	_advance(0.2)
	contact = world.acoustics.contact_for(distant_ally, target.actor_id)
	_check(not contact.is_empty() and not contact.confirmed and not contact.visible and contact.confidence <= 0.48, "Team callouts preserve uncertainty and never grant remote silhouettes")
	world.actors.erase(distant_ally)
	distant_ally.queue_free()
	_reset()
	_check(world.acoustics.memories.is_empty() and world.acoustics.pending.is_empty() and world.gadgets.devices.is_empty(), "Round cleanup clears acoustic events, memories and gadgets")
	print("ACOUSTIC_REGRESSIONS: %d assertions; %d failures" % [assertions, failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _actor(id: int, team: int, position: Vector3):
	var actor: TestActor = TestActor.new()
	actor.actor_id = id
	actor.team = team
	actor.collision_layer = 2
	actor.collision_mask = 1
	world.add_child(actor)
	actor.position = position
	world.actors.append(actor)
	return actor

func _add_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = position
	return body

func _advance(seconds: float) -> void:
	for i in range(int(ceil(seconds * 60.0))):
		world.acoustics._physics_process(1.0 / 60.0)

func _reset() -> void:
	world.acoustics.clear()
	world.gadgets.clear()
	for actor in world.actors:
		actor.ping_cooldown = 0.0
		actor.gadget_used = [false, false]
		actor.set_reconstruction(0.0)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS · ", message)
	else:
		failures += 1
		push_error("FAIL · " + message)

func _advance_devices(seconds: float) -> void:
	for i in range(int(ceil(seconds * 60.0))):
		world.gadgets._physics_process(1.0 / 60.0)
		world.acoustics._physics_process(1.0 / 60.0)
