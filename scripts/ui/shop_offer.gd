extends PanelContainer
signal purchased(index: int)
var offer_index: int = -1

func setup(item: Dictionary, index: int, money: int) -> void:
	offer_index = index
	var kind := str(item.get("type", "joker"))
	var title := str(item.get("id", ""))
	var description := ""
	var color := Color("d8b471")
	if kind == "joker":
		var data = GameCatalog.joker(title)
		if data:
			title = data.title
			description = data.description
			color = data.accent
			%Kind.text = "JOKER · " + data.rarity.to_upper()
	else:
		var data: Dictionary = {}
		if kind == "voucher":
			for voucher in GameCatalog.vouchers():
				if voucher.id == title:
					data = voucher
		else:
			data = GameCatalog.consumable(title)
		title = str(data.get("title", data.get("name", title)))
		description = str(data.get("description", ""))
		%Kind.text = str(data.get("kind", kind)).to_upper()
	%Title.text = title
	%Title.add_theme_color_override("font_color", color.lightened(0.25))
	%Description.text = description
	%Buy.text = "Sold" if item.get("sold", false) else "Buy  $%d" % int(item.get("price", 0))
	%Buy.disabled = item.get("sold", false) or money < int(item.get("price", 0))
	%Buy.pressed.connect(func(): purchased.emit(offer_index))
