extends Control

# 工艺藏品掉落通知系统

var notification_queue: Array[Dictionary] = []
var is_showing: bool = false

func _ready() -> void:
	modulate = Color(1, 1, 1, 0)  # 初始透明

func show_loot_notification(item_data: Dictionary) -> void:
	notification_queue.append(item_data)
	if not is_showing:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.size() == 0:
		is_showing = false
		return

	is_showing = true
	var item_data = notification_queue.pop_front()
	_display_notification(item_data)

func _display_notification(item_data: Dictionary) -> void:
	# 清除旧内容
	for child in get_children():
		child.queue_free()

	# 获取品质颜色
	var quality = item_data.get("quality", "")
	var quality_color = _get_quality_color(quality)

	# 背景面板
	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.offset_left = -200
	bg.offset_right = 200
	bg.offset_top = -60
	bg.offset_bottom = 20

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_border_width_all(3)
	style.set_border_color(quality_color)
	style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(vbox)

	# 品质标签
	var quality_label = Label.new()
	quality_label.text = _get_quality_text(quality)
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size", 14)
	quality_label.add_theme_color_override("font_color", quality_color)
	vbox.add_child(quality_label)

	# 物品名称
	var name_label = Label.new()
	name_label.text = item_data.get("name", "未知物品")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	# 物品描述
	var desc_label = Label.new()
	desc_label.text = item_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_label)

	# 卖出价格
	var price_label = Label.new()
	price_label.text = "价值: $" + str(item_data.get("sell_price", 0))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(price_label)

	# 淡入动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(bg, "offset_top", -50, 0.3).from(-80)

	# 3秒后淡出
	await get_tree().create_timer(3.0).timeout

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

	await tween.finished
	_show_next_notification()

func _get_quality_color(quality: String) -> Color:
	match quality:
		"green":
			return Color(0.2, 0.85, 0.3, 1)
		"blue":
			return Color(0.3, 0.5, 1.0, 1)
		"purple":
			return Color(0.6, 0.3, 0.9, 1)
		_:
			return Color(0.6, 0.6, 0.6, 1)

func _get_quality_text(quality: String) -> String:
	match quality:
		"green":
			return "【普通】工艺藏品"
		"blue":
			return "【稀有】工艺藏品"
		"purple":
			return "【史诗】工艺藏品"
		_:
			return "工艺藏品"
