extends Area2D

## 四向直线飞行的子弹。由 Player 实例化并设置 direction 与 global_position。

@export var speed: float = 400.0
@export var damage: int = 10

var direction: Vector2 = Vector2.UP

@onready var _screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	_screen_notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
