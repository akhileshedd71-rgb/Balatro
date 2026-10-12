extends SceneTree
## Dispatch real viewport pointer input so BaseButton ordering and hold timers are
## exercised together. Touch uses these same events via emulate_mouse_from_touch.

var checks: int = 0
var failures: int = 0
var selected_indices: Array[int] = []
var inspected_indices: Array[int] = []
var card: PlayingCard

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _pointer_move(position: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	root.push_input(event, true)

func _pointer_button(down: bool, position: Vector2 = Vector2(130, 130)) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)

func _short_tap() -> void:
	_pointer_move(Vector2(130, 130))
	_pointer_button(true)
	await create_timer(0.04).timeout
	_pointer_button(false)
	await process_frame

func _run() -> void:
	# A signal or coroutine failure must fail CI instead of leaving its tree alive.
	create_timer(12.0).timeout.connect(func() -> void:
		push_error("Card input test timed out")
		quit(1))
	card = load("res://scenes/ui/playing_card.tscn").instantiate() as PlayingCard
	# The UI can configure preferences before adding a scene to the tree.
	card.reduced_motion = true
	card.setup({"id": 7, "rank": 14, "suit": "S", "enhancement": ""}, 3)
	root.add_child(card)
	card.position = Vector2(100, 100)
	card.card_selected.connect(func(index: int) -> void: selected_indices.append(index))
	card.card_inspected.connect(func(index: int) -> void: inspected_indices.append(index))
	await process_frame

	_pointer_move(Vector2(130, 130))
	await create_timer(card.hover_duration + 0.1).timeout
	_check(card.visual.position == Vector2.ZERO and is_zero_approx(card.visual.rotation),
		"Reduced motion configured before ready prevents hover movement")
	card.pulse()
	await create_timer(0.1).timeout
	_check(card.visual.modulate == Color.WHITE, "Reduced motion suppresses scoring flashes")
	card.reduced_motion = false

	await _short_tap()
	_check(selected_indices == [3] and inspected_indices.is_empty(),
		"Short pointer tap selects the correct hand index without inspection")
	_pointer_move(Vector2(130, 130))
	_pointer_button(true)
	await create_timer(card.inspect_hold_duration + 0.12).timeout
	_check(inspected_indices == [3], "Holding a card inspects the correct hand index")
	_check(selected_indices == [3], "Inspection does not select while the pointer remains down")
	_pointer_button(false)
	await process_frame
	_check(selected_indices == [3], "Release after a completed hold does not also select")
	await _short_tap()
	_check(selected_indices == [3, 3], "A later short tap is not swallowed by the previous hold")

	_pointer_move(Vector2(130, 130))
	_pointer_button(true)
	_pointer_move(Vector2(170, 130), Vector2(40, 0))
	await create_timer(card.inspect_hold_duration + 0.12).timeout
	_check(inspected_indices == [3], "Dragging within a card cancels its pending inspection")
	_pointer_button(false, Vector2(170, 130))
	await process_frame

	var selections_before_disable := selected_indices.size()
	card.disabled = true
	_pointer_move(Vector2(130, 130))
	_pointer_button(true)
	await create_timer(card.inspect_hold_duration + 0.12).timeout
	_pointer_button(false)
	await process_frame
	_check(selected_indices.size() == selections_before_disable and inspected_indices == [3],
		"Disabled cards cannot select or inspect through pointer input")
	card.disabled = false

	card.reduced_motion = true
	card.set_selected(true)
	_check(card.visual.position == Vector2(0, -card.selection_lift) and is_zero_approx(card.visual.rotation),
		"Reduced motion applies the selection affordance immediately without wobble")
	_check(card.selected_mark.visible, "Selected cards have a visible mark independent of border color")
	card.set_selected(false)
	_check(card.visual.position == Vector2.ZERO, "Reduced motion returns deselected cards to their layout position")

	# Enhanced cards must communicate their identity in words, including after reuse.
	card.setup({"id": 8, "rank": 9, "suit": "H", "enhancement": "steel", "edition": "foil", "seal": "red"}, 5)
	_check(card.tooltip_text.contains("9 of Hearts") and card.tooltip_text.contains("Steel"),
		"Enhanced card inspection text includes rank, suit, and enhancement")
	_check(card.enhancement_label.visible and card.enhancement_label.text == "STEEL",
		"Enhancement has a semantic label rather than relying only on color")
	card.set_face_down(true)
	_check(card.tooltip_text == "Face-down card" and card.back_art.visible,
		"Face-down cards expose only the hidden-card description")
	_check(not card.top_rank.visible and not card.bottom_rank.visible and not card.pip_canvas.visible and not card.enhancement_label.visible,
		"Face-down cards hide rank, suit, and enhancement labels")
	card.set_face_down(false)
	_check(card.enhancement_label.visible and card.tooltip_text.contains("Steel"),
		"Turning a card face-up restores its enhancement identity")
	card.setup({"id": 9, "rank": 2, "suit": "D", "enhancement": ""}, 6)
	_check(card.enhancement_label.text.is_empty() and not card.tooltip_text.contains("Steel"),
		"Reusing a card scene does not retain stale enhancement text")

	card.queue_free()
	await process_frame
	print("Card input: %d checks, %d failures." % [checks, failures])
	quit(1 if failures > 0 else 0)
