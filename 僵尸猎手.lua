--====================================================--
--  僵尸猎手 · Zombie Hunter (手机端)
--  基于 Remote Spy 抓包还原的 Fire 协议自动战斗脚本
--  UI: HSX 同款黑曜石开源 UI
--====================================================--

local repo = "https://raw.githubusercontent.com/fningna51-stack/-/main/"
local Library = loadstring(game:HttpGet(repo .. "%E8%84%9A%E6%9C%ACUI%E8%87%AA%E5%88%B6"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

--====================================================--
--  服务与常量
--====================================================--
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Events      = ReplicatedStorage:WaitForChild("Events")
local FireRemote  = Events:WaitForChild("Actions"):WaitForChild("Fire")
local LavaRemote  = Events:WaitForChild("Actions"):WaitForChild("Lava")

-- 抓包确认的武器列表（按持有优先级）
local KNOWN_WEAPONS = { "M4A1", "MP5", "M1911" }

-- 瞄准部位优先级（自动从上到下找第一个存在的部件）
local AIM_PARTS = {
	["爆头 (Head)"]        = { "HeadHitbox", "Head" },
	["胸部 (Chest)"]       = { "ChestHitbox", "UpperTorso", "BodyHitbox" },
	["身体中心 (Root)"]    = { "HumanoidRootPart", "BodyHitbox", "UpperTorso" },
}

--====================================================--
--  工具函数
--====================================================--
local function GetCharacter()
	return LocalPlayer.Character
end

-- 找到当前手持武器（名称 + 模型 + Exit 部件）
local function GetEquippedWeapon(forcedName)
	local char = GetCharacter()
	if not char then return nil end

	if forcedName and forcedName ~= "自动检测" then
		local w = char:FindFirstChild(forcedName)
		if w then
			return forcedName, w, w:FindFirstChild("Exit", true)
		end
	end

	for _, name in ipairs(KNOWN_WEAPONS) do
		local w = char:FindFirstChild(name)
		if w then
			return name, w, w:FindFirstChild("Exit", true)
		end
	end

	-- 兜底：任何带 Exit 部件的模型都当作武器
	for _, child in ipairs(char:GetChildren()) do
		local exit = child:FindFirstChild("Exit", true)
		if exit then
			return child.Name, child, exit
		end
	end
	return nil
end

local function GetMuzzlePosition(exitPart, char)
	if exitPart then
		if exitPart:IsA("Attachment") then
			return exitPart.WorldPosition
		elseif exitPart:IsA("BasePart") then
			return exitPart.Position
		end
	end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or Vector3.zero
end

-- 在僵尸模型上按优先级找瞄准部位
local function ResolveAimPart(zombie, priorityList)
	for _, partName in ipairs(priorityList) do
		local p = zombie:FindFirstChild(partName)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- 收集范围内所有活僵尸，按距离排序
local function GetZombiesInRange(maxDistance, aimPriority)
	local results = {}
	local char = GetCharacter()
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return results end

	local folder = Workspace:FindFirstChild("ActiveZombies")
	if not folder then return results end

	for _, zombie in ipairs(folder:GetChildren()) do
		local humanoid = zombie:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local part = ResolveAimPart(zombie, aimPriority)
			if part then
				local dist = (part.Position - myRoot.Position).Magnitude
				if dist <= maxDistance then
					table.insert(results, {
						Model = zombie,
						Part = part,
						Distance = dist,
						Humanoid = humanoid,
					})
				end
			end
		end
	end

	table.sort(results, function(a, b) return a.Distance < b.Distance end)
	return results
end

--====================================================--
--  核心：完全按抓包格式构造 Fire 调用
--  Fire:FireServer(武器名, 命中表, 弹道表)
--  命中表项: { 命中部件, 命中点Vector3, 法线Vector3 }
--  弹道表项: { 武器名, 枪口Vector3, 目标Vector3, 命中Vector3,
--              true, 命中部件, false, false, "Default", Exit部件 }
--====================================================--
local function FireAtZombies(targets, weaponName, exitPart, shotsPerTarget)
	local char = GetCharacter()
	if not char or #targets == 0 then return 0 end

	local muzzle = GetMuzzlePosition(exitPart, char)
	local exitValue = exitPart or char:FindFirstChild("HumanoidRootPart")

	local hits, shots = {}, {}

	for _, t in ipairs(targets) do
		if t.Part and t.Part.Parent then
			local hitPos = t.Part.Position
			local normal = (hitPos - muzzle).Magnitude > 0
				and (hitPos - muzzle).Unit
				or Vector3.new(0, 0, -1)

			for _ = 1, shotsPerTarget do
				table.insert(hits, { t.Part, hitPos, normal })
				table.insert(shots, {
					weaponName,
					muzzle,
					hitPos,          -- 目标点
					hitPos,          -- 命中点
					true,
					t.Part,
					false,
					false,
					"Default",
					exitValue,
				})
			end
		end
	end

	if #hits > 0 then
		pcall(function()
			FireRemote:FireServer(weaponName, hits, shots)
		end)
	end
	return #hits
end

--====================================================--
--  UI 窗口
--====================================================--
local Window = Library:CreateWindow({
	Title = "僵尸猎手",
	Footer = "版本: v1.1 | 手机端",
	Icon = 95816097006870,
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Combat  = Window:AddTab("自动战斗", "crosshair"),
	Visual  = Window:AddTab("透视", "eye"),
	Fly     = Window:AddTab("飞行", "send"),
	Protect = Window:AddTab("防护", "shield"),
	Misc    = Window:AddTab("杂项", "boxes"),
	["UI Settings"] = Window:AddTab("界面设置", "settings"),
}

--====================================================--
--  页 1：自动战斗
--====================================================--
local CombatLeft = Tabs.Combat:AddLeftGroupbox("静默开火", "zap")

CombatLeft:AddToggle("AutoFire", {
	Text = "自动开火 (Kill Aura)",
	Tooltip = "自动向范围内的所有僵尸开火，无需手动瞄准",
	Default = false,
	Callback = function(Value)
		print("[战斗] 自动开火:", Value)
	end,
})

CombatLeft:AddDropdown("WeaponSelect", {
	Values = { "自动检测", "M4A1", "MP5", "M1911" },
	Default = 1,
	Multi = false,
	Text = "武器选择",
	Tooltip = "自动检测 = 使用当前手持武器",
	Callback = function(Value)
		print("[战斗] 武器:", Value)
	end,
})

CombatLeft:AddDropdown("AimPart", {
	Values = { "爆头 (Head)", "胸部 (Chest)", "身体中心 (Root)" },
	Default = 1,
	Multi = false,
	Text = "瞄准部位",
	Tooltip = "爆头伤害最高，打不中时自动降级",
	Callback = function(Value)
		print("[战斗] 瞄准部位:", Value)
	end,
})

local CombatRight = Tabs.Combat:AddRightGroupbox("参数调节", "sliders")

CombatRight:AddSlider("FireRange", {
	Text = "射程 ( studs )",
	Default = 150, Min = 10, Max = 500, Rounding = 0,
	Tooltip = "只攻击此距离内的僵尸",
})

CombatRight:AddSlider("FireRate", {
	Text = "开火间隔 ( 秒 )",
	Default = 0.15, Min = 0.05, Max = 1, Rounding = 2,
	Tooltip = "越小射速越快，太小可能被检测",
})

CombatRight:AddSlider("MaxTargets", {
	Text = "同时攻击目标数",
	Default = 3, Min = 1, Max = 10, Rounding = 0,
	Tooltip = "一次开火同时命中多少只僵尸",
})

CombatRight:AddSlider("ShotsPerTarget", {
	Text = "单目标连发倍数",
	Default = 1, Min = 1, Max = 5, Rounding = 0,
	Tooltip = "每轮对每个目标发射几发（加速击杀，慎用）",
})

CombatLeft:AddDivider()

CombatLeft:AddButton({
	Text = "一键清场 (立即攻击全场僵尸)",
	Tooltip = "立刻对所有射程内僵尸打一轮",
	Func = function()
		local aim = AIM_PARTS[Options.AimPart.Value] or AIM_PARTS["爆头 (Head)"]
		local weaponName, _, exitPart = GetEquippedWeapon(Options.WeaponSelect.Value)
		if not weaponName then
			Library:Notify({ Title = "错误", Description = "未检测到手上的武器！", Time = 3 })
			return
		end
		local zombies = GetZombiesInRange(Options.FireRange.Value, aim)
		local n = FireAtZombies(zombies, weaponName, exitPart, 1)
		Library:Notify({ Title = "清场", Description = "已攻击 " .. n .. " 个目标", Time = 3 })
	end,
})

-- 自动开火主循环
task.spawn(function()
	while true do
		local interval = Options.FireRate and Options.FireRate.Value or 0.15
		task.wait(interval)
		if Library.Unloaded then break end
		if Toggles.AutoFire and Toggles.AutoFire.Value then
			local ok, err = pcall(function()
				local aim = AIM_PARTS[Options.AimPart.Value] or AIM_PARTS["爆头 (Head)"]
				local weaponName, _, exitPart = GetEquippedWeapon(Options.WeaponSelect.Value)
				if weaponName then
					local zombies = GetZombiesInRange(Options.FireRange.Value, aim)
					-- 截取前 N 个最近的
					local targets = {}
					for i = 1, math.min(Options.MaxTargets.Value, #zombies) do
						targets[i] = zombies[i]
					end
					FireAtZombies(targets, weaponName, exitPart, Options.ShotsPerTarget.Value)
				end
			end)
			if not ok then warn("[自动开火错误]", err) end
		end
	end
end)

--====================================================--
--  页 2：僵尸透视 (ESP)
--====================================================--
local VisualLeft = Tabs.Visual:AddLeftGroupbox("僵尸透视", "eye")

local ESPStore = {} -- [model] = {Highlight, Billboard}

local function RemoveESP(model)
	local item = ESPStore[model]
	if item then
		if item.Highlight then pcall(function() item.Highlight:Destroy() end) end
		if item.Billboard then pcall(function() item.Billboard:Destroy() end) end
		ESPStore[model] = nil
	end
end

local function AddESP(zombie)
	if ESPStore[zombie] then return end

	local hl = Instance.new("Highlight")
	hl.FillColor = Options.EspColor and Options.EspColor.Value or Color3.fromRGB(255, 40, 40)
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.4
	hl.Adornee = zombie
	hl.Parent = zombie

	local billboard
	if Toggles.EspName and Toggles.EspName.Value then
		billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 160, 0, 44)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.TextSize = 13
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard

		local adornee = zombie:FindFirstChild("Head") or zombie:FindFirstChild("HumanoidRootPart")
		if adornee then
			billboard.Adornee = adornee
			billboard.Parent = zombie
		else
			billboard:Destroy()
			billboard = nil
		end
	end

	ESPStore[zombie] = { Highlight = hl, Billboard = billboard }
end

VisualLeft:AddToggle("ZombieESP", {
	Text = "僵尸高亮透视",
	Tooltip = "隔墙显示所有僵尸轮廓",
	Default = false,
	Callback = function(Value)
		if not Value then
			for model in pairs(ESPStore) do RemoveESP(model) end
		end
	end,
})
:AddColorPicker("EspColor", {
	Default = Color3.fromRGB(255, 40, 40),
	Title = "透视颜色",
})

VisualLeft:AddToggle("EspName", {
	Text = "显示名字 / 血量 / 距离",
	Tooltip = "在僵尸头顶显示信息",
	Default = true,
})

VisualLeft:AddSlider("EspRange", {
	Text = "透视范围 ( studs )",
	Default = 300, Min = 50, Max = 1000, Rounding = 0,
})

-- ESP 主循环
task.spawn(function()
	while true do
		task.wait(0.5)
		if Library.Unloaded then break end
		if Toggles.ZombieESP and Toggles.ZombieESP.Value then
			pcall(function()
				local char = GetCharacter()
				local myRoot = char and char:FindFirstChild("HumanoidRootPart")
				local folder = Workspace:FindFirstChild("ActiveZombies")
				if not (myRoot and folder) then return end

				-- 清理已死/超范围的
				for model in pairs(ESPStore) do
					local hum = model.Parent and model:FindFirstChildOfClass("Humanoid")
					local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
					if not hum or hum.Health <= 0 or not root
						or (root.Position - myRoot.Position).Magnitude > Options.EspRange.Value then
						RemoveESP(model)
					end
				end

				-- 添加新僵尸 + 刷新文字
				for _, zombie in ipairs(folder:GetChildren()) do
					local hum = zombie:FindFirstChildOfClass("Humanoid")
					local root = zombie:FindFirstChild("HumanoidRootPart")
					if hum and hum.Health > 0 and root
						and (root.Position - myRoot.Position).Magnitude <= Options.EspRange.Value then
						AddESP(zombie)
						local item = ESPStore[zombie]
						if item and item.Highlight then
							item.Highlight.FillColor = Options.EspColor.Value
						end
						if item and item.Billboard then
							local label = item.Billboard:FindFirstChildOfClass("TextLabel")
							if label then
								local dist = math.floor((root.Position - myRoot.Position).Magnitude)
								label.Text = string.format("%s\n血量 %d | %dm",
									zombie.Name, math.floor(hum.Health), dist)
							end
						end
					end
				end
			end)
		end
	end
end)

--====================================================--
--  页 3：飞行
--====================================================--
local FlyLeft = Tabs.Fly:AddLeftGroupbox("飞行控制", "send")

local flyState = {
	Flying = false,
	GoingUp = false,
	GoingDown = false,
	BodyVelocity = nil,
	BodyGyro = nil,
	Connection = nil,
	ButtonsGui = nil,
}

-- 手写拖动（Draggable 已废弃，部分手机执行器失效）
local function MakeDraggable(frame, dragHandle)
	dragHandle = dragHandle or frame
	local dragging = false
	local dragStart, startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	dragHandle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	dragHandle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- 屏幕上的 上升/下降 按住按钮（飞行开启时显示，可拖动）
local function CreateFlyButtons()
	if flyState.ButtonsGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZHFlyButtons"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true

	-- 优先挂 PlayerGui：部分手机执行器对 gethui/CoreGui 不渲染
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 110, 0, 150)
	frame.Position = UDim2.new(1, -130, 0.5, -75)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = frame

	local function holdBtn(text, posY, color)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -16, 0, 60)
		btn.Position = UDim2.new(0, 8, 0, posY)
		btn.BackgroundColor3 = color
		btn.BackgroundTransparency = 0.15
		btn.Text = text
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 18
		btn.BorderSizePixel = 0
		btn.Parent = frame
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = btn
		return btn
	end

	local upBtn = holdBtn("上升 ▲", 8, Color3.fromRGB(45, 90, 160))
	local downBtn = holdBtn("下降 ▼", 80, Color3.fromRGB(120, 60, 160))

	MakeDraggable(frame)

	upBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			flyState.GoingUp = true
		end
	end)
	upBtn.InputEnded:Connect(function() flyState.GoingUp = false end)

	downBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			flyState.GoingDown = true
		end
	end)
	downBtn.InputEnded:Connect(function() flyState.GoingDown = false end)

	flyState.ButtonsGui = gui
end

local function StartFly()
	local char = GetCharacter()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	humanoid.PlatformStand = true

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.zero
	bv.Parent = root

	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bg.P = 9e4
	bg.CFrame = root.CFrame
	bg.Parent = root

	flyState.BodyVelocity = bv
	flyState.BodyGyro = bg

	local camera = Workspace.CurrentCamera
	flyState.Connection = RunService.RenderStepped:Connect(function()
		if not flyState.Flying then return end
		local c = GetCharacter()
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not r or not hum or hum.Health <= 0 then return end

		local speed = Options.FlySpeed and Options.FlySpeed.Value or 50
		local vel = hum.MoveDirection * speed
		if flyState.GoingUp then
			vel = vel + Vector3.new(0, speed, 0)
		elseif flyState.GoingDown then
			vel = vel + Vector3.new(0, -speed, 0)
		end
		bv.Velocity = vel
		bg.CFrame = CFrame.new(r.Position, r.Position + camera.CFrame.LookVector)
	end)

	CreateFlyButtons()
	if flyState.ButtonsGui then
		flyState.ButtonsGui.Enabled = true
	end
end

local function StopFly()
	flyState.Flying = false
	flyState.GoingUp = false
	flyState.GoingDown = false
	if flyState.Connection then
		flyState.Connection:Disconnect()
		flyState.Connection = nil
	end
	if flyState.BodyVelocity then flyState.BodyVelocity:Destroy() flyState.BodyVelocity = nil end
	if flyState.BodyGyro then flyState.BodyGyro:Destroy() flyState.BodyGyro = nil end
	if flyState.ButtonsGui then flyState.ButtonsGui.Enabled = false end

	local char = GetCharacter()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	end
end

FlyLeft:AddToggle("FlyToggle", {
	Text = "开启飞行",
	Tooltip = "方向跟随摇杆 + 相机朝向，用屏幕按钮升降",
	Default = false,
	Callback = function(Value)
		if Value then
			flyState.Flying = true
			StartFly()
			Library:Notify({ Title = "飞行", Description = "已开启，拖动摇杆移动，按住右侧按钮升降", Time = 3 })
		else
			StopFly()
		end
	end,
})

FlyLeft:AddSlider("FlySpeed", {
	Text = "飞行速度",
	Default = 50, Min = 10, Max = 300, Rounding = 0,
	Tooltip = "飞行移动速度",
})

FlyLeft:AddLabel("手机端：开启后屏幕右侧出现「上升/下降」按住按钮，可拖动位置", true)

-- PC 快捷键：E 上升 / Q 下降
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		flyState.GoingUp = true
	elseif input.KeyCode == Enum.KeyCode.Q then
		flyState.GoingDown = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E then
		flyState.GoingUp = false
	elseif input.KeyCode == Enum.KeyCode.Q then
		flyState.GoingDown = false
	end
end)

-- 死亡/重生后自动关闭飞行
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	if flyState.Flying then
		StopFly()
		if Toggles.FlyToggle then
			Toggles.FlyToggle:SetValue(false)
		end
	end
end)

--====================================================--
--  页 4：防护
--====================================================--
local ProtectLeft = Tabs.Protect:AddLeftGroupbox("伤害防护", "shield")

ProtectLeft:AddToggle("AntiLava", {
	Text = "免疫岩浆伤害",
	Tooltip = "拦截客户端上报的岩浆触碰事件（需要执行器支持 hookmetamethod）",
	Default = false,
})

ProtectLeft:AddToggle("AntiVoid", {
	Text = "掉落保护",
	Tooltip = "掉出地图时自动传送回安全位置",
	Default = false,
})

-- 穿墙 (Noclip)：持续把角色部件碰撞关掉
ProtectLeft:AddToggle("Noclip", {
	Text = "穿墙 (Noclip)",
	Tooltip = "开启后可穿过墙体和障碍物",
	Default = false,
})

local noclipConnection
local function SetNoclip(enabled)
	if enabled then
		if noclipConnection then return end
		noclipConnection = RunService.Stepped:Connect(function()
			local char = GetCharacter()
			if not char then return end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
	else
		if noclipConnection then
			noclipConnection:Disconnect()
			noclipConnection = nil
		end
		-- Roblox 角色部件默认 CanCollide = false，无需恢复
	end
end

Toggles.Noclip:OnChanged(function()
	SetNoclip(Toggles.Noclip.Value)
end)

-- 防岩浆：hook __namecall 拦截 Lava 上报
do
	local mt = getrawmetatable and getrawmetatable(game)
	if mt and hookmetamethod then
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			if Toggles.AntiLava and Toggles.AntiLava.Value
				and method == "FireServer" and self == LavaRemote then
				return -- 直接吞掉，不上报
			end
			return oldNamecall(self, ...)
		end)
	else
		ProtectLeft:AddLabel("当前执行器不支持 hookmetamethod，防岩浆不可用", true)
	end
end

-- 掉落保护
task.spawn(function()
	while true do
		task.wait(0.3)
		if Library.Unloaded then break end
		if Toggles.AntiVoid and Toggles.AntiVoid.Value then
			pcall(function()
				local char = GetCharacter()
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < Workspace.FallenPartsDestroyHeight + 10 then
					root.CFrame = CFrame.new(0, 50, 0)
					root.Velocity = Vector3.zero
				end
			end)
		end
	end
end)

--====================================================--
--  页 5：杂项
--====================================================--
local MiscLeft = Tabs.Misc:AddLeftGroupbox("人物增强", "user")

MiscLeft:AddSlider("WalkSpeed", {
	Text = "移动速度",
	Default = 16, Min = 16, Max = 200, Rounding = 0,
	Callback = function(Value)
		pcall(function()
			local hum = GetCharacter() and GetCharacter():FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = Value end
		end)
	end,
})

MiscLeft:AddSlider("JumpPower", {
	Text = "跳跃高度",
	Default = 50, Min = 50, Max = 300, Rounding = 0,
	Callback = function(Value)
		pcall(function()
			local hum = GetCharacter() and GetCharacter():FindFirstChildOfClass("Humanoid")
			if hum then hum.JumpPower = Value end
		end)
	end,
})

-- 重生后保持速度/跳跃
LocalPlayer.CharacterAdded:Connect(function(char)
	task.wait(1)
	pcall(function()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = Options.WalkSpeed.Value
			hum.JumpPower = Options.JumpPower.Value
		end
	end)
end)

--====================================================--
--  页 6：界面设置
--====================================================--
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("菜单", "wrench")

MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "自定义光标",
	Default = true,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})

MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "通知位置",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})

MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "DPI缩放（手机建议 75%）",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		Library:SetDPIScale(tonumber(Value))
	end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("菜单快捷键")
	:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "菜单快捷键" })

MenuGroup:AddButton("卸载脚本", function()
	StopFly()
	SetNoclip(false)
	if flyState.ButtonsGui then
		pcall(function() flyState.ButtonsGui:Destroy() end)
		flyState.ButtonsGui = nil
	end
	for model in pairs(ESPStore) do RemoveESP(model) end
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

pcall(function()
	ThemeManager:SetLibrary(Library)
	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
	ThemeManager:SetFolder("ZombieHunter")
	SaveManager:SetFolder("ZombieHunter/config")
	SaveManager:BuildConfigSection(Tabs["UI Settings"])
	ThemeManager:ApplyToTab(Tabs["UI Settings"])
	SaveManager:LoadAutoloadConfig()
end)

Library:Notify({
	Title = "僵尸猎手 v1.1",
	Description = "加载成功！「自动战斗」开火打僵尸，「飞行」页一键起飞",
	Time = 5,
})
