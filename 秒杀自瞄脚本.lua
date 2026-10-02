--============================================================
-- 客户端脚本 基于 Remote Spy 抓包制作 (NetworkRemote)
-- 功能: 自瞄秒杀 / 击杀光环 / 飞行 / 加速 / 自动增益 / ESP
-- UI: WindUI
--============================================================

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

--// 服务
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// 抓包得到的远程
local Network = game:GetService("ReplicatedStorage").Modules.Packages.Network.NetworkRemote

--// 全局配置
local Config = {
    AimbotEnabled = false,
    AimbotFOV = 300,
    AimPart = "BodyHitbox",   -- BodyHitbox / HeadHitbox
    FireRate = 0.05,
    KillAura = false,
    KillAuraRange = 200,
    Fly = false,
    FlySpeed = 60,
    SpeedEnabled = false,
    Speed = 16,
    ESP = false,
}

--============================================================
-- 工具函数
--============================================================

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRoot()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHitbox(model, part)
    return model:FindFirstChild(part) or model:FindFirstChild("BodyHitbox") or model:FindFirstChild("HumanoidRootPart")
end

-- 获取所有敌人角色模型(workspace下的玩家模型)
local function GetEnemies()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local model = Workspace:FindFirstChild(plr.Name)
            if model and GetHitbox(model, Config.AimPart) then
                table.insert(list, {Player = plr, Model = model})
            end
        end
    end
    return list
end

-- 屏幕视野内最近的敌人
local function GetClosestEnemy()
    local best, bestDist = nil, Config.AimbotFOV
    for _, e in ipairs(GetEnemies()) do
        local hitbox = GetHitbox(e.Model, Config.AimPart)
        local pos, onScreen = Camera:WorldToViewportPoint(hitbox.Position)
        if onScreen then
            local dist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = hitbox
            end
        end
    end
    return best
end

-- 核心: 伪造 Shoot 事件直接命中目标 (来自抓包格式)
local function ShootAt(hitbox)
    local root = GetRoot()
    if not root then return end
    local hitPos = hitbox.Position
    local direction = (hitPos - root.Position).Unit * 1000
    Network:FireServer("Shoot",
        root.Position + Vector3.new(0, 1.5, 0),  -- 起点
        direction,                                -- 方向/速度
        hitbox,                                   -- 目标Hitbox
        hitPos,                                   -- 命中点
        os.clock()                                -- 时间戳
    )
end

--============================================================
-- 自瞄 (自动锁定视野内最近敌人开火)
--============================================================
local aimConn
local function SetAimbot(state)
    Config.AimbotEnabled = state
    if aimConn then aimConn:Disconnect() aimConn = nil end
    if state then
        local last = 0
        aimConn = RunService.Heartbeat:Connect(function()
            if os.clock() - last < Config.FireRate then return end
            local target = GetClosestEnemy()
            if target then
                ShootAt(target)
                last = os.clock()
            end
        end)
    end
end

--============================================================
-- 击杀光环 (自动攻击范围内所有敌人)
--============================================================
local auraConn
local function SetKillAura(state)
    Config.KillAura = state
    if auraConn then auraConn:Disconnect() auraConn = nil end
    if state then
        local last = 0
        auraConn = RunService.Heartbeat:Connect(function()
            if os.clock() - last < Config.FireRate then return end
            local root = GetRoot()
            if not root then return end
            for _, e in ipairs(GetEnemies()) do
                local hitbox = GetHitbox(e.Model, Config.AimPart)
                if (hitbox.Position - root.Position).Magnitude <= Config.KillAuraRange then
                    ShootAt(hitbox)
                    last = os.clock()
                end
            end
        end)
    end
end

--============================================================
-- 飞行 (利用客户端权威的 CharacterReplicationHeartbeat)
--============================================================
local flyConn
local function SetFly(state)
    Config.Fly = state
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if state then
        flyConn = RunService.Heartbeat:Connect(function(dt)
            local root = GetRoot()
            if not root then return end
            local move = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls():GetMoveVector()
            local dir = (Camera.CFrame.LookVector * -move.Z) + (Camera.CFrame.RightVector * move.X)
            root.CFrame = root.CFrame + dir * Config.FlySpeed * dt
            root.Velocity = Vector3.zero
            -- 上报伪造位置保持服务器同步
            Network:FireServer("CharacterReplicationHeartbeat", root.Position)
        end)
    end
end

-- 加速
local speedConn
local function SetSpeed(state)
    Config.SpeedEnabled = state
    if speedConn then speedConn:Disconnect() speedConn = nil end
    if state then
        speedConn = RunService.Heartbeat:Connect(function()
            local c = GetCharacter()
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = Config.Speed end
        end)
    end
end

--============================================================
-- ESP 透视 (玩家高亮)
--============================================================
local espObjs = {}
local function SetESP(state)
    Config.ESP = state
    for _, hl in pairs(espObjs) do hl:Destroy() end
    espObjs = {}
    if state then
        for _, e in ipairs(GetEnemies()) do
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromRGB(255, 60, 60)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.5
            hl.Adornee = e.Model
            hl.Parent = e.Model
            table.insert(espObjs, hl)
        end
    end
end

--============================================================
-- 自动领取增益 (Fly / X-Ray, 来自抓包 RequestBoostOffer)
--============================================================
local boostConn
local function SetAutoBoost(state)
    if boostConn then boostConn:Disconnect() boostConn = nil end
    if state then
        boostConn = RunService.Heartbeat:Connect(function()
            task.wait(5)
            pcall(function()
                Network:FireServer("RequestBoostOffer", "Fly")
                Network:FireServer("RequestBoostOffer", "X-Ray")
            end)
        end)
    end
end

--============================================================
-- WindUI 界面
--============================================================
local Window = WindUI:CreateWindow({
    Title = "秒杀面板",
    Icon = "crosshair",
    Author = "RemoteSpy 抓包制作",
    Folder = "AimPanel",
    Size = UDim2.fromOffset(480, 360),
    Transparent = true,
    ToggleKey = Enum.KeyCode.RightControl,
})

-- 战斗页
local CombatTab = Window:Tab({ Title = "战斗", Icon = "swords" })

CombatTab:Toggle({
    Title = "自瞄秒杀 (锁定最近敌人自动开火)",
    Value = false,
    Callback = SetAimbot,
})

CombatTab:Toggle({
    Title = "击杀光环 (范围内全部敌人)",
    Value = false,
    Callback = SetKillAura,
})

CombatTab:Dropdown({
    Title = "瞄准部位",
    Values = {"BodyHitbox", "HeadHitbox"},
    Value = "BodyHitbox",
    Callback = function(v) Config.AimPart = v end,
})

CombatTab:Slider({
    Title = "自瞄视野范围 (像素)",
    Value = { Min = 50, Max = 1000, Default = 300 },
    Callback = function(v) Config.AimbotFOV = v end,
})

CombatTab:Slider({
    Title = "射速间隔 (秒)",
    Value = { Min = 0.01, Max = 1, Default = 0.05 },
    Step = 0.01,
    Callback = function(v) Config.FireRate = v end,
})

CombatTab:Slider({
    Title = "击杀光环范围",
    Value = { Min = 20, Max = 1000, Default = 200 },
    Callback = function(v) Config.KillAuraRange = v end,
})

-- 移动页
local MoveTab = Window:Tab({ Title = "移动", Icon = "rocket" })

MoveTab:Toggle({
    Title = "飞行 (心跳伪造, 服务器同步)",
    Value = false,
    Callback = SetFly,
})

MoveTab:Slider({
    Title = "飞行速度",
    Value = { Min = 16, Max = 300, Default = 60 },
    Callback = function(v) Config.FlySpeed = v end,
})

MoveTab:Toggle({
    Title = "加速",
    Value = false,
    Callback = SetSpeed,
})

MoveTab:Slider({
    Title = "移动速度",
    Value = { Min = 16, Max = 250, Default = 50 },
    Callback = function(v) Config.Speed = v end,
})

-- 视觉页
local VisualTab = Window:Tab({ Title = "视觉", Icon = "eye" })

VisualTab:Toggle({
    Title = "敌人高亮透视 (ESP)",
    Value = false,
    Callback = SetESP,
})

-- 自动页
local AutoTab = Window:Tab({ Title = "自动", Icon = "bot" })

AutoTab:Toggle({
    Title = "自动领取增益 (Fly + X-Ray)",
    Value = false,
    Callback = SetAutoBoost,
})

AutoTab:Button({
    Title = "刷新转盘状态",
    Callback = function()
        Network:FireServer("RequestSpinWheelState")
        WindUI:Notify({ Title = "转盘", Content = "已请求转盘状态", Duration = 2 })
    end,
})

WindUI:Notify({
    Title = "加载完成",
    Content = "按 RightControl 开关面板",
    Duration = 4,
})
