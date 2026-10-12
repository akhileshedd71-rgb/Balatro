class_name RunConsumables
extends RefCounted
## Applies consumable data to permanent cards; returns false without spending on invalid targets.

static func apply(run: Node, item: Dictionary, selected: Array) -> bool:
	var effect: String = str(item.get("effect", ""))
	var target: String = str(item.get("target", ""))
	var amount: int = int(item.get("amount", 1))
	match effect:
		"level_hand":
			run.levels[target] = int(run.levels.get(target, 1)) + maxi(1, amount)
			run.planets_used += 1
		"money":
			run.money += mini(maxi(run.money, 0), amount)
		"duplicate_joker":
			if run.jokers.is_empty() or run.jokers.size() >= run.joker_slots:
				return _fail(run, "You need a Joker and an empty Joker slot.")
			var duplicate: Dictionary = run.jokers[run.rng.randi_range(0, run.jokers.size() - 1)].duplicate(true)
			run.jokers = [duplicate.duplicate(true), duplicate]
		"all_rank":
			if run.phase != "playing" or run.hand.is_empty():
				return _fail(run, "Use this Spectral card during a blind.")
			for card: Dictionary in run.hand:
				_change_card(run, card, "rank", amount)
			run.hand_size = maxi(5, run.hand_size - 1)
		"copy":
			if not _targets(run, selected, 2, 2):
				return false
			var source: Dictionary = run.hand[int(selected[0])]
			var destination: Dictionary = run.hand[int(selected[1])]
			for key: String in ["rank", "suit", "enhancement", "edition", "seal"]:
				_change_card(run, destination, key, source[key])
		"destroy":
			if not _targets(run, selected, 1, maxi(1, amount)):
				return false
			var ids: Array = []
			for index: int in selected:
				ids.append(run.hand[index].id)
			run.remove_card_ids(ids)
			run.draw_to_hand()
		"enhance", "suit", "rank_up", "edition", "seal":
			var limit: int = 1 if effect in ["edition", "seal"] else 2
			if not _targets(run, selected, 1, limit):
				return false
			for index: int in selected:
				var card: Dictionary = run.hand[index]
				match effect:
					"enhance": _change_card(run, card, "enhancement", target)
					"suit": _change_card(run, card, "suit", target)
					"rank_up": _change_card(run, card, "rank", 2 + (int(card.rank) - 2 + amount) % 13)
					"edition": _change_card(run, card, "edition", target)
					"seal": _change_card(run, card, "seal", target)
		_:
			return _fail(run, "This consumable cannot be used here.")
	if str(item.get("kind", "")) == "tarot":
		run.tarots_used += 1
	return true

static func _targets(run: Node, selected: Array, minimum: int, maximum: int) -> bool:
	if run.phase != "playing":
		return _fail(run, "Start a blind to select cards for this upgrade.")
	if selected.size() < minimum or selected.size() > maximum:
		return _fail(run, "Select %d%s card%s first." % [minimum, "–%d" % maximum if maximum != minimum else "", "s" if maximum > 1 else ""])
	return true

static func _change_card(run: Node, card: Dictionary, key: String, value: Variant) -> void:
	card[key] = value
	for permanent: Dictionary in run.deck:
		if permanent.id == card.id:
			permanent[key] = value
			return

static func _fail(run: Node, message: String) -> bool:
	run.notice.emit(message)
	return false
