class_name JokerData
extends Resource
## Editor-visible, data-driven scoring modifier. Effects are handled by ScoreEngine.

@export_group("Identity")
@export var id: String = ""
@export var title: String = "Joker"
@export_multiline var description: String = ""
@export_enum("Common", "Uncommon", "Rare") var rarity: String = "Common"
@export_range(1, 20, 1) var price: int = 4

@export_group("Scoring")
@export_enum("chips", "mult", "xmult", "card_chips", "card_mult", "card_xmult", "chips_per_discard", "mult_per_tarot", "mult_per_hand", "mult_per_money", "chips_per_hand_left", "mult_per_discard_left", "xmult_per_planet", "held_king", "held_low", "cash") var effect: String = "mult"
@export var amount: float = 4.0
@export var condition: String = "always"

@export_group("Presentation")
@export var accent: Color = Color("e5b966")
@export_enum("moon", "sun", "prism", "skull", "eye", "joker", "star", "clover") var art: String = "joker"
