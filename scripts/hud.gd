extends CanvasLayer

# ===== 节点引用（延迟获取，防止场景未就绪时报错）=====
var ammo_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var death_screen: Control = null
var crosshair: Control = null
var craft_notification: Control = null

# ===== 引用武器系统（C# WeaponController）=====
var weapon_ctrl: Node = null

func _ready() -> void:
	# 安全获取节点引用（节点可能不存在于某些场景中）
	ammo_label = get_node_or_null("AmmoPanel/AmmoLabel")
	health_bar = get_node_or_null("HealthPanel/HealthBar")
	health_label = get_node_or_null("HealthPanel/HealthLabel")
	death_screen = get_node_or_null("DeathScreen")
	crosshair = get_node_or_null("Crosshair")
	craft_notification = get_node_or_null("CraftLootNotification")

	# 默认隐藏 HUD（基地/大厅不显示）
	self.visible = false

	# 获取武器控制器引用
	weapon_ctrl = get_node_or_null("/root/Main/Player/WeaponController")

	# 如果武器控制器存在，初始化显示
	if weapon_ctrl:
		update_health(100.0, 100.0)
		update_ammo()

func _process(_delta: float) -> void:
	# 实时更新弹药显示
	if weapon_ctrl:
		update_ammo_display()

func update_health(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label:
		health_label.text = str(int(current)) + " / " + str(int(maximum))

func update_ammo_display() -> void:
	if weapon_ctrl and ammo_label:
		ammo_label.text = weapon_ctrl.get_ammo_status()

func update_ammo() -> void:
	if weapon_ctrl and ammo_label:
		ammo_label.text = weapon_ctrl.get_ammo_status()

func show_death_screen() -> void:
	if death_screen:
		death_screen.visible = true
	if crosshair:
		crosshair.visible = false

# ===== 工艺藏品通知 =====
func show_loot_notification(item_data: Dictionary) -> void:
	print("[HUD] 显示工艺藏品通知: ", item_data.get("name", ""))
	if craft_notification and craft_notification.has_method("show_loot_notification"):
		craft_notification.show_loot_notification(item_data)

func _on_RestartButton_pressed() -> void:
	# 重启游戏
	get_tree().paused = false
	get_tree().reload_current_scene()

# ===== HUD 显示/隐藏（由游戏场景调用）=====
func show_game_hud() -> void:
	"""进入游戏时调用，显示 HUD"""
	self.visible = true
	if crosshair:
		crosshair.visible = true

func hide_game_hud() -> void:
	"""返回基地/大厅时调用，隐藏 HUD"""
	self.visible = false
	if death_screen and is_instance_valid(death_screen):
		death_screen.visible = false
