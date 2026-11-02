extends Node2D
class_name SentinelLevel1Projectile

@export var lifetime := 3.0

@onready var projectile_sprite: AnimatedSprite2D = $Sentinel_level1_projectile_anim

var velocity := Vector2.ZERO

func aim(direction: Vector2) -> void:
	projectile_sprite.rotation = direction.angle() + PI / 2.0

func launch(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	aim(velocity.normalized())

func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
