class_name RunController
extends Node
## Run state owner. UI observes signals; scoring and economy are independent services.

signal changed
signal scored(result: Dictionary)
signal phase_changed(phase: String)
signal notice(message: String)

@export var save_path: String = "user://run_save.json"
const ANTE_TARGETS: Array[int] = [300, 800, 2000, 5000, 11000, 20000, 35000, 50000]
const BOSS_IDS: Array[String] = ["heart", "drought", "needle", "mask", "echo", "pocket", "wall", "crown"]
const BOSS_NAMES: Array[String] = ["The Heart", "The Drought", "The Needle", "The Mask", "The Echo", "The Pocket", "The Wall", "The Crown"]
const BOSS_DESCRIPTIONS: Array[String] = [
	"Hearts are debuffed: they contribute no card chips or enhancements.",
	"No discards this blind. Make every hand count.",
	"Play at most 3 cards per hand.",
	"Face cards are debuffed: Jacks, Queens, and Kings do not score.",
	"Only your first poker hand type scores. Other types cost a hand and score 0.",
	"Hand size is reduced to 6 for this blind.",
	"The target score is doubled.",
	"A final challenge: the target score is 50% higher.",
]

var phase: String = "blind"
var seed_text: String = ""
var ante: int = 1
var blind_index: int = 0
var round_number: int = 0
var money: int = 4
var hands_left: int = 4
var discards_left: int = 3
var round_score: int = 0
var target_score: int = 300
var hand: Array = []
var draw_pile: Array = []
var deck: Array = []
var jokers: Array = []
var consumables: Array = []
var levels: Dictionary = {}
var shop_items: Array = []
var reroll_cost: int = 5
var deck_id: String = "red"
var stake: int = 0
var challenge_id: String = ""
var last_result: Dictionary = {}
var wins: int = 0
var joker_slots: int = 5
var consumable_slots: int = 2
var hand_size: int = 8
var base_hands: int = 4
var base_discards: int = 3
var vouchers: Array = []
var discount: float = 0.0
var rare_bonus: float = 0.0
var reroll_discount: int = 0
var tarots_used: int = 0
var planets_used: int = 0
var discards_used: int = 0
var hand_counts: Dictionary = {}
var last_hand: String = ""
var boss_hand_lock: String = ""
var next_card_id: int = 52
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func new_run(run_seed: String = "", deck_type: String = "red", difficulty: int = 0, challenge: String = "") -> void:
	seed_text = run_seed.strip_edges().to_upper().substr(0, 32)
	if seed_text.is_empty():
		seed_text = "%08X" % (Time.get_unix_time_from_system() as int ^ Time.get_ticks_usec())
	rng.seed = seed_text.hash()
	deck_id = deck_type if deck_type in ["red", "blue", "gold"] else "red"
	stake = clampi(difficulty, 0, 2)
	challenge_id = challenge if challenge in ["pair_only", "no_discards", "short_stack"] else ""
	ante = 1
	blind_index = 0
	round_number = 0
	money = 10 if deck_id == "gold" else 4
	base_hands = 5 if deck_id == "blue" else 4
	base_discards = 4 if deck_id == "red" else 3
	hand_size = 6 if challenge_id == "short_stack" else 8
	if challenge_id == "short_stack":
		money = 0
	joker_slots = 5
	consumable_slots = 2
	discount = 0.0
	rare_bonus = 0.0
	reroll_discount = 0
	tarots_used = 0
	planets_used = 0
	discards_used = 0
	hand_counts = {}
	last_hand = ""
	boss_hand_lock = ""
	levels = {}
	for name: String in PokerEvaluator.HANDS:
		levels[name] = 1
	jokers = [{"id": "jester", "edition": "", "counter": 0.0}]
	consumables = []
	shop_items = []
	vouchers = []
	last_result = {}
	hand = []
	draw_pile = []
	deck = []
	for suit: String in ["S", "H", "D", "C"]:
		for rank: int in range(2, 15):
			deck.append({"id": str(deck.size()), "rank": rank, "suit": suit, "enhancement": "", "edition": "", "seal": ""})
	next_card_id = 52
	_update_target()
	round_score = 0
	hands_left = base_hands
	discards_left = base_discards
	_set_phase("blind")
	_commit()

func start_blind() -> void:
	if phase != "blind":
		return
	_update_target()
	round_score = 0
	hands_left = base_hands
	discards_left = 0 if challenge_id == "no_discards" or _boss() == "drought" else base_discards
	boss_hand_lock = ""
	last_result = {}
	round_number += 1
	hand = []
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	draw_to_hand()
	_set_phase("playing")
	_commit()

func play_cards(indices: Array) -> Dictionary:
	if phase != "playing" or hands_left <= 0:
		return _error("Start a blind before playing a hand.")
	if not _valid_indices(indices, 1, max_played_cards()):
		return _error("Select 1–%d cards to play." % max_played_cards())
	var played: Array = _selected(indices)
	var hand_name: String = str(PokerEvaluator.evaluate(played, get_context()).hand)
	var restriction: String = _restriction(hand_name)
	var held: Array = []
	for index: int in range(hand.size()):
		if index not in indices:
			held.append(hand[index])
	hands_left -= 1
	var result: Dictionary = ScoreEngine.score(played, held, jokers, levels, get_context(), rng) if restriction.is_empty() else _blocked_result(hand_name, restriction)
	if not restriction.is_empty():
		notice.emit(restriction + " One hand spent; 0 scored.")
	hand = held
	remove_card_ids(result.get("destroyed_ids", []))
	money += int(result.get("cash", 0))
	round_score += int(result.total)
	last_hand = hand_name
	hand_counts[hand_name] = int(hand_counts.get(hand_name, 0)) + 1
	if _boss() == "echo" and boss_hand_lock.is_empty():
		boss_hand_lock = hand_name
	last_result = result
	if round_score >= target_score:
		_finish_blind()
	elif hands_left <= 0 or (hand.is_empty() and draw_pile.is_empty()):
		_set_phase("lost")
	else:
		draw_to_hand()
	scored.emit(result)
	_commit()
	return result

func discard_cards(indices: Array) -> bool:
	if phase != "playing" or discards_left <= 0 or not _valid_indices(indices, 1, 5):
		notice.emit("Select 1–5 cards and make sure you have a discard left.")
		return false
	var ordered: Array = indices.duplicate()
	ordered.sort()
	ordered.reverse()
	for index: int in ordered:
		hand.remove_at(index)
	discards_left -= 1
	discards_used += 1
	draw_to_hand()
	if hand.is_empty():
		_set_phase("lost")
	_commit()
	return true

func sort_hand(by_suit: bool = false) -> void:
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if by_suit and a.suit != b.suit:
			return ["S", "H", "C", "D"].find(a.suit) < ["S", "H", "C", "D"].find(b.suit)
		if a.rank == b.rank:
			return str(a.suit) < str(b.suit)
		return int(a.rank) > int(b.rank)
	)
	_commit()

func preview(indices: Array) -> Dictionary:
	if not _valid_indices(indices, 1, 5):
		return {}
	var held: Array = []
	for index: int in range(hand.size()):
		if index not in indices:
			held.append(hand[index])
	var preview_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	preview_rng.seed = rng.seed
	preview_rng.state = rng.state
	var context: Dictionary = get_context()
	context.hands_left = maxi(0, hands_left - 1)
	var played: Array = _selected(indices)
	var hand_name: String = str(PokerEvaluator.evaluate(played, context).hand)
	var restriction: String = _restriction(hand_name)
	if not restriction.is_empty():
		return _blocked_result(hand_name, restriction)
	return ScoreEngine.score(played, held, jokers, levels, context, preview_rng)

func buy_item(index: int) -> bool:
	if phase != "shop" or index < 0 or index >= shop_items.size():
		return false
	var offer: Dictionary = shop_items[index]
	if bool(offer.sold) or money < int(offer.price):
		notice.emit("Not enough cash." if not bool(offer.sold) else "Already purchased.")
		return false
	var paid_price: int = int(offer.price)
	match str(offer.type):
		"joker":
			if jokers.size() >= joker_slots:
				notice.emit("Your Joker slots are full. Sell one to make space.")
				return false
			jokers.append({"id": str(offer.id), "edition": "", "counter": 0.0})
		"consumable":
			if consumables.size() >= consumable_slots:
				notice.emit("Your consumable slots are full.")
				return false
			consumables.append({"id": str(offer.id)})
		"voucher":
			_apply_voucher(RunEconomy.voucher(str(offer.id)))
		_:
			return false
	money -= paid_price
	offer.sold = true
	if str(offer.type) == "voucher":
		RunEconomy.refresh_prices(shop_items, discount)
	_commit()
	return true

func reroll_shop() -> bool:
	if phase != "shop" or money < reroll_cost:
		notice.emit("Not enough cash to reroll.")
		return false
	money -= reroll_cost
	reroll_cost += 1
	shop_items = RunEconomy.make_shop(rng, vouchers, discount, rare_bonus)
	_commit()
	return true

func leave_shop() -> void:
	if phase != "shop":
		return
	blind_index += 1
	if blind_index == 3:
		ante += 1
		blind_index = 0
	shop_items = []
	_update_target()
	_set_phase("blind")
	_commit()

func sell_joker(index: int) -> bool:
	if phase in ["won", "lost"] or index < 0 or index >= jokers.size():
		return false
	var item: Resource = GameCatalog.joker(str(jokers[index].id))
	money += maxi(1, int(item.price) / 2)
	jokers.remove_at(index)
	_commit()
	return true

func move_joker(from: int, to: int) -> void:
	if from < 0 or from >= jokers.size() or to < 0 or to >= jokers.size() or from == to:
		return
	var moved: Dictionary = jokers.pop_at(from)
	jokers.insert(to, moved)
	_commit()

func use_consumable(index: int, selected_indices: Array = []) -> bool:
	if phase in ["won", "lost"] or index < 0 or index >= consumables.size():
		return false
	if not selected_indices.is_empty() and not _valid_indices(selected_indices, 1, 5):
		return false
	var item: Dictionary = GameCatalog.consumable(str(consumables[index].id))
	if not RunConsumables.apply(self, item, selected_indices):
		return false
	consumables.remove_at(index)
	notice.emit("%s used." % str(item.title))
	if phase == "playing" and hand.is_empty():
		_set_phase("lost")
	_commit()
	return true

func sell_consumable(index: int) -> void:
	if phase in ["won", "lost"] or index < 0 or index >= consumables.size():
		return
	var item: Dictionary = GameCatalog.consumable(str(consumables[index].id))
	money += maxi(1, int(item.price) / 2)
	consumables.remove_at(index)
	_commit()

func blind_name() -> String:
	return ["Small Blind", "Big Blind", BOSS_NAMES[clampi(ante - 1, 0, 7)]][blind_index]

func boss_description() -> String:
	return BOSS_DESCRIPTIONS[clampi(ante - 1, 0, 7)] if blind_index == 2 else "Reach the target before your hands run out."

func max_played_cards() -> int:
	return 3 if _boss() == "needle" else 5

func get_context() -> Dictionary:
	return {"ante": ante, "blind_index": blind_index, "boss": _boss(), "hand_size": _effective_hand_size(), "hands_left": hands_left, "discards_left": discards_left, "money": money, "round_number": round_number, "tarots_used": tarots_used, "planets_used": planets_used, "discards_used": discards_used, "hand_counts": hand_counts, "last_hand": last_hand, "deck_size": deck.size(), "debuff_suit": "H" if _boss() == "heart" else "", "debuff_faces": _boss() == "mask"}

func save_run() -> bool:
	return RunPersistence.write(save_path, RunPersistence.capture(self, rng))

func load_run() -> bool:
	var data: Dictionary = RunPersistence.read(save_path)
	if data.is_empty():
		return false
	RunPersistence.restore(self, rng, data)
	phase_changed.emit(phase)
	changed.emit()
	return true

func has_save() -> bool:
	return not RunPersistence.read(save_path).is_empty()

func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func draw_to_hand() -> void:
	while hand.size() < _effective_hand_size() and not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())

func remove_card_ids(ids: Array) -> void:
	for cards: Array in [deck, hand, draw_pile]:
		for index: int in range(cards.size() - 1, -1, -1):
			if cards[index].id in ids:
				cards.remove_at(index)

func _finish_blind() -> void:
	var reward: int = 3 + blind_index + hands_left + mini(5, maxi(money, 0) / 5)
	money += reward
	last_result.reward = reward
	if ante == 8 and blind_index == 2:
		wins += 1
		_set_phase("won")
		return
	hand = []
	draw_pile = []
	reroll_cost = maxi(1, 5 - reroll_discount)
	shop_items = RunEconomy.make_shop(rng, vouchers, discount, rare_bonus)
	_set_phase("shop")

func _apply_voucher(item: Dictionary) -> void:
	vouchers.append(str(item.id))
	var amount: int = int(item.amount)
	match str(item.effect):
		"hands": base_hands += amount
		"discards": base_discards += amount
		"hand_size": hand_size += amount
		"joker_slots": joker_slots += amount
		"consumable_slots": consumable_slots += amount
		"discount": discount = clampf(discount + float(item.amount), 0.0, 0.9)
		"rare_chance": rare_bonus += float(item.amount)
		"reroll_discount":
			reroll_discount += amount
			reroll_cost = maxi(1, reroll_cost - amount)

func _boss() -> String:
	return BOSS_IDS[clampi(ante - 1, 0, 7)] if blind_index == 2 else ""

func _effective_hand_size() -> int:
	return mini(hand_size, 6) if _boss() == "pocket" else hand_size

func _update_target() -> void:
	var blind_factor: float = [1.0, 1.5, 2.0][blind_index]
	var stake_factor: float = [1.0, 1.25, 1.6][stake]
	var boss_factor: float = 2.0 if _boss() == "wall" else (1.5 if _boss() == "crown" else 1.0)
	target_score = int(ceil(ANTE_TARGETS[clampi(ante - 1, 0, 7)] * blind_factor * stake_factor * boss_factor))

func _shuffle(cards: Array) -> void:
	for index: int in range(cards.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var swap: Variant = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = swap

func _valid_indices(indices: Array, minimum: int, maximum: int) -> bool:
	if indices.size() < minimum or indices.size() > maximum:
		return false
	var seen: Dictionary = {}
	for value: Variant in indices:
		if not value is int or int(value) < 0 or int(value) >= hand.size() or seen.has(value):
			return false
		seen[value] = true
	return true

func _selected(indices: Array) -> Array:
	var cards: Array = []
	# Physical left-to-right hand order is scoring order, regardless of tap order.
	for index: int in range(hand.size()):
		if index in indices:
			cards.append(hand[index])
	return cards

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_changed.emit(phase)

func _commit() -> void:
	if not save_run():
		notice.emit("Your device could not save this run.")
	changed.emit()

func _error(message: String) -> Dictionary:
	notice.emit(message)
	return {"error": message}

func _restriction(hand_name: String) -> String:
	if challenge_id == "pair_only" and hand_name not in ["Pair", "Two Pair"]:
		return "This challenge only scores Pair or Two Pair."
	if not boss_hand_lock.is_empty() and hand_name != boss_hand_lock:
		return "The Echo only scores %s." % boss_hand_lock
	return ""

func _blocked_result(hand_name: String, reason: String) -> Dictionary:
	return {"hand": hand_name, "chips": 0, "mult": 0.0, "total": 0, "events": [{"label": reason, "chips": 0, "mult": 0.0, "kind": "debuff"}], "destroyed_ids": [], "cash": 0, "scoring_indices": [], "blocked_reason": reason}
