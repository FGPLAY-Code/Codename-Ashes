extends Node3D

# ===== 撤离点参数 =====
const EXTRACTION_RADIUS: float = 5.0       # 撤离区半径（米）
const EXTRACTION_HEIGHT: float = 3.0       # 烟雾高度（米）
const COUNTDOWN_TIME: int = 10             # 倒计时秒数
const SPAWN_MIN: float = 5.0              # 距离玩家最小距离（米）
const SPAWN_MAX: float = 100.0            # 距离玩家最大距离（米）
const RAYCAST_HEIGHT: float = 50.0        # 射线起点高度

# ===== 节点引用 =====
@onready var detection_area: Area3D = $DetectionArea
@onready var particles: GPUParticles3D = $RedSmokeParticles

# ===== 状态 =====
var countdown_seconds: int = COUNTDOWN_TIME
var player_inside: bool = false
var extraction_in_progress: bool = false

# ===== 信号 =====
signal extraction_started(seconds_remaining: int)
signal extraction_progress(seconds_remaining: int)
signal extraction_cancelled()
signal extraction_complete()

func _ready() -> void:
	# 连接检测区域信号
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	
	# 延迟一帧等待碰撞体生成后再定位
	await get_tree().process_frame
	
	# 生成随机位置
	generate_random_position()
	
	print("[ExtractionPoint] 撤离点已生成，位置: ", global_position)

# 在玩家附近随机生成有效位置（不生成在虚空上）
func generate_random_position() -> void:
	# 获取玩家实际位置
	var player_spawn := Vector3(0, 0, 0)
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and is_instance_valid(players[0]):
		player_spawn = players[0].global_position
	
	var space_state = get_world_3d().direct_space_state
	
	# 尝试 30 次，找一个不在虚空上的位置
	for attempt in range(30):
		var angle := randf() * TAU
		var distance := randf_range(SPAWN_MIN, SPAWN_MAX)
		
		var offset := Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		var test_pos = player_spawn + offset
		
		# 向下打射线，检测正下方是否有地面
		var ray_from = Vector3(test_pos.x, RAYCAST_HEIGHT, test_pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_from + Vector3.DOWN * 100)
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			continue  # 下面是虚空，重试
		
		global_position = test_pos
		global_position.y = result.position.y + 0.5
		return  # 成功找到位置
	
	# 30 次都没找到，退回到玩家附近
	print("[ExtractionPoint] 警告：未找到有效撤离位置，退回玩家附近")
	global_position = player_spawn + Vector3(10, 0.5, 10)

# 玩家进入检测区域
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and not extraction_in_progress:
		player_inside = true
		start_extraction()
		print("[ExtractionPoint] 玩家进入撤离区")

# 玩家离开检测区域
func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") and extraction_in_progress:
		player_inside = false
		cancel_extraction()
		print("[ExtractionPoint] 玩家离开撤离区，取消撤离")

# 开始撤离
func start_extraction() -> void:
	if extraction_in_progress:
		return
	
	extraction_in_progress = true
	countdown_seconds = COUNTDOWN_TIME
	
	# 发送开始信号
	extraction_started.emit(countdown_seconds)
	
	# 改变粒子颜色表示激活
	if particles:
		var mat = particles.process_material as ParticleProcessMaterial
		if mat:
			# 更亮的红色表示激活状态
			mat.color = Color(1.0, 0.2, 0.1, 0.8)

# 玩家触发倒计时更新（由 player.gd 每秒调用）
func on_countdown_tick() -> void:
	countdown_seconds -= 1
	
	if countdown_seconds > 0:
		extraction_progress.emit(countdown_seconds)
		print("[ExtractionPoint] 撤离倒计时: ", countdown_seconds)
	else:
		complete_extraction()

# 取消撤离
func cancel_extraction() -> void:
	extraction_in_progress = false
	countdown_seconds = COUNTDOWN_TIME
	
	extraction_cancelled.emit()
	
	# 恢复粒子颜色
	if particles:
		var mat = particles.process_material as ParticleProcessMaterial
		if mat:
			mat.color = Color(1.0, 0.1, 0.0, 0.6)

# 完成撤离
func complete_extraction() -> void:
	extraction_in_progress = false
	
	# 发送完成信号
	extraction_complete.emit()
	
	print("[ExtractionPoint] 撤离完成！")

# 获取当前倒计时剩余秒数
func get_countdown() -> int:
	return countdown_seconds

# 是否正在撤离中
func is_extracting() -> bool:
	return extraction_in_progress
