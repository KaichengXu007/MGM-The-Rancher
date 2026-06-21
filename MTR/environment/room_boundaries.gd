extends Node2D

## 在房间四周生成 StaticBody2D 墙壁，阻挡玩家与怪物越界。

@export var room_size: Vector2 = Vector2(1152, 648)
@export var wall_thickness: float = 32.0
@export var wall_color: Color = Color(0.28, 0.25, 0.22, 1.0)


func _ready() -> void:
	_add_wall(Vector2(room_size.x * 0.5, wall_thickness * 0.5), Vector2(room_size.x, wall_thickness))
	_add_wall(
		Vector2(room_size.x * 0.5, room_size.y - wall_thickness * 0.5),
		Vector2(room_size.x, wall_thickness)
	)
	_add_wall(Vector2(wall_thickness * 0.5, room_size.y * 0.5), Vector2(wall_thickness, room_size.y))
	_add_wall(
		Vector2(room_size.x - wall_thickness * 0.5, room_size.y * 0.5),
		Vector2(wall_thickness, room_size.y)
	)


func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center

	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape_node.shape = rect_shape
	body.add_child(shape_node)

	var half := size * 0.5
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	visual.color = wall_color
	body.add_child(visual)

	add_child(body)
