"""
绿洲行动 - 灰烬峡谷 废墟场景生成器
Ash Ravine - Ruins Scene Generator

使用方法：
1. 打开 Blender (新建场景)
2. Scripting 工作区
3. 打开此脚本
4. 点击 "运行脚本"
5. 模型会自动生成在原点附近
"""

import bpy
import math
import random
from mathutils import Vector

# 设置随机种子（可改）
random.seed(42)

# ===== 工具函数 =====

def clear_scene():
    """清空场景"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # 清空材质
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)

def create_material(name, color, roughness=0.8, metallic=0.1):
    """创建基础材质"""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    # 清除默认节点
    nodes.clear()
    # 添加 Principled BSDF
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    # 添加输出节点
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (200, 0)
    # 连接
    mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def set_smooth(obj, smooth=True):
    """设置平滑/扁平着色"""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth() if smooth else bpy.ops.object.shade_flat()

# ===== 建筑生成函数 =====

def create_building(x, y, z, width=6, depth=6, height=4, rotation_y=0, damage=0.2):
    """创建建筑主体"""
    h = height * random.uniform(1-damage, 1+damage*0.5)
    
    # 主体
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + h/2))
    building = bpy.context.active_object
    building.scale = (width, depth, h)
    building.rotation_euler = (0, 0, rotation_y)
    building.name = "Building"
    
    mat = create_material("Mat_Building", (0.45, 0.42, 0.4), roughness=0.9, metallic=0)
    building.data.materials.append(mat)
    set_smooth(building, smooth=False)
    
    # 添加窗户（如果建筑够大）
    if width >= 4 and height >= 3:
        window_mat = create_material("Mat_Window", (0.2, 0.25, 0.3), roughness=0.1, metallic=0.8)
        for i in range(int(width / 2)):
            wx = x + (i - width/4 + 0.5) * 2
            bpy.ops.mesh.primitive_cube_add(size=2, location=(wx, y - depth/2 - 0.01, z + h * 0.6))
            win = bpy.context.active_object
            win.scale = (0.6, 0.05, 0.8)
            win.rotation_euler = (0, 0, rotation_y)
            win.data.materials.append(window_mat)
    
    return building

def create_factory(x, y, z, rotation_y=0):
    """创建工厂建筑"""
    mat = create_material("Mat_Factory", (0.35, 0.33, 0.3), roughness=0.85, metallic=0.3)
    
    # 主体厂房
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 4))
    factory = bpy.context.active_object
    factory.scale = (15, 8, 4)
    factory.rotation_euler = (0, 0, rotation_y)
    factory.name = "Factory"
    factory.data.materials.append(mat)
    
    # 烟囱
    bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=10, location=(x + 5, y, z + 9), rotation=(math.pi/2, 0, rotation_y))
    chimney = bpy.context.active_object
    chimney.name = "Chimney"
    chimney_mat = create_material("Mat_Chimney", (0.3, 0.28, 0.25), roughness=0.95, metallic=0)
    chimney.data.materials.append(chimney_mat)
    
    return factory, chimney

def create_watchtower(x, y, z, rotation_y=0):
    """创建瞭望塔"""
    mat = create_material("Mat_Tower_Metal", (0.4, 0.38, 0.35), roughness=0.6, metallic=0.7)
    
    # 塔身
    bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=8, location=(x, y, z + 4), rotation=(math.pi/2, 0, rotation_y))
    tower = bpy.context.active_object
    tower.name = "Watchtower"
    tower.data.materials.append(mat)
    
    # 平台
    bpy.ops.mesh.primitive_cylinder_add(radius=2, depth=0.3, location=(x, y, z + 8), rotation=(math.pi/2, 0, rotation_y))
    platform = bpy.context.active_object
    platform.name = "TowerPlatform"
    platform.data.materials.append(mat)
    
    # 栏杆
    rail_mat = create_material("Mat_Rail", (0.5, 0.2, 0.1), roughness=0.5, metallic=0.8)
    for angle in [0, math.pi/2, math.pi, math.pi*1.5]:
        rx = x + math.cos(angle) * 1.5
        ry = y + math.sin(angle) * 1.5
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=1, location=(rx, ry, z + 8.5), rotation=(math.pi/2, 0, rotation_y))
        rail = bpy.context.active_object
        rail.data.materials.append(rail_mat)
    
    return tower

def create_oiltank(x, y, z, rotation_y=0):
    """创建油罐"""
    mat = create_material("Mat_Oiltank", (0.2, 0.25, 0.3), roughness=0.4, metallic=0.8)
    
    bpy.ops.mesh.primitive_cylinder_add(radius=2.5, depth=6, location=(x, y, z + 2.5), rotation=(math.pi/2, 0, rotation_y))
    tank = bpy.context.active_object
    tank.name = "OilTank"
    tank.data.materials.append(mat)
    
    # 顶部管道
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=2, location=(x, y, z + 5), rotation=(0, 0, 0))
    pipe = bpy.context.active_object
    pipe.name = "TankPipe"
    pipe.data.materials.append(mat)
    
    return tank

def create_wrecked_vehicle(x, y, z, rotation_y=0):
    """创建废弃车辆"""
    mat = create_material("Mat_Vehicle", (0.3, 0.2, 0.15), roughness=0.7, metallic=0.6)
    
    # 车身
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 0.6))
    car = bpy.context.active_object
    car.scale = (2, 4, 0.8)
    car.rotation_euler = (random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), rotation_y + random.uniform(-0.3, 0.3))
    car.name = "WreckedCar"
    car.data.materials.append(mat)
    
    return car

def create_fence(x, y, z, length=10, rotation_y=0):
    """创建围栏"""
    mat = create_material("Mat_Fence", (0.35, 0.3, 0.25), roughness=0.8, metallic=0.4)
    
    # 立柱
    for i in range(int(length / 2) + 1):
        px = x + i * 2
        bpy.ops.mesh.primitive_cube_add(size=2, location=(px, y, z + 1))
        post = bpy.context.active_object
        post.scale = (0.1, 0.1, 2)
        post.rotation_euler = (0, 0, rotation_y)
        post.name = "FencePost"
        post.data.materials.append(mat)
    
    # 横杆
    for h in [0.5, 1.5]:
        bpy.ops.mesh.primitive_cube_add(size=2, location=(x + length/2, y, z + h))
        rail = bpy.context.active_object
        rail.scale = (length, 0.05, 0.05)
        rail.rotation_euler = (0, 0, rotation_y)
        rail.name = "FenceRail"
        rail.data.materials.append(mat)
    
def create_rubble_pile(x, y, z, size=5):
    """创建大型碎石堆"""
    mat = create_material("Mat_Rubble", (0.45, 0.4, 0.35), roughness=0.95, metallic=0)
    
    # 大块
    for _ in range(10):
        bx = x + random.uniform(-size, size)
        by = y + random.uniform(-size, size)
        bz = z + random.uniform(0, size * 0.5)
        bpy.ops.mesh.primitive_cube_add(size=2, location=(bx, by, bz))
        rock = bpy.context.active_object
        rock.scale = (
            random.uniform(0.5, 2),
            random.uniform(0.5, 2),
            random.uniform(0.3, 1.5)
        )
        rock.rotation_euler = (
            random.uniform(-0.5, 0.5),
            random.uniform(-0.5, 0.5),
            random.uniform(0, math.pi)
        )
        rock.name = "Rubble"
        rock.data.materials.append(mat)

def create_container(x, y, z, rotation_y=0, color_type='gray'):
    """创建集装箱"""
    # 颜色配置
    colors = {
        'gray': (0.35, 0.35, 0.38),
        'rust': (0.45, 0.25, 0.15),
        'blue': (0.2, 0.3, 0.45),
        'green': (0.2, 0.35, 0.2)
    }
    color = colors.get(color_type, colors['gray'])
    
    # 创建主体
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z))
    container = bpy.context.active_object
    container.scale = (3, 1.5, 1)  # 标准集装箱比例
    container.rotation_euler = (0, 0, rotation_y)
    container.name = f"Container_{color_type}"
    
    # 添加材质
    mat = create_material(f"Mat_Container_{color_type}", color, roughness=0.7, metallic=0.3)
    container.data.materials.append(mat)
    
    # 顶部加横条细节
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 0.95))
    detail = bpy.context.active_object
    detail.scale = (3.1, 1.6, 0.05)
    detail.rotation_euler = (0, 0, rotation_y)
    detail.data.materials.append(mat)
    
    set_smooth(container, smooth=False)
    
    return container

def create_ruined_wall(x, y, z, height=3, rotation_y=0):
    """创建废墟墙"""
    # 随机高度变化
    h = height + random.uniform(-0.5, 1)
    
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + h/2))
    wall = bpy.context.active_object
    wall.scale = (0.4, random.uniform(2, 4), h)
    wall.rotation_euler = (0, 0, rotation_y)
    wall.name = "RuinedWall"
    
    mat = create_material("Mat_Wall", (0.5, 0.45, 0.4), roughness=0.9, metallic=0)
    wall.data.materials.append(mat)
    set_smooth(wall, smooth=False)
    
    return wall

def create_debris(x, y, z, count=5):
    """创建碎石堆"""
    debris = []
    mat = create_material("Mat_Debris", (0.4, 0.38, 0.35), roughness=0.95, metallic=0)
    
    for i in range(count):
        bx = x + random.uniform(-1.5, 1.5)
        by = y + random.uniform(-1.5, 1.5)
        bz = z + random.uniform(0, 0.5)
        
        bpy.ops.mesh.primitive_cube_add(size=2, location=(bx, by, bz))
        rock = bpy.context.active_object
        rock.scale = (
            random.uniform(0.2, 0.8),
            random.uniform(0.2, 0.8),
            random.uniform(0.1, 0.4)
        )
        rock.rotation_euler = (
            random.uniform(-0.3, 0.3),
            random.uniform(-0.3, 0.3),
            random.uniform(0, math.pi)
        )
        rock.name = f"Debris_{i}"
        rock.data.materials.append(mat)
        debris.append(rock)
    
    return debris

def create_barrier(x, y, z, rotation_y=0):
    """创建掩体"""
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 0.6))
    barrier = bpy.context.active_object
    barrier.scale = (1.5, 0.3, 0.6)
    barrier.rotation_euler = (0, 0, rotation_y)
    barrier.name = "Barrier"
    
    mat = create_material("Mat_Barrier", (0.3, 0.3, 0.32), roughness=0.6, metallic=0.5)
    barrier.data.materials.append(mat)
    set_smooth(barrier, smooth=False)
    
    return barrier

def create_tower(x, y, z, rotation_y=0):
    """创建吊塔残骸"""
    # 塔身
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.3, depth=8,
        location=(x, y, z + 4),
        rotation=(math.pi/2, 0, rotation_y)
    )
    tower = bpy.context.active_object
    tower.name = "Tower"
    
    mat = create_material("Mat_Tower", (0.4, 0.35, 0.3), roughness=0.7, metallic=0.6)
    tower.data.materials.append(mat)
    
    # 横臂
    bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 7.5))
    arm = bpy.context.active_object
    arm.scale = (3, 0.15, 0.15)
    arm.rotation_euler = (0, 0, rotation_y)
    arm.data.materials.append(mat)
    
    return tower, arm

def create_crate_stack(x, y, z, count=3):
    """创建木箱堆"""
    crates = []
    mat = create_material("Mat_Crate", (0.45, 0.35, 0.2), roughness=0.85, metallic=0)
    
    for i in range(count):
        bpy.ops.mesh.primitive_cube_add(size=2, location=(x, y, z + 0.5 + i * 0.9))
        crate = bpy.context.active_object
        crate.scale = (0.6, 0.6, 0.6)
        crate.rotation_euler = (0, 0, random.uniform(-0.2, 0.2))
        crate.name = f"Crate_{i}"
        crate.data.materials.append(mat)
        set_smooth(crate, smooth=False)
        crates.append(crate)
    
    return crates

# ===== 主生成函数 =====

def generate_ash_ravine():
    """生成灰烬峡谷场景"""
    print("=" * 50)
    print("正在生成: 灰烬峡谷 (Ash Ravine)")
    print("=" * 50)
    
    # 清空场景
    clear_scene()
    
    # ===== 集装箱区域 (港口/仓库) =====
    print("生成集装箱...")
    # 分散在 -250 到 250 范围内
    container_positions = [
        (50, 0, 0, 0, 'gray'),
        (80, 40, 0, math.pi/6, 'rust'),
        (60, -50, 0, -math.pi/4, 'blue'),
        (120, 20, 0, 0, 'gray'),
        (100, 80, 0, math.pi/2, 'green'),
        (-60, 100, 0, 0, 'rust'),
        (-120, 60, 0, -math.pi/3, 'gray'),
        (-80, -80, 0, math.pi/4, 'blue'),
        (180, -120, 0, math.pi/8, 'gray'),
        (-160, 150, 0, -math.pi/5, 'rust'),
        (200, 50, 0, math.pi/3, 'blue'),
        (-180, -30, 0, 0, 'green'),
    ]
    for pos in container_positions:
        create_container(*pos)
    
    # ===== 废墟墙 =====
    print("生成废墟墙...")
    wall_positions = [
        (0, 150, 0, 4, 0),
        (30, 180, 0, 3.5, math.pi/8),
        (-50, 120, 0, 2.5, -math.pi/6),
        (200, -150, 0, 5, math.pi/4),
        (-180, 50, 0, 4, 0),
        (-150, -120, 0, 3, math.pi/3),
        (100, 200, 0, 4.5, -math.pi/4),
        (-100, -200, 0, 3.5, math.pi/6),
        (180, 100, 0, 5, 0),
        (-200, -80, 0, 4, math.pi/5),
    ]
    for pos in wall_positions:
        create_ruined_wall(*pos)
    
    # ===== 碎石堆 =====
    print("生成碎石堆...")
    # 大范围随机分布
    debris_centers = []
    for _ in range(50):  # 增加到50堆
        cx = random.uniform(-250, 250)
        cy = random.uniform(-250, 250)
        debris_centers.append((cx, cy))
    for cx, cy in debris_centers:
        create_debris(cx, cy, 0, count=random.randint(3, 8))
    
    # ===== 掩体 =====
    print("生成掩体...")
    barrier_positions = [
        (20, 50, 0, 0),
        (-40, 30, 0, math.pi/6),
        (70, -30, 0, -math.pi/4),
        (-60, -50, 0, math.pi/3),
        (0, -100, 0, 0),
        (100, 0, 0, math.pi/8),
        (-80, 80, 0, -math.pi/3),
        (150, 80, 0, math.pi/4),
        (-150, -60, 0, 0),
        (80, -120, 0, -math.pi/6),
        (-30, 150, 0, math.pi/5),
        (180, -80, 0, 0),
        (-180, 30, 0, math.pi/3),
        (50, -180, 0, -math.pi/4),
        (-100, 0, 0, 0),
    ]
    for pos in barrier_positions:
        create_barrier(*pos)
    
    # ===== 吊塔 =====
    print("生成吊塔...")
    create_tower(-200, 150, 0, rotation_y=math.pi/4)
    create_tower(220, -180, 0, rotation_y=-math.pi/6)
    create_tower(-150, -200, 0, rotation_y=math.pi/3)
    create_tower(180, 200, 0, rotation_y=-math.pi/5)
    
    # ===== 木箱堆 =====
    print("生成木箱堆...")
    create_crate_stack(30, 80, 0, 3)
    create_crate_stack(-70, 50, 0, 2)
    create_crate_stack(80, -100, 0, 4)
    create_crate_stack(-120, -150, 0, 3)
    create_crate_stack(150, 120, 0, 2)
    create_crate_stack(-180, 80, 0, 4)
    create_crate_stack(100, -180, 0, 3)
    
    # ===== 建筑 =====
    print("生成建筑...")
    building_positions = [
        (0, 200, 0, 8, 6, 5, 0),      # 中心大建筑
        (-150, 180, 0, 6, 5, 4, math.pi/6),
        (180, 150, 0, 10, 8, 6, -math.pi/4),
        (-100, -180, 0, 7, 7, 4, math.pi/3),
        (150, -150, 0, 6, 6, 5, 0),
        (80, 220, 0, 5, 4, 3, math.pi/8),
        (-200, 100, 0, 8, 5, 4, -math.pi/5),
        (220, -100, 0, 6, 6, 5, math.pi/3),
    ]
    for pos in building_positions:
        create_building(*pos)
    
    # ===== 工厂 =====
    print("生成工厂...")
    create_factory(-200, -200, 0, rotation_y=math.pi/4)
    create_factory(200, 200, 0, rotation_y=-math.pi/6)
    
    # ===== 瞭望塔 =====
    print("生成瞭望塔...")
    create_watchtower(100, 180, 0, rotation_y=0)
    create_watchtower(-120, -150, 0, rotation_y=math.pi/4)
    create_watchtower(200, -50, 0, rotation_y=-math.pi/3)
    
    # ===== 油罐 =====
    print("生成油罐...")
    create_oiltank(-180, 200, 0, rotation_y=math.pi/6)
    create_oiltank(220, 80, 0, rotation_y=-math.pi/4)
    create_oiltank(-100, -220, 0, rotation_y=math.pi/3)
    
    # ===== 废弃车辆 =====
    print("生成废弃车辆...")
    vehicle_positions = [
        (50, 60, 0, 0),
        (-80, 40, 0, math.pi/4),
        (120, -80, 0, -math.pi/3),
        (-60, -100, 0, math.pi/6),
        (180, 50, 0, 0),
        (-150, -80, 0, -math.pi/4),
        (0, -200, 0, math.pi/3),
        (200, -200, 0, -math.pi/5),
    ]
    for pos in vehicle_positions:
        create_wrecked_vehicle(*pos)
    
    # ===== 围栏 =====
    print("生成围栏...")
    create_fence(-150, 50, 0, length=40, rotation_y=0)
    create_fence(100, 200, 0, length=30, rotation_y=math.pi/4)
    create_fence(-200, -100, 0, length=50, rotation_y=-math.pi/6)
    create_fence(50, -180, 0, length=35, rotation_y=math.pi/3)
    
    # ===== 大型碎石堆 =====
    print("生成碎石...")
    for _ in range(20):
        rx = random.uniform(-250, 250)
        ry = random.uniform(-250, 250)
        create_rubble_pile(rx, ry, 0, size=random.uniform(3, 8))
    
    print("=" * 50)
    print("生成完成!")
    print("提示: 选中所有物体，按 Ctrl+A 应用变换")
    print("导出: File -> Export -> glTF 2.0 (.glb)")
    print("=" * 50)

# 运行
generate_ash_ravine()
