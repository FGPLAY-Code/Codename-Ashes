extends Node

## 枪械散射控制器
## 优先读取 weapon_data（WeaponData 资源），为 null 时降级使用 @export 默认值

@export var weapon_data: WeaponData = null

@export var stand_spread_deg: float = 3.0
@export var crouch_spread_mult: float = 0.05
@export var ads_spread_mult: float = 0.35
@export var move_spread_mult: float = 1.6
@export var vert_mult: float = 0.8

func _get_stand() -> float:    return weapon_data.stand_spread_deg if weapon_data else stand_spread_deg
func _get_crouch() -> float:   return weapon_data.crouch_spread_mult if weapon_data else crouch_spread_mult
func _get_ads() -> float:      return weapon_data.ads_spread_mult if weapon_data else ads_spread_mult
func _get_move() -> float:     return weapon_data.move_spread_mult if weapon_data else move_spread_mult
func _get_vert() -> float:     return weapon_data.vert_mult if weapon_data else vert_mult

func get_spread_deg(crouching: bool, ads: bool, moving: bool, bloom_deg: float) -> float:
	var deg = _get_stand()
	if crouching: deg *= _get_crouch()
	if ads: deg *= _get_ads()
	if moving: deg *= _get_move()
	deg += bloom_deg
	return deg

func get_spread_direction(forward: Vector3, crouching: bool, ads: bool, moving: bool, bloom_deg: float) -> Vector3:
	var s = deg_to_rad(get_spread_deg(crouching, ads, moving, bloom_deg))
	if s <= 0.0:
		return forward
	var r = sqrt(randf())
	var a = randf() * TAU
	var off_y = sin(a) * s * r
	var off_x = cos(a) * s * r * _get_vert()
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()
	return (forward + right * off_x + up * off_y).normalized()
