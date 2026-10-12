class_name PlayingCard
extends Button
## Reusable touch target. All movement happens inside Visual, preserving hand layout.

signal card_selected(card_index: int)
signal card_inspected(card_index: int)

@export_group("Interaction")
@export_range(0.25, 1.0, 0.05) var inspect_hold_duration: float = 0.45
@export_range(4.0, 40.0, 1.0) var hold_drag_tolerance: float = 16.0
@export_group("Motion")
@export_range(0.05, 0.5, 0.01) var hover_duration: float = 0.18
@export_range(0.0, 40.0, 1.0) var selection_lift: float = 22.0
@export_range(0.0, 20.0, 1.0) var hover_lift: float = 8.0
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			_move_visual(false)

const PAPER := Color("f3ead5")
const GOLD := Color("e2b96b")
const SUIT_COLORS := {"S": Color("233e45"), "C": Color("285449"), "H": Color("bf5748"), "D": Color("bd6740")}
const SUIT_NAMES := {"S": "Spades", "H": "Hearts", "D": "Diamonds", "C": "Clubs"}

var card: Dictionary = {}
var card_index: int = -1
var is_selected: bool = false
var _face_down: bool = false
var _hovered: bool = false
var _motion: Tween
var _paper_style: StyleBoxFlat
var _holding: bool = false
var _suppress_release: bool = false
var _press_position: Vector2

@onready var visual: Control = $Visual
@onready var paper: Panel = $Visual/Paper
@onready var pip_canvas: Control = $Visual/Pips
@onready var top_rank: Label = $Visual/TopRank
@onready var bottom_rank: Label = $Visual/BottomRank
@onready var court_art: TextureRect = $Visual/CourtArt
@onready var back_art: TextureRect = $Visual/BackArt
@onready var enhancement_label: Label = $Visual/Enhancement
@onready var selected_mark: Label = $Visual/SelectedMark
@onready var hold_timer: Timer = $HoldTimer

func _ready() -> void:
	pressed.connect(_on_pressed)
	button_down.connect(_on_pointer_down)
	button_up.connect(_on_pointer_up)
	hold_timer.timeout.connect(_on_inspect_timeout)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	resized.connect(_layout_visual)
	pip_canvas.draw.connect(_draw_pips)
	_paper_style = paper.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	paper.add_theme_stylebox_override("panel", _paper_style)
	var font_path := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
	if ResourceLoader.exists(font_path):
		var rank_font := load(font_path) as Font
		top_rank.add_theme_font_override("font", rank_font)
		bottom_rank.add_theme_font_override("font", rank_font)
	_layout_visual()
	_refresh()

func setup(data: Dictionary, index: int = -1) -> void:
	card = data.duplicate(true)
	card_index = index
	if is_node_ready():
		_refresh()

func set_selected(value: bool, animate: bool = true) -> void:
	is_selected = value
	if not is_node_ready():
		return
	selected_mark.visible = value and not _face_down
	_paper_style.border_color = GOLD if value else Color("c9c2ae")
	_paper_style.set_border_width_all(3 if value else 1)
	z_index = 5 if value else 0
	_move_visual(animate)

func set_face_down(value: bool) -> void:
	_face_down = value
	if is_node_ready():
		_refresh()

func pulse() -> void:
	if not is_node_ready() or reduced_motion:
		return
	var glow := create_tween()
	glow.tween_property(visual, "modulate", Color(1.35, 1.25, 0.9), 0.08)
	glow.tween_property(visual, "modulate", Color.WHITE, 0.25)

func _on_hover(value: bool) -> void:
	_hovered = value
	if not value and _holding:
		hold_timer.stop()
	if not disabled:
		_move_visual()

func _on_pointer_down() -> void:
	_holding = true
	_suppress_release = false
	_press_position = get_local_mouse_position()
	hold_timer.start(inspect_hold_duration)

func _on_pointer_up() -> void:
	_holding = false
	hold_timer.stop()

func _on_pressed() -> void:
	# BaseButton emits pressed on release. A completed hold is inspection only.
	if _suppress_release:
		_suppress_release = false
		return
	card_selected.emit(card_index)

func _on_inspect_timeout() -> void:
	if not _holding or disabled:
		return
	_suppress_release = true
	card_inspected.emit(card_index)

func _gui_input(event: InputEvent) -> void:
	if not _holding:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if event.position.distance_to(_press_position) > hold_drag_tolerance:
			hold_timer.stop()

func _move_visual(animate: bool = true) -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	var lift := -selection_lift if is_selected else (-hover_lift if _hovered and not reduced_motion else 0.0)
	var tilt := (-0.017 if card_index % 2 == 0 else 0.017) if _hovered and not reduced_motion else 0.0
	if not animate or reduced_motion:
		visual.position = Vector2(0, lift)
		visual.rotation = tilt
		return
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(visual, "position", Vector2(0, lift), hover_duration)
	_motion.tween_property(visual, "rotation", tilt, hover_duration)

func _layout_visual() -> void:
	if not is_node_ready():
		return
	visual.size = size
	visual.pivot_offset = size * 0.5
	var rank_size := int(clampf(size.x * 0.23, 19.0, 32.0))
	top_rank.add_theme_font_size_override("font_size", rank_size)
	bottom_rank.add_theme_font_size_override("font_size", rank_size)
	top_rank.position = Vector2(size.x * 0.09, size.y * 0.035)
	top_rank.size = Vector2(size.x * 0.35, rank_size * 1.2)
	bottom_rank.size = top_rank.size
	bottom_rank.position = size - top_rank.position
	bottom_rank.rotation = PI
	pip_canvas.queue_redraw()

func _refresh() -> void:
	var rank := int(card.get("rank", 14))
	var suit := str(card.get("suit", "S"))
	var rank_text := str(rank)
	if rank == 11: rank_text = "J"
	elif rank == 12: rank_text = "Q"
	elif rank == 13: rank_text = "K"
	elif rank == 14: rank_text = "A"
	top_rank.text = rank_text
	bottom_rank.text = rank_text
	var color: Color = SUIT_COLORS.get(suit, SUIT_COLORS["S"])
	top_rank.add_theme_color_override("font_color", color)
	bottom_rank.add_theme_color_override("font_color", color)
	var enhancement := str(card.get("enhancement", ""))
	enhancement_label.text = "" if enhancement in ["", "none", "base"] else enhancement.to_upper()
	enhancement_label.visible = not _face_down
	var paper_color := PAPER
	if enhancement == "steel": paper_color = Color("d9e1df")
	elif enhancement == "glass": paper_color = Color("dceae5")
	elif enhancement == "bonus": paper_color = Color("dce8e9")
	elif enhancement == "mult": paper_color = Color("f1dbcc")
	elif enhancement == "lucky": paper_color = Color("e5ebd6")
	_paper_style.bg_color = paper_color
	var edition := str(card.get("edition", ""))
	if edition == "foil": _paper_style.border_color = Color("9ac9d3")
	elif edition == "holographic": _paper_style.border_color = Color("d8a6d3")
	elif edition == "polychrome": _paper_style.border_color = Color("c4bb8b")
	back_art.visible = _face_down
	top_rank.visible = not _face_down
	bottom_rank.visible = not _face_down
	pip_canvas.visible = not _face_down
	court_art.visible = rank in [11, 12, 13] and not _face_down
	if court_art.visible:
		var illustration: String = {11: "jack", 12: "queen", 13: "king"}[rank]
		court_art.texture = load("res://assets/art/%s.svg" % illustration)
	selected_mark.visible = is_selected and not _face_down
	tooltip_text = "Face-down card" if _face_down else "%s of %s%s" % [rank_text, SUIT_NAMES.get(suit, suit), " · " + enhancement.capitalize() if enhancement_label.text != "" else ""]
	pip_canvas.queue_redraw()

func _draw_pips() -> void:
	var suit := str(card.get("suit", "S"))
	var rank := int(card.get("rank", 14))
	var ink: Color = SUIT_COLORS.get(suit, SUIT_COLORS["S"])
	_draw_suit(Vector2(size.x * 0.165, size.y * 0.28), size.x * 0.065, suit, ink)
	_draw_suit(Vector2(size.x * 0.835, size.y * 0.72), size.x * 0.065, suit, ink, true)
	if rank == 14:
		_draw_suit(size * Vector2(0.50, 0.5), size.x * 0.23, suit, ink)
	elif rank <= 10:
		var pips: Array[Vector2] = []
		match rank:
			2: pips = [Vector2(.5,.31), Vector2(.5,.69)]
			3: pips = [Vector2(.5,.28), Vector2(.5,.5), Vector2(.5,.72)]
			4: pips = [Vector2(.36,.31), Vector2(.64,.31), Vector2(.36,.69), Vector2(.64,.69)]
			5: pips = [Vector2(.36,.28), Vector2(.64,.28), Vector2(.5,.5), Vector2(.36,.72), Vector2(.64,.72)]
			6: pips = [Vector2(.36,.28), Vector2(.64,.28), Vector2(.36,.5), Vector2(.64,.5), Vector2(.36,.72), Vector2(.64,.72)]
			7: pips = [Vector2(.36,.28), Vector2(.64,.28), Vector2(.5,.39), Vector2(.36,.5), Vector2(.64,.5), Vector2(.36,.72), Vector2(.64,.72)]
			8: pips = [Vector2(.36,.26), Vector2(.64,.26), Vector2(.5,.38), Vector2(.36,.5), Vector2(.64,.5), Vector2(.5,.62), Vector2(.36,.74), Vector2(.64,.74)]
			9: pips = [Vector2(.36,.25), Vector2(.64,.25), Vector2(.36,.41), Vector2(.64,.41), Vector2(.5,.5), Vector2(.36,.59), Vector2(.64,.59), Vector2(.36,.75), Vector2(.64,.75)]
			10: pips = [Vector2(.36,.25), Vector2(.64,.25), Vector2(.5,.33), Vector2(.36,.41), Vector2(.64,.41), Vector2(.36,.59), Vector2(.64,.59), Vector2(.5,.67), Vector2(.36,.75), Vector2(.64,.75)]
		for point in pips:
			_draw_suit(point * size, size.x * (0.086 if rank > 7 else 0.098), suit, ink, point.y > .5)
	var seal := str(card.get("seal", ""))
	if seal not in ["", "none"]:
		var seal_color: Color = {"red": Color("bc554d"), "blue": Color("539bc5"), "gold": GOLD, "purple": Color("9d7daf")}.get(seal, GOLD)
		pip_canvas.draw_circle(size * Vector2(.76,.20), size.x * .09, seal_color)
		pip_canvas.draw_arc(size * Vector2(.76,.20), size.x * .064, 0, TAU, 24, Color(1,1,1,.65), 1.0, true)

func _draw_suit(center: Vector2, radius: float, suit: String, ink: Color, flip: bool = false) -> void:
	pip_canvas.draw_set_transform(center, PI if flip else 0.0, Vector2.ONE * radius)
	match suit:
		"D":
			pip_canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-1.25), Vector2(.8,0), Vector2(0,1.25), Vector2(-.8,0)]), ink)
		"H":
			pip_canvas.draw_circle(Vector2(-.45,-.3), .58, ink)
			pip_canvas.draw_circle(Vector2(.45,-.3), .58, ink)
			pip_canvas.draw_colored_polygon(PackedVector2Array([Vector2(-.94,-.02), Vector2(.94,-.02), Vector2(0,1.13)]), ink)
		"C":
			pip_canvas.draw_circle(Vector2(0,-.53), .56, ink)
			pip_canvas.draw_circle(Vector2(-.52,.21), .56, ink)
			pip_canvas.draw_circle(Vector2(.52,.21), .56, ink)
			pip_canvas.draw_colored_polygon(PackedVector2Array([Vector2(-.38,1.12), Vector2(.38,1.12), Vector2(.08,.0), Vector2(-.08,.0)]), ink)
		_:
			pip_canvas.draw_circle(Vector2(-.43,.21), .54, ink)
			pip_canvas.draw_circle(Vector2(.43,.21), .54, ink)
			pip_canvas.draw_colored_polygon(PackedVector2Array([Vector2(-.93,.02), Vector2(.93,.02), Vector2(0,-1.19)]), ink)
			pip_canvas.draw_colored_polygon(PackedVector2Array([Vector2(-.35,1.12), Vector2(.35,1.12), Vector2(.06,.25), Vector2(-.06,.25)]), ink)
	pip_canvas.draw_set_transform(Vector2.ZERO)
