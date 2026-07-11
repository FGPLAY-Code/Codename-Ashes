extends PanelContainer

## 背包库存 UI — Win11 Mica/Acrylic 设计风格
## 数据逻辑在内部管理，保持与原版相同的公开 API 接口

# ===== 设计令牌（参考 LVMO_GAME 设计系统） =====
const C_ACCENT := Color(0.376, 0.804, 1.0)        # #60cdff
const C_ACCENT_HOVER := Color(0.231, 0.718, 0.941)
const C_BG_ACRYLIC := Color(0.918, 0.929, 0.961, 0.78)
const C_BG_CARD := Color(1.0, 1.0, 1.0, 0.35)
const C_BG_CARD_HOVER := Color(1.0, 1.0, 1.0, 0.50)
const C_BORDER := Color(0.0, 0.078, 0.235, 0.12)
const C_TEXT := Color(0.067, 0.094, 0.153)         # #111827
const C_TEXT_SEC := Color(0.067, 0.094, 0.153, 0.65)
const C_TEXT_TER := Color(0.067, 0.094, 0.153, 0.40)
const C_SUCCESS := Color(0.212, 0.769, 0.239)
const C_DANGER := Color(0.910, 0.067, 0.137)
const C_WARNING := Color(0.992, 0.737, 0.251)

# 深色主题
const C_BG_ACRYLIC_DARK := Color(0.078, 0.098, 0.157, 0.85)
const C_BG_CARD_DARK := Color(0.157, 0.176, 0.255, 0.55)
const C_BG_CARD_HOVER_DARK := Color(0.157, 0.176, 0.255, 0.70)
const C_BORDER_DARK := Color(0.471, 0.706, 1.0, 0.10)
const C_TEXT_DARK := Color(0.910, 0.929, 0.961)
const C_TEXT_SEC_DARK := Color(0.784, 0.843, 0.941, 0.65)
const C_TEXT_TER_DARK := Color(0.706, 0.784, 0.902, 0.40)

const CELL_SIZE := 80
const ARMOR_CELL_SIZE := 240
const SLOT_COUNT := 28
const RADIUS := 7.0

# 品质颜色
const QUALITY_COLORS := {
	"green":  Color(0.212, 0.769, 0.239),
	"blue":   Color(0.255, 0.553, 0.953),
	"purple": Color(0.624, 0.392, 0.902)
}
const QUALITY_LABELS := {
	"green":  "[普通]",
	"blue":   "[稀有]",
	"purple": "[史诗]"
}

# ===== 背包数据 =====
var slots: Array[Dictionary] = []
var armor_slot: Dictionary = {}

# ===== 拖动系统 =====
var is_dragging: bool = false
var drag_source_index: int = -1
var drag_source_is_ammo_box: bool = false
var drag_item_data: Dictionary = {}
var drag_preview: Control = null

# ===== 主题状态 =====
var _dark_mode := true  # 游戏内使用深色

# ===== 节点引用（缓存）=====
@onready var _grid: GridContainer = $VBox/GridScroll/Grid
@onready var _armor_container: PanelContainer = $VBox/ArmorRow/ArmorSlot

# ===================================================================
# 生命周期
# ===================================================================

func _ready():
	_initialize_slots()
	refresh()
	gui_input.connect(_on_inventory_gui_input)
	_init_ammo_when_ready()

func _process(_delta):
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - Vector2(40, 40)

# ===================================================================
# 数据初始化
# ===================================================================

func _initialize_slots():
	slots.clear()
	for i in SLOT_COUNT:
		slots.append({ "id": i, "name": "", "icon": "", "count": 0,
			"description": "", "is_ammo": false, "quality": "" })
	slots[0] = { "id": 0, "name": "7.62x39mm", "icon": "ammo", "count": 0,
		"description": "步枪弹药（备弹）", "is_ammo": true, "quality": "" }
	armor_slot = { "name": "防弹衣", "icon": "armor", "count": 1,
		"description": "增加 50 点护甲", "quality": "" }

func _init_ammo_when_ready():
	var wait = 0.0
	while wait < 3.0:
		await get_tree().process_frame
		wait += 0.016
		var p = _get_player()
		if p:
			var ammo = _get_reserve_ammo()
			for s in slots:
				if s.get("is_ammo") and s.name != "":
					s.count = ammo
					break
			refresh()
			return
	print("[Inventory] 等待超时，未找到玩家")

# ===================================================================
# 公开 API（保持与原版一致，供外部调用）
# ===================================================================

func refresh():
	_populate_grid()
	_populate_armor_slot()

func get_empty_slot_count() -> int:
	var c = 0
	for s in slots:
		if s.name == "": c += 1
	return c

func add_item_from_ammo_box(item_data: Dictionary) -> bool:
	for s in slots:
		if s.name == item_data.name and s.icon == item_data.icon:
			s.count += item_data.count
			_update_after_drop()
			return true
	for i in slots.size():
		if slots[i].name == "":
			slots[i] = item_data.duplicate(true)
			slots[i].id = i
			_update_after_drop()
			return true
	return false

func get_ammo_count() -> int:
	for s in slots:
		if s.get("is_ammo") and s.name != "":
			return s.count
	return 0

func sync_from_player():
	var p = _get_player()
	if not p: return
	var pa = p.get_reserve_ammo()
	for s in slots:
		if s.get("is_ammo") and s.name != "":
			s.count = pa
			break
	refresh()

func start_drag_from_ammo_box(item_data: Dictionary):
	is_dragging = true
	drag_source_index = -1
	drag_source_is_ammo_box = true
	drag_item_data = item_data.duplicate(true)
	_create_drag_preview()

# ===================================================================
# UI 构建
# ===================================================================

func _make_style(bg: Color, border: Color, radius: float = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(radius)
	return s

func _populate_grid():
	if not _grid: return
	for c in _grid.get_children(): c.queue_free()
	for i in SLOT_COUNT:
		_grid.add_child(_create_cell(i))

func _create_cell(idx: int) -> Control:
	var data = slots[idx]
	var cell = PanelContainer.new()
	cell.name = "Slot_%d" % idx
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.set_meta("slot_index", idx)

	# Mica/Acrylic Card 风格
	var bg = C_BG_CARD_DARK if _dark_mode else C_BG_CARD
	var bdr = C_BORDER_DARK if _dark_mode else C_BORDER
	if data.name != "" and data.get("quality", "") != "":
		bdr = _quality_color(data.get("quality", ""))
	cell.add_theme_stylebox_override("panel", _make_style(bg, bdr))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
	cell.add_child(vb)

	if data.name == "":
		var hint = Label.new()
		hint.text = "+"
		hint.add_theme_font_size_override("font_size", 20)
		hint.add_theme_color_override("font_color", C_TEXT_TER_DARK if _dark_mode else C_TEXT_TER)
		vb.add_child(hint)
	else:
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = _item_color(data.icon, data.get("quality", ""))
		vb.add_child(icon)

		var nl = Label.new()
		nl.text = data.name
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(CELL_SIZE - 12, 0)
		nl.add_theme_font_size_override("font_size", 11)
		nl.add_theme_color_override("font_color", _quality_color(data.get("quality", "")) if data.get("quality", "") != "" else (C_TEXT_DARK if _dark_mode else C_TEXT))
		vb.add_child(nl)

		if data.count > 1 or data.get("is_ammo"):
			var cl = Label.new()
			if data.get("is_ammo"):
				cl.text = "x" + str(_get_reserve_ammo())
			else:
				cl.text = "x" + str(data.count)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.add_theme_font_size_override("font_size", 12)
			cl.add_theme_color_override("font_color", C_WARNING)
			vb.add_child(cl)

		if data.get("quality", "") != "":
			var ql = Label.new()
			ql.text = QUALITY_LABELS.get(data.get("quality", ""), "")
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ql.add_theme_font_size_override("font_size", 9)
			ql.add_theme_color_override("font_color", _quality_color(data.get("quality", "")))
			vb.add_child(ql)

	cell.gui_input.connect(_on_slot_gui_input.bind(cell, idx))
	return cell

func _populate_armor_slot():
	if not _armor_container: return
	for c in _armor_container.get_children(): c.queue_free()

	var st = _make_style(
		Color(0.15, 0.25, 0.45, 0.85) if armor_slot.name != "" else (C_BG_CARD_DARK if _dark_mode else C_BG_CARD),
		C_ACCENT, RADIUS)
	st.set_border_width_all(2)
	_armor_container.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_armor_container.add_child(vb)

	if armor_slot.name != "":
		var ic = ColorRect.new()
		ic.custom_minimum_size = Vector2(100, 100)
		ic.color = _item_color(armor_slot.icon, armor_slot.get("quality", ""))
		vb.add_child(ic)

		var nl = Label.new()
		nl.text = armor_slot.name
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 18)
		nl.add_theme_color_override("font_color", C_TEXT_DARK if _dark_mode else C_TEXT)
		vb.add_child(nl)

		var dl = Label.new()
		dl.text = armor_slot.description
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_font_size_override("font_size", 13)
		dl.add_theme_color_override("font_color", C_TEXT_SEC_DARK if _dark_mode else C_TEXT_SEC)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(ARMOR_CELL_SIZE - 20, 0)
		vb.add_child(dl)
	else:
		var el = Label.new()
		el.text = "防弹衣槽（空）"
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.add_theme_font_size_override("font_size", 16)
		el.add_theme_color_override("font_color", C_TEXT_TER_DARK if _dark_mode else C_TEXT_TER)
		vb.add_child(el)

# ===================================================================
# 拖动系统
# ===================================================================

func _on_slot_gui_input(event: InputEvent, _cell: Control, idx: int):
	if event is InputEventMouseButton:
		var me = event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_LEFT:
			if me.pressed: _start_drag(idx, false)
			else: _end_drag_over_slot(idx)
	elif event is InputEventMouseMotion and is_dragging:
		_update_drop_highlight(get_global_mouse_position())

func _on_inventory_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var me = event as InputEventMouseButton
		if me.button_index == MOUSE_BUTTON_LEFT and not me.pressed and is_dragging:
			_cancel_drag()

func _start_drag(idx: int, from_box: bool):
	var d = slots[idx]
	if d.name == "": return
	is_dragging = true
	drag_source_index = idx
	drag_source_is_ammo_box = from_box
	drag_item_data = d.duplicate(true)
	_create_drag_preview()
	_set_slot_dimmed(idx, true)

func _create_drag_preview():
	if drag_preview: drag_preview.queue_free()
	drag_preview = PanelContainer.new()
	drag_preview.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	drag_preview.add_theme_stylebox_override("panel", _make_style(
		C_ACCENT * Color(1,1,1,0.85), Color(1,1,1,1), RADIUS))
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	drag_preview.add_child(vb)
	var ic = ColorRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.color = _item_color(drag_item_data.get("icon", ""), drag_item_data.get("quality", ""))
	vb.add_child(ic)
	var lb = Label.new()
	lb.text = "x" + str(drag_item_data.get("count", 1))
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(lb)
	add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position() - Vector2(40, 40)

func _end_drag_over_slot(target: int):
	if not is_dragging: return
	var td = slots[target]
	if td.name == "":
		slots[target] = drag_item_data.duplicate(true)
		slots[target].id = target
		if drag_source_index >= 0: _clear_slot(drag_source_index)
		_update_after_drop()
	elif td.name == drag_item_data.name and td.icon == drag_item_data.icon:
		_add_to_slot(target, drag_item_data.count)
		if drag_source_index >= 0: _clear_slot(drag_source_index)
		_update_after_drop()
	else:
		var tmp = slots[target].duplicate(true)
		slots[target] = drag_item_data.duplicate(true)
		slots[target].id = target
		if drag_source_index >= 0:
			slots[drag_source_index] = tmp
			slots[drag_source_index].id = drag_source_index
		_update_after_drop()
	_end_drag()

func _add_to_slot(idx: int, amount: int):
	slots[idx].count += amount
	if slots[idx].get("is_ammo"):
		_sync_ammo_to_player()

func _set_slot_dimmed(idx: int, dim: bool):
	var cell = _grid.get_node_or_null("Slot_%d" % idx) if _grid else null
	if cell:
		var bg = Color(0.078, 0.098, 0.157, 0.50) if dim else (C_BG_CARD_DARK if _dark_mode else C_BG_CARD)
		var st = cell.get_theme_stylebox("panel") as StyleBoxFlat
		if st: st.bg_color = bg

func _update_drop_highlight(mpos: Vector2):
	if not _grid: return
	for i in SLOT_COUNT:
		var cell = _grid.get_node_or_null("Slot_%d" % i)
		if not cell: continue
		var st = cell.get_theme_stylebox("panel") as StyleBoxFlat
		if not st: continue
		if cell.get_global_rect().has_point(mpos):
			var bdr = C_SUCCESS if slots[i].name == drag_item_data.name else C_WARNING
			st.border_color = bdr
		else:
			var d = slots[i]
			st.border_color = _quality_color(d.get("quality", "")) if d.get("quality", "") != "" else (C_BORDER_DARK if _dark_mode else C_BORDER)

func _update_after_drop():
	refresh()
	_sync_ammo_to_player()

func _clear_slot(idx: int):
	var s = slots[idx]
	s.name = ""; s.icon = ""; s.count = 0
	s.description = ""; s.is_ammo = false; s.quality = ""

func _end_drag():
	is_dragging = false
	drag_source_index = -1
	drag_source_is_ammo_box = false
	drag_item_data = {}
	if drag_preview: drag_preview.queue_free(); drag_preview = null

func _cancel_drag():
	if drag_source_index >= 0: _set_slot_dimmed(drag_source_index, false)
	_end_drag()
	refresh()

# ===================================================================
# 玩家数据同步
# ===================================================================

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("Player")

func _get_reserve_ammo() -> int:
	var p = _get_player()
	if p and p.has_method("get_reserve_ammo"):
		return p.get_reserve_ammo()
	return 90

func _sync_ammo_to_player():
	var p = _get_player()
	if p and p.has_method("set_reserve_ammo"):
		for s in slots:
			if s.get("is_ammo") and s.name != "":
				p.set_reserve_ammo(s.count)
				break

# ===================================================================
# 颜色工具
# ===================================================================

func _quality_color(q: String) -> Color:
	return QUALITY_COLORS.get(q, C_ACCENT)

func _item_color(icon_type: String, quality: String = "") -> Color:
	if quality != "":
		var ci = load("res://scripts/craft_items.gd")
		if ci: return ci.get_quality_color(quality)
	match icon_type:
		"heal":    return Color(0.2, 0.9, 0.3)
		"ammo":    return Color(0.9, 0.7, 0.2)
		"grenade": return Color(0.3, 0.5, 0.3)
		"armor":   return Color(0.3, 0.5, 0.8)
		_:         return Color(0.6, 0.6, 0.6)
