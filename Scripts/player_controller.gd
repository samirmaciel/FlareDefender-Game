extends CharacterBody2D

@export var move_speed := 240.0
@export var sprint_speed := 360.0
@export var sprint_animation_speed_scale := 1.6

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: PlayerStats = $PlayerStats

var facing_left := false
var is_attacking := false
var next_attack_animation := "Attack"

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.flip_h = false
	animated_sprite.play("Idle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_attacking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_start_attack()

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	direction.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	direction.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	direction = direction.normalized()

	if absf(direction.x) > 0.01:
		facing_left = direction.x < 0.0
		animated_sprite.flip_h = facing_left

	var sprint_requested := Input.is_key_pressed(KEY_SHIFT) and not direction.is_zero_approx()
	var sprinting := sprint_requested and stats.can_sprint()
	stats.update_stamina(sprinting, _delta)

	var current_speed := sprint_speed if sprinting else move_speed
	velocity = direction * current_speed
	move_and_slide()
	_update_animation(direction, sprinting)

func _update_animation(direction: Vector2, sprinting: bool) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_attacking = false
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != "Guard":
			animated_sprite.play("Guard")
		return

	if is_attacking:
		return

	if direction.is_zero_approx():
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != "Idle":
			animated_sprite.play("Idle")
	else:
		animated_sprite.speed_scale = sprint_animation_speed_scale if sprinting else 1.0
		if animated_sprite.animation != "Walking":
			animated_sprite.play("Walking")

func _start_attack() -> void:
	is_attacking = true
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(next_attack_animation)
	next_attack_animation = "Attack2" if next_attack_animation == "Attack" else "Attack"

func _on_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
