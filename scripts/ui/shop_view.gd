extends VBoxContainer
const OFFER_SCENE = preload("res://scenes/ui/shop_offer.tscn")
var run: RunController
var compact := false
var mobile := false

func _ready() -> void:
	resized.connect(_layout_offers)

func _layout_offers() -> void:
	%ShopEyebrow.visible = not compact
	%ShopTitle.add_theme_font_size_override("font_size", 30 if compact else 34)
	%Offers.columns = 5 if compact else (3 if size.x > 800 else 2)
	%Reroll.custom_minimum_size.y = 80 if mobile else 56
	%NextBlind.custom_minimum_size.y = 80 if mobile else 56
	%Reroll.add_theme_font_size_override("font_size", 25 if mobile else 20)
	%NextBlind.add_theme_font_size_override("font_size", 25 if mobile else 20)

func bind(controller: RunController) -> void:
	run = controller
	%Reroll.pressed.connect(func(): run.reroll_shop())
	%NextBlind.pressed.connect(func(): run.leave_shop())

func refresh() -> void:
	for child in %Offers.get_children():
		%Offers.remove_child(child)
		child.queue_free()
	for i in run.shop_items.size():
		var offer = OFFER_SCENE.instantiate()
		%Offers.add_child(offer)
		offer.setup(run.shop_items[i], i, run.money)
		offer.get_node("%Description").add_theme_font_size_override("font_size", 21 if mobile else 17)
		offer.get_node("%Buy").custom_minimum_size.y = 70 if mobile else 43
		offer.get_node("%Buy").add_theme_font_size_override("font_size", 24 if mobile else 17)
		offer.purchased.connect(func(index: int): run.buy_item(index))
	%Reroll.text = "Reroll  $%d" % run.reroll_cost
	%Reroll.disabled = run.money < run.reroll_cost
	_layout_offers.call_deferred()
