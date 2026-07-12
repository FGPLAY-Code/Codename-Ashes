using Godot;
using System;

#nullable disable

/// <summary>
/// 枪械散射控制器 — 纯数学函数。
/// 根据玩家姿态（站立/蹲下/开镜/移动）和连续射击 bloom 计算散射方向。
/// </summary>
public partial class SpreadController : Node
{
    // ===== 导出参数（Inspector 可调） =====
    [Export] public float StandSpreadDeg { get; set; } = 3.0f;
    [Export] public float CrouchSpreadMult { get; set; } = 0.05f;
    [Export] public float AdsSpreadMult { get; set; } = 0.35f;
    [Export] public float MoveSpreadMult { get; set; } = 1.6f;
    [Export] public float VertMult { get; set; } = 0.8f;

    /// <summary>
    /// 计算当前总散射角度（度），包含姿态修正 + bloom 叠加。
    /// </summary>
    public float GetSpreadDeg(bool crouching, bool ads, bool moving, float bloomDeg)
    {
        float deg = StandSpreadDeg;
        if (crouching)  deg *= CrouchSpreadMult;
        if (ads)        deg *= AdsSpreadMult;
        if (moving)     deg *= MoveSpreadMult;
        deg += bloomDeg;
        return deg;
    }

    /// <summary>
    /// 在 forward 方向周围随机采样一个带散射的方向向量。
    /// 使用圆形椭圆采样（极坐标），射击散布更自然。
    /// </summary>
    public Vector3 GetSpreadDirection(Vector3 forward, bool crouching, bool ads, bool moving, float bloomDeg)
    {
        float s = Mathf.DegToRad(GetSpreadDeg(crouching, ads, moving, bloomDeg));
        if (s <= 0f) return forward;

        // 圆形椭圆采样：半径平方根使散布内密外疏
        float r = Mathf.Sqrt((float)GD.Randf());
        float a = (float)GD.Randf() * Mathf.Tau;
        float offY = Mathf.Sin(a) * s * r;
        float offX = Mathf.Cos(a) * s * r * VertMult;

        // 构建局部坐标系：right × up
        Vector3 right = forward.Cross(Vector3.Up).Normalized();
        Vector3 up = right.Cross(forward).Normalized();

        return (forward + right * offX + up * offY).Normalized();
    }
}
