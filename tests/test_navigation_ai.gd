extends SceneTree
const Navigation = preload("res://scripts/navigation.gd")
const Bot = preload("res://scripts/bot.gd")
const Level = preload("res://scripts/level.gd")

class StubLevel:
	extends RefCounted
	var nav_bounds: Rect2 = Rect2(-12,-12,24,24)
	var nav_obstacles: Array[Rect2] = [Rect2(-1,-8,2,16)]
	var cover_points: Array = [Vector3(3,0,4),Vector3(-3,0,4)]
	var spawns: Dictionary = {"attack":[Vector3(-8,0,8)], "defend":[Vector3(8,0,-8)]}
	func get_zone(_point: Vector3) -> String:
		return "TEST"

class StubAcoustics:
	extends RefCounted
	var contacts: Array = []
	func contacts_for(_actor) -> Array:
		return contacts
	func has_line_of_sight(_from: Vector3, _to: Vector3) -> bool:
		return true

class StubActor:
	extends Node3D
	var actor_id: int = 10
	var team: int = 1
	var alive: bool = true
	var extracted: bool = false
	var health: float = 100
	var ammo: int = 20
	var reserve: int = 80
	var reload_left: float = 0
	var ping_cooldown: float = 0
	var aim_direction: Vector3 = Vector3.FORWARD
	var gadget_loadout: Array = ["ear","bell"]
	var gadget_used: Array = [false,false]
	var last_command: Dictionary = {}
	func eye_position() -> Vector3:
		return global_position + Vector3.UP *1.6
	func apply_command(command: Dictionary) -> void:
		last_command = command

class StubGame:
	extends Node3D
	var settings: Dictionary = {"difficulty":1,"seed":42}
	var metrics: Dictionary = {"seed":42}
	var phase: String = "playing"
	var attacker_team: int = 0
	var time_left: float = 120
	var elapsed: float = 8
	var round_index: int = 0
	var extraction_alerts: Dictionary = {}
	var actors: Array = []
	var bots: Array = []
	var human = null
	var level = StubLevel.new()
	var acoustics = StubAcoustics.new()
	var navigation = Navigation.new()
	var exits: Array = [{"id":"A","name":"ARCHE","position":Vector3(8,0,-8),"radius":3.0,"duration":5.0},{"id":"B","name":"VEINE","position":Vector3(-8,0,-8),"radius":3.0,"duration":5.0}]
	func active_exits() -> Array:
		return exits
	func notify(_message: String, _team: int = -1) -> void:
		pass

var failures: int = 0
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for team_size in [1,2,3]:
		var sanctuary = Level.new()
		root.add_child(sanctuary)
		sanctuary.build(team_size)
		var navigation = Navigation.new()
		navigation.setup(sanctuary)
		var all_connected: bool = true
		var all_safe: bool = true
		var valid_spawns: bool = true
		for role in ["attack", "defend"]:
			for spawn in sanctuary.spawns[role]:
				valid_spawns = valid_spawns and navigation.is_walkable(spawn)
				for exit_data in sanctuary.exits:
					var route: PackedVector3Array = navigation.find_path(spawn,exit_data.position)
					var connected: bool = not route.is_empty()
					if connected:
						connected = route[-1].distance_to(exit_data.position) < float(exit_data.radius) - 0.5
					all_connected = all_connected and connected
					var route_previous: Vector3 = spawn
					for route_point in route:
						all_safe = all_safe and navigation.segment_walkable(route_previous,route_point)
						route_previous = route_point
		check(valid_spawns,"%dv%d all actor spawns are walkable" % [team_size,team_size])
		check(all_connected,"%dv%d every spawn reaches every active exit" % [team_size,team_size])
		check(all_safe,"%dv%d all simplified routes preserve wall clearance" % [team_size,team_size])
		sanctuary.free()
	var game = StubGame.new()
	root.add_child(game)
	game.navigation.setup(game.level)
	var path: PackedVector3Array = game.navigation.find_path(Vector3(-8,0,0),Vector3(8,0,0))
	check(path.size() >= 3,"navigation routes around an opaque wall")
	var previous: Vector3 = Vector3(-8,0,0)
	var safe: bool = true
	for point in path:
		safe = safe and game.navigation.segment_walkable(previous,point)
		previous = point
	check(safe,"smoothed path never cuts inflated wall corners")
	check(not game.navigation.is_walkable(Vector3.ZERO),"solid wall cell is non walkable")
	check(not game.navigation.is_walkable(Vector3(100,0,100)),"outside world is non walkable")
	check(game.navigation.is_walkable(Vector3(4,0,4)),"open floor is walkable")
	var actor = StubActor.new()
	game.add_child(actor)
	actor.position = Vector3(8,0,-5)
	game.actors.append(actor)
	var bot = Bot.new()
	bot.setup(game,actor,0)
	game.bots.append(bot)
	game.extraction_alerts["A"] = 8.0
	bot.tick(0.3)
	check(bot.state == "INTERCEPT","near defender reacts to public extraction alarm")
	check(bot.goal.distance_to(Vector3(8,0,-8)) <0.1,"alarm provides gate objective only")
	check(bot._best_contact.is_empty(),"extraction alarm does not create an enemy contact")
	check(actor.last_command.ping,"defender pings the activated gate")
	game.extraction_alerts.clear()
	game.acoustics.contacts = [{"target_id":-71,"team":0,"position":Vector3(5,0,-5),"confidence":0.64,"state":2,"age":0.1,"confirmed":false,"visible":true,"category":"run"}]
	bot.tick(0.3)
	check(bot.state == "INVESTIGATE","ordinary false acoustic contact attracts investigation")
	check(not actor.last_command.fire,"bot never fires precisely at an unconfirmed contact")
	for step in range(30):
		bot.tick(0.3)
	check(bot.state != "INVESTIGATE" and bot._best_contact.is_empty(),"unconfirmed search is bounded and returns to objective")
	game.acoustics.contacts = [{"target_id":77,"team":0,"position":Vector3(8,0,-10),"confidence":1.0,"state":4,"age":0.0,"confirmed":true,"visible":true,"category":"ping"}]
	bot.tick(0.3)
	check(bot.state == "ENGAGE","confirmed acoustic silhouette enters combat")
	check(not actor.last_command.fire,"first confirmed acquisition respects reaction delay")
	for step in range(12):
		bot.tick(0.1)
	check(actor.last_command.fire,"reaction elapsed and aligned visible contact permits combat")
	var other = StubActor.new()
	other.actor_id =11
	game.add_child(other)
	other.position = Vector3(-8,0,-4)
	game.actors.append(other)
	var other_bot = Bot.new()
	other_bot.setup(game,other,1)
	game.bots.append(other_bot)
	game.acoustics.contacts = []
	game.extraction_alerts["A"] =8.0
	bot.tick(0.3)
	other_bot.tick(0.3)
	check(bot.state == "INTERCEPT" and other_bot.state != "INTERCEPT","one assigned responder prevents team convergence")
	bot.set_order("hold",Vector3(8,0,-5))
	game.extraction_alerts.clear()
	bot.tick(0.3)
	check(bot.state == "HOLD","ally hold order changes objective")
	actor.team =0
	actor.position =Vector3(8,0,-8)
	bot._order=""
	bot._objective_exit =game.exits[0]
	bot._route_left=10
	bot.tick(0.3)
	check(bot.state == "EXTRACT" and actor.last_command.interact,"attacker inside exit holds extraction command")
	print("AI TEST FAILURES: ",failures)
	game.free()
	quit(1 if failures else 0)
