--[[
    Rivals Hub - 客户端脚本
    基于 Remote Spy 抓包分析
    UI: WindUI (移动端适配)
]]

-- ==================== 服务 & 变量 ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== 远程事件 ====================
local function safeGet(parent, ...)
    local current = parent
    for _, name in ipairs({...}) do
        current = current:WaitForChild(name, 10)
        if not current then return nil end
    end
    return current
end

local NetworkRemote = safeGet(ReplicatedStorage, "Modules", "Packages", "Network", "NetworkRemote")
local NetworkRemoteFunction = safeGet(ReplicatedStorage, "Modules", "Packages", "Network", "NetworkRemoteFunction")

-- ==================== 工具函数 ====================
local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(player)
    local char = getCharacter(player)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
    local char = getCharacter(player)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHitbox(player)
    local char = getCharacter(player)
    if not char then return nil end
    return char:FindFirstChild("HeadHitbox") or char:FindFirstChild("BodyHitbox") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    if myTeam and theirTeam then
        return myTeam ~= theirTeam
    end
    return true
end

local function getEnemies()
    local enemies = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) and getCharacter(player) and getHumanoid(player) and getHumanoid(player).Health > 0 then
            table.insert(enemies, player)
        end
    end
    return enemies
end

local function worldToScreen(pos)
    local vector, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vector.X, vector.Y), onScreen, vector.Z
end

local function notify(title, content, duration)
    if WindUI then
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
        })
    end
end

-- ==================== 配置状态 ====================
local Config = {
    -- Combat
    SilentAim = false,
    Aimbot = false,
    AimbotFOV = 150,
    AimbotSmooth = 0.5,
    HitboxExpander = false,
    HitboxSize = 15,
    KillAura = false,
    KillAuraRange = 200,
    NoRecoil = false,
    NoSpread = false,
    AutoFire = false,

    -- Visuals
    ESP = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPTeamColor = true,
    Tracers = false,
    TracerOrigin = "Bottom",
    FOVCircle = false,
    FOVRadius = 150,
    FullBright = false,
    CustomCrosshair = false,

    -- Movement
    Fly = false,
    FlySpeed = 50,
    Speed = false,
    SpeedValue = 32,
    NoClip = false,
    AutoDeploy = false,
    JumpPower = false,
    JumpValue = 100,

    -- Misc
    SpinWheelInfo = false,
    AutoRequestBoosts = false,
    RequestNuke = false,
    PingSpoof = false,
    PingValue = 0.01,
    AntiAFK = false,
    FPSUnlock = false,
    TimeRewardInfo = false,

    -- World
    GravityModifier = false,
    GravityValue = 196.2,
    FOVModifier = false,
    FOVValue = 70,
}

-- ==================== WindUI 加载 ====================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Rivals Hub",
    Folder = "rivalshub",
    Icon = "solar:cursor-square-bold",
    NewElements = true,
    OpenButton = {
        Title = "Rivals Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.6,
        Color = ColorSequence.new(
            Color3.fromHex("#FF4757"),
            Color3.fromHex("#FF6B81")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

-- ==================== 颜色 ====================
local Red = Color3.fromHex("#FF4757")
local Green = Color3.fromHex("#2ED573")
local Blue = Color3.fromHex("#1E90FF")
local Yellow = Color3.fromHex("#FFA502")
local Purple = Color3.fromHex("#A55EEA")
local Cyan = Color3.fromHex("#00D2D3")

-- ==================== 战斗标签页 ====================
local CombatTab = Window:Tab({
    Title = "战斗",
    Icon = "solar:cursor-square-bold",
    IconColor = Red,
    IconShape = "Square",
    Border = true,
})

-- 自瞄/静默瞄准
local AimbotSection = CombatTab:Section({
    Title = "自瞄系统",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

AimbotSection:Toggle({
    Title = "静默瞄准",
    Desc = "自动将子弹导向最近敌人",
    Callback = function(v)
        Config.SilentAim = v
    end,
})

AimbotSection:Space()

AimbotSection:Toggle({
    Title = "自动瞄准",
    Desc = "摄像机自动跟随敌人",
    Callback = function(v)
        Config.Aimbot = v
    end,
})

AimbotSection:Space()

AimbotSection:Slider({
    Title = "自瞄 FOV",
    Desc = "自瞄范围半径",
    Step = 1,
    Value = { Min = 10, Max = 500, Default = 150 },
    Callback = function(v)
        Config.AimbotFOV = v
    end,
})

AimbotSection:Space()

AimbotSection:Slider({
    Title = "平滑度",
    Desc = "瞄准平滑程度 (0-1)",
    Step = 0.05,
    Value = { Min = 0, Max = 1, Default = 0.5 },
    Callback = function(v)
        Config.AimbotSmooth = v
    end,
})

-- 命中盒
local HitboxSection = CombatTab:Section({
    Title = "命中盒扩展",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

HitboxSection:Toggle({
    Title = "扩展命中盒",
    Desc = "放大敌人命中盒",
    Callback = function(v)
        Config.HitboxExpander = v
        if not v then
            -- 还原
            for _, player in ipairs(Players:GetPlayers()) do
                local char = getCharacter(player)
                if char then
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.Size = part:GetAttribute("OriginalSize") or part.Size
                        end
                    end
                end
            end
        end
    end,
})

HitboxSection:Space()

HitboxSection:Slider({
    Title = "命中盒大小",
    Desc = "扩展后的尺寸",
    Step = 1,
    Value = { Min = 5, Max = 50, Default = 15 },
    Callback = function(v)
        Config.HitboxSize = v
    end,
})

-- 杀戮光环
local AuraSection = CombatTab:Section({
    Title = "杀戮光环",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

AuraSection:Toggle({
    Title = "杀戮光环",
    Desc = "自动射击范围内所有敌人",
    Callback = function(v)
        Config.KillAura = v
    end,
})

AuraSection:Space()

AuraSection:Slider({
    Title = "范围",
    Desc = "杀戮光环距离",
    Step = 1,
    Value = { Min = 10, Max = 500, Default = 200 },
    Callback = function(v)
        Config.KillAuraRange = v
    end,
})

-- 武器
local WeaponSection = CombatTab:Section({
    Title = "武器修改",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

WeaponSection:Toggle({
    Title = "无后坐力",
    Desc = "消除枪械后坐力",
    Callback = function(v)
        Config.NoRecoil = v
    end,
})

WeaponSection:Space()

WeaponSection:Toggle({
    Title = "无散射",
    Desc = "子弹精准无散射",
    Callback = function(v)
        Config.NoSpread = v
    end,
})

WeaponSection:Space()

WeaponSection:Toggle({
    Title = "自动开火",
    Desc = "按住鼠标自动连射",
    Callback = function(v)
        Config.AutoFire = v
    end,
})

-- ==================== 视觉标签页 ====================
local VisualsTab = Window:Tab({
    Title = "视觉",
    Icon = "solar:eye-bold",
    IconColor = Cyan,
    IconShape = "Square",
    Border = true,
})

local ESPSection = VisualsTab:Section({
    Title = "透视 ESP",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

ESPSection:Toggle({
    Title = "启用 ESP",
    Desc = "显示敌人信息",
    Callback = function(v)
        Config.ESP = v
    end,
})

ESPSection:Space()

ESPSection:Toggle({
    Title = "方框",
    Desc = "显示敌人边框",
    Callback = function(v)
        Config.ESPBox = v
    end,
})

ESPSection:Space()

ESPSection:Toggle({
    Title = "名字",
    Desc = "显示玩家名字",
    Callback = function(v)
        Config.ESPName = v
    end,
})

ESPSection:Space()

ESPSection:Toggle({
    Title = "血量条",
    Desc = "显示敌人血量",
    Callback = function(v)
        Config.ESPHealth = v
    end,
})

ESPSection:Space()

ESPSection:Toggle({
    Title = "距离",
    Desc = "显示与敌人距离",
    Callback = function(v)
        Config.ESPDistance = v
    end,
})

ESPSection:Space()

ESPSection:Toggle({
    Title = "队伍颜色",
    Desc = "按队伍显示颜色",
    Callback = function(v)
        Config.ESPTeamColor = v
    end,
})

local TracerSection = VisualsTab:Section({
    Title = "追踪线",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

TracerSection:Toggle({
    Title = "启用追踪线",
    Desc = "画线连接敌人",
    Callback = function(v)
        Config.Tracers = v
    end,
})

local VisualMiscSection = VisualsTab:Section({
    Title = "其他视觉",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

VisualMiscSection:Toggle({
    Title = "FOV 圆圈",
    Desc = "显示自瞄范围圈",
    Callback = function(v)
        Config.FOVCircle = v
    end,
})

VisualMiscSection:Space()

VisualMiscSection:Slider({
    Title = "FOV 半径",
    Desc = "圆圈半径大小",
    Step = 1,
    Value = { Min = 10, Max = 500, Default = 150 },
    Callback = function(v)
        Config.FOVRadius = v
    end,
})

VisualMiscSection:Space()

VisualMiscSection:Toggle({
    Title = "全亮",
    Desc = "移除地图阴影",
    Callback = function(v)
        Config.FullBright = v
        if v then
            Lighting.Brightness = 2
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        else
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
            Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        end
    end,
})

VisualMiscSection:Space()

VisualMiscSection:Toggle({
    Title = "自定义准星",
    Desc = "替换游戏准星",
    Callback = function(v)
        Config.CustomCrosshair = v
    end,
})

-- ==================== 移动标签页 ====================
local MovementTab = Window:Tab({
    Title = "移动",
    Icon = "solar:bolt-bold",
    IconColor = Yellow,
    IconShape = "Square",
    Border = true,
})

local FlySection = MovementTab:Section({
    Title = "飞行",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

FlySection:Toggle({
    Title = "启用飞行",
    Desc = "自由飞行模式",
    Callback = function(v)
        Config.Fly = v
        local char = getCharacter(LocalPlayer)
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if v then
                if root then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "FlyVelocity"
                    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bv.Velocity = Vector3.new(0, 0, 0)
                    bv.Parent = root
                    local bg = Instance.new("BodyGyro")
                    bg.Name = "FlyGyro"
                    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                    bg.P = 10000
                    bg.Parent = root
                end
                if hum then
                    hum.PlatformStand = true
                end
            else
                if root then
                    local bv = root:FindFirstChild("FlyVelocity")
                    local bg = root:FindFirstChild("FlyGyro")
                    if bv then bv:Destroy() end
                    if bg then bg:Destroy() end
                end
                if hum then
                    hum.PlatformStand = false
                end
            end
        end
    end,
})

FlySection:Space()

FlySection:Slider({
    Title = "飞行速度",
    Desc = "飞行移动速度",
    Step = 1,
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(v)
        Config.FlySpeed = v
    end,
})

local SpeedSection = MovementTab:Section({
    Title = "速度与跳跃",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

SpeedSection:Toggle({
    Title = "加速",
    Desc = "提升移动速度",
    Callback = function(v)
        Config.Speed = v
    end,
})

SpeedSection:Space()

SpeedSection:Slider({
    Title = "速度值",
    Desc = "WalkSpeed 数值",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 32 },
    Callback = function(v)
        Config.SpeedValue = v
    end,
})

SpeedSection:Space()

SpeedSection:Toggle({
    Title = "高跳",
    Desc = "提升跳跃力",
    Callback = function(v)
        Config.JumpPower = v
    end,
})

SpeedSection:Space()

SpeedSection:Slider({
    Title = "跳跃力",
    Desc = "JumpPower 数值",
    Step = 1,
    Value = { Min = 50, Max = 500, Default = 100 },
    Callback = function(v)
        Config.JumpValue = v
    end,
})

local NoclipSection = MovementTab:Section({
    Title = "穿墙",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

NoclipSection:Toggle({
    Title = "启用穿墙",
    Desc = "无视碰撞穿墙",
    Callback = function(v)
        Config.NoClip = v
    end,
})

local DeploySection = MovementTab:Section({
    Title = "部署/复活",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

DeploySection:Toggle({
    Title = "自动部署",
    Desc = "死亡后自动复活",
    Callback = function(v)
        Config.AutoDeploy = v
    end,
})

DeploySection:Space()

DeploySection:Button({
    Title = "立即部署",
    Color = Green,
    Callback = function()
        if NetworkRemoteFunction then
            local success = pcall(function()
                NetworkRemoteFunction:InvokeServer("Deploy", "Spawn@0,1.50,0")
            end)
            notify("部署", success and "已发送部署请求" or "部署失败", 3)
        end
    end,
})

DeploySection:Space()

DeploySection:Button({
    Title = "部署到随机位置",
    Color = Blue,
    Callback = function()
        if NetworkRemoteFunction then
            local x = math.random(-500, 500)
            local z = math.random(-500, 500)
            local pos = string.format("Spawn@%.2f,1.50,%.2f", x, z)
            pcall(function()
                NetworkRemoteFunction:InvokeServer("Deploy", pos)
            end)
            notify("部署", "已部署到: " .. pos, 3)
        end
    end,
})

-- ==================== 杂项标签页 ====================
local MiscTab = Window:Tab({
    Title = "杂项",
    Icon = "solar:settings-bold",
    IconColor = Purple,
    IconShape = "Square",
    Border = true,
})

-- 抽奖
local SpinSection = MiscTab:Section({
    Title = "幸运转盘",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

SpinSection:Toggle({
    Title = "自动刷新转盘状态",
    Desc = "持续获取转盘信息",
    Callback = function(v)
        Config.SpinWheelInfo = v
    end,
})

SpinSection:Space()

SpinSection:Button({
    Title = "查询转盘状态",
    Color = Purple,
    Callback = function()
        if NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestSpinWheelState")
            end)
            notify("转盘", "已请求转盘状态", 3)
        end
    end,
})

-- 增益
local BoostSection = MiscTab:Section({
    Title = "增益道具",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

BoostSection:Toggle({
    Title = "自动请求增益",
    Desc = "自动请求 Fly/X-Ray/Nuke",
    Callback = function(v)
        Config.AutoRequestBoosts = v
        if v and NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestBoostOffer", "Fly")
                NetworkRemote:FireServer("RequestBoostOffer", "X-Ray")
                NetworkRemote:FireServer("RequestBoostOffer", "Nuke")
            end)
            notify("增益", "已请求所有增益", 3)
        end
    end,
})

BoostSection:Space()

BoostSection:Button({
    Title = "请求飞行增益",
    Color = Cyan,
    Callback = function()
        if NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestBoostOffer", "Fly")
            end)
            notify("增益", "已请求 Fly", 2)
        end
    end,
})

BoostSection:Space()

BoostSection:Button({
    Title = "请求透视增益",
    Color = Blue,
    Callback = function()
        if NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestBoostOffer", "X-Ray")
            end)
            notify("增益", "已请求 X-Ray", 2)
        end
    end,
})

BoostSection:Space()

BoostSection:Button({
    Title = "请求核弹增益",
    Color = Red,
    Callback = function()
        if NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestBoostOffer", "Nuke")
                NetworkRemote:FireServer("RequestNukeOffer")
            end)
            notify("增益", "已请求 Nuke", 2)
        end
    end,
})

BoostSection:Space()

BoostSection:Toggle({
    Title = "核弹触发",
    Desc = "尝试触发核弹",
    Callback = function(v)
        Config.RequestNuke = v
        if v and NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestNukeOffer")
                NetworkRemote:FireServer("NukePurchaseFunnel", "OfferShown")
            end)
        end
    end,
})

-- 网络
local NetworkSection = MiscTab:Section({
    Title = "网络优化",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

NetworkSection:Toggle({
    Title = "延迟伪装",
    Desc = "伪装极低延迟",
    Callback = function(v)
        Config.PingSpoof = v
    end,
})

NetworkSection:Space()

NetworkSection:Slider({
    Title = "伪装延迟",
    Desc = "Ping 值 (秒)",
    Step = 0.001,
    Value = { Min = 0.001, Max = 0.1, Default = 0.01 },
    Callback = function(v)
        Config.PingValue = v
    end,
})

-- 防检测
local AntiSection = MiscTab:Section({
    Title = "防检测",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

AntiSection:Toggle({
    Title = "防挂机",
    Desc = "防止被踢出",
    Callback = function(v)
        Config.AntiAFK = v
    end,
})

AntiSection:Space()

AntiSection:Toggle({
    Title = "FPS 解锁",
    Desc = "解除帧率限制",
    Callback = function(v)
        Config.FPSUnlock = v
        if setfpscap then
            setfpscap(v and math.huge or 60)
        end
    end,
})

AntiSection:Space()

AntiSection:Toggle({
    Title = "时间奖励信息",
    Desc = "显示在线奖励",
    Callback = function(v)
        Config.TimeRewardInfo = v
    end,
})

-- ==================== 世界标签页 ====================
local WorldTab = Window:Tab({
    Title = "世界",
    Icon = "solar:planet-bold",
    IconColor = Green,
    IconShape = "Square",
    Border = true,
})

local PhysicsSection = WorldTab:Section({
    Title = "物理修改",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

PhysicsSection:Toggle({
    Title = "重力修改",
    Desc = "修改世界重力",
    Callback = function(v)
        Config.GravityModifier = v
        if v then
            Workspace.Gravity = Config.GravityValue
        else
            Workspace.Gravity = 196.2
        end
    end,
})

PhysicsSection:Space()

PhysicsSection:Slider({
    Title = "重力值",
    Desc = "Workspace.Gravity",
    Step = 1,
    Value = { Min = 0, Max = 500, Default = 50 },
    Callback = function(v)
        Config.GravityValue = v
        if Config.GravityModifier then
            Workspace.Gravity = v
        end
    end,
})

PhysicsSection:Space()

PhysicsSection:Toggle({
    Title = "FOV 修改",
    Desc = "修改摄像机视野",
    Callback = function(v)
        Config.FOVModifier = v
        if v then
            Camera.FieldOfView = Config.FOVValue
        else
            Camera.FieldOfView = 70
        end
    end,
})

PhysicsSection:Space()

PhysicsSection:Slider({
    Title = "FOV 值",
    Desc = "摄像机视野角度",
    Step = 1,
    Value = { Min = 30, Max = 120, Default = 90 },
    Callback = function(v)
        Config.FOVValue = v
        if Config.FOVModifier then
            Camera.FieldOfView = v
        end
    end,
})

local VoteSection = WorldTab:Section({
    Title = "地图投票",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

local maps = {"Ridge", "Silo", "Castle", "Jungle", "Hard"}
for _, map in ipairs(maps) do
    VoteSection:Button({
        Title = "投票: " .. map,
        Color = Blue,
        Callback = function()
            if NetworkRemote then
                pcall(function()
                    NetworkRemote:FireServer("VoteClick", map)
                end)
                notify("投票", "已投票给 " .. map, 2)
            end
        end,
    })
    VoteSection:Space()
end

local InfoSection = WorldTab:Section({
    Title = "信息",
    Box = true,
    BoxBorder = true,
    Opened = true,
})

InfoSection:Button({
    Title = "复制玩家列表",
    Color = Yellow,
    Callback = function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(names, p.Name)
        end
        if setclipboard then
            setclipboard(table.concat(names, ", "))
        end
        notify("信息", "已复制 " .. #names .. " 个玩家", 3)
    end,
})

InfoSection:Space()

InfoSection:Button({
    Title = "服务器锁定",
    Color = Red,
    Callback = function()
        if NetworkRemote then
            -- 尝试通过高频请求占用服务器
            for i = 1, 50 do
                task.spawn(function()
                    pcall(function()
                        NetworkRemote:FireServer("RequestSpinWheelState")
                    end)
                end)
            end
            notify("服务器", "已发送锁定请求", 3)
        end
    end,
})

InfoSection:Space()

InfoSection:Button({
    Title = "销毁 UI",
    Color = Red,
    Callback = function()
        Window:Destroy()
    end,
})

-- ==================== 核心功能实现 ====================

-- 获取最近的敌人（屏幕距离）
local function getClosestEnemyToCursor()
    local closest = nil
    local closestDist = Config.AimbotFOV
    local mouse = UserInputService:GetMouseLocation()

    for _, player in ipairs(getEnemies()) do
        local hitbox = getHitbox(player)
        if hitbox then
            local screenPos, onScreen = worldToScreen(hitbox.Position)
            if onScreen then
                local dist = (screenPos - mouse).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- 获取最近的敌人（世界距离）
local function getClosestEnemyWorld()
    local closest = nil
    local closestDist = Config.KillAuraRange
    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return nil end

    for _, player in ipairs(getEnemies()) do
        local root = getRootPart(player)
        if root then
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
    end
    return closest
end

-- ==================== 远程事件 Hook (静默瞄准/无散射/Ping伪装) ====================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" and self == NetworkRemote then
        local eventName = args[1]

        -- 静默瞄准
        if Config.SilentAim and eventName == "Shoot" then
            local target = getClosestEnemyToCursor()
            if target then
                local hitbox = getHitbox(target)
                local myRoot = getRootPart(LocalPlayer)
                if hitbox and myRoot then
                    local origin = myRoot.Position
                    local direction = (hitbox.Position - origin).Unit * 1000
                    args[2] = origin
                    args[3] = direction
                    args[4] = hitbox
                    args[5] = hitbox.Position
                    args[6] = tick()
                end
            end
        end

        -- 无散射
        if Config.NoSpread and eventName == "Shoot" then
            if typeof(args[3]) == "Vector3" then
                args[3] = args[3].Unit * 1000
            end
        end

        -- Ping 伪装
        if Config.PingSpoof and eventName == "PingReply" then
            args[3] = Config.PingValue
        end
    end

    return oldNamecall(self, unpack(args))
end))

-- ==================== 杀戮光环 ====================
local killAuraCooldown = 0
task.spawn(function()
    while task.wait(0.05) do
        if Config.KillAura and NetworkRemote then
            killAuraCooldown = killAuraCooldown - 0.05
            if killAuraCooldown <= 0 then
                local target = getClosestEnemyWorld()
                if target then
                    local hitbox = getHitbox(target)
                    local myRoot = getRootPart(LocalPlayer)
                    if hitbox and myRoot then
                        pcall(function()
                            NetworkRemote:FireServer("Shoot",
                                myRoot.Position,
                                (hitbox.Position - myRoot.Position).Unit * 1000,
                                hitbox,
                                hitbox.Position,
                                tick()
                            )
                        end)
                        killAuraCooldown = 0.05
                    end
                end
            end
        end
    end
end)

-- ==================== ESP 绘制 ====================
local ESPDrawings = {}
local function clearESP()
    for _, drawing in pairs(ESPDrawings) do
        for _, d in pairs(drawing) do
            if d and d.Remove then d:Remove() end
        end
    end
    ESPDrawings = {}
end

-- FOV 圆圈
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Radius = 150
fovCircle.Filled = false

task.spawn(function()
    while task.wait() do
        if Config.FOVCircle then
            local mouse = UserInputService:GetMouseLocation()
            fovCircle.Visible = true
            fovCircle.Position = mouse
            fovCircle.Radius = Config.FOVRadius
        else
            fovCircle.Visible = false
        end
    end
end)

-- ESP 主循环
task.spawn(function()
    while task.wait(0.03) do
        -- 清除旧的
        clearESP()

        if Config.ESP or Config.Tracers then
            for _, player in ipairs(getEnemies()) do
                local char = getCharacter(player)
                local hum = getHumanoid(player)
                local root = getRootPart(player)
                if not char or not hum or not root then continue end

                local head = char:FindFirstChild("Head")
                local headPos = head and head.Position or root.Position
                local rootPos = root.Position

                local screenRoot, onScreenRoot = worldToScreen(rootPos)
                local screenHead, onScreenHead = worldToScreen(headPos)

                if not onScreenRoot and not onScreenHead then continue end

                local teamColor = Config.ESPTeamColor and (player.Team and player.Team.TeamColor.Color) or Color3.fromRGB(255, 0, 0)
                local healthPercent = hum.Health / hum.MaxHealth

                local playerDrawings = {}

                -- 方框
                if Config.ESP and Config.ESPBox then
                    local top = Vector2.new(screenHead.X, screenHead.Y)
                    local bottom = Vector2.new(screenRoot.X, screenRoot.Y)
                    local height = (bottom - top).Y
                    local width = height / 2

                    local box = Drawing.new("Square")
                    box.Visible = true
                    box.Color = teamColor
                    box.Thickness = 1
                    box.Size = Vector2.new(width, height)
                    box.Position = Vector2.new(top.X - width / 2, top.Y)
                    playerDrawings.box = box

                    -- 血量条
                    if Config.ESPHealth then
                        local healthBg = Drawing.new("Square")
                        healthBg.Visible = true
                        healthBg.Color = Color3.fromRGB(0, 0, 0)
                        healthBg.Thickness = 1
                        healthBg.Size = Vector2.new(3, height)
                        healthBg.Position = Vector2.new(top.X - width / 2 - 6, top.Y)
                        playerDrawings.healthBg = healthBg

                        local health = Drawing.new("Square")
                        health.Visible = true
                        health.Color = healthPercent > 0.5 and Color3.fromRGB(0, 255, 0) or (healthPercent > 0.25 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0))
                        health.Thickness = 1
                        health.Size = Vector2.new(3, height * healthPercent)
                        health.Position = Vector2.new(top.X - width / 2 - 6, top.Y + height * (1 - healthPercent))
                        playerDrawings.health = health
                    end
                end

                -- 名字
                if Config.ESP and Config.ESPName then
                    local name = Drawing.new("Text")
                    name.Visible = true
                    name.Text = player.Name
                    name.Color = teamColor
                    name.Size = 14
                    name.Center = true
                    name.Position = Vector2.new(screenHead.X, screenHead.Y - 16)
                    playerDrawings.name = name
                end

                -- 距离
                if Config.ESP and Config.ESPDistance then
                    local myRoot = getRootPart(LocalPlayer)
                    if myRoot then
                        local dist = math.floor((rootPos - myRoot.Position).Magnitude)
                        local distText = Drawing.new("Text")
                        distText.Visible = true
                        distText.Text = dist .. " studs"
                        distText.Color = Color3.fromRGB(255, 255, 255)
                        distText.Size = 12
                        distText.Center = true
                        distText.Position = Vector2.new(screenRoot.X, screenRoot.Y + 4)
                        playerDrawings.distance = distText
                    end
                end

                -- 追踪线
                if Config.Tracers then
                    local tracer = Drawing.new("Line")
                    tracer.Visible = true
                    tracer.Color = teamColor
                    tracer.Thickness = 1
                    tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    tracer.To = screenRoot
                    playerDrawings.tracer = tracer
                end

                ESPDrawings[player.Name] = playerDrawings
            end
        end
    end
end)

-- ==================== 命中盒扩展 ====================
task.spawn(function()
    while task.wait(0.1) do
        if Config.HitboxExpander then
            for _, player in ipairs(getEnemies()) do
                local char = getCharacter(player)
                if char then
                    for _, part in ipairs(char:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            if not part:GetAttribute("OriginalSize") then
                                part:SetAttribute("OriginalSize", part.Size)
                            end
                            part.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                        end
                    end
                end
            end
        end
    end
end)

-- ==================== 速度/跳跃 ====================
task.spawn(function()
    while task.wait(0.1) do
        local hum = getHumanoid(LocalPlayer)
        if hum then
            if Config.Speed then
                hum.WalkSpeed = Config.SpeedValue
            end
            if Config.JumpPower then
                hum.UseJumpPower = true
                hum.JumpPower = Config.JumpValue
            end
        end
    end
end)

-- ==================== 飞行 ====================
task.spawn(function()
    while task.wait() do
        if Config.Fly then
            local char = getCharacter(LocalPlayer)
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local bv = root and root:FindFirstChild("FlyVelocity")
                local bg = root and root:FindFirstChild("FlyGyro")
                if bv and bg then
                    local camCF = Camera.CFrame
                    local moveDir = Vector3.new(0, 0, 0)
                    local keys = UserInputService:GetKeysPressed()
                    for _, key in ipairs(keys) do
                        if key.KeyCode == Enum.KeyCode.W then
                            moveDir = moveDir + camCF.LookVector
                        elseif key.KeyCode == Enum.KeyCode.S then
                            moveDir = moveDir - camCF.LookVector
                        elseif key.KeyCode == Enum.KeyCode.A then
                            moveDir = moveDir - camCF.RightVector
                        elseif key.KeyCode == Enum.KeyCode.D then
                            moveDir = moveDir + camCF.RightVector
                        elseif key.KeyCode == Enum.KeyCode.Space then
                            moveDir = moveDir + Vector3.new(0, 1, 0)
                        elseif key.KeyCode == Enum.KeyCode.LeftControl then
                            moveDir = moveDir - Vector3.new(0, 1, 0)
                        end
                    end
                    if moveDir.Magnitude > 0 then
                        moveDir = moveDir.Unit * Config.FlySpeed
                    end
                    bv.Velocity = moveDir
                    bg.CFrame = camCF
                end
            end
        end
    end
end)

-- ==================== 穿墙 ====================
task.spawn(function()
    while task.wait() do
        if Config.NoClip then
            local char = getCharacter(LocalPlayer)
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end)

-- ==================== 自动瞄准 ====================
task.spawn(function()
    while task.wait() do
        if Config.Aimbot then
            local target = getClosestEnemyToCursor()
            if target then
                local hitbox = getHitbox(target)
                if hitbox then
                    local targetPos = hitbox.Position
                    local camCF = Camera.CFrame
                    local newCF = CFrame.new(camCF.Position, targetPos)
                    local smooth = Config.AimbotSmooth
                    Camera.CFrame = camCF:Lerp(newCF, 1 - smooth)
                end
            end
        end
    end
end)

-- ==================== 自动部署 ====================
task.spawn(function()
    while task.wait(1) do
        if Config.AutoDeploy and NetworkRemoteFunction then
            local hum = getHumanoid(LocalPlayer)
            if hum and hum.Health <= 0 then
                pcall(function()
                    NetworkRemoteFunction:InvokeServer("Deploy", "Spawn@0,1.50,0")
                end)
            end
        end
    end
end)

-- ==================== 转盘状态监听 ====================
local spinState = nil
if NetworkRemote then
    NetworkRemote.OnClientEvent:Connect(function(name, data)
        if name == "SpinWheelState" then
            spinState = data
            if Config.SpinWheelInfo then
                notify("转盘", string.format(
                    "普通抽奖: %d | 黄金抽奖: %d\n免费冷却: %ds",
                    data.Spins or 0,
                    data.GoldenSpins or 0,
                    data.FreeSpinCooldown or 0
                ), 5)
            end
        elseif name == "UpdateTimeRewards" then
            if Config.TimeRewardInfo then
                notify("时间奖励", string.format(
                    "在线时间: %ds | 当前奖励: %d",
                    data.TimeSpent or 0,
                    data.CurrentTimeReward or 0
                ), 5)
            end
        elseif name == "BoostOfferReady" then
            notify("增益就绪", tostring(data) .. " 已就绪", 3)
        end
    end)
end

-- ==================== 自动请求增益 ====================
task.spawn(function()
    while task.wait(30) do
        if Config.AutoRequestBoosts and NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestBoostOffer", "Fly")
                NetworkRemote:FireServer("RequestBoostOffer", "X-Ray")
                NetworkRemote:FireServer("RequestBoostOffer", "Nuke")
            end)
        end
        if Config.SpinWheelInfo and NetworkRemote then
            pcall(function()
                NetworkRemote:FireServer("RequestSpinWheelState")
            end)
        end
    end
end)

-- ==================== 防挂机 ====================
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

task.spawn(function()
    while task.wait(120) do
        if Config.AntiAFK then
            pcall(function()
                firetouchinterest(getRootPart(LocalPlayer), getRootPart(LocalPlayer), 0)
                firetouchinterest(getRootPart(LocalPlayer), getRootPart(LocalPlayer), 1)
            end)
        end
    end
end)

-- ==================== 准星 ====================
local crosshairLines = {}
for i = 1, 4 do
    crosshairLines[i] = Drawing.new("Line")
    crosshairLines[i].Visible = false
    crosshairLines[i].Color = Color3.fromRGB(0, 255, 0)
    crosshairLines[i].Thickness = 1
end

task.spawn(function()
    while task.wait() do
        local visible = Config.CustomCrosshair
        for _, line in ipairs(crosshairLines) do
            line.Visible = visible
        end
        if visible then
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local size = 6
            crosshairLines[1].From = center + Vector2.new(-size, 0)
            crosshairLines[1].To = center + Vector2.new(-2, 0)
            crosshairLines[2].From = center + Vector2.new(2, 0)
            crosshairLines[2].To = center + Vector2.new(size, 0)
            crosshairLines[3].From = center + Vector2.new(0, -size)
            crosshairLines[3].To = center + Vector2.new(0, -2)
            crosshairLines[4].From = center + Vector2.new(0, 2)
            crosshairLines[4].To = center + Vector2.new(0, size)
        end
    end
end)

-- ==================== 自动开火 ====================
task.spawn(function()
    while task.wait(0.01) do
        if Config.AutoFire and NetworkRemote then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                local target = getClosestEnemyToCursor()
                if target then
                    local hitbox = getHitbox(target)
                    local myRoot = getRootPart(LocalPlayer)
                    if hitbox and myRoot then
                        pcall(function()
                            NetworkRemote:FireServer("Shoot",
                                myRoot.Position,
                                (hitbox.Position - myRoot.Position).Unit * 1000,
                                hitbox,
                                hitbox.Position,
                                tick()
                            )
                        end)
                    end
                end
            end
        end
    end
end)

-- ==================== 角色重生重置 ====================
LocalPlayer.CharacterAdded:Connect(function(char)
    -- 重新应用设置
    task.wait(1)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Config.Speed then hum.WalkSpeed = Config.SpeedValue end
        if Config.JumpPower then
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpValue
        end
    end
    if Config.Fly then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "FlyVelocity"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = root
            local bg = Instance.new("BodyGyro")
            bg.Name = "FlyGyro"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.Parent = root
        end
    end
end)

-- ==================== 通知 ====================
notify("Rivals Hub", "脚本已加载！", 3)

-- 清理函数
local function cleanup()
    clearESP()
    if fovCircle then fovCircle:Remove() end
    for _, line in ipairs(crosshairLines) do
        if line then line:Remove() end
    end
end

-- UI 关闭时清理
local originalDestroy = Window.Destroy
function Window:Destroy()
    cleanup()
    return originalDestroy(self)
end
