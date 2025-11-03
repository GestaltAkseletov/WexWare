--[ LOCAL COMBAT SQUAD SCRIPT (R15) V7.0 - ВСЕ ФУНКЦИИ ]--

-- Включает: 9 Юнитов, Партиклы, Автономный AI, Голосовые Отклики и Все Тактические Команды.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Workspace = game:GetService("Workspace")

local RunService = game:GetService("RunService")

local ContentProvider = game:GetService("ContentProvider")

local Debris = game:GetService("Debris")

local UIS = game:GetService("UserInputService")

-- =================================================================================

--                              [ 1. КОНФИГУРАЦИЯ АССЕТОВ И ПАРАМЕТРОВ ]

-- =================================================================================

local CONFIG = {

    SquadNames = {"Victor", "Ethan", "Grant", "Alex", "Marcus", "Owen", "Leo", "Caleb", "Ryan"}, 

    MaxSquadSize = 9, 

    

    ASSET_IDS = {

        -- Экипировка и Анимации (рабочие ID)

        Shirt = "rbxassetid://10287910007",   

        Pants = "rbxassetid://10287914480",   

        Helmet = "rbxassetid://6552796191",   

        WeaponBack = "rbxassetid://6661904712", 

        WalkAnimationId = 9482705178, 

        JumpAnimationId = "rbxassetid://507646549", 

        AimAnimationId = "rbxassetid://899026410", 

        -- Звуки и Партиклы

        RESPONSE_SOUND_ID = "rbxassetid://135308704",   -- "Roger That"

        GunshotSoundId = "rbxassetid://2811598570",     -- Звук выстрела

        MuzzleFlashTexture = "rbxassetid://6273181881", -- Вспышка

        DustParticleTexture = "rbxassetid://6273183594",-- Пыль/След шага

    },

    FOOTSTEP_SOUND_ID = "rbxassetid://479709292", 

    

    -- Параметры Поведения и Строя

    Spacing = 3, FollowOffset = 6, 

    FollowDelayFactor = 0.95, JumpForce = 50, 

    AttackFormationDepth = 15, AttackFormationWidth = 3,  

    -- Параметры Патруля и AI

    PatrolCenter = nil, PatrolRadius = 0,   

    IdleCheckInterval = 5, IdleCheckChance = 0.1, -- 10% шанс на действие раз в 5 сек

}

local Squad = {}

local Mouse = LocalPlayer:GetMouse()

local TargetingMode = false 

local LastStateChange = {} 

local TargetPositions = {} 

local CurrentFormation = "Follow"

local PatrolPoint = Vector3.new()

local CONFIG.AttackTarget = nil

-- =================================================================================

--                              [ 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]

-- =================================================================================

local function IsAssetId(id)

    return tonumber(id) ~= nil and id ~= ""

end

local function PlayResponseSound(message)

    local sound = Instance.new("Sound")

    sound.SoundId = CONFIG.ASSET_IDS.RESPONSE_SOUND_ID

    sound.Volume = 1

    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then

        sound.Parent = LocalPlayer.Character.PrimaryPart

    end

    sound:Play()

    Debris:AddItem(sound, 2)

    LocalPlayer:SetAttribute("ChatCommandFeedback", "Squad: " .. message)

end

local function GetRandomPatrolPoint()

    if not CONFIG.PatrolCenter or CONFIG.PatrolRadius == 0 then return nil end

    local x = CONFIG.PatrolCenter.X + math.random(-CONFIG.PatrolRadius, CONFIG.PatrolRadius)

    local z = CONFIG.PatrolCenter.Z + math.random(-CONFIG.PatrolRadius, CONFIG.PatrolRadius)

    local ray = Ray.new(Vector3.new(x, 1000, z), Vector3.new(0, -2000, 0))

    local hit, pos = Workspace:FindPartOnRay(ray, nil, false, true)

    return pos

end

local function FireAtTarget(unit, targetPos)

    local root = unit:FindFirstChild("HumanoidRootPart")

    local muzzleFlashEmitter = root:FindFirstChild("MuzzleFlash")

    if not root or not muzzleFlashEmitter then return end

    

    -- 1. Звук Выстрела

    local sound = Instance.new("Sound")

    sound.SoundId = CONFIG.ASSET_IDS.GunshotSoundId

    sound.Volume = 0.8; sound.Parent = root

    sound:Play(); Debris:AddItem(sound, 1) 

    

    -- 2. Визуальный Эффект (Луч - трассер)

    local distance = (targetPos - root.Position).magnitude

    local lookVector = (targetPos - root.Position).unit

    

    local laser = Instance.new("Part")

    laser.Anchored = true; laser.CanCollide = false; laser.Color = Color3.new(1, 0.8, 0.2); laser.Material = Enum.Material.Neon

    laser.Size = Vector3.new(0.1, 0.1, distance)

    laser.CFrame = CFrame.new(root.Position, targetPos) * CFrame.new(0, 0, -distance / 2)

    laser.Parent = Workspace

    Debris:AddItem(laser, 0.05) 

    -- 3. Партиклы Выстрела (Вспышка и Дым)

    local muzzlePos = root.CFrame * CFrame.new(1.5, 0, -2) -- Позиция "дула" (передний правый край)

    muzzleFlashEmitter.CFrame = CFrame.new(muzzlePos.Position, muzzlePos.Position + lookVector)

    muzzleFlashEmitter:Emit(5) 

    

    local smoke = Instance.new("Smoke")

    smoke.Color = Color3.new(0.2, 0.2, 0.2); smoke.Size = 0.5; smoke.RiseVelocity = 1

    smoke.Parent = laser 

    Debris:AddItem(smoke, 0.5) 

end

-- Создание партиклов для юнита

local function CreateUnitParticles(unit)

    local root = unit:FindFirstChild("HumanoidRootPart")

    if not root then return end

    -- 1. Партиклы Ходьбы (Dust/Mud)

    local dustEmitter = Instance.new("ParticleEmitter")

    dustEmitter.Name = "FootDust"

    dustEmitter.Texture = CONFIG.ASSET_IDS.DustParticleTexture

    dustEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.5)})

    dustEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})

    dustEmitter.Lifetime = 0.5; dustEmitter.Rate = 0; dustEmitter.EmissionDirection = Enum.ParticleEmissionDirection.Top

    dustEmitter.Parent = root

    

    -- 2. Партиклы Выстрела (Muzzle Flash)

    local muzzleFlashEmitter = Instance.new("ParticleEmitter")

    muzzleFlashEmitter.Name = "MuzzleFlash"

    muzzleFlashEmitter.Texture = CONFIG.ASSET_IDS.MuzzleFlashTexture

    muzzleFlashEmitter.Size = NumberSequence.new(0.5, 1)

    muzzleFlashEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.05, 0), NumberSequenceKeypoint.new(1, 1)})

    muzzleFlashEmitter.Color = ColorSequence.new(Color3.new(1, 1, 0), Color3.new(1, 0.5, 0))

    muzzleFlashEmitter.Lifetime = 0.1; muzzleFlashEmitter.Rate = 0; muzzleFlashEmitter.LightEmission = 1

    muzzleFlashEmitter.Acceleration = Vector3.new(0, 0, -2)

    muzzleFlashEmitter.Parent = root 

end

local function SetupUnit(unit, name)

    unit.Name = name

    unit:SetAttribute("CurrentState", "Follow")

    unit:SetAttribute("LastIdleTime", tick())

    

    local human = unit:FindFirstChildOfClass("Humanoid")

    if not human then return unit end

    

    -- Создание партиклов

    CreateUnitParticles(unit) 

    

    human.RigType = Enum.HumanoidRigType.R15

    local animator = human:FindFirstChildOfClass("Animator") or Instance.new("Animator", human)

    local aimAnim = Instance.new("Animation"); aimAnim.AnimationId = CONFIG.ASSET_IDS.AimAnimationId

    unit:SetAttribute("AimAnimTrack", animator:LoadAnimation(aimAnim))

    

    local idleAnim = Instance.new("Animation"); idleAnim.AnimationId = CONFIG.ASSET_IDS.JumpAnimationId -- Заглушка

    unit:SetAttribute("IdleCheckAnim", animator:LoadAnimation(idleAnim))

    

    local sound = Instance.new("Sound"); sound.SoundId = CONFIG.FOOTSTEP_SOUND_ID; sound.Volume = 0.5; sound.Parent = unit.PrimaryPart 

    

    local appearance = Instance.new("HumanoidDescription")

    appearance.Shirt = IsAssetId(CONFIG.ASSET_IDS.Shirt) and tonumber(CONFIG.ASSET_IDS.Shirt) or 0

    appearance.Pants = IsAssetId(CONFIG.ASSET_IDS.Pants) and tonumber(CONFIG.ASSET_IDS.Pants) or 0

    

    local accessories = {}

    if IsAssetId(CONFIG.ASSET_IDS.Helmet) then table.insert(accessories, tonumber(CONFIG.ASSET_IDS.Helmet)) end

    if IsAssetId(CONFIG.ASSET_IDS.WeaponBack) then table.insert(accessories, tonumber(CONFIG.ASSET_IDS.WeaponBack)) end

    appearance:SetAccessories(accessories)

    human:ApplyDescription(appearance)

    local animateScript = unit:FindFirstChild("Animate")

    if animateScript then

        local walkState = animateScript:FindFirstChild("walk"):FindFirstChild("WalkAnim")

        local jumpState = animateScript:FindFirstChild("jump"):FindFirstChild("JumpAnim")

        if walkState and CONFIG.ASSET_IDS.WalkAnimationId ~= "" then walkState.AnimationId = CONFIG.ASSET_IDS.WalkAnimationId end

        if jumpState and CONFIG.ASSET_IDS.JumpAnimationId ~= "" then jumpState.AnimationId = CONFIG.ASSET_IDS.JumpAnimationId end

    end

    

    return unit

end

local function SpawnSquad()

    if not LocalPlayer.Character or not LocalPlayer.Character.Parent then return end

    

    for _, unit in ipairs(Squad) do unit:Destroy() end

    Squad = {}

    

    for i = 1, CONFIG.MaxSquadSize do

        local name = CONFIG.SquadNames[i]

        local unit = LocalPlayer.Character:Clone()

        unit.PrimaryPart.CFrame = LocalPlayer.Character.PrimaryPart.CFrame * CFrame.new(math.random(-5, 5), 5, math.random(-5, 5))

        unit.Parent = Workspace

        unit = SetupUnit(unit, name)

        Squad[i] = unit

    end

    CurrentFormation = "Follow"

    PlayResponseSound(string.format("Squad of %d units, ready!", CONFIG.MaxSquadSize))

end

-- =================================================================================

--                              [ 3. ЛОГИКА ДВИЖЕНИЯ И АВТОНОМНОЕ ПОВЕДЕНИЕ ]

-- =================================================================================

local function MoveUnit(unit, targetPos, dt)

    local human = unit:FindFirstChildOfClass("Humanoid")

    local primary = unit.PrimaryPart

    local dustEmitter = primary:FindFirstChild("FootDust")

    if not human or not primary then return end

    

    local distance = (primary.Position - targetPos).magnitude

    

    local sound = primary:FindFirstChildOfClass("Sound")

    if sound then

        if distance > 2 and human.MoveDirection.magnitude > 0.1 then

            if not sound.Playing then sound:Play() end

            if dustEmitter then dustEmitter:Emit(2) end -- Партиклы

        else

            sound:Stop()

        end

    end

    if distance > 2 then

        human:MoveTo(targetPos)

        local direction = (targetPos - primary.Position).unit

        local targetCFrame = CFrame.new(primary.Position, primary.Position + direction)

        unit:SetPrimaryPartCFrame(primary.CFrame:Lerp(targetCFrame, 0.15))

    else

        human:MoveTo(primary.Position)

    end

end

local function HandleSmartIdle(unit, dt)

    local unitRoot = unit:FindFirstChild("HumanoidRootPart")

    local unitHuman = unit:FindFirstChildOfClass("Humanoid")

    local idleAnimTrack = unit:GetAttribute("IdleCheckAnim")

    

    if not unitRoot or not unitHuman or unitHuman.MoveDirection.magnitude > 0.1 then 

        unit:SetAttribute("LastIdleTime", tick()) 

        return 

    end

    

    local lastIdleTime = unit:GetAttribute("LastIdleTime") or tick()

    

    if (tick() - lastIdleTime) > CONFIG.IdleCheckInterval then

        unit:SetAttribute("LastIdleTime", tick()) 

        

        if math.random() < CONFIG.IdleCheckChance then

            if idleAnimTrack and not idleAnimTrack.IsPlaying then

                idleAnimTrack:Play()

                task.wait(idleAnimTrack.Length)

            end

        elseif math.random() < CONFIG.IdleCheckChance then

            unitRoot.CFrame = unitRoot.CFrame * CFrame.Angles(0, math.rad(math.random(-90, 90)), 0)

        end

    end

end

-- =================================================================================

--                              [ 4. ЦИКЛ ОБНОВЛЕНИЯ (Heartbeat) ]

-- =================================================================================

RunService.Heartbeat:Connect(function(dt)

    local char = LocalPlayer.Character

    if not char or not char.Parent then return end

    

    local playerPos = char.PrimaryPart.Position

    local charHumanoid = char:FindFirstChildOfClass("Humanoid")

    

    local isFiringJump = charHumanoid and charHumanoid.Jump and CONFIG.AttackTarget and (not TargetingMode)

    for i, unit in ipairs(Squad) do

        local unitHuman = unit:FindFirstChildOfClass("Humanoid")

        local unitRoot = unit:FindFirstChild("HumanoidRootPart")

        if not unitHuman or not unitRoot then continue end

        

        local unitState = unit:GetAttribute("CurrentState")

        local unitAimTrack = unit:GetAttribute("AimAnimTrack")

        

        if unitState == "AttackStance" and CONFIG.AttackTarget then

            -- РЕЖИМ АТАКИ

            if isFiringJump then

                FireAtTarget(unit, CONFIG.AttackTarget)

                unit:SetAttribute("CurrentState", "Follow")

                unitAimTrack:Stop()

            else

                local targetDirection = (CONFIG.AttackTarget - unitRoot.Position).unit 

                local rightVector = Vector3.new(targetDirection.Z, 0, -targetDirection.X).unit

                local lineCenter = CONFIG.AttackTarget - targetDirection * CONFIG.AttackFormationDepth

                local positionInLine = i - (CONFIG.MaxSquadSize + 1) / 2

                local targetPos = lineCenter + rightVector * (positionInLine * CONFIG.AttackFormationWidth)

                

                MoveUnit(unit, targetPos, dt) 

                

                local lookVector = (CONFIG.AttackTarget - unitRoot.Position).unit

                local targetCFrame = CFrame.new(unitRoot.Position, unitRoot.Position + lookVector)

                unitRoot.CFrame = unitRoot.CFrame:Lerp(targetCFrame, 0.2)

                

                if not unitAimTrack.IsPlaying then unitAimTrack:Play() end

            end

        

        elseif CONFIG.PatrolRadius > 0 then

            -- РЕЖИМ ПАТРУЛЯ

            if unitAimTrack and unitAimTrack.IsPlaying then unitAimTrack:Stop() end

            local now = tick(); local lastChangeTime = LastStateChange[unit.Name] or 0

            

            -- Логика смены состояний

            if now - lastChangeTime > 5 and math.random() < 0.05 and unitState ~= "Sit" then 

                local newState = (math.random() < 0.2 and "Sit") or (math.random() < 0.5 and "Alert") or "Walk"

                unit:SetAttribute("CurrentState", newState); LastStateChange[unit.Name] = now

            end

            

            if unitState == "Sit" then unitHuman.Sit = true; 

            elseif unitState == "Alert" then unitHuman.Sit = false;

            elseif unitState == "Walk" or unitState == "Follow" then

                unitHuman.Sit = false

                if (PatrolPoint - unitRoot.Position).magnitude < 2 or (now - lastChangeTime > 60) then

                    PatrolPoint = GetRandomPatrolPoint() or unitRoot.Position

                end

                MoveUnit(unit, PatrolPoint, dt)

            end

        else

            -- РЕЖИМ СЛЕДОВАНИЯ / СТРОЯ

            if unitAimTrack and unitAimTrack.IsPlaying then unitAimTrack:Stop() end

            

            local direction = char.PrimaryPart.CFrame.lookVector

            local targetPos = Vector3.new()

            

            if CurrentFormation == "Follow" or CurrentFormation == "Line" then

                local row = math.ceil(i / 3); local col = (i - 1) % 3 + 1

                local offsetX = (col - 2) * CONFIG.Spacing

                local offsetZ = (row - 1) * CONFIG.FollowOffset + CONFIG.FollowOffset

                local baseTarget = playerPos - direction * offsetZ + char.PrimaryPart.CFrame.rightVector * offsetX

                

                if CurrentFormation == "Follow" then

                    if not TargetPositions[unit.Name] then TargetPositions[unit.Name] = baseTarget end

                    local lerpFactor = math.min(1, (1 - CONFIG.FollowDelayFactor) * dt * 5)

                    TargetPositions[unit.Name] = TargetPositions[unit.Name]:Lerp(baseTarget, lerpFactor)

                    targetPos = TargetPositions[unit.Name]

                else

                    targetPos = baseTarget

                end

            elseif CurrentFormation == "Iline" or CurrentFormation == "Gtap" then

                if not TargetPositions[unit.Name] then TargetPositions[unit.Name] = unitRoot.Position end

                targetPos = TargetPositions[unit.Name]

            end

            

            MoveUnit(unit, targetPos, dt)

            

            if unitState == "Follow" or unitState == "Line" then

                HandleSmartIdle(unit, dt) 

            end

            unit:SetAttribute("CurrentState", CurrentFormation)

        end

    end

    

    if isFiringJump then

        CONFIG.AttackTarget = nil

        charHumanoid.Jump = false

        PlayResponseSound("Target neutralized. Returning to Follow.")

    end

end)

-- =================================================================================

--                              [ 5. ОБРАБОТКА КОМАНД ]

-- =================================================================================

local function EnterTargetingMode(targetState)

    TargetingMode = true

    PlayResponseSound("Acknowledged. Targeting mode activated.")

    local connection

    connection = Mouse.Button1Down:Connect(function()

        if Mouse.Hit.p and TargetingMode then

            TargetingMode = false

            CurrentFormation = "AttackStance"

            CONFIG.AttackTarget = Mouse.Hit.p

            

            for _, unit in ipairs(Squad) do unit:SetAttribute("CurrentState", "AttackStance") end

            PlayResponseSound("Target acquired. Taking stance. JUMP for FIRE!")

            connection:Disconnect()

        end

    end)

end

local function ExecuteUnitJump(unitName)

    local unit = nil

    for _, u in ipairs(Squad) do

        if u.Name:lower() == unitName:lower() then unit = u; break end

    end

    

    if unit and unit:FindFirstChild("HumanoidRootPart") then

        unit:FindFirstChild("HumanoidRootPart"):ApplyImpulse(Vector3.new(0, CONFIG.JumpForce, 0) * unit:FindFirstChild("HumanoidRootPart").Mass)

        PlayResponseSound(unitName .. " jumping!")

    end

end

LocalPlayer.Chatted:Connect(function(msg)

    local args = msg:split(" ")

    if args[1]:lower() ~= ".soldier" then return end

    

    local command = args[2]:lower()

    

    if command == "spawn" then SpawnSquad()

    elseif command == "kill" or command == "despawn" then

        for _, unit in ipairs(Squad) do unit:Destroy() end

        Squad = {}; TargetingMode = false; CONFIG.AttackTarget = nil; CurrentFormation = "Follow"

        PlayResponseSound("Disengaged.")

    

    elseif command == "follow" then CurrentFormation = "Follow"; CONFIG.PatrolRadius = 0; PlayResponseSound("Aye Sir! Returning to formation.")

    elseif command == "line" then CurrentFormation = "Line"; CONFIG.PatrolRadius = 0; PlayResponseSound("Line formation!")

    elseif command == "iline" then CurrentFormation = "Iline"; CONFIG.PatrolRadius = 0; TargetPositions = {}; PlayResponseSound("I-Line, hold position!")

    

    elseif command == "attack" then EnterTargetingMode("AttackStance")

    elseif command == "center" then

        local ray = Ray.new(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000)

        local hit, pos = Workspace:FindPartOnRay(ray)

        if pos then CONFIG.PatrolCenter = pos; PlayResponseSound("Patrol Center set.") end

    elseif command == "patrol" then

        local radius = tonumber(args[3])

        if CONFIG.PatrolCenter and radius and radius >= 5 and radius <= 100 then

            CONFIG.PatrolRadius = radius; CurrentFormation = "Patrol"; 

            PlayResponseSound("Patrolling area, radius: " .. radius .. " studs.")

        else PlayResponseSound("Error: Need valid radius 5-100 or center.") end

        

    elseif command == "jump" and args[3] then ExecuteUnitJump(args[3])

    elseif command == "gtap" then CurrentFormation = "Gtap"; TargetPositions = {}; PlayResponseSound("G-Tap activated. Click for position.")

    

    elseif command == "help" then

        PlayResponseSound("Commands: spawn, kill, follow, line, iline, attack, center, patrol [radius], jump [name], gtap")

    end

end)

-- Обработка клика для G-Tap

UIS.InputBegan:Connect(function(input, gameProcessedEvent)

    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not gameProcessedEvent and CurrentFormation == "Gtap" then

        local ray = Ray.new(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000)

        local hit, pos = Workspace:FindPartOnRay(ray)

        if pos then

            local index = 1

            for _, unit in ipairs(Squad) do

                local row = math.ceil(index / 3); local col = (index - 1) % 3 + 1

                local offsetX = (col - 2) * CONFIG.Spacing

                local offsetZ = (row - 1) * CONFIG.FollowOffset + CONFIG.FollowOffset

                TargetPositions[unit.Name] = pos + Vector3.new(offsetX, 0, offsetZ) 

                index = index + 1

            end

            PlayResponseSound("G-Tap: Squad positions updated.")

        end

    end

end)

-- Инициализация

local function PreloadAssets()

    local assets = {}

    for _, id in pairs(CONFIG.ASSET_IDS) do

        if type(id) == "string" and id:sub(1, 12) == "rbxassetid:/" then table.insert(assets, id)

        elseif type(id) == "string" and IsAssetId(id) then table.insert(assets, "rbxassetid://" .. id)

        end

    end

    table.insert(assets, CONFIG.FOOTSTEP_SOUND_ID)

    game:GetService("ContentProvider"):PreloadAsync(assets)

end

PreloadAssets()

--[ LOCAL COMBAT SQUAD SCRIPT (R15) V7.0 - ВСЕ ФУНКЦИИ ]--

-- Включает: 9 Юнитов, Партиклы, Автономный AI, Голосовые Отклики и Все Тактические Команды.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Workspace = game:GetService("Workspace")

local RunService = game:GetService("RunService")

local ContentProvider = game:GetService("ContentProvider")

local Debris = game:GetService("Debris")

local UIS = game:GetService("UserInputService")

-- =================================================================================

--                              [ 1. КОНФИГУРАЦИЯ АССЕТОВ И ПАРАМЕТРОВ ]

-- =================================================================================

local CONFIG = {

    SquadNames = {"Victor", "Ethan", "Grant", "Alex", "Marcus", "Owen", "Leo", "Caleb", "Ryan"}, 

    MaxSquadSize = 9, 

    

    ASSET_IDS = {

        -- Экипировка и Анимации (рабочие ID)

        Shirt = "rbxassetid://10287910007",   

        Pants = "rbxassetid://10287914480",   

        Helmet = "rbxassetid://6552796191",   

        WeaponBack = "rbxassetid://6661904712", 

        WalkAnimationId = 9482705178, 

        JumpAnimationId = "rbxassetid://507646549", 

        AimAnimationId = "rbxassetid://899026410", 

        -- Звуки и Партиклы

        RESPONSE_SOUND_ID = "rbxassetid://135308704",   -- "Roger That"

        GunshotSoundId = "rbxassetid://2811598570",     -- Звук выстрела

        MuzzleFlashTexture = "rbxassetid://6273181881", -- Вспышка

        DustParticleTexture = "rbxassetid://6273183594",-- Пыль/След шага

    },

    FOOTSTEP_SOUND_ID = "rbxassetid://479709292", 

    

    -- Параметры Поведения и Строя

    Spacing = 3, FollowOffset = 6, 

    FollowDelayFactor = 0.95, JumpForce = 50, 

    AttackFormationDepth = 15, AttackFormationWidth = 3,  

    -- Параметры Патруля и AI

    PatrolCenter = nil, PatrolRadius = 0,   

    IdleCheckInterval = 5, IdleCheckChance = 0.1, -- 10% шанс на действие раз в 5 сек

}

local Squad = {}

local Mouse = LocalPlayer:GetMouse()

local TargetingMode = false 

local LastStateChange = {} 

local TargetPositions = {} 

local CurrentFormation = "Follow"

local PatrolPoint = Vector3.new()

local CONFIG.AttackTarget = nil

-- =================================================================================

--                              [ 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ]

-- =================================================================================

local function IsAssetId(id)

    return tonumber(id) ~= nil and id ~= ""

end

local function PlayResponseSound(message)

    local sound = Instance.new("Sound")

    sound.SoundId = CONFIG.ASSET_IDS.RESPONSE_SOUND_ID

    sound.Volume = 1

    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then

        sound.Parent = LocalPlayer.Character.PrimaryPart

    end

    sound:Play()

    Debris:AddItem(sound, 2)

    LocalPlayer:SetAttribute("ChatCommandFeedback", "Squad: " .. message)

end

local function GetRandomPatrolPoint()

    if not CONFIG.PatrolCenter or CONFIG.PatrolRadius == 0 then return nil end

    local x = CONFIG.PatrolCenter.X + math.random(-CONFIG.PatrolRadius, CONFIG.PatrolRadius)

    local z = CONFIG.PatrolCenter.Z + math.random(-CONFIG.PatrolRadius, CONFIG.PatrolRadius)

    local ray = Ray.new(Vector3.new(x, 1000, z), Vector3.new(0, -2000, 0))

    local hit, pos = Workspace:FindPartOnRay(ray, nil, false, true)

    return pos

end

local function FireAtTarget(unit, targetPos)

    local root = unit:FindFirstChild("HumanoidRootPart")

    local muzzleFlashEmitter = root:FindFirstChild("MuzzleFlash")

    if not root or not muzzleFlashEmitter then return end

    

    -- 1. Звук Выстрела

    local sound = Instance.new("Sound")

    sound.SoundId = CONFIG.ASSET_IDS.GunshotSoundId

    sound.Volume = 0.8; sound.Parent = root

    sound:Play(); Debris:AddItem(sound, 1) 

    

    -- 2. Визуальный Эффект (Луч - трассер)

    local distance = (targetPos - root.Position).magnitude

    local lookVector = (targetPos - root.Position).unit

    

    local laser = Instance.new("Part")

    laser.Anchored = true; laser.CanCollide = false; laser.Color = Color3.new(1, 0.8, 0.2); laser.Material = Enum.Material.Neon

    laser.Size = Vector3.new(0.1, 0.1, distance)

    laser.CFrame = CFrame.new(root.Position, targetPos) * CFrame.new(0, 0, -distance / 2)

    laser.Parent = Workspace

    Debris:AddItem(laser, 0.05) 

    -- 3. Партиклы Выстрела (Вспышка и Дым)

    local muzzlePos = root.CFrame * CFrame.new(1.5, 0, -2) -- Позиция "дула" (передний правый край)

    muzzleFlashEmitter.CFrame = CFrame.new(muzzlePos.Position, muzzlePos.Position + lookVector)

    muzzleFlashEmitter:Emit(5) 

    

    local smoke = Instance.new("Smoke")

    smoke.Color = Color3.new(0.2, 0.2, 0.2); smoke.Size = 0.5; smoke.RiseVelocity = 1

    smoke.Parent = laser 

    Debris:AddItem(smoke, 0.5) 

end

-- Создание партиклов для юнита

local function CreateUnitParticles(unit)

    local root = unit:FindFirstChild("HumanoidRootPart")

    if not root then return end

    -- 1. Партиклы Ходьбы (Dust/Mud)

    local dustEmitter = Instance.new("ParticleEmitter")

    dustEmitter.Name = "FootDust"

    dustEmitter.Texture = CONFIG.ASSET_IDS.DustParticleTexture

    dustEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.5)})

    dustEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})

    dustEmitter.Lifetime = 0.5; dustEmitter.Rate = 0; dustEmitter.EmissionDirection = Enum.ParticleEmissionDirection.Top

    dustEmitter.Parent = root

    

    -- 2. Партиклы Выстрела (Muzzle Flash)

    local muzzleFlashEmitter = Instance.new("ParticleEmitter")

    muzzleFlashEmitter.Name = "MuzzleFlash"

    muzzleFlashEmitter.Texture = CONFIG.ASSET_IDS.MuzzleFlashTexture

    muzzleFlashEmitter.Size = NumberSequence.new(0.5, 1)

    muzzleFlashEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.05, 0), NumberSequenceKeypoint.new(1, 1)})

    muzzleFlashEmitter.Color = ColorSequence.new(Color3.new(1, 1, 0), Color3.new(1, 0.5, 0))

    muzzleFlashEmitter.Lifetime = 0.1; muzzleFlashEmitter.Rate = 0; muzzleFlashEmitter.LightEmission = 1

    muzzleFlashEmitter.Acceleration = Vector3.new(0, 0, -2)

    muzzleFlashEmitter.Parent = root 

end

local function SetupUnit(unit, name)

    unit.Name = name

    unit:SetAttribute("CurrentState", "Follow")

    unit:SetAttribute("LastIdleTime", tick())

    

    local human = unit:FindFirstChildOfClass("Humanoid")

    if not human then return unit end

    

    -- Создание партиклов

    CreateUnitParticles(unit) 

    

    human.RigType = Enum.HumanoidRigType.R15

    local animator = human:FindFirstChildOfClass("Animator") or Instance.new("Animator", human)

    local aimAnim = Instance.new("Animation"); aimAnim.AnimationId = CONFIG.ASSET_IDS.AimAnimationId

    unit:SetAttribute("AimAnimTrack", animator:LoadAnimation(aimAnim))

    

    local idleAnim = Instance.new("Animation"); idleAnim.AnimationId = CONFIG.ASSET_IDS.JumpAnimationId -- Заглушка

    unit:SetAttribute("IdleCheckAnim", animator:LoadAnimation(idleAnim))

    

    local sound = Instance.new("Sound"); sound.SoundId = CONFIG.FOOTSTEP_SOUND_ID; sound.Volume = 0.5; sound.Parent = unit.PrimaryPart 

    

    local appearance = Instance.new("HumanoidDescription")

    appearance.Shirt = IsAssetId(CONFIG.ASSET_IDS.Shirt) and tonumber(CONFIG.ASSET_IDS.Shirt) or 0

    appearance.Pants = IsAssetId(CONFIG.ASSET_IDS.Pants) and tonumber(CONFIG.ASSET_IDS.Pants) or 0

    

    local accessories = {}

    if IsAssetId(CONFIG.ASSET_IDS.Helmet) then table.insert(accessories, tonumber(CONFIG.ASSET_IDS.Helmet)) end

    if IsAssetId(CONFIG.ASSET_IDS.WeaponBack) then table.insert(accessories, tonumber(CONFIG.ASSET_IDS.WeaponBack)) end

    appearance:SetAccessories(accessories)

    human:ApplyDescription(appearance)

    local animateScript = unit:FindFirstChild("Animate")

    if animateScript then

        local walkState = animateScript:FindFirstChild("walk"):FindFirstChild("WalkAnim")

        local jumpState = animateScript:FindFirstChild("jump"):FindFirstChild("JumpAnim")

        if walkState and CONFIG.ASSET_IDS.WalkAnimationId ~= "" then walkState.AnimationId = CONFIG.ASSET_IDS.WalkAnimationId end

        if jumpState and CONFIG.ASSET_IDS.JumpAnimationId ~= "" then jumpState.AnimationId = CONFIG.ASSET_IDS.JumpAnimationId end

    end

    

    return unit

end

local function SpawnSquad()

    if not LocalPlayer.Character or not LocalPlayer.Character.Parent then return end

    

    for _, unit in ipairs(Squad) do unit:Destroy() end

    Squad = {}

    

    for i = 1, CONFIG.MaxSquadSize do

        local name = CONFIG.SquadNames[i]

        local unit = LocalPlayer.Character:Clone()

        unit.PrimaryPart.CFrame = LocalPlayer.Character.PrimaryPart.CFrame * CFrame.new(math.random(-5, 5), 5, math.random(-5, 5))

        unit.Parent = Workspace

        unit = SetupUnit(unit, name)

        Squad[i] = unit

    end

    CurrentFormation = "Follow"

    PlayResponseSound(string.format("Squad of %d units, ready!", CONFIG.MaxSquadSize))

end

-- =================================================================================

--                              [ 3. ЛОГИКА ДВИЖЕНИЯ И АВТОНОМНОЕ ПОВЕДЕНИЕ ]

-- =================================================================================

local function MoveUnit(unit, targetPos, dt)

    local human = unit:FindFirstChildOfClass("Humanoid")

    local primary = unit.PrimaryPart

    local dustEmitter = primary:FindFirstChild("FootDust")

    if not human or not primary then return end

    

    local distance = (primary.Position - targetPos).magnitude

    

    local sound = primary:FindFirstChildOfClass("Sound")

    if sound then

        if distance > 2 and human.MoveDirection.magnitude > 0.1 then

            if not sound.Playing then sound:Play() end

            if dustEmitter then dustEmitter:Emit(2) end -- Партиклы

        else

            sound:Stop()

        end

    end

    if distance > 2 then

        human:MoveTo(targetPos)

        local direction = (targetPos - primary.Position).unit

        local targetCFrame = CFrame.new(primary.Position, primary.Position + direction)

        unit:SetPrimaryPartCFrame(primary.CFrame:Lerp(targetCFrame, 0.15))

    else

        human:MoveTo(primary.Position)

    end

end

local function HandleSmartIdle(unit, dt)

    local unitRoot = unit:FindFirstChild("HumanoidRootPart")

    local unitHuman = unit:FindFirstChildOfClass("Humanoid")

    local idleAnimTrack = unit:GetAttribute("IdleCheckAnim")

    

    if not unitRoot or not unitHuman or unitHuman.MoveDirection.magnitude > 0.1 then 

        unit:SetAttribute("LastIdleTime", tick()) 

        return 

    end

    

    local lastIdleTime = unit:GetAttribute("LastIdleTime") or tick()

    

    if (tick() - lastIdleTime) > CONFIG.IdleCheckInterval then

        unit:SetAttribute("LastIdleTime", tick()) 

        

        if math.random() < CONFIG.IdleCheckChance then

            if idleAnimTrack and not idleAnimTrack.IsPlaying then

                idleAnimTrack:Play()

                task.wait(idleAnimTrack.Length)

            end

        elseif math.random() < CONFIG.IdleCheckChance then

            unitRoot.CFrame = unitRoot.CFrame * CFrame.Angles(0, math.rad(math.random(-90, 90)), 0)

        end

    end

end

-- =================================================================================

--                              [ 4. ЦИКЛ ОБНОВЛЕНИЯ (Heartbeat) ]

-- =================================================================================

RunService.Heartbeat:Connect(function(dt)

    local char = LocalPlayer.Character

    if not char or not char.Parent then return end

    

    local playerPos = char.PrimaryPart.Position

    local charHumanoid = char:FindFirstChildOfClass("Humanoid")

    

    local isFiringJump = charHumanoid and charHumanoid.Jump and CONFIG.AttackTarget and (not TargetingMode)

    for i, unit in ipairs(Squad) do

        local unitHuman = unit:FindFirstChildOfClass("Humanoid")

        local unitRoot = unit:FindFirstChild("HumanoidRootPart")

        if not unitHuman or not unitRoot then continue end

        

        local unitState = unit:GetAttribute("CurrentState")

        local unitAimTrack = unit:GetAttribute("AimAnimTrack")

        

        if unitState == "AttackStance" and CONFIG.AttackTarget then

            -- РЕЖИМ АТАКИ

            if isFiringJump then

                FireAtTarget(unit, CONFIG.AttackTarget)

                unit:SetAttribute("CurrentState", "Follow")

                unitAimTrack:Stop()

            else

                local targetDirection = (CONFIG.AttackTarget - unitRoot.Position).unit 

                local rightVector = Vector3.new(targetDirection.Z, 0, -targetDirection.X).unit

                local lineCenter = CONFIG.AttackTarget - targetDirection * CONFIG.AttackFormationDepth

                local positionInLine = i - (CONFIG.MaxSquadSize + 1) / 2

                local targetPos = lineCenter + rightVector * (positionInLine * CONFIG.AttackFormationWidth)

                

                MoveUnit(unit, targetPos, dt) 

                

                local lookVector = (CONFIG.AttackTarget - unitRoot.Position).unit

                local targetCFrame = CFrame.new(unitRoot.Position, unitRoot.Position + lookVector)

                unitRoot.CFrame = unitRoot.CFrame:Lerp(targetCFrame, 0.2)

                

                if not unitAimTrack.IsPlaying then unitAimTrack:Play() end

            end

        

        elseif CONFIG.PatrolRadius > 0 then

            -- РЕЖИМ ПАТРУЛЯ

            if unitAimTrack and unitAimTrack.IsPlaying then unitAimTrack:Stop() end

            local now = tick(); local lastChangeTime = LastStateChange[unit.Name] or 0

            

            -- Логика смены состояний

            if now - lastChangeTime > 5 and math.random() < 0.05 and unitState ~= "Sit" then 

                local newState = (math.random() < 0.2 and "Sit") or (math.random() < 0.5 and "Alert") or "Walk"

                unit:SetAttribute("CurrentState", newState); LastStateChange[unit.Name] = now

            end

            

            if unitState == "Sit" then unitHuman.Sit = true; 

            elseif unitState == "Alert" then unitHuman.Sit = false;

            elseif unitState == "Walk" or unitState == "Follow" then

                unitHuman.Sit = false

                if (PatrolPoint - unitRoot.Position).magnitude < 2 or (now - lastChangeTime > 60) then

                    PatrolPoint = GetRandomPatrolPoint() or unitRoot.Position

                end

                MoveUnit(unit, PatrolPoint, dt)

            end

        else

            -- РЕЖИМ СЛЕДОВАНИЯ / СТРОЯ

            if unitAimTrack and unitAimTrack.IsPlaying then unitAimTrack:Stop() end

            

            local direction = char.PrimaryPart.CFrame.lookVector

            local targetPos = Vector3.new()

            

            if CurrentFormation == "Follow" or CurrentFormation == "Line" then

                local row = math.ceil(i / 3); local col = (i - 1) % 3 + 1

                local offsetX = (col - 2) * CONFIG.Spacing

                local offsetZ = (row - 1) * CONFIG.FollowOffset + CONFIG.FollowOffset

                local baseTarget = playerPos - direction * offsetZ + char.PrimaryPart.CFrame.rightVector * offsetX

                

                if CurrentFormation == "Follow" then

                    if not TargetPositions[unit.Name] then TargetPositions[unit.Name] = baseTarget end

                    local lerpFactor = math.min(1, (1 - CONFIG.FollowDelayFactor) * dt * 5)

                    TargetPositions[unit.Name] = TargetPositions[unit.Name]:Lerp(baseTarget, lerpFactor)

                    targetPos = TargetPositions[unit.Name]

                else

                    targetPos = baseTarget

                end

            elseif CurrentFormation == "Iline" or CurrentFormation == "Gtap" then

                if not TargetPositions[unit.Name] then TargetPositions[unit.Name] = unitRoot.Position end

                targetPos = TargetPositions[unit.Name]

            end

            

            MoveUnit(unit, targetPos, dt)

            

            if unitState == "Follow" or unitState == "Line" then

                HandleSmartIdle(unit, dt) 

            end

            unit:SetAttribute("CurrentState", CurrentFormation)

        end

    end

    

    if isFiringJump then

        CONFIG.AttackTarget = nil

        charHumanoid.Jump = false

        PlayResponseSound("Target neutralized. Returning to Follow.")

    end

end)

-- =================================================================================

--                              [ 5. ОБРАБОТКА КОМАНД ]

-- =================================================================================

local function EnterTargetingMode(targetState)

    TargetingMode = true

    PlayResponseSound("Acknowledged. Targeting mode activated.")

    local connection

    connection = Mouse.Button1Down:Connect(function()

        if Mouse.Hit.p and TargetingMode then

            TargetingMode = false

            CurrentFormation = "AttackStance"

            CONFIG.AttackTarget = Mouse.Hit.p

            

            for _, unit in ipairs(Squad) do unit:SetAttribute("CurrentState", "AttackStance") end

            PlayResponseSound("Target acquired. Taking stance. JUMP for FIRE!")

            connection:Disconnect()

        end

    end)

end

local function ExecuteUnitJump(unitName)

    local unit = nil

    for _, u in ipairs(Squad) do

        if u.Name:lower() == unitName:lower() then unit = u; break end

    end

    

    if unit and unit:FindFirstChild("HumanoidRootPart") then

        unit:FindFirstChild("HumanoidRootPart"):ApplyImpulse(Vector3.new(0, CONFIG.JumpForce, 0) * unit:FindFirstChild("HumanoidRootPart").Mass)

        PlayResponseSound(unitName .. " jumping!")

    end

end

LocalPlayer.Chatted:Connect(function(msg)

    local args = msg:split(" ")

    if args[1]:lower() ~= ".soldier" then return end

    

    local command = args[2]:lower()

    

    if command == "spawn" then SpawnSquad()

    elseif command == "kill" or command == "despawn" then

        for _, unit in ipairs(Squad) do unit:Destroy() end

        Squad = {}; TargetingMode = false; CONFIG.AttackTarget = nil; CurrentFormation = "Follow"

        PlayResponseSound("Disengaged.")

    

    elseif command == "follow" then CurrentFormation = "Follow"; CONFIG.PatrolRadius = 0; PlayResponseSound("Aye Sir! Returning to formation.")

    elseif command == "line" then CurrentFormation = "Line"; CONFIG.PatrolRadius = 0; PlayResponseSound("Line formation!")

    elseif command == "iline" then CurrentFormation = "Iline"; CONFIG.PatrolRadius = 0; TargetPositions = {}; PlayResponseSound("I-Line, hold position!")

    

    elseif command == "attack" then EnterTargetingMode("AttackStance")

    elseif command == "center" then

        local ray = Ray.new(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000)

        local hit, pos = Workspace:FindPartOnRay(ray)

        if pos then CONFIG.PatrolCenter = pos; PlayResponseSound("Patrol Center set.") end

    elseif command == "patrol" then

        local radius = tonumber(args[3])

        if CONFIG.PatrolCenter and radius and radius >= 5 and radius <= 100 then

            CONFIG.PatrolRadius = radius; CurrentFormation = "Patrol"; 

            PlayResponseSound("Patrolling area, radius: " .. radius .. " studs.")

        else PlayResponseSound("Error: Need valid radius 5-100 or center.") end

        

    elseif command == "jump" and args[3] then ExecuteUnitJump(args[3])

    elseif command == "gtap" then CurrentFormation = "Gtap"; TargetPositions = {}; PlayResponseSound("G-Tap activated. Click for position.")

    

    elseif command == "help" then

        PlayResponseSound("Commands: spawn, kill, follow, line, iline, attack, center, patrol [radius], jump [name], gtap")

    end

end)

-- Обработка клика для G-Tap

UIS.InputBegan:Connect(function(input, gameProcessedEvent)

    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not gameProcessedEvent and CurrentFormation == "Gtap" then

        local ray = Ray.new(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000)

        local hit, pos = Workspace:FindPartOnRay(ray)

        if pos then

            local index = 1

            for _, unit in ipairs(Squad) do

                local row = math.ceil(index / 3); local col = (index - 1) % 3 + 1

                local offsetX = (col - 2) * CONFIG.Spacing

                local offsetZ = (row - 1) * CONFIG.FollowOffset + CONFIG.FollowOffset

                TargetPositions[unit.Name] = pos + Vector3.new(offsetX, 0, offsetZ) 

                index = index + 1

            end

            PlayResponseSound("G-Tap: Squad positions updated.")

        end

    end

end)

-- Инициализация

local function PreloadAssets()

    local assets = {}

    for _, id in pairs(CONFIG.ASSET_IDS) do

        if type(id) == "string" and id:sub(1, 12) == "rbxassetid:/" then table.insert(assets, id)

        elseif type(id) == "string" and IsAssetId(id) then table.insert(assets, "rbxassetid://" .. id)

        end

    end

    table.insert(assets, CONFIG.FOOTSTEP_SOUND_ID)

    game:GetService("ContentProvider"):PreloadAsync(assets)

end

PreloadAssets()
