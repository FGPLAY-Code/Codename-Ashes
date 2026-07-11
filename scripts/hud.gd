extends CanvasLayer

# ===== 节点引用（延迟获取，防止场景未就绪时报错）=====
var ammo_count_label: Label = null
var ammo_reserve_label: Label = null
var ammo_round_label: Label = null
var health_bar: ProgressBar = null
var health_fill: TextureRect = null
var health_label: Label = null
var death_screen: Control = null
var crosshair: Control = null
var craft_notification: Control = null

# ===== 引用武器系统（C# WeaponController）=====
var weapon_ctrl: Node = null

func _ready() -> void:
	# 安全获取节点引用（节点可能不存在于某些场景中）
	ammo_count_label = get_node_or_null("AmmoPanel/AmmoCountLabel")
	ammo_reserve_label = get_node_or_null("AmmoPanel/AmmoReserveLabel")
	ammo_round_label = get_node_or_null("AmmoPanel/RoundTypeLabel")
	health_bar = get_node_or_null("HealthPanel/HealthBar")
	health_fill = get_node_or_null("HealthPanel/HealthFillClip/HealthFill")
	health_label = get_node_or_null("HealthPanel/HealthLabel")
	death_screen = get_node_or_null("DeathScreen")
	crosshair = get_node_or_null("Crosshair")
	craft_notification = get_node_or_null("CraftLootNotification")

	# 设置亚克力面板样式
	_apply_styles()

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
	if health_fill and maximum > 0.0:
		health_fill.scale.x = clampf(current / maximum, 0.0, 1.0)
	if health_label:
		health_label.text = str(int(current)) + " / " + str(int(maximum))

func update_ammo_display() -> void:
	if not weapon_ctrl:
		return
	var status = weapon_ctrl.get_ammo_status()  # e.g. "30 / 90"
	var parts = status.split(" / ")
	if ammo_count_label and parts.size() >= 1:
		ammo_count_label.text = parts[0]
	if ammo_reserve_label and parts.size() >= 2:
		ammo_reserve_label.text = "/  " + parts[1]

func update_ammo() -> void:
	update_ammo_display()

# ===== Win11 Mica / Acrylic 样式（参考 LVMO_GAME 设计系统）=====

const C_BG_ACRYLIC_DARK := Color(0.078, 0.098, 0.157, 0.78)  # --bg-acrylic-dark
const C_BG_CARD_DARK := Color(0.157, 0.176, 0.255, 0.55)     # --bg-card-dark
const C_BORDER_SUBTLE := Color(0.471, 0.706, 1.0, 0.10)      # --border-subtle-dark
const C_ACCENT := Color(0.376, 0.804, 1.0)                    # #60cdff
const C_TEXT_PRIMARY := Color(0.910, 0.929, 0.961)            # --text-primary-dark
const C_TEXT_SECONDARY := Color(0.784, 0.843, 0.941, 0.65)    # --text-secondary-dark
const C_TEXT_TERTIARY := Color(0.706, 0.784, 0.902, 0.40)    # --text-tertiary-dark

func _acrylic_card(bg: Color = C_BG_CARD_DARK, border: Color = C_BORDER_SUBTLE) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(7)
	return s

func _apply_styles():
	# HealthPanel — 亚克力卡片 + 青色左边框点缀
	var hp = get_node_or_null("HealthPanel")
	if hp:
		var st = _acrylic_card()
		# 青色左框（2px 宽）
		st.border_width_left = 3
		st.border_color = C_ACCENT
		st.border_width_top = 0
		st.border_width_right = 0
		st.border_width_bottom = 0
		hp.add_theme_stylebox_override("panel", st)
	
	# AmmoPanel — 亚克力卡片 + 青色上边框点缀
	var ap = get_node_or_null("AmmoPanel")
	if ap:
		var st = _acrylic_card()
		st.border_width_top = 2
		st.border_color = C_ACCENT
		st.border_width_left = 0
		st.border_width_right = 0
		st.border_width_bottom = 0
		ap.add_theme_stylebox_override("panel", st)
	
	# HealthBar 背景（透明填充，用 HealthFill 代替）
	if health_bar:
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.078, 0.098, 0.157, 0.35)
		bg.set_corner_radius_all(4)
		health_bar.add_theme_stylebox_override("background", bg)
		var empty_fill = StyleBoxFlat.new()
		empty_fill.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		health_bar.add_theme_stylebox_override("fill", empty_fill)
	
	# HealthFill — Win11 蓝白渐变
	if health_fill:
		var grad = Gradient.new()
		grad.colors = PackedColorArray([
			Color(0.310, 0.765, 0.969, 1.0),   # 左端：#4FC3F7 淡蓝
			Color(0.890, 0.949, 0.992, 1.0)    # 右端：#E3F2FD 极淡蓝白
		])
		var tex = GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 512
		health_fill.texture = tex
	
	# HealthFillClip 圆角裁切
	var clip = get_node_or_null("HealthPanel/HealthFillClip")
	if clip:
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		cs.set_corner_radius_all(4)
		clip.add_theme_stylebox_override("panel", cs)

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
