extends VBoxContainer
signal selection_changed(indices: Array)
signal play_requested(indices: Array)
signal discard_requested(indices: Array)
signal joker_inspected(index: int)
signal consumable_inspected(index: int)
signal deck_requested
signal advance_requested
signal score_tick(index: int)
signal score_progress(event: Dictionary)
signal card_inspected(index: int)

const CARD_SCENE = preload("res://scenes/ui/playing_card.tscn")
const JOKER_SCENE = preload("res://scenes/ui/joker_card.tscn")
var run: RunController
var selected: Array = []
var busy := false
var reduced_motion := false
var card_nodes: Array = []
var compact := false

func set_compact(value: bool, portrait: bool) -> void:
	compact = value
	%ShopView.compact = compact
	%ShopView.mobile = compact or portrait
	add_theme_constant_override("separation", 8 if compact else 14)
	%JokerRow.custom_minimum_size.y = 98 if compact else 142
	%Stage.custom_minimum_size.y = 65 if compact else 195
	%StageTitle.add_theme_font_size_override("font_size", 30 if compact else 38)
	%HandArea.custom_minimum_size.y = 153 if compact else 193
	%PlayButton.custom_minimum_size.y = 80 if compact or portrait else 62
	%DiscardButton.custom_minimum_size.y = 80 if compact or portrait else 62
	%Pocket0.custom_minimum_size.y = 90 if compact else 110
	%Pocket1.custom_minimum_size.y = 90 if compact else 110
	for control in [%SortRank, %SortSuit, %DeckButton]:
		control.custom_minimum_size.y = 80 if compact or portrait else 55
	_position_cards.call_deferred()
	_position_jokers.call_deferred()

func bind(controller: RunController) -> void:
	run = controller
	%ShopView.bind(run)
	%PlayButton.pressed.connect(func(): play_requested.emit(selected.duplicate()))
	%DiscardButton.pressed.connect(func(): discard_requested.emit(selected.duplicate()))
	%SortRank.pressed.connect(func(): selected.clear(); run.sort_hand(false))
	%SortSuit.pressed.connect(func(): selected.clear(); run.sort_hand(true))
	%DeckButton.pressed.connect(func(): deck_requested.emit())
	%AdvanceButton.pressed.connect(func(): advance_requested.emit())
	%Pocket0.pressed.connect(func(): consumable_inspected.emit(0))
	%Pocket1.pressed.connect(func(): consumable_inspected.emit(1))
	%Pocket2.pressed.connect(func(): consumable_inspected.emit(2))
	%HandArea.resized.connect(_position_cards)
	%JokerRow.resized.connect(_position_jokers)

func refresh() -> void:
	if busy:
		return
	selected.clear()
	_render_jokers()
	_render_hand()
	_render_pockets()
	var playing := run.phase == "playing"
	var shop := run.phase == "shop"
	%HandSection.visible = playing
	%Actions.visible = playing
	%Stage.visible = not shop
	%ShopView.visible = shop
	%ScoredCards.visible = false
	%StageCenter.visible = true
	%AdvanceButton.visible = not playing and not shop
	%StageEyebrow.text = "MAKE YOUR NEXT MOVE"
	%StageTitle.text = "The table is yours."
	%StageDescription.text = "Select up to %d cards to make a poker hand." % run.max_played_cards()
	if run.blind_index == 2:
		%StageEyebrow.text = "BOSS BLIND · " + run.blind_name().to_upper()
		%StageDescription.text = run.boss_description()
	if shop:
		%ShopView.refresh()
	elif run.phase == "blind":
		%StageEyebrow.text = "ANTE %d · ROUND %d" % [run.ante, run.round_number]
		%StageTitle.text = run.blind_name()
		%StageDescription.text = "Score %s chips. Reward $%d." % [_number(run.target_score), 3 + run.blind_index]
		%AdvanceButton.text = "Play blind  →"
	elif run.phase == "won":
		%StageEyebrow.text = "ALL EIGHT ANTES COMPLETE"
		%StageTitle.text = "You beat the table."
		%StageDescription.text = "A beautiful run. The next stake is waiting."
		%AdvanceButton.text = "Start a new run  →"
	elif run.phase == "lost":
		%StageEyebrow.text = "EVERY RUN TELLS A STORY"
		%StageTitle.text = "One more hand?"
		%StageDescription.text = "%s / %s chips. Try a new seed or build." % [_number(run.round_score), _number(run.target_score)]
		%AdvanceButton.text = "Try again  →"
	_update_selection()

func _render_hand() -> void:
	for child in %HandArea.get_children():
		%HandArea.remove_child(child)
		child.queue_free()
	card_nodes.clear()
	for i in run.hand.size():
		var card = CARD_SCENE.instantiate()
		%HandArea.add_child(card)
		card.setup(run.hand[i], i)
		card.reduced_motion = reduced_motion
		card.card_selected.connect(_select_card)
		card.card_inspected.connect(func(index: int): card_inspected.emit(index))
		card_nodes.append(card)
	%DeckButton.text = "▤  %d / %d" % [run.draw_pile.size(), run.deck.size()]
	_position_cards.call_deferred()

func _position_cards() -> void:
	var count := card_nodes.size()
	if count == 0:
		return
	var card_width := clampf(%HandArea.size.x / 8.3, 79, 94 if compact else 118)
	var card_height := card_width * 1.42
	var step := minf(card_width + 11, (%HandArea.size.x - card_width - 8) / maxf(count - 1, 1))
	var start: float = (%HandArea.size.x - (step * (count - 1) + card_width)) / 2
	for i in count:
		var card = card_nodes[i]
		card.custom_minimum_size = Vector2.ZERO
		card.size = Vector2(card_width, card_height)
		card.position = Vector2(start + step * i, 20 + absf(i - (count - 1) / 2.0) * 2)

func _render_jokers() -> void:
	for child in %JokerRow.get_children():
		%JokerRow.remove_child(child)
		child.queue_free()
	%JokerCount.text = "JOKERS   %d / %d" % [run.jokers.size(), run.joker_slots]
	for i in run.joker_slots:
		if i < run.jokers.size():
			var joker = JOKER_SCENE.instantiate()
			%JokerRow.add_child(joker)
			joker.setup(run.jokers[i], i)
			joker.joker_selected.connect(func(index: int): joker_inspected.emit(index))
		else:
			var slot := Button.new()
			slot.text = "+"
			slot.add_theme_color_override("font_color", Color("4d7362"))
			slot.add_theme_stylebox_override("normal", preload("res://resources/inset.tres"))
			slot.tooltip_text = "Find Jokers in the shop after defeating a blind."
			slot.pressed.connect(func(): joker_inspected.emit(-1))
			%JokerRow.add_child(slot)
	_position_jokers.call_deferred()

func _position_jokers() -> void:
	var children := %JokerRow.get_children()
	var width := minf(68 if compact else 94, (%JokerRow.size.x - 8 * (children.size() - 1)) / maxf(children.size(), 1))
	for i in children.size():
		children[i].custom_minimum_size = Vector2.ZERO
		children[i].size = Vector2(width, 94 if compact else 131)
		children[i].position = Vector2(i * (width + 8), 3)

func _render_pockets() -> void:
	%PocketHeading.text = "POCKET   %d / %d" % [run.consumables.size(), run.consumable_slots]
	for i in 3:
		var button: Button = [%Pocket0, %Pocket1, %Pocket2][i]
		button.visible = i < run.consumable_slots
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size.x = 48
		if i < run.consumables.size():
			var item = run.consumables[i]
			var id := str(item.id) if item is Dictionary else str(item)
			var data := GameCatalog.consumable(id)
			button.text = "✦\n" + str(data.get("title", data.get("name", id)))
			button.add_theme_font_size_override("font_size", 17)
		else:
			button.text = "+"

func _select_card(index: int) -> void:
	if busy or run.phase != "playing":
		return
	if selected.has(index):
		selected.erase(index)
	elif selected.size() < 5:
		selected.append(index)
	_update_selection()

func _update_selection() -> void:
	for i in card_nodes.size():
		card_nodes[i].set_selected(selected.has(i), not reduced_motion)
	%SelectionLabel.text = "%d / 5 SELECTED" % selected.size()
	%PlayButton.disabled = selected.is_empty() or selected.size() > run.max_played_cards() or busy or run.phase != "playing"
	%DiscardButton.disabled = selected.is_empty() or run.discards_left <= 0 or busy
	selection_changed.emit(selected)

func animate_score(cards: Array, result: Dictionary) -> void:
	busy = true
	%PlayButton.disabled = true
	%DiscardButton.disabled = true
	%StageCenter.visible = false
	%ScoredCards.visible = true
	for child in %ScoredCards.get_children():
		child.queue_free()
	var width := 84.0
	var start: float = (%Stage.size.x - cards.size() * (width + 14) + 14) / 2
	var played_nodes: Array = []
	for i in cards.size():
		var card = CARD_SCENE.instantiate()
		%ScoredCards.add_child(card)
		card.setup(cards[i], -1)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2.ZERO
		card.size = Vector2(width, 116)
		card.position = Vector2(start + i * (width + 14), maxf(2, (%Stage.size.y - 116) / 2))
		played_nodes.append(card)
	for i in result.get("events", []).size():
		var event: Dictionary = result.events[i].duplicate()
		event["hand"] = result.get("hand", "")
		score_progress.emit(event)
		score_tick.emit(i)
		if i < played_nodes.size() and not reduced_motion:
			played_nodes[i].pulse()
		await get_tree().create_timer(0.065 if reduced_motion else 0.13).timeout
	%ScoredCards.visible = false
	%StageCenter.visible = true
	%StageEyebrow.text = str(result.get("hand", "" )).to_upper()
	%StageTitle.text = "+" + _number(int(result.get("total", 0)))
	%StageDescription.text = "%s chips  ×  %s mult" % [_number(int(result.get("chips", 0))), str(result.get("mult", 0))]
	await get_tree().create_timer(0.35 if reduced_motion else 0.75).timeout
	busy = false

func _number(value: int) -> String:
	return preload("res://scripts/ui/hud.gd").format_number(value)
