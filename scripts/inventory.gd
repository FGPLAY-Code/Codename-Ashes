extends Control

# 背包格子数据（普通物品）
var slots: Array[Dictionary] = []

# 装备槽数据（防弹衣）
var armor_slot: Dictionary = {
	"name": "",
	"icon": "",
	"count": 0,
	"description": ""
}

# ===== 拖动系统状态 =====
var is_dragging: bool = false
var drag_source_index: int = -1          # 源格子索引（-1表示从外部拖入）
var drag_source_is_ammo_box: bool = false # 是否从弹药箱拖入
var drag_item_data: Dictionary = {}       # 拖动中的物品数据
var drag_preview: Control = null           # 拖动预览元素

const SLOT_COUNT: int = 28  # 7x4 格子
const CELL_SIZE: int = 80
const ARMOR_CELL_SIZE: int = 240  # 3x3 大格 = 80 * 3

func _ready() -> void:
	_initialize_slots()
	_populate_grid()
	_populate_armor_slot()
	
	# 连接全局输入以处理拖动放下
	gui_input.connect(_on_inventory_gui_input)
	
	# 等待玩家初始化完成后同步弹药数据
	# 使用协程等待，确保在玩家加入组后再获取
	_init_ammo_when_ready()

func _init_ammo_when_ready() -> void:
	# 等待最多 3 秒，让玩家有时间初始化
	var wait_time = 0.0
	var max_wait = 3.0
	while wait_time < max_wait:
		await get_tree().process_frame
		wait_time += 0.016  # 大约一帧的时间
		var player = _get_player()
		if player:
			print("[Inventory] 找到玩家，初始化弹药数据")
			var ammo_count = _get_reserve_ammo()
			for slot in slots:
				if slot.get("is_ammo", false) and slot["name"] != "":
					slot["count"] = ammo_count
					print("[Inventory] 弹药格初始化为: ", ammo_count)
					break
			refresh()
			return
	
	print("[Inventory] 等待超时，未找到玩家")

func _process(_delta: float) -> void:
	# 拖动预览跟随鼠标
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - Vector2(40, 40)

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("Player")

func _get_reserve_ammo() -> int:
	var p = _get_player()
	if p and p.has_method("get_reserve_ammo"):
		var ammo = p.get_reserve_ammo()
		print("[Inventory] _get_reserve_ammo() = ", ammo)  # 调试
		return ammo
	print("[Inventory] _get_reserve_ammo() - 玩家未找到，返回默认值 90")
	return 90

func _initialize_slots() -> void:
	slots.clear()
	for i in range(SLOT_COUNT):
		slots.append({
			"id": i,
			"name": "",
			"icon": "",
			"count": 0,
			"description": "",
			"is_ammo": false
		})

	# 普通背包物品（防弹衣已移至独立装备槽）
	# 注意：这里初始化为0，延迟函数会从玩家读取真实值
	_add_item("7.62x39mm", "ammo", 0, "步枪弹药（备弹）", true)

	# 初始化装备槽：防弹衣
	armor_slot = {
		"name": "防弹衣",
		"icon": "armor",
		"count": 1,
		"description": "增加 50 点护甲"
	}

func _add_item(item_name: String, icon_type: String, count: int, description: String, is_ammo: bool = false) -> bool:
	# 先找是否有同类物品（弹药格特殊处理，不叠加）
	if not is_ammo:
		for slot in slots:
			if slot["name"] == item_name:
				slot["count"] += count
				return true

	# 弹药：直接找空格子插入
	for slot in slots:
		if slot["name"] == "":
			slot["name"] = item_name
			slot["icon"] = icon_type
			slot["count"] = count
			slot["description"] = description
			slot["is_ammo"] = is_ammo
			print("[Inventory] _add_item 添加物品: ", item_name, " x", count, " is_ammo=", is_ammo)
			return true

	return false

func _populate_grid() -> void:
	var grid = $VBox/GridScroll/Grid
	if not grid:
		return

	# 弹药数量由背包系统管理，不要每次都从玩家覆盖
	# 只有在消耗弹药时才会同步到玩家

	# 清除旧格子
	for child in grid.get_children():
		child.queue_free()

	# 创建新格子
	for i in range(SLOT_COUNT):
		var cell = _create_slot_cell(i)
		grid.add_child(cell)

func _populate_armor_slot() -> void:
	var armor_container = $VBox/ArmorRow/ArmorSlot
	if not armor_container:
		return

	# 清除旧内容
	for child in armor_container.get_children():
		child.queue_free()

	# 设置大格样式
	var style = StyleBoxFlat.new()
	if armor_slot["name"] != "":
		style.bg_color = Color(0.15, 0.25, 0.45, 0.95)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.set_border_width_all(2)
	style.set_border_color(Color(0.4, 0.6, 0.9, 0.8))
	style.set_corner_radius_all(6)
	armor_container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	armor_container.add_child(vbox)

	if armor_slot["name"] != "":
		# 装备图标
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(100, 100)
		icon.color = _get_item_color(armor_slot["icon"])
		vbox.add_child(icon)

		# 装备名称
		var name_label = Label.new()
		name_label.text = armor_slot["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		vbox.add_child(name_label)

		# 描述
		var desc_label = Label.new()
		desc_label.text = armor_slot["description"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(ARMOR_CELL_SIZE - 20, 0)
		vbox.add_child(desc_label)
	else:
		# 空槽提示
		var empty_label = Label.new()
		empty_label.text = "防弹衣槽（空）"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(empty_label)

func _create_slot_cell(slot_index: int) -> Control:
	var cell = PanelContainer.new()
	cell.name = "Slot_" + str(slot_index)
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.set_meta("slot_index", slot_index)

	var data = slots[slot_index]

	# 设置背景样式（根据物品品质设置边框颜色）
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.set_border_width_all(2)
	# 工艺藏品使用品质边框
	var border_color = Color(0.4, 0.4, 0.4, 0.8)
	if data["name"] != "" and data.get("quality", "") != "":
		border_color = _get_item_color(data.get("icon", ""), data.get("quality", ""))
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	style.set_border_color(border_color)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
	cell.add_child(vbox)

	if data["name"] != "":
		# 物品图标（用颜色方块代替）
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		var color = _get_item_color(data["icon"], data.get("quality", ""))
		icon.color = color
		vbox.add_child(icon)

		# 物品名称（品质颜色显示）
		var name_label = Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(CELL_SIZE - 12, 0)
		name_label.add_theme_font_size_override("font_size", 11)
		# 工艺藏品名称使用品质颜色
		if data.get("quality", "") != "":
			name_label.add_theme_color_override("font_color", _get_item_color(data["icon"], data["quality"]))
		else:
			name_label.add_theme_color_override("font_color", Color(1, 1, 1))
		vbox.add_child(name_label)

		# 数量（弹药格始终显示，普通物品>1才显示）
		if data["count"] > 1 or data.get("is_ammo", false):
			var count_label = Label.new()
			# 弹药格：始终从玩家实时读取备弹数
			if data.get("is_ammo", false):
				count_label.text = "x" + str(_get_reserve_ammo())
			else:
				count_label.text = "x" + str(data["count"])
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 12)
			count_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			vbox.add_child(count_label)
		# 显示品质标签（工艺藏品）
		if data.get("quality", "") != "":
			var quality_label = Label.new()
			quality_label.text = _get_quality_label(data.get("quality", ""))
			quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			quality_label.add_theme_font_size_override("font_size", 9)
			quality_label.add_theme_color_override("font_color", _get_item_color(data["icon"], data["quality"]))
			vbox.add_child(quality_label)
	else:
		# 空格子提示
		var empty_hint = Label.new()
		empty_hint.text = "+"
		empty_hint.add_theme_font_size_override("font_size", 20)
		empty_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(empty_hint)

	# 连接鼠标信号
	cell.gui_input.connect(_on_slot_gui_input.bind(cell, slot_index))

	return cell

func _get_quality_label(quality: String) -> String:
	match quality:
		"green":
			return "[普通]"
		"blue":
			return "[稀有]"
		"purple":
			return "[史诗]"
		_:
			return ""

func _get_item_color(icon_type: String, quality: String = "") -> Color:
	# 如果有品质，优先使用品质颜色
	if quality != "":
		var craft_items_script = load("res://scripts/craft_items.gd")
		if craft_items_script:
			return craft_items_script.get_quality_color(quality)
	match icon_type:
		"heal":
			return Color(0.2, 0.9, 0.3, 1)   # 绿色
		"ammo":
			return Color(0.9, 0.7, 0.2, 1)   # 金色
		"grenade":
			return Color(0.3, 0.5, 0.3, 1)   # 深绿
		"armor":
			return Color(0.3, 0.5, 0.8, 1)   # 蓝色
		_:
			return Color(0.6, 0.6, 0.6, 1)

func refresh() -> void:
	_populate_grid()
	_populate_armor_slot()

# ===== 拖动系统 =====

func _on_slot_gui_input(event: InputEvent, _cell: Control, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# 开始拖动
				_start_drag(slot_index, false)
			else:
				# 放下物品
				_end_drag_over_slot(slot_index)
	elif event is InputEventMouseMotion and is_dragging:
		# 更新高亮
		_update_drop_highlight(get_global_mouse_position())

func _on_inventory_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if is_dragging:
				_cancel_drag()

func _start_drag(slot_index: int, from_ammo_box: bool) -> void:
	var data = slots[slot_index]
	if data["name"] == "":
		return
	
	is_dragging = true
	drag_source_index = slot_index
	drag_source_is_ammo_box = from_ammo_box
	drag_item_data = data.duplicate(true)
	
	# 创建拖动预览
	_create_drag_preview()
	
	# 隐藏原格子物品（用半透明效果）
	_set_slot_dimmed(slot_index, true)

func start_drag_from_ammo_box(item_data: Dictionary) -> void:
	# 从弹药箱开始拖动
	is_dragging = true
	drag_source_index = -1
	drag_source_is_ammo_box = true
	drag_item_data = item_data.duplicate(true)
	
	# 创建拖动预览
	_create_drag_preview()

func _create_drag_preview() -> void:
	if drag_preview:
		drag_preview.queue_free()
	
	drag_preview = PanelContainer.new()
	drag_preview.custom_minimum_size = Vector2(80, 80)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_border_color(Color(1, 1, 1, 1))
	style.set_corner_radius_all(4)
	drag_preview.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	drag_preview.add_child(vbox)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.color = _get_item_color(drag_item_data.get("icon", ""))
	vbox.add_child(icon)
	
	var label = Label.new()
	label.text = "x" + str(drag_item_data.get("count", 1))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)
	
	add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position() - Vector2(40, 40)

func _end_drag_over_slot(target_index: int) -> void:
	if not is_dragging:
		return
	
	var target_data = slots[target_index]
	
	if target_data["name"] == "":
		# 目标格子为空，直接移动
		slots[target_index] = drag_item_data.duplicate(true)
		slots[target_index]["id"] = target_index
		
		# 清空源格子
		if drag_source_index >= 0:
			slots[drag_source_index] = {
				"id": drag_source_index,
				"name": "",
				"icon": "",
				"count": 0,
				"description": "",
				"is_ammo": false
			}
		
		_update_after_drop()
	elif target_data["name"] == drag_item_data["name"] and target_data["icon"] == drag_item_data["icon"]:
		# 同类物品，叠加
		_add_to_slot(target_index, drag_item_data["count"])
		
		# 清空源格子
		if drag_source_index >= 0:
			slots[drag_source_index] = {
				"id": drag_source_index,
				"name": "",
				"icon": "",
				"count": 0,
				"description": "",
				"is_ammo": false
			}
		
		_update_after_drop()
	else:
		# 不同类物品，交换位置
		var temp = slots[target_index].duplicate(true)
		slots[target_index] = drag_item_data.duplicate(true)
		slots[target_index]["id"] = target_index
		
		if drag_source_index >= 0:
			slots[drag_source_index] = temp
			slots[drag_source_index]["id"] = drag_source_index
		
		_update_after_drop()
	
	_end_drag()

func _add_to_slot(slot_index: int, amount: int) -> void:
	slots[slot_index]["count"] += amount
	# 如果是弹药，同步到玩家数据
	if slots[slot_index].get("is_ammo", false):
		_sync_ammo_to_player()

func _set_slot_dimmed(slot_index: int, dimmed: bool) -> void:
	var grid = $VBox/GridScroll/Grid
	if not grid:
		return
	var cell = grid.get_node_or_null("Slot_" + str(slot_index))
	if cell:
		var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if dimmed:
				style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
			else:
				style.bg_color = Color(0.2, 0.2, 0.2, 0.9)

func _update_drop_highlight(mouse_pos: Vector2) -> void:
	var grid = $VBox/GridScroll/Grid
	if not grid:
		return
	
	for i in range(SLOT_COUNT):
		var cell = grid.get_node_or_null("Slot_" + str(i))
		if cell:
			var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				if cell.get_global_rect().has_point(mouse_pos):
					# 高亮目标格子
					if slots[i]["name"] == drag_item_data["name"]:
						style.border_color = Color(0.2, 0.9, 0.3, 1)  # 绿色表示可叠加
					else:
						style.border_color = Color(0.9, 0.7, 0.2, 1)  # 黄色表示可放置
				else:
					style.border_color = Color(0.4, 0.4, 0.4, 0.8)  # 恢复默认

func _update_after_drop() -> void:
	refresh()
	_sync_ammo_to_player()

func _sync_ammo_to_player() -> void:
	var player = _get_player()
	if player and player.has_method("set_reserve_ammo"):
		# 弹药同步：slot["count"] 直接同步到玩家（slot 已经是增量后的值）
		for slot in slots:
			if slot.get("is_ammo", false) and slot["name"] != "":
				print("[Inventory] _sync_ammo_to_player 同步弹药: ", slot["count"])
				player.set_reserve_ammo(slot["count"])
				break

# 从玩家同步弹药数据到背包（用于换弹时调用）
func sync_from_player() -> void:
	var player = _get_player()
	if not player:
		return
	var player_ammo = player.get_reserve_ammo()
	for slot in slots:
		if slot.get("is_ammo", false) and slot["name"] != "":
			slot["count"] = player_ammo
			print("[Inventory] sync_from_player 同步弹药格为: ", player_ammo)
			break
	refresh()

func _end_drag() -> void:
	is_dragging = false
	drag_source_index = -1
	drag_source_is_ammo_box = false
	drag_item_data = {}
	
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func _cancel_drag() -> void:
	# 恢复源格子
	if drag_source_index >= 0:
		_set_slot_dimmed(drag_source_index, false)
	
	_end_drag()
	refresh()

# 获取可以接收物品的格子数量
func get_empty_slot_count() -> int:
	var count = 0
	for slot in slots:
		if slot["name"] == "":
			count += 1
	return count

# 添加物品到背包（从弹药箱）
func add_item_from_ammo_box(item_data: Dictionary) -> bool:
	# 先尝试叠加
	for slot in slots:
		if slot["name"] == item_data["name"] and slot["icon"] == item_data["icon"]:
			slot["count"] += item_data["count"]
			_update_after_drop()
			return true
	
	# 找空格子
	for i in range(slots.size()):
		if slots[i]["name"] == "":
			slots[i] = item_data.duplicate(true)
			slots[i]["id"] = i
			_update_after_drop()
			return true
	
	return false

# 获取弹药数量
func get_ammo_count() -> int:
	for slot in slots:
		if slot.get("is_ammo", false) and slot["name"] != "":
			print("[Inventory] get_ammo_count() 返回: ", slot["count"])
			return slot["count"]
	print("[Inventory] get_ammo_count() 未找到弹药格，返回 0")
	return 0
