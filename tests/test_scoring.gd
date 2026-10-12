extends SceneTree
## Headless regression tests. Run: godot --headless --path . -s tests/test_scoring.gd

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_test_poker_hands()
	_test_scoring_pipeline()
	_test_randomness_and_preview()
	_test_catalog_and_jokers()
	if failures.is_empty():
		print("SCORING TESTS PASSED: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL: " + failure)
		printerr("%d of %d checks failed" % [failures.size(), checks])
		quit(1)

func _test_poker_hands() -> void:
	var cases: Array = [
		["High Card", [_c(14, "S"), _c(10, "H"), _c(7, "D"), _c(4, "C"), _c(2, "S")], 1],
		["Pair", [_c(8, "S"), _c(8, "H"), _c(14, "D"), _c(4, "C"), _c(2, "S")], 2],
		["Two Pair", [_c(8, "S"), _c(8, "H"), _c(4, "D"), _c(4, "C"), _c(2, "S")], 4],
		["Three of a Kind", [_c(8, "S"), _c(8, "H"), _c(8, "D"), _c(4, "C"), _c(2, "S")], 3],
		["Straight", [_c(10, "S"), _c(11, "H"), _c(12, "D"), _c(13, "C"), _c(14, "S")], 5],
		["Flush", [_c(2, "H"), _c(4, "H"), _c(6, "H"), _c(8, "H"), _c(10, "H")], 5],
		["Full House", [_c(8, "S"), _c(8, "H"), _c(8, "D"), _c(4, "C"), _c(4, "S")], 5],
		["Four of a Kind", [_c(8, "S"), _c(8, "H"), _c(8, "D"), _c(8, "C"), _c(2, "S")], 4],
		["Straight Flush", [_c(2, "H"), _c(3, "H"), _c(4, "H"), _c(5, "H"), _c(6, "H")], 5],
		["Five of a Kind", [_c(8, "S"), _c(8, "H"), _c(8, "D"), _c(8, "C"), _c(8, "S")], 5],
		["Flush House", [_c(8, "S"), _c(8, "S"), _c(8, "S"), _c(4, "S"), _c(4, "S")], 5],
		["Flush Five", [_c(8, "S"), _c(8, "S"), _c(8, "S"), _c(8, "S"), _c(8, "S")], 5],
	]
	for test: Array in cases:
		var evaluated: Dictionary = PokerEvaluator.evaluate(test[1])
		_check(evaluated.hand == test[0], "Recognizes " + test[0])
		_check(evaluated.scoring_indices.size() == test[2], test[0] + " only scores contributors")
	var wheel: Array = [_c(14, "S"), _c(2, "H"), _c(3, "D"), _c(4, "C"), _c(5, "S")]
	_check(PokerEvaluator.evaluate(wheel).hand == "Straight", "Ace can be low in a wheel")
	_check(PokerEvaluator.evaluate([_c(12, "S"), _c(13, "H"), _c(14, "D"), _c(2, "C"), _c(3, "S")]).hand == "High Card", "Straights cannot wrap through Ace")
	var wild_flush: Array = [_c(2, "H"), _c(5, "H"), _c(7, "H"), _c(9, "H"), _c(11, "S", "wild")]
	_check(PokerEvaluator.evaluate(wild_flush).hand == "Flush", "Wild card completes Flush")
	_check(PokerEvaluator.evaluate(wild_flush, {"debuff_suit": "D"}).hand == "High Card", "Suit debuff removes Wild any-suit ability")
	_check(PokerEvaluator.evaluate(wild_flush, {"debuff_faces": true}).hand == "High Card", "Face debuff removes Wild ability on Jack")
	wild_flush[4].suit = "H"
	_check(PokerEvaluator.evaluate(wild_flush, {"debuff_suit": "H"}).hand == "Flush", "Debuffed Wild retains printed suit for hand recognition")
	var stone_pair: Array = [_c(6, "S"), _c(6, "H"), _c(14, "D", "stone")]
	_check(PokerEvaluator.evaluate(stone_pair).hand == "Pair", "Stone does not supply rank")
	_check(PokerEvaluator.evaluate(stone_pair).scoring_indices == [0, 1, 2], "Stone is included after hand recognition")
	_check(PokerEvaluator.evaluate([_c(14, "H", "stone")]).hand == "High Card", "Stone-only hand is High Card")
	_check(PokerEvaluator.evaluate([]).scoring_indices.is_empty(), "Empty hand has no scoring cards")

func _test_scoring_pipeline() -> void:
	var plain: Array = [_c(10, "S")]
	var result: Dictionary = _score(plain)
	_check(result.chips == 15 and result.mult == 1 and result.total == 15, "High Card: (5 + 10) × 1")
	result = _score([_c(14, "H")])
	_check(result.chips == 16, "Ace gives 11 chips")
	result = _score([_c(12, "H")])
	_check(result.chips == 15, "Face cards give 10 chips")
	result = _score([_c(8, "S"), _c(8, "H"), _c(14, "D")])
	_check(result.total == 52, "Pair excludes Ace kicker")
	result = ScoreEngine.score(plain, [], [], {"High Card": 3}, {})
	_check(result.chips == 35 and result.mult == 3, "Planet hand levels apply before cards")
	var ordered: Dictionary = _score(plain, [], ["jester", "amplifier"])
	var reversed: Dictionary = _score(plain, [], ["amplifier", "jester"])
	_check(ordered.total == 150 and reversed.total == 90, "Joker array order changes +Mult/×Mult result")
	result = _score([_c(10, "H", "bonus")])
	_check(result.chips == 45, "Bonus adds 30 chips")
	result = _score([_c(10, "H", "mult")])
	_check(result.mult == 5, "Mult enhancement adds 4")
	result = _score([_c(10, "H", "glass")], [], ["jester"])
	_check(result.mult == 6, "Glass doubles Mult before flat Joker addition")
	result = _score(plain, [_c(2, "D", "steel")], ["jester"])
	_check(result.mult == 5.5, "Held Steel triggers before Jokers")
	result = _score([_c(10, "S", "steel")])
	_check(result.mult == 1, "Played Steel does not trigger held ability")
	result = _score([_c(10, "S", "stone")])
	_check(result.chips == 55, "Stone replaces rank chips with 50")
	result = _score([_c(10, "S", "", "foil")])
	_check(result.chips == 65, "Foil adds 50 chips")
	result = _score([_c(10, "S", "", "holographic")])
	_check(result.mult == 11, "Holographic adds 10 Mult")
	result = _score([_c(10, "S", "", "polychrome")])
	_check(result.mult == 1.5, "Polychrome multiplies by 1.5")
	result = _score([_c(10, "H", "mult", "", "red")], [], ["heartline"])
	_check(result.chips == 25 and result.mult == 15, "Red Seal repeats card chips, enhancement and per-card Joker")
	result = _score(plain, [_c(2, "D", "steel", "", "red")])
	_check(result.mult == 2.25, "Held red-sealed Steel triggers twice")
	result = _score([_c(10, "H", "", "", "gold")])
	_check(result.cash == 3, "Scored Gold Seal earns money")
	result = _score([_c(10, "H", "mult")], [], ["heartline"], {"debuff_suit": "H"})
	_check(result.total == 5, "Suit debuff disables card and associated triggers")
	result = _score([_c(12, "C")], [], [], {"debuff_faces": true})
	_check(result.chips == 5, "Face debuff blocks face chip value")
	result = _score([_c(10, "S", "wild")], [], ["heartline"], {"debuff_suit": "H"})
	_check(result.total == 5, "Wild cards are debuffed by any suit boss")
	result = _score([_c(10, "H", "stone")], [], [], {"debuff_suit": "H"})
	_check(result.chips == 55, "Stone ignores suit debuff")
	result = _score(plain, [], [], {"half_base": true})
	_check(result.chips == 13 and result.mult == 1, "Flint halves base only, rounding upward")
	result = ScoreEngine.score([], [], [], {}, {})
	_check(result.total == 0 and result.events.is_empty(), "Empty hand cannot score")
	result = _score(plain, [], ["jester", "amplifier"])
	_check(result.events[-1].chips == result.chips and result.events[-1].mult == result.mult, "Cascade snapshots match final score")

func _test_randomness_and_preview() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 98765
	rng_b.seed = 98765
	var luck: Array = [_c(10, "S", "lucky"), _c(10, "H", "glass")]
	for _iteration: int in range(12):
		var first: Dictionary = ScoreEngine.score(luck, [], [], {}, {}, rng_a)
		var second: Dictionary = ScoreEngine.score(luck, [], [], {}, {}, rng_b)
		_check(first == second, "Identical RNG seeds produce identical score outcomes")
	var saved_state: int = rng_a.state
	var card: Dictionary = _c(14, "H", "glass", "", "gold")
	var input_before: Dictionary = card.duplicate(true)
	var preview: Dictionary = ScoreEngine.score([card, _c(14, "S", "lucky")], [], [{"id": "payday"}], {}, {"preview": true}, rng_a)
	_check(rng_a.state == saved_state, "Preview leaves RNG state untouched")
	_check(preview.cash == 0 and preview.destroyed_ids.is_empty(), "Preview cannot grant cash or destroy cards")
	_check(card == input_before, "Scoring never mutates card dictionaries")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 451
	var shattered: bool = false
	var lucky_mult: bool = false
	var lucky_cash: bool = false
	for _iteration: int in range(200):
		var glass: Dictionary = ScoreEngine.score([_c(10, "S", "glass")], [], [], {}, {}, rng)
		shattered = shattered or not glass.destroyed_ids.is_empty()
		var lucky: Dictionary = ScoreEngine.score([_c(10, "S", "lucky")], [], [], {}, {}, rng)
		lucky_mult = lucky_mult or lucky.mult > 1.0
		lucky_cash = lucky_cash or lucky.cash > 0
	_check(shattered and lucky_mult and lucky_cash, "Seeded sequence exercises glass and both lucky outcomes")

func _test_catalog_and_jokers() -> void:
	var ids: Dictionary = {}
	for joker: JokerData in GameCatalog.jokers():
		_check(not ids.has(joker.id), "Unique Joker ID: " + joker.id)
		ids[joker.id] = true
		_check(not joker.description.is_empty() and joker.price > 0, "Joker has authored metadata: " + joker.id)
	_check(ids.size() >= 30, "At least 30 Joker resources")
	_check(GameCatalog.joker("missing") == null, "Unknown Joker ID is safe")
	var planets: int = 0
	var planet_hands: Dictionary = {}
	for item: Dictionary in GameCatalog.consumables():
		if item.kind == "planet":
			planets += 1
			planet_hands[item.target] = true
	_check(planets == 12 and planet_hands.size() == 12, "Exactly one Planet for each hand type")
	_check(GameCatalog.consumable("planet_x").target == "Five of a Kind", "Planet X stable external ID")
	_check(GameCatalog.vouchers().size() == 8, "Eight usable vouchers")
	_check(_score([_c(14, "H")], [], ["fibonacci"]).mult == 9, "Fibonacci includes Ace")
	_check(_score([_c(10, "H")], [], ["even_steven"]).mult == 5, "Even Steven triggers even ranks")
	_check(_score([_c(14, "H")], [], ["odd_todd"]).chips == 47, "Odd Todd includes Ace")
	_check(_score([_c(11, "H")], [], ["smiley"]).mult == 6, "Smiley triggers face ranks")
	_check(_score([_c(2, "H")], [], ["tiny_dancer"]).mult == 1.2, "Tiny Dancer multiplies small ranks")
	_check(_score([_c(10, "H")], [], ["bankroll"], {"money": 24}).mult == 5, "Bankroll rounds down money stacks")
	_check(_score([_c(10, "H")], [], ["leftover"], {"hands_left": 2}).chips == 45, "Leftover counts remaining hands")
	_check(_score([_c(10, "H")], [], ["blue_reserve"], {"discards_left": 3}).mult == 7, "Blue Reserve counts discards")
	_check(_score([_c(10, "H")], [], ["ritual"], {"tarots_used": 7}).mult == 8, "Ritual scales across run")
	_check(_score([_c(10, "H")], [], ["echo"], {"hand_counts": {"High Card": 4}}).mult == 9, "Echo uses previous hand counts")
	_check(_score([_c(10, "H")], [], ["constellation"], {"planets_used": 5}).mult == 1.5, "Constellation scales with Planets")
	_check(_score([_c(10, "H")], [_c(13, "D"), _c(13, "C")], ["royal_court"]).mult == 2.25, "Royal Court triggers each held King")
	_check(_score([_c(10, "H")], [_c(3, "D"), _c(14, "C")], ["stargazer"]).mult == 7, "Stargazer uses lowest held chip value")
	_check(_score([_c(10, "H")], [], ["recycler"], {"discards_used": 4}).chips == 47, "Recycler uses total run discards")
	_check(_score([_c(10, "H")], [], ["boss_breaker"], {"boss": "club"}).mult == 2, "Boss Breaker checks active boss")
	_check(_score([_c(10, "H")], [], ["payday"]).cash == 1, "Payday rewards each played hand")
	_check(_score([_c(10, "H")], [], ["payday", "bankroll"], {"money": 4}).mult == 2, "Bankroll sees cash awarded by earlier Joker")
	_check(_score([_c(10, "H")], [], ["bankroll", "payday"], {"money": 4}).mult == 1, "Later cash does not retroactively improve Bankroll")
	_check(_score([_c(10, "H", "", "", "gold")], [], ["bankroll"], {"money": 2}).mult == 2, "Gold Seal cash feeds Bankroll in same cascade")
	var edition_score: Dictionary = ScoreEngine.score([_c(10, "H")], [], [{"id": "jester", "edition": "polychrome"}], {}, {})
	_check(edition_score.mult == 7.5, "Joker Polychrome applies after its +Mult ability")
	var nonface_stone: Dictionary = _score([_c(13, "H", "stone")], [], ["smiley"])
	_check(nonface_stone.mult == 1, "Stone cannot count as a face card for Jokers")

func _score(played: Array, held: Array = [], joker_ids: Array = [], context: Dictionary = {}) -> Dictionary:
	var owned: Array = []
	for id: String in joker_ids:
		owned.append({"id": id, "edition": "", "counter": 0.0})
	return ScoreEngine.score(played, held, owned, {}, context)

func _c(rank: int, suit: String, enhancement: String = "", edition: String = "", seal: String = "") -> Dictionary:
	return {"id": "%s%d" % [suit, rank], "rank": rank, "suit": suit,
		"enhancement": enhancement, "edition": edition, "seal": seal}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
