extends SceneTree
## Scene-level behavior and signal tests. The shell runner isolates user://.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.run.save_path = "user://ui_test_save.json"
	game.run.new_run("MIDNIGHT")
	game.run.start_blind()
	game.table.reduced_motion = true
	await settle()
	check(game.run.phase == "playing", "First launch opens a playable blind")
	check(game.table.card_nodes.size() == 8, "Eight instantiated hand card scenes")
	check(game.table.get_node("%PlayButton").disabled, "Cannot play an empty selection")
	game.table.card_nodes[3].pressed.emit()
	game.table.card_nodes[4].pressed.emit()
	check(game.table.selected == [3, 4], "Card scene signals select both Queens")
	check(game.get_node("%RunHUD").get_node("%HandName").text == "Pair", "HUD previews the real evaluated hand")
	check(not game.table.get_node("%PlayButton").disabled, "Selection enables play")
	await game._play(game.table.selected.duplicate())
	await settle()
	check(game.run.round_score == 180, "Playing first pair scores 180")
	check(game.run.hands_left == 3 and game.run.hand.size() == 8, "Play spends a hand and redraws")
	check(game.table.selected.is_empty() and not game.table.busy, "Animation releases controls and clears selection")
	game.table.card_nodes[1].pressed.emit()
	game.table.card_nodes[7].pressed.emit()
	await game._play(game.table.selected.duplicate())
	await settle()
	check(game.run.phase == "shop" and game.run.round_score == 360, "Second real pair defeats the blind")
	check(game.table.get_node("%ShopView").visible, "Shop scene is shown")
	check(not game.table.get_node("%HandSection").visible, "Hand input is hidden during shopping")
	var offers = game.table.get_node("%ShopView").get_node("%Offers")
	check(offers.get_child_count() == 5, "Five shop offer scenes are present")
	check(offers.columns == 3, "Desktop shop lays out three columns after container resize")
	var price: int = game.run.shop_items[2].price
	var cash_before: int = game.run.money
	offers.get_child(2).get_node("%Buy").pressed.emit()
	await settle()
	check(game.run.money == cash_before - price, "Shop Buy button charges listed price")
	check(game.run.consumables.size() == 1, "Purchase appears in consumable inventory")
	check(offers.get_child(2).get_node("%Buy").disabled, "Purchased offer cannot be bought twice")
	game.table.get_node("%ShopView").get_node("%NextBlind").pressed.emit()
	await settle()
	check(game.run.phase == "blind", "Next Blind button enters selection phase")
	game.table.get_node("%AdvanceButton").pressed.emit()
	await settle()
	check(game.run.phase == "playing" and game.run.blind_index == 1, "Play blind begins Big Blind")
	game.table.card_nodes[0].card_inspected.emit(0)
	check(game.dialog.visible, "Long-hold inspection opens the card dialog")
	check(game.dialog.get_node("%Body").text.contains("card chips"), "Inspection explains card chip value")
	game.dialog.close()
	game.table.card_nodes[0].pressed.emit()
	var old_rank: int = game.run.hand[0].rank
	game._inspect_consumable(0)
	game._dialog_action("consume")
	await settle()
	check(game.run.consumables.is_empty(), "Consumable Use button removes used item")
	check(int(game.run.hand[0].rank) != old_rank, "MIDNIGHT Strength consumable upgrades selected card")
	# UI fixture for the voucher-expanded third slot, without changing scoring tests.
	game.run.consumable_slots = 3
	game.run.consumables = ["planet_pluto", "planet_venus", "planet_earth"]
	game._refresh()
	await settle()
	check(game.table.get_node("%Pocket2").visible, "Third consumable slot is accessible after Crystal Ball")
	game.table.get_node("%Pocket2").pressed.emit()
	check(game.dialog.get_node("%Title").text == "Earth", "Third pocket inspects its actual item")
	game.dialog.close()
	game._setting_changed("motion", false)
	check(game.table.reduced_motion, "Reduced-motion setting reaches table")
	check(game.table.card_nodes[0].reduced_motion, "Reduced-motion setting reaches card components")
	game._show_new_run()
	game.dialog.get_node("%SeedInput").text = "UI-TEST"
	game.dialog.get_node("%DeckChoice").select(1)
	game._dialog_action("start")
	await settle()
	check(game.run.seed_text == "UI-TEST" and game.run.deck_id == "blue", "New-run dialog applies seed and deck")
	check(game.run.hands_left == 5, "Blue deck gameplay bonus is active")
	check(not game.dialog.visible, "Starting a run closes dialog")
	game.run.clear_save()
	game.queue_free()
	await settle()
	await create_timer(0.3).timeout
	print("UI checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
