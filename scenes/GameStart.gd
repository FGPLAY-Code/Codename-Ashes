extends Control

const SAVE_FILE_PATH = "user://player_data.cfg"
const AMMO_PRICE_PER_30 = 30000
const AMMO_PRICE_PER_BULLET = 100

# 联机模式状态
enum Mode { OFFLINE, CONNECTING, ONLINE }
var current_mode: int = Mode.OFFLINE

@onready var cash_label: Label = %CashLabel
@onready var action_button: Button = %ActionButton
@onready var mode_button: Button = %ModeButton
@onready var player_name_label: Label = %PlayerNameLabel
@onready var account_popup: PanelContainer = $AccountPopup
@onready var name_edit: LineEdit = $AccountPopup/VBox/NameEdit

var player_cash: int = 0
var player_name: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	load_player_data()
	_update_display()
	_update_mode_button()

func _has_network_manager() -> bool:
	return get_node_or_null("/root/NetworkManager") != null

func load_player_data() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	if err == OK:
		player_name = config.get_value("player", "name", "未知玩家")
		var saved_cash = config.get_value("player", "cash", 0)
		var inventory_value = calculate_inventory_value(config)
		player_cash = saved_cash + inventory_value
		print("[GameStart] 加载存档: saved_cash=¥", saved_cash, " inventory_value=¥", inventory_value, " total=¥", player_cash)
	else:
		player_name = "未知玩家"
		player_cash = 0

func calculate_inventory_value(config: ConfigFile) -> int:
	var total = 0
	var slots = config.get_value("inventory", "slots", [])
	for slot in slots:
		if slot is Dictionary:
			if slot.get("is_ammo", false):
				var ammo_count = slot.get("count", 0)
				var bundle30 = ammo_count / 30
				var remainder = ammo_count % 30
				total += bundle30 * AMMO_PRICE_PER_30
				total += remainder * AMMO_PRICE_PER_BULLET
			else:
				var sell_price = slot.get("sell_price", 0)
				var count = slot.get("count", 1)
				total += sell_price * count
	return total

func _format_cash(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _update_display() -> void:
	if cash_label:
		cash_label.text = "¥ " + _format_cash(player_cash)
	else:
		push_error("GameStart: CashLabel 节点未找到")
	if player_name_label:
		player_name_label.text = player_name
	else:
		push_error("GameStart: PlayerNameLabel 节点未找到")

# ================================================================
# 模式按钮逻辑
# ================================================================

func _update_mode_button() -> void:
	if not is_instance_valid(mode_button):
		return
	mode_button.disabled = false
	match current_mode:
		Mode.OFFLINE:
			mode_button.text = "模式：离线"
			mode_button.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Mode.CONNECTING:
			mode_button.text = "模式：连接中..."
			mode_button.disabled = true
			mode_button.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		Mode.ONLINE:
			mode_button.text = "模式：在线"
			mode_button.add_theme_color_override("font_color", Color(0.3, 0.6, 1))

func _on_mode_button_pressed() -> void:
	if current_mode == Mode.ONLINE:
		_disconnect_from_server()
		return
	if current_mode == Mode.CONNECTING:
		return
	_try_connect_to_server()

func _try_connect_to_server() -> void:
	_set_mode(Mode.CONNECTING)
	if not _has_network_manager():
		push_error("[GameStart] NetworkManager 未找到，请先将其添加为 AutoLoad")
		_set_mode(Mode.OFFLINE)
		return
	_test_server_http()

func _test_server_http() -> void:
	var server_http: String = "http://160.202.47.159:3000"  # 兜底地址
	if _has_network_manager():
		var nm = get_node("/root/NetworkManager")
		if "SERVER_HTTP" in nm:
			server_http = nm.SERVER_HTTP
	
	var http = HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	http.request_completed.connect(_on_http_test_completed.bind(http))
	var err = http.request(server_http + "/api/ping")
	if err != OK:
		_on_http_test_completed(0, 0, PackedStringArray(), PackedByteArray())

func _on_http_test_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: Variant = null) -> void:
	if is_instance_valid(mode_button):
		mode_button.disabled = false
	if response_code == 200:
		_set_mode(Mode.ONLINE)
		print("[GameStart] 服务器连接成功！")
	else:
		_set_mode(Mode.OFFLINE)
		print("[GameStart] 服务器连接失败（code=", response_code, "），保持离线模式")
	if http_request and is_instance_valid(http_request):
		http_request.queue_free()

func _set_mode(m: int) -> void:
	current_mode = m
	_update_mode_button()

func _disconnect_from_server() -> void:
	if _has_network_manager():
		var nm = get_node("/root/NetworkManager")
		if nm and nm.has_method("disconnect_from_server"):
			nm.disconnect_from_server()
		print("[GameStart] 已断开与服务器的连接")
	_set_mode(Mode.OFFLINE)

# ================================================================
# 原有逻辑
# ================================================================

func _on_action_button_pressed() -> void:
	if action_button:
		action_button.disabled = true
	
	# 根据当前模式决定跳转目标
	if current_mode == Mode.OFFLINE:
		# 离线模式：直接进入游戏（单人）
		_clear_inventory_cache()
		get_tree().change_scene_to_file("res://scenes/AshRavine.tscn")
	else:
		# 在线模式：先选择游玩模式
		get_tree().change_scene_to_file("res://scenes/GameSelect.tscn")

func _clear_inventory_cache() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	if err == OK:
		config.set_value("inventory", "slots", [])
		config.set_value("player", "cash", config.get_value("player", "cash", 0))
		config.save(SAVE_FILE_PATH)
		print("[GameStart] 背包已清空，开始新一局")

func _on_account_button_pressed() -> void:
	name_edit.text = player_name
	account_popup.visible = true

func _on_change_name_pressed() -> void:
	var new_name = name_edit.text.strip_edges()
	if new_name.is_empty():
		print("[GameStart] 账户名不能为空")
		return
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	if err == OK:
		config.set_value("player", "name", new_name)
		config.save(SAVE_FILE_PATH)
		player_name = new_name
		_update_display()
		print("[GameStart] 账户名已修改为: ", new_name)
		account_popup.visible = false
	else:
		print("[GameStart] 保存失败")

func _on_logout_pressed() -> void:
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("player_data.cfg"):
		dir.remove("player_data.cfg")
		print("[GameStart] 账号已注销，所有数据已清除")
	get_tree().change_scene_to_file("res://scenes/Start.tscn")

func _on_close_popup_pressed() -> void:
	account_popup.visible = false
