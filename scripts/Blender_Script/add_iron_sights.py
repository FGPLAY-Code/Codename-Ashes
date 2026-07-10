"""
AKM 机瞄添加脚本 - 绿洲行动
使用方法：Blender → Scripting → 粘入运行
"""

import bpy
import math

# ============ 配置 ============
EXPORT_PATH = r"E:\Godot\绿洲行动 demo\绿洲行动-demo\models\AKM_WithSights.glb"
# ==============================

def add_front_sight(parent_name="AKM_Model"):
    """准星 - 枪口端的小垂直叶片"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.85, 0.085))
    fs = bpy.context.active_object
    fs.name = "FrontSight"
    fs.scale = (0.012, 0.012, 0.055)
    bpy.ops.object.transform_apply(scale=True)

    # 给准星加材质槽（枪械金属色）
    mat = bpy.data.materials.new(name="Metal_Black")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)  # 深黑
    bsdf.inputs["Metallic"].default_value = 0.9
    bsdf.inputs["Roughness"].default_value = 0.4
    fs.data.materials.append(mat)

    # 父子链接
    parent = bpy.data.objects.get(parent_name)
    if parent:
        fs.parent = parent
    return fs


def add_rear_sight(parent_name="AKM_Model"):
    """照门 - 机匣后端的缺口框"""
    # 照门底座
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.3, 0.075))
    rs_base = bpy.context.active_object
    rs_base.name = "RearSight_Base"
    rs_base.scale = (0.05, 0.02, 0.015)
    bpy.ops.object.transform_apply(scale=True)

    # 照门框架（左右两臂 + 横梁，围出缺口）
    def add_sight_part(loc, scale, name):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        p = bpy.context.active_object
        p.name = name
        p.scale = scale
        bpy.ops.object.transform_apply(scale=True)
        return p

    left_arm = add_sight_part((-0.025, -0.3, 0.095), (0.008, 0.018, 0.03), "RearSight_Left")
    right_arm = add_sight_part((0.025, -0.3, 0.095), (0.008, 0.018, 0.03), "RearSight_Right")
    top_bar = add_sight_part((0, -0.3, 0.115), (0.04, 0.018, 0.008), "RearSight_Top")

    # 合并为一个对象
    bpy.ops.object.select_all(action='DESELECT')
    rs_base.select_set(True)
    left_arm.select_set(True)
    right_arm.select_set(True)
    top_bar.select_set(True)
    bpy.context.view_layer.objects.active = rs_base
    bpy.ops.object.join()
    rear_sight = bpy.context.active_object
    rear_sight.name = "RearSight"

    # 材质
    mat = bpy.data.materials.new(name="Metal_Black")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    bsdf.inputs["Metallic"].default_value = 0.9
    bsdf.inputs["Roughness"].default_value = 0.4
    rear_sight.data.materials.append(mat)

    # 父子链接
    parent = bpy.data.objects.get(parent_name)
    if parent:
        rear_sight.parent = parent
    return rear_sight


def export_glb(path):
    """导出 GLB"""
    obj = bpy.data.objects.get("AKM_Model")
    if obj:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        export_materials='EXPORT'
    )
    print(f"✅ 已导出: {path}")


def main():
    # 找到主模型
    parent_name = None
    for name in ["AKM_Model", "AKM_Main"]:
        if bpy.data.objects.get(name):
            parent_name = name
            break

    if not parent_name:
        print("❌ 未找到 AKM_Model！请先运行减面脚本。")
        return

    print(f"✅ 找到: {parent_name}")
    add_front_sight(parent_name)
    print("✅ 准星已添加")
    add_rear_sight(parent_name)
    print("✅ 照门已添加")
    export_glb(EXPORT_PATH)


if __name__ == "__main__":
    main()
