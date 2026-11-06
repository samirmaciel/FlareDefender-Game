extends Node2D

var outline_points := PackedVector2Array()
var dash_length := 28.0
var gap_length := 18.0
var line_width := 5.0
var line_color := Color(1.0, 1.0, 1.0, 0.92)

func set_outline(points: PackedVector2Array) -> void:
	outline_points = points
	queue_redraw()

func _draw() -> void:
	if outline_points.size() < 2:
		return
	var perimeter := 0.0
	for point_index in range(outline_points.size()):
		perimeter += outline_points[point_index].distance_to(outline_points[(point_index + 1) % outline_points.size()])
	if perimeter <= 0.0:
		return

	var pattern_size := dash_length + gap_length
	var dash_count := maxi(roundi(perimeter / pattern_size), 1)
	var pattern_period := perimeter / float(dash_count)
	var dash_span := pattern_period * dash_length / pattern_size
	var distance_along_outline := 0.0
	for point_index in range(outline_points.size()):
		var start := outline_points[point_index]
		var finish := outline_points[(point_index + 1) % outline_points.size()]
		var edge := finish - start
		var edge_length := edge.length()
		if edge_length <= 0.0:
			continue
		var direction := edge / edge_length
		var edge_distance := 0.0
		while edge_distance < edge_length:
			var phase := fposmod(distance_along_outline + edge_distance, pattern_period)
			var is_dash := phase < dash_span
			var remaining_pattern := dash_span - phase if is_dash else pattern_period - phase
			var segment_length := minf(edge_length - edge_distance, maxf(remaining_pattern, 0.1))
			if is_dash:
				draw_line(start + direction * edge_distance, start + direction * (edge_distance + segment_length), line_color, line_width, true)
			edge_distance += segment_length
		distance_along_outline += edge_length
