extends Resource
class_name WeaponData

## 枪械基础属性数据资源
## 每把枪一个 .tres 文件，在 Inspector 中创建和编辑

# ===== 标识 =====
@export var weapon_name: String = "AKM"
@export var display_name: String = "AK-47"

# ===== 散射参数 =====
@export var stand_spread_deg: float = 3.0
@export var crouch_spread_mult: float = 0.05
@export var ads_spread_mult: float = 0.35
@export var move_spread_mult: float = 1.6
@export var vert_mult: float = 0.8

# ===== 射击参数 =====
@export var base_damage: float = 25.0
@export var magazine_capacity: int = 30
@export var reserve_ammo_start: int = 90
@export var fire_rate_auto: float = 0.08
@export var fire_rate_semi: float = 0.15

# ===== 后坐力 =====
@export var recoil_kick: float = 0.03

# ===== Bloom =====
@export var bloom_per_shot: float = 0.15
@export var bloom_recovery: float = 0.6

# ===== 爆头检测 =====
@export var head_bottom_offset: float = 4.0
@export var head_top_offset: float = 4.5

# ===== 音效 =====
@export var gun_sound_path: String = "res://resources/mp3/ak_gunshot.mp3"
