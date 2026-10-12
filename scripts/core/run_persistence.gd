class_name RunPersistence
extends RefCounted
## Plain-data snapshots with exact 64-bit RNG strings and atomic replacement.

const VERSION: int = 1
const FIELDS: Array[String] = [
	"phase", "seed_text", "ante", "blind_index", "round_number", "money",
	"hands_left", "discards_left", "round_score", "target_score", "hand",
	"draw_pile", "deck", "jokers", "consumables", "levels", "shop_items",
	"reroll_cost", "deck_id", "stake", "challenge_id", "last_result", "wins",
	"joker_slots", "consumable_slots", "hand_size", "base_hands", "base_discards",
	"vouchers", "discount", "rare_bonus", "reroll_discount", "tarots_used",
	"hand_counts", "last_hand", "boss_hand_lock", "next_card_id", "planets_used", "discards_used",
]

static func capture(run: Node, rng: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = {"version": VERSION, "rng_seed": str(rng.seed), "rng_state": str(rng.state)}
	for field: String in FIELDS:
		data[field] = run.get(field)
	return data

static func write(path: String, data: Dictionary) -> bool:
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if not _valid(data):
		return {}
	return data

static func _valid(data: Dictionary) -> bool:
	if not _number(data.get("version", null)) or int(data.version) != VERSION:
		return false
	for field: String in FIELDS:
		if not data.has(field):
			return false
	for field: String in ["phase", "seed_text", "deck_id", "challenge_id", "last_hand", "boss_hand_lock"]:
		if not data[field] is String:
			return false
	for field: String in ["ante", "blind_index", "round_number", "money", "hands_left", "discards_left", "round_score", "target_score", "reroll_cost", "stake", "wins", "joker_slots", "consumable_slots", "hand_size", "base_hands", "base_discards", "discount", "rare_bonus", "reroll_discount", "tarots_used", "next_card_id", "planets_used", "discards_used"]:
		if not _number(data[field]) or float(data[field]) < 0.0:
			return false
	if int(data.stake) > 2 or int(data.joker_slots) < 1 or int(data.hand_size) < 1:
		return false
	if data.phase not in ["blind", "playing", "shop", "won", "lost"]:
		return false
	if int(data.ante) < 1 or int(data.ante) > 8 or int(data.blind_index) not in [0, 1, 2]:
		return false
	if not str(data.get("rng_seed", "")).is_valid_int() or not str(data.get("rng_state", "")).is_valid_int():
		return false
	for field: String in ["deck", "hand", "draw_pile", "jokers", "consumables", "shop_items", "vouchers"]:
		if not data[field] is Array:
			return false
	for field: String in ["deck", "hand", "draw_pile"]:
		var ids: Dictionary = {}
		for card: Variant in data[field]:
			if not card is Dictionary or not card.has_all(["id", "rank", "suit", "enhancement", "edition", "seal"]):
				return false
			if not _number(card.rank) or int(card.rank) < 2 or int(card.rank) > 14 or card.suit not in ["S", "H", "D", "C"]:
				return false
			for key: String in ["id", "suit", "enhancement", "edition", "seal"]:
				if not card[key] is String:
					return false
			if ids.has(card.id):
				return false
			ids[card.id] = true
	for owned: Variant in data.jokers:
		if not owned is Dictionary or not owned.has_all(["id", "edition", "counter"]):
			return false
		if GameCatalog.joker(str(owned.id)) == null:
			return false
	for item: Variant in data.consumables:
		if not item is Dictionary or not item.has("id") or GameCatalog.consumable(str(item.id)).is_empty():
			return false
	for item: Variant in data.shop_items:
		if not item is Dictionary or not item.has_all(["type", "id", "price", "sold"]):
			return false
		if item.type not in ["joker", "consumable", "voucher"] or not _number(item.price) or float(item.price) < 0 or not item.sold is bool:
			return false
		if item.type == "joker" and GameCatalog.joker(str(item.id)) == null:
			return false
		if item.type == "consumable" and GameCatalog.consumable(str(item.id)).is_empty():
			return false
		if item.type == "voucher" and RunEconomy.voucher(str(item.id)).is_empty():
			return false
	if not (data.levels is Dictionary and data.hand_counts is Dictionary and data.last_result is Dictionary):
		return false
	for level: Variant in data.levels.values():
		if not _number(level) or int(level) < 1:
			return false
	for count: Variant in data.hand_counts.values():
		if not _number(count) or int(count) < 0:
			return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func restore(run: Node, rng: RandomNumberGenerator, data: Dictionary) -> void:
	# JSON numbers are floats. Normalize domain integers before restoring dictionaries.
	for field: String in ["deck", "hand", "draw_pile"]:
		for card: Dictionary in data[field]:
			card.rank = int(card.rank)
	for item: Dictionary in data.shop_items:
		item.price = int(item.price)
	for field: String in ["levels", "hand_counts"]:
		for key: String in data[field]:
			data[field][key] = int(data[field][key])
	for field: String in FIELDS:
		run.set(field, data[field])
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
