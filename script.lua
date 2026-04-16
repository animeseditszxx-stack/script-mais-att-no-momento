--[[
    Arsenal Script By Toddyx
    Version: 4.1 FIXED + HYPERSHOT
]]

-- ========================
-- CORE SERVICES
-- ========================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Cam = game.Workspace.CurrentCamera
local LP = Players.LocalPlayer
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ========================
-- CONFIG MANAGER
-- ========================
local C = {
    Aim = {
        Enabled = false, FOV = 100, Smooth = 0.1, Bone = "Head",
        Prediction = false, VisibleCheck = false,
        Keybind = Enum.UserInputType.MouseButton2,
        TargetLock = false, TargetLockKey = Enum.KeyCode.E,
        Priority = "Closest to Crosshair", AntiSwitch = true,
        AntiSwitchTime = 1.5, DynamicSmooth = false,
        AimDelay = 0, RandomOffset = 0, HitChance = 100,
        ClutchMode = false, ClutchHP = 30,
        ReactionMin = 50, ReactionMax = 150,
        Humanizer = false, TremorStrength = 0.2,
        MultiBoneScan = false,
    },
    ESP = {
        Enabled = false, Boxes = false, Tracers = false,
        Names = false, Skeleton = false, HealthBar = false,
        Distance = false, Offscreen = false, Chams = false,
        VisibleOnly = false, FadeDistance = false,
        PriorityHighlight = false, PriorityRange = 30,
        TeamCheck = true, Color = Color3.fromRGB(255,0,0),
        SkeletonColor = Color3.fromRGB(255,255,255),
        KeyToggle = false, Visible = true,
        TrailESP = false, LastPosition = false,
        DangerZone = false, GradientHP = false,
    },
    Player = {
        WalkSpeed = 16, WSEnabled = false,
        JumpPower = 50, JPEnabled = false,
        FlyEnabled = false, FlySpeed = 50,
        Noclip = false, AntiRagdoll = false,
        AntiFall = false, BunnyHop = false,
        Strafe = false, VelocityControl = false,
        VelocityAmount = 1.0, AntiLock = false,
        QuickStop = false,
    },
    Combat = {
        Hitbox = false, HitboxTeamCheck = true,
        NoRecoil = false, NoSpread = false,
        HitSound = false, Hitmarker = false,
    },
    Hypershot = {
        Hitbox = false, HitboxSize = 15,
        HitboxTeamCheck = true,
        NoRecoil = false, NoSpread = false,
        InfAmmo = false,
        BunnyHop = false,
        WalkSpeed = false, WalkSpeedValue = 16,
        JumpPower = false, JumpPowerValue = 50,
        AimbotEnabled = false, AimbotFOV = 120,
        AimbotSmooth = 0.1, AimbotBone = "Head",
        AimbotPrediction = false, AimbotVisible = false,
        AimbotKeybind = Enum.UserInputType.MouseButton2,
        ESPEnabled = false, ESPBoxes = false,
        ESPNames = false, ESPTracers = false,
        ESPSkeleton = false, ESPHealthBar = false,
        ESPTeamCheck = true,
        ESPColor = Color3.fromRGB(0, 200, 255),
        FullBright = false,
        FPSBoost = false,
        Fly = false, FlySpeed = 50,
        AntiRagdoll = false, AntiFall = false,
        Noclip = false,
        HitSound = false, Hitmarker = false,
    },
    Performance = {
        FPSBoost = false, AdaptiveFPS = false,
        FPSLimit = 0,
    },
    Misc = {
        AntiAFK = false, DebugMode = false,
        KeybindOverlay = false, SpectatorDetection = false,
        EnemyWarning = false, EnemyWarningRange = 50,
        StreamMode = false, StreamKey = Enum.KeyCode.F8,
        PanicKey = Enum.KeyCode.F9,
        RiskSystem = false, FakeLegit = false,
        AntiSpectator = false,
    },
    Mode = "Legit",
}

-- ========================
-- STATE
-- ========================
local State = {
    currentTarget = nil,
    lastTargetSwitch = 0,
    lockedTarget = nil,
    lockActive = false,
    spectators = {},
    flyConn = nil,
    flyEnabled = false,
    hsyFlyEnabled = false,
    hsyFlyConn = nil,
    mobileAim = false,
    mobileFlyUp = false,
    mobileFlyDown = false,
    dashCD = false,
    tpConn = nil,
    tpEnabled = false,
    threatTable = {},
    lastSeenPos = {},
    removedEffects = {},
    originalSizes = {},
    hsyOriginalSizes = {},
    devAccess = false,
    streamMode = false,
    clutchActive = false,
    fps = 60,
    ping = 0,
    behaviorSeed = math.random(1,9999),
    -- Hypershot aimbot state
    hsyCurrentTarget = nil,
    hsyLastSwitch = 0,
}

-- ========================
-- UTILS
-- ========================
local Utils = {}

function Utils.isEnemy(p)
    if not p or not p.Character then return false end
    if p.Team == nil or LP.Team == nil then return true end
    return p.Team ~= LP.Team
end

function Utils.isVisible(p)
    if not p or not p.Character then return false end
    local head = p.Character:FindFirstChild("Head")
    if not head then return false end
    local origin = Cam.CFrame.Position
    local direction = (head.Position - origin).Unit * 999
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LP.Character, Cam})
    return hit and hit:IsDescendantOf(p.Character)
end

function Utils.getDistance(p)
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if myHRP and hrp then return (hrp.Position - myHRP.Position).Magnitude end
    return math.huge
end

function Utils.getHP(p)
    local hum = p and p.Character and p.Character:FindFirstChild("Humanoid")
    return hum and hum.Health or math.huge
end

function Utils.getCrosshairDist(p, bone)
    if not p or not p.Character then return math.huge end
    local part = p.Character:FindFirstChild(bone) or p.Character:FindFirstChild("Head")
    if not part then return math.huge end
    local pos, vis = Cam:WorldToViewportPoint(part.Position)
    if not vis then return math.huge end
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    return (Vector2.new(pos.X, pos.Y) - center).Magnitude
end

-- ========================
-- PERFORMANCE MANAGER
-- ========================
local Schedulers = {}
local frameCount = 0
local lastFPSTime = tick()

local function registerScheduler(name, interval, fn)
    Schedulers[name] = {interval = interval, fn = fn, last = 0}
end

local function tickSchedulers()
    local now = tick()
    frameCount = frameCount + 1
    if (now - lastFPSTime) >= 1 then
        State.fps = frameCount
        frameCount = 0
        lastFPSTime = now
        pcall(function()
            State.ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if C.Performance.AdaptiveFPS then
            if State.fps < 40 and not C.Performance.FPSBoost then
                enableFPSBoost()
            elseif State.fps > 80 and C.Performance.FPSBoost then
                disableFPSBoost()
            end
        end
    end
    for name, s in pairs(Schedulers) do
        if (now - s.last) >= s.interval then
            s.last = now
            pcall(s.fn)
        end
    end
end

function enableFPSBoost()
    C.Performance.FPSBoost = true
    for _, obj in pairs(Lighting:GetDescendants()) do
        if obj:IsA("PostEffect") or obj:IsA("Sky") then
            obj.Enabled = false
            table.insert(State.removedEffects, obj)
        end
    end
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or
           obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
            table.insert(State.removedEffects, obj)
        end
    end
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
end

function disableFPSBoost()
    C.Performance.FPSBoost = false
    for _, obj in pairs(State.removedEffects) do
        pcall(function() obj.Enabled = true end)
    end
    State.removedEffects = {}
    Lighting.GlobalShadows = true
end

-- ========================
-- AUDIO MODULE
-- ========================
local sounds = {}
local function createSound(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or 0.5
    s.Parent = workspace
    return s
end
sounds.hit = createSound("rbxassetid://4612378535", 0.7)
sounds.stream = createSound("rbxassetid://3398229412", 0.3)
sounds.clutch = createSound("rbxassetid://1848354536", 0.5)

local function playSound(name)
    if sounds[name] then pcall(function() sounds[name]:Play() end) end
end

-- ========================
-- BRAIN
-- ========================
local Brain = {}

function Brain.getStress()
    local count = 0
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return 0 end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and Utils.isEnemy(p) then
            if Utils.getDistance(p) < 50 then count = count + 1 end
        end
    end
    return math.clamp(count/3, 0, 1)
end

function Brain.isThreat(p)
    return State.threatTable[p.Name] == true
end

function Brain.updateThreats()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp and myHRP then
                local dir = (myHRP.Position - hrp.Position).Unit
                local dot = dir:Dot(hrp.CFrame.LookVector)
                State.threatTable[p.Name] = dot > 0.7 and Utils.getDistance(p) < 100
            end
        end
    end
end

function Brain.getSmooth(target)
    local base = C.Aim.Smooth
    if C.Aim.DynamicSmooth then
        base = base * math.clamp(Utils.getDistance(target)/150, 1, 3)
    end
    base = base + Brain.getStress() * 0.05
    local myHum = LP.Character and LP.Character:FindFirstChild("Humanoid")
    if C.Aim.ClutchMode and myHum and myHum.Health <= C.Aim.ClutchHP then
        base = base * 0.4
        if not State.clutchActive then
            State.clutchActive = true
            playSound("clutch")
        end
    else
        State.clutchActive = false
    end
    if C.Misc.RiskSystem and #State.spectators > 1 then
        base = base * 1.5
    end
    return math.clamp(base, 0.01, 1)
end

function Brain.getHumanOffset()
    if not C.Aim.Humanizer then return Vector3.new(0,0,0) end
    local t = tick()
    local s = State.behaviorSeed
    local str = C.Aim.TremorStrength * (1 + Brain.getStress())
    return Vector3.new(
        math.sin(t*7.3+s)*str,
        math.cos(t*5.1+s)*str,
        math.sin(t*9.7+s)*str*0.5
    )
end

-- ========================
-- AIM MODULE
-- ========================
local BONES_LIST = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
}

local AimModule = {}

function AimModule.getBonePos(char, bone)
    if bone == "Random" then
        local b = {"Head","UpperTorso","LowerTorso"}
        bone = b[math.random(1,#b)]
    end
    local part = char:FindFirstChild(bone) or char:FindFirstChild("UpperTorso")
    return part and part.Position
end

function AimModule.getBestBone(char)
    if not C.Aim.MultiBoneScan then return C.Aim.Bone end
    local best, bestDist = C.Aim.Bone, math.huge
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, b in pairs({"Head","UpperTorso","LowerTorso"}) do
        local part = char:FindFirstChild(b)
        if part then
            local pos, vis = Cam:WorldToViewportPoint(part.Position)
            if vis then
                local d = (Vector2.new(pos.X,pos.Y)-center).Magnitude
                if d < bestDist then bestDist = d best = b end
            end
        end
    end
    return best
end

function AimModule.getPredicted(p, bone)
    if not p.Character then return nil end
    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
    local bonePos = AimModule.getBonePos(p.Character, bone)
    if not hrp or not bonePos then return nil end
    if C.Aim.Prediction then
        local vel = hrp.Velocity
        local dist = (bonePos - Cam.CFrame.Position).Magnitude
        local pingFactor = State.ping / 1000
        local prevData = State.lastSeenPos[p.Name]
        local prevVel = prevData and prevData.vel or vel
        local accel = vel - prevVel
        return bonePos + vel*(dist/600 + pingFactor) + accel*0.1
    end
    return bonePos
end

function AimModule.getTarget()
    if State.lockActive and State.lockedTarget then
        local t = State.lockedTarget
        if t.Character and t.Character:FindFirstChild("Humanoid") and
           t.Character.Humanoid.Health > 0 then return t end
        State.lockedTarget = nil
        State.lockActive = false
    end
    local now = tick()
    if C.Aim.AntiSwitch and State.currentTarget and
       (now - State.lastTargetSwitch) < C.Aim.AntiSwitchTime then
        local t = State.currentTarget
        if t.Character and t.Character:FindFirstChild("Humanoid") and
           t.Character.Humanoid.Health > 0 and
           Utils.getCrosshairDist(t, C.Aim.Bone) <= C.Aim.FOV then
            return t
        end
    end
    local candidates = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and Utils.isEnemy(p) then
            if C.Aim.VisibleCheck and not Utils.isVisible(p) then continue end
            local cd = Utils.getCrosshairDist(p, C.Aim.Bone)
            if cd <= C.Aim.FOV then
                table.insert(candidates, {
                    player = p,
                    crossDist = cd,
                    hp = Utils.getHP(p),
                    dist = Utils.getDistance(p),
                    threat = Brain.isThreat(p) and 1 or 0,
                })
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b)
        local p = C.Aim.Priority
        if a.threat ~= b.threat then return a.threat > b.threat end
        if p == "Lowest HP" then return a.hp < b.hp
        elseif p == "Closest" then return a.dist < b.dist
        else return a.crossDist < b.crossDist end
    end)
    local best = candidates[1].player
    if best ~= State.currentTarget then
        State.lastTargetSwitch = now
        State.currentTarget = best
        State.behaviorSeed = math.random(1,9999)
    end
    return best
end

function AimModule.doAim(target)
    if math.random(1,100) > C.Aim.HitChance then return end
    local bone = AimModule.getBestBone(target.Character)
    local bonePos = AimModule.getPredicted(target, bone)
    if not bonePos then return end
    bonePos = bonePos + Brain.getHumanOffset()
    if C.Aim.RandomOffset > 0 then
        bonePos = bonePos + Vector3.new(
            (math.random()-0.5)*C.Aim.RandomOffset,
            (math.random()-0.5)*C.Aim.RandomOffset, 0
        )
    end
    local smooth = Brain.getSmooth(target)
    local targetCF = CFrame.new(Cam.CFrame.Position, bonePos)
    Cam.CFrame = Cam.CFrame:Lerp(targetCF, smooth)
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.lastSeenPos[target.Name] = {pos = hrp.Position, vel = hrp.Velocity, time = tick()}
    end
end

-- ========================
-- HYPERSHOT AIM MODULE
-- ========================
local HsyAim = {}

function HsyAim.getTarget()
    local now = tick()
    if (now - State.hsyLastSwitch) < 0.5 and State.hsyCurrentTarget then
        local t = State.hsyCurrentTarget
        if t.Character and t.Character:FindFirstChild("Humanoid") and
           t.Character.Humanoid.Health > 0 then
            local cd = Utils.getCrosshairDist(t, C.Hypershot.AimbotBone)
            if cd <= C.Hypershot.AimbotFOV then return t end
        end
    end
    local candidates = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and Utils.isEnemy(p) then
            if C.Hypershot.AimbotVisible and not Utils.isVisible(p) then continue end
            local cd = Utils.getCrosshairDist(p, C.Hypershot.AimbotBone)
            if cd <= C.Hypershot.AimbotFOV then
                table.insert(candidates, {player = p, crossDist = cd, dist = Utils.getDistance(p)})
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates, function(a,b) return a.crossDist < b.crossDist end)
    local best = candidates[1].player
    if best ~= State.hsyCurrentTarget then
        State.hsyLastSwitch = now
        State.hsyCurrentTarget = best
    end
    return best
end

function HsyAim.doAim(target)
    local part = target.Character:FindFirstChild(C.Hypershot.AimbotBone) or
                 target.Character:FindFirstChild("Head")
    if not part then return end
    local bonePos = part.Position
    if C.Hypershot.AimbotPrediction then
        local hrp = target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.Velocity
            local dist = (bonePos - Cam.CFrame.Position).Magnitude
            bonePos = bonePos + vel * (dist/600)
        end
    end
    local targetCF = CFrame.new(Cam.CFrame.Position, bonePos)
    Cam.CFrame = Cam.CFrame:Lerp(targetCF, C.Hypershot.AimbotSmooth)
end

-- ========================
-- ESP SYSTEM — CACHE PERMANENTE (SEM RECRIAR)
-- ========================
local ESPCache = {}

-- Cada player tem seus objetos cached
local function getOrCreateESPForPlayer(p)
    if not ESPCache[p.UserId] then
        ESPCache[p.UserId] = {
            -- Skeleton lines (14 bones)
            skeletonLines = {},
            -- Health bar bg + fill
            hpBg = Drawing.new("Square"),
            hpFill = Drawing.new("Square"),
            -- Distance label
            distLabel = Drawing.new("Text"),
            -- Name label
            nameLabel = Drawing.new("Text"),
            -- Box
            box = Drawing.new("Square"),
            -- Tracer
            tracer = Drawing.new("Line"),
            -- Offscreen (criado on demand)
            offArrow = nil,
        }
        local cache = ESPCache[p.UserId]

        -- Inicializa skeleton lines
        for i = 1, #BONES_LIST do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 1.5
            table.insert(cache.skeletonLines, line)
        end

        -- Inicializa outros
        cache.hpBg.Visible = false
        cache.hpBg.Filled = true

        cache.hpFill.Visible = false
        cache.hpFill.Filled = true

        cache.distLabel.Visible = false
        cache.distLabel.Size = 13
        cache.distLabel.Outline = true

        cache.nameLabel.Visible = false
        cache.nameLabel.Size = 13
        cache.nameLabel.Outline = true
        cache.nameLabel.Center = true

        cache.box.Visible = false
        cache.box.Filled = false
        cache.box.Thickness = 1

        cache.tracer.Visible = false
        cache.tracer.Thickness = 1
    end
    return ESPCache[p.UserId]
end

local function hideESPForPlayer(cache)
    if not cache then return end
    for _, line in pairs(cache.skeletonLines) do line.Visible = false end
    cache.hpBg.Visible = false
    cache.hpFill.Visible = false
    cache.distLabel.Visible = false
    cache.nameLabel.Visible = false
    cache.box.Visible = false
    cache.tracer.Visible = false
    if cache.offArrow then cache.offArrow.Visible = false end
end

local function removeESPForPlayer(userId)
    local cache = ESPCache[userId]
    if not cache then return end
    for _, line in pairs(cache.skeletonLines) do line:Remove() end
    cache.hpBg:Remove()
    cache.hpFill:Remove()
    cache.distLabel:Remove()
    cache.nameLabel:Remove()
    cache.box:Remove()
    cache.tracer:Remove()
    if cache.offArrow then cache.offArrow:Remove() end
    ESPCache[userId] = nil
end

-- Hypershot ESP Cache separado
local HsyESPCache = {}

local function getOrCreateHsyESP(p)
    if not HsyESPCache[p.UserId] then
        HsyESPCache[p.UserId] = {
            skeletonLines = {},
            hpBg = Drawing.new("Square"),
            hpFill = Drawing.new("Square"),
            nameLabel = Drawing.new("Text"),
            box = Drawing.new("Square"),
            tracer = Drawing.new("Line"),
        }
        local cache = HsyESPCache[p.UserId]
        for i = 1, #BONES_LIST do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 1.5
            table.insert(cache.skeletonLines, line)
        end
        cache.hpBg.Visible = false
        cache.hpBg.Filled = true
        cache.hpFill.Visible = false
        cache.hpFill.Filled = true
        cache.nameLabel.Visible = false
        cache.nameLabel.Size = 13
        cache.nameLabel.Outline = true
        cache.nameLabel.Center = true
        cache.box.Visible = false
        cache.box.Filled = false
        cache.box.Thickness = 1
        cache.tracer.Visible = false
        cache.tracer.Thickness = 1
    end
    return HsyESPCache[p.UserId]
end

local function hideHsyESP(cache)
    if not cache then return end
    for _, line in pairs(cache.skeletonLines) do line.Visible = false end
    cache.hpBg.Visible = false
    cache.hpFill.Visible = false
    cache.nameLabel.Visible = false
    cache.box.Visible = false
    cache.tracer.Visible = false
end

-- Cleanup quando player sai
Players.PlayerRemoving:Connect(function(p)
    removeESPForPlayer(p.UserId)
    local hcache = HsyESPCache[p.UserId]
    if hcache then
        for _, line in pairs(hcache.skeletonLines) do line:Remove() end
        hcache.hpBg:Remove() hcache.hpFill:Remove()
        hcache.nameLabel:Remove() hcache.box:Remove() hcache.tracer:Remove()
        HsyESPCache[p.UserId] = nil
    end
end)

-- ========================
-- ESP UPDATE — ATUALIZA SEM RECRIAR
-- ========================
local function updateESP()
    if State.streamMode then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP then
                local cache = ESPCache[p.UserId]
                if cache then hideESPForPlayer(cache) end
            end
        end
        return
    end

    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)

    for _, p in pairs(Players:GetPlayers()) do
        if p == LP then continue end

        local cache = getOrCreateESPForPlayer(p)

        -- Verifica se deve mostrar
        local shouldShow = C.ESP.Enabled and C.ESP.Visible and
                           p.Character and Utils.isEnemy(p)
        if C.ESP.VisibleOnly and shouldShow then
            shouldShow = Utils.isVisible(p)
        end

        if not shouldShow or not p.Character then
            hideESPForPlayer(cache)
            continue
        end

        local char = p.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then hideESPForPlayer(cache) continue end

        -- Cor base
        local color = C.ESP.Color
        if C.ESP.PriorityHighlight then
            local dist = Utils.getDistance(p)
            if Brain.isThreat(p) then color = Color3.fromRGB(255,50,50)
            elseif dist <= C.ESP.PriorityRange then color = Color3.fromRGB(255,150,0) end
        end
        if C.ESP.GradientHP then
            local hp = hum.Health / hum.MaxHealth
            color = Color3.fromRGB(255*(1-hp), 255*hp, 0)
        end

        -- Alpha por distancia
        local alpha = 1
        if C.ESP.FadeDistance and myHRP then
            local dist = (hrp.Position - myHRP.Position).Magnitude
            alpha = math.clamp(1 - dist/400, 0.1, 1)
        end

        -- Posição na tela
        local pos, vis = Cam:WorldToViewportPoint(hrp.Position)
        local onScreen = vis and pos.Z > 0

        -- ====== SKELETON ======
        if C.ESP.Skeleton then
            for i, bone in pairs(BONES_LIST) do
                local line = cache.skeletonLines[i]
                if not line then continue end
                local p0 = char:FindFirstChild(bone[1])
                local p1 = char:FindFirstChild(bone[2])
                if p0 and p1 then
                    local s0, v0 = Cam:WorldToViewportPoint(p0.Position)
                    local s1, v1 = Cam:WorldToViewportPoint(p1.Position)
                    if v0 and v1 and s0.Z > 0 then
                        line.From = Vector2.new(s0.X, s0.Y)
                        line.To = Vector2.new(s1.X, s1.Y)
                        line.Color = C.ESP.SkeletonColor
                        line.Transparency = 1 - alpha
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(cache.skeletonLines) do line.Visible = false end
        end

        -- ====== HEALTH BAR ======
        if C.ESP.HealthBar and onScreen then
            local hp = hum.Health / hum.MaxHealth
            local bh, bw = 40, 5
            local x, y = pos.X - 22, pos.Y - bh/2
            cache.hpBg.Size = Vector2.new(bw, bh)
            cache.hpBg.Position = Vector2.new(x, y)
            cache.hpBg.Color = Color3.fromRGB(0,0,0)
            cache.hpBg.Transparency = 0.5
            cache.hpBg.Visible = true
            cache.hpFill.Size = Vector2.new(bw, bh*hp)
            cache.hpFill.Position = Vector2.new(x, y+bh*(1-hp))
            cache.hpFill.Color = Color3.fromRGB(255*(1-hp), 255*hp, 0)
            cache.hpFill.Transparency = 1 - alpha
            cache.hpFill.Visible = true
        else
            cache.hpBg.Visible = false
            cache.hpFill.Visible = false
        end

        -- ====== DISTANCE ======
        if C.ESP.Distance and onScreen and myHRP then
            local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
            cache.distLabel.Text = dist .. "m"
            cache.distLabel.Color = color
            cache.distLabel.Transparency = 1 - alpha
            cache.distLabel.Position = Vector2.new(pos.X+12, pos.Y)
            cache.distLabel.Visible = true
        else
            cache.distLabel.Visible = false
        end

        -- ====== NAME ======
        if C.ESP.Names and onScreen then
            cache.nameLabel.Text = p.Name
            cache.nameLabel.Color = color
            cache.nameLabel.Position = Vector2.new(pos.X, pos.Y - 20)
            cache.nameLabel.Visible = true
        else
            cache.nameLabel.Visible = false
        end

        -- ====== BOX ======
        if C.ESP.Boxes and onScreen then
            local headPos = char:FindFirstChild("Head") and
                           Cam:WorldToViewportPoint(char.Head.Position)
            if headPos then
                local height = math.abs(pos.Y - headPos.Y) * 1.2
                local width = height * 0.6
                cache.box.Size = Vector2.new(width, height)
                cache.box.Position = Vector2.new(pos.X - width/2, pos.Y - height*0.8)
                cache.box.Color = color
                cache.box.Thickness = 1
                cache.box.Visible = true
            end
        else
            cache.box.Visible = false
        end

        -- ====== TRACERS ======
        if C.ESP.Tracers and onScreen then
            cache.tracer.From = Vector2.new(center.X, Cam.ViewportSize.Y)
            cache.tracer.To = Vector2.new(pos.X, pos.Y)
            cache.tracer.Color = color
            cache.tracer.Thickness = 1
            cache.tracer.Visible = true
        else
            cache.tracer.Visible = false
        end

        -- ====== OFFSCREEN ======
        if C.ESP.Offscreen and not onScreen then
            if not cache.offArrow then
                cache.offArrow = Drawing.new("Triangle")
                cache.offArrow.Filled = true
            end
            local dir = (Vector2.new(pos.X, pos.Y) - center)
            if dir.Magnitude > 0 then
                dir = dir.Unit
                local angle = math.atan2(dir.Y, dir.X)
                local radius = math.min(center.X, center.Y) - 30
                local ap = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
                cache.offArrow.PointA = ap + Vector2.new(math.cos(angle)*10, math.sin(angle)*10)
                cache.offArrow.PointB = ap + Vector2.new(math.cos(angle+2.5)*8, math.sin(angle+2.5)*8)
                cache.offArrow.PointC = ap + Vector2.new(math.cos(angle-2.5)*8, math.sin(angle-2.5)*8)
                cache.offArrow.Color = color
                cache.offArrow.Visible = true
            end
        else
            if cache.offArrow then cache.offArrow.Visible = false end
        end

        -- ====== CHAMS ======
        if C.ESP.Chams then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Material = Enum.Material.Neon
                    part.Color = color
                end
            end
        end
    end
end

-- ========================
-- HYPERSHOT ESP UPDATE
-- ========================
local function updateHsyESP()
    if not C.Hypershot.ESPEnabled then
        for _, p in pairs(Players:GetPlayers()) do
            local cache = HsyESPCache[p.UserId]
            if cache then hideHsyESP(cache) end
        end
        return
    end

    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

    for _, p in pairs(Players:GetPlayers()) do
        if p == LP then continue end
        local cache = getOrCreateHsyESP(p)

        local shouldShow = p.Character and Utils.isEnemy(p)
        if C.Hypershot.ESPTeamCheck then shouldShow = shouldShow and Utils.isEnemy(p) end

        if not shouldShow or not p.Character then
            hideHsyESP(cache)
            continue
        end

        local char = p.Character
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then hideHsyESP(cache) continue end

        local color = C.Hypershot.ESPColor
        local pos, vis = Cam:WorldToViewportPoint(hrp.Position)
        local onScreen = vis and pos.Z > 0

        -- Skeleton
        if C.Hypershot.ESPSkeleton then
            for i, bone in pairs(BONES_LIST) do
                local line = cache.skeletonLines[i]
                if not line then continue end
                local p0 = char:FindFirstChild(bone[1])
                local p1 = char:FindFirstChild(bone[2])
                if p0 and p1 then
                    local s0, v0 = Cam:WorldToViewportPoint(p0.Position)
                    local s1, v1 = Cam:WorldToViewportPoint(p1.Position)
                    if v0 and v1 and s0.Z > 0 then
                        line.From = Vector2.new(s0.X, s0.Y)
                        line.To = Vector2.new(s1.X, s1.Y)
                        line.Color = color
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        else
            for _, line in pairs(cache.skeletonLines) do line.Visible = false end
        end

        -- Health bar
        if C.Hypershot.ESPHealthBar and onScreen then
            local hp = hum.Health / hum.MaxHealth
            local bh, bw = 40, 5
            local x, y = pos.X - 22, pos.Y - bh/2
            cache.hpBg.Size = Vector2.new(bw, bh)
            cache.hpBg.Position = Vector2.new(x, y)
            cache.hpBg.Color = Color3.fromRGB(0,0,0)
            cache.hpBg.Transparency = 0.5
            cache.hpBg.Visible = true
            cache.hpFill.Size = Vector2.new(bw, bh*hp)
            cache.hpFill.Position = Vector2.new(x, y+bh*(1-hp))
            cache.hpFill.Color = Color3.fromRGB(255*(1-hp), 255*hp, 0)
            cache.hpFill.Visible = true
        else
            cache.hpBg.Visible = false
            cache.hpFill.Visible = false
        end

        -- Names
        if C.Hypershot.ESPNames and onScreen then
            cache.nameLabel.Text = p.Name
            cache.nameLabel.Color = color
            cache.nameLabel.Position = Vector2.new(pos.X, pos.Y - 20)
            cache.nameLabel.Visible = true
        else
            cache.nameLabel.Visible = false
        end

        -- Boxes
        if C.Hypershot.ESPBoxes and onScreen then
            local head = char:FindFirstChild("Head")
            if head then
                local headPos = Cam:WorldToViewportPoint(head.Position)
                local height = math.abs(pos.Y - headPos.Y) * 1.2
                local width = height * 0.6
                cache.box.Size = Vector2.new(width, height)
                cache.box.Position = Vector2.new(pos.X - width/2, pos.Y - height*0.8)
                cache.box.Color = color
                cache.box.Visible = true
            end
        else
            cache.box.Visible = false
        end

        -- Tracers
        if C.Hypershot.ESPTracers and onScreen then
            cache.tracer.From = Vector2.new(center.X, Cam.ViewportSize.Y)
            cache.tracer.To = Vector2.new(pos.X, pos.Y)
            cache.tracer.Color = color
            cache.tracer.Visible = true
        else
            cache.tracer.Visible = false
        end
    end
end

-- ========================
-- HITBOX SYSTEMS
-- ========================
local function applyHitbox(teamCheck, sizeVec)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            if teamCheck and not Utils.isEnemy(p) then continue end
            local parts = {"RightUpperLeg","LeftUpperLeg","HeadHB","HumanoidRootPart"}
            for _, pn in pairs(parts) do
                local part = p.Character:FindFirstChild(pn)
                if part then
                    if not State.originalSizes[p.Name] then State.originalSizes[p.Name] = {} end
                    if not State.originalSizes[p.Name][pn] then
                        State.originalSizes[p.Name][pn] = part.Size
                    end
                    part.CanCollide = false
                    part.Transparency = 0.75
                    part.Size = sizeVec or Vector3.new(21,21,21)
                end
            end
        end
    end
end

local function removeHitbox(sizesTable)
    local t = sizesTable or State.originalSizes
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and t[p.Name] then
            for pn, sz in pairs(t[p.Name]) do
                local part = p.Character:FindFirstChild(pn)
                if part then part.Size = sz part.Transparency = 0 end
            end
        end
    end
    if sizesTable then
        for k in pairs(sizesTable) do sizesTable[k] = nil end
    else
        State.originalSizes = {}
    end
end

-- ========================
-- PLAYER MODULE
-- ========================
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient
local originalOutdoor = Lighting.OutdoorAmbient

local function enableFullbright()
    Lighting.Brightness = 10
    Lighting.Ambient = Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
end

local function disableFullbright()
    Lighting.Brightness = originalBrightness
    Lighting.Ambient = originalAmbient
    Lighting.OutdoorAmbient = originalOutdoor
end

local function stopFly(stateKey, connKey)
    State[stateKey] = false
    if State[connKey] then State[connKey]:Disconnect() State[connKey] = nil end
    local char = LP.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if hrp then
            local bv = hrp:FindFirstChild("FlyBodyVelocity")
            local bg = hrp:FindFirstChild("FlyBodyGyro")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
        end
        if hum then hum.PlatformStand = false end
    end
end

local function startFly(mobile, stateKey, connKey, speedGetter)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    hum.PlatformStand = true
    local bg = Instance.new("BodyGyro")
    bg.Name = "FlyBodyGyro"
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bg.D = 100
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FlyBodyVelocity"
    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bv.P = 1000
    bv.Velocity = Vector3.new(0,0,0)
    bv.Parent = hrp
    State[stateKey] = true
    State[connKey] = RunService.RenderStepped:Connect(function()
        if not State[stateKey] then return end
        local c = LP.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local b = h and h:FindFirstChild("FlyBodyGyro")
        local v = h and h:FindFirstChild("FlyBodyVelocity")
        if not h or not b or not v then return end
        local move = Vector3.new(0,0,0)
        local cf = Cam.CFrame
        local spd = speedGetter()
        if mobile then
            local hu = c:FindFirstChild("Humanoid")
            if hu and hu.MoveDirection.Magnitude > 0 then
                move = move + hu.MoveDirection * spd
            end
            if State.mobileFlyUp then move = move + Vector3.new(0,1,0) end
            if State.mobileFlyDown then move = move - Vector3.new(0,1,0) end
        else
            if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
        end
        v.Velocity = move.Magnitude > 0 and move.Unit * spd or Vector3.new(0,0,0)
        b.CFrame = CFrame.new(h.Position, h.Position + cf.LookVector)
    end)
end

-- ========================
-- VISUAL MODULE
-- ========================
local FOVring = Drawing.new("Circle")
FOVring.Visible = false
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(255,0,0)
FOVring.Filled = false
FOVring.Radius = 100

local FOVring2 = Drawing.new("Circle")
FOVring2.Visible = false
FOVring2.Thickness = 2
FOVring2.Color = Color3.fromRGB(0,255,0)
FOVring2.Filled = false
FOVring2.Radius = 100

local hsyFOVring = Drawing.new("Circle")
hsyFOVring.Visible = false
hsyFOVring.Thickness = 2
hsyFOVring.Color = Color3.fromRGB(0,200,255)
hsyFOVring.Filled = false
hsyFOVring.Radius = 120

local fpsLabel = Drawing.new("Text")
fpsLabel.Visible = false
fpsLabel.Size = 16
fpsLabel.Color = Color3.fromRGB(255,255,255)
fpsLabel.Outline = true
fpsLabel.Position = Vector2.new(10,10)

local sessionStart = os.time()
local timerLabel = Drawing.new("Text")
timerLabel.Visible = false
timerLabel.Size = 16
timerLabel.Color = Color3.fromRGB(255,255,255)
timerLabel.Outline = true
timerLabel.Position = Vector2.new(10,30)

local warningLabel = Drawing.new("Text")
warningLabel.Visible = false
warningLabel.Size = 20
warningLabel.Color = Color3.fromRGB(255,80,80)
warningLabel.Outline = true
warningLabel.Center = true

local debugLabel = Drawing.new("Text")
debugLabel.Visible = false
debugLabel.Size = 14
debugLabel.Color = Color3.fromRGB(100,255,100)
debugLabel.Outline = true
debugLabel.Position = Vector2.new(10,50)

local crosshairLines = {}
local crosshairEnabled = false
local crosshairColor = Color3.fromRGB(255,255,255)
local crosshairSize = 10
local crosshairGap = 5
local radarEnabled = false
local radarSize = 150
local radarRange = 100
local radarDots = {}

local function updateCrosshair()
    for _, l in pairs(crosshairLines) do l.Visible = false end
    crosshairLines = {}
    if not crosshairEnabled or State.streamMode then return end
    local cx = Cam.ViewportSize.X/2
    local cy = Cam.ViewportSize.Y/2
    local segs = {
        {Vector2.new(cx-crosshairSize-crosshairGap,cy),Vector2.new(cx-crosshairGap,cy)},
        {Vector2.new(cx+crosshairGap,cy),Vector2.new(cx+crosshairSize+crosshairGap,cy)},
        {Vector2.new(cx,cy-crosshairSize-crosshairGap),Vector2.new(cx,cy-crosshairGap)},
        {Vector2.new(cx,cy+crosshairGap),Vector2.new(cx,cy+crosshairSize+crosshairGap)},
    }
    for _, seg in pairs(segs) do
        local line = Drawing.new("Line")
        line.From = seg[1]
        line.To = seg[2]
        line.Color = crosshairColor
        line.Thickness = 2
        line.Visible = true
        table.insert(crosshairLines, line)
    end
end

local function updateRadar()
    for _, d in pairs(radarDots) do d:Remove() end
    radarDots = {}
    if not radarEnabled or State.streamMode then return end
    local cx = Cam.ViewportSize.X - radarSize/2 - 10
    local cy = radarSize/2 + 10
    local bg = Drawing.new("Circle")
    bg.Position = Vector2.new(cx,cy)
    bg.Radius = radarSize/2
    bg.Color = Color3.fromRGB(0,0,0)
    bg.Transparency = 0.5
    bg.Filled = true
    bg.Visible = true
    table.insert(radarDots, bg)
    local border = Drawing.new("Circle")
    border.Position = Vector2.new(cx,cy)
    border.Radius = radarSize/2
    border.Color = Color3.fromRGB(255,255,255)
    border.Thickness = 1
    border.Filled = false
    border.Visible = true
    table.insert(radarDots, border)
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and Utils.isEnemy(p) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local delta = hrp.Position - myHRP.Position
                if delta.Magnitude <= radarRange then
                    local angle = math.atan2(delta.Z, delta.X)
                    local camAngle = math.atan2(Cam.CFrame.LookVector.Z, Cam.CFrame.LookVector.X)
                    local relAngle = angle - camAngle
                    local scale = (delta.Magnitude/radarRange)*(radarSize/2)
                    local dot = Drawing.new("Circle")
                    dot.Position = Vector2.new(cx+math.cos(relAngle)*scale, cy+math.sin(relAngle)*scale)
                    dot.Radius = 4
                    dot.Color = Color3.fromRGB(255,0,0)
                    dot.Filled = true
                    dot.Visible = true
                    table.insert(radarDots, dot)
                end
            end
        end
    end
end

local function updateWarning()
    if not C.Misc.EnemyWarning or State.streamMode then
        warningLabel.Visible = false
        return
    end
    local nearest, nearestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and Utils.isEnemy(p) then
            local d = Utils.getDistance(p)
            if d < nearestDist then nearestDist = d nearest = p end
        end
    end
    if nearest and nearestDist <= C.Misc.EnemyWarningRange then
        warningLabel.Text = "ENEMY NEARBY! [" .. math.floor(nearestDist) .. "m] " .. nearest.Name
        warningLabel.Position = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y*0.15)
        warningLabel.Visible = true
    else
        warningLabel.Visible = false
    end
end

local function updateDebug()
    if not C.Misc.DebugMode or State.streamMode or not State.devAccess then
        debugLabel.Visible = false
        return
    end
    debugLabel.Visible = true
    local t = State.currentTarget
    debugLabel.Text = string.format(
        "[DEBUG v4.1]\nTarget: %s\nDist: %dm | HP: %d\nLocked: %s | FPS: %d\nPing: %dms | Stress: %d%%\nSpectators: %d | Mode: %s\nStream: %s",
        t and t.Name or "None",
        t and math.floor(Utils.getDistance(t)) or 0,
        t and math.floor(Utils.getHP(t)) or 0,
        State.lockActive and "YES" or "NO",
        State.fps,
        math.floor(State.ping),
        math.floor(Brain.getStress()*100),
        #State.spectators,
        C.Mode,
        State.streamMode and "ON" or "OFF"
    )
end

local function setStreamMode(enabled)
    State.streamMode = enabled
    if enabled then
        FOVring.Visible = false
        FOVring2.Visible = false
        fpsLabel.Visible = false
        timerLabel.Visible = false
        warningLabel.Visible = false
        debugLabel.Visible = false
        hsyFOVring.Visible = false
        for _, l in pairs(crosshairLines) do l.Visible = false end
        for _, p in pairs(Players:GetPlayers()) do
            if ESPCache[p.UserId] then hideESPForPlayer(ESPCache[p.UserId]) end
            if HsyESPCache[p.UserId] then hideHsyESP(HsyESPCache[p.UserId]) end
        end
        playSound("stream")
    else
        playSound("stream")
    end
end

local keybindGui = nil

local function createKeybindOverlay()
    if keybindGui then keybindGui:Destroy() end
    keybindGui = Instance.new("ScreenGui")
    keybindGui.Name = "KeybindOverlay"
    keybindGui.ResetOnSpawn = false
    keybindGui.Parent = LP.PlayerGui
    local frame = Instance.new("Frame", keybindGui)
    frame.Size = UDim2.new(0,165,0,210)
    frame.Position = UDim2.new(0,10,0.5,-105)
    frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,0,0,25)
    title.BackgroundTransparency = 1
    title.Text = "KEYBINDS"
    title.TextColor3 = Color3.fromRGB(255,200,50)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    local binds = {
        {"Q","Dash"},{"E","Target Lock"},{"Z","ESP Toggle"},
        {"RMB","Aimbot"},{"Space","BHop/Fly Up"},
        {"Shift","Fly Down"},{"F8","Stream Mode"},{"F9","Panic Key"},
    }
    for i, bind in pairs(binds) do
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1,-10,0,20)
        lbl.Position = UDim2.new(0,5,0,22+(i-1)*23)
        lbl.BackgroundTransparency = 1
        lbl.Text = "[" .. bind[1] .. "] " .. bind[2]
        lbl.TextColor3 = Color3.fromRGB(200,200,200)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
    end
end

-- ========================
-- MOBILE BUTTONS
-- ========================
local mobileGui = nil

local function createMobileButtons()
    if mobileGui then mobileGui:Destroy() end
    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "ArsenalMobileGui"
    mobileGui.ResetOnSpawn = false
    mobileGui.Parent = LP.PlayerGui

    local function makeBtn(text, pos, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,82,0,48)
        btn.Position = pos
        btn.BackgroundColor3 = color or Color3.fromRGB(25,25,25)
        btn.BackgroundTransparency = 0.25
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Text = text
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = mobileGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
        return btn
    end

    makeBtn("UP", UDim2.new(1,-90,0.65,0), Color3.fromRGB(0,100,220))
    .MouseButton1Click:Connect(function() State.mobileFlyUp = true task.wait(0.15) State.mobileFlyUp = false end)

    makeBtn("DOWN", UDim2.new(1,-90,0.75,0), Color3.fromRGB(0,60,180))
    .MouseButton1Click:Connect(function() State.mobileFlyDown = true task.wait(0.15) State.mobileFlyDown = false end)

    local flyBtn = makeBtn("FLY: OFF", UDim2.new(1,-90,0.55,0))
    flyBtn.MouseButton1Click:Connect(function()
        State.flyEnabled = not State.flyEnabled
        if State.flyEnabled then startFly(true,"flyEnabled","flyConn",function() return C.Player.FlySpeed end)
        else stopFly("flyEnabled","flyConn") end
        flyBtn.Text = State.flyEnabled and "FLY: ON" or "FLY: OFF"
        flyBtn.BackgroundColor3 = State.flyEnabled and Color3.fromRGB(0,170,70) or Color3.fromRGB(25,25,25)
    end)

    local aimBtn = makeBtn("AIM: OFF", UDim2.new(1,-90,0.45,0))
    aimBtn.MouseButton1Click:Connect(function()
        State.mobileAim = not State.mobileAim
        C.Aim.Enabled = State.mobileAim
        aimBtn.Text = State.mobileAim and "AIM: ON" or "AIM: OFF"
        aimBtn.BackgroundColor3 = State.mobileAim and Color3.fromRGB(200,40,40) or Color3.fromRGB(25,25,25)
    end)

    local espBtn = makeBtn("ESP: OFF", UDim2.new(1,-90,0.35,0))
    espBtn.MouseButton1Click:Connect(function()
        C.ESP.Visible = not C.ESP.Visible
        espBtn.Text = C.ESP.Visible and "ESP: ON" or "ESP: OFF"
        espBtn.BackgroundColor3 = C.ESP.Visible and Color3.fromRGB(180,120,0) or Color3.fromRGB(25,25,25)
    end)

    local spdBtn = makeBtn("SPD: OFF", UDim2.new(1,-90,0.25,0))
    spdBtn.MouseButton1Click:Connect(function()
        C.Player.WSEnabled = not C.Player.WSEnabled
        spdBtn.Text = C.Player.WSEnabled and "SPD: ON" or "SPD: OFF"
        spdBtn.BackgroundColor3 = C.Player.WSEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(25,25,25)
        if not C.Player.WSEnabled then
            local char = LP.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = 16 end
        end
    end)

    local hitBtn = makeBtn("HIT: OFF", UDim2.new(1,-90,0.15,0))
    hitBtn.MouseButton1Click:Connect(function()
        C.Combat.Hitbox = not C.Combat.Hitbox
        hitBtn.Text = C.Combat.Hitbox and "HIT: ON" or "HIT: OFF"
        hitBtn.BackgroundColor3 = C.Combat.Hitbox and Color3.fromRGB(160,0,160) or Color3.fromRGB(25,25,25)
        if not C.Combat.Hitbox then removeHitbox(State.originalSizes) end
    end)
end

-- ========================
-- INPUT
-- ========================
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == C.Misc.PanicKey then
        C.Aim.Enabled = false
        C.ESP.Enabled = false
        C.Combat.Hitbox = false
        C.Player.WSEnabled = false
        C.Hypershot.AimbotEnabled = false
        C.Hypershot.Hitbox = false
        stopFly("flyEnabled","flyConn")
        stopFly("hsyFlyEnabled","hsyFlyConn")
        removeHitbox(State.originalSizes)
        removeHitbox(State.hsyOriginalSizes)
        return
    end
    if input.KeyCode == C.Misc.StreamKey then
        C.Misc.StreamMode = not C.Misc.StreamMode
        setStreamMode(C.Misc.StreamMode)
        return
    end
    if input.KeyCode == C.Aim.TargetLockKey and C.Aim.TargetLock then
        if not State.lockActive then
            local t = AimModule.getTarget()
            if t then State.lockedTarget = t State.lockActive = true end
        else
            State.lockActive = false
            State.lockedTarget = nil
        end
    end
    if C.ESP.KeyToggle and input.KeyCode == Enum.KeyCode.Z then
        C.ESP.Visible = not C.ESP.Visible
    end
    if input.KeyCode == Enum.KeyCode.Q and not State.dashCD then
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            State.dashCD = true
            hrp.Velocity = hrp.CFrame.LookVector * 100
            task.wait(0.5)
            State.dashCD = false
        end
    end
end)

-- ========================
-- SCHEDULERS
-- ========================
registerScheduler("ESP", 0.02, updateESP)
registerScheduler("HsyESP", 0.02, updateHsyESP)
registerScheduler("Radar", 0.05, updateRadar)
registerScheduler("Warning", 0.2, updateWarning)
registerScheduler("Threats", 0.5, Brain.updateThreats)
registerScheduler("Spectators", 1.0, function()
    if not C.Misc.SpectatorDetection then return end
    State.spectators = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            if not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(State.spectators, p.Name)
            end
        end
    end
end)
registerScheduler("Crosshair", 0.02, updateCrosshair)

-- ========================
-- MAIN LOOPS
-- ========================
RunService.RenderStepped:Connect(function()
    tickSchedulers()

    -- FOV rings
    if not State.streamMode then
        FOVring.Position = Cam.ViewportSize/2
        FOVring2.Position = Cam.ViewportSize/2
        hsyFOVring.Position = Cam.ViewportSize/2
        local hasTarget = AimModule.getTarget() ~= nil
        if FOVring.Visible then FOVring.Color = hasTarget and Color3.fromRGB(255,255,0) or Color3.fromRGB(255,0,0) end
        if FOVring2.Visible then FOVring2.Color = hasTarget and Color3.fromRGB(255,255,0) or Color3.fromRGB(0,255,0) end
    end

    -- Aimbot Arsenal
    if C.Aim.Enabled then
        local pressed = false
        if C.Aim.Keybind == Enum.UserInputType.MouseButton2 then
            pressed = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif C.Aim.Keybind == Enum.UserInputType.MouseButton1 then
            pressed = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        else
            pressed = UIS:IsKeyDown(C.Aim.Keybind)
        end
        if pressed or State.mobileAim then
            local target = AimModule.getTarget()
            if target then
                if C.Aim.AimDelay > 0 then task.wait(C.Aim.AimDelay/1000) end
                AimModule.doAim(target)
            end
        end
    end

    -- Aimbot Hypershot
    if C.Hypershot.AimbotEnabled then
        local pressed = false
        if C.Hypershot.AimbotKeybind == Enum.UserInputType.MouseButton2 then
            pressed = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif C.Hypershot.AimbotKeybind == Enum.UserInputType.MouseButton1 then
            pressed = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        else
            pressed = UIS:IsKeyDown(C.Hypershot.AimbotKeybind)
        end
        if pressed then
            local target = HsyAim.getTarget()
            if target then HsyAim.doAim(target) end
        end
    end

    -- FPS
    if fpsLabel.Visible then fpsLabel.Text = "FPS: " .. State.fps end
    if timerLabel.Visible then
        local e = os.time() - sessionStart
        timerLabel.Text = string.format("Session: %02d:%02d", math.floor(e/60), e%60)
    end
    updateDebug()
end)

RunService.Heartbeat:Connect(function()
    local char = LP.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        if C.Player.WSEnabled then hum.WalkSpeed = C.Player.WalkSpeed end
        if C.Player.JPEnabled then hum.JumpPower = C.Player.JumpPower end
        if C.Hypershot.WalkSpeed then hum.WalkSpeed = C.Hypershot.WalkSpeedValue end
        if C.Hypershot.JumpPower then hum.JumpPower = C.Hypershot.JumpPowerValue end
    end
    if C.Player.BunnyHop and char then
        local h = char:FindFirstChild("Humanoid")
        if h and h.FloorMaterial ~= Enum.Material.Air and UIS:IsKeyDown(Enum.KeyCode.Space) then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
    if C.Hypershot.BunnyHop and char then
        local h = char:FindFirstChild("Humanoid")
        if h and h.FloorMaterial ~= Enum.Material.Air and UIS:IsKeyDown(Enum.KeyCode.Space) then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
    if C.Player.Noclip and char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    if C.Hypershot.Noclip and char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    if C.Player.AntiRagdoll and char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
    end
    if C.Hypershot.AntiRagdoll and char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
    end
    if C.Player.AntiFall and char then
        local h = char:FindFirstChild("Humanoid")
        if h then h:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end
    end
    if C.Hypershot.AntiFall and char then
        local h = char:FindFirstChild("Humanoid")
        if h then h:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end
    end
    if C.Combat.Hitbox then
        applyHitbox(C.Combat.HitboxTeamCheck, Vector3.new(21,21,21))
    end
    if C.Hypershot.Hitbox then
        applyHitbox(C.Hypershot.HitboxTeamCheck, Vector3.new(C.Hypershot.HitboxSize, C.Hypershot.HitboxSize, C.Hypershot.HitboxSize))
    end
    if C.Player.AntiLock and char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local t = tick()
            hrp.CFrame = hrp.CFrame * CFrame.new(
                math.sin(t*7.3+State.behaviorSeed)*0.3,0,
                math.cos(t*5.1+State.behaviorSeed)*0.3
            )
        end
    end
    if C.Player.QuickStop and char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local h = char:FindFirstChild("Humanoid")
        if hrp and h and h.MoveDirection.Magnitude == 0 then
            hrp.Velocity = Vector3.new(hrp.Velocity.X*0.7, hrp.Velocity.Y, hrp.Velocity.Z*0.7)
        end
    end
    -- Hypershot Inf Ammo
    if C.Hypershot.InfAmmo then
        local gui = LP.PlayerGui
        local g = gui:FindFirstChild("GUI")
        if g then
            local cl = g:FindFirstChild("Client")
            local vars = cl and cl:FindFirstChild("Variables")
            if vars then
                if vars:FindFirstChild("ammocount") then vars.ammocount.Value = 999 end
                if vars:FindFirstChild("ammocount2") then vars.ammocount2.Value = 999 end
            end
        end
    end
end)

LP.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    task.wait(0.5)
    if C.Player.WSEnabled then hum.WalkSpeed = C.Player.WalkSpeed end
    if C.Player.JPEnabled then hum.JumpPower = C.Player.JumpPower end
    if State.flyEnabled then task.wait(0.5) startFly(isMobile,"flyEnabled","flyConn",function() return C.Player.FlySpeed end) end
    if State.hsyFlyEnabled then task.wait(0.5) startFly(isMobile,"hsyFlyEnabled","hsyFlyConn",function() return C.Hypershot.FlySpeed end) end
end)

-- Weapon system
local weaponConfigs = {}
local lastWeapon = nil
RunService.Heartbeat:Connect(function()
    local char = LP.Character
    if not char then return end
    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") then
            if t.Name ~= lastWeapon then
                lastWeapon = t.Name
                if weaponConfigs[t.Name] then
                    local wc = weaponConfigs[t.Name]
                    if wc.FOV then C.Aim.FOV = wc.FOV end
                    if wc.Smooth then C.Aim.Smooth = wc.Smooth end
                end
            end
            break
        end
    end
end)

-- ========================
-- LOAD RAYFIELD
-- ========================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Arsenal Script By Toddyx",
    LoadingTitle = "Arsenal Script",
    LoadingSubtitle = "v4.1 FIXED + HYPERSHOT",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ArsenalScript",
        FileName = "Config"
    },
    KeySystem = false,
})

-- ========================
-- ABA: MAIN
-- ========================
local MainTab = Window:CreateTab("Main", "home")
MainTab:CreateSection("Arsenal Script v4.1")
MainTab:CreateLabel("By Toddyx | F8=Stream | F9=Panic | E=Lock | Q=Dash | Z=ESP")

MainTab:CreateButton({
    Name = "Discord",
    Callback = function()
        setclipboard("discord.gg/M2dHpEQy")
        Rayfield:Notify({ Title = "Discord", Content = "Copied!", Duration = 3 })
    end,
})

MainTab:CreateSection("Profiles")

MainTab:CreateButton({
    Name = "Legit Mode",
    Callback = function()
        C.Mode = "Legit"
        C.Aim.Smooth = 0.04
        C.Aim.FOV = 80
        C.Aim.DynamicSmooth = true
        C.Aim.AntiSwitch = true
        C.Aim.Humanizer = true
        C.Aim.HitChance = 90
        C.Player.WalkSpeed = 18
        Rayfield:Notify({ Title = "Legit", Content = "Natural mode activated.", Duration = 3 })
    end,
})

MainTab:CreateButton({
    Name = "Rage Mode",
    Callback = function()
        C.Mode = "Rage"
        C.Aim.Smooth = 0.9
        C.Aim.FOV = 350
        C.Aim.DynamicSmooth = false
        C.Aim.AntiSwitch = false
        C.Aim.Humanizer = false
        C.Aim.HitChance = 100
        C.Player.WalkSpeed = 120
        Rayfield:Notify({ Title = "Rage", Content = "Full power!", Duration = 3 })
    end,
})

MainTab:CreateButton({
    Name = "Legit Assist",
    Callback = function()
        C.Mode = "LegitAssist"
        C.Aim.Enabled = true
        C.Aim.Smooth = 0.03
        C.Aim.FOV = 65
        C.Aim.VisibleCheck = true
        C.Aim.Prediction = true
        C.Aim.DynamicSmooth = true
        C.Aim.AntiSwitch = true
        C.Aim.Humanizer = true
        C.Aim.HitChance = 85
        C.Player.WalkSpeed = 16
        Rayfield:Notify({ Title = "Legit Assist", Content = "Looks human!", Duration = 4 })
    end,
})

-- ========================
-- ABA: AIM (ARSENAL)
-- ========================
local AimTab = Window:CreateTab("Aim", "crosshair")

AimTab:CreateSection("Aimbot")

AimTab:CreateToggle({ Name = "Aimbot", CurrentValue = false, Flag = "AimbotOn",
    Callback = function(v) C.Aim.Enabled = v end })

AimTab:CreateSlider({ Name = "FOV", Range = {10,400}, Increment = 5, Suffix = "px",
    CurrentValue = 100, Flag = "AimFOV",
    Callback = function(v) C.Aim.FOV = v FOVring.Radius = v FOVring2.Radius = v end })

AimTab:CreateSlider({ Name = "Smooth", Range = {1,20}, Increment = 1, Suffix = "x",
    CurrentValue = 2, Flag = "AimSmooth",
    Callback = function(v) C.Aim.Smooth = v/20 end })

AimTab:CreateDropdown({ Name = "Aim Bone",
    Options = {"Head","UpperTorso","LowerTorso","Random"},
    CurrentOption = {"Head"}, Flag = "AimBone",
    Callback = function(v) C.Aim.Bone = v[1] end })

AimTab:CreateDropdown({ Name = "Priority",
    Options = {"Closest to Crosshair","Lowest HP","Closest"},
    CurrentOption = {"Closest to Crosshair"}, Flag = "AimPrio",
    Callback = function(v) C.Aim.Priority = v[1] end })

AimTab:CreateDropdown({ Name = "Keybind",
    Options = {"Mouse2","Mouse1","LeftAlt","CapsLock","V","F","X"},
    CurrentOption = {"Mouse2"}, Flag = "AimKey",
    Callback = function(v)
        local b = {
            ["Mouse2"]=Enum.UserInputType.MouseButton2,
            ["Mouse1"]=Enum.UserInputType.MouseButton1,
            ["LeftAlt"]=Enum.KeyCode.LeftAlt,
            ["CapsLock"]=Enum.KeyCode.CapsLock,
            ["V"]=Enum.KeyCode.V,["F"]=Enum.KeyCode.F,["X"]=Enum.KeyCode.X,
        }
        C.Aim.Keybind = b[v[1]] or Enum.UserInputType.MouseButton2
    end })

AimTab:CreateToggle({ Name = "Prediction", CurrentValue = false, Flag = "AimPred",
    Callback = function(v) C.Aim.Prediction = v end })

AimTab:CreateToggle({ Name = "Visible Check", CurrentValue = false, Flag = "AimVis",
    Callback = function(v) C.Aim.VisibleCheck = v end })

AimTab:CreateToggle({ Name = "Dynamic Smooth", CurrentValue = false, Flag = "DynSmooth",
    Callback = function(v) C.Aim.DynamicSmooth = v end })

AimTab:CreateToggle({ Name = "Multi Bone Scan", CurrentValue = false, Flag = "MultiBone",
    Callback = function(v) C.Aim.MultiBoneScan = v end })

AimTab:CreateSection("Target System")

AimTab:CreateToggle({ Name = "Target Lock (Tecla E)", CurrentValue = false, Flag = "TLock",
    Callback = function(v)
        C.Aim.TargetLock = v
        if not v then State.lockActive = false State.lockedTarget = nil end
    end })

AimTab:CreateToggle({ Name = "Anti Switch", CurrentValue = true, Flag = "AntiSwitch",
    Callback = function(v) C.Aim.AntiSwitch = v end })

AimTab:CreateSlider({ Name = "Anti Switch Delay", Range = {5,30}, Increment = 1, Suffix = "x0.1s",
    CurrentValue = 15, Flag = "AntiSwitchDelay",
    Callback = function(v) C.Aim.AntiSwitchTime = v/10 end })

AimTab:CreateSection("Humanizer")

AimTab:CreateToggle({ Name = "Humanizer", CurrentValue = false, Flag = "Humanizer",
    Callback = function(v) C.Aim.Humanizer = v end })

AimTab:CreateSlider({ Name = "Tremor Strength", Range = {1,20}, Increment = 1, Suffix = "x0.1",
    CurrentValue = 2, Flag = "TremorStr",
    Callback = function(v) C.Aim.TremorStrength = v/10 end })

AimTab:CreateSlider({ Name = "Hit Chance", Range = {10,100}, Increment = 5, Suffix = "%",
    CurrentValue = 100, Flag = "HitChance",
    Callback = function(v) C.Aim.HitChance = v end })

AimTab:CreateSlider({ Name = "Aim Delay", Range = {0,300}, Increment = 10, Suffix = "ms",
    CurrentValue = 0, Flag = "AimDelay",
    Callback = function(v) C.Aim.AimDelay = v end })

AimTab:CreateSlider({ Name = "Random Offset", Range = {0,5}, Increment = 1, Suffix = "units",
    CurrentValue = 0, Flag = "RandOffset",
    Callback = function(v) C.Aim.RandomOffset = v end })

AimTab:CreateToggle({ Name = "Clutch Mode (Low HP)", CurrentValue = false, Flag = "Clutch",
    Callback = function(v) C.Aim.ClutchMode = v end })

AimTab:CreateSlider({ Name = "Clutch HP Threshold", Range = {10,60}, Increment = 5, Suffix = "HP",
    CurrentValue = 30, Flag = "ClutchHP",
    Callback = function(v) C.Aim.ClutchHP = v end })

AimTab:CreateToggle({ Name = "Fake Legit", CurrentValue = false, Flag = "FakeLegit",
    Callback = function(v) C.Misc.FakeLegit = v end })

AimTab:CreateSection("FOV Visual")

AimTab:CreateToggle({ Name = "FOV V1", CurrentValue = false, Flag = "FOV1",
    Callback = function(v) FOVring.Visible = v end })

AimTab:CreateToggle({ Name = "FOV V2", CurrentValue = false, Flag = "FOV2",
    Callback = function(v) FOVring2.Visible = v end })

AimTab:CreateColorPicker({ Name = "FOV V1 Color", Color = Color3.fromRGB(255,0,0), Flag = "FOV1C",
    Callback = function(v) FOVring.Color = v end })

AimTab:CreateColorPicker({ Name = "FOV V2 Color", Color = Color3.fromRGB(0,255,0), Flag = "FOV2C",
    Callback = function(v) FOVring2.Color = v end })

-- ========================
-- ABA: ESP (ARSENAL)
-- ========================
local ESPTab = Window:CreateTab("ESP", "eye")

local ESPLib = {
    Players = false,
    Boxes = false,
    Tracers = false,
    Names = false,
    TeamMates = false,
    TeamColor = false,
    Color = Color3.fromRGB(255,0,0),
}

-- Sincroniza as flags do ESPLib com o Config interno
local function syncESPLib()
    C.ESP.Enabled = ESPLib.Players
    C.ESP.Boxes = ESPLib.Boxes
    C.ESP.Tracers = ESPLib.Tracers
    C.ESP.Names = ESPLib.Names
end

ESPTab:CreateSection("ESP")

ESPTab:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "ESPOn",
    Callback = function(v)
        C.ESP.Enabled = v
        C.ESP.Visible = v
    end })

ESPTab:CreateToggle({ Name = "Boxes", CurrentValue = false, Flag = "ESPBox",
    Callback = function(v) C.ESP.Boxes = v end })

ESPTab:CreateToggle({ Name = "Tracers", CurrentValue = false, Flag = "ESPTrac",
    Callback = function(v) C.ESP.Tracers = v end })

ESPTab:CreateToggle({ Name = "Names", CurrentValue = false, Flag = "ESPNames",
    Callback = function(v) C.ESP.Names = v end })
ESPTab:CreateToggle({ Name = "Skeleton", CurrentValue = false, Flag = "ESPSkel",
    Callback = function(v) C.ESP.Skeleton = v end })

ESPTab:CreateToggle({ Name = "Health Bar", CurrentValue = false, Flag = "ESPHp",
    Callback = function(v) C.ESP.HealthBar = v end })

ESPTab:CreateToggle({ Name = "Distance", CurrentValue = false, Flag = "ESPDist",
    Callback = function(v) C.ESP.Distance = v end })

ESPTab:CreateToggle({ Name = "Off Screen Arrows", CurrentValue = false, Flag = "ESPOff",
    Callback = function(v) C.ESP.Offscreen = v end })

ESPTab:CreateToggle({ Name = "Chams", CurrentValue = false, Flag = "ESPChams",
    Callback = function(v) C.ESP.Chams = v end })

ESPTab:CreateToggle({ Name = "Trail ESP", CurrentValue = false, Flag = "ESPTrail",
    Callback = function(v) C.ESP.TrailESP = v end })

ESPTab:CreateToggle({ Name = "Danger Zone", CurrentValue = false, Flag = "ESPDanger",
    Callback = function(v) C.ESP.DangerZone = v end })

ESPTab:CreateToggle({ Name = "Gradient HP", CurrentValue = false, Flag = "ESPGrad",
    Callback = function(v) C.ESP.GradientHP = v end })

ESPTab:CreateSection("ESP Intelligence")

ESPTab:CreateToggle({ Name = "Visible Only", CurrentValue = false, Flag = "ESPVisOnly",
    Callback = function(v) C.ESP.VisibleOnly = v end })

ESPTab:CreateToggle({ Name = "Fade by Distance", CurrentValue = false, Flag = "ESPFade",
    Callback = function(v) C.ESP.FadeDistance = v end })

ESPTab:CreateToggle({ Name = "Priority Highlight", CurrentValue = false, Flag = "ESPPrio",
    Callback = function(v) C.ESP.PriorityHighlight = v end })

ESPTab:CreateSlider({ Name = "Priority Range", Range = {10,150}, Increment = 5, Suffix = "m",
    CurrentValue = 30, Flag = "ESPPrioRange",
    Callback = function(v) C.ESP.PriorityRange = v end })

ESPTab:CreateToggle({ Name = "Team Check", CurrentValue = true, Flag = "ESPTeam",
    Callback = function(v)
        C.ESP.TeamCheck = v
        ESPLib.TeamMates = not v
        ESPLib.TeamColor = not v
    end })

ESPTab:CreateToggle({ Name = "ESP Key Toggle (Z)", CurrentValue = false, Flag = "ESPKeyTog",
    Callback = function(v) C.ESP.KeyToggle = v end })

ESPTab:CreateColorPicker({ Name = "ESP Color", Color = Color3.fromRGB(255,0,0), Flag = "ESPColor",
    Callback = function(v) C.ESP.Color = v ESPLib.Color = v end })

ESPTab:CreateColorPicker({ Name = "Skeleton Color", Color = Color3.fromRGB(255,255,255), Flag = "SkelColor",
    Callback = function(v) C.ESP.SkeletonColor = v end })

ESPTab:CreateSection("Radar")

ESPTab:CreateToggle({ Name = "Radar", CurrentValue = false, Flag = "Radar",
    Callback = function(v) radarEnabled = v end })

ESPTab:CreateSlider({ Name = "Radar Range", Range = {50,500}, Increment = 10, Suffix = "studs",
    CurrentValue = 100, Flag = "RadarRange",
    Callback = function(v) radarRange = v end })

-- ========================
-- ABA: PLAYER (ARSENAL)
-- ========================
local PlayerTab = Window:CreateTab("Player", "user")

PlayerTab:CreateSection("Movement")

PlayerTab:CreateToggle({ Name = "Fly", CurrentValue = false, Flag = "Fly",
    Callback = function(v)
        if v then startFly(isMobile,"flyEnabled","flyConn",function() return C.Player.FlySpeed end)
        else stopFly("flyEnabled","flyConn") end
    end })

PlayerTab:CreateSlider({ Name = "Fly Speed", Range = {10,400}, Increment = 5, Suffix = "Speed",
    CurrentValue = 50, Flag = "FlySpeed",
    Callback = function(v) C.Player.FlySpeed = v end })

PlayerTab:CreateToggle({ Name = "Walk Speed", CurrentValue = false, Flag = "WS",
    Callback = function(v)
        C.Player.WSEnabled = v
        if not v then
            local char = LP.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = 16 end
        end
    end })

PlayerTab:CreateSlider({ Name = "Walk Speed Value", Range = {16,500}, Increment = 1, Suffix = "Speed",
    CurrentValue = 16, Flag = "WSVal",
    Callback = function(v) C.Player.WalkSpeed = v end })

PlayerTab:CreateToggle({ Name = "Jump Power", CurrentValue = false, Flag = "JP",
    Callback = function(v)
        C.Player.JPEnabled = v
        if not v then
            local char = LP.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.JumpPower = 50 end
        end
    end })

PlayerTab:CreateSlider({ Name = "Jump Power Value", Range = {50,500}, Increment = 1, Suffix = "Power",
    CurrentValue = 50, Flag = "JPVal",
    Callback = function(v) C.Player.JumpPower = v end })

PlayerTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Flag = "Noclip",
    Callback = function(v) C.Player.Noclip = v end })

PlayerTab:CreateToggle({ Name = "Anti Ragdoll", CurrentValue = false, Flag = "AntiRag",
    Callback = function(v) C.Player.AntiRagdoll = v end })

PlayerTab:CreateToggle({ Name = "Anti Fall Damage", CurrentValue = false, Flag = "AntiFall",
    Callback = function(v) C.Player.AntiFall = v end })

PlayerTab:CreateToggle({ Name = "Bunny Hop", CurrentValue = false, Flag = "BHop",
    Callback = function(v) C.Player.BunnyHop = v end })

PlayerTab:CreateToggle({ Name = "Strafe Assist", CurrentValue = false, Flag = "Strafe",
    Callback = function(v) C.Player.Strafe = v end })

PlayerTab:CreateToggle({ Name = "Quick Stop", CurrentValue = false, Flag = "QStop",
    Callback = function(v) C.Player.QuickStop = v end })

PlayerTab:CreateToggle({ Name = "Anti Lock", CurrentValue = false, Flag = "AntiLock",
    Callback = function(v) C.Player.AntiLock = v end })

PlayerTab:CreateLabel("Dash: Pressione Q")

PlayerTab:CreateSection("Teleport")

PlayerTab:CreateToggle({ Name = "Click TP", CurrentValue = false, Flag = "ClickTP",
    Callback = function(v)
        State.tpEnabled = v
        if v then
            State.tpConn = UIS.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 and State.tpEnabled then
                    local unitRay = Cam:ScreenPointToRay(input.Position.X, input.Position.Y)
                    local ray = Ray.new(unitRay.Origin, unitRay.Direction * 500)
                    local hit, pos = workspace:FindPartOnRay(ray, LP.Character)
                    if hit then
                        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0)) end
                    end
                end
            end)
        else
            if State.tpConn then State.tpConn:Disconnect() end
        end
    end })

PlayerTab:CreateDropdown({
    Name = "TP to Player",
    Options = (function()
        local names = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(names, p.Name) end
        end
        if #names == 0 then names = {"None"} end
        return names
    end)(),
    CurrentOption = {},
    Flag = "TPPlayer",
    Callback = function(v)
        local t = Players:FindFirstChild(v[1])
        if t and t.Character then
            local hrp = t.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp and myHRP then
                myHRP.CFrame = hrp.CFrame + Vector3.new(0,3,0)
                Rayfield:Notify({ Title = "TP", Content = "Teleported to " .. v[1], Duration = 3 })
            end
        end
    end,
})

-- ========================
-- ABA: COMBAT (ARSENAL)
-- ========================
local CombatTab = Window:CreateTab("Combat", "sword")

CombatTab:CreateSection("Hitbox")

CombatTab:CreateToggle({ Name = "Hitbox", CurrentValue = false, Flag = "Hitbox",
    Callback = function(v)
        C.Combat.Hitbox = v
        if not v then removeHitbox(State.originalSizes) end
    end })

CombatTab:CreateToggle({ Name = "Team Check Hitbox", CurrentValue = true, Flag = "HitboxTeam",
    Callback = function(v) C.Combat.HitboxTeamCheck = v end })

CombatTab:CreateSection("Gun Mods")

CombatTab:CreateButton({ Name = "Inf Ammo",
    Callback = function()
        task.spawn(function()
            while task.wait() do
                local gui = LP.PlayerGui
                local g = gui:FindFirstChild("GUI")
                if g then
                    local cl = g:FindFirstChild("Client")
                    local vars = cl and cl:FindFirstChild("Variables")
                    if vars then
                        if vars:FindFirstChild("ammocount") then vars.ammocount.Value = 999 end
                        if vars:FindFirstChild("ammocount2") then vars.ammocount2.Value = 999 end
                    end
                end
            end
        end)
        Rayfield:Notify({ Title = "Inf Ammo", Content = "Active!", Duration = 3 })
    end })

CombatTab:CreateButton({ Name = "Rapid Fire",
    Callback = function()
        local rs = game.ReplicatedStorage
        if rs:FindFirstChild("Weapons") then
            for _, v in pairs(rs.Weapons:GetDescendants()) do
                if v.Name == "FireRate" then v.Value = 0.01 end
            end
        end
        Rayfield:Notify({ Title = "Rapid Fire", Content = "Active!", Duration = 3 })
    end })

CombatTab:CreateToggle({ Name = "No Recoil", CurrentValue = false, Flag = "NoRecoil",
    Callback = function(v)
        C.Combat.NoRecoil = v
        if v then
            local rs = game.ReplicatedStorage
            if rs:FindFirstChild("Weapons") then
                for _, obj in pairs(rs.Weapons:GetDescendants()) do
                    if obj.Name == "Recoil" or obj.Name == "VerticalRecoil" or obj.Name == "HorizontalRecoil" then
                        obj.Value = 0
                    end
                end
            end
        end
    end })

CombatTab:CreateToggle({ Name = "No Spread", CurrentValue = false, Flag = "NoSpread",
    Callback = function(v)
        C.Combat.NoSpread = v
        if v then
            local rs = game.ReplicatedStorage
            if rs:FindFirstChild("Weapons") then
                for _, obj in pairs(rs.Weapons:GetDescendants()) do
                    if obj.Name == "Spread" or obj.Name == "SpreadAngle" then obj.Value = 0 end
                end
            end
        end
    end })

CombatTab:CreateToggle({ Name = "Hit Sound", CurrentValue = false, Flag = "HitSound",
    Callback = function(v) C.Combat.HitSound = v end })

CombatTab:CreateToggle({ Name = "Hitmarker", CurrentValue = false, Flag = "Hitmarker",
    Callback = function(v) C.Combat.Hitmarker = v end })

CombatTab:CreateSection("Weapon Config")

CombatTab:CreateButton({ Name = "Save Weapon Config",
    Callback = function()
        if lastWeapon then
            weaponConfigs[lastWeapon] = {FOV = C.Aim.FOV, Smooth = C.Aim.Smooth}
            Rayfield:Notify({ Title = "Weapon Config", Content = "Saved: " .. lastWeapon, Duration = 3 })
        else
            Rayfield:Notify({ Title = "Weapon Config", Content = "No weapon equipped!", Duration = 3 })
        end
    end })

-- ========================
-- ABA: HYPERSHOT
-- ========================
local HsyTab = Window:CreateTab("Hypershot", "target")

HsyTab:CreateSection("Hypershot Aimbot")
HsyTab:CreateLabel("Configs separadas para o Hypershot")

HsyTab:CreateToggle({ Name = "Aimbot", CurrentValue = false, Flag = "HsyAimOn",
    Callback = function(v) C.Hypershot.AimbotEnabled = v end })

HsyTab:CreateSlider({ Name = "FOV", Range = {10,400}, Increment = 5, Suffix = "px",
    CurrentValue = 120, Flag = "HsyFOV",
    Callback = function(v) C.Hypershot.AimbotFOV = v hsyFOVring.Radius = v end })

HsyTab:CreateSlider({ Name = "Smooth", Range = {1,20}, Increment = 1, Suffix = "x",
    CurrentValue = 3, Flag = "HsySmooth",
    Callback = function(v) C.Hypershot.AimbotSmooth = v/20 end })

HsyTab:CreateDropdown({ Name = "Aim Bone",
    Options = {"Head","UpperTorso","LowerTorso","Random"},
    CurrentOption = {"Head"}, Flag = "HsyBone",
    Callback = function(v) C.Hypershot.AimbotBone = v[1] end })

HsyTab:CreateToggle({ Name = "Prediction", CurrentValue = false, Flag = "HsyPred",
    Callback = function(v) C.Hypershot.AimbotPrediction = v end })

HsyTab:CreateToggle({ Name = "Visible Check", CurrentValue = false, Flag = "HsyVis",
    Callback = function(v) C.Hypershot.AimbotVisible = v end })

HsyTab:CreateDropdown({ Name = "Keybind",
    Options = {"Mouse2","Mouse1","LeftAlt","CapsLock","V","F"},
    CurrentOption = {"Mouse2"}, Flag = "HsyKey",
    Callback = function(v)
        local b = {
            ["Mouse2"]=Enum.UserInputType.MouseButton2,
            ["Mouse1"]=Enum.UserInputType.MouseButton1,
            ["LeftAlt"]=Enum.KeyCode.LeftAlt,
            ["CapsLock"]=Enum.KeyCode.CapsLock,
            ["V"]=Enum.KeyCode.V,
            ["F"]=Enum.KeyCode.F,
        }
        C.Hypershot.AimbotKeybind = b[v[1]] or Enum.UserInputType.MouseButton2
    end })

HsyTab:CreateToggle({ Name = "FOV Ring", CurrentValue = false, Flag = "HsyFOVRing",
    Callback = function(v) hsyFOVring.Visible = v end })

HsyTab:CreateColorPicker({ Name = "FOV Color", Color = Color3.fromRGB(0,200,255), Flag = "HsyFOVColor",
    Callback = function(v) hsyFOVring.Color = v end })

HsyTab:CreateSection("Hypershot Hitbox")

HsyTab:CreateToggle({ Name = "Hitbox", CurrentValue = false, Flag = "HsyHitbox",
    Callback = function(v)
        C.Hypershot.Hitbox = v
        if not v then removeHitbox(State.hsyOriginalSizes) end
    end })

HsyTab:CreateSlider({ Name = "Hitbox Size", Range = {5,30}, Increment = 1, Suffix = "units",
    CurrentValue = 15, Flag = "HsyHitboxSize",
    Callback = function(v) C.Hypershot.HitboxSize = v end })

HsyTab:CreateToggle({ Name = "Team Check Hitbox", CurrentValue = true, Flag = "HsyHitboxTeam",
    Callback = function(v) C.Hypershot.HitboxTeamCheck = v end })

HsyTab:CreateSection("Hypershot ESP")

HsyTab:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "HsyESPOn",
    Callback = function(v) C.Hypershot.ESPEnabled = v end })

HsyTab:CreateToggle({ Name = "Boxes", CurrentValue = false, Flag = "HsyESPBox",
    Callback = function(v) C.Hypershot.ESPBoxes = v end })

HsyTab:CreateToggle({ Name = "Names", CurrentValue = false, Flag = "HsyESPNames",
    Callback = function(v) C.Hypershot.ESPNames = v end })

HsyTab:CreateToggle({ Name = "Skeleton", CurrentValue = false, Flag = "HsyESPSkel",
    Callback = function(v) C.Hypershot.ESPSkeleton = v end })

HsyTab:CreateToggle({ Name = "Health Bar", CurrentValue = false, Flag = "HsyESPHp",
    Callback = function(v) C.Hypershot.ESPHealthBar = v end })

HsyTab:CreateToggle({ Name = "Tracers", CurrentValue = false, Flag = "HsyESPTrac",
    Callback = function(v) C.Hypershot.ESPTracers = v end })

HsyTab:CreateToggle({ Name = "Team Check ESP", CurrentValue = true, Flag = "HsyESPTeam",
    Callback = function(v) C.Hypershot.ESPTeamCheck = v end })

HsyTab:CreateColorPicker({ Name = "ESP Color", Color = Color3.fromRGB(0,200,255), Flag = "HsyESPColor",
    Callback = function(v) C.Hypershot.ESPColor = v end })

HsyTab:CreateSection("Hypershot Movement")

HsyTab:CreateToggle({ Name = "Fly", CurrentValue = false, Flag = "HsyFly",
    Callback = function(v)
        if v then startFly(isMobile,"hsyFlyEnabled","hsyFlyConn",function() return C.Hypershot.FlySpeed end)
        else stopFly("hsyFlyEnabled","hsyFlyConn") end
    end })

HsyTab:CreateSlider({ Name = "Fly Speed", Range = {10,300}, Increment = 5, Suffix = "Speed",
    CurrentValue = 50, Flag = "HsyFlySpeed",
    Callback = function(v) C.Hypershot.FlySpeed = v end })

HsyTab:CreateToggle({ Name = "Walk Speed", CurrentValue = false, Flag = "HsyWS",
    Callback = function(v)
        C.Hypershot.WalkSpeed = v
        if not v then
            local char = LP.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = 16 end
        end
    end })

HsyTab:CreateSlider({ Name = "Walk Speed Value", Range = {16,300}, Increment = 1, Suffix = "Speed",
    CurrentValue = 30, Flag = "HsyWSVal",
    Callback = function(v) C.Hypershot.WalkSpeedValue = v end })

HsyTab:CreateToggle({ Name = "Jump Power", CurrentValue = false, Flag = "HsyJP",
    Callback = function(v)
        C.Hypershot.JumpPower = v
        if not v then
            local char = LP.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.JumpPower = 50 end
        end
    end })

HsyTab:CreateSlider({ Name = "Jump Power Value", Range = {50,500}, Increment = 1, Suffix = "Power",
    CurrentValue = 100, Flag = "HsyJPVal",
    Callback = function(v) C.Hypershot.JumpPowerValue = v end })

HsyTab:CreateToggle({ Name = "Bunny Hop", CurrentValue = false, Flag = "HsyBHop",
    Callback = function(v) C.Hypershot.BunnyHop = v end })

HsyTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Flag = "HsyNoclip",
    Callback = function(v) C.Hypershot.Noclip = v end })

HsyTab:CreateToggle({ Name = "Anti Ragdoll", CurrentValue = false, Flag = "HsyAntiRag",
    Callback = function(v) C.Hypershot.AntiRagdoll = v end })

HsyTab:CreateToggle({ Name = "Anti Fall Damage", CurrentValue = false, Flag = "HsyAntiFall",
    Callback = function(v) C.Hypershot.AntiFall = v end })

HsyTab:CreateSection("Hypershot Gun Mods")

HsyTab:CreateToggle({ Name = "Inf Ammo", CurrentValue = false, Flag = "HsyInfAmmo",
    Callback = function(v) C.Hypershot.InfAmmo = v end })

HsyTab:CreateToggle({ Name = "No Recoil", CurrentValue = false, Flag = "HsyNoRecoil",
    Callback = function(v)
        C.Hypershot.NoRecoil = v
        if v then
            local rs = game.ReplicatedStorage
            if rs:FindFirstChild("Weapons") then
                for _, obj in pairs(rs.Weapons:GetDescendants()) do
                    if obj.Name == "Recoil" or obj.Name == "VerticalRecoil" then obj.Value = 0 end
                end
            end
        end
    end })

HsyTab:CreateToggle({ Name = "No Spread", CurrentValue = false, Flag = "HsyNoSpread",
    Callback = function(v)
        C.Hypershot.NoSpread = v
        if v then
            local rs = game.ReplicatedStorage
            if rs:FindFirstChild("Weapons") then
                for _, obj in pairs(rs.Weapons:GetDescendants()) do
                    if obj.Name == "Spread" or obj.Name == "SpreadAngle" then obj.Value = 0 end
                end
            end
        end
    end })

HsyTab:CreateToggle({ Name = "Hit Sound", CurrentValue = false, Flag = "HsyHitSound",
    Callback = function(v) C.Hypershot.HitSound = v end })

HsyTab:CreateToggle({ Name = "Hitmarker", CurrentValue = false, Flag = "HsyHitmarker",
    Callback = function(v) C.Hypershot.Hitmarker = v end })

HsyTab:CreateSection("Hypershot Misc")

HsyTab:CreateToggle({ Name = "Full Bright", CurrentValue = false, Flag = "HsyFB",
    Callback = function(v)
        C.Hypershot.FullBright = v
        if v then enableFullbright() else disableFullbright() end
    end })

HsyTab:CreateToggle({ Name = "FPS Boost", CurrentValue = false, Flag = "HsyFPSBoost",
    Callback = function(v)
        C.Hypershot.FPSBoost = v
        if v then enableFPSBoost() else disableFPSBoost() end
    end })

-- ========================
-- ABA: VISUALS
-- ========================
local VisualTab = Window:CreateTab("Visuals", "sparkles")

VisualTab:CreateSection("Misc Visuals")

VisualTab:CreateToggle({ Name = "Crosshair", CurrentValue = false, Flag = "Crosshair",
    Callback = function(v)
        crosshairEnabled = v
        if not v then for _, l in pairs(crosshairLines) do l.Visible = false end crosshairLines = {} end
    end })

VisualTab:CreateSlider({ Name = "Crosshair Size", Range = {5,50}, Increment = 1, Suffix = "px",
    CurrentValue = 10, Flag = "CrosshairSize",
    Callback = function(v) crosshairSize = v end })

VisualTab:CreateSlider({ Name = "Crosshair Gap", Range = {0,20}, Increment = 1, Suffix = "px",
    CurrentValue = 5, Flag = "CrosshairGap",
    Callback = function(v) crosshairGap = v end })

VisualTab:CreateColorPicker({ Name = "Crosshair Color", Color = Color3.fromRGB(255,255,255), Flag = "CrossColor",
    Callback = function(v) crosshairColor = v end })

VisualTab:CreateToggle({ Name = "Full Bright", CurrentValue = false, Flag = "FullBright",
    Callback = function(v) if v then enableFullbright() else disableFullbright() end end })

VisualTab:CreateToggle({ Name = "FPS Counter", CurrentValue = false, Flag = "FPSCount",
    Callback = function(v) fpsLabel.Visible = v end })

VisualTab:CreateToggle({ Name = "Session Timer", CurrentValue = false, Flag = "Timer",
    Callback = function(v) timerLabel.Visible = v end })

-- ========================
-- ABA: MOBILE
-- ========================
local MobileTab = Window:CreateTab("Mobile", "smartphone")
MobileTab:CreateSection("Mobile Mode")
MobileTab:CreateLabel("Detected: " .. (isMobile and "Mobile" or "PC"))

MobileTab:CreateToggle({ Name = "Mobile Buttons", CurrentValue = isMobile, Flag = "MobileBtn",
    Callback = function(v)
        if v then createMobileButtons()
        else if mobileGui then mobileGui:Destroy() mobileGui = nil end end
    end })

MobileTab:CreateToggle({ Name = "Auto Aim Mobile", CurrentValue = false, Flag = "MobileAim",
    Callback = function(v) State.mobileAim = v C.Aim.Enabled = v end })

MobileTab:CreateSlider({ Name = "Mobile FOV", Range = {10,400}, Increment = 5, Suffix = "px",
    CurrentValue = 150, Flag = "MobileFOV",
    Callback = function(v) C.Aim.FOV = v end })

MobileTab:CreateToggle({ Name = "FPS Boost Mobile", CurrentValue = false, Flag = "MobileFPS",
    Callback = function(v) if v then enableFPSBoost() else disableFPSBoost() end end })

-- ========================
-- ABA: PC
-- ========================
local PCTab = Window:CreateTab("PC", "monitor")
PCTab:CreateSection("PC Mode")

PCTab:CreateToggle({ Name = "Keybind Overlay", CurrentValue = false, Flag = "KBOverlay",
    Callback = function(v)
        if v then createKeybindOverlay()
        else if keybindGui then keybindGui:Destroy() keybindGui = nil end end
    end })

PCTab:CreateToggle({ Name = "FPS Boost", CurrentValue = false, Flag = "FPSBoost",
    Callback = function(v) if v then enableFPSBoost() else disableFPSBoost() end end })

PCTab:CreateToggle({ Name = "Adaptive FPS Boost", CurrentValue = false, Flag = "AdaptFPS",
    Callback = function(v) C.Performance.AdaptiveFPS = v end })

PCTab:CreateSlider({ Name = "FPS Limiter", Range = {0,144}, Increment = 5, Suffix = "FPS",
    CurrentValue = 0, Flag = "FPSLimit",
    Callback = function(v) C.Performance.FPSLimit = v end })

-- ========================
-- ABA: MISC
-- ========================
local MiscTab = Window:CreateTab("Misc", "settings")

MiscTab:CreateSection("Utilities")

MiscTab:CreateToggle({ Name = "Enemy Warning", CurrentValue = false, Flag = "EnemyWarn",
    Callback = function(v) C.Misc.EnemyWarning = v end })

MiscTab:CreateSlider({ Name = "Warning Range", Range = {10,200}, Increment = 5, Suffix = "m",
    CurrentValue = 50, Flag = "WarnRange",
    Callback = function(v) C.Misc.EnemyWarningRange = v end })

MiscTab:CreateToggle({ Name = "Spectator Detection", CurrentValue = false, Flag = "SpectDet",
    Callback = function(v) C.Misc.SpectatorDetection = v end })

MiscTab:CreateToggle({ Name = "Anti Spectator", CurrentValue = false, Flag = "AntiSpect",
    Callback = function(v) C.Misc.AntiSpectator = v end })

MiscTab:CreateToggle({ Name = "Risk System", CurrentValue = false, Flag = "RiskSys",
    Callback = function(v) C.Misc.RiskSystem = v end })

MiscTab:CreateToggle({ Name = "Stream Mode (F8)", CurrentValue = false, Flag = "StreamMode",
    Callback = function(v) C.Misc.StreamMode = v setStreamMode(v) end })

MiscTab:CreateToggle({ Name = "Anti AFK", CurrentValue = false, Flag = "AntiAFK",
    Callback = function(v)
        C.Misc.AntiAFK = v
        if v then
            task.spawn(function()
                while C.Misc.AntiAFK do
                    task.wait(55)
                    local VU = game:GetService("VirtualUser")
                    VU:CaptureController()
                    VU:ClickButton2(Vector2.new())
                end
            end)
        end
    end })

MiscTab:CreateSection("Themes")

MiscTab:CreateDropdown({
    Name = "Select Theme",
    Options = {"Default","Ocean","Amethyst","Green","Light","Dark"},
    CurrentOption = {"Default"},
    Flag = "Theme",
    Callback = function(v)
        local theme = v[1]
        local ok = pcall(function() Rayfield:SetTheme(theme) end)
        if not ok then pcall(function() Window:ChangeTheme(theme) end) end
        Rayfield:Notify({ Title = "Theme", Content = theme .. " applied!", Duration = 3 })
    end,
})

-- ========================
-- ABA: CONFIG
-- ========================
local ConfigTab = Window:CreateTab("Config", "settings")
ConfigTab:CreateLabel("Arsenal Script v4.1 | By Toddyx")

ConfigTab:CreateButton({ Name = "Hot Reload",
    Callback = function()
        Rayfield:LoadConfiguration()
        Rayfield:Notify({ Title = "Config", Content = "Reloaded!", Duration = 3 })
    end })

ConfigTab:CreateButton({ Name = "Destroy UI",
    Callback = function()
        stopFly("flyEnabled","flyConn")
        stopFly("hsyFlyEnabled","hsyFlyConn")
        disableFPSBoost()
        disableFullbright()
        removeHitbox(State.originalSizes)
        removeHitbox(State.hsyOriginalSizes)
        for _, p in pairs(Players:GetPlayers()) do
            if ESPCache[p.UserId] then removeESPForPlayer(p.UserId) end
        end
        for _, d in pairs(radarDots) do d:Remove() end
        for _, l in pairs(crosshairLines) do l:Remove() end
        if mobileGui then mobileGui:Destroy() end
        if keybindGui then keybindGui:Destroy() end
        warningLabel:Remove()
        debugLabel:Remove()
        fpsLabel:Remove()
        timerLabel:Remove()
        FOVring:Remove()
        FOVring2:Remove()
        hsyFOVring:Remove()
        if State.tpConn then State.tpConn:Disconnect() end
        Rayfield:Destroy()
    end })

-- ========================
-- ABA: DEV (ACESSO RESTRITO)
-- ========================
local DevTab = Window:CreateTab("DEV", "code")
DevTab:CreateSection("Developer Access")
DevTab:CreateLabel("Enter your Roblox username to unlock")

-- Variável para guardar o que foi digitado
local devInputValue = ""

DevTab:CreateInput({
    Name = "Username",
    PlaceholderText = "Digite seu nick e pressione Enter...",
    RemoveTextAfterFocusLost = false,
    Flag = "DevInput",
    Callback = function(v)
        -- Só guarda o valor, não verifica ainda
        devInputValue = v
    end,
})

-- Botão separado para confirmar — evita verificar a cada letra
DevTab:CreateButton({
    Name = "Confirmar Acesso",
    Callback = function()
        local playerName = LP.Name
        -- Verifica: o que foi digitado == nome do player == nick autorizado
        if devInputValue == playerName and playerName == "zoompro177" then
            State.devAccess = true
            C.Misc.DebugMode = true
            debugLabel.Visible = true
            Rayfield:Notify({
                Title = "DEV ACCESS GRANTED",
                Content = "Welcome, " .. playerName .. "! All tools unlocked.",
                Duration = 5,
            })
        else
            State.devAccess = false
            Rayfield:Notify({
                Title = "Access Denied",
                Content = "Incorrect. Expected your own username.",
                Duration = 3,
            })
        end
        devInputValue = ""
    end,
})
DevTab:CreateSection("Dev Tools")

DevTab:CreateToggle({ Name = "Debug Panel", CurrentValue = false, Flag = "DebugPanel",
    Callback = function(v)
        if not State.devAccess then
            Rayfield:Notify({ Title = "Locked", Content = "Enter dev credentials first!", Duration = 3 })
            return
        end
        C.Misc.DebugMode = v
        debugLabel.Visible = v
    end })

DevTab:CreateButton({ Name = "Print Spectators",
    Callback = function()
        if not State.devAccess then
            Rayfield:Notify({ Title = "Locked", Content = "No access!", Duration = 3 })
            return
        end
        local spec = #State.spectators > 0 and table.concat(State.spectators, ", ") or "None"
        Rayfield:Notify({ Title = "Spectators (" .. #State.spectators .. ")", Content = spec, Duration = 5 })
    end })

DevTab:CreateButton({ Name = "Print Target Info",
    Callback = function()
        if not State.devAccess then
            Rayfield:Notify({ Title = "Locked", Content = "No access!", Duration = 3 })
            return
        end
        local t = State.currentTarget
        if t then
            Rayfield:Notify({
                Title = "Target: " .. t.Name,
                Content = string.format("HP: %d | Dist: %dm | Threat: %s | Locked: %s",
                    math.floor(Utils.getHP(t)),
                    math.floor(Utils.getDistance(t)),
                    Brain.isThreat(t) and "YES" or "NO",
                    State.lockActive and "YES" or "NO"
                ),
                Duration = 5,
            })
        else
            Rayfield:Notify({ Title = "No Target", Content = "No target in FOV", Duration = 3 })
        end
    end })

DevTab:CreateButton({ Name = "Print FPS / Ping",
    Callback = function()
        if not State.devAccess then return end
        Rayfield:Notify({
            Title = "Performance",
            Content = string.format("FPS: %d | Ping: %dms | Stress: %d%%",
                State.fps, math.floor(State.ping), math.floor(Brain.getStress()*100)
            ),
            Duration = 5,
        })
    end })

-- ========================
-- INIT
-- ========================
Rayfield:LoadConfiguration()

if isMobile then
    task.wait(2)
    createMobileButtons()
    Rayfield:Notify({ Title = "Mobile Detected!", Content = "Buttons active!", Duration = 4 })
end

Rayfield:Notify({ Title = "Arsenal Script v4.1", Content = "Loaded! F8=Stream | F9=Panic", Duration = 5 })
