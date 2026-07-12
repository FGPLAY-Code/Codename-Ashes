extends CharacterBody3D

# ===== 移动参数 =====
const WALK_SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const CROUCH_SPEED: float = 3.0  # 蹲下速度
const ADS_SPEED: float = 4.0      # 开镜速度（介于站立和蹲下之间）
const JUMP_VELOCITY: float = 5.0
const MOUSE_SENSITIVITY: float = 0.003
const FRICTION: float = 10.0

# ===== 蹲下参数 =====
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.0
const STAND_EYE_HEIGHT: float = 1.6
const CROUCH_EYE_HEIGHT: float = 0.8

# ===== 探头参数 =====
const PEEK_TILT_ANGLE: float = 0.26  # 约15度（弧度）
const PEEK_SHIFT_DISTANCE: float = 0.3  # 探头时身体偏移距离

# ===== 节点引用（安全获取）=====
@onready var camera_pivot: Node3D = get_node_or_null("CameraPivot")  # 相机挂载点
@onready var camera: Camera3D = get_node_or_null("CameraPivot/Camera3D")  # 相机
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")  # 碰撞体
var raycast: RayCast3D  # RayCast3D - 射击用（检测敌人）
var interact_raycast: RayCast3D  # InteractRaycast - 交互用（检测可拾取物）
var gun_muzzle: Node3D  # 枪口位置 - 动态获取

# ===== HUD 引用 =====
var hud: CanvasLayer
var ammo_label: Label
var reload_hint: Label
var health_bar: ProgressBar
var health_label: Label
var hip_crosshair: Control       # 腰射准星（原有十字）
var iron_sight_crosshair: Control # 机瞄准星（瞄准时显示）
var inventory_panel: Control     # 背包界面
var search_panel: Control        # 搜索界面
var interact_prompt: Control     # 交互提示（F 搜索）

# ===== 背包系统 =====
var inventory_open: bool = false
var search_open: bool = false    # 搜索界面是否打开

# ===== 交互系统 =====
var look_target: Node3D = null  # 当前准心对准的可交互物体
var INTERACT_RANGE: float = 3.5  # 交互最大距离（米）

# ===== 射击参数 =====
var ammo: int = 30
var max_ammo: int = 30
var reserve_ammo: int = 90
var is_reloading: bool = false
var can_shoot: bool = true
const FIRE_RATE_AUTO: float = 0.08  # 全自动，每秒约12发
const FIRE_RATE_SEMI: float = 0.15   # 单发，每秒约6-7发

# ===== 开火模式 =====
enum FireMode { AUTO, SEMI }
var current_fire_mode: FireMode = FireMode.AUTO
var fire_rate: float = FIRE_RATE_AUTO  # 当前射速

# ===== 枪声音频 =====
var gun_audio: AudioStreamPlayer

# ===== 后座力参数 =====
const RECOIL_KICK: float = 0.015  # 每次射击枪口上跳（正值=枪口向上）
const RECOIL_RECOVERY: float = 0.03  # 每帧恢复速度

# ===== 重力 =====
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# ===== 按键状态 =====
var is_shooting: bool = false
var is_crouching: bool = false
var is_ads: bool = false
var is_peeking_left: bool = false
var is_peeking_right: bool = false

# ===== 初始化状态 =====
var physics_enabled: bool = false  # 等待碰撞体生成后再启用物理

# ===== 武器系统 =====
var weapon: Node3D  # 武器模型节点
var weapon_pivot: Node3D  # 武器挂载点
# ===== 武器位置参数（AKM 突击步枪尺寸）=====
const HIP_POSITION := Vector3(0.3, -0.2, -0.3)  # 腰射位置
const ADS_POSITION := Vector3(0.1, -0.15, -0.15)  # 瞄准位置
const HIP_ROTATION := Vector3(0, 0, 0)
const ADS_ROTATION := Vector3(0, 0, 0)
const ADS_FOV := 50.0  # 瞄准时 FOV
const HIP_FOV := 75.0  # 正常 FOV

# ===== 枪械晃动参数 =====
const WALK_BOB_SPEED: float = 8.0    # 走路晃动频率
const WALK_BOB_AMOUNT: float = 0.015  # 走路晃动幅度（位置）
const WALK_SWAY_AMOUNT: float = 0.03  # 走路晃动幅度（旋转）
const SPRINT_MULTIPLIER: float = 1.5  # 奔跑时晃动倍数
var walk_cycle: float = 0.0  # 晃动周期计时器
var base_weapon_pos: Vector3 = Vector3.ZERO  # 武器基础位置
var base_weapon_rot: Vector3 = Vector3.ZERO  # 武器基础旋转

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	velocity = Vector3.ZERO
	
	# 防止斜面滑动漂移
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	
	# 初始化相机子节点引用
	if camera:
		raycast = camera.get_node_or_null("RayCast3D")
		interact_raycast = camera.get_node_or_null("InteractRaycast")
		gun_muzzle = camera.get_node_or_null("GunMuzzle")
	
	# 让射线排除自身（不命中自己的碰撞体）
	if raycast:
		raycast.add_exception(self)
	if interact_raycast:
		interact_raycast.add_exception(self)
	
	# 初始化枪声音频
	setup_gun_audio()
	
	setup_hud()
	setup_weapon()
	
	# 添加到 Player 组（让敌人生成器能找到）
	add_to_group("Player")
	print("[Player] 已加入 Player 组")
	
	# 等待碰撞体生成完成后再启用物理
	await get_tree().create_timer(2.0).timeout
	
	if global_position.y > 2.0:
		await get_tree().create_timer(1.0).timeout
	
	physics_enabled = true

func setup_gun_audio() -> void:
	# 创建枪声音频播放器
	gun_audio = AudioStreamPlayer.new()
	gun_audio.name = "GunAudio"
	gun_audio.volume_db = 0  # 音量设置
	gun_audio.pitch_scale = 1.0
	gun_audio.max_polyphony = 3  # 允许同时播放多个枪声（用于快速射击）
	add_child(gun_audio)
	
	# 加载AK枪声音频
	var audio_path = "res://resources/mp3/ak_gunshot.mp3"
	var audio_stream = load(audio_path)
	if audio_stream:
		gun_audio.stream = audio_stream
		print("[Player] AK枪声音频加载成功")
	else:
		push_error("[Player] 无法加载AK枪声音频: " + audio_path)

func play_gun_sound() -> void:
	if gun_audio and gun_audio.stream:
		if gun_audio.playing:
			# 如果正在播放，等待一小段时间再播放新声音
			await get_tree().create_timer(0.02).timeout
		gun_audio.play()

func setup_hud() -> void:
	var hud_scene = preload("res://scenes/HUD.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)
	
	ammo_label = hud.get_node("AmmoPanel/AmmoLabel")
	reload_hint = hud.get_node("ReloadHint")
	health_bar = hud.get_node("HealthPanel/HealthBar")
	health_label = hud.get_node("HealthPanel/HealthLabel")
	hip_crosshair = hud.get_node("Crosshair")
	iron_sight_crosshair = hud.get_node("IronSightCrosshair")
	inventory_panel = hud.get_node("InventoryPanel")
	search_panel = hud.get_node("SearchPanel")
	interact_prompt = hud.get_node("InteractPrompt")
	
	# 为 F 键方框创建白色空心边框样式
	var fkey_panel = hud.get_node("InteractPrompt/FKeySquare")
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)           # 透明背景
	sb.border_color = Color(1, 1, 1, 1)        # 白色边框
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	fkey_panel.add_theme_stylebox_override("panel", sb)
	
	update_ammo_display()
	update_health_display()

func update_ammo_display() -> void:
	if ammo_label:
		ammo_label.text = str(ammo) + " / " + str(reserve_ammo)
	# 更新开火模式显示
	update_fire_mode_display()

func update_health_display() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if health_label:
		health_label.text = str(int(health)) + " / " + str(int(max_health))

func toggle_fire_mode() -> void:
	if is_reloading:
		return
	
	if current_fire_mode == FireMode.AUTO:
		current_fire_mode = FireMode.SEMI
		fire_rate = FIRE_RATE_SEMI
		print("[Player] 开火模式切换为: 单发 SEMI")
	else:
		current_fire_mode = FireMode.AUTO
		fire_rate = FIRE_RATE_AUTO
		print("[Player] 开火模式切换为: 全自动 AUTO")
	
	update_fire_mode_display()

func update_fire_mode_display() -> void:
	if not hud:
		return
	
	# 查找或创建开火模式显示标签
	var fire_mode_label = hud.get_node_or_null("FireModeLabel")
	if not fire_mode_label:
		# 创建开火模式显示标签 - 居中偏下显示
		fire_mode_label = Label.new()
		fire_mode_label.name = "FireModeLabel"
		fire_mode_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		fire_mode_label.offset_top = 200   # 向下偏移200像素（屏幕中下部）
		fire_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fire_mode_label.add_theme_font_size_override("font_size", 18)
		fire_mode_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.9))
		hud.add_child(fire_mode_label)
	
	# 更新显示
	if current_fire_mode == FireMode.AUTO:
		fire_mode_label.text = "[B] AUTO 全自动"
	else:
		fire_mode_label.text = "[B] SEMI 单发"

# ===== 武器系统 =====
func find_muzzle_point(node: Node) -> Node3D:
	# 尝试查找枪口节点
	var muzzle = node.get_node_or_null("Muzzle") as Node3D
	if muzzle:
		return muzzle
	
	# 如果没找到，创建一个在枪口位置的儿子节点
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	# AKM 枪口大约在模型前方
	muzzle.position = Vector3(0, 0, -1.0)
	node.add_child(muzzle)
	return muzzle

func setup_weapon() -> void:
	# 尝试获取场景中已有的武器挂载点
	weapon_pivot = get_node_or_null("CameraPivot/WeaponPivot")
	
	if weapon_pivot == null:
		# 如果场景中没有WeaponPivot，则创建
		weapon_pivot = Node3D.new()
		weapon_pivot.name = "WeaponPivot"
		weapon_pivot.position = Vector3.ZERO
		camera_pivot.add_child(weapon_pivot)
		# 场景中没有武器，需要通过代码加载
		create_akm_weapon()
	else:
		# 场景中已有WeaponPivot，查找AKM模型
		var akm_model = weapon_pivot.get_node_or_null("AKM_Model")
		if akm_model != null:
			weapon = akm_model
			disable_all_collisions(weapon)
			# 查找枪口位置点
			var muzzle = find_muzzle_point(weapon)
			if muzzle:
				gun_muzzle = muzzle
			# 保存基础位置
			base_weapon_pos = weapon.position
			base_weapon_rot = weapon.rotation
			print("=== 使用场景中的 AKM 模型 ===")
		else:
			# 有WeaponPivot但没有AKM，通过代码加载
			create_akm_weapon()

func disable_all_collisions(node: Node) -> void:
	# 递归禁用节点及其所有子节点的碰撞体
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		disable_all_collisions(child)

func create_akm_weapon() -> void:
	# 加载 AKM GLB 模型
	print("=== 正在加载 AKM 模型 ===")
	var glb_path = "res://models/Guns/GLB/AKM_v1.0.glb"
	var akm_model = load(glb_path)
	
	if akm_model == null:
		push_error("无法加载 AKM 模型: " + glb_path)
		print("!!! AKM 模型加载失败 !!!")
		return
	
	print("AKM 模型加载成功: ", akm_model)
	
	# GLB 作为 PackedScene 实例化
	print("正在实例化 AKM 模型...")
	var instance = akm_model.instantiate()
	if instance == null:
		push_error("无法实例化 AKM 模型")
		print("!!! AKM 模型实例化失败 !!!")
		return
	
	print("AKM 模型实例化成功")
	
	# 设置名称
	instance.name = "AKM_Model"
	
	# 调整缩放（AKM 模型尺寸适配 FPS 视角）
	instance.scale = Vector3(1.0, 1.0, 1.0)
	
	# 设置初始位置和旋转
	instance.position = HIP_POSITION
	# AKM 模型朝向：去掉 PI 旋转，如果还反可以改成 PI
	instance.rotation = Vector3(0, 0, 0)
	
	print("AKM 位置: ", instance.position, " 缩放: ", instance.scale)
	
	# 添加到武器挂载点
	weapon_pivot.add_child(instance)
	weapon = instance
	print("AKM 已添加到 weapon_pivot")
	
	# 保存武器基础位置和旋转（用于晃动计算）
	base_weapon_pos = HIP_POSITION
	base_weapon_rot = HIP_ROTATION
	
	# 禁用所有碰撞体（玩家武器不需要碰撞）
	disable_all_collisions(instance)
	
	# 查找或创建枪口位置点
	var muzzle = find_muzzle_point(instance)
	if muzzle:
		gun_muzzle = muzzle
	
	print("=== AKM 武器系统初始化完成 ===")

func toggle_ads(ads_on: bool) -> void:
	if not weapon:
		return
	
	is_ads = ads_on
	
	var target_pos = ADS_POSITION if ads_on else HIP_POSITION
	var target_rot = ADS_ROTATION if ads_on else HIP_ROTATION
	
	# 更新基础位置（瞄准时晃动基于瞄准位置）
	base_weapon_pos = target_pos
	base_weapon_rot = target_rot
	
	# 武器动画
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(weapon, "position", target_pos, 0.12)
	tween.tween_property(weapon, "rotation", target_rot, 0.12)
	
	# FOV 动画
	var target_fov = ADS_FOV if ads_on else HIP_FOV
	var fov_tween = create_tween()
	fov_tween.tween_property(camera, "fov", target_fov, 0.12)
	
	# 准星切换：腰射 ↔ 机瞄
	if hip_crosshair:
		hip_crosshair.visible = not ads_on
	if iron_sight_crosshair:
		iron_sight_crosshair.visible = ads_on

func _input(event: InputEvent) -> void:
	# 背包或搜索界面打开时只允许关闭操作
	if inventory_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory_toggle"):
			close_inventory()
		return
	
	# 搜索界面打开时按 ESC 关闭
	if search_open:
		if event.is_action_pressed("ui_cancel"):
			close_search_panel()
		return
	
	if event is InputEventMouseMotion:
		# 始终响应鼠标转动视角
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("inventory_toggle"):
		toggle_inventory()

	if event.is_action_pressed("shoot"):
		is_shooting = true
		# 单发模式：按下只射击一次
		if current_fire_mode == FireMode.SEMI:
			shoot()
			is_shooting = false  # 单发模式下松手前不再自动射击

	if event.is_action_released("shoot"):
		is_shooting = false
	
	# 切换开火模式
	if event.is_action_pressed("toggle_fire_mode"):
		toggle_fire_mode()

	if event.is_action_pressed("crouch"):
		start_crouch()

	if event.is_action_released("crouch"):
		stop_crouch()
	
	# 探头
	if event.is_action_pressed("peek_left"):
		start_peek_left()
	if event.is_action_released("peek_left"):
		stop_peek_left()
	if event.is_action_pressed("peek_right"):
		start_peek_right()
	if event.is_action_released("peek_right"):
		stop_peek_right()
	
	# 瞄准
	if event.is_action_pressed("aim"):
		toggle_ads(true)
	if event.is_action_released("aim"):
		toggle_ads(false)

	# 死亡后按 R 重开
	if event.is_action_pressed("reload") and health <= 0:
		restart_game()
		return  # 不触发换弹

	# 正常换弹
	if event.is_action_pressed("reload"):
		reload()
	
	# 交互
	if event.is_action_pressed("interact"):
		interact_with_look_target()

func _physics_process(delta: float) -> void:
	# 等待物理系统启用（碰撞体生成完成后）
	if not physics_enabled:
		return
	
	# 背包或搜索界面打开时禁止移动和射击
	if inventory_open or search_open:
		velocity = Vector3.ZERO
		return
	
	# 全自动射击
	if is_shooting and not is_reloading and ammo > 0:
		if can_shoot:
			shoot()

	if not is_on_floor():
		velocity.y -= gravity * delta

	# 蹲下时不能跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# 基于 Player.rotation.y 计算移动方向
	var forward := Vector3(0, 0, -1).rotated(Vector3.UP, rotation.y)
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, rotation.y)
	var direction := (input_dir.x * right + (-input_dir.y) * forward)
	
	# 计算当前速度
	var current_speed := WALK_SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif is_ads:
		current_speed = ADS_SPEED
	elif Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta * 10)
			velocity.z = move_toward(velocity.z, 0, FRICTION * delta * 10)
	
	move_and_slide()
	
	# ===== 枪械晃动 =====
	_update_weapon_bob(delta)
	
	# ===== 交互提示检测 =====
	update_interact_prompt()

func shoot() -> void:
	if not can_shoot or is_reloading or ammo <= 0:
		return

	ammo -= 1
	# 射击不消耗备弹，只消耗弹匣，不需要同步背包
	update_ammo_display()

	# 播放枪声
	play_gun_sound()

	# 应用后座力 - 枪口往上跳（负向旋转）
	apply_recoil()

	show_muzzle_flash()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider == null or not is_instance_valid(collider):
			return  # 目标已被删除，直接返回
		
		var hit_point = raycast.get_collision_point()
		spawn_impact_effect(hit_point, raycast.get_collision_normal())
		
		# get_collider() 有时返回 CharacterBody3D（直接命中根节点）
		# 有时返回 CollisionShape3D（命中子节点），需要向上找拥有 take_damage 的节点
		var target: Node = collider
		while target != null and not target.has_method("take_damage"):
			target = target.get_parent()
		if target != null and is_instance_valid(target):
			var enemy: CharacterBody3D = target as CharacterBody3D
			var base_damage: float = 25.0
			var final_damage: float = base_damage
			
			# 爆头判定：命中点必须在胶囊顶部附近的一个窄范围内才算爆头
			# 胶囊高度 8 单位，底部在 enemy.global_position.y
			# 爆头窗口设在胶囊 50%~63% 高度处（比之前更低，精确匹配模型头部）
			if enemy != null:
				var cap_bottom: float = enemy.global_position.y
				var head_bottom: float = cap_bottom + 4.0   # 窗口下限
				var head_top: float = cap_bottom + 4.5     # 窗口上限
				if hit_point.y > head_bottom and hit_point.y < head_top:
					var multiplier: float = 2.0 if is_crouching else 1.75
					final_damage = base_damage * multiplier
					var emoji: String = "💀" if multiplier >= 2.0 else "🎯"
					print(emoji, " 爆头！倍率 x", multiplier, " → 伤害 ", final_damage)
					_show_hit_feedback(multiplier)
			
			target.take_damage(final_damage)

	can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

	if ammo <= 0 and reserve_ammo > 0:
		reload()

func apply_recoil() -> void:
	# 蹲下时后坐力减半，瞄准时后坐力增加
	var recoil_multiplier = 0.5 if is_crouching else 1.0
	if is_ads:
		recoil_multiplier *= 0.7  # 瞄准时更稳定
	var kick = RECOIL_KICK * recoil_multiplier
	
	# 枪口往上跳（只影响视角，不影响角色移动方向）
	camera_pivot.rotate_x(kick)
	# 不再影响角色左右旋转！
	
	# 武器后座动画
	if weapon:
		var recoil_offset = Vector3(randf_range(-0.005, 0.005), kick * 0.3, kick * 0.5)
		var tween = create_tween()
		tween.tween_property(weapon, "position", weapon.position + recoil_offset, 0.02)
		tween.tween_property(weapon, "position", weapon.position, 0.06)

func reload() -> void:
	if is_reloading or ammo == max_ammo or reserve_ammo <= 0:
		return

	is_reloading = true
	is_shooting = false
	reload_hint.visible = true
	
	# 换弹动画 - 武器移出视野
	if weapon:
		var tween = create_tween()
		tween.tween_property(weapon, "position:y", weapon.position.y - 0.5, 0.3)
		tween.tween_property(weapon, "rotation:x", -0.5, 0.3)

	await get_tree().create_timer(1.5).timeout

	var needed = max_ammo - ammo
	var to_reload = mini(needed, reserve_ammo)
	ammo += to_reload
	reserve_ammo -= to_reload

	# 同步背包弹药数据
	if inventory_panel and inventory_panel.has_method("sync_from_player"):
		inventory_panel.sync_from_player()

	update_ammo_display()
	
	# 换弹完成 - 武器回来
	if weapon:
		var target_pos = ADS_POSITION if is_ads else HIP_POSITION
		var tween = create_tween()
		tween.tween_property(weapon, "position", target_pos, 0.2)
		tween.tween_property(weapon, "rotation:x", 0, 0.2)
	
	reload_hint.visible = false
	is_reloading = false

func show_muzzle_flash() -> void:
	if not gun_muzzle:
		return

	var flash = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.15)
	flash.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.6, 0.1)
	mat.emission_energy_multiplier = 4.0
	flash.material_override = mat

	flash.position = gun_muzzle.position
	camera_pivot.add_child(flash)

	await get_tree().create_timer(0.05).timeout
	if flash:
		flash.queue_free()

func spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	var spark = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	spark.mesh = sphere

	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.8, 0.6, 0.4)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1, 0.6, 0.2)
	spark_mat.emission_energy_multiplier = 1.5
	spark.material_override = spark_mat

	spark.position = pos + normal * 0.02
	get_tree().root.add_child(spark)

	await get_tree().create_timer(0.2).timeout
	if spark:
		spark.queue_free()

var health: float = 100.0
var max_health: float = 100.0

func take_damage(amount: float) -> void:
	health -= amount
	health = max(0, health)
	
	# 更新血量条
	update_health_display()
	
	# 受伤闪红效果
	show_damage_effect()
	
	if health <= 0:
		die()

func show_damage_effect() -> void:
	if not hud:
		return
	# 避免叠加：已有遮罩则先清除
	var old_overlay = hud.get_node_or_null("DamageOverlay")
	if old_overlay:
		old_overlay.queue_free()
	
	# 创建红色遮罩
	var damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.anchors_preset = Control.PRESET_FULL_RECT
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(1, 0, 0, 0.35)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(damage_overlay)
	
	# 渐隐动画
	var tween = create_tween()
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.4)
	tween.tween_callback(damage_overlay.queue_free)

func _show_hit_feedback(_multiplier: float) -> void:
	if not hud:
		return
	
	# 清除旧反馈
	var old = hud.get_node_or_null("HeadshotFeedback")
	if old:
		old.queue_free()
	
	# 创建爆头准心（两条45°斜线交叉）
	var feedback = Control.new()
	feedback.name = "HeadshotFeedback"
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feedback.size = Vector2(80, 80)
	feedback.position -= Vector2(40, 40)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(feedback)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0.85, 0, 0)  # 透明背景
	
	# 横线
	var h_line = ColorRect.new()
	h_line.name = "H"
	h_line.size = Vector2(50, 3)
	h_line.position = Vector2(15, 38.5)
	h_line.color = Color(1, 1, 1, 1)
	h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.add_child(h_line)
	
	# 竖线
	var v_line = ColorRect.new()
	v_line.name = "V"
	v_line.size = Vector2(3, 50)
	v_line.position = Vector2(38.5, 15)
	v_line.color = Color(1, 1, 1, 1)
	v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.add_child(v_line)
	
	# 整体旋转45°
	feedback.pivot_offset = Vector2(40, 40)
	feedback.rotation = PI / 4
	
	# 快速缩小消失
	var tween = create_tween()
	tween.tween_property(feedback, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.2)
	tween.tween_callback(feedback.queue_free)

func die() -> void:
	if is_crouching:
		stop_crouch()
	
	# 显示死亡画面（不清除其他子弹，让它们自然消失）
	show_death_screen()

func show_death_screen() -> void:
	if not hud:
		return
	
	# 暗色死亡遮罩
	var overlay = ColorRect.new()
	overlay.name = "DeathOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.1, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)
	
	# 死亡文字
	var death_label = Label.new()
	death_label.name = "DeathLabel"
	death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_label.text = "YOU DIED"
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.modulate = Color(0.9, 0.1, 0.1, 1)
	hud.add_child(death_label)
	
	# 提示按 R 重开
	var hint_label = Label.new()
	hint_label.name = "RestartHint"
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_top = 100
	hint_label.text = "按 R 重新开始"
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.modulate = Color(0.7, 0.7, 0.7, 1)
	hud.add_child(hint_label)
	
	# 解锁鼠标，让玩家可以点击
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func restart_game() -> void:
	# 重新加载当前场景
	get_tree().reload_current_scene()

func heal(amount: float) -> void:
	health = min(health + amount, max_health)

func get_reserve_ammo() -> int:
	return reserve_ammo

func add_reserve_ammo(amount: int) -> void:
	reserve_ammo += amount
	update_ammo_display()

func set_reserve_ammo(amount: int) -> void:
	reserve_ammo = amount
	update_ammo_display()

# ===== 背包系统 =====
func toggle_inventory() -> void:
	if inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if inventory_open:
		return
	
	inventory_open = true
	
	# 显示背包界面
	if inventory_panel:
		inventory_panel.visible = true
		# 刷新背包数据（实时显示备弹）
		if inventory_panel.has_method("refresh"):
			inventory_panel.refresh()
	
	# 解锁鼠标以便交互
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 隐藏准星
	if hip_crosshair:
		hip_crosshair.visible = false
	if iron_sight_crosshair:
		iron_sight_crosshair.visible = false
	
	# 关闭瞄准
	if is_ads:
		toggle_ads(false)
	
	# 停止移动和射击
	is_shooting = false

func close_inventory() -> void:
	if not inventory_open:
		return
	
	inventory_open = false
	
	# 隐藏背包界面
	if inventory_panel:
		inventory_panel.visible = false
	
	# 锁定鼠标
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 恢复准星
	if hip_crosshair:
		hip_crosshair.visible = true

# ===== 蹲下功能 =====
func start_crouch() -> void:
	if is_crouching:
		return
	is_crouching = true
	
	# 缩小碰撞体
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = CROUCH_HEIGHT
		capsule.radius = 0.4  # 保持不变
	
	# 降低眼睛高度
	if camera_pivot:
		camera_pivot.position.y = CROUCH_EYE_HEIGHT

func stop_crouch() -> void:
	if not is_crouching:
		return
	is_crouching = false
	
	# 恢复碰撞体
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = STAND_HEIGHT
		capsule.radius = 0.4
	
	# 恢复眼睛高度
	if camera_pivot:
		camera_pivot.position.y = STAND_EYE_HEIGHT

# ===== 探头功能 =====
func start_peek_left() -> void:
	if is_peeking_left:
		return
	is_peeking_left = true
	is_peeking_right = false
	_apply_peek()

func start_peek_right() -> void:
	if is_peeking_right:
		return
	is_peeking_right = true
	is_peeking_left = false
	_apply_peek()

func stop_peek_left() -> void:
	if not is_peeking_left:
		return
	is_peeking_left = false
	_apply_peek()

func stop_peek_right() -> void:
	if not is_peeking_right:
		return
	is_peeking_right = false
	_apply_peek()

func _apply_peek() -> void:
	if not camera_pivot:
		return
	
	# 停止任何探头
	if not is_peeking_left and not is_peeking_right:
		# 恢复正常
		rotation.z = 0.0
		if collision_shape:
			collision_shape.position.x = 0.0
	else:
		# 计算倾斜方向和偏移
		var tilt: float = 0.0
		var shift: float = 0.0
		
		if is_peeking_left and is_peeking_right:
			# 同时按Q和E，互相抵消
			tilt = 0.0
			shift = 0.0
		elif is_peeking_left:
			tilt = PEEK_TILT_ANGLE
			shift = -PEEK_SHIFT_DISTANCE  # 身体左移
		elif is_peeking_right:
			tilt = -PEEK_TILT_ANGLE
			shift = PEEK_SHIFT_DISTANCE   # 身体右移
		
		# 应用相机倾斜（绕Z轴旋转）
		rotation.z = tilt
		
		# 移动碰撞体（向左探头时身体左移，敌人只能打到你暴露的右侧）
		if collision_shape:
			collision_shape.position.x = shift

# ===== 交互系统 =====
func update_interact_prompt() -> void:
	if not hud or not interact_raycast:
		return
	
	
	# 强制更新射线
	interact_raycast.force_raycast_update()
	
	# 重置目标
	look_target = null
	
	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		print("交互射线命中: ", collider.name if collider else "null")
		# 显示命中物体的碰撞层信息
		if collider is CollisionObject3D:
			print("  命中物体 collision_layer=", collider.collision_layer)
		# 向上找到有 interact 方法的节点
		var target: Node = collider
		while target != null and not target.has_method("interact"):
			target = target.get_parent()
			print("  上查: ", str(target.name) if target != null else "null")
		
		if target != null and target.has_method("interact"):
			var dist = interact_raycast.get_collision_point().distance_to(global_position)
			if dist <= INTERACT_RANGE:
				look_target = target
				print("找到可交互物体: ", target.name, " 距离: ", dist)
			else:
				print("太远: ", dist, " > ", INTERACT_RANGE)
		else:
			print("命中物体无 interact 方法: ", collider.name if collider else "null")
	
	# 显示/隐藏提示
	if interact_prompt:
		interact_prompt.visible = (look_target != null)

func interact_with_look_target() -> void:
	if look_target == null or not is_instance_valid(look_target):
		return
	
	# 背包或搜索界面打开时禁止交互
	if inventory_open or search_open:
		return
	
	# 检查目标是否是弹药箱
	if look_target.has_method("is_ammo_box"):
		# 打开搜索界面
		open_search_panel(look_target)
	elif look_target.has_method("interact"):
		# 其他可交互物体直接调用 interact
		look_target.interact(self)

# ===== 搜索界面 =====
func open_search_panel(ammo_box: Node3D) -> void:
	search_open = true
	search_panel.visible = true
	current_interact_ammo_box = ammo_box  # 追踪当前弹药箱
	
	# 刷新背包数据（确保显示最新数据）
	if inventory_panel and inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	
	# 解锁鼠标以便交互
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 隐藏其他界面
	interact_prompt.visible = false
	
	# 清空弹药箱格子
	var ammo_box_grid = search_panel.get_node("HBox/RightPanel/AmmoBoxGrid")
	for child in ammo_box_grid.get_children():
		child.queue_free()
	
	# 添加弹药箱物品（9个格子，弹药箱放中间）
	var item_count = 9
	var center_index = 4  # 中间位置
	
	# 检查这个特定弹药箱是否已被拾取（每个弹药箱独立追踪）
	var is_this_box_picked = ammo_box.get_meta("picked", false) if ammo_box else false
	
	for i in range(item_count):
		# 只有未被拾取时才显示弹药
		var show_ammo = i == center_index and not is_this_box_picked
		var slot = create_ammo_slot(show_ammo, ammo_box, i)
		ammo_box_grid.add_child(slot)
	
	# 初始化拖动状态
	is_search_dragging = false
	
	# 显示玩家的背包物品
	refresh_search_inventory()

func create_ammo_slot(has_item: bool, ammo_box: Node3D, slot_index: int = 0) -> Control:
	var panel = PanelContainer.new()
	panel.name = "AmmoSlot_" + str(slot_index)
	panel.custom_minimum_size = Vector2(80, 80)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	
	if has_item:
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = Color(0.9, 0.7, 0.2, 1)  # 金色弹药
		vbox.add_child(icon)
		
		var name_label = Label.new()
		name_label.text = "7.62x39mm"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_label)
		
		var count_label = Label.new()
		count_label.text = "x30"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
		vbox.add_child(count_label)
		
		# 存储弹药箱引用和数据用于拾取
		panel.set_meta("ammo_box", ammo_box)
		panel.set_meta("slot_index", slot_index)
		panel.set_meta("is_center", has_item)
		
		# 连接拖动信号
		panel.gui_input.connect(_on_ammo_slot_gui_input.bind(panel, slot_index, has_item, ammo_box))
	else:
		# 空格子
		var empty_hint = Label.new()
		empty_hint.text = "+"
		empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_hint.add_theme_font_size_override("font_size", 24)
		empty_hint.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		panel.add_child(empty_hint)
	
	return panel

func refresh_search_inventory() -> void:
	var inventory_grid = search_panel.get_node("HBox/LeftPanel/InventoryGrid")
	# 清空
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# 从真实背包数据中读取并显示
	var slots: Array = []
	if inventory_panel:
		slots = inventory_panel.slots
	if slots.size() > 0:
		for i in range(mini(28, slots.size())):
			var slot_data: Dictionary = slots[i]
			var slot = create_search_slot(slot_data, i)
			inventory_grid.add_child(slot)
	else:
		# 如果没有真实背包数据，显示空格子
		for i in range(28):
			var slot = create_empty_slot()
			inventory_grid.add_child(slot)

func create_search_slot(slot_data: Dictionary, slot_index: int = 0) -> Control:
	var panel = PanelContainer.new()
	panel.name = "SearchSlot_" + str(slot_index)
	panel.custom_minimum_size = Vector2(60, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	
	panel.set_meta("slot_index", slot_index)
	panel.set_meta("is_search_slot", true)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	if slot_data.get("name", "") != "":
		# 物品图标
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.color = _get_search_item_color(slot_data.get("icon", ""))
		vbox.add_child(icon)
		
		# 物品名称
		var name_label = Label.new()
		name_label.text = slot_data.get("name", "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(56, 0)
		vbox.add_child(name_label)
		
		# 数量
		var count = slot_data.get("count", 0)
		# 弹药格：始终从玩家实时读取
		if slot_data.get("is_ammo", false):
			count = get_reserve_ammo()
		if count > 1 or slot_data.get("is_ammo", false):
			var count_label = Label.new()
			count_label.text = "x" + str(count)
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 11)
			count_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			vbox.add_child(count_label)
		
		# 连接拖动信号（背包格子可以拖出）
		panel.gui_input.connect(_on_search_slot_gui_input.bind(panel, slot_index, slot_data))
	else:
		# 空格子（可以接收拖放）
		var empty_hint = Label.new()
		empty_hint.text = "+"
		empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_hint.add_theme_font_size_override("font_size", 20)
		empty_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(empty_hint)
		
		# 连接拖动信号（空格子可以接收）
		panel.gui_input.connect(_on_search_slot_gui_input.bind(panel, slot_index, slot_data))
	
	return panel

func _get_search_item_color(icon_type: String) -> Color:
	match icon_type:
		"heal": return Color(0.2, 0.9, 0.3, 1)
		"ammo": return Color(0.9, 0.7, 0.2, 1)
		"grenade": return Color(0.3, 0.5, 0.3, 1)
		"armor": return Color(0.3, 0.5, 0.8, 1)
		_: return Color(0.6, 0.6, 0.6, 1)

func create_empty_slot() -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(60, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func close_search_panel() -> void:
	search_open = false
	search_panel.visible = false
	
	# 锁定鼠标
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_ammo_ui() -> void:
	# 更新弹药UI显示
	if inventory_panel and inventory_panel.has_method("get_ammo_count"):
		var ammo_count = inventory_panel.get_ammo_count()
		# 更新玩家弹药数据
		set_reserve_ammo(ammo_count)
		# 刷新背包显示
		if inventory_panel.has_method("refresh"):
			inventory_panel.refresh()


# ===== 搜索界面拖动系统 =====
var is_search_dragging: bool = false
var search_drag_preview: Control = null
var search_drag_source_type: String = ""  # "ammo_box" 或 "inventory"
var search_drag_source_index: int = -1
var search_drag_item_data: Dictionary = {}
var current_interact_ammo_box: Node3D = null  # 当前正在交互的弹药箱

func _on_ammo_slot_gui_input(event: InputEvent, cell: Control, slot_index: int, has_item: bool, ammo_box: Node3D) -> void:
	if not has_item:
		return
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# 开始从弹药箱拖动
				_start_ammo_drag(cell, slot_index, ammo_box)
			else:
				# 放下
				pass  # 拖动结束时处理

func _on_search_slot_gui_input(event: InputEvent, cell: Control, slot_index: int, slot_data: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# 点击背包格子
				if is_search_dragging and search_drag_source_type == "ammo_box":
					# 从弹药箱放入背包
					_place_ammo_to_inventory(slot_index)
				elif slot_data.get("name", "") != "":
					# 开始从背包拖动
					_start_inventory_drag(cell, slot_index, slot_data)
			else:
				# 释放鼠标
				if is_search_dragging and search_drag_source_type == "inventory":
					_end_search_drag_over_inventory(slot_index)
	
	elif event is InputEventMouseMotion and is_search_dragging:
		_update_search_drop_highlight(get_viewport().get_mouse_position())

func _select_ammo_from_box(cell: Control) -> void:
	# 检查当前弹药箱是否已被拾取
	var is_this_box_picked = current_interact_ammo_box.get_meta("picked", false) if current_interact_ammo_box else false
	if is_this_box_picked:
		return
	
	is_search_dragging = true
	search_drag_source_type = "ammo_box"
	search_drag_source_index = 4  # 弹药箱中间位置
	search_drag_item_data = {
		"name": "7.62x39mm",
		"icon": "ammo",
		"count": 30,
		"description": "7.62x39mm步枪弹药",
		"is_ammo": true
	}
	
	# 创建拖动预览
	_create_search_drag_preview()
	
	# 隐藏原格子
	var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)

func _start_ammo_drag(cell: Control, _slot_index: int, _ammo_box: Node3D) -> void:
	_select_ammo_from_box(cell)

func _update_ammo_slot_visual(_cell: Control) -> void:
	# 找到弹药箱格子并更新显示
	var center_index = 4  # 中间位置
	var ammo_box_grid = search_panel.find_child("AmmoBoxGrid", true, false)
	if not ammo_box_grid:
		return
	
	var slot = ammo_box_grid.get_child(center_index)
	if not slot:
		return
	
	# 清空格子内容
	for child in slot.get_children():
		child.queue_free()
	
	# 添加空样式
	var empty_label = Label.new()
	empty_label.text = ""
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(empty_label)


func _start_inventory_drag(cell: Control, slot_index: int, slot_data: Dictionary) -> void:
	is_search_dragging = true
	search_drag_source_type = "inventory"
	search_drag_source_index = slot_index
	search_drag_item_data = slot_data.duplicate(true)
	
	# 创建拖动预览
	_create_search_drag_preview()
	
	# 隐藏原格子
	var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)

func _create_search_drag_preview() -> void:
	if search_drag_preview:
		search_drag_preview.queue_free()
	
	search_drag_preview = PanelContainer.new()
	search_drag_preview.custom_minimum_size = Vector2(60, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_border_color(Color(1, 1, 1, 1))
	style.set_corner_radius_all(4)
	search_drag_preview.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	search_drag_preview.add_child(vbox)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.color = _get_search_item_color(search_drag_item_data.get("icon", ""))
	vbox.add_child(icon)
	
	var label = Label.new()
	label.text = "x" + str(search_drag_item_data.get("count", 1))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(label)
	
	search_panel.add_child(search_drag_preview)
	search_drag_preview.global_position = search_panel.global_position + get_viewport().get_mouse_position() - Vector2(30, 30)

func _process(_delta: float) -> void:
	# 拖动预览跟随鼠标
	if is_search_dragging and search_drag_preview:
		search_drag_preview.global_position = search_panel.global_position + get_viewport().get_mouse_position() - Vector2(30, 30)

func _place_ammo_to_inventory(target_index: int) -> void:
	# 从弹药箱放入背包
	if not is_search_dragging or search_drag_source_type != "ammo_box":
		return
	
	var target_data = inventory_panel.slots[target_index] if inventory_panel else {}
	
	if target_data.get("name", "") == "":
		# 空格子，直接放入
		inventory_panel.add_item_from_ammo_box(search_drag_item_data)
		# 标记当前弹药箱已被拾取（每个弹药箱独立追踪）
		if current_interact_ammo_box:
			current_interact_ammo_box.set_meta("picked", true)
		_update_ammo_ui()
		_refresh_search_after_drop()
	elif target_data.get("name", "") == search_drag_item_data["name"] and target_data.get("is_ammo", false):
		# 同类弹药叠加
		_add_to_inventory_slot(target_index, search_drag_item_data["count"])
		# 标记当前弹药箱已被拾取（每个弹药箱独立追踪）
		if current_interact_ammo_box:
			current_interact_ammo_box.set_meta("picked", true)
		_update_ammo_ui()
		_refresh_search_after_drop()
	else:
		# 不支持放入非弹药物品
		_cancel_search_drag()
		return
	
	# 立即更新弹药箱格子显示
	_refresh_ammo_box_slot()
	
	_end_search_drag()

func _refresh_ammo_box_slot() -> void:
	# 刷新弹药箱格子显示
	var center_index = 4
	var ammo_box_grid = search_panel.find_child("AmmoBoxGrid", true, false)
	if not ammo_box_grid:
		return
	
	var slot = ammo_box_grid.get_child(center_index)
	if not slot:
		return
	
	# 清空格子内容
	for child in slot.get_children():
		child.queue_free()
	
	# 如果当前弹药箱已被拾取，显示空样式
	var is_this_box_picked = current_interact_ammo_box.get_meta("picked", false) if current_interact_ammo_box else false
	if is_this_box_picked:
		var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.3)

func _end_search_drag_over_inventory(target_index: int) -> void:
	if not is_search_dragging:
		return
	
	# 获取目标格子数据
	var inventory_grid = search_panel.get_node("HBox/LeftPanel/InventoryGrid")
	var target_cell = inventory_grid.get_node_or_null("SearchSlot_" + str(target_index))
	if not target_cell:
		_cancel_search_drag()
		return
	
	var target_data = inventory_panel.slots[target_index] if inventory_panel else {}
	
	# 处理物品放置
	if search_drag_source_type == "inventory":
		# 背包内移动/交换
		if target_data.get("name", "") == "":
			# 空格子，直接移动
			_move_inventory_item(search_drag_source_index, target_index)
			_refresh_search_after_drop()
		elif target_data.get("name", "") == search_drag_item_data["name"]:
			# 同类物品，叠加
			_add_to_inventory_slot(target_index, search_drag_item_data["count"])
			_move_inventory_item(search_drag_source_index, -1)  # 清空源格子
			_refresh_search_after_drop()
		else:
			# 不同类，交换
			_swap_inventory_items(search_drag_source_index, target_index)
			_refresh_search_after_drop()
	
	_end_search_drag()

func _add_to_inventory_slot(slot_index: int, amount: int) -> void:
	if inventory_panel and slot_index >= 0 and slot_index < inventory_panel.slots.size():
		var slot = inventory_panel.slots[slot_index]
		slot["count"] += amount
		# 同步弹药到玩家
		if slot.get("is_ammo", false):
			_sync_ammo_to_player(slot["count"])

func _move_inventory_item(from_index: int, to_index: int) -> void:
	if not inventory_panel:
		return
	if to_index < 0:
		# 清空
		inventory_panel.slots[from_index] = {
			"id": from_index,
			"name": "",
			"icon": "",
			"count": 0,
			"description": "",
			"is_ammo": false
		}
	else:
		var temp = inventory_panel.slots[to_index].duplicate(true)
		inventory_panel.slots[to_index] = inventory_panel.slots[from_index].duplicate(true)
		inventory_panel.slots[to_index]["id"] = to_index
		inventory_panel.slots[from_index] = temp
		inventory_panel.slots[from_index]["id"] = from_index

func _swap_inventory_items(index1: int, index2: int) -> void:
	if not inventory_panel:
		return
	var temp = inventory_panel.slots[index1].duplicate(true)
	inventory_panel.slots[index1] = inventory_panel.slots[index2].duplicate(true)
	inventory_panel.slots[index1]["id"] = index1
	inventory_panel.slots[index2] = temp
	inventory_panel.slots[index2]["id"] = index2

func _sync_ammo_to_player(amount: int) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("set_reserve_ammo"):
		player.set_reserve_ammo(amount)

func _update_search_drop_highlight(mouse_pos: Vector2) -> void:
	if not is_search_dragging:
		return
	
	var inventory_grid = search_panel.get_node("HBox/LeftPanel/InventoryGrid")
	
	for i in range(28):
		var cell = inventory_grid.get_node_or_null("SearchSlot_" + str(i))
		if cell:
			var style = cell.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				if cell.get_global_rect().has_point(mouse_pos):
					var slot_data = inventory_panel.slots[i] if inventory_panel and i < inventory_panel.slots.size() else {}
					if slot_data.get("name", "") == search_drag_item_data.get("name", ""):
						style.border_color = Color(0.2, 0.9, 0.3, 1)  # 绿色=可叠加
					elif slot_data.get("name", "") == "":
						style.border_color = Color(0.9, 0.7, 0.2, 1)  # 黄色=可放置
					else:
						style.border_color = Color(0.8, 0.3, 0.3, 1)  # 红色=交换
				else:
					style.border_color = Color(0.3, 0.3, 0.3, 0.5)  # 默认

func _refresh_search_after_drop() -> void:
	# 刷新搜索界面的背包显示
	refresh_search_inventory()
	# 同步真实背包
	if inventory_panel:
		inventory_panel.refresh()

func _end_search_drag() -> void:
	is_search_dragging = false
	search_drag_source_type = ""
	search_drag_source_index = -1
	search_drag_item_data = {}
	
	if search_drag_preview:
		search_drag_preview.queue_free()
		search_drag_preview = null

func _cancel_search_drag() -> void:
	# 恢复原格子
	var source_cell
	if search_drag_source_type == "ammo_box":
		var ammo_grid = search_panel.get_node("HBox/RightPanel/AmmoBoxGrid")
		source_cell = ammo_grid.get_node_or_null("AmmoSlot_" + str(search_drag_source_index))
	else:
		var inventory_grid = search_panel.get_node("HBox/LeftPanel/InventoryGrid")
		source_cell = inventory_grid.get_node_or_null("SearchSlot_" + str(search_drag_source_index))
	
	if source_cell:
		var style = source_cell.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if search_drag_source_type == "ammo_box":
				style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
			else:
				style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	
	_end_search_drag()
	refresh_search_inventory()

# ===== 枪械晃动系统 =====
func _update_weapon_bob(delta: float) -> void:
	if not weapon:
		return
	
	# 换弹时忽略晃动，保持换弹动画
	if is_reloading:
		return
	
	# 检测是否在移动
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving := input_dir.length() > 0.1 and is_on_floor()
	var is_sprinting := Input.is_action_pressed("sprint") and is_moving
	
	# 计算晃动倍数
	var multiplier: float = 1.0
	if is_moving:
		if is_sprinting:
			multiplier = SPRINT_MULTIPLIER  # 奔跑 1.5倍
		elif is_ads:
			multiplier = 0.75  # 开镜 0.75倍
	
	if is_moving:
		# 更新晃动周期
		walk_cycle += delta * WALK_BOB_SPEED * multiplier
		
		# 计算晃动值
		var bob_y := sin(walk_cycle) * WALK_BOB_AMOUNT * multiplier
		var bob_x := cos(walk_cycle * 0.5) * WALK_BOB_AMOUNT * 0.5 * multiplier
		var sway_rot := sin(walk_cycle * 0.5) * WALK_SWAY_AMOUNT * multiplier
		
		# 应用晃动（叠加在基础位置/旋转上）
		var target_pos = base_weapon_pos + Vector3(bob_x, bob_y, 0)
		var target_rot = base_weapon_rot + Vector3(sway_rot * 0.3, sway_rot, sway_rot * 0.2)
		
		weapon.position = weapon.position.lerp(target_pos, 0.2)
		weapon.rotation = weapon.rotation.lerp(target_rot, 0.2)
	else:
		# 停止移动时，平滑恢复基础位置和旋转
		walk_cycle = 0.0
		weapon.position = weapon.position.lerp(base_weapon_pos, 0.15)
		weapon.rotation = weapon.rotation.lerp(base_weapon_rot, 0.15)
