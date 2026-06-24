extends Node2D

## 商店房间：5 个商品格（血包 + 4 个随机遗物）。

const HEALTH_PACK_PRICE: int = 2
const RELIC_PRICE: int = 6

const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(252, 300),
	Vector2(402, 300),
	Vector2(552, 300),
	Vector2(702, 300),
	Vector2(852, 300),
]

@export var shop_item_scene: PackedScene


func _ready() -> void:
	if shop_item_scene == null:
		push_warning("Shop: shop_item_scene 未设置")
		return

	_spawn_item(ShopItem.ProductType.HEALTH_PACK, "", HEALTH_PACK_PRICE, SLOT_POSITIONS[0])

	var relic_ids: Array[String] = GlobalManager.get_random_unowned_relic_ids(4)
	for i in relic_ids.size():
		_spawn_item(ShopItem.ProductType.RELIC, relic_ids[i], RELIC_PRICE, SLOT_POSITIONS[i + 1])


func _spawn_item(type: ShopItem.ProductType, relic_id: String, price: int, pos: Vector2) -> void:
	var item: Area2D = shop_item_scene.instantiate()
	add_child(item)
	item.global_position = pos
	if item.has_method("setup"):
		item.setup(type, relic_id, price)
