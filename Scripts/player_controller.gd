extends CharacterBody2D

@export var move_speed := 240.0
@export var sprint_speed := 360.0

var animated_sprite: AnimatedSprite2D
var hand_tool_sprite: Sprite2D
var facing_left := false

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	direction.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	direction.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	direction = direction.normalized()

	var sprint_requested := Input.is_key_pressed(KEY_SHIFT) and not direction.is_zero_approx()
	var stats: PlayerStats = $PlayerStats
	var sprinting := sprint_requested and stats.can_sprint()
	stats.update_stamina(sprinting, _delta)

	var current_speed := sprint_speed if sprinting else move_speed
	velocity = direction * current_speed
	move_and_slide()
