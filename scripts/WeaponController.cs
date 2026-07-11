using Godot;
using System;

#nullable disable

/// <summary>
/// 枪械控制器 — Hitscan 射击、弹药管理、换弹、后坐力、枪口闪光、散射集成。
/// GDScript 端通过下列信号和公开方法桥接调用。
/// 
/// 信号：
///   ammo_changed(int current, int max, int reserve)
///   fire_mode_changed(string mode)   — "AUTO" / "SEMI"
///   reload_state_changed(bool reloading)
///   shot_fired(float headshotMultiplier)
/// 
/// 公开方法：
///   tick_fire(triggerHeld, crouching, ads, moving)
///   start_reload()
///   toggle_fire_mode()
///   get_fire_mode() -> string
///   get_ammo_status() -> string      — "30 / 90"
///   get_reserve_ammo() -> int
///   add_reserve_ammo(int)
///   set_reserve_ammo(int)
/// </summary>
public partial class WeaponController : Node
{
    // ===== 导出属性 =====
    [Export] public int MagazineCapacity { get; set; } = 30;
    [Export] public int ReserveAmmoStart { get; set; } = 90;
    [Export] public float FireRateAuto { get; set; } = 0.08f;
    [Export] public float FireRateSemi { get; set; } = 0.15f;
    [Export] public float BaseDamage { get; set; } = 25f;
    [Export] public float RecoilKick { get; set; } = 0.03f;
    [Export] public float BloomPerShot { get; set; } = 0.15f;
    [Export] public float BloomRecovery { get; set; } = 0.6f;
    [Export] public float HeadBottomOffset { get; set; } = 4.0f;
    [Export] public float HeadTopOffset { get; set; } = 4.5f;
    [Export] public string GunSoundPath { get; set; } = "res://resources/mp3/ak_gunshot.mp3";

    // ===== 信号 =====
    [Signal] public delegate void AmmoChangedEventHandler(int current, int max, int reserve);
    [Signal] public delegate void FireModeChangedEventHandler(string mode);
    [Signal] public delegate void ReloadStateChangedEventHandler(bool reloading);
    [Signal] public delegate void ShotFiredEventHandler(float headshotMultiplier);

    // ===== 运行时状态 =====
    private int _ammo;
    private int _reserveAmmo;
    private bool _isReloading = false;
    private float _fireCooldown = 0f;
    private string _fireMode = "AUTO";
    private float _bloom = 0f;
    private bool _prevTrigger = false;

    // ===== 懒加载节点引用 =====
    private RayCast3D _ray;
    private Node3D _cameraPivot;
    private Node3D _gunMuzzle;
    private Node3D _weaponModel;
    private SpreadController _spread;
    private AudioStreamPlayer _gunAudio;

    // ===================================================================
    // 生命周期
    // ===================================================================

    public override void _Ready()
    {
        _ammo = MagazineCapacity;
        _reserveAmmo = ReserveAmmoStart;
        _fireMode = "AUTO";
        _fireCooldown = 0f;

        ResolveRefs();
        SetupGunSound();

        EmitSignal(SignalName.AmmoChanged, _ammo, MagazineCapacity, _reserveAmmo);
        EmitSignal(SignalName.FireModeChanged, _fireMode);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_fireCooldown > 0f)
            _fireCooldown -= (float)delta;
        if (_bloom > 0f)
            _bloom = Mathf.Max(0f, _bloom - BloomRecovery * (float)delta);
    }

    // ===================================================================
    // 引用解析
    // ===================================================================

    private void ResolveRefs()
    {
        if (_spread == null)
            _spread = GetNode<SpreadController>("../SpreadController");
        if (_ray == null)
            _ray = GetNode<RayCast3D>("../CameraPivot/Camera3D/RayCast3D");
        if (_cameraPivot == null)
            _cameraPivot = GetNode<Node3D>("../CameraPivot");
        if (_gunMuzzle == null)
            _gunMuzzle = GetNode<Node3D>("../CameraPivot/Camera3D/GunMuzzle");

        // 射线排除父级碰撞体（Player → CharacterBody3D → CollisionObject3D）
        if (_ray != null)
        {
            CollisionObject3D colParent = GetParent<CollisionObject3D>();
            if (colParent != null)
                _ray.AddException(colParent);
        }
    }

    // ===================================================================
    // 射击驱动（由 player.gd 每帧调用）
    // ===================================================================

    public void TickFire(bool triggerHeld, bool crouching, bool ads, bool moving)
    {
        ResolveRefs();
        if (_ray == null) return;
        if (_isReloading) { _prevTrigger = triggerHeld; return; }

        bool wantShoot = false;
        if (_fireMode == "SEMI")
        {
            // 半自动：仅按下瞬间（边沿触发）
            if (triggerHeld && !_prevTrigger)
                wantShoot = true;
        }
        else
        {
            // 全自动：按住连发
            if (triggerHeld)
                wantShoot = true;
        }
        _prevTrigger = triggerHeld;

        if (wantShoot && _ammo > 0 && _fireCooldown <= 0f)
            DoShoot(crouching, ads, moving);
    }

    // ===================================================================
    // 换弹
    // ===================================================================

    public void StartReload()
    {
        if (_isReloading || _ammo == MagazineCapacity || _reserveAmmo <= 0)
            return;
        _isReloading = true;
        EmitSignal(SignalName.ReloadStateChanged, true);

        // 异步等待换弹时长
        ReloadAsync();
    }

    private async void ReloadAsync()
    {
        await ToSignal(GetTree().CreateTimer(1.5), SceneTreeTimer.SignalName.Timeout);
        if (_isReloading)
        {
            int needed = MagazineCapacity - _ammo;
            int toReload = Math.Min(needed, _reserveAmmo);
            _ammo += toReload;
            _reserveAmmo -= toReload;
            EmitSignal(SignalName.AmmoChanged, _ammo, MagazineCapacity, _reserveAmmo);
        }
        _isReloading = false;
        EmitSignal(SignalName.ReloadStateChanged, false);
    }

    // ===================================================================
    // 射击模式切换
    // ===================================================================

    public void ToggleFireMode()
    {
        if (_isReloading) return;
        if (_fireMode == "AUTO")
        {
            _fireMode = "SEMI";
            _fireCooldown = FireRateSemi;
        }
        else
        {
            _fireMode = "AUTO";
            _fireCooldown = FireRateAuto;
        }
        EmitSignal(SignalName.FireModeChanged, _fireMode);
    }

    // ===================================================================
    // 公开查询方法
    // ===================================================================

    public string GetFireMode() => _fireMode;
    public int GetReserveAmmo() => _reserveAmmo;

    public void AddReserveAmmo(int amount)
    {
        _reserveAmmo += amount;
        EmitSignal(SignalName.AmmoChanged, _ammo, MagazineCapacity, _reserveAmmo);
    }

    public void SetReserveAmmo(int amount)
    {
        _reserveAmmo = amount;
        EmitSignal(SignalName.AmmoChanged, _ammo, MagazineCapacity, _reserveAmmo);
    }

    /// <summary>
    /// 返回 "30 / 90" 格式字符串供 HUD 显示。
    /// </summary>
    public string GetAmmoStatus() => _ammo.ToString() + " / " + _reserveAmmo.ToString();

    // ===================================================================
    // 射击核心
    // ===================================================================

    private void DoShoot(bool crouching, bool ads, bool moving)
    {
        _ammo -= 1;
        _fireCooldown = (_fireMode == "SEMI") ? FireRateSemi : FireRateAuto;

        ApplyRecoil(crouching, ads);
        ShowMuzzleFlash();
        PlayGunSound();
        _bloom = Mathf.Min(_bloom + BloomPerShot, 10.0f);

        // 1. 计算带散射的射线方向
        Vector3 forward = -_ray.GlobalTransform.Basis.Z;
        Vector3 dir = (_spread != null)
            ? _spread.GetSpreadDirection(forward, crouching, ads, moving, _bloom)
            : forward;

        // 2. 旋转射线并强制更新
        _ray.Rotation = Vector3.Zero;
        _ray.LookAt(_ray.GlobalPosition + dir);
        _ray.ForceRaycastUpdate();

        // 3. 碰撞检测
        if (_ray.IsColliding())
        {
            GodotObject collider = _ray.GetCollider();
            if (collider != null && GodotObject.IsInstanceValid(collider))
            {
                Vector3 hitPoint = _ray.GetCollisionPoint();
                SpawnImpactEffect(hitPoint, _ray.GetCollisionNormal());

                // 向上找拥有 take_damage 方法的节点
                Node target = collider as Node;
                while (target != null && !target.HasMethod("take_damage"))
                    target = target.GetParent();

                if (target != null && GodotObject.IsInstanceValid(target))
                {
                    float finalDamage = BaseDamage;

                    // 爆头检测（通过坐标 Y 轴判定）
                    if (target is CharacterBody3D enemy)
                    {
                        float capBottom = enemy.GlobalPosition.Y;
                        float headBottom = capBottom + HeadBottomOffset;
                        float headTop = capBottom + HeadTopOffset;
                        if (hitPoint.Y > headBottom && hitPoint.Y < headTop)
                        {
                            float mult = crouching ? 2.0f : 1.75f;
                            finalDamage = BaseDamage * mult;
                            EmitSignal(SignalName.ShotFired, mult);
                        }
                    }

                    target.Call("take_damage", finalDamage);
                }
            }
        }

        // 4. 射线归零（不影响下一次检测起点）
        _ray.Rotation = Vector3.Zero;

        EmitSignal(SignalName.AmmoChanged, _ammo, MagazineCapacity, _reserveAmmo);

        // 5. 弹药耗尽 → 自动换弹
        if (_ammo <= 0 && _reserveAmmo > 0)
            StartReload();
    }

    // ===================================================================
    // 后坐力
    // ===================================================================

    private void ApplyRecoil(bool crouching, bool ads)
    {
        float mult = crouching ? 0.5f : 1.0f;
        if (ads) mult *= 0.7f;
        float kick = RecoilKick * mult;

        // 视角上跳（CameraPivot 绕 X 轴旋转）
        if (_cameraPivot != null)
            _cameraPivot.RotateX(kick);

        // 枪械模型位置抖动 + 复位
        if (_weaponModel == null)
            _weaponModel = GetNode<Node3D>("../CameraPivot/WeaponPivot/AKM_Model");
        if (_weaponModel != null)
        {
            Vector3 recoilOffset = new Vector3(
                (float)GD.Randf() * 0.01f - 0.005f,
                kick * 0.3f,
                kick * 0.5f
            );
            Tween tween = CreateTween();
            tween.TweenProperty(_weaponModel, "position",
                _weaponModel.Position + recoilOffset, 0.02f);
            tween.TweenProperty(_weaponModel, "position",
                _weaponModel.Position, 0.06f);
        }
    }

    // ===================================================================
    // 枪口闪光
    // ===================================================================

    private async void ShowMuzzleFlash()
    {
        if (_gunMuzzle == null) return;

        MeshInstance3D flash = new MeshInstance3D();
        BoxMesh box = new BoxMesh();
        box.Size = new Vector3(0.08f, 0.08f, 0.15f);
        flash.Mesh = box;

        StandardMaterial3D mat = new StandardMaterial3D();
        mat.AlbedoColor = new Color(1f, 0.8f, 0.3f);
        mat.EmissionEnabled = true;
        mat.Emission = new Color(1f, 0.6f, 0.1f);
        mat.EmissionEnergyMultiplier = 4.0f;
        flash.MaterialOverride = mat;

        flash.Position = _gunMuzzle.Position;
        if (_cameraPivot != null)
            _cameraPivot.AddChild(flash);
        else
            AddChild(flash);

        await ToSignal(GetTree().CreateTimer(0.05f), SceneTreeTimer.SignalName.Timeout);
        if (GodotObject.IsInstanceValid(flash))
            flash.QueueFree();
    }

    // ===================================================================
    // 弹着点特效
    // ===================================================================

    private async void SpawnImpactEffect(Vector3 pos, Vector3 normal)
    {
        MeshInstance3D spark = new MeshInstance3D();
        SphereMesh sphere = new SphereMesh();
        sphere.Radius = 0.02f;
        sphere.Height = 0.04f;
        spark.Mesh = sphere;

        StandardMaterial3D m = new StandardMaterial3D();
        m.AlbedoColor = new Color(0.8f, 0.6f, 0.4f);
        m.EmissionEnabled = true;
        m.Emission = new Color(1f, 0.6f, 0.2f);
        m.EmissionEnergyMultiplier = 1.5f;
        spark.MaterialOverride = m;

        spark.Position = pos + normal * 0.02f;
        GetTree().Root.AddChild(spark);

        await ToSignal(GetTree().CreateTimer(0.2f), SceneTreeTimer.SignalName.Timeout);
        if (GodotObject.IsInstanceValid(spark))
            spark.QueueFree();
    }

    // ===================================================================
    // 枪声
    // ===================================================================

    private void SetupGunSound()
    {
        _gunAudio = new AudioStreamPlayer();
        _gunAudio.Name = "GunAudio";
        AudioStream sound = GD.Load<AudioStream>(GunSoundPath);
        if (sound != null)
        {
            _gunAudio.Stream = sound;
            _gunAudio.VolumeDb = 0f;
            _gunAudio.Bus = "Master";
            if (_cameraPivot != null)
                _cameraPivot.AddChild(_gunAudio);
            else
                AddChild(_gunAudio);
        }
        else
        {
            GD.PushError("无法加载枪声音频: " + GunSoundPath);
        }
    }

    private void PlayGunSound()
    {
        if (_gunAudio != null && _gunAudio.Stream != null)
            _gunAudio.Play();
    }
}
