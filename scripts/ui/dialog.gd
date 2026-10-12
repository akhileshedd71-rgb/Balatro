extends Control
signal action_requested(action: String)
signal settings_changed(key: String, value: bool)
signal closed
var mobile := false

func _ready() -> void:
	%Close.pressed.connect(close)
	resized.connect(_fit_scroll)
	for title in ["Red deck · +1 discard", "Blue deck · +1 hand", "Gold deck · +$6"]:
		%DeckChoice.add_item(title)
	for title in ["White stake · Standard", "Red stake · 1.25× targets", "Green stake · 1.6× targets"]:
		%StakeChoice.add_item(title)
	for title in ["Campaign · Eight antes", "Challenge · Pairs only", "Challenge · No discards", "Challenge · Short stack"]:
		%ChallengeChoice.add_item(title)
	for key in ["Music", "Effects", "Motion", "CRT"]:
		get_node("%" + key + "Toggle").toggled.connect(func(value: bool): settings_changed.emit(key.to_lower(), value))

func open(title: String, body: String, choices: Array = [], mode: String = "info") -> void:
	%Title.text = title
	%Body.text = body
	%Body.fit_content = false
	%Body.custom_minimum_size.y = 350 if mode == "collection" else (78 if mode == "new" else 100)
	%Body.add_theme_font_size_override("normal_font_size", 26 if mobile else 19)
	%Body.scroll_to_line(0)
	%NewRunFields.visible = mode == "new"
	%Settings.visible = mode == "settings"
	for child in %Choices.get_children():
		%Choices.remove_child(child)
		child.queue_free()
	for choice: Dictionary in choices:
		var button := Button.new()
		button.text = choice.text
		button.custom_minimum_size = Vector2(0, 64 if mobile else 52)
		button.add_theme_font_size_override("font_size", 25 if mobile else 20)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = choice.get("disabled", false)
		if choice.get("primary", false):
			button.add_theme_stylebox_override("normal", preload("res://resources/gold.tres"))
			button.add_theme_color_override("font_color", Color("18392e"))
		button.pressed.connect(func(): action_requested.emit(str(choice.action)))
		%Choices.add_child(button)
	visible = true
	%Close.grab_focus()
	_fit_scroll.call_deferred()

func _fit_scroll() -> void:
	if not is_node_ready():
		return
	%Scroll.custom_minimum_size.x = minf(620, get_viewport_rect().size.x - 80)
	%Scroll.custom_minimum_size.y = minf(%Panel.get_combined_minimum_size().y, get_viewport_rect().size.y - 60)

func close() -> void:
	visible = false
	closed.emit()

func new_run_options() -> Dictionary:
	return {"seed": %SeedInput.text, "deck": ["red", "blue", "gold"][%DeckChoice.selected], "stake": %StakeChoice.selected,
		"challenge": ["", "pair_only", "no_discards", "short_stack"][%ChallengeChoice.selected]}

func set_settings(settings: Dictionary) -> void:
	for key in ["Music", "Effects", "Motion", "CRT"]:
		get_node("%" + key + "Toggle").set_pressed_no_signal(settings.get(key.to_lower(), true))
