class_name ScoreEngine
extends RefCounted
## Pure scoring pipeline: base -> played cards -> held cards -> ordered Jokers.
## The actual Mult is mutated immediately, so +Mult and xMult never commute.

static func score(played: Array, held: Array, jokers: Array, levels: Dictionary,
		context: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var evaluated: Dictionary = PokerEvaluator.evaluate(played, context)
	var hand: String = evaluated.hand
	var definition: Dictionary = PokerEvaluator.HANDS[hand]
	var level: int = maxi(1, int(levels.get(hand, 1)))
	var result: Dictionary = {
		"hand": hand, "chips": int(definition.base_chips) + (level - 1) * int(definition.chip_growth),
		"mult": float(definition.base_mult) + (level - 1) * float(definition.mult_growth),
		"total": 0, "events": [], "destroyed_ids": [], "cash": 0,
		"scoring_indices": evaluated.scoring_indices,
	}
	if played.is_empty():
		result.chips = 0
		result.mult = 0.0
		return result
	if context.get("half_base", false) or context.get("boss", "") == "flint":
		result.chips = maxi(1, int(ceil(result.chips / 2.0)))
		result.mult = maxf(1.0, ceil(result.mult / 2.0))
	_event(result, "%s · Lv.%d" % [hand, level], "base")
	for index: int in evaluated.scoring_indices:
		var card: Dictionary = played[index]
		if _debuffed(card, context):
			_event(result, "%s · debuffed" % _card_label(card), "debuff")
			continue
		var repetitions: int = 2 if card.get("seal", "") == "red" else 1
		for trigger: int in range(repetitions):
			_score_card(result, card, context, rng, trigger > 0)
			for owned: Dictionary in jokers:
				var data: JokerData = GameCatalog.joker(str(owned.get("id", "")))
				if data != null and data.effect.begins_with("card_") and _card_matches(card, data.condition):
					_apply(result, data.effect.trim_prefix("card_"), data.amount, data.title)
		if card.get("enhancement", "") == "glass" and not context.get("preview", false) and rng != null:
			if rng.randf() < 0.25:
				result.destroyed_ids.append(card.get("id", ""))
				_event(result, "Glass shattered", "destroy")
	for card: Dictionary in held:
		if card.get("enhancement", "") == "steel" and not _debuffed(card, context):
			var repetitions: int = 2 if card.get("seal", "") == "red" else 1
			for _trigger: int in range(repetitions):
				_apply(result, "xmult", 1.5, "Steel · held")
	for owned: Dictionary in jokers:
		var data: JokerData = GameCatalog.joker(str(owned.get("id", "")))
		if data == null:
			continue
		var edition: String = str(owned.get("edition", ""))
		if edition == "foil":
			_apply(result, "chips", 50.0, "%s · Foil" % data.title)
		elif edition == "holographic":
			_apply(result, "mult", 10.0, "%s · Holographic" % data.title)
		if not data.effect.begins_with("card_") and _hand_matches(data.condition, played, held, hand, context):
			_score_joker(result, data, held, hand, context)
		if edition == "polychrome":
			_apply(result, "xmult", 1.5, "%s · Polychrome" % data.title)
	result.total = int(floor(float(result.chips) * float(result.mult)))
	return result

static func _score_card(result: Dictionary, card: Dictionary, context: Dictionary,
		rng: RandomNumberGenerator, retrigger: bool) -> void:
	var enhancement: String = str(card.get("enhancement", ""))
	var chips: int = 50 if enhancement == "stone" else _rank_chips(int(card.get("rank", 2)))
	if enhancement == "bonus":
		chips += 30
	var label: String = _card_label(card) + (" · again" if retrigger else "")
	_apply(result, "chips", float(chips), label)
	match enhancement:
		"mult":
			_apply(result, "mult", 4.0, "Mult card")
		"glass":
			_apply(result, "xmult", 2.0, "Glass card")
		"lucky":
			if not context.get("preview", false) and rng != null:
				if rng.randf() < 0.2:
					_apply(result, "mult", 20.0, "Lucky!")
				if rng.randf() < 1.0 / 15.0:
					result.cash += 20
					_event(result, "Lucky · +$20", "cash")
	match str(card.get("edition", "")):
		"foil":
			_apply(result, "chips", 50.0, "Foil")
		"holographic":
			_apply(result, "mult", 10.0, "Holographic")
		"polychrome":
			_apply(result, "xmult", 1.5, "Polychrome")
	if card.get("seal", "") == "gold" and not context.get("preview", false):
		result.cash += 3
		_event(result, "Gold seal · +$3", "cash")

static func _score_joker(result: Dictionary, data: JokerData, held: Array,
		hand: String, context: Dictionary) -> void:
	var amount: float = data.amount
	match data.effect:
		"chips", "mult", "xmult":
			_apply(result, data.effect, amount, data.title)
		"chips_per_discard":
			_apply(result, "chips", amount * int(context.get("discards_used", 0)), data.title)
		"mult_per_tarot":
			_apply(result, "mult", amount * int(context.get("tarots_used", 0)), data.title)
		"mult_per_hand":
			var counts: Dictionary = context.get("played_hand_counts", context.get("hand_counts", {}))
			_apply(result, "mult", amount * int(counts.get(hand, 0)), data.title)
		"mult_per_money":
			_apply(result, "mult", floor((float(context.get("money", 0)) + float(result.cash)) / amount), data.title)
		"chips_per_hand_left":
			_apply(result, "chips", amount * int(context.get("hands_left", 0)), data.title)
		"mult_per_discard_left":
			_apply(result, "mult", amount * int(context.get("discards_left", 0)), data.title)
		"xmult_per_planet":
			_apply(result, "xmult", 1.0 + amount * int(context.get("planets_used", 0)), data.title)
		"held_king":
			for card: Dictionary in held:
				if int(card.get("rank", 0)) == 13 and card.get("enhancement", "") != "stone" and not _debuffed(card, context):
					var times: int = 2 if card.get("seal", "") == "red" else 1
					for _repeat: int in range(times):
						_apply(result, "xmult", amount, data.title)
		"held_low":
			var lowest: int = 99
			for card: Dictionary in held:
				if card.get("enhancement", "") != "stone" and not _debuffed(card, context):
					lowest = mini(lowest, _rank_chips(int(card.get("rank", 2))))
			if lowest != 99:
				_apply(result, "mult", lowest * amount, data.title)
		"cash":
			if not context.get("preview", false):
				result.cash += int(amount)
				_event(result, "%s · +$%d" % [data.title, int(amount)], "cash")

static func _apply(result: Dictionary, effect: String, amount: float, title: String) -> void:
	if is_zero_approx(amount) or (effect == "xmult" and is_equal_approx(amount, 1.0)):
		return
	var suffix: String = ""
	match effect:
		"chips":
			result.chips += int(amount)
			suffix = "+%d Chips" % int(amount)
		"mult":
			result.mult += amount
			suffix = "+%s Mult" % _number(amount)
		"xmult":
			result.mult *= amount
			suffix = "×%s Mult" % _number(amount)
	_event(result, "%s · %s" % [title, suffix], effect)

static func _event(result: Dictionary, label: String, kind: String) -> void:
	result.events.append({"label": label, "chips": result.chips, "mult": result.mult, "kind": kind})

static func _card_matches(card: Dictionary, condition: String) -> bool:
	var rank: int = int(card.get("rank", 2))
	var is_stone: bool = card.get("enhancement", "") == "stone"
	if condition in ["S", "H", "D", "C"]:
		return not is_stone and (card.get("suit", "") == condition or card.get("enhancement", "") == "wild")
	match condition:
		"fibonacci": return not is_stone and rank in [2, 3, 5, 8, 14]
		"ace": return not is_stone and rank == 14
		"even": return not is_stone and rank in [2, 4, 6, 8, 10]
		"odd": return not is_stone and rank in [3, 5, 7, 9, 14]
		"face": return not is_stone and rank in [11, 12, 13]
		"small": return not is_stone and rank >= 2 and rank <= 5
		"stone", "glass", "lucky": return card.get("enhancement", "") == condition
	return condition == "always"

static func _hand_matches(condition: String, played: Array, held: Array,
		hand: String, context: Dictionary) -> bool:
	match condition:
		"always": return true
		"pair": return _contains_group(played, 2)
		"triple": return _contains_group(played, 3)
		"four": return _contains_group(played, 4)
		"flush": return hand in ["Flush", "Straight Flush", "Flush House", "Flush Five"]
		"straight": return hand in ["Straight", "Straight Flush"]
		"high_card": return hand == "High Card"
		"no_discards": return int(context.get("discards_left", 0)) == 0
		"last_hand": return int(context.get("hands_left", 0)) == 0
		"small_hand": return played.size() <= 3
		"money20": return int(context.get("money", 0)) >= 20
		"boss": return str(context.get("blind_type", "")) == "boss" or (context.get("boss", "") != "" and context.get("boss", "") != "none")
		"steel_held":
			for card: Dictionary in held:
				if card.get("enhancement", "") == "steel" and not _debuffed(card, context):
					return true
	return false

static func _contains_group(cards: Array, minimum: int) -> bool:
	var counts: Dictionary = {}
	for card: Dictionary in cards:
		if card.get("enhancement", "") == "stone":
			continue
		var rank: int = int(card.get("rank", 2))
		counts[rank] = int(counts.get(rank, 0)) + 1
		if int(counts[rank]) >= minimum:
			return true
	return false

static func _debuffed(card: Dictionary, context: Dictionary) -> bool:
	if card.get("debuffed", false):
		return true
	if card.get("enhancement", "") == "stone":
		return false
	var suit: String = str(context.get("debuff_suit", ""))
	if not suit.is_empty() and (card.get("suit", "") == suit or card.get("enhancement", "") == "wild"):
		return true
	return context.get("debuff_faces", false) and int(card.get("rank", 0)) in [11, 12, 13]

static func _rank_chips(rank: int) -> int:
	return 11 if rank == 14 else mini(rank, 10)

static func _card_label(card: Dictionary) -> String:
	if card.get("enhancement", "") == "stone":
		return "Stone"
	var rank: int = int(card.get("rank", 2))
	var names: Dictionary = {11: "J", 12: "Q", 13: "K", 14: "A"}
	var suits: Dictionary = {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}
	return str(names.get(rank, str(rank))) + str(suits.get(card.get("suit", "S"), ""))

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, round(value)) else ("%.2f" % value).trim_suffix("0")
