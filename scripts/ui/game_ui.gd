extends Control
## Composition root: coordinates scene signals, never owns scoring rules.
const HUD = preload("res://scripts/ui/hud.gd")
var settings := {"music": true, "effects": true, "motion": true, "crt": true}
var inspected_index := -1
var inspected_kind := ""
var toast_tween: Tween
var selection_sound_ready := false
var compact_landscape := false
@onready var run: RunController = %RunController
@onready var table = %TableView
@onready var dialog = %Dialog
@onready var audio = %AudioDirector

func _ready() -> void:
	_load_settings()
	table.bind(run)
	run.changed.connect(_refresh)
	run.notice.connect(_toast)
	table.selection_changed.connect(_selection_changed)
	table.play_requested.connect(_play)
	table.discard_requested.connect(_discard)
	table.joker_inspected.connect(_inspect_joker)
	table.consumable_inspected.connect(_inspect_consumable)
	table.deck_requested.connect(_show_deck)
	table.card_inspected.connect(_inspect_card)
	table.advance_requested.connect(_advance)
	table.score_tick.connect(audio.play_score)
	table.score_progress.connect(func(event: Dictionary): %RunHUD.update_run(run, event))
	%RunHUD.get_node("%RunInfo").pressed.connect(_show_run_info)
	%MenuButton.pressed.connect(_show_menu)
	%SoundButton.pressed.connect(func(): _setting_changed("music", not settings.music))
	dialog.action_requested.connect(_dialog_action)
	dialog.settings_changed.connect(_setting_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply_settings()
	if not run.load_run():
		run.new_run("MIDNIGHT")
		run.start_blind()
	_refresh()
	selection_sound_ready = true

func _layout() -> void:
	var pixels: Vector2i = DisplayServer.window_get_size()
	if DisplayServer.get_name() == "headless":
		pixels = Vector2i(get_viewport_rect().size)
	var portrait := pixels.y > pixels.x
	compact_landscape = not portrait and pixels.y < 650
	var design := Vector2i(720, 1200) if portrait else (Vector2i(1152, 720) if pixels.x < 1100 else Vector2i(1440, 900))
	if get_window().content_scale_size != design:
		get_window().content_scale_size = design
	%RunHUD.visible = not portrait and not compact_landscape
	%CompactHUD.visible = portrait or compact_landscape
	%Subtitle.visible = not portrait and pixels.x >= 1100
	%HeaderSpacer.visible = not %Subtitle.visible
	%Seed.visible = not portrait and not compact_landscape
	%Brand.add_theme_font_size_override("font_size", 31 if portrait else 35)
	%FooterRight.visible = not portrait
	%RunHUD.custom_minimum_size.x = 234 if pixels.x < 1100 else 264
	%SafeMargin.add_theme_constant_override("margin_left", 18 if pixels.x < 1100 else 30)
	%SafeMargin.add_theme_constant_override("margin_right", 18 if pixels.x < 1100 else 30)
	%SafeMargin.add_theme_constant_override("margin_top", 8 if compact_landscape else 20)
	%SafeMargin.add_theme_constant_override("margin_bottom", 8 if compact_landscape else 15)
	$SafeMargin/Layout.add_theme_constant_override("separation", 8 if compact_landscape else 18)
	$SafeMargin/Layout/Separator.visible = not compact_landscape
	$SafeMargin/Layout/Footer.visible = not compact_landscape
	%MenuButton.custom_minimum_size.y = 80 if portrait or compact_landscape else 50
	%SoundButton.custom_minimum_size = Vector2(80, 80) if portrait or compact_landscape else Vector2(54, 50)
	table.set_compact(compact_landscape, portrait)
	var mobile := portrait or compact_landscape
	for node in [%CompactBlind, %CompactHands, %CompactCash]:
		node.add_theme_font_size_override("font_size", 26 if mobile else 22)
	for node in [%MenuButton, %SoundButton, table.get_node("%PlayButton"), table.get_node("%DiscardButton")]:
		node.add_theme_font_size_override("font_size", 25 if mobile else 20)
	dialog.mobile = mobile
	table.get_node("Inventory/ConsumablePanel").custom_minimum_size.x = 150 if portrait else 184
	table.get_node("%OrderHint").visible = not portrait
	if is_instance_valid(run):
		_refresh()

func _refresh() -> void:
	if not is_node_ready() or table.busy:
		return
	table.refresh()
	%RunHUD.update_run(run)
	%Seed.text = "SEED  " + run.seed_text
	%CompactBlind.text = "%s\n%s / %s" % [run.blind_name(), HUD.format_number(run.round_score), HUD.format_number(run.target_score)]
	%CompactHands.text = "%d HANDS\n%d DISCARDS" % [run.hands_left, run.discards_left]
	%CompactCash.text = "$%d\nANTE %d/8" % [run.money, run.ante]

func _selection_changed(indices: Array) -> void:
	if selection_sound_ready and not indices.is_empty():
		audio.unlock()
		audio.play_select()
	var preview: Dictionary = run.preview(indices) if not indices.is_empty() else {}
	%RunHUD.update_run(run, preview)
	if not preview.is_empty() and not table.busy:
		table.get_node("%StageEyebrow").text = "PROJECTED SCORE · " + str(preview.hand).to_upper()
		table.get_node("%StageTitle").text = "%s  ×  %s" % [HUD.format_number(int(preview.chips)), str(preview.mult)]
		table.get_node("%StageDescription").text = (str(preview.blocked_reason) + " Playing spends one hand.") if preview.has("blocked_reason") else "%s chips  ·  Level %d" % [HUD.format_number(int(preview.total)), run.levels.get(preview.hand, 1)]
	elif not table.busy and run.phase == "playing":
		table.get_node("%StageEyebrow").text = "MAKE YOUR NEXT MOVE"
		table.get_node("%StageTitle").text = "The table is yours."
		table.get_node("%StageDescription").text = run.boss_description() if run.blind_index == 2 else "Select up to 5 cards to make a poker hand."

func _play(indices: Array) -> void:
	if table.busy or indices.is_empty():
		return
	audio.unlock()
	var cards: Array = []
	for index in indices:
		cards.append(run.hand[index].duplicate(true))
	table.busy = true
	var result := run.play_cards(indices)
	if result.has("error") or result.is_empty():
		table.busy = false
		_refresh()
		return
	%RunHUD.update_run(run, result)
	await table.animate_score(cards, result)
	_refresh()
	if run.phase == "shop":
		_toast("Blind defeated. Time to build your next combo.")
	elif run.phase == "won":
		_toast("Eight antes. Twenty-four blinds. The table is yours.")

func _discard(indices: Array) -> void:
	if not table.busy:
		audio.unlock()
		if run.discard_cards(indices):
			audio.play_discard()

func _advance() -> void:
	if run.phase == "blind":
		run.start_blind()
	else:
		_show_new_run()

func _show_menu() -> void:
	if table.busy:
		return
	dialog.open("The midnight table", "[color=#d8b471]A little luck. A lot of possibilities.[/color]\nYour run saves automatically after every move.", [
		{"text": "Back to the table", "action": "close", "primary": true},
		{"text": "New run", "action": "new"},
		{"text": "How to play", "action": "help"},
		{"text": "Run info & hand levels", "action": "run_info"},
		{"text": "Joker collection", "action": "collection"},
		{"text": "Sound & display", "action": "settings"},
	])

func _show_new_run() -> void:
	dialog.open("A fresh deck. A new story.", "Start an eight-ante campaign or a challenge.\n[color=#d8b471]Starting replaces the current saved run.[/color]", [
		{"text": "Shuffle & play  →", "action": "start", "primary": true}], "new")

func _show_run_info() -> void:
	var body := "[color=#d8b471]%s DECK · %s[/color]\nSeed: %s\nAnte %d / 8 · Round %d\n\n" % [run.deck_id.to_upper(), ["WHITE STAKE", "RED STAKE", "GREEN STAKE"][run.stake], run.seed_text, run.ante, run.round_number]
	body += "[b]Hand levels[/b]\n"
	for hand: String in PokerEvaluator.HANDS:
		body += "%s   ·   Lv.%d\n" % [hand, run.levels.get(hand, 1)]
	body += "\nInterest: $1 per $5 held, up to $5 after a blind.\nUnused hands earn $1 each. Jokers trigger left to right."
	dialog.open("Your run", body, [{"text": "Poker hand guide", "action": "hands"}], "collection")

func _show_deck() -> void:
	var names := {"S": "SPADES ♠", "H": "HEARTS ♥", "C": "CLUBS ♣", "D": "DIAMONDS ♦"}
	var body := "[color=#d8b471]%d cards in your deck · %d left to draw[/color]\n\n" % [run.deck.size(), run.draw_pile.size()]
	for suit: String in names:
		body += "[b]" + names[suit] + "[/b]\n"
		var ranks: Array = []
		for card: Dictionary in run.deck:
			if card.suit == suit:
				var rank := str(card.rank)
				if int(card.rank) >= 11:
					rank = ["J", "Q", "K", "A"][int(card.rank) - 11]
				if not str(card.enhancement).is_empty():
					rank += "*"
				ranks.append(rank)
		body += "  ".join(ranks) + "\n\n"
	body += "* Enhanced card. Inspect a held card to see its ability."
	dialog.open("Your full deck", body, [], "collection")

func _inspect_card(index: int) -> void:
	if table.busy or index < 0 or index >= run.hand.size():
		return
	var card: Dictionary = run.hand[index]
	var rank: String = {11: "Jack", 12: "Queen", 13: "King", 14: "Ace"}.get(int(card.rank), str(card.rank))
	var suit: String = {"S": "Spades", "H": "Hearts", "D": "Diamonds", "C": "Clubs"}[card.suit]
	var body := "%d card chips when scored.\n\n" % (11 if int(card.rank) == 14 else mini(int(card.rank), 10))
	var enhancements := {"bonus": "+30 Chips when scored.", "mult": "+4 Mult when scored.", "wild": "Counts as any suit.", "glass": "×2 Mult; 1 in 4 chance to shatter permanently.", "steel": "×1.5 Mult while held, rather than played.", "lucky": "1 in 5 chance for +20 Mult; 1 in 15 for $20.", "stone": "+50 Chips; no rank or suit; always scores."}
	body += str(enhancements.get(card.enhancement, "No enhancement.")) + "\n\n"
	body += "Edition: " + (str(card.edition).capitalize() if card.edition != "" else "Standard") + "\n"
	body += "Seal: " + (str(card.seal).capitalize() if card.seal != "" else "None")
	dialog.open(rank + " of " + suit, body)

func _inspect_joker(index: int) -> void:
	if table.busy:
		return
	if index < 0:
		dialog.open("Make room for a little magic.", "Win a blind to visit the shop. Jokers change the rules of scoring.\n\nThey trigger [color=#d8b471]from left to right[/color]. Put +Mult before ×Mult to get more out of a hand.")
		return
	inspected_index = index
	inspected_kind = "joker"
	var item = GameCatalog.joker(run.jokers[index].id)
	var sell_price := maxi(1, int(item.price / 2.0))
	dialog.open(item.title, "[color=#d8b471]" + item.rarity.to_upper() + " JOKER[/color]\n\n" + item.description + "\n\nPosition %d of %d. Order changes your score." % [index + 1, run.jokers.size()], [
		{"text": "Move left  ←", "action": "joker_left", "disabled": index == 0},
		{"text": "Move right  →", "action": "joker_right", "disabled": index >= run.jokers.size() - 1},
		{"text": "Sell for $%d" % sell_price, "action": "joker_sell"},
	])

func _inspect_consumable(index: int) -> void:
	if table.busy:
		return
	if index >= run.consumables.size():
		dialog.open("A little something in your pocket.", "Buy Planets, Tarots, or Spectrals in the shop.\n\n[b]Planets[/b] level up poker hands.\n[b]Tarots[/b] enhance selected cards.\n[b]Spectrals[/b] offer powerful changes with a cost.")
		return
	inspected_index = index
	inspected_kind = "consumable"
	var owned = run.consumables[index]
	var id := str(owned.id) if owned is Dictionary else str(owned)
	var item := GameCatalog.consumable(id)
	dialog.open(str(item.title), str(item.kind).to_upper() + "\n\n" + str(item.description) + "\n\nFor card effects, select cards in your hand before using.", [
		{"text": "Use card", "action": "consume", "primary": true},
		{"text": "Sell for $%d" % maxi(1, int(item.price / 2.0)), "action": "consumable_sell"},
	])

func _dialog_action(action: String) -> void:
	audio.unlock()
	match action:
		"close": dialog.close()
		"new": _show_new_run()
		"run_info": _show_run_info()
		"start":
			var options: Dictionary = dialog.new_run_options()
			dialog.close()
			run.new_run(options.seed, options.deck, options.stake, options.challenge)
			run.start_blind()
		"help":
			dialog.open("Every hand is a possibility.", "[b]1. Make a poker hand.[/b]\nTap cards to select up to five. Tap again to deselect. Play to score, or discard to draw replacements.\n\n[b]2. Beat the blind.[/b]\nScore enough chips before your hands run out. Only the cards that form the poker hand score. Aces are worth 11; face cards, 10.\n\n[b]3. Build something ridiculous.[/b]\nSpend rewards on Jokers and upgrades. Chips × Mult is your score. +Mult before ×Mult makes a stronger combo. Tap a Joker to reorder or sell it.\n\n[b]4. Reach ante eight.[/b]\nEvery ante has a Small Blind, Big Blind, and Boss. Read the boss rule before you play. Keep money for interest.\n\nKeyboard: 1–8 select · Space play · D discard · R sort · Esc menu.", [{"text": "Poker hand guide", "action": "hands"}], "collection")
		"hands":
			var body := "[color=#d8b471]BASE CHIPS × MULT · LEVEL 1[/color]\n\n"
			for hand: String in PokerEvaluator.HANDS:
				var data: Dictionary = PokerEvaluator.HANDS[hand]
				body += "[b]%s[/b]  ·  %d × %s\n" % [hand, data.base_chips, str(data.base_mult)]
			dialog.open("Know your hands", body, [], "collection")
		"collection":
			var body := "[color=#d8b471]%d UNIQUE JOKERS · DISCOVER YOUR NEXT SYNERGY[/color]\n\n" % GameCatalog.jokers().size()
			for item in GameCatalog.jokers():
				body += "[b]%s[/b] · %s · $%d\n%s\n\n" % [item.title, item.rarity, item.price, item.description]
			dialog.open("The Joker collection", body, [], "collection")
		"settings":
			dialog.open("Set the mood.", "Adjust the table to your taste. Settings are saved on this device.", [], "settings")
			dialog.set_settings(settings)
		"joker_left", "joker_right":
			var to_index := inspected_index + (-1 if action == "joker_left" else 1)
			run.move_joker(inspected_index, to_index)
			_inspect_joker(to_index)
		"joker_sell":
			run.sell_joker(inspected_index)
			dialog.close()
		"consume":
			if run.use_consumable(inspected_index, table.selected.duplicate()):
				dialog.close()
		"consumable_sell":
			run.sell_consumable(inspected_index)
			dialog.close()

func _setting_changed(key: String, value: bool) -> void:
	settings[key] = value
	_apply_settings()
	var config := ConfigFile.new()
	for name: String in settings:
		config.set_value("preferences", name, settings[name])
	config.save("user://settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key: String in settings:
			settings[key] = config.get_value("preferences", key, true)

func _apply_settings() -> void:
	audio.set_music(settings.music)
	audio.effects_enabled = settings.effects
	table.reduced_motion = not settings.motion
	for card in table.card_nodes:
		card.reduced_motion = not settings.motion
	%CRT.visible = settings.crt
	$Felt.material.set_shader_parameter("motion", 1.0 if settings.motion else 0.0)
	%SoundButton.text = "♪" if settings.music else "♪̸"

func _toast(message: String) -> void:
	%Toast.text = message
	%Toast.modulate.a = 1.0
	%Toast.visible = true
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.5)
	toast_tween.tween_property(%Toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func(): %Toast.visible = false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			if dialog.visible:
				dialog.close()
			else:
				_show_menu()
		elif not dialog.visible and not table.busy:
			if event.keycode == KEY_SPACE:
				_play(table.selected.duplicate())
			elif event.keycode == KEY_D:
				_discard(table.selected.duplicate())
			elif event.keycode == KEY_R:
				run.sort_hand()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
				var index: int = event.keycode - KEY_1
				if index < run.hand.size():
					table._select_card(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(run):
		run.save_run()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if dialog.visible:
			dialog.close()
		else:
			_show_menu()
