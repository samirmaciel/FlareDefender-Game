extends Node2D
class_name SentinelLevel1Weapon

@export var projectile_scene: PackedScene = preload("res://Entities/sentinel_level1_projectile.tscn")
@export var fire_interval := 1.0
@export var projectile_speed := 420.0
@export var muzzle_distance := 20.0

@onready var weapon_sprite: AnimatedSprite2D = $Sentinel_level1_weapon_anim

var placement_preview := false
var is_placement_valid := false
var target: Node2D
var fire_timer := 0.0
var is_firing := false

func _ready() -> void:
	weapon_sprite.animation_finished.connect(_on_weapon_animation_finished)
	weapon_sprite.frame_changed.connect(_on_weapon_frame_changed)
	weapon_sprite.sprite_frames.set_animation_loop("Fire", false)
	weapon_sprite.play("Idle")
	if not placement_preview:
		_acquire_player()

func start_placement_preview() -> void:
	placement_preview = true
	set_placement_valid(false)
	$StaticBody2D/CollisionShape2D.set_deferred("disabled", true)

func set_placement_valid(is_valid: bool) -> void:
	is_placement_valid = is_valid
	if placement_preview:
		modulate = Color(0.0, 0.913, 0.0, 0.549) if is_valid else Color(1.0, 0.1, 0.1, 0.549)

func confirm_placement() -> void:
	placement_preview = false
	modulate = Color.WHITE
	$StaticBody2D/CollisionShape2D.set_deferred("disabled", false)
	fire_timer = 0.0
	_acquire_player()

func _process(delta: float) -> void:
	if placement_preview:
		return
	if not is_instance_valid(target):
		_acquire_player()
	if not is_instance_valid(target):
		return

	var direction := (target.global_position - global_position).normalized()
	if direction.is_zero_approx():
		return
	# The weapon artwork points upward in its default frame.
	weapon_sprite.rotation = direction.angle() + PI / 2.0

	if is_firing:
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		is_firing = true
		weapon_sprite.play("Fire")

func _on_weapon_frame_changed() -> void:
	if weapon_sprite.animation != "Fire" or weapon_sprite.frame != 1 or not is_firing:
		return
	if not is_instance_valid(target):
		_acquire_player()
	if not is_instance_valid(target):
		return
	var direction := (target.global_position - global_position).normalized()
	if direction.is_zero_approx():
		return
	var projectile := projectile_scene.instantiate() as SentinelLevel1Projectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * muzzle_distance
	projectile.launch(direction, projectile_speed)

func _on_weapon_animation_finished() -> void:
	if weapon_sprite.animation != "Fire" or not is_firing:
		return
	weapon_sprite.play("Idle")
	is_firing = false
	fire_timer = fire_interval

func _acquire_player() -> void:
	target = get_tree().get_first_node_in_group("player") as Node2D
