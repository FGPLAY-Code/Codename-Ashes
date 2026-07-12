## GameRooms.gd
## 房间列表界面（在线模式）

extends Control

# ================================================================
# UI 节点 - 全部在 _ready 里手动获取
# ================================================================
var status_label: Label
var room_scroll: ScrollContainer
var room_list: VBoxContainer
var create_button: Button
var connect_button: Button
var refresh_button: Button
var back_button: Button
var _create_dialog: PanelContainer
var dlg_name_edit: LineEdit
var dlg_public_check: CheckBox
var dlg_confirm: Button
var dlg_cancel: Button
var _connect_dialog: PanelContainer
var code_edit: LineEdit
var conn_confirm: Button
var conn_cancel: Button

var _room_items: Array = []

# ================================================================
# 生命周期
# ================================================================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[GameRooms] _ready()")

	# 获取所有节点
	_find_nodes()

	# 隐藏弹窗
	if _create_dialog: _create_dialog.hide()
	if _connect_dialog: _connect_dialog.hide()

	# 连接 NetworkManager 信号
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		if nm.has_signal("room_list_updated"):
			nm.room_list_updated.connect(_on_room_list_updated)
		if nm.has_signal("room_created"):
			nm.room_created.connect(_on_room_created)
		if nm.has_signal("room_create_failed"):
			nm.room_create_failed.connect(_on_room_create_failed)
		if nm.has_signal("room_joined"):
			nm.room_joined.connect(_on_room_joined)
		if nm.has_signal("room_join_failed"):
			nm.room_join_failed.connect(_on_room_join_failed)
		if nm.has_signal("disconnected_from_server"):
			nm.disconnected_from_server.connect(_on_disconnected)
		if nm.has_signal("connected_to_server"):
			nm.connected_to_server.connect(_on_connected_to_server)

	# 连接 UI 信号
	if create_button: create_button.pressed.connect(_on_create_pressed)
	if connect_button: connect_button.pressed.connect(_on_connect_pressed)
	if refresh_button: refresh_button.pressed.connect(_on_refresh_pressed)
	if back_button: back_button.pressed.connect(_on_back_pressed)
	if dlg_confirm: dlg_confirm.pressed.connect(_on_create_confirm)
	if dlg_cancel: dlg_cancel.pressed.connect(_close_dialogs)
	if conn_confirm: conn_confirm.pressed.connect(_on_connect_confirm)
	if conn_cancel: conn_cancel.pressed.connect(_close_dialogs)

	# 根据连接状态决定是否允许操作
	_update_connection_ui()

## 递归查找所有UI节点
func _find_nodes() -> void:
	status_label = _search_by_name(self, "StatusLabel")
	room_scroll = _search_by_name(self, "RoomScroll")
	room_list = _search_by_name(self, "RoomList")
	create_button = _search_by_name(self, "CreateButton")
	connect_button = _search_by_name(self, "ConnectButton")
	refresh_button = _search_by_name(self, "RefreshButton")
	back_button = _search_by_name(self, "BackButton")
	_create_dialog = _search_by_name(self, "CreateDialog")
	dlg_name_edit = _search_by_name(self, "NameEdit")
	dlg_public_check = _search_by_name(self, "PublicCheck")
	dlg_confirm = _search_by_name(self, "ConfirmBtn")
	# CreateDialog 下的 CancelBtn
	var all_cancel1 = _search_all_by_name(_create_dialog, "CancelBtn")
	if all_cancel1.size() > 0: dlg_cancel = all_cancel1[0]
	_connect_dialog = _search_by_name(self, "ConnectDialog")
	code_edit = _search_by_name(self, "CodeEdit")
	var all_confirm2 = _search_all_by_name(_connect_dialog, "ConfirmBtn")
	if all_confirm2.size() > 0: conn_confirm = all_confirm2[0]
	var all_cancel2 = _search_all_by_name(_connect_dialog, "CancelBtn")
	if all_cancel2.size() > 0: conn_cancel = all_cancel2[0]

	# 调试输出
	print("[GameRooms] 节点获取结果:")
	print("  status_label=", status_label)
	print("  room_list=", room_list)
	print("  create_button=", create_button)
	print("  _create_dialog=", _create_dialog)
	print("  _connect_dialog=", _connect_dialog)
	print("  dlg_name_edit=", dlg_name_edit)

## 按名称递归查找第一个匹配节点
func _search_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _search_by_name(child, name)
		if result:
			return result
	return null

## 按名称递归查找所有匹配节点
func _search_all_by_name(node: Node, name: String) -> Array:
	var result := []
	if node.name == name:
		result.append(node)
	for child in node.get_children():
		var sub = _search_all_by_name(child, name)
		for r in sub:
			result.append(r)
	return result

# ================================================================
# 刷新列表
# ================================================================

func _refresh_list() -> void:
	if status_label: status_label.text = "正在获取房间列表..."
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("get_room_list"):
		nm.get_room_list()
	else:
		if status_label: status_label.text = "NetworkManager 不可用"

# ================================================================
# NetworkManager 信号回调
# ================================================================

func _on_room_list_updated(rooms: Array) -> void:
	_room_items = rooms
	_clear_room_list()
	if rooms.size() == 0:
		if status_label: status_label.text = "暂无公开房间，创建一个吧！"
		return
	if status_label: status_label.text = "找到 %d 个房间" % rooms.size()
	for room in rooms:
		var item = _make_room_item(room)
		if room_list: room_list.add_child(item)

func _on_room_created(room_id: String) -> void:
	print("[GameRooms] 房间创建成功: ", room_id)
	# 创建成功后进入房间场景
	get_tree().change_scene_to_file("res://scenes/Rooms.tscn")

func _on_room_create_failed(error: String) -> void:
	push_error("[GameRooms] 创建房间失败: " + error)
	if status_label: status_label.text = "创建失败: " + error

func _on_room_joined(data: Dictionary) -> void:
	print("[GameRooms] 加入房间成功: ", data.get("room_id"))
	get_tree().change_scene_to_file("res://scenes/Rooms.tscn")

func _on_room_join_failed(error: String) -> void:
	push_error("[GameRooms] 加入失败: " + error)
	if status_label: status_label.text = "错误: " + error

func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/GameSelect.tscn")

func _on_connected_to_server() -> void:
	print("[GameRooms] WebSocket 连接成功，刷新房间列表")
	_update_connection_ui()
	_refresh_list()

## 根据连接状态更新 UI（按钮启用/禁用 + 状态提示）
func _update_connection_ui() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	var connected: bool = nm != null and nm.has_method("is_connected_to_server") and nm.is_connected_to_server()
	if connected:
		if create_button: create_button.disabled = false
		if connect_button: connect_button.disabled = false
		if refresh_button: refresh_button.disabled = false
		_refresh_list()
	else:
		if create_button: create_button.disabled = true
		if connect_button: connect_button.disabled = true
		if refresh_button: refresh_button.disabled = true
		if status_label: status_label.text = "正在连接服务器..."
		# 若 NetworkManager 有 token 但未连接，主动尝试连接
		if nm and nm.has_method("is_logged_in") and nm.is_logged_in():
			if nm.has_method("connect_to_server"):
				nm.connect_to_server()
				print("[GameRooms] 主动触发 WebSocket 连接")

# ================================================================
# 按钮回调
# ================================================================

func _on_create_pressed() -> void:
	print("[GameRooms] 创建房间按钮")
	var nm = get_node_or_null("/root/NetworkManager")
	var player_name := "玩家"
	if nm and nm.has_method("get_player_data"):
		var pd = nm.get_player_data()
		if pd and pd.has("username"):
			player_name = pd["username"]
	if dlg_name_edit: dlg_name_edit.text = "%s的房间" % player_name
	if dlg_public_check: dlg_public_check.button_pressed = true
	if _create_dialog: _create_dialog.show()

func _on_connect_pressed() -> void:
	print("[GameRooms] 直接连接按钮")
	if code_edit: code_edit.text = ""
	if _connect_dialog: _connect_dialog.show()

func _on_refresh_pressed() -> void:
	_refresh_list()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameSelect.tscn")

# ================================================================
# 弹窗确认
# ================================================================

func _on_create_confirm() -> void:
	if _create_dialog: _create_dialog.hide()
	var room_name := ""
	var is_public := true
	if dlg_name_edit: room_name = dlg_name_edit.text.strip_edges()
	if dlg_public_check: is_public = dlg_public_check.button_pressed
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("create_room"):
		nm.create_room(room_name, is_public)
		if status_label: status_label.text = "正在创建房间..."
	else:
		push_error("[GameRooms] NetworkManager.create_room 不可用")

func _on_connect_confirm() -> void:
	if _connect_dialog: _connect_dialog.hide()
	var code := ""
	if code_edit: code = code_edit.text.strip_edges().to_upper()
	if code.length() < 4:
		if status_label: status_label.text = "房间码至少需要4位字符"
		return
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("join_private_room"):
		nm.join_private_room(code)
		if status_label: status_label.text = "正在通过房间码加入..."
	else:
		push_error("[GameRooms] NetworkManager.join_private_room 不可用")

func _close_dialogs() -> void:
	if _create_dialog: _create_dialog.hide()
	if _connect_dialog: _connect_dialog.hide()

# ================================================================
# 内部辅助
# ================================================================

func _clear_room_list() -> void:
	if not room_list: return
	for child in room_list.get_children():
		child.queue_free()
	_room_items.clear()

func _make_room_item(room: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var name_label := Label.new()
	name_label.text = "房间: %s" % room.get("name", "未知")
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)
	var info := Label.new()
	var map_name: String = room.get("map", "未知")
	var count: int = room.get("player_count", 0)
	var max_p: int = room.get("max_players", 9)
	info.text = "地图: %s | 人数: %d/%d | 房主: %s" % [map_name, count, max_p, room.get("host", "未知")]
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(info)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_join_room_by_id(room.get("id", ""))
	)
	return panel

func _join_room_by_id(room_id: String) -> void:
	if room_id.is_empty(): return
	print("[GameRooms] 请求加入房间: ", room_id)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("join_room"):
		nm.join_room(room_id)
		if status_label: status_label.text = "正在加入房间..."
	else:
		push_error("[GameRooms] NetworkManager.join_room 不可用")
