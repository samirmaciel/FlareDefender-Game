extends Area2D
class_name WoodResource

signal collected

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		collected.emit()
		queue_free()
