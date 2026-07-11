## Rooms.gd
## 房间内场景 - 创建/加入房间后显示
## UI 风格参照 GameStart.tscn

extends Control

# ================================================================
# UI 节点
# ================================================================
var title_label: Label
var player_list: VBoxContainer
var player_scroll: ScrollContainer
var leave_button: Button
var start_button: Button

# ================================================================
# 状态
# ================================================================
var _is_host: bool = false

# ================================================================
# 生命周期
# ================================================================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_find_nodes()
	_connect_signals()

	# 初始加载房间数据
	_refresh_room()

# 手动查找所有 UI 节点（避免缓存问题）
func _find_nodes() -> void:
	title_label = _search_by_name(self, "TitleLabel")
	player_scroll = _search_by_name(self, "PlayerScroll")
	player_list = _search_by_name(self, "PlayerList")
	leave_button = _search_by_name(self, "LeaveButton")
	start_button = _search_by_name(self, "StartButton")
	print("[Rooms] 节点获取: title=", title_label, " player_list=", player_list, " leave=", leave_button, " start=", start_button)

# 递归按名称查找节点
func _search_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var r = _search_by_name(child, name)
		if r: return r
	return null

# ================================================================
# 信号连接
# ================================================================

func _connect_signals() -> void:
	if leave_button:
		leave_button.pressed.connect(_on_leave_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.connect("room_updated",        Callable(self, "_on_room_updated"))
		nm.connect("player_joined_room",  Callable(self, "_on_player_joined_room"))
		nm.connect("player_left_room",    Callable(self, "_on_player_left_room"))
		nm.connect("kicked_from_room",   Callable(self, "_on_kicked_from_room"))
		nm.connect("game_started",        Callable(self, "_on_game_started"))

# ================================================================
# 刷新房间
# ================================================================

func _refresh_room() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if not nm:
		return

	# 从 NetworkManager 获取玩家列表，并计算是否为房主
	var players = nm.get_player_list()
	_is_host = false

	for p in players:
		var socket_id = p.get("socket_id", "")
		if p.get("is_host", false) and socket_id != "":
			# 尝试判断本玩家是否房主（与服务端 socket.id 比对）
			# 服务端在 room_joined 回调里没返回自己的 socket_id，
			# 所以暂时用玩家列表第一个 is_host 来决定 StartButton 显隐
			_is_host = p.get("is_host", false)
			break

	_update_ui()

func _update_ui() -> void:
	# 标题显示当前房间名
	if title_label:
		var nm = get_node_or_null("/root/NetworkManager")
		var room_id = nm.get_current_room_id() if nm else ""
		title_label.text = "房间 - %s" % room_id

	# 仅房主显示"开始游戏"按钮
	if start_button:
		start_button.visible = _is_host

	# 刷新玩家列表
	_build_player_list()

# ================================================================
# 构建玩家列表
# ================================================================

func _build_player_list() -> void:
	if not player_list:
		return

	# 清空旧条目
	for child in player_list.get_children():
		child.queue_free()

	var nm = get_node_or_null("/root/NetworkManager")
	var players = nm.get_player_list() if nm else []

	if players.size() == 0:
		var empty = Label.new()
		empty.text = "暂无玩家，等待加入..."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		player_list.add_child(empty)
		return

	for p in players:
		var item = _make_player_item(p)
		player_list.add_child(item)

# 单个玩家条目：【用户名                         socket_id】【踢出按钮】
func _make_player_item(p: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 40)

	var name_str = p.get("name", "未知")
	var socket_str = p.get("socket_id", "?.?.?.?")
	var is_host = p.get("is_host", false)

	# 用户名标签（占满左侧剩余空间）
	var name_lbl = Label.new()
	name_lbl.text = name_str + (" [房主]" if is_host else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# socket_id 作为标识（代替 IP 显示）
	var id_lbl = Label.new()
	id_lbl.text = socket_str
	id_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	id_lbl.add_theme_font_size_override("font_size", 14)
	id_lbl.custom_minimum_size = Vector2(160, 0)
	id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(id_lbl)

	# 踢出按钮（仅房主可见，不能踢自己）
	if _is_host and not is_host:
		var kick_btn = Button.new()
		kick_btn.text = "踢出"
		kick_btn.custom_minimum_size = Vector2(80, 0)
		var target_id = socket_str
		kick_btn.pressed.connect(func(): _on_kick_pressed(target_id, name_str))
		hbox.add_child(kick_btn)

	return hbox

# ================================================================
# 按钮回调
# ================================================================

func _on_leave_pressed() -> void:
	print("[Rooms] 退出房间")
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("leave_room"):
		nm.leave_room()
	get_tree().change_scene_to_file("res://scenes/GameRooms.tscn")

func _on_start_pressed() -> void:
	if not _is_host:
		return
	print("[Rooms] 房主开始游戏")
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("start_game"):
		nm.start_game()

func _on_kick_pressed(target_socket_id: String, username: String) -> void:
	if not _is_host:
		return
	print("[Rooms] 踢出玩家: ", username, " (", target_socket_id, ")")
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("kick_player"):
		nm.kick_player(target_socket_id)

# ================================================================
# NetworkManager 信号回调
# ================================================================

func _on_room_updated(data: Dictionary) -> void:
	print("[Rooms] room_updated: ", data)
	_refresh_room()

func _on_player_joined_room(data: Dictionary) -> void:
	print("[Rooms] player_joined: ", data)
	_refresh_room()

func _on_player_left_room(data: Dictionary) -> void:
	print("[Rooms] player_left: ", data)
	_refresh_room()

func _on_kicked_from_room(data: Dictionary) -> void:
	print("[Rooms] 被踢出房间: ", data.get("kicker", "房主"))
	_show_kicked_popup(data.get("kicker", "房主"))

func _on_game_started(data: Dictionary) -> void:
	print("[Rooms] 游戏开始，跳转到 AshRavine")
	get_tree().change_scene_to_file("res://scenes/AshRavine.tscn")

# ================================================================
# 被踢弹出提示（2秒后自动返回房间列表）
# ================================================================

func _show_kicked_popup(kicker_name: String) -> void:
	var popup = PopupPanel.new()
	popup.set_size(Vector2(400, 150))
	popup.set_position(
		get_viewport_rect().size / 2 - Vector2(200, 75)
	)

	var vbox = VBoxContainer.new()
	popup.add_child(vbox)

	var msg = Label.new()
	msg.text = "你被 %s 移出房间" % kicker_name
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 22)
	vbox.add_child(msg)

	var hint = Label.new()
	hint.text = "正在返回房间列表..."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

	add_child(popup)
	popup.popup()

	# 2秒后返回 GameRooms
	var timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(func():
		popup.queue_free()
		get_tree().change_scene_to_file("res://scenes/GameRooms.tscn")
	)
	add_child(timer)
	timer.start(2.0)