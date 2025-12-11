local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local PlaceId = game.PlaceId

local Collection = {}
local LastPosition = Vector3.new(0, 0, 0)
local AFKTimer = 0
local IsHopping = false

local function Debug_Log(...)
    if getgenv().Config.Debug then
        print("[Auto-System]:", ...)
    end
end

function Collection:GetSelfDistance(Object)
    local _Magnitude = 9999
    local success, _ = pcall(function()
        if not LocalPlayer.Character then return end
        
        local Position = (typeof(Object) == "CFrame") and Object.Position or Object
        local RootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if RootPart then
            _Magnitude = (RootPart.Position - Position).Magnitude
        end
    end)
    return _Magnitude
end

function Collection:HopLowServer()
    if IsHopping then return end
    IsHopping = true
    
    Debug_Log("Finding low population server...")
    local Api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    
    local function TryHop()
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(Api))
        end)
        
        if success and result and result.data then
            for _, server in pairs(result.data) do
                if type(server) == "table" and server.id ~= game.JobId and server.playing > 0 and server.playing < server.maxPlayers then
                    Debug_Log("Found Server! Players: " .. server.playing .. " | Hopping...")
                    TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                    task.delay(10, function() 
                        IsHopping = false 
                    end)
                    return true
                end
            end
        end
        return false
    end
    
    if not TryHop() then
        Debug_Log("Could not find a better server, retrying shortly...")
        IsHopping = false
    end
end

function Collection:CheckCrowdAndHop()
    if IsHopping then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local NearbyCount = 0
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = Collection:GetSelfDistance(player.Character.HumanoidRootPart.Position)
            if dist < getgenv().Config.CheckRadius then
                NearbyCount = NearbyCount + 1
            end
        end
    end
    
    Debug_Log("Players Nearby:", NearbyCount)

    if NearbyCount > getgenv().Config.MaxPlayers then
        warn("!!! Too Crowded ("..NearbyCount.." Players) -> HOPPING SERVER !!!")
        Collection:HopLowServer()
    end
end

function Collection:CheckStuckStatus()
    if IsHopping or not getgenv().Config.AFK_Enabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local CurrentPos = LocalPlayer.Character.HumanoidRootPart.Position
    local DistMoved = (CurrentPos - LastPosition).Magnitude

    if DistMoved < getgenv().Config.AFK_MoveRadius then
        AFKTimer = AFKTimer + getgenv().Config.CheckInterval
        Debug_Log("AFK Timer: " .. AFKTimer .. "/" .. getgenv().Config.AFK_TimeLimit)

        if AFKTimer >= getgenv().Config.AFK_TimeLimit then
            warn("!!! Character Stuck/AFK for "..AFKTimer.."s -> HOPPING SERVER !!!")
            Collection:HopLowServer()
            AFKTimer = 0
        end
    else
        AFKTimer = 0
        LastPosition = CurrentPos
    end
end

task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(5)
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LastPosition = LocalPlayer.Character.HumanoidRootPart.Position
    end
    
    Debug_Log("Auto Control Started (Crowd + Anti-Stuck)...")
    
    while true do
        pcall(function()
            Collection:CheckCrowdAndHop()
            Collection:CheckStuckStatus()
        end)
        task.wait(getgenv().Config.CheckInterval)
    end
end)
