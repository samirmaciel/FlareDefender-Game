extends CharacterBody2D
class_name PlayerController

enum HeldItem { NONE, AXE, GOLD, HAMMER, KNIFE, MEAT, PICKAXE, WOOD }

signal held_item_changed(item: HeldItem)

@export var move_speed := 240.0
@export var sprint_speed := 360.0
@export var sprint_animation_speed_scale := 1.6
@export var held_item: HeldItem = HeldItem.KNIFE

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: PlayerStats = $PlayerStats

var facing_left := false
var is_interacting := false

const IDLE_ANIMATIONS := {
	HeldItem.NONE: "Idle",
	HeldItem.AXE: "Idle Axe",
	HeldItem.GOLD: "Idle Gold",
	HeldItem.HAMMER: "Idle Hammer",
	HeldItem.KNIFE: "Idle Knife",
	HeldItem.MEAT: "Idle Meat",
	HeldItem.PICKAXE: "Idle Pickaxe",
	HeldItem.WOOD: "Idle Wood",
}

const MOVE_ANIMATIONS := {
	HeldItem.NONE: "Run",
	HeldItem.AXE: "Run Axe",
	HeldItem.GOLD: "Run Gold",
	HeldItem.HAMMER: "Run Hammer",
	HeldItem.KNIFE: "Run Knife",
	HeldItem.MEAT: "Run Meat",
	HeldItem.PICKAXE: "Run Pickaxe",
	HeldItem.WOOD: "Run Wood",
}

const ACTION_ANIMATIONS := {
	HeldItem.AXE: "Interact Axe",
	HeldItem.HAMMER: "Interact Hammer",
	HeldItem.KNIFE: "Interact Knife",
	HeldItem.PICKAXE: "Interact Pickaxe",
}

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.flip_h = false
	# Item interactions should finish so the controller can return to idle/run.
	for animation_name in ACTION_ANIMATIONS.values():
		animated_sprite.sprite_frames.set_animation_loop(animation_name, false)
	_play_if_needed(IDLE_ANIMATIONS[held_item])

func equip_item(item: HeldItem) -> void:
	if held_item == item:
		return
	held_item = item
	held_item_changed.emit(held_item)
	if not is_interacting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_play_if_needed(IDLE_ANIMATIONS[held_item])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_interacting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_start_interaction()

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	direction.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	direction.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	direction = direction.normalized()

	if is_interacting and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_interacting = false
	if is_interacting:
		velocity = Vector2.ZERO
		stats.update_stamina(false, _delta)
		move_and_slide()
		return

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
		is_interacting = false

	if is_interacting:
		return

	if direction.is_zero_approx():
		animated_sprite.speed_scale = 1.0
		_play_if_needed(IDLE_ANIMATIONS[held_item])
	else:
		animated_sprite.speed_scale = sprint_animation_speed_scale if sprinting else 1.0
		_play_if_needed(MOVE_ANIMATIONS[held_item])

func _start_interaction() -> void:
	var action_animation: String = ACTION_ANIMATIONS.get(held_item, "")
	if action_animation.is_empty():
		return
	is_interacting = true
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(action_animation)

func _harvest_tree_in_front() -> void:
	var facing := Vector2.LEFT if facing_left else Vector2.RIGHT
	var best_tree: HarvestableTree
	var best_distance := 60.0
	var player_feet_y := global_position.y
	var player_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_collision:
		player_feet_y += player_collision.position.y
		if player_collision.shape is CapsuleShape2D:
			player_feet_y += (player_collision.shape as CapsuleShape2D).height * 0.5
		elif player_collision.shape is RectangleShape2D:
			player_feet_y += (player_collision.shape as RectangleShape2D).size.y * 0.5
	const SIDE_HIT_VERTICAL_TOLERANCE := 24.0
	for node in get_tree().get_nodes_in_group("harvestable_trees"):
		if not is_instance_valid(node) or node.harvested:
			continue
		var offset: Vector2 = node.global_position - global_position
		var distance := offset.length()
		# Align the player's feet with the tree base so attacks from above or
		# below are rejected even when the player is diagonally nearby.
		var feet_to_tree_base := absf(player_feet_y - node.global_position.y)
		if distance > best_distance or offset.dot(facing) <= 0.0 or feet_to_tree_base > SIDE_HIT_VERTICAL_TOLERANCE:
			continue
		best_tree = node
		best_distance = distance
	if best_tree:
		best_tree.harvest()

func _on_animation_finished() -> void:
	if is_interacting:
		if held_item == HeldItem.AXE and animated_sprite.animation == ACTION_ANIMATIONS[HeldItem.AXE]:
			_harvest_tree_in_front()
		is_interacting = false

func _play_if_needed(animation_name: String) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
