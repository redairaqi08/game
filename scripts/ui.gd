extends CanvasLayer

# All hostile HUD information comes from the observer's acoustic memory.
const INK := Color("e3e8dc")
const MUTED := Color("8caaa7")
const TEAL := Color("69e1d1")
const AMBER := Color("edb570")
const BG := Color(0.025, 0.055, 0.065, 0.94)
const FONT = preload("res://assets/fonts/Interface-Regular.ttf")
const BOLD = preload("res://assets/fonts/Interface-Bold.ttf")
const MONO = preload("res://assets/fonts/Telemetry.ttf")
const GADGETS := {
	"decoy": ["ÉCHO ERRANT", "Leurre mobile · attire les investigations"],
	"veil": ["VOILE MUET", "Brouillage local · masque une traversée"],
	"thorn": ["ÉPINE D'ÉCOUTE", "Piège de proximité · surveille vos arrières"],
	"ear": ["OREILLE DE PIERRE", "Capteur · détecte une infiltration silencieuse"],
	"bell": ["CLOCHE BRISÉE", "Mine acoustique · révèle sans infliger de dégâts"],
	"choir": ["CHŒUR DE CRISTAL", "Balise · émet plusieurs impulsions de reconnaissance"]
}
const TUTORIAL := [
	["01 / LE MOUVEMENT", "Déplacez-vous, sprintez, sautez, puis accroupissez-vous. Sprint + accroupissement déclenche une glissade."],
	["02 / LE BRUIT", "Écoutez les pas et observez leurs ondes. La marche porte à 8 m ; la course, à 20 m. Approchez d'un contact."],
	["03 / LA PERCEPTION", "Une onde donne une hypothèse. Une silhouette demande un signal suffisant et une ligne de vue. Repérez un contact."],
	["04 / LE PING", "Appuyez sur F. Le ping détecte aussi un ennemi immobile, mais signale votre présence. Recharge : 8 secondes."],
	["05 / LE COMBAT", "Visez avec le clic droit, tirez avec le clic gauche. Rechargez avec R ; 1 / 2 change d'arme."],
	["06 / LA DIVERSION", "Utilisez votre gadget principal avec G. Un Écho errant reproduit une course et peut détourner un Veilleur."],
	["07 / LA SURVEILLANCE", "Posez votre second gadget avec T. Un piège surveille un passage ; ses alertes restent soumises à l'occlusion."],
	["08 / L'EXTRACTION", "Gagnez une arche marquée A, B ou C. Maintenez E dans le cercle. Vous restez vulnérable pendant l'extraction."]
]

var game
var root: Control
var menu: Control
var content: VBoxContainer
var hud: Control
var pause_panel: Control
var result_panel: Control
var map_overlay: Control
var order_panel: Control
var map_canvas: Control
var status_label: Label
var objective_label: Label
var zone_label: Label
var clock_label: Label
var score_label: Label
var health_label: Label
var health_bar: ProgressBar
var ammo_label: Label
var reserve_label: Label
var ping_label: Label
var gadget_label: Label
var feed_label: Label
var team_label: Label
var interact_label: Label
var extraction_bar: ProgressBar
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_text: Label
var tutorial_step := 0
var tutorial_elapsed := 0.0
var tutorial_start := Vector3.ZERO
var tutorial_flags: Dictionary = {}
var notifications: Array = []
var page := "play"
var selectors: Dictionary = {}
var selected_options: Dictionary = {}
var hit_left := 0.0
var damage_left := 0.0
var binding_action := ""
var binding_button: Button
var paused := false
var last_phase := ""
var is_map_open := false
var theme_resource: Theme

class EchoGraphic extends Control:
	var clock := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		for index in range(5):
			var r := radius * (0.22 + 0.17 * index)
			draw_arc(center, r, -PI * 0.94 + index * 0.13, PI * 0.78, 72, Color(0.34, 0.76, 0.71, 0.16 + index * 0.025), 1.0, true)
		var r := radius * fmod(clock * 0.15, 1.0)
		draw_arc(center, r, 0.0, TAU, 80, Color(0.4, 0.95, 0.86, 0.25 * (1.0 - r / maxf(radius, 1.0))), 1.3, true)
		draw_line(center - Vector2(radius * 0.6, 0), center + Vector2(radius * 0.6, 0), Color(0.4, 0.8, 0.74, 0.12))
		draw_circle(center, 3.0, Color("69e1d1"))

class HUDInk extends Control:
	var owner_ui
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if owner_ui == null or owner_ui.game == null or owner_ui.game.phase != "playing":
			return
		var center := size * 0.5
		if owner_ui.damage_left>0:
			draw_rect(Rect2(Vector2.ZERO,size),Color(0.65,0.14,0.10,owner_ui.damage_left*0.42),false,18.0)
		var observer = owner_ui.game.get_observer()
		var color := Color(0.85, 0.97, 0.9, 0.65)
		if observer != null and observer.command_interact:
			color.a *= 0.2
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * 5.0, center + direction * 10.0, color, 1.0, true)
		if owner_ui.hit_left > 0.0:
			var fade := clampf(owner_ui.hit_left / 0.22, 0, 1)
			for direction in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
				draw_line(center + direction * 11.0, center + direction * 17.0, Color(1,0.77,0.4,fade), 2.0, true)
		if observer == null or owner_ui.game.acoustics == null:
			return
		var records: Array = owner_ui.game.acoustics.contacts_for(observer)
		for record in records:
			if float(record.get("confidence", 0)) < 0.12 or float(record.get("age", 99)) > 5:
				continue
			var point: Vector3 = record.get("position", Vector3.ZERO)
			var delta: Vector3 = point - observer.global_position
			var forward: Vector3 = observer.aim_direction
			var angle := atan2(delta.x, delta.z) - atan2(forward.x, forward.z)
			var direction := Vector2(-sin(angle), -cos(angle))
			var radius := minf(size.x, size.y) * 0.31
			var strength := clampf(float(record.get("confidence",0.3)),0.15,0.8)
			var tint := Color(0.93,0.71,0.44,strength * 0.7)
			var arc_angle := direction.angle()
			draw_arc(center, radius, arc_angle - 0.055, arc_angle + 0.055, 10, tint, 2.0, true)

class TacticalMap extends Control:
	var owner_ui
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_delta: float) -> void:
		if is_visible_in_tree(): queue_redraw()
	func _project(point: Vector3, bounds: Rect2, area: Rect2) -> Vector2:
		return area.position + (Vector2(point.x,point.z) - bounds.position) / bounds.size * area.size
	func _draw() -> void:
		if owner_ui == null or owner_ui.game.level == null:
			return
		var level = owner_ui.game.level
		var bounds: Rect2 = level.nav_bounds
		if bounds.size.x <= 0 or bounds.size.y <= 0: return
		var area := Rect2(Vector2(70,55),size-Vector2(140,110))
		var ratio: float = minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
		area.size = bounds.size * ratio
		area.position = (size-area.size)*0.5
		draw_rect(area, Color(0.04,0.09,0.1,1))
		for x in range(11):
			var px := area.position.x + area.size.x*x/10.0
			draw_line(Vector2(px,area.position.y),Vector2(px,area.end.y),Color(0.3,0.6,0.57,0.09),1.0)
		for z in range(9):
			var pz := area.position.y + area.size.y*z/8.0
			draw_line(Vector2(area.position.x,pz),Vector2(area.end.x,pz),Color(0.3,0.6,0.57,0.09),1.0)
		for obstacle in level.nav_obstacles:
			var rect: Rect2 = obstacle
			var projected := Rect2(area.position+(rect.position-bounds.position)*ratio,rect.size*ratio)
			draw_rect(projected,Color(0.24,0.34,0.34,0.9))
			draw_rect(projected,Color(0.4,0.54,0.5,0.2),false,1.0)
		for zone in level.zones:
			var point := _project(zone.get("position",Vector3.ZERO),bounds,area)
			draw_string(owner_ui.FONT,point+Vector2(5,18),str(zone.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.57,0.67,0.64,0.65))
		for exit_data in owner_ui.game.active_exits():
			var point := _project(exit_data.position,bounds,area)
			var active: bool = owner_ui.game.extraction_alerts.has(str(exit_data.id))
			var tint := Color("edb570") if active else Color("69e1d1")
			draw_arc(point,11,0,TAU,32,tint,2,true)
			draw_string(owner_ui.BOLD,point+Vector2(-4,5),str(exit_data.id),HORIZONTAL_ALIGNMENT_LEFT,-1,15,tint)
		var observer = owner_ui.game.get_observer()
		if observer != null:
			for actor in owner_ui.game.actors:
				if not is_instance_valid(actor) or actor.team != observer.team or not actor.alive or actor.extracted:
					continue
				var point := _project(actor.global_position,bounds,area)
				var tint := Color("e3e8dc") if actor == observer else Color("69e1d1")
				draw_circle(point,5,tint)
				var facing: Vector3 = actor.aim_direction
				draw_line(point,point+Vector2(facing.x,facing.z)*15,tint,2,true)
			if owner_ui.game.acoustics != null:
				for record in owner_ui.game.acoustics.contacts_for(observer):
					var confidence: float = float(record.get("confidence",0))
					if confidence < 0.1 or float(record.get("age",99)) > 6: continue
					var point := _project(record.get("position",Vector3.ZERO),bounds,area)
					var tint := Color(0.93,0.71,0.44,confidence*0.8)
					draw_arc(point,7+(1-confidence)*14,0,TAU,24,tint,1.3,true)
					draw_circle(point,2,tint)
		draw_rect(area,Color(0.4,0.7,0.65,0.4),false,1)

func setup(game_ref) -> void:
	game = game_ref
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_resource = _create_theme()
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_resource
	add_child(root)
	_build_menu()
	_build_hud()
	_build_pause()
	_build_map()
	_build_orders()
	show_menu()

func _create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",TEAL)
	theme.set_color("font_pressed_color","Button",Color("111f22"))
	theme.set_color("font_disabled_color","Button",Color("526260"))
	for kind in ["Button","OptionButton"]:
		var normal := _style(Color(0.05,0.1,0.11,0.85),Color(0.28,0.43,0.42,0.6),1)
		normal.content_margin_left = 18
		normal.content_margin_right = 18
		normal.content_margin_top = 7 if kind=="OptionButton" else 12
		normal.content_margin_bottom = 7 if kind=="OptionButton" else 12
		theme.set_stylebox("normal",kind,normal)
		theme.set_stylebox("hover",kind,_style(Color(0.09,0.21,0.21,0.97),TEAL,1))
		theme.set_stylebox("pressed",kind,_style(TEAL,TEAL,1))
		theme.set_stylebox("focus",kind,_style(Color(0,0,0,0),TEAL,2))
		theme.set_color("font_color",kind,INK)
		theme.set_color("font_hover_color",kind,TEAL)
	theme.set_stylebox("panel","PopupMenu",_style(Color("101f25"),Color("375451"),1))
	theme.set_color("font_color","PopupMenu",INK)
	theme.set_color("font_hover_color","PopupMenu",TEAL)
	theme.set_stylebox("hover","PopupMenu",_style(Color("20403f"),TEAL,0))
	theme.set_stylebox("panel","PanelContainer",_style(BG,Color(0.33,0.55,0.5,0.35),1))
	theme.set_stylebox("background","ProgressBar",_style(Color(0.12,0.21,0.22,0.8),Color(0,0,0,0),0))
	theme.set_stylebox("fill","ProgressBar",_style(TEAL,Color(0,0,0,0),0))
	return theme

func _style(fill: Color,border: Color,width: int=1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _full(control: Control,parent: Node) -> Control:
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

func _box(parent: Node,vertical: bool=true,gap: int=12) -> BoxContainer:
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box

func _label(parent: Node,text: String,font_size: int=18,tint: Color=INK,font: Font=FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	label.add_theme_font_override("font",font)
	parent.add_child(label)
	return label

func _paragraph(parent: Node,text: String,font_size: int=18,tint: Color=MUTED) -> Label:
	var label := _label(parent,text,font_size,tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node,text: String,callback: Callable,primary: bool=false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal",_style(TEAL,TEAL,1))
		button.add_theme_color_override("font_color",Color("112527"))
		button.add_theme_font_override("font",BOLD)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _spacer(parent: Node,height: float=12) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)
	return spacer

func _margin(parent: Node,padding: int=28) -> MarginContainer:
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,padding)
	parent.add_child(margin)
	return margin

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	return panel

func _build_menu() -> void:
	menu = Control.new()
	_full(menu,root)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	_full(shade,menu)
	shade.color = Color(0.015,0.035,0.045,0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_shade := ColorRect.new()
	menu.add_child(left_shade)
	left_shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left_shade.offset_right = 560
	left_shade.color = Color(0.015,0.038,0.05,0.88)
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := HBoxContainer.new()
	menu.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 62
	header.offset_right = -62
	header.offset_top = 32
	header.offset_bottom = 60
	_label(header,"VESPERIDE / ARCHIVES DE LA TRAME",13,MUTED,MONO).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header,"TRANSMISSION LOCALE   •   HORS LIGNE",13,TEAL,MONO)
	var left := VBoxContainer.new()
	menu.add_child(left)
	left.position = Vector2(62,128)
	left.custom_minimum_size = Vector2(390,0)
	left.add_theme_constant_override("separation",5)
	_label(left,"L E   G R A N D   S I L E N C E",13,TEAL,MONO)
	var title := _label(left,"SONAR",92,INK,BOLD)
	title.add_theme_constant_override("outline_size",0)
	_label(left,"E C H O E S   O F   T H E   H O L L O W",13,AMBER,MONO)
	_spacer(left,20)
	_paragraph(left,"Dans le Creux, chaque pas\nlaisse une vérité. Ou un mensonge.",20,Color("a9bcb7"))
	_spacer(left,28)
	for item in [["01", "JOUER", "play"],["02","ENTRAÎNEMENT","training"],["03","ÉQUIPEMENT","equipment"],["04","GUIDE","guide"],["05","UNIVERS","lore"],["06","PARAMÈTRES","settings"]]:
		var target: String = item[2]
		var b := _button(left,str(item[0])+"     "+str(item[1]),func(): _open_page(target))
		b.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),0))
		b.custom_minimum_size.y = 40
		b.add_theme_font_size_override("font_size",18)
	_spacer(left,8)
	var quit := _button(left,"QUITTER",func(): get_tree().quit())
	quit.add_theme_stylebox_override("normal",_style(Color(0,0,0,0),Color(0,0,0,0),0))
	quit.add_theme_font_size_override("font_size",13)
	quit.add_theme_color_override("font_color",MUTED)
	var card := PanelContainer.new()
	menu.add_child(card)
	card.anchor_left = 0.43
	card.anchor_right = 0.95
	card.anchor_top = 0.13
	card.anchor_bottom = 0.93
	card.add_theme_stylebox_override("panel",_style(Color(0.025,0.06,0.074,0.92),Color(0.36,0.61,0.56,0.4),1))
	var margin := _margin(card,26)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	var footer := Label.new()
	menu.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 62
	footer.offset_top = -45
	footer.text = "LE SANCTUAIRE DES TROIS ÉCHOS                          VERSION 0.1  /  ALPHA DE PRODUCTION"
	footer.add_theme_font_override("font",MONO)
	footer.add_theme_font_size_override("font_size",12)
	footer.add_theme_color_override("font_color",MUTED)

func _open_page(target: String) -> void:
	page = target
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	selectors.clear()
	match target:
		"play": _play_page()
		"training": _training_page()
		"equipment": _equipment_page()
		"guide": _guide_page()
		"lore": _lore_page()
		"settings": _settings_page()

func _section(kicker: String,title: String,description: String) -> void:
	_label(content,kicker,12,TEAL,MONO)
	_label(content,title,34,INK,BOLD)
	_paragraph(content,description,17)
	_spacer(content,8)

func _selector(parent: Node,label_text: String,items: Array,current: int=0) -> OptionButton:
	var row := _box(parent,false,20)
	var label := _label(row,label_text,16,MUTED)
	label.custom_minimum_size.x = 175
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = 36
	for item in items: option.add_item(str(item))
	option.select(clampi(current,0,maxi(0,items.size()-1)))
	row.add_child(option)
	return option

func _play_page() -> void:
	_section("01 / INCURSION", "Écouter. Tromper. S'extraire.","Les Passeurs gagnent l'une des arches vivants. Les Veilleurs les interceptent. Chaque extraction vaut 100 points.")
	selectors.team = _selector(content,"FORMAT",["3 contre 3 · sanctuaire complet","2 contre 2 · secteur resserré","1 contre 1 · duel acoustique"],3-int(game.settings.get("team_size",3)))
	selectors.difficulty = _selector(content,"DIFFICULTÉ",["Initiation","Normal","Difficile","Expert"],int(game.settings.get("difficulty",1)))
	selectors.rounds = _selector(content,"PARTIE",["Rapide · 4 manches","Standard · 6 manches"],1 if int(game.settings.get("rounds",4))==6 else 0)
	selectors.role = _selector(content,"PREMIER RÔLE",["Passeur · attaque","Veilleur · défense"],0 if str(game.settings.get("initial_role","attack"))=="attack" else 1)
	selectors.mode = _selector(content,"RÈGLES",["Alternance équilibrée","Attaque uniquement","Défense uniquement","Simulation bots contre bots"],maxi(0,["standard","attack","defend","simulation"].find(str(game.settings.get("mode","standard")))))
	_spacer(content,8)
	_label(content,"VOTRE ÉQUIPEMENT",12,TEAL,MONO)
	selectors.primary = _selector(content,"G · PRINCIPAL",["Écho errant","Voile muet","Épine d'écoute"],0)
	selectors.secondary = _selector(content,"T · SECONDAIRE",["Écho errant","Voile muet","Épine d'écoute"],2)
	selectors.role.item_selected.connect(func(_index): _update_gadgets())
	selectors.primary.item_selected.connect(func(index):
		if selectors.secondary.selected==index: selectors.secondary.select((index+1)%3)
	)
	selectors.secondary.item_selected.connect(func(index):
		if selectors.primary.selected==index: selectors.primary.select((index+1)%3)
	)
	_update_gadgets()
	var saved_types: Array=["decoy","veil","thorn"] if selectors.role.selected==0 else ["ear","bell","choir"]
	selectors.primary.select(maxi(0,saved_types.find(str(game.settings.get("primary_gadget",saved_types[0])))))
	selectors.secondary.select(maxi(0,saved_types.find(str(game.settings.get("secondary_gadget",saved_types[2])))))
	if selectors.primary.selected==selectors.secondary.selected: selectors.secondary.select((selectors.primary.selected+1)%3)
	_spacer(content,6)
	_button(content,"LANCER L'INCURSION     →",_launch_selected,true)
	_label(content,"1 vie par manche  •  2 alliés autonomes en 3v3  •  Aucun compte requis",12,MUTED)

func _update_gadgets() -> void:
	var attack: bool = selectors.role.selected == 0
	var list: Array = ["Écho errant","Voile muet","Épine d'écoute"] if attack else ["Oreille de pierre","Cloche brisée","Chœur de cristal"]
	for key in ["primary","secondary"]:
		var option: OptionButton = selectors[key]
		var index: int = option.selected
		option.clear()
		for item in list: option.add_item(item)
		option.select(clampi(index,0,2))

func _launch_selected() -> void:
	var role: String = "attack" if selectors.role.selected==0 else "defend"
	var types: Array = ["decoy","veil","thorn"] if role=="attack" else ["ear","bell","choir"]
	var modes: Array = ["standard","attack","defend","simulation"]
	var options: Dictionary = {
		"team_size":3-selectors.team.selected,"difficulty":selectors.difficulty.selected,
		"rounds":4 if selectors.rounds.selected==0 else 6,"mode":modes[selectors.mode.selected],
		"initial_role":role,"primary_gadget":types[selectors.primary.selected],"secondary_gadget":types[selectors.secondary.selected]
	}
	_start(options)

func _start(options: Dictionary) -> void:
	selected_options = options.duplicate(true)
	tutorial_step = 0
	tutorial_elapsed = 0
	tutorial_flags.clear()
	menu.hide()
	pause_panel.hide()
	map_overlay.hide()
	order_panel.hide()
	if is_instance_valid(result_panel): result_panel.queue_free()
	hud.show()
	notifications.clear()
	game.start_match(options)
	if game.human != null: tutorial_start = game.human.global_position

func _training_page() -> void:
	_section("02 / APPRENDRE", "Le son est votre regard.","Prenez le temps d'apprendre les rythmes. Le monde reste visible ; les présences ne se reconstruisent qu'à partir d'informations acoustiques.")
	_label(content,"PARCOURS GUIDÉ",20,INK,BOLD)
	_paragraph(content,"Huit étapes progressives : mouvement, bruit, perception, ping, combat, diversion, surveillance, extraction.",17)
	_button(content,"COMMENCER LE TUTORIEL    →",func(): _start({"mode":"tutorial","team_size":1,"difficulty":0,"rounds":1,"initial_role":"attack","primary_gadget":"decoy","secondary_gadget":"thorn"}),true)
	_spacer(content,18)
	_label(content,"ENTRAÎNEMENT LIBRE",20,INK,BOLD)
	_paragraph(content,"Explorez le secteur de duel, testez vos armes et vos signatures contre des bots. Échap permet de réinitialiser la session.",17)
	_button(content,"ENTRER DANS LE SANCTUAIRE",func(): _start({"mode":"training","team_size":1,"difficulty":0,"rounds":1,"initial_role":"attack","primary_gadget":"decoy","secondary_gadget":"veil"}))
	_spacer(content,20)
	_paragraph(content,"Conseil : un ennemi parfaitement immobile peut rester invisible. Le ping peut le reconstruire, tant qu'aucun mur opaque ne le masque.",16,AMBER)

func _equipment_page() -> void:
	_section("03 / RÉSONATEURS", "La Trame se manipule.","Deux dispositifs sont choisis avant la partie. Une utilisation de chaque dispositif par manche. Leur placement engage votre stratégie.")
	for group in [["LES PASSEURS",["decoy","veil","thorn"]],["LES VEILLEURS",["ear","bell","choir"]]]:
		_label(content,str(group[0]),13,TEAL,MONO)
		for key in group[1]:
			_label(content,str(GADGETS[key][0]),18,INK,BOLD)
			_paragraph(content,str(GADGETS[key][1]),16)
		_spacer(content,12)
	_button(content,"CHOISIR MON ÉQUIPEMENT    →",func(): _open_page("play"))

func _guide_page() -> void:
	_section("04 / DOCTRINE", "Chaque bruit a un prix.","La carte ne devient jamais noire. Regardez le terrain, écoutez les présences et décidez ce que vous êtes prêt à révéler.")
	var rows: Array = [
		["DÉPLACEMENT", "ZQSD / WASD selon le clavier choisi · Souris pour regarder"],
		["MOUVEMENT", "Maj : sprint · Ctrl / C : accroupissement · Espace : saut\nSprint + accroupissement : glissade"],
		["COMBAT", "Clic gauche : tir · Clic droit : visée · R : recharge · 1 / 2 : armes"],
		["INFORMATION", "F : ping · G / T : gadgets · Tab : carte tactique"],
		["COOPÉRATION", "Alt : commandes d'équipe · E : maintenir pour s'extraire"],
		["PERCEPTION", "Signal faible → zone probable → reconstruction → contact confirmé.\nUne silhouette disparaît lorsque l'information se dégrade."],
		["EXTRACTION", "Chaque Passeur extrait rapporte 100 points à son équipe.\nChaque Passeur arrêté rapporte 100 points aux Veilleurs."]
	]
	for row in rows:
		_label(content,str(row[0]),12,TEAL,MONO)
		_paragraph(content,str(row[1]),17)
		_spacer(content,8)
	_button(content,"APPRENDRE EN JOUANT    →",func(): _open_page("training"))

func _lore_page() -> void:
	_section("05 / FRAGMENT D'ARCHIVE", "Nous étions une voix.","Sous la pierre, les Vesperides ont bâti une civilisation qui entendait son monde. Puis le Grand Silence a traversé la Trame.")
	_label(content,"LE CREUX",13,TEAL,MONO)
	_paragraph(content,"Un réseau de cavernes immenses, de cathédrales minérales et de canaux assoupis. Les colonies bioluminescentes en éclairent les veines. Rien ici n'est vraiment muet.",19)
	_spacer(content,16)
	_label(content,"LA TRAME",13,TEAL,MONO)
	_paragraph(content,"La pierre garde les vibrations. Les Vesperides en déchiffrent les retours grâce à leurs organes de résonance. Une présence devient une forme ; une forme redevient un écho.",19)
	_spacer(content,16)
	_label(content,"DEUX RÉPONSES AU SILENCE",13,TEAL,MONO)
	_paragraph(content,"Les Passeurs veulent franchir les anciens seuils et retrouver une issue. Les Veilleurs protègent les équilibres fragiles du Creux. Les uns espèrent sauver leur peuple ; les autres craignent que l'ouverture n'achève de le perdre.",19)
	_spacer(content,16)
	_paragraph(content,"« Le silence n'est pas l'absence. C'est ce qui attend une réponse. »",18,AMBER)

func _settings_page() -> void:
	_section("06 / ACCORDAGE", "Votre manière d'écouter.","Les réglages sont conservés localement. Le mode de mouvement réduit limite les oscillations et facilite la lecture des contacts.")
	_slider_setting("Sensibilité souris","mouse_sensitivity",0.0005,0.005,0.0001,0.002)
	_slider_setting("Champ de vision","fov",65,110,1,86)
	_slider_setting("Volume général","volume",0,1,0.05,0.7)
	var motion := _selector(content,"CAMÉRA",["Mouvement naturel","Mouvement réduit"],0 if bool(game.settings.get("camera_motion",true)) else 1)
	motion.item_selected.connect(func(index): game.settings.camera_motion=index==0; _save_settings())
	var graphics := _selector(content,"GRAPHISMES",["Économie","Équilibré","Élevé"],int(game.settings.get("graphics",1)))
	graphics.item_selected.connect(func(index): game.settings.graphics=index; _save_settings())
	var layout := _selector(content,"CLAVIER",["AZERTY · ZQSD","QWERTY · WASD"],0 if str(game.settings.get("layout","azerty"))=="azerty" else 1)
	layout.item_selected.connect(func(index): game.settings.layout="azerty" if index==0 else "qwerty"; _save_settings())
	_spacer(content,8)
	_paragraph(content,"Les indices visuels accompagnent les sons : ondes, contacts mémorisés, recharge du ping et alertes. La carte respecte les informations réellement perçues.",16,MUTED)
	_spacer(content,12)
	_label(content,"RÉASSIGNER LES TOUCHES",12,TEAL,MONO)
	_paragraph(content,"Cliquez une action puis pressez une touche. Échap annule. Les boutons de souris conservent leur affectation initiale sauf remplacement par une touche.",14)
	for binding in [["Avancer","move_forward"],["Reculer","move_back"],["Aller à gauche","move_left"],["Aller à droite","move_right"],["Sprinter","sprint"],["S'accroupir / glisser","crouch"],["Sauter","jump"],["Tirer","fire"],["Viser","aim"],["Recharger","reload"],["Ping","ping"],["Gadget principal","gadget_primary"],["Gadget secondaire","gadget_secondary"],["Interagir","interact"],["Carte tactique","tactical_map"],["Ordres","orders"],["Arme principale","weapon_1"],["Arme secondaire","weapon_2"],["Pause","pause"]]:
		_binding_row(str(binding[0]),str(binding[1]))
	_button(content,"RÉTABLIR LES TOUCHES",func(): game.settings.key_bindings={}; _save_settings(); _open_page("settings"))
	_button(content,"RETOUR À L'INCURSION",func(): _open_page("play"))

func _slider_setting(title: String,key: String,minimum: float,maximum: float,step: float,default_value: float) -> void:
	var row := _box(content,false,18)
	var name_label := _label(row,title,16,MUTED)
	name_label.custom_minimum_size.x = 175
	var slider := HSlider.new()
	slider.min_value=minimum
	slider.max_value=maximum
	slider.step=step
	slider.value=float(game.settings.get(key,default_value))
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y=38
	row.add_child(slider)
	var value_label := _label(row,_setting_value(key,slider.value),14,TEAL,MONO)
	value_label.custom_minimum_size.x=56
	value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value):
		game.settings[key]=value
		value_label.text=_setting_value(key,value)
		_save_settings()
		if key=="volume" and game.audio!=null: game.audio.set_volume(value)
	)

func _setting_value(key: String,value: float) -> String:
	if key=="mouse_sensitivity": return "%.1f" % (value*1000)
	if key=="volume": return "%d %%" % int(value*100)
	return "%d°" % int(value)

func _save_settings() -> void:
	if game.has_method("save_settings"): game.save_settings()

func _build_hud() -> void:
	hud=Control.new()
	_full(hud,root)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var ink:=HUDInk.new()
	ink.owner_ui=self
	_full(ink,hud)
	var top_left:=VBoxContainer.new()
	hud.add_child(top_left)
	top_left.position=Vector2(36,26)
	top_left.add_theme_constant_override("separation",6)
	status_label=_label(top_left,"PASSEURS / ATTAQUE",14,TEAL,MONO)
	objective_label=_label(top_left,"Atteignez une arche. Restez vivant.",17,INK)
	team_label=_label(top_left,"●  ●  ●",13,MUTED,MONO)
	var top_center:=VBoxContainer.new()
	hud.add_child(top_center)
	top_center.anchor_left=0.5
	top_center.anchor_right=0.5
	top_center.offset_left=-180
	top_center.offset_right=180
	top_center.offset_top=22
	clock_label=_label(top_center,"04:00",34,INK,MONO)
	clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	score_label=_label(top_center,"000   /   000",14,TEAL,MONO)
	score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var top_right:=VBoxContainer.new()
	hud.add_child(top_right)
	top_right.anchor_left=1
	top_right.anchor_right=1
	top_right.offset_left=-390
	top_right.offset_right=-36
	top_right.offset_top=30
	zone_label=_label(top_right,"SANCTUAIRE",14,MUTED,MONO)
	zone_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var map_hint:=_label(top_right,"TAB  CARTE     ALT  ORDRES",12,MUTED,MONO)
	map_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var health_panel:=PanelContainer.new()
	hud.add_child(health_panel)
	health_panel.anchor_top=1
	health_panel.anchor_bottom=1
	health_panel.offset_left=36
	health_panel.offset_right=280
	health_panel.offset_top=-125
	health_panel.offset_bottom=-35
	var health_column:=_box(_margin(health_panel,14),true,5)
	var hrow:=_box(health_column,false)
	health_label=_label(hrow,"100",32,INK,BOLD)
	_label(hrow,"INTÉGRITÉ",11,MUTED,MONO).size_flags_vertical=Control.SIZE_SHRINK_CENTER
	health_bar=ProgressBar.new()
	health_bar.show_percentage=false
	health_bar.custom_minimum_size=Vector2(210,4)
	health_column.add_child(health_bar)
	var ammo_panel:=PanelContainer.new()
	hud.add_child(ammo_panel)
	ammo_panel.anchor_left=1
	ammo_panel.anchor_right=1
	ammo_panel.anchor_top=1
	ammo_panel.anchor_bottom=1
	ammo_panel.offset_left=-290
	ammo_panel.offset_right=-36
	ammo_panel.offset_top=-136
	ammo_panel.offset_bottom=-35
	var ammo_column:=_box(_margin(ammo_panel,14),true,2)
	ammo_label=_label(ammo_column,"20 / 80",33,INK,MONO)
	reserve_label=_label(ammo_column,"FUSIL DE RÉSONANCE     R RECHARGE",10,MUTED,MONO)
	var bottom:=VBoxContainer.new()
	hud.add_child(bottom)
	bottom.anchor_left=0.5
	bottom.anchor_right=0.5
	bottom.anchor_top=1
	bottom.anchor_bottom=1
	bottom.offset_left=-360
	bottom.offset_right=360
	bottom.offset_top=-105
	bottom.offset_bottom=-25
	bottom.add_theme_constant_override("separation",8)
	ping_label=_label(bottom,"F  IMPULSION DISPONIBLE",14,TEAL,MONO)
	ping_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	gadget_label=_label(bottom,"G  ÉCHO ERRANT      T  ÉPINE D'ÉCOUTE",11,INK,MONO)
	gadget_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var move_hint:=_label(bottom,"MAJ SPRINT   ·   CTRL ACCROUPIR / GLISSER   ·   E INTERAGIR",10,MUTED,MONO)
	move_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var feed_box:=VBoxContainer.new()
	hud.add_child(feed_box)
	feed_box.position=Vector2(36,126)
	feed_box.custom_minimum_size.x=420
	feed_label=_label(feed_box,"",14,MUTED,FONT)
	feed_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feed_label.custom_minimum_size.x=420
	var interaction:=VBoxContainer.new()
	hud.add_child(interaction)
	interaction.anchor_left=0.5
	interaction.anchor_right=0.5
	interaction.anchor_top=0.69
	interaction.anchor_bottom=0.69
	interaction.offset_left=-240
	interaction.offset_right=240
	interaction.add_theme_constant_override("separation",10)
	interact_label=_label(interaction,"",15,INK,MONO)
	interact_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	extraction_bar=ProgressBar.new()
	extraction_bar.custom_minimum_size=Vector2(480,5)
	extraction_bar.show_percentage=false
	interaction.add_child(extraction_bar)
	extraction_bar.hide()
	tutorial_panel=PanelContainer.new()
	hud.add_child(tutorial_panel)
	tutorial_panel.anchor_left=1
	tutorial_panel.anchor_right=1
	tutorial_panel.offset_left=-425
	tutorial_panel.offset_right=-36
	tutorial_panel.offset_top=120
	var tutorial_box:=_box(_margin(tutorial_panel,18),true,8)
	tutorial_title=_label(tutorial_box,"",14,TEAL,MONO)
	tutorial_text=_paragraph(tutorial_box,"",16,INK)
	tutorial_text.custom_minimum_size.x=345
	_label(tutorial_box,"F8 · Étape suivante",11,MUTED,MONO)
	tutorial_panel.hide()

func _build_pause() -> void:
	pause_panel=Control.new()
	_full(pause_panel,root)
	var shade:=ColorRect.new()
	_full(shade,pause_panel)
	shade.color=Color(0.01,0.025,0.03,0.8)
	var center:=CenterContainer.new()
	_full(center,pause_panel)
	var card:=_panel(center)
	card.custom_minimum_size=Vector2(510,0)
	var column:=_box(_margin(card,36),true,12)
	_label(column,"TRANSMISSION SUSPENDUE",12,TEAL,MONO)
	_label(column,"Le Creux attend.",36,INK,BOLD)
	_spacer(column,18)
	_button(column,"REPRENDRE    →",func(): game.set_paused(false),true)
	_button(column,"RECOMMENCER LA PARTIE",func(): game.set_paused(false); _start(selected_options))
	_button(column,"RETOUR AU MENU",func(): game.set_paused(false); game.return_to_menu())
	_label(column,"ÉCHAP · Reprendre",12,MUTED,MONO)
	pause_panel.hide()

func _build_map() -> void:
	map_overlay=Control.new()
	_full(map_overlay,root)
	map_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade:=ColorRect.new()
	_full(shade,map_overlay)
	shade.color=Color(0.01,0.035,0.045,0.93)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var header:=VBoxContainer.new()
	map_overlay.add_child(header)
	header.position=Vector2(72,42)
	_label(header,"LA MÉMOIRE DU CREUX",12,TEAL,MONO)
	_label(header,"Carte tactique",30,INK,BOLD)
	map_canvas=TacticalMap.new()
	map_canvas.owner_ui=self
	map_overlay.add_child(map_canvas)
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.offset_top=100
	map_canvas.offset_bottom=-75
	var legend:=_label(map_overlay,"● Vous     ● Alliés     ○ Contacts estimés     ◉ Arches    /    Les contacts vieillissent ; les murs restent opaques.",14,MUTED,MONO)
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_left=72
	legend.offset_top=-48
	map_overlay.hide()

func _build_orders() -> void:
	order_panel=Control.new()
	_full(order_panel,root)
	var shade:=ColorRect.new()
	_full(shade,order_panel)
	shade.color=Color(0.02,0.04,0.05,0.75)
	var center:=CenterContainer.new()
	_full(center,order_panel)
	var card:=_panel(center)
	card.custom_minimum_size=Vector2(480,0)
	var column:=_box(_margin(card,28),true,8)
	_label(column,"FRÉQUENCE D'ÉQUIPE",12,TEAL,MONO)
	_label(column,"Donner un ordre",28,INK,BOLD)
	var orders: Array = [["1  SUIVEZ-MOI","follow"],["2  TENEZ LA POSITION","hold"],["3  COUVREZ-MOI","cover"],["4  AVANCEZ","advance"],["5  REPLIEZ-VOUS","retreat"],["6  PRÉPAREZ L'EXTRACTION","extract"]]
	for order in orders:
		var order_name: String=order[1]
		_button(column,str(order[0]),func(): _send_order(order_name))
	_label(column,"Relâchez ALT pour fermer",12,MUTED,MONO)
	order_panel.hide()

func _send_order(order: String) -> void:
	game.command_allies(order)
	order_panel.hide()
	if not paused: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if game==null or game.phase!="playing" or paused: return
	if event is InputEventKey and not event.echo:
		var key: InputEventKey=event
		if event.is_action("tactical_map"):
			is_map_open=key.pressed
			map_overlay.visible=key.pressed
			get_viewport().set_input_as_handled()
		elif event.is_action("orders"):
			order_panel.visible=key.pressed
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if key.pressed else Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif key.pressed and order_panel.visible:
			var orders: Array=["follow","hold","cover","advance","retreat","extract"]
			var index: int=int(key.physical_keycode)-KEY_1
			if index>=0 and index<orders.size():
				_send_order(orders[index])
				get_viewport().set_input_as_handled()
		elif key.pressed and key.physical_keycode==KEY_F8 and str(game.settings.get("mode",""))=="tutorial":
			tutorial_step=mini(tutorial_step+1,TUTORIAL.size()-1)
			tutorial_elapsed=0
			get_viewport().set_input_as_handled()

func show_menu() -> void:
	if root==null: return
	menu.show()
	hud.hide()
	pause_panel.hide()
	map_overlay.hide()
	order_panel.hide()
	if is_instance_valid(result_panel): result_panel.queue_free()
	paused=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_open_page("play")

func set_pause(value: bool) -> void:
	paused=value
	pause_panel.visible=value
	map_overlay.hide()
	order_panel.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func push_message(message: String) -> void:
	notifications.append({"text":message,"left":6.0})
	while notifications.size()>5: notifications.pop_front()

func show_hud() -> void:
	menu.hide()
	pause_panel.hide()
	map_overlay.hide()
	order_panel.hide()
	if is_instance_valid(result_panel): result_panel.hide()
	hud.show()
	paused=false
	if game.human!=null and tutorial_step==0: tutorial_start=game.human.global_position
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func flash_hit(_kill: bool=false) -> void:
	hit_left=0.22

func hit_feedback(_headshot: bool=false) -> void:
	flash_hit()

func damage_feedback(_damage: float) -> void:
	damage_left=0.6

func show_round_result(summary: Dictionary) -> void:
	_show_result(summary,false)

func show_final_result(summary: Dictionary) -> void:
	_show_result(summary,true)

func _show_result(summary: Dictionary,final: bool) -> void:
	hud.hide()
	pause_panel.hide()
	map_overlay.hide()
	order_panel.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(result_panel):
		root.remove_child(result_panel)
		result_panel.queue_free()
	result_panel=Control.new()
	_full(result_panel,root)
	var shade:=ColorRect.new()
	_full(shade,result_panel)
	shade.color=Color(0.01,0.035,0.045,0.92)
	var center:=CenterContainer.new()
	_full(center,result_panel)
	var card:=_panel(center)
	card.custom_minimum_size=Vector2(740,0)
	var column:=_box(_margin(card,42),true,14)
	_label(column,"INCURSION TERMINÉE" if final else "FIN DE MANCHE  /  %02d" % (int(summary.get("round",game.round_index+1))),12,TEAL,MONO)
	_label(column,str(summary.get("title","La Trame se souvient.")),38,INK,BOLD)
	_paragraph(column,str(summary.get("subtitle","Les points récompensent les extractions et les interceptions.")),18,MUTED)
	_spacer(column,6)
	var result_scores: Array=summary.get("scores",game.scores)
	var row:=_box(column,false,45)
	_label(row,"%03d" % int(result_scores[0]),64,TEAL,MONO)
	_label(row,"/",44,MUTED,MONO)
	_label(row,"%03d" % int(result_scores[1]),64,AMBER,MONO)
	_label(column,"VOTRE ÉQUIPE                                   ÉQUIPE ADVERSE",11,MUTED,MONO)
	_label(column,"%d EXTRACTION(S)    ·    %d PASSEUR(S) ARRÊTÉ(S)" % [int(summary.get("extracted",0)),int(summary.get("stopped",0))],15,INK,MONO)
	if game.human!=null:
		var stats: Dictionary=game.human.stats
		_label(column,"%d élimination(s)  ·  %d ping(s)  ·  %d gadget(s)" % [int(stats.get("kills",0)),int(stats.get("pings",0)),int(stats.get("gadgets",0))],16,MUTED)
	_spacer(column,14)
	if final:
		_button(column,"REJOUER    →",func(): _start(selected_options),true)
		_button(column,"CHANGER DE MODE",func(): game.return_to_menu())
	else:
		_button(column,"MANCHE SUIVANTE    →",func():
			result_panel.hide()
			hud.show()
			game.next_round()
		,true)
		_label(column,"Les rôles alternent ; le score reste acquis.",13,MUTED)
	_button(column,"RETOUR AU MENU",func(): game.return_to_menu())

func _process(delta: float) -> void:
	if game==null or root==null: return
	hit_left=maxf(0,hit_left-delta)
	damage_left=maxf(0,damage_left-delta)
	if game.phase=="playing" and not paused:
		if menu.visible: menu.hide(); hud.show()
		_update_hud(delta)
	last_phase=game.phase

func _update_hud(delta: float) -> void:
	var observer=game.get_observer()
	var seconds: int=maxi(0,int(ceil(game.time_left)))
	clock_label.text="%02d:%02d" % [seconds/60,seconds%60]
	clock_label.add_theme_color_override("font_color",AMBER if seconds<30 else INK)
	score_label.text="%03d   /   %03d     M%02d" % [int(game.scores[0]),int(game.scores[1]),game.round_index+1]
	for index in range(notifications.size()-1,-1,-1):
		notifications[index].left-=delta
		if float(notifications[index].left)<=0: notifications.remove_at(index)
	var lines:=PackedStringArray()
	for item in notifications: lines.append(str(item.text))
	feed_label.text="\n\n".join(lines)
	if observer==null:
		status_label.text="OBSERVATION / TRANSMISSION PERDUE"
		interact_label.text="Les bots poursuivent la manche."
		extraction_bar.hide()
		return
	var attack: bool=observer.team==game.attacker_team
	var own_human=game.human
	var spectating: bool=own_human==null or not own_human.alive or own_human.extracted
	status_label.text=("SPECTATEUR · " if spectating else "")+("PASSEURS / ATTAQUE" if attack else "VEILLEURS / DÉFENSE")
	status_label.add_theme_color_override("font_color",TEAL if attack else AMBER)
	objective_label.text="Atteignez une arche. Maintenez E pour sortir." if attack else "Interceptez les Passeurs. Protégez les arches."
	if game.level!=null: zone_label.text=game.level.get_zone(observer.global_position).to_upper()
	var allies:=PackedStringArray()
	for actor in game.actors:
		if not is_instance_valid(actor) or actor.team!=observer.team: continue
		var state: String="EXTRAIT" if actor.extracted else ("EN VIE" if actor.alive else "PERDU")
		allies.append(("VOUS" if actor.is_human else "ÉCHO %d" % actor.actor_id)+" · "+state)
	team_label.text="   /   ".join(allies)
	health_label.text="%03d" % maxi(0,int(observer.health))
	health_bar.value=observer.health
	ammo_label.text="%02d / %02d" % [maxi(0,int(observer.ammo)),maxi(0,int(observer.reserve))]
	reserve_label.text=("RECHARGE %.1fs" % observer.reload_left) if observer.reload_left>0 else ("FUSIL DE RÉSONANCE" if observer.weapon_index==0 else "PISTOLET D'ÉCHO")+"   R RECHARGE"
	ping_label.text="F  IMPULSION DISPONIBLE" if observer.ping_cooldown<=0 else "F  RECHARGE DE L'IMPULSION   %.1fs" % observer.ping_cooldown
	ping_label.add_theme_color_override("font_color",TEAL if observer.ping_cooldown<=0 else MUTED)
	var gadgets_text:=PackedStringArray()
	for index in range(mini(2,observer.gadget_loadout.size())):
		var type: String=str(observer.gadget_loadout[index])
		var used: bool=index<observer.gadget_used.size() and bool(observer.gadget_used[index])
		var name_text: String=str(GADGETS.get(type,[type,""])[0])
		gadgets_text.append(("G" if index==0 else "T")+"  "+name_text+(" [UTILISÉ]" if used else ""))
	gadget_label.text="    /    ".join(gadgets_text)
	interact_label.text=""
	extraction_bar.hide()
	if attack and observer.alive and not observer.extracted:
		for exit_data in game.active_exits():
			var distance: float=observer.global_position.distance_to(exit_data.position)
			if distance<float(exit_data.radius)+0.8:
				interact_label.text="MAINTENIR E  /  "+str(exit_data.name).to_upper()
				if observer.extraction_progress>0:
					extraction_bar.show()
					extraction_bar.max_value=1.0
					extraction_bar.value=observer.extraction_progress
					interact_label.text="EXTRACTION EN COURS  /  %.1fs" % maxf(0,float(exit_data.duration)*(1.0-observer.extraction_progress))
				break
	if game.extraction_alerts.size()>0 and not attack:
		interact_label.text="ALERTE EXTRACTION   /   "+" · ".join(PackedStringArray(game.extraction_alerts.keys()))
	if game.preparation_left > 0.0:
		interact_label.text="HARMONISATION  /  %ds AVANT LA MANCHE" % int(ceil(game.preparation_left))
		objective_label.text="Repérez les sorties sur la carte. Préparez votre itinéraire."
	if spectating:
		interact_label.text="OBSERVATION D'UN ALLIÉ  /  ESPACE POUR CHANGER"
	if str(game.settings.get("mode",""))=="tutorial" and not spectating:
		tutorial_panel.show()
		_update_tutorial(delta,observer)
	else:
		tutorial_panel.hide()

func _update_tutorial(delta: float,observer) -> void:
	tutorial_elapsed+=delta
	var ready:=false
	match tutorial_step:
		0:
			if observer.global_position.distance_to(tutorial_start)>4: tutorial_flags.moved=true
			if Input.is_action_pressed("sprint"): tutorial_flags.sprint=true
			if Input.is_action_pressed("jump"): tutorial_flags.jump=true
			if Input.is_action_pressed("crouch"): tutorial_flags.crouch=true
			if observer.stance=="slide": tutorial_flags.slide=true
			ready=tutorial_flags.size()>=5
		1: ready=game.acoustics.contacts_for(observer).size()>0 and tutorial_elapsed>=7.3
		2:
			for record in game.acoustics.contacts_for(observer):
				if float(record.get("confidence",0))>0.35: ready=true
		3:
			if not tutorial_flags.has("ping_baseline"): tutorial_flags.ping_baseline=int(observer.stats.get("pings",0))
			ready=int(observer.stats.get("pings",0))>int(tutorial_flags.ping_baseline)
		4:
			if not tutorial_flags.has("shot_baseline"): tutorial_flags.shot_baseline=int(observer.stats.get("shots",0))
			if observer.reload_left>0: tutorial_flags.reloaded=true
			ready=int(observer.stats.get("shots",0))>int(tutorial_flags.shot_baseline) and bool(tutorial_flags.get("reloaded",false))
		5:
			if observer.gadget_used.size()>0 and bool(observer.gadget_used[0]):
				if not tutorial_flags.has("used_at"): tutorial_flags.used_at=tutorial_elapsed
				ready=tutorial_elapsed-float(tutorial_flags.used_at)>2.0
		6:
			var used: bool=observer.gadget_used.size()>1 and bool(observer.gadget_used[1])
			if used:
				for event in game.acoustics.event_log:
					if str(event.get("category",""))=="trap": ready=true
		7: ready=observer.extraction_progress>0
	if ready and tutorial_step<TUTORIAL.size()-1:
		tutorial_step+=1
		tutorial_elapsed=0
		tutorial_flags.clear()
	game.tutorial_step=tutorial_step
	tutorial_title.text=str(TUTORIAL[tutorial_step][0])
	tutorial_text.text=str(TUTORIAL[tutorial_step][1])

func _binding_row(title: String,action: String) -> void:
	var row:=_box(content,false,16)
	_label(row,title,15,MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var button:=_button(row,_binding_name(action),func(): pass)
	button.custom_minimum_size=Vector2(180,38)
	button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(func():
		if is_instance_valid(binding_button): binding_button.text=_binding_name(binding_action)
		binding_action=action
		binding_button=button
		button.text="PRESSEZ UNE TOUCHE…"
	)

func _binding_name(action: String) -> String:
	var events: Array[InputEvent]=InputMap.action_get_events(action)
	if events.is_empty(): return "—"
	var event: InputEvent=events[0]
	if event is InputEventKey:
		var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		return OS.get_keycode_string(code)
	return event.as_text().replace("Mouse Button ","Souris ")

func _input(event: InputEvent) -> void:
	if binding_action.is_empty() or not menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode!=KEY_ESCAPE:
			var code: int=int(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
			var conflict: String=_binding_conflict(code,binding_action)
			if not conflict.is_empty():
				if is_instance_valid(binding_button):
					binding_button.text="TOUCHE DÉJÀ UTILISÉE"
					binding_button.tooltip_text="Conflit avec "+conflict+". Choisissez une autre touche ; Échap annule."
				get_viewport().set_input_as_handled()
				return
			var bindings: Dictionary=game.settings.get("key_bindings",{})
			bindings[binding_action]=code
			game.settings.key_bindings=bindings
			_save_settings()
		if is_instance_valid(binding_button): binding_button.text=_binding_name(binding_action)
		binding_action=""
		get_viewport().set_input_as_handled()

func _binding_conflict(code: int,action: String) -> String:
	for other in ["move_forward","move_back","move_left","move_right","sprint","crouch","jump","fire","aim","reload","ping","gadget_primary","gadget_secondary","interact","tactical_map","orders","weapon_1","weapon_2","pause"]:
		if other==action or not InputMap.has_action(other): continue
		for event in InputMap.action_get_events(other):
			if event is InputEventKey:
				var existing: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
				if existing==code: return other
	return ""
