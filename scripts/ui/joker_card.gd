class_name JokerCard
extends Button
## Original illustrated modifier card. Touch selects it for the shared inspector.

signal joker_selected(joker_index: int)

var joker_id: String = ""
var joker_index: int = -1
var owned: Dictionary = {}
var _selected: bool = false
var _hovered: bool = false
var _motion: Tween
var _frame_style: StyleBoxFlat

@onready var visual: Control = $Visual
@onready var frame: Panel = $Visual/Frame
@onready var art: TextureRect = $Visual/Art
@onready var title: Label = $Visual/Title
@onready var number_label: Label = $Visual/Number
@onready var edition_label: Label = $Visual/Edition

func _ready() -> void:
	pressed.connect(func() -> void: joker_selected.emit(joker_index))
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	resized.connect(_layout)
	_frame_style = frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	frame.add_theme_stylebox_override("panel", _frame_style)
	var font_path := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
	if ResourceLoader.exists(font_path):
		title.add_theme_font_override("font", load(font_path) as Font)
	_layout()
	_refresh()

func setup(data: Dictionary, index: int = -1) -> void:
	owned = data.duplicate(true)
	joker_id = str(data.get("id", "jester"))
	joker_index = index
	if is_node_ready():
		_refresh()

func set_selected(value: bool) -> void:
	_selected = value
	if not is_node_ready(): return
	_frame_style.border_color = Color("e2b96b") if value else Color("b9b39f")
	_frame_style.set_border_width_all(3 if value else 1)
	_move()

func pulse() -> void:
	var effect := create_tween()
	effect.tween_property(visual, "modulate", Color(1.4, 1.25, 0.9), .1)
	effect.tween_property(visual, "modulate", Color.WHITE, .25)

func _refresh() -> void:
	var data: JokerData = GameCatalog.joker(joker_id)
	if data == null:
		title.text = "JOKER"
		art.texture = load("res://assets/art/joker.svg")
		return
	title.text = data.title.to_upper()
	art.texture = load("res://assets/art/%s.svg" % data.art)
	number_label.text = "NO. %02d" % (joker_index + 1) if joker_index >= 0 else data.rarity.to_upper()
	var edition := str(owned.get("edition", ""))
	edition_label.text = edition.to_upper() if edition not in ["", "none"] else ""
	title.add_theme_color_override("font_color", Color("293e3c"))
	tooltip_text = "%s\n%s\n%s · $%d" % [data.title, data.description, data.rarity, data.price]
	if edition == "foil": _frame_style.border_color = Color("9ac9d3")
	elif edition == "holographic": _frame_style.border_color = Color("d8a6d3")
	elif edition == "polychrome": _frame_style.border_color = Color("b4d1aa")

func _layout() -> void:
	if not is_node_ready(): return
	visual.size = size
	visual.pivot_offset = size * .5
	title.add_theme_font_size_override("font_size", int(clampf(size.x * .11, 10.0, 16.0)))
	number_label.add_theme_font_size_override("font_size", int(clampf(size.x * .067, 8.0, 11.0)))

func _on_hover(value: bool) -> void:
	_hovered = value
	if not disabled: _move()

func _move() -> void:
	if _motion and _motion.is_valid(): _motion.kill()
	var lift := -8.0 if _selected else (-5.0 if _hovered else 0.0)
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(visual, "position:y", lift, .2)
	_motion.tween_property(visual, "rotation", -.025 if _hovered else 0.0, .2)
