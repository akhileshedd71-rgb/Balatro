class_name PokerEvaluator
extends RefCounted
## Pure hand recognition. Stone cards always score, but do not form poker hands.

const HANDS: Dictionary = {
	"High Card": {"base_chips": 5, "base_mult": 1.0, "chip_growth": 10, "mult_growth": 1.0},
	"Pair": {"base_chips": 10, "base_mult": 2.0, "chip_growth": 15, "mult_growth": 1.0},
	"Two Pair": {"base_chips": 20, "base_mult": 2.0, "chip_growth": 20, "mult_growth": 1.0},
	"Three of a Kind": {"base_chips": 30, "base_mult": 3.0, "chip_growth": 20, "mult_growth": 2.0},
	"Straight": {"base_chips": 30, "base_mult": 4.0, "chip_growth": 30, "mult_growth": 3.0},
	"Flush": {"base_chips": 35, "base_mult": 4.0, "chip_growth": 15, "mult_growth": 2.0},
	"Full House": {"base_chips": 40, "base_mult": 4.0, "chip_growth": 25, "mult_growth": 2.0},
	"Four of a Kind": {"base_chips": 60, "base_mult": 7.0, "chip_growth": 30, "mult_growth": 3.0},
	"Straight Flush": {"base_chips": 100, "base_mult": 8.0, "chip_growth": 40, "mult_growth": 4.0},
	"Five of a Kind": {"base_chips": 120, "base_mult": 12.0, "chip_growth": 35, "mult_growth": 3.0},
	"Flush House": {"base_chips": 140, "base_mult": 14.0, "chip_growth": 40, "mult_growth": 4.0},
	"Flush Five": {"base_chips": 160, "base_mult": 16.0, "chip_growth": 50, "mult_growth": 3.0},
}

static func evaluate(cards: Array, context: Dictionary = {}) -> Dictionary:
	var ranks: Dictionary = {}
	var normal: Array = []
	var stones: Array = []
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		if card.get("enhancement", "") == "stone":
			stones.append(index)
			continue
		normal.append(index)
		var rank: int = int(card.get("rank", 2))
		if not ranks.has(rank):
			ranks[rank] = []
		ranks[rank].append(index)
	var groups: Array = ranks.values()
	groups.sort_custom(func(a: Array, b: Array) -> bool:
		if a.size() != b.size():
			return a.size() > b.size()
		return int(cards[a[0]].rank) > int(cards[b[0]].rank))
	var flush: Array = _flush_indices(cards, normal, context)
	var straight: Array = _straight_indices(cards, normal)
	var straight_flush: Array = _straight_indices(cards, flush)
	var largest: int = 0 if groups.is_empty() else groups[0].size()
	var second: int = 0 if groups.size() < 2 else groups[1].size()
	var hand: String = "High Card"
	var scored: Array = []
	if largest >= 5 and flush.size() >= 5:
		hand = "Flush Five"
		scored = groups[0].slice(0, 5)
	elif largest >= 3 and second >= 2 and flush.size() >= 5:
		hand = "Flush House"
		scored = groups[0].slice(0, 3) + groups[1].slice(0, 2)
	elif largest >= 5:
		hand = "Five of a Kind"
		scored = groups[0].slice(0, 5)
	elif straight_flush.size() == 5:
		hand = "Straight Flush"
		scored = straight_flush
	elif largest >= 4:
		hand = "Four of a Kind"
		scored = groups[0].slice(0, 4)
	elif largest >= 3 and second >= 2:
		hand = "Full House"
		scored = groups[0].slice(0, 3) + groups[1].slice(0, 2)
	elif flush.size() >= 5:
		hand = "Flush"
		scored = flush.slice(0, 5)
	elif straight.size() == 5:
		hand = "Straight"
		scored = straight
	elif largest >= 3:
		hand = "Three of a Kind"
		scored = groups[0].slice(0, 3)
	elif largest >= 2 and second >= 2:
		hand = "Two Pair"
		scored = groups[0].slice(0, 2) + groups[1].slice(0, 2)
	elif largest >= 2:
		hand = "Pair"
		scored = groups[0].slice(0, 2)
	elif not normal.is_empty():
		var best: int = normal[0]
		for index: int in normal:
			if int(cards[index].rank) > int(cards[best].rank):
				best = index
		scored = [best]
	scored.append_array(stones)
	scored.sort()
	return {"hand": hand, "scoring_indices": scored,
		"base_chips": HANDS[hand].base_chips, "base_mult": HANDS[hand].base_mult}

static func _flush_indices(cards: Array, indices: Array, context: Dictionary) -> Array:
	for suit: String in ["S", "H", "D", "C"]:
		var matches: Array = []
		for index: int in indices:
			if cards[index].get("suit", "") == suit or _active_wild(cards[index], context):
				matches.append(index)
		if matches.size() >= 5:
			return matches
	return []

static func _straight_indices(cards: Array, indices: Array) -> Array:
	var rank_to_index: Dictionary = {}
	for index: int in indices:
		rank_to_index[int(cards[index].rank)] = index
	if rank_to_index.has(14):
		rank_to_index[1] = rank_to_index[14]
	for high: int in range(14, 4, -1):
		var matches: Array = []
		for rank: int in range(high, high - 5, -1):
			if not rank_to_index.has(rank):
				break
			matches.append(rank_to_index[rank])
		if matches.size() == 5:
			return matches
	return []

static func _active_wild(card: Dictionary, context: Dictionary) -> bool:
	if card.get("enhancement", "") != "wild" or card.get("debuffed", false):
		return false
	if not str(context.get("debuff_suit", "")).is_empty():
		return false
	return not (context.get("debuff_faces", false) and int(card.get("rank", 0)) in [11, 12, 13])
