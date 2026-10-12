class_name RunEconomy
extends RefCounted
## Deterministic shop selection. Catalog Resources own item values and effects.

static func make_shop(rng: RandomNumberGenerator, owned_vouchers: Array, discount: float, rare_bonus: float) -> Array:
	var offers: Array = []
	var excluded: Array = []
	for _slot in range(2):
		var candidates: Array = []
		var weights: Array[float] = []
		for joker: Resource in GameCatalog.jokers():
			if joker.id in excluded:
				continue
			candidates.append(joker)
			var weight: float = 6.0
			if str(joker.rarity).to_lower() == "uncommon":
				weight = 3.0 + rare_bonus
			elif str(joker.rarity).to_lower() == "rare":
				weight = 1.0 + rare_bonus
			weights.append(weight)
		if not candidates.is_empty():
			var selected: Resource = candidates[_weighted_index(rng, weights)]
			excluded.append(selected.id)
			offers.append(_offer("joker", selected.id, discounted_price(int(selected.price), discount)))
	var items: Array = GameCatalog.consumables()
	for _slot in range(2):
		var candidates: Array = []
		var weights: Array[float] = []
		for item: Dictionary in items:
			if item.id in excluded:
				continue
			candidates.append(item)
			weights.append(0.6 if item.kind == "spectral" else 4.0)
		if not candidates.is_empty():
			var chosen: Dictionary = candidates[_weighted_index(rng, weights)]
			excluded.append(chosen.id)
			offers.append(_offer("consumable", chosen.id, discounted_price(int(chosen.price), discount)))
	var vouchers: Array = GameCatalog.vouchers().filter(func(item: Dictionary) -> bool: return item.id not in owned_vouchers)
	if not vouchers.is_empty():
		var voucher: Dictionary = vouchers[rng.randi_range(0, vouchers.size() - 1)]
		offers.append(_offer("voucher", voucher.id, discounted_price(int(voucher.price), discount)))
	return offers

static func discounted_price(base_price: int, discount: float) -> int:
	return maxi(1, int(ceil(float(base_price) * (1.0 - clampf(discount, 0.0, 1.0)))))

static func refresh_prices(offers: Array, discount: float) -> void:
	for offer: Dictionary in offers:
		if bool(offer.sold):
			continue
		var base_price: int = 1
		match str(offer.type):
			"joker": base_price = int(GameCatalog.joker(str(offer.id)).price)
			"consumable": base_price = int(GameCatalog.consumable(str(offer.id)).price)
			"voucher": base_price = int(voucher(str(offer.id)).price)
		offer.price = discounted_price(base_price, discount)

static func _weighted_index(rng: RandomNumberGenerator, weights: Array[float]) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for index: int in range(weights.size()):
		roll -= weights[index]
		if roll < 0.0:
			return index
	return weights.size() - 1

static func _offer(kind: String, id: String, price: int) -> Dictionary:
	return {"type": kind, "id": id, "price": price, "sold": false}

static func voucher(id: String) -> Dictionary:
	for item: Dictionary in GameCatalog.vouchers():
		if item.id == id:
			return item
	return {}
