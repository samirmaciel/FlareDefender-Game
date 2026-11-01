extends Area2D
class_name WoodResource

signal collected

var is_collecting := false

func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController or is_collecting:
		return
	is_collecting = true
	collected.emit()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collect_tween := create_tween().set_parallel(true)
	collect_tween.tween_property(self, "global_position:y", global_position.y - 28.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	collect_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	collect_tween.chain().tween_callback(queue_free)
