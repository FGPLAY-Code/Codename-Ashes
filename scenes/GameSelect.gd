## GameSelect.gd
## 游戏模式选择界面
## 从基地（GameStart）的"行动"按钮跳转而来（仅在线模式时显示）

extends Control

# ================================================================
# 节点引用
# ================================================================
@onready var status_label: Label = $CenterPanel/VBox/StatusLabel
@onready var online_button: Button = $CenterPanel/VBox/OnlineButton
@onready var offline_button: Button = $CenterPanel/VBox/OfflineButton
@onready var back_button: Button = $CenterPanel/VBox/BackButton
@onready var error_popup: CenterContainer = $ErrorPopup

# ================================================================
# 状态
# ================================================================
var _username: String = ""
var _server_ok: bool = false

# ================================================================
# 生命周期
# ================================================================

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 连接错误弹窗信号
	if error_popup:
		error_popup.connect("retry_requested", Callable(self, "_on_error_retry"))
		error_popup.connect("back_requested", Callable(self, "_on_error_back"))

# ================================================================
# 按钮回调
# ================================================================

func _on_offline_button_pressed() -> void:
	"""离线游玩：直接进入 AshRavine 场景（单人模式）"""
	print("[GameSelect] 选择离线游玩")
	get_tree().change_scene_to_file("res://scenes/AshRavine.tscn")

func _on_online_button_pressed() -> void:
	"""在线游玩：获取用户数据并检查服务器连接"""
	print("[GameSelect] 选择在线游玩，开始获取用户数据...")
	status_label.text = "正在检查服务器连接..."
	_set_buttons_disabled(true)
	_fetch_user_data()

func _on_back_button_pressed() -> void:
	"""返回基地（GameStart）"""
	print("[GameSelect] 返回基地")
	get_tree().change_scene_to_file("res://scenes/GameStart.tscn")

# ================================================================
# 错误弹窗回调
# ================================================================

func _on_error_retry() -> void:
	"""重试：重新获取用户数据并检查服务器"""
	print("[GameSelect] 重试获取用户信息...")
	error_popup.hide_error()
	status_label.text = "正在检查服务器连接..."
	_set_buttons_disabled(true)
	_fetch_user_data()

func _on_error_back() -> void:
	"""上一步：返回基地并设为离线模式"""
	print("[GameSelect] 返回基地并设为离线模式")
	error_popup.hide_error()
	# 返回 GameStart 并设为离线模式
	var tree := get_tree()
	tree.change_scene_to_file("res://scenes/GameStart.tscn")
	# 通过延迟调用设置模式（等场景加载完成）
	tree.create_timer(0.1).timeout.connect(func():
		var game_start = tree.get_root().get_child(tree.get_root().get_child_count() - 1)
		if game_start and game_start.has_method("_set_mode"):
			game_start._set_mode(0)  # Mode.OFFLINE = 0
	)

# ================================================================
# 用户数据获取
# ================================================================

func _fetch_user_data() -> void:
	"""获取用户名，并检查服务器连接"""
	# 1. 从本地存档读取用户名
	_load_username()
	
	# 2. 检查服务器连接
	_check_server_connection()

func _load_username() -> void:
	"""从本地存档读取用户名"""
	var config = ConfigFile.new()
	var err = config.load("user://player_data.cfg")
	if err == OK:
		_username = config.get_value("player", "name", "")
		print("[GameSelect] 读取用户名: ", _username)
	else:
		_username = ""
		push_error("[GameSelect] 读取用户数据失败")

func _check_server_connection() -> void:
	"""检查服务器连接"""
	var server_http: String = "http://160.202.47.159:3000"  # 兜底地址
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and "SERVER_HTTP" in nm:
		server_http = nm.SERVER_HTTP
	
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200:
			_server_ok = true
			print("[GameSelect] 服务器连接成功")
		else:
			_server_ok = false
			push_error("[GameSelect] 服务器连接失败: ", response_code)
		http.queue_free()
		_on_all_data_fetched()
	)
	http.request(server_http + "/api/ping")

func _on_all_data_fetched() -> void:
	"""所有数据获取完成，检查结果"""
	_set_buttons_disabled(false)
	
	# 检查是否有错误
	if _username.is_empty():
		_show_error("获取用户信息失败！", "无法读取本地用户数据，请检查存档文件。")
		return
	
	if not _server_ok:
		var server_addr: String = "160.202.47.159:3000"
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and "SERVER_HTTP" in nm:
			server_addr = nm.SERVER_HTTP.replace("http://", "").replace("https://", "")
		_show_error("无法连接至灰烬服务器！", "请检查网络连接后重试。\n服务器地址: " + server_addr)
		return
	
	# 所有检查通过
	status_label.text = "用户名: %s\n服务器连接正常" % [_username]
	print("[GameSelect] 用户数据获取成功，开始在线游戏")
	_start_online_game()

# ================================================================
# 辅助函数
# ================================================================

func _show_error(title: String, message: String) -> void:
	"""显示错误弹窗"""
	status_label.text = "获取用户信息失败！"
	if error_popup:
		error_popup.show_error(title, message)

func _set_buttons_disabled(disabled: bool) -> void:
	"""禁用/启用所有按钮"""
	online_button.disabled = disabled
	offline_button.disabled = disabled
	back_button.disabled = disabled

func _start_online_game() -> void:
	"""在线模式验证通过，跳转至房间列表"""
	print("[GameSelect] 在线验证通过，跳转至房间列表")
	
	# 确保 NetworkManager 已连接到服务器
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("is_connected_to_server") and not nm.is_connected_to_server():
		nm.connect_to_server()
	
	get_tree().change_scene_to_file("res://scenes/GameRooms.tscn")

func _has_network_manager() -> bool:
	return get_node_or_null("/root/NetworkManager") != null
