extends CharacterBody3D

enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }

@export var max_health: float = 100.0
@export var move_speed: float = 2.0
@export var chase_speed: float = 4.0
@export var detection_radius: float = 15.0
@export var attack_range: float = 8.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var patrol_enabled: bool = true
@export var patrol_radius: float = 10.0

var health: float = 100.0
var current_state: State = State.IDLE
var can_attack: bool = true
var player_ref: Node3D = null
var patrol_target: Vector3
var muzzle_pos: Node3D
var glb_node: Node3D
var glb_initial_transform: Transform3D
var anim_player: AnimationPlayer

# 状态计时器（替代 await，避免冻结物理帧）
var _patrol_wait_timer: float = 0.0
var _dead_timer: float = 0.0
var _lost_sight_timer: float = 0.0
const LOST_SIGHT_TIMEOUT: float = 3.0  # 丢失视线多久后放弃追击
const EDGE_CHECK_DIST: float = 1.5     # 边缘检测前方距离
const EDGE_MAX_DROP: float = 2.0       # 允许的最大落差（米）

# 重力
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	health = max_health
	add_to_group("Enemy")

	# 碰撞层配置
	# layer = 2：自身在第2层（让玩家子弹/敌人子弹能检测到敌人）
	# mask = 1（地面）| 2（玩家/敌人自身）：能站在地面上，也能与其他第2层物体交互
	collision_layer = 2
	collision_mask = 1 | 2  # = 3

	# 获取节点引用
	muzzle_pos = get_node_or_null("MuzzlePos")

	# GLB 模型初始化
	glb_node = get_node_or_null("SoldierMesh")
	if glb_node:
		_disable_glb_collisions(glb_node)
		glb_initial_transform = glb_node.transform
		print("[Enemy] GLB 初始位置: ", glb_node.position, " 旋转: ", glb_node.rotation)

	# 动画系统（已禁用，仅做初始化）
	anim_player = _find_animation_player(self)
	if anim_player:
		_strip_position_tracks(anim_player)
		print("[Enemy] AnimationPlayer 动画列表: ", anim_player.get_animation_list())

	# 自动创建 DetectionRange（场景中可能缺失）
	_setup_detection_range()

	# 自动创建 3D 血条
	_setup_health_bar()

	# 巡逻初始化
	if patrol_enabled:
		_pick_patrol_target()
		current_state = State.PATROL


func _setup_detection_range() -> void:
	# 如果场景已有 DetectionRange 就复用
	var dr = get_node_or_null("DetectionRange")
	if dr:
		var cs = dr.get_node_or_null("CollisionShape3D")
		if cs and cs.shape:
			cs.shape.radius = detection_radius
		dr.body_entered.connect(_on_detection_body_entered)
		dr.body_exited.connect(_on_detection_body_exited)
		return

	# 动态创建 DetectionRange
	dr = Area3D.new()
	dr.name = "DetectionRange"
	var shape = SphereShape3D.new()
	shape.radius = detection_radius
	var cs_new = CollisionShape3D.new()
	cs_new.shape = shape
	dr.add_child(cs_new)
	add_child(dr)
	dr.body_entered.connect(_on_detection_body_entered)
	dr.body_exited.connect(_on_detection_body_exited)


func _setup_health_bar() -> void:
	# 如果场景已有 HealthBar 子节点就跳过
	if has_node("HealthBar3D"):
		return

	var bar_root = Node3D.new()
	bar_root.name = "HealthBar3D"
	# 放在胶囊顶部上方
	bar_root.position.y = 2.8

	# 背景板（黑色半透明）
	var bg = MeshInstance3D.new()
	bg.name = "Background"
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(1.2, 0.12)
	bg.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = Color(0, 0, 0, 0.5)
	bg_mat.no_depth_test = true
	bg.material_override = bg_mat
	bar_root.add_child(bg)

	# 血条（红色）
	var bar = MeshInstance3D.new()
	bar.name = "Bar"
	var bar_quad = QuadMesh.new()
	bar_quad.size = Vector2(1.1, 0.08)
	bar.mesh = bar_quad
	var bar_mat = StandardMaterial3D.new()
	bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bar_mat.albedo_color = Color(0.9, 0.15, 0.15, 0.9)
	bar_mat.no_depth_test = true
	bar.material_override = bar_mat
	bar.position.z = 0.001  # 略微前移避免z-fighting
	bar_root.add_child(bar)

	add_child(bar_root)


func _update_health_bar_3d() -> void:
	var bar_root = get_node_or_null("HealthBar3D")
	if not bar_root:
		return

	var ratio = clampf(health / max_health, 0.0, 1.0)
	var bar = bar_root.get_node_or_null("Bar") as MeshInstance3D
	if bar and bar.mesh is QuadMesh:
		var quad = bar.mesh as QuadMesh
		quad.size.x = 1.1 * ratio
		# 从中心缩小需要偏移位置
		bar.position.x = -0.55 * (1.0 - ratio)

	# 血条始终面向相机
	var cam = get_viewport().get_camera_3d()
	if cam:
		bar_root.look_at(cam.global_position, Vector3.UP)
	# 默认隐藏，受伤后显示
	bar_root.visible = health < max_health


func _disable_glb_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_glb_collisions(child)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	# 同步 GLB 模型
	if glb_node:
		# 基础变换 = 初始偏移（相对父节点）
		glb_node.transform = glb_initial_transform
		# 叠加 CharacterBody3D 的全局朝向（只旋转 Y 轴）
		glb_node.global_rotation.y = global_rotation.y + glb_initial_transform.basis.get_euler(EULER_ORDER_YXZ).y

	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 3D 血条更新 + 面向相机
	_update_health_bar_3d()

	# 状态机
	match current_state:
		State.IDLE:
			_do_idle(delta)
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			_do_chase(delta)
		State.ATTACK:
			_do_attack(delta)
		State.DEAD:
			_do_dead(delta)


# ====== 状态处理（全部用 delta 计时，不使用 await） ======

func _do_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _do_patrol(delta: float) -> void:
	if not patrol_enabled:
		current_state = State.IDLE
		return

	# 等待计时
	if _patrol_wait_timer > 0:
		velocity = Vector3.ZERO
		_patrol_wait_timer -= delta
		move_and_slide()
		return

	var direction = (patrol_target - global_position)
	direction.y = 0
	var dist = direction.length()

	if dist > 1.0:
		direction = direction.normalized()
		# 前方边缘检测：如果前面是悬崖，换巡逻目标
		if not _is_path_ahead_safe(direction):
			_pick_patrol_target()
			velocity = Vector3.ZERO
			_patrol_wait_timer = 1.0
			move_and_slide()
			return
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(global_position + direction, Vector3.UP)
	else:
		# 到达巡逻点，等待后选新目标
		velocity = Vector3.ZERO
		_patrol_wait_timer = 2.0
		_pick_patrol_target()

	move_and_slide()


func _do_chase(delta: float) -> void:
	# 玩家引用检查
	if not _is_player_valid():
		_return_to_patrol()
		return

	var player_pos = player_ref.global_position
	var distance = global_position.distance_to(player_pos)

	# 超出视野范围
	if distance > detection_radius * 1.5:
		_return_to_patrol()
		return

	# 视线检测：被遮挡则累计丢失计时
	if not _has_line_of_sight(player_pos):
		_lost_sight_timer += delta
		if _lost_sight_timer >= LOST_SIGHT_TIMEOUT:
			_return_to_patrol()
			return
	else:
		_lost_sight_timer = 0.0

	# 进入攻击范围
	if distance <= attack_range:
		current_state = State.ATTACK
		return

	# 追击移动 + 边缘检测
	var direction = (player_pos - global_position).normalized()
	direction.y = 0
	
	# 如果正前方是悬崖，尝试斜向/横向绕行
	if not _is_path_ahead_safe(direction):
		# 先试左前方45°
		var left = direction.rotated(Vector3.UP, deg_to_rad(45))
		if _is_path_ahead_safe(left):
			direction = left
		else:
			# 再试右前方45°
			var right = direction.rotated(Vector3.UP, deg_to_rad(-45))
			if _is_path_ahead_safe(right):
				direction = right
			else:
				# 都不可走，横向移动
				var side = direction.rotated(Vector3.UP, deg_to_rad(90))
				if _is_path_ahead_safe(side):
					direction = side
				else:
					direction = direction.rotated(Vector3.UP, deg_to_rad(-90))
	
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	look_at(global_position + direction, Vector3.UP)
	move_and_slide()


func _do_attack(_delta: float) -> void:
	if not _is_player_valid():
		_return_to_patrol()
		return

	var dist = global_position.distance_to(player_ref.global_position)

	# 超出攻击范围 → 继续追
	if dist > attack_range:
		current_state = State.CHASE
		return

	# 面向玩家
	var dir = (player_ref.global_position - global_position).normalized()
	if dir.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	velocity = Vector3.ZERO
	move_and_slide()

	# 开火
	if can_attack:
		attack()


func _do_dead(delta: float) -> void:
	velocity = Vector3.ZERO
	_dead_timer += delta
	if _dead_timer >= 0.5:
		queue_free()


# ====== 工具方法 ======

func _is_player_valid() -> bool:
	return player_ref != null and is_instance_valid(player_ref)


func _return_to_patrol() -> void:
	player_ref = null
	_lost_sight_timer = 0.0
	if patrol_enabled:
		current_state = State.PATROL
	else:
		current_state = State.IDLE


func _pick_patrol_target() -> void:
	patrol_target = global_position + Vector3(
		randf() * patrol_radius - patrol_radius / 2.0,
		0,
		randf() * patrol_radius - patrol_radius / 2.0
	)


func _has_line_of_sight(target_pos: Vector3) -> bool:
	var from = global_position + Vector3(0, 1.5, 0)  # 敌人眼睛高度
	var to = target_pos + Vector3(0, 0.9, 0)          # 玩家胸口
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # 排除自身
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # 没有命中障碍物 = 视线畅通


## 边缘检测：检查前方 EDGE_CHECK_DIST 处的地面是否安全
## 返回 true = 可以向前走，false = 前面是悬崖/虚空
func _is_path_ahead_safe(direction: Vector3) -> bool:
	var forward_pos = global_position + direction.normalized() * EDGE_CHECK_DIST
	forward_pos.y += 0.3  # 避免从脚下穿过
	
	var space_state = get_world_3d().direct_space_state
	
	# 第一步：正前方下方是否有地面？
	var down_query = PhysicsRayQueryParameters3D.create(
		forward_pos,
		forward_pos + Vector3.DOWN * 10
	)
	down_query.collision_mask = 1  # layer 1 = 地面
	var hit = space_state.intersect_ray(down_query)
	if hit.is_empty():
		return false  # 前方是虚空
	
	# 第二步：落差是否超过 EDGE_MAX_DROP？
	var drop = forward_pos.y - hit.position.y
	if drop > EDGE_MAX_DROP:
		return false  # 落差太大
	
	return true


func _scan_for_player() -> void:
	# 仅作为 Area3D 信号的补充兜底
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var p = players[0]
		if is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			if dist <= detection_radius and _has_line_of_sight(p.global_position):
				player_ref = p
				_lost_sight_timer = 0.0
				current_state = State.CHASE
				print("[Enemy] 扫描发现玩家！距离: ", dist)


# ====== 动画辅助 ======

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null


func _strip_position_tracks(ap: AnimationPlayer) -> void:
	for anim_name in ap.get_animation_list():
		var anim = ap.get_animation(anim_name)
		if not anim:
			continue
		var tracks_to_clear: Array[int] = []
		for i in range(anim.get_track_count()):
			if anim.track_get_type(i) == 3:  # Transform 轨道
				tracks_to_clear.append(i)
		for i in range(tracks_to_clear.size() - 1, -1, -1):
			anim.remove_track(tracks_to_clear[i])
		if tracks_to_clear.size() > 0:
			print("[Enemy] 清除 '", anim_name, "' 的 Transform 轨道: ", tracks_to_clear.size(), " 条")


# ====== 战斗 ======

func attack():
	if not can_attack or not _is_player_valid():
		can_attack = true
		return

	can_attack = false
	_fire_bullet()
	print("[Enemy] 开枪！")

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _fire_bullet() -> void:
	if not _is_player_valid():
		return

	var bullet_script = load("res://scripts/enemy_bullet.gd")
	var bullet = Area3D.new()
	bullet.set_script(bullet_script)

	# 枪口位置
	var spawn_pos: Vector3
	if muzzle_pos:
		spawn_pos = muzzle_pos.global_position
	else:
		spawn_pos = global_position + Vector3(0, 1.35, 0) + (-global_transform.basis.z) * 0.3

	# 瞄准玩家胸口 + 随机散布（±5度）
	var aim_target = player_ref.global_position + Vector3(0, 0.9, 0)
	var base_dir = (aim_target - spawn_pos).normalized()
	var spread = randf_range(-0.087, 0.087)
	var spread_dir = base_dir.rotated(Vector3.UP, spread)
	spread_dir = spread_dir.rotated(spread_dir.cross(Vector3.UP).normalized(), spread)

	bullet.direction = spread_dir
	bullet.damage = damage
	bullet.owner_enemy = self

	var world = get_tree().root
	world.add_child(bullet)
	bullet.global_position = spawn_pos


func take_damage(amount: float):
	if current_state == State.DEAD:
		return

	health -= amount
	print("[Enemy] 被击中！剩余血量: ", health)

	velocity = Vector3.ZERO

	if health <= 0:
		die()
	else:
		if current_state == State.IDLE or current_state == State.PATROL:
			# 被打时直接知道玩家在哪，立即追击
			player_ref = _get_nearest_player()
			if player_ref:
				_lost_sight_timer = 0.0
				current_state = State.CHASE


func die():
	current_state = State.DEAD
	_dead_timer = 0.0
	print("[Enemy] 死亡！")


# ====== 交互系统 ======

func interact(_player: Node3D) -> void:
	# 交互回调 - 玩家按E键对准敌人时调用
	# 目前实现：近战攻击，造成50点伤害
	if current_state == State.DEAD:
		return
	
	print("[Enemy] 玩家交互！触发近战攻击")
	take_damage(50.0)


func _get_nearest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("Player")
	var nearest: Node3D = null
	var min_dist: float = INF
	for p in players:
		if is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				nearest = p
	return nearest


# ====== Area3D 信号回调 ======

func _on_detection_body_entered(body):
	if body == null or not is_instance_valid(body):
		return
	if body.name == "Player" or body.has_method("take_damage"):
		player_ref = body
		_lost_sight_timer = 0.0
		if current_state == State.IDLE or current_state == State.PATROL:
			current_state = State.CHASE
			print("[Enemy] DetectionRange 发现玩家！")


func _on_detection_body_exited(body):
	if body == player_ref:
		# 不立即放弃，给 _do_chase 中的视线检测 + 计时器来处理
		# 这样短暂丢失（如玩家快速跑过遮挡物后）不会中断追击
		print("[Enemy] 玩家离开 DetectionRange")
