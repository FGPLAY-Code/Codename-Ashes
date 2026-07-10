extends Control

const SAVE_FILE_PATH = "user://player_data.cfg"
const AMMO_PRICE_PER_30 = 30000
const AMMO_PRICE_PER_BULLET = 100

@onready var cash_label: Label = %CashLabel
@onready var action_button: Button = %ActionButton
@onready var player_name_label: Label = %PlayerNameLabel
@onready var account_popup: PanelContainer = $AccountPopup
@onready var name_edit: LineEdit = $AccountPopup/VBox/NameEdit

var player_cash: int = 0
var player_name: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	load_player_data()
	_update_display()

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

func _on_action_button_pressed() -> void:
	if action_button:
		action_button.disabled = true
	_clear_inventory_cache()
	get_tree().change_scene_to_file("res://scenes/AshRavine.tscn")

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
