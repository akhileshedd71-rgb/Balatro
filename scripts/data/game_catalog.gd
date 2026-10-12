class_name GameCatalog
extends RefCounted
## Authored Joker Resources and immutable consumable/voucher definitions.

const JOKER_RESOURCES: Array = [
	preload("res://resources/jokers/jester.tres"),
	preload("res://resources/jokers/chip_stack.tres"),
	preload("res://resources/jokers/amplifier.tres"),
	preload("res://resources/jokers/heartline.tres"),
	preload("res://resources/jokers/diamond_mine.tres"),
	preload("res://resources/jokers/clubhouse.tres"),
	preload("res://resources/jokers/spade_castle.tres"),
	preload("res://resources/jokers/fibonacci.tres"),
	preload("res://resources/jokers/scholar.tres"),
	preload("res://resources/jokers/even_steven.tres"),
	preload("res://resources/jokers/odd_todd.tres"),
	preload("res://resources/jokers/smiley.tres"),
	preload("res://resources/jokers/tiny_dancer.tres"),
	preload("res://resources/jokers/pair_program.tres"),
	preload("res://resources/jokers/triplicate.tres"),
	preload("res://resources/jokers/square_deal.tres"),
	preload("res://resources/jokers/flush_hour.tres"),
	preload("res://resources/jokers/straight_shooter.tres"),
	preload("res://resources/jokers/lone_wolf.tres"),
	preload("res://resources/jokers/clean_slate.tres"),
	preload("res://resources/jokers/last_call.tres"),
	preload("res://resources/jokers/bankroll.tres"),
	preload("res://resources/jokers/leftover.tres"),
	preload("res://resources/jokers/blue_reserve.tres"),
	preload("res://resources/jokers/stargazer.tres"),
	preload("res://resources/jokers/ritual.tres"),
	preload("res://resources/jokers/echo.tres"),
	preload("res://resources/jokers/minimalist.tres"),
	preload("res://resources/jokers/steelworks.tres"),
	preload("res://resources/jokers/royal_court.tres"),
	preload("res://resources/jokers/stone_mason.tres"),
	preload("res://resources/jokers/glassworks.tres"),
	preload("res://resources/jokers/constellation.tres"),
	preload("res://resources/jokers/boss_breaker.tres"),
	preload("res://resources/jokers/lucky_star.tres"),
	preload("res://resources/jokers/payday.tres"),
	preload("res://resources/jokers/recycler.tres"),
 ]

static func jokers() -> Array:
	return JOKER_RESOURCES.duplicate()

static func joker(id: String) -> JokerData:
	if id == "joker":
		id = "jester"
	for data: JokerData in JOKER_RESOURCES:
		if data.id == id:
			return data
	return null

static func consumables() -> Array:
	var result: Array = []
	var planets: Array = [
		["pluto", "Pluto", "High Card"], ["mercury", "Mercury", "Pair"],
		["uranus", "Uranus", "Two Pair"], ["venus", "Venus", "Three of a Kind"],
		["saturn", "Saturn", "Straight"], ["jupiter", "Jupiter", "Flush"],
		["earth", "Earth", "Full House"], ["mars", "Mars", "Four of a Kind"],
		["neptune", "Neptune", "Straight Flush"], ["planet_x", "Planet X", "Five of a Kind"],
		["ceres", "Ceres", "Flush House"], ["eris", "Eris", "Flush Five"],
	]
	for planet: Array in planets:
		var hand: Dictionary = PokerEvaluator.HANDS[planet[2]]
		result.append(_item(("planet_x" if planet[0] == "planet_x" else "planet_" + planet[0]), planet[1], "planet", 3, "level_hand", 1, planet[2],
			"Level up %s: +%d Chips, +%s Mult." % [planet[2], hand.chip_growth, str(hand.mult_growth)], Color("8dbbea")))
	var enhancements: Array = [
		["bonus", "The Hierophant", "+30 Chips when scored."],
		["mult", "The Empress", "+4 Mult when scored."],
		["wild", "The Lovers", "Counts as any suit."],
		["glass", "Justice", "×2 Mult; 1 in 4 chance to shatter."],
		["steel", "The Chariot", "×1.5 Mult while held in hand."],
		["lucky", "The Magician", "1 in 5 for +20 Mult; 1 in 15 for $20."],
		["stone", "The Tower", "+50 Chips; no rank or suit; always scores."],
	]
	for enhancement: Array in enhancements:
		result.append(_item("tarot_" + enhancement[0], enhancement[1], "tarot", 3, "enhance", 2, enhancement[0],
			"Enhance up to 2 selected cards. " + enhancement[2], Color("d5ab72")))
	var suits: Array = [["spades", "The World", "S"], ["hearts", "The Sun", "H"],
		["clubs", "The Moon", "C"], ["diamonds", "The Star", "D"]]
	for suit: Array in suits:
		result.append(_item("tarot_" + suit[0], suit[1], "tarot", 3, "suit", 2, suit[2],
			"Convert up to 2 selected cards to " + suit[0] + ".", Color("d5ab72")))
	result.append(_item("tarot_strength", "Strength", "tarot", 3, "rank_up", 1, "", "Raise up to 2 selected cards by one rank. Aces wrap to 2.", Color("d5ab72")))
	result.append(_item("tarot_hanged_man", "The Hanged Man", "tarot", 3, "destroy", 2, "", "Destroy up to 2 selected cards.", Color("d5ab72")))
	result.append(_item("tarot_death", "Death", "tarot", 4, "copy", 1, "", "Copy the first selected card onto the second selected card.", Color("d5ab72")))
	result.append(_item("tarot_hermit", "The Hermit", "tarot", 3, "money", 20, "", "Double your money, gaining up to $20.", Color("d5ab72")))
	result.append(_item("spectral_aura", "Aura", "spectral", 5, "edition", 1, "polychrome", "Give one selected card Polychrome: ×1.5 Mult when scored.", Color("bda0df")))
	result.append(_item("spectral_deja_vu", "Deja Vu", "spectral", 5, "seal", 1, "red", "Give one selected card a Red Seal. It triggers twice.", Color("bda0df")))
	result.append(_item("spectral_ankh", "Ankh", "spectral", 6, "duplicate_joker", 1, "", "Copy a random Joker, destroying all others. Requires an open Joker slot.", Color("bda0df")))
	result.append(_item("spectral_ouija", "Ouija", "spectral", 8, "all_rank", 14, "", "Convert your held cards to Aces. Hand size decreases by 1.", Color("bda0df")))
	return result

static func consumable(id: String) -> Dictionary:
	for item: Dictionary in consumables():
		if item.id == id:
			return item
	return {}

static func vouchers() -> Array:
	return [
		_voucher("voucher_grabber", "Grabber", "One extra hand every blind.", "hands", 1),
		_voucher("voucher_wasteful", "Wasteful", "One extra discard every blind.", "discards", 1),
		_voucher("voucher_paintbrush", "Paintbrush", "Increase your hand size by 1.", "hand_size", 1),
		_voucher("voucher_antimatter", "Antimatter", "One additional Joker slot.", "joker_slots", 1),
		_voucher("voucher_crystal", "Crystal Ball", "One additional consumable slot.", "consumable_slots", 1),
		_voucher("voucher_clearance", "Clearance", "Shop prices reduced by 25%.", "discount", 0.25),
		_voucher("voucher_omen", "Omen Globe", "Improves the chance of rare Jokers in shops.", "rare_chance", 0.15),
		_voucher("voucher_reroll", "Reroll Surplus", "Shop rerolls cost $2 less (minimum $1).", "reroll_discount", 2),
	]

static func voucher(id: String) -> Dictionary:
	for item: Dictionary in vouchers():
		if item.id == id:
			return item
	return {}

static func _item(id: String, title: String, kind: String, price: int, effect: String,
		amount: float, target: String, description: String, accent: Color) -> Dictionary:
	return {"id": id, "title": title, "kind": kind, "price": price, "effect": effect,
		"amount": amount, "target": target, "description": description, "accent": accent}

static func _voucher(id: String, title: String, description: String, effect: String, amount: float) -> Dictionary:
	return {"id": id, "title": title, "description": description, "price": 10,
		"kind": "voucher", "effect": effect, "amount": amount, "accent": Color("e4bf77")}
