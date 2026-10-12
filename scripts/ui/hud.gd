extends PanelContainer

func update_run(run: RunController, preview: Dictionary = {}) -> void:
	%BlindTitle.text = run.blind_name()
	%BlindRule.text = run.boss_description() if run.blind_index == 2 else "A little luck. A good beginning."
	%TargetValue.text = format_number(run.target_score)
	%ScoreValue.text = format_number(run.round_score)
	%Progress.max_value = maxi(run.target_score, 1)
	%Progress.value = run.round_score
	%Reward.text = "REWARD  $%d" % (3 + run.blind_index)
	%HandsValue.text = str(run.hands_left)
	%DiscardsValue.text = str(run.discards_left)
	%Cash.text = "$%d" % run.money
	%Ante.text = "ANTE  %d / 8\nROUND  %d" % [run.ante, run.round_number]
	var info: Dictionary = preview if not preview.is_empty() else run.last_result
	%HandName.text = str(info.get("hand", "Choose your cards"))
	%HandLevel.text = "LEVEL %d" % run.levels.get(info.get("hand", "High Card"), 1) if not info.is_empty() else "PLAY UP TO 5 CARDS"
	%Chips.text = format_number(int(info.get("chips", 0)))
	%Mult.text = ("%.1f" % float(info.get("mult", 0))).trim_suffix(".0")

static func format_number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result
