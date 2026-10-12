extends SceneTree
## Reproducible legal-action smoke test: all 24 campaign blinds at their real targets.
## The bot sees only the current hand and displayed shop offers. No deck peeking,
## injected cards/cash/levels, changed targets, or skipped rounds. This is evidence
## of winnability for one strategy and seed, not a statistical balance guarantee.

var ratings: Dictionary = {"jester":4.0,"chip_stack":10.0,"amplifier":40.0,"heartline":7.0,"diamond_mine":2.0,"clubhouse":5.0,"spade_castle":3.0,"fibonacci":18.0,"scholar":5.0,"even_steven":10.0,"odd_todd":10.0,"smiley":8.0,"tiny_dancer":6.0,"pair_program":8.0,"triplicate":5.0,"square_deal":5.0,"flush_hour":4.0,"straight_shooter":4.0,"lone_wolf":10.0,"clean_slate":25.0,"last_call":28.0,"bankroll":6.0,"leftover":4.0,"blue_reserve":4.0,"stargazer":13.0,"ritual":3.0,"echo":45.0,"minimalist":20.0,"steelworks":5.0,"royal_court":9.0,"stone_mason":3.0,"glassworks":3.0,"constellation":12.0,"boss_breaker":15.0,"lucky_star":3.0,"payday":3.0,"recycler":20.0}

func _initialize() -> void:
	var run: RunController = RunController.new()
	run.save_path = "user://test_campaign_playthrough.json"
	run.new_run("BALANCE1")
	var turns: int = 0
	while run.phase not in ["won", "lost"] and turns < 700:
		turns += 1
		match run.phase:
			"blind": run.start_blind()
			"shop": shop(run)
			"playing":
				consume(run)
				var best: Dictionary = best_play(run)
				if best.indices.is_empty():
					break
				if run.discards_left > 0 and best.total < run.target_score - run.round_score:
					var drop: Array = []
					for index: int in range(run.hand.size()):
						if index not in best.indices and run.hand[index].enhancement != "steel":
							drop.append(index)
					if not drop.is_empty():
						run.discard_cards(drop.slice(0, 5))
						continue
				run.play_cards(best.indices)
	var won: bool = run.phase == "won" and run.round_number == 24 and run.ante == 8
	if won:
		print("CAMPAIGN PLAYTHROUGH PASSED: 24 real blinds, final %d / %d, %d actions" % [run.round_score, run.target_score, turns])
	else:
		printerr("CAMPAIGN PLAYTHROUGH FAILED: phase=%s, ante=%d, blind=%d, score=%d/%d" % [run.phase, run.ante, run.blind_index, run.round_score, run.target_score])
	run.clear_save()
	run.free()
	quit(0 if won else 1)

func shop(run: RunController) -> void:
	for index: int in range(run.consumables.size()-1,-1,-1):
		var info: Dictionary = GameCatalog.consumable(run.consumables[index].id)
		if info.effect in ["level_hand", "money"]: run.use_consumable(index)
	for index: int in range(run.shop_items.size()):
		var offer: Dictionary = run.shop_items[index]
		if offer.type != "joker": continue
		var rating: float = ratings.get(offer.id, 0.0)
		if run.jokers.size() >= run.joker_slots:
			var worst_index: int = 0
			for slot: int in range(run.jokers.size()):
				if ratings.get(run.jokers[slot].id,0.0) < ratings.get(run.jokers[worst_index].id,0.0): worst_index=slot
			if rating > ratings.get(run.jokers[worst_index].id,0.0)+2 and run.money + GameCatalog.joker(run.jokers[worst_index].id).price / 2 >= offer.price:
				run.sell_joker(worst_index)
		if run.jokers.size() < run.joker_slots:
			run.buy_item(index)
	for index: int in range(run.shop_items.size()):
		var offer: Dictionary=run.shop_items[index]
		if offer.type != "consumable": continue
		var item: Dictionary=GameCatalog.consumable(offer.id)
		var valuable: bool = item.effect in ["level_hand","money"] or item.target in ["mult","steel","glass","lucky","polychrome","red"]
		if valuable and run.buy_item(index):
			if item.effect in ["level_hand","money"]: run.use_consumable(run.consumables.size()-1)
	# Mult addition before multiplier effects, preserving cards for later one-shot items.
	for target: int in range(run.jokers.size()):
		for source: int in range(target+1,run.jokers.size()):
			var current: JokerData=GameCatalog.joker(run.jokers[target].id)
			var later: JokerData=GameCatalog.joker(run.jokers[source].id)
			if current.effect.begins_with("xmult") and not later.effect.begins_with("xmult"):
				run.move_joker(source,target)
	run.leave_shop()

func consume(run: RunController) -> void:
	for index: int in range(run.consumables.size()-1,-1,-1):
		var item: Dictionary=GameCatalog.consumable(run.consumables[index].id)
		if item.effect in ["level_hand","money"]:
			run.use_consumable(index)
			continue
		var selected: Array=[]
		for card_index: int in range(run.hand.size()):
			if run.hand[card_index].enhancement == "": selected.append(card_index)
		if selected.is_empty(): selected=[0]
		run.use_consumable(index,selected.slice(0,1 if item.effect in ["edition","seal"] else 2))

func best_play(run: RunController) -> Dictionary:
	var best: Dictionary = {"total": -1, "indices": [], "hand": ""}
	for mask: int in range(1, 1 << run.hand.size()):
		var indices: Array = []
		for index: int in range(run.hand.size()):
			if mask & (1 << index): indices.append(index)
		if indices.size() > run.max_played_cards(): continue
		var preview: Dictionary = run.preview(indices)
		if not run.boss_hand_lock.is_empty() and preview.hand != run.boss_hand_lock: continue
		if int(preview.get("total", 0)) > int(best.total):
			best = {"total": preview.total, "indices": indices, "hand": preview.hand}
	return best
