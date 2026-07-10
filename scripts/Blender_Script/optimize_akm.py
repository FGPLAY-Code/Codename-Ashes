"""
AKM 模型优化脚本 - 绿洲行动
使用方法：Blender → Scripting 工作区 → 新建文本 → 粘入运行
"""

import bpy
import math

# ============ 配置 ============
TARGET_FACES = 15000  # 目标面数（枪械模型 1.5 万面足够精细）
EXPORT_PATH = r"E:\Godot\绿洲行动 demo\绿洲行动-demo\models\AKM_Optimized.glb"
# ==============================

def main():
    # 1. 找到 Tripo 模型
    tripo_name = None
    for obj in bpy.data.objects:
        if obj.name.startswith("tripo_node"):
            tripo_name = obj.name
            break

    if not tripo_name:
        print("❌ 未找到 Tripo 模型！请确保已导入模型。")
        return

    obj = bpy.data.objects[tripo_name]
    original_faces = len(obj.data.polygons)
    print(f"✅ 找到模型: {tripo_name} ({original_faces} 面)")

    # 2. 选中并设为活跃
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # 3. 应用变换（重置位置/旋转/缩放）
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    print("✅ 已应用旋转变换")

    # 4. 分离松散部件（枪管、弹匣等独立 parts）
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='LOOSE')
    bpy.ops.object.mode_set(mode='OBJECT')
    parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    print(f"✅ 分离出 {len(parts)} 个部件:")
    for p in parts:
        print(f"   {p.name}: {len(p.data.polygons)} 面")

    # 5. 对每个部件分别减面（保留细节）
    total_before = 0
    total_after = 0

    for part in parts:
        faces = len(part.data.polygons)
        if faces <= 100:
            continue  # 跳过微小碎片

        total_before += faces
        ratio = TARGET_FACES / original_faces
        target = max(faces * ratio * 3, 500)  # 按比例缩放，最少 500 面

        bpy.context.view_layer.objects.active = part
        bpy.ops.object.modifier_add(type='DECIMATE')
        dec = part.modifiers[-1]
        dec.ratio = target / faces
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dec.name)

        new_faces = len(part.data.polygons)
        total_after += new_faces
        print(f"   {part.name}: {faces} → {new_faces} 面")

    print(f"\n📊 减面统计: {total_before} → {total_after} 面 (减少 {100*(1-total_after/total_before):.1f}%)")

    # 6. 重命名主部件（方便 Godot 引用）
    main_part = parts[0]
    main_part.name = "AKM_Main"

    # 7. 清空未使用的材质/数据（减小文件）
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:
        part.select_set(True)
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = "AKM_Model"

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.tris_convert_to_quads()
    bpy.ops.object.mode_set(mode='OBJECT')

    print(f"✅ 合并完成: {len(joined.data.polygons)} 面")

    # 8. 导出 GLB (Blender 4.x 参数)
    bpy.ops.export_scene.gltf(
        filepath=EXPORT_PATH,
        export_format='GLB',
        export_materials='EXPORT'
    )
    print(f"✅ 已导出: {EXPORT_PATH}")

if __name__ == "__main__":
    main()
