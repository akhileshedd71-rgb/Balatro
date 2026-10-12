extends SceneTree
## Headless behavioral tests. All saves use temporary, isolated paths.

var checks: int = 0
var failures: int = 0
var instances: Array[RunController] = []

func _initialize() -> void:
	_test_determinism()
	_test_actions()
	_test_shop()
	_test_discounts()
	_test_consumables()
	_test_campaign()
	_test_bosses()
	_test_exhausted_actions()
	_test_persistence()
	for run: RunController in instances:
		run.clear_save()
		run.free()
	print("RunController: %d checks, %d failures." % [checks, failures])
	quit(1 if failures > 0 else 0)

func _run(seed_value: String = "TEST", deck_type: String = "red", difficulty: int = 0, challenge: String = "") -> RunController:
	var run: RunController = RunController.new()
	run.save_path = "user://test_run_%d.json" % instances.size()
	instances.append(run)
	run.new_run(seed_value, deck_type, difficulty, challenge)
	return run

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _test_determinism() -> void:
	var first: RunController = _run("MIDNIGHT")
	var second: RunController = _run("midnight")
	first.start_blind()
	second.start_blind()
	_check(first.hand == second.hand, "same normalized seed gives identical opening hand")
	_check(first.draw_pile == second.draw_pile, "same seed gives identical full shuffle")
	_check(first.deck.size() == 52 and first.hand.size() == 8, "standard deck and hand sizes")
	_check(first.jokers.size() == 1 and first.jokers[0].id == "jester", "starter Joker exists")
	_check(first.discards_left == 4, "red deck extra discard")
	first.discard_cards([0, 2, 4])
	second.discard_cards([0, 2, 4])
	_check(first.hand == second.hand, "same choices preserve deterministic drawing")
	var other: RunController = _run("OTHER")
	other.start_blind()
	_check(other.hand != first.hand, "different seed changes draw order")
	var blue: RunController = _run("A", "blue")
	blue.start_blind()
	_check(blue.hands_left == 5 and blue.discards_left == 3, "blue deck extra hand")
	var gold: RunController = _run("A", "gold")
	_check(gold.money == 10, "gold deck extra start cash")
	var challenge: RunController = _run("A", "red", 0, "short_stack")
	challenge.start_blind()
	_check(challenge.money == 0 and challenge.hand.size() == 6, "short stack challenge")
	var stake_run: RunController = _run("A", "red", 2)
	_check(stake_run.target_score == 480, "stake target scaling")

func _test_actions() -> void:
	var run: RunController = _run()
	_check(run.play_cards([0]).has("error"), "cannot play before blind starts")
	run.start_blind()
	var before: Array = run.hand.duplicate(true)
	var rng_before: int = run.rng.state
	_check(run.play_cards([]).has("error"), "empty hand rejected")
	_check(run.play_cards([0, 0]).has("error"), "duplicate indices rejected")
	_check(run.play_cards([-1]).has("error"), "negative index rejected")
	_check(run.play_cards([0, 1, 2, 3, 4, 5]).has("error"), "more than five selected rejected")
	_check(run.play_cards(["0"]).has("error"), "noninteger index rejected")
	_check(run.hand == before and run.hands_left == 4, "invalid actions preserve state")
	var estimate: Dictionary = run.preview([0])
	_check(run.rng.state == rng_before and run.hand == before, "preview is pure")
	var result: Dictionary = run.play_cards([0])
	_check(int(result.total) == int(estimate.total), "preview matches actual deterministic score")
	_check(run.hands_left == 3 and run.hand.size() == 8, "playing spends one hand and refills")
	_check(run.hand_counts.get(result.hand, 0) == 1, "hand usage statistics update")
	_check(run.deck.size() == 52, "playing does not remove permanent deck cards")
	_check(not run.discard_cards([999]), "discard validates bounds")
	var card_ids: Array = []
	for card: Dictionary in run.hand:
		card_ids.append(card.id)
	run.sort_hand(false)
	var sorted_ids: Array = []
	for card: Dictionary in run.hand:
		sorted_ids.append(card.id)
	card_ids.sort()
	sorted_ids.sort()
	_check(card_ids == sorted_ids, "sorting preserves the held cards")
	run.target_score = 99999999
	run.hands_left = 1
	run.play_cards([0])
	_check(run.phase == "lost", "exhausting hands loses the run")
	_check(not run.discard_cards([0]), "cannot discard after losing")

func _win_blind(run: RunController) -> void:
	if run.phase == "blind":
		run.start_blind()
	run.target_score = 1 # Fixture: transition validation, not a claim of gameplay balance.
	run.play_cards([0])

func _test_shop() -> void:
	var run: RunController = _run()
	run.money = 25
	_win_blind(run)
	_check(run.phase == "shop" and run.money == 36, "reward includes blind, unused hands, and capped interest")
	_check(run.shop_items.size() == 5, "shop has two Jokers, two consumables, and one voucher")
	run.money = 0
	_check(not run.buy_item(0) and not bool(run.shop_items[0].sold), "unaffordable purchase rejected")
	_check(not run.reroll_shop(), "unaffordable reroll rejected")
	run.money = 100
	var price: int = int(run.shop_items[0].price)
	_check(run.buy_item(0) and run.money == 100 - price, "purchase charges displayed amount")
	_check(not run.buy_item(0), "sold offer cannot be purchased twice")
	_check(run.jokers.size() == 2, "Joker purchase adds inventory")
	run.joker_slots = 2
	_check(not run.buy_item(1), "Joker slot capacity enforced")
	_check(run.buy_item(2) and run.buy_item(3), "two consumable purchases succeed")
	var cash: int = run.money
	_check(run.reroll_shop() and run.reroll_cost == 6 and run.money == cash - 5, "rerolls spend cash and escalate")
	_check(not run.buy_item(2), "consumable slot capacity enforced")
	var joker_before: String = run.jokers[0].id
	run.move_joker(0, 1)
	_check(run.jokers[1].id == joker_before, "Joker move changes scoring order")
	cash = run.money
	_check(run.sell_joker(0) and run.money > cash, "Joker sale returns cash")
	_check(not run.sell_joker(-1), "invalid sale rejected")
	run.sell_consumable(0)
	_check(run.consumables.size() == 1, "consumable sale frees slot")
	run.leave_shop()
	_check(run.phase == "blind" and run.blind_index == 1, "leave shop advances to Big Blind")
	_check(not run.buy_item(0), "cannot buy outside shop")
	_win_blind(run)
	_check(run.reroll_cost == 5, "reroll cost resets in next shop")

func _test_consumables() -> void:
	var run: RunController = _run()
	run.consumables = [{"id": "planet_mercury"}]
	_check(run.use_consumable(0) and run.levels.Pair == 2, "planet permanently levels associated poker hand")
	_check(run.planets_used == 1, "planet scaler records usage")
	run.consumables = [{"id": "tarot_mult"}]
	_check(not run.use_consumable(0), "targeted Tarot cannot be used before drawing")
	_check(run.consumables.size() == 1, "invalid consumable action preserves item")
	run.start_blind()
	var id: String = run.hand[0].id
	_check(run.use_consumable(0, [0]), "Tarot applies to selected card")
	_check(run.hand[0].enhancement == "mult", "enhancement visible in current hand")
	var permanent: Dictionary = run.deck.filter(func(card: Dictionary) -> bool: return card.id == id)[0]
	_check(permanent.enhancement == "mult" and run.tarots_used == 1, "enhancement persisted to base deck")
	run.consumables = [{"id": "tarot_death"}]
	var source: Dictionary = run.hand[0].duplicate(true)
	var target_id: String = run.hand[1].id
	_check(not run.use_consumable(0, [0]), "copy requires two selected cards")
	_check(run.use_consumable(0, [0, 1]), "copy accepts two selected cards")
	_check(run.hand[1].id == target_id and run.hand[1].rank == source.rank and run.hand[1].enhancement == source.enhancement, "copy preserves unique identity and copies properties")
	run.consumables = [{"id": "tarot_hanged_man"}]
	_check(run.use_consumable(0, [0, 1]) and run.deck.size() == 50, "destroy permanently removes selected cards")
	_check(run.hand.size() == 8, "destroy refills hand")
	run.consumables = [{"id": "spectral_ouija"}]
	_check(run.use_consumable(0), "spectral all-rank applies")
	_check(run.hand.all(func(card: Dictionary) -> bool: return int(card.rank) == 14) and run.hand_size == 7, "Ouija sets held cards to aces with hand-size drawback")
	run.consumables = [{"id": "spectral_ankh"}]
	_check(run.use_consumable(0) and run.jokers.size() == 2, "spectral duplicates Joker")

func _test_discounts() -> void:
	var run: RunController = _run("DISCOUNT")
	_win_blind(run)
	run.money = 100
	run.shop_items = [
		{"type": "joker", "id": "amplifier", "price": 8, "sold": false},
		{"type": "consumable", "id": "tarot_death", "price": 4, "sold": false},
		{"type": "voucher", "id": "voucher_clearance", "price": 10, "sold": false},
	]
	_check(run.buy_item(2) and is_equal_approx(run.discount, 0.25), "Clearance applies a fractional percentage discount")
	_check(run.money == 90, "Clearance charges its original displayed price")
	_check(run.shop_items[0].price == 6 and run.shop_items[1].price == 3, "Clearance updates unsold offers in current shop")
	_check(run.shop_items[2].price == 10 and bool(run.shop_items[2].sold), "purchased voucher keeps original receipt price")
	_check(RunEconomy.discounted_price(7, 0.25) == 6, "fractional discounted prices round up")
	_check(RunEconomy.discounted_price(1, 0.99) == 1, "discount preserves minimum price")
	_check(run.save_run(), "discounted shop saves")
	var restored: RunController = _run("RESTORE_DISCOUNT")
	RunPersistence.write(restored.save_path, RunPersistence.read(run.save_path))
	_check(restored.load_run() and is_equal_approx(restored.discount, 0.25), "percentage discount survives save/load")
	_check(restored.shop_items[0].price == 6, "discounted offer price survives save/load")
	_check(restored.reroll_shop(), "discounted shop rerolls")
	for offer: Dictionary in restored.shop_items:
		var base_price: int = 10
		if offer.type == "joker":
			base_price = GameCatalog.joker(str(offer.id)).price
		elif offer.type == "consumable":
			base_price = int(GameCatalog.consumable(str(offer.id)).price)
		_check(offer.price == int(ceil(base_price * 0.75)), "new shop offer receives percentage discount")
		_check(offer.id != "voucher_clearance", "owned voucher is excluded from future shop")

func _test_campaign() -> void:
	var run: RunController = _run("CAMPAIGN")
	for index: int in range(24):
		_check(run.ante == index / 3 + 1 and run.blind_index == index % 3, "campaign ante and blind %d" % index)
		_win_blind(run)
		if index < 23:
			_check(run.phase == "shop", "blind %d opens shop" % index)
			run.leave_shop()
		else:
			_check(run.phase == "won" and run.wins == 1, "final boss wins campaign")
	_check(run.round_number == 24, "campaign includes 24 played blinds")
	run.new_run("NEXT")
	_check(run.ante == 1 and run.wins == 1 and run.deck.size() == 52, "new run resets gameplay and preserves wins")

func _test_bosses() -> void:
	var run: RunController = _run()
	run.blind_index = 2
	run.start_blind()
	_check(run.get_context().debuff_suit == "H", "Heart boss context debuffs hearts")
	run.new_run("BOSS")
	run.ante = 2
	run.blind_index = 2
	run.start_blind()
	_check(run.discards_left == 0 and not run.discard_cards([0]), "Drought disallows discards")
	run.new_run("BOSS")
	run.ante = 3
	run.blind_index = 2
	run.start_blind()
	_check(run.max_played_cards() == 3 and run.play_cards([0, 1, 2, 3]).has("error"), "Needle enforces maximum three")
	run.new_run("BOSS")
	run.ante = 4
	run.blind_index = 2
	run.start_blind()
	_check(run.get_context().debuff_faces, "Mask context debuffs face cards")
	run.new_run("BOSS")
	run.ante = 5
	run.blind_index = 2
	run.start_blind()
	run.play_cards([0])
	_check(run.boss_hand_lock == "High Card", "Echo locks first played hand")
	run.hand = run.deck.filter(func(card: Dictionary) -> bool: return int(card.rank) == 2).duplicate(true)
	var hands_before: int = run.hands_left
	_check(run.preview([0, 1]).total == 0, "Echo previews zero for a different poker type")
	var rejected: Dictionary = run.play_cards([0, 1])
	_check(rejected.total == 0 and rejected.has("blocked_reason") and run.hands_left == hands_before - 1, "Echo spends a hand with zero score on other poker types")
	run.new_run("BOSS")
	run.ante = 6
	run.blind_index = 2
	run.start_blind()
	_check(run.hand.size() == 6, "Pocket deals six cards")
	run.new_run("BOSS")
	run.ante = 7
	run.blind_index = 2
	run.start_blind()
	_check(run.target_score == 140000, "Wall doubles boss target")
	run.new_run("BOSS")
	run.ante = 8
	run.blind_index = 2
	run.start_blind()
	_check(run.target_score == 150000, "Crown adds final score challenge")

func _test_exhausted_actions() -> void:
	var run: RunController = _run("NO_MOVES")
	run.ante = 5
	run.blind_index = 2
	run.start_blind()
	run.boss_hand_lock = "Full House"
	run.discards_left = 0
	run.hands_left = 1
	run.hand = run.deck.filter(func(card: Dictionary) -> bool: return card.suit == "S").slice(0, 8).duplicate(true)
	var before_score: int = run.round_score
	var result: Dictionary = run.play_cards([0])
	_check(result.total == 0 and run.round_score == before_score and run.phase == "lost", "Echo with no matching type can spend final hand and end run")
	run.new_run("PAIR_CHALLENGE", "red", 0, "pair_only")
	run.start_blind()
	_check(run.preview([0]).total == 0, "pair-only challenge previews zero for non-pairs")
	var before: int = run.hands_left
	run.play_cards([0])
	_check(run.hands_left == before - 1 and run.hand.size() == 8 and run.phase == "playing", "pair-only challenge can redraw with zero scoring play")
	run.hand = [run.hand[0]]
	run.draw_pile = []
	run.deck = run.hand.duplicate(true)
	run.consumables = [{"id": "tarot_hanged_man"}]
	_check(run.use_consumable(0, [0]) and run.phase == "lost", "destroying last available card ends run")
	run.new_run("NO_CARDS")
	run.start_blind()
	run.hand = [run.hand[0]]
	run.draw_pile = []
	_check(run.discard_cards([0]) and run.phase == "lost", "discarding last available card ends run")

func _test_persistence() -> void:
	var original: RunController = _run("PERSIST")
	original.start_blind()
	original.discard_cards([1, 3])
	original.consumables = [{"id": "planet_pluto"}]
	original.use_consumable(0)
	_check(original.save_run() and original.has_save(), "save succeeds and is recognized")
	var restored: RunController = _run("TEMP")
	var restored_path: String = restored.save_path
	_check(RunPersistence.write(restored_path, RunPersistence.read(original.save_path)), "snapshot copied to test restore path")
	_check(restored.load_run(), "valid save loads")
	_check(restored.hand == original.hand and restored.deck == original.deck, "loaded cards match")
	_check(restored.seed_text == original.seed_text and restored.rng.state == original.rng.state, "RNG 64-bit state restored exactly")
	_check(restored.planets_used == 1 and restored.discards_used == 1 and restored.levels["High Card"] == 2, "progress and scalers restore")
	original.discard_cards([0, 2])
	restored.discard_cards([0, 2])
	_check(restored.hand == original.hand, "loaded run draws identically")
	_win_blind(original)
	_win_blind(restored)
	_check(restored.shop_items == original.shop_items, "loaded run generates identical shop")
	original.money = 99
	restored.money = 99
	original.reroll_shop()
	restored.reroll_shop()
	_check(restored.shop_items == original.shop_items, "loaded RNG matches subsequent weighted reroll")
	var old_phase: String = restored.phase
	var broken: Dictionary = RunPersistence.capture(restored, restored.rng)
	broken.hand = [{"id": "invalid"}]
	RunPersistence.write(restored.save_path, broken)
	_check(not restored.load_run() and restored.phase == old_phase, "malformed save rejected without altering active state")
	broken = RunPersistence.capture(restored, restored.rng)
	broken.money = {}
	RunPersistence.write(restored.save_path, broken)
	_check(not restored.load_run(), "invalid scalar types rejected")
	restored.clear_save()
	_check(not restored.has_save(), "clear save removes persisted state")
