using System.Collections.Generic;
using System.Linq;

/// <summary>
/// 背包库存纯数据模型 — 不继承 Godot 类型，无需源码生成器。
/// inventory.gd 在运行时实例化此类并委托数据操作。
/// </summary>
public class InventoryModel
{
    // ===== 数据定义 =====
    public class SlotData
    {
        public int Id;
        public string Name = "";
        public string Icon = "";
        public int Count;
        public string Description = "";
        public bool IsAmmo;
        public string Quality = "";   // green / blue / purple / ""

        public bool IsEmpty => string.IsNullOrEmpty(Name);

        public SlotData Clone() => new()
        {
            Id = Id, Name = Name, Icon = Icon,
            Count = Count, Description = Description,
            IsAmmo = IsAmmo, Quality = Quality
        };
    }

    public const int SlotCount = 28;

    public List<SlotData> Slots { get; private set; }
    public SlotData ArmorSlot { get; set; }

    // ===== 构造 =====
    public InventoryModel()
    {
        Slots = new List<SlotData>(SlotCount);
        for (int i = 0; i < SlotCount; i++)
        {
            Slots.Add(new SlotData { Id = i });
        }
        ArmorSlot = new SlotData
        {
            Name = "防弹衣",
            Icon = "armor",
            Count = 1,
            Description = "增加 50 点护甲"
        };
    }

    // ===== 基础操作 =====

    /// <summary>添加物品，同类叠加。返回 true 表示成功。</summary>
    public bool AddItem(string name, string icon, int count, string desc, bool isAmmo = false, string quality = "")
    {
        if (isAmmo)
        {
            // 弹药：直接找空格子
            foreach (var slot in Slots)
            {
                if (slot.IsEmpty)
                {
                    FillSlot(slot, name, icon, count, desc, true, quality);
                    return true;
                }
            }
            return false;
        }

        // 非弹药：先找同类叠加
        foreach (var slot in Slots)
        {
            if (slot.Name == name)
            {
                slot.Count += count;
                return true;
            }
        }
        // 没找到同类，找空格子
        foreach (var slot in Slots)
        {
            if (slot.IsEmpty)
            {
                FillSlot(slot, name, icon, count, desc, false, quality);
                return true;
            }
        }
        return false;
    }

    /// <summary>移动/交换格子</summary>
    public void MoveSlot(int from, int to)
    {
        if (from == to) return;
        var dest = Slots[to];
        if (dest.IsEmpty)
        {
            Slots[to] = Slots[from].Clone();
            Slots[to].Id = to;
            ClearSlot(from);
        }
        else if (dest.Name == Slots[from].Name && dest.Icon == Slots[from].Icon)
        {
            // 同类叠加
            dest.Count += Slots[from].Count;
            ClearSlot(from);
        }
        else
        {
            // 交换
            (Slots[to], Slots[from]) = (Slots[from].Clone(), Slots[to].Clone());
            Slots[to].Id = to;
            Slots[from].Id = from;
        }
    }

    /// <summary>获取空格数量</summary>
    public int EmptySlotCount => Slots.Count(s => s.IsEmpty);

    /// <summary>获取弹药格数量</summary>
    public int GetAmmoCount()
    {
        var ammo = Slots.FirstOrDefault(s => s.IsAmmo && !string.IsNullOrEmpty(s.Name));
        return ammo?.Count ?? 0;
    }

    // ===== 内部 =====
    private static void FillSlot(SlotData slot, string name, string icon, int count, string desc, bool isAmmo, string quality)
    {
        slot.Name = name;
        slot.Icon = icon;
        slot.Count = count;
        slot.Description = desc;
        slot.IsAmmo = isAmmo;
        slot.Quality = quality;
    }

    private void ClearSlot(int index)
    {
        var s = Slots[index];
        s.Name = ""; s.Icon = ""; s.Count = 0;
        s.Description = ""; s.IsAmmo = false; s.Quality = "";
    }
}
