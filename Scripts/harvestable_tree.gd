extends Area2D
class_name HarvestableTree

@export var wood_drop_count := 4
@export var hits_to_fell := 6

@onready var tree_sprite: Sprite2D = $TreeSprite
@onready var stump_sprite: Sprite2D = $StumpSprite

var harvested := false
var hits_received := 0
var shake_tween: Tween
var tree_sprite_rest_position := Vector2.ZERO
var player: PlayerController

func _ready() -> void:
	add_to_group("harvestable_trees")
	tree_sprite_rest_position = tree_sprite.position
	tree_sprite.visible = true
	stump_sprite.visible = false
	player = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false) as PlayerController
	_update_tree_sort_order()

func _process(_delta: float) -> void:
	_update_tree_sort_order()

func _update_tree_sort_order() -> void:
	if not is_instance_valid(player):
		return
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_half_height := 0.0
	if player_collision and player_collision.shape is CapsuleShape2D:
		player_half_height = (player_collision.shape as CapsuleShape2D).height * 0.5
	elif player_collision and player_collision.shape is RectangleShape2D:
		player_half_height = (player_collision.shape as RectangleShape2D).size.y * 0.5
	var player_feet_y := player.global_position.y + player_collision.position.y + player_half_height if player_collision else player.global_position.y
	tree_sprite.z_index = 2 if player_feet_y < global_position.y else 0

func harvest() -> void:
	if harvested:
		return
	hits_received += 1
	_shake_tree()
	if hits_received < hits_to_fell:
		return
	harvested = true
	tree_sprite.visible = false
	stump_sprite.visible = true
	$CollisionShape2D.set_deferred("disabled", true)
	_drop_wood()

func _shake_tree() -> void:
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()
	tree_sprite.position = tree_sprite_rest_position
	shake_tween = create_tween()
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(2.0, 0.0), 0.02)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(-2.0, 0.0), 0.03)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(1.0, 0.0), 0.025)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position, 0.02)

func _drop_wood() -> void:
	var wood_scene := preload("res://Entities/wood_resource.tscn")
	for index in wood_drop_count:
		var wood := wood_scene.instantiate()
		get_tree().current_scene.add_child(wood)
		wood.global_position = global_position + Vector2((index - (wood_drop_count - 1) * 0.5) * 20.0, 4.0)
