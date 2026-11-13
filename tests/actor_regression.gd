extends SceneTree
const Actor = preload("res://scripts/actor.gd")
class SilentAcoustics extends Node:
	var events: int = 0
	func emit_sound(_a, _c, _o = Vector3.INF, _d = {}):
		events += 1
	func ping(_a):
		return true
class SilentAudio extends Node:
	func play_event(_c, _o, _i = 1.0):
		pass
class StubGame extends Node3D:
	var actors: Array = []
	var human = null
	var phase = "playing"
	var settings = {"fov": 85.0, "camera_motion": false}
	var balance = {}
	var elapsed: float = 0
	var attacker_team: int = 0
	var acoustics
	var audio
	var gadgets = null
	var dead_count: int = 0
	func get_observer():
		return human
	func on_actor_hit(_a, _b, _c, _d):
		pass
	func on_actor_died(_a, _b):
		dead_count += 1
var game
var failures: Array = []
func _initialize():
	call_deferred("run")
func expect(value: bool, label: String):
	if not value:
		failures.append(label)
	print("ACTOR_CHECK %s %s" % ["PASS" if value else "FAIL", label])
func frames(count: int):
	for i in range(count):
		await physics_frame
func run():
	game = StubGame.new()
	root.add_child(game)
	game.acoustics = SilentAcoustics.new()
	game.add_child(game.acoustics)
	game.audio = SilentAudio.new()
	game.add_child(game.audio)
	var floor_body = StaticBody3D.new()
	var floor_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	floor_shape.shape = box
	floor_shape.position.y = -.5
	floor_body.add_child(floor_shape)
	game.add_child(floor_body)
	var a = Actor.new()
	game.add_child(a)
	a.setup(game, 0, 0, false, Vector3(0,.05,10))
	game.actors.append(a)
	var b = Actor.new()
	game.add_child(b)
	b.setup(game, 10, 1, false, Vector3(0,.05,0))
	game.actors.append(b)
	await frames(10)
	expect(absf(a.rotation.y) < .05, "attack faces map centre")
	a.apply_command({"move": Vector3.FORWARD, "sprint": true, "look": Vector3.FORWARD})
	await frames(45)
	expect(a.global_position.z < 6.3, "sprint travels with physical controller")
	expect(game.acoustics.events > 1, "movement emits footstep events")
	a.apply_command({"move": Vector3.FORWARD, "sprint": true, "crouch": true, "look": Vector3.FORWARD})
	await frames(2)
	expect(a.stance == "slide", "sprint crouch starts slide")
	expect(a._shape.height < 1.4, "slide lowers hitbox")
	a.apply_command({"move": Vector3.ZERO, "crouch": false, "look": Vector3.FORWARD})
	await frames(60)
	expect(a._shape.height > 1.7, "stand restores hitbox")
	a.global_position = Vector3(0,.04,6)
	b.global_position = Vector3(0,.04,0)
	a.apply_command({"fire": true, "aim": true, "look": Vector3.FORWARD})
	await frames(65)
	expect(not b.alive, "rifle hits and eliminates perceived-space target")
	expect(game.dead_count == 1, "death is reported once")
	expect(a.stats.kills == 1 and a.stats.damage >= 100, "combat statistics recorded")
	var retained: float = b.health
	b.take_damage(500, a)
	expect(b.health == retained and game.dead_count == 1, "dead target ignores repeated damage")
	a.apply_command({"interact": true, "fire": true})
	await frames(20)
	var previous_ammo: int = a.ammo
	await frames(20)
	expect(a.ammo == previous_ammo, "interaction blocks firing")
	a.apply_command({"reload": true})
	await frames(120)
	expect(a.ammo == 20 and a.reserve < 80, "reload consumes reserve and refills magazine")
	a._switch_weapon(1)
	expect(a.ammo == 10 and a.weapon_index == 1, "pistol switching uses separate magazine")
	a.set_reconstruction(0.0)
	expect(not a.visual.visible and a.collision_layer == 2, "invisibility preserves collision hitbox")
	# A low, solid obstacle is climbed only after both swept body paths clear.
	a.apply_command({})
	var obstacle = StaticBody3D.new()
	var obstacle_collision = CollisionShape3D.new()
	var obstacle_shape = BoxShape3D.new()
	obstacle_shape.size = Vector3(2, .8, 1)
	obstacle_collision.shape = obstacle_shape
	obstacle.add_child(obstacle_collision)
	game.add_child(obstacle)
	obstacle.global_position = Vector3(4, .4, 4.9)
	a.global_position = Vector3(4, .04, 6)
	a.velocity = Vector3.ZERO
	await frames(5)
	a.apply_command({"jump": true, "look": Vector3.FORWARD})
	await frames(30)
	expect(a.global_position.y > .78 and a.global_position.z < 5.2, "mantle climbs actual low obstacle without teleport")
	# A full-height wall cannot pass the ledge probe and remains impassable.
	obstacle_shape.size = Vector3(2, 3, 1)
	obstacle.global_position = Vector3(4, 1.5, 4.9)
	a.global_position = Vector3(4, .04, 6)
	a.velocity = Vector3.ZERO
	a._mantle_cooldown = 0.0
	a.apply_command({})
	await frames(5)
	a.apply_command({"jump": true, "move": Vector3.FORWARD, "look": Vector3.FORWARD})
	await frames(30)
	expect(a._mantle_points.is_empty() and a.global_position.z > 5.6, "full-height wall rejects mantle and movement")
	game.settings.mode = "tutorial"
	b.alive = true
	b.health = 100.0
	b.take_damage(500, a)
	expect(b.alive and b.health == 25.0, "tutorial target remains alive for interactive lessons")
	print("ACTOR_RESULT failures=%d" % failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
