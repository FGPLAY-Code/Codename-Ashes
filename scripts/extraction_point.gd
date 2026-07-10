extends Node3D

# ===== 撤离点参数 =====
const EXTRACTION_RADIUS: float = 5.0       # 撤离区半径（米）
const EXTRACTION_HEIGHT: float = 3.0       # 烟雾高度（米）
const COUNTDOWN_TIME: int = 10             # 倒计时秒数
const SPAWN_RANGE: float = 200.0          # 距离玩家出生点最大距离（米）

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
	
	# 生成随机位置
	generate_random_position()
	
	print("[ExtractionPoint] 撤离点已生成，位置: ", global_position)

# 在玩家出生点附近生成随机位置
func generate_random_position() -> void:
	# 玩家出生点
	var player_spawn := Vector3(0, 0, 0)
	
	# 在 50-200 米范围内随机生成
	var angle := randf() * TAU  # 0 到 2π 的随机角度
	var distance := randf_range(50.0, SPAWN_RANGE)
	
	var offset := Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	
	global_position = player_spawn + offset
	
	# 确保在地面上方
	global_position.y = 0.5

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
