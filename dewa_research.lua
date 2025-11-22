local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local RESEARCH = {
    Config = {
        WebhookURL = "https://ptb.discord.com/api/webhooks/1441678001396776970/_v41PNSbfFd76m9C4Iirb79RaYdRsFSpL91JwqltiPTQPimg5WvkTJAGolh4Hx_wxzgV",
        InstantResearch = false,
        AntiLagResearch = false,
        FishDataResearch = false,
        LocationResearch = false,
        DiscoveryMode = false,
        MaxTimeout = 5,
        EnableValidation = true,
        FullAutoMode = false,
        AutoSequence = {
            {name = "Instant", delay = 5, duration = 300},
            {name = "AntiLag", delay = 10, duration = 180},
            {name = "Location", delay = 10, duration = 120},
            {name = "FishData", delay = 10, duration = 240},
            {name = "Discovery", delay = 15, duration = 180}
        },
        AutoGenerateReport = false
    },
    
    State = {
        DiscoveredRemotes = {},
        TestedConfigs = {},
        FPSBaseline = 0,
        FPSResults = {},
        BestInstantMethod = nil,
        BestAntiLag = nil,
        CapturedCalls = {},
        SuccessfulTests = {},
        FailedTests = {},
        Hook = nil,
        OriginalSettings = {},
        DisabledObjects = {},
        ModifiedSettings = false,
        FishDatabase = {},
        SecretFishFound = {},
        InjectionTests = {},
        BestInjectionMethod = nil,
        FishingLocations = {},
        TeleportTests = {},
        WorkingTeleports = {},
        BestFishingSpot = nil,
        DiscoveredPatterns = {},
        UnknownSuccesses = {},
        ErrorLog = {},
        TestedHashes = {}
    },
    
    Threads = {},
    GUI = {}
}

function RESEARCH:SendWebhook(title, description, color, fields)
    task.spawn(function()
        pcall(function()
            local embed = {
                title = title,
                description = description,
                color = color or 65280,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
                fields = fields or {},
                footer = {text = "DEWA RESEARCH | " .. Player.Name}
            }
            
            local payload = HttpService:JSONEncode({embeds = {embed}})
            local requestFunc = request or http_request or syn and syn.request
            
            if requestFunc then
                requestFunc({
                    Url = self.Config.WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            end
        end)
    end)
end

function RESEARCH:SendWebhookFile(filename, content, message)
    task.spawn(function()
        pcall(function()
            local boundary = "----WebKitFormBoundary" .. tostring(math.random(1000000, 9999999))
            local requestFunc = request or http_request or syn and syn.request
            
            if not requestFunc then return end
            
            local body = "--" .. boundary .. "\r\n"
            body = body .. "Content-Disposition: form-data; name=\"content\"\r\n\r\n"
            body = body .. (message or "Research Report") .. "\r\n"
            body = body .. "--" .. boundary .. "\r\n"
            body = body .. "Content-Disposition: form-data; name=\"file\"; filename=\"" .. filename .. "\"\r\n"
            body = body .. "Content-Type: text/plain\r\n\r\n"
            body = body .. content .. "\r\n"
            body = body .. "--" .. boundary .. "--\r\n"
            
            requestFunc({
                Url = self.Config.WebhookURL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
                },
                Body = body
            })
        end)
    end)
end

function RESEARCH:UpdateStatus(text)
    if self.GUI.StatusLabel then
        self.GUI.StatusLabel.Text = text
    end
end

function RESEARCH:LogError(context, error)
    local errorEntry = {
        Context = context,
        Error = tostring(error),
        Time = os.date("%H:%M:%S"),
        Timestamp = tick()
    }
    
    table.insert(self.State.ErrorLog, errorEntry)
    
    if #self.State.ErrorLog % 5 == 0 then
        self:SendWebhook(
            "⚠️ Error Logged",
            string.format("%s: %s", context, tostring(error):sub(1, 200)),
            16776960
        )
    end
end

function RESEARCH:ValidateRemote(remote)
    if not remote or not remote.Object then
        return false, "Invalid remote object"
    end
    
    if not remote.Object.Parent then
        return false, "Remote has no parent"
    end
    
    local success = pcall(function()
        local _ = remote.Object.Name
    end)
    
    if not success then
        return false, "Remote no longer exists"
    end
    
    return true, "Valid"
end

function RESEARCH:GenerateTestHash(remote, args)
    local argsStr = HttpService:JSONEncode(args)
    return remote.Name .. "_" .. argsStr
end

function RESEARCH:HasBeenTested(hash)
    return self.State.TestedHashes[hash] ~= nil
end

function RESEARCH:MarkTested(hash)
    self.State.TestedHashes[hash] = true
end

function RESEARCH:AutoSaveProgress(testType, data)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local filename = string.format("DEWA_AutoSave_%s.txt", Player.Name)
    
    local entry = string.format(
        "\n[%s] %s TEST\n" ..
        "Time: %s\n" ..
        "Data: %s\n" ..
        "---\n",
        timestamp,
        testType,
        timestamp,
        HttpService:JSONEncode(data)
    )
    
    if writefile then
        pcall(function()
            local existing = ""
            if isfile and isfile(filename) then
                existing = readfile(filename)
            end
            writefile(filename, existing .. entry)
        end)
    end
    
    self:SendWebhook(
        "💾 Auto-Saved: " .. testType,
        "Progress saved to file: " .. filename,
        3447003
    )
end

function RESEARCH:GetFPS()
    local success, fps = pcall(function()
        return math.floor(1 / Stats.RenderStepped:Wait())
    end)
    return success and fps or 60
end

function RESEARCH:MeasureFPS(duration)
    local samples = {}
    local endTime = tick() + duration
    
    while tick() < endTime do
        table.insert(samples, self:GetFPS())
        task.wait(0.1)
    end
    
    local sum = 0
    for _, fps in ipairs(samples) do
        sum = sum + fps
    end
    
    return math.floor(sum / #samples)
end

function RESEARCH:EnableRemoteHook()
    if self.State.Hook or not hookmetamethod then return end
    
    local success, oldNamecall = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(remote, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" or method == "InvokeServer" then
                pcall(function()
                    local name = remote.Name:lower()
                    if name:find("fish") or name:find("cast") or name:find("catch") or 
                       name:find("rod") or name:find("complete") then
                        table.insert(RESEARCH.State.CapturedCalls, {
                            Remote = remote.Name,
                            Method = method,
                            Args = args,
                            Time = tick()
                        })
                    end
                end)
            end
            
            return old(remote, ...)
        end)
        return old
    end)
    
    if success then
        self.State.Hook = oldNamecall
        self:SendWebhook(
            "Remote Hook Enabled",
            "Capturing all fishing remote calls",
            65280
        )
    end
end

function RESEARCH:DisableRemoteHook()
    if self.State.Hook and hookmetamethod then
        pcall(function()
            hookmetamethod(game, "__namecall", self.State.Hook)
        end)
        self.State.Hook = nil
    end
end

function RESEARCH:DetectSuccess()
    local success = false
    
    pcall(function()
        for _, obj in pairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local text = obj.Text:lower()
                if text:find("you got") or text:find("caught") or 
                   text:find("obtained") or text:find("success") then
                    success = true
                    break
                end
            end
        end
    end)
    
    return success
end

function RESEARCH:StartInstantResearch()
    if not self.Config.InstantResearch then return end
    
    local thread = task.spawn(function()
        self:UpdateStatus("Research: Enabling remote hook...")
        self:EnableRemoteHook()
        
        task.wait(2)
        
        self:UpdateStatus("Research: Scanning remotes...")
        self:SendWebhook("Instant Research Started", "Auto-discovering fishing methods", 3447003)
        
        local remotes = {}
        for _, obj in pairs(game:GetDescendants()) do
            if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                local name = obj.Name:lower()
                if name:find("fish") or name:find("cast") or name:find("catch") or 
                   name:find("rod") or name:find("complete") or name:find("charge") then
                    table.insert(remotes, {
                        Object = obj,
                        Name = obj.Name,
                        Type = obj.ClassName,
                        Path = obj:GetFullName()
                    })
                end
            end
        end
        
        self:SendWebhook(
            "Remotes Discovered",
            string.format("Found %d potential fishing remotes", #remotes),
            65280,
            {
                {name = "Total Found", value = tostring(#remotes), inline = true},
                {name = "RemoteFunctions", value = tostring(#remotes), inline = true}
            }
        )
        
        task.wait(2)
        
        self:UpdateStatus("Research: Testing arguments...")
        
        local testArgs = {
            {},
            {100},
            {99},
            {98},
            {97},
            {96},
            {95},
            {94},
            {93},
            {92},
            {90},
            {85},
            {80},
            {75},
            {50},
            {25},
            {0},
            {1},
            {-1},
            {true},
            {false},
            {nil},
            {100, true},
            {100, false},
            {99, true},
            {98, true},
            {1, true},
            {1, false},
            {0, true},
            {true, 100},
            {false, 0},
            {0.5, 0.5, 100},
            {0.5, 0.5, 99},
            {0.5, 0.5, 95},
            {1, 1, 100},
            {0, 0, 100},
            {-1.2331848144531125, 0.21007949047268, 176377617.004593},
            {Vector3.new(0, 0, 0)},
            {Vector3.new(0, 0, 0), 100},
            {Vector3.new(1, 1, 1)},
            {CFrame.new(0, 0, 0)},
            {math.random(90, 100)},
            {math.random(95, 100)},
            {math.random(97, 100)},
            {math.random(98, 100)},
            {tick()},
            {os.time()},
            {workspace},
            {Player},
            {Player.Character},
            {"Perfect"},
            {"Great"},
            {"Good"},
            {"Complete"},
            {"Finish"},
            {"Success"},
            {100, "Perfect"},
            {99, "Perfect"},
            {100, Player},
            {100, workspace},
            {{Score = 100}},
            {{Score = 99}},
            {{Score = 100, Perfect = true}},
            {{Perfect = true}},
            {{Success = true}},
            {{Complete = true}},
            {{Value = 100}},
            {{Result = "Perfect"}},
            {{Fish = true, Score = 100}},
            {100, 100, 100},
            {99, 99, 99},
            {1, 1, 1},
            {0, 0, 0},
            {100, 50, 25},
            {"arg1", "arg2", 100},
            {Player.Name, 100},
            {Player.UserId, 100},
            {math.huge},
            {-math.huge},
            {0/0},
            {100, 100},
            {50, 50},
            {75, 75}
        }
        
        local workingConfigs = {}
        
        for i, remote in ipairs(remotes) do
            if not self.Config.InstantResearch then break end
            
            self:UpdateStatus(string.format("Testing %d/%d: %s", i, #remotes, remote.Name))
            
            for argIndex, args in ipairs(testArgs) do
                local testHash = self:GenerateTestHash(remote, args)
                
                if self.Config.EnableValidation then
                    local valid, reason = self:ValidateRemote(remote)
                    if not valid then
                        self:LogError("Remote Validation", reason .. " - " .. remote.Name)
                        goto continue
                    end
                    
                    if self:HasBeenTested(testHash) then
                        goto continue
                    end
                end
                
                local success, result = pcall(function()
                    local timeoutThread = task.delay(self.Config.MaxTimeout, function()
                        error("Timeout exceeded")
                    end)
                    
                    local response
                    if remote.Type == "RemoteFunction" then
                        response = remote.Object:InvokeServer(unpack(args))
                    else
                        remote.Object:FireServer(unpack(args))
                        response = "fired"
                    end
                    
                    task.cancel(timeoutThread)
                    return response
                end)
                
                if not success then
                    self:LogError("Remote Call", result)
                end
                
                self:MarkTested(testHash)
                
                if success then
                    task.wait(1)
                    local successDetected = self:DetectSuccess()
                    
                    local config = {
                        Remote = remote.Name,
                        Type = remote.Type,
                        Path = remote.Path,
                        Args = HttpService:JSONEncode(args),
                        Result = tostring(result),
                        ArgPattern = argIndex,
                        Success = successDetected,
                        Score = 0
                    }
                    
                    if successDetected then
                        config.Score = 100
                        table.insert(self.State.SuccessfulTests, config)
                        
                        self:AutoSaveProgress("INSTANT_SUCCESS", config)
                        
                        self:SendWebhook(
                            "✅ SUCCESS - Instant Test",
                            string.format("Remote: %s\nType: %s", remote.Name, remote.Type),
                            65280,
                            {
                                {name = "Arguments", value = HttpService:JSONEncode(args), inline = false},
                                {name = "Result", value = tostring(result):sub(1, 100), inline = false},
                                {name = "Path", value = remote.Path:sub(1, 100), inline = false}
                            }
                        )
                    else
                        config.Score = 50
                        table.insert(self.State.FailedTests, config)
                    end
                    
                    table.insert(workingConfigs, config)
                    
                    local totalTests = #self.State.SuccessfulTests + #self.State.FailedTests
                    if totalTests % 10 == 0 then
                        self:AutoSaveProgress("INSTANT_CHECKPOINT", {
                            TestsCompleted = totalTests,
                            Successful = #self.State.SuccessfulTests,
                            Failed = #self.State.FailedTests,
                            CurrentRemote = remote.Name
                        })
                    end
                end
                
                ::continue::
                task.wait(1.5)
            end
            
            local remoteTotalTests = #self.State.SuccessfulTests + #self.State.FailedTests
            if remoteTotalTests % 20 == 0 then
                self:AutoSaveProgress("REMOTE_CHECKPOINT", {
                    RemotesTested = i,
                    TotalRemotes = #remotes,
                    TestsCompleted = remoteTotalTests,
                    Successful = #self.State.SuccessfulTests
                })
            end
            
            task.wait(1)
        end
        
        self:UpdateStatus("Research: Testing timings...")
        
        local timingTests = {
            {cast = 0.05, charge = 0.1, spam = 0.01},
            {cast = 0.08, charge = 0.25, spam = 0.018},
            {cast = 0.1, charge = 0.3, spam = 0.025},
            {cast = 0.15, charge = 0.5, spam = 0.05}
        }
        
        for i, timing in ipairs(timingTests) do
            if not self.Config.InstantResearch then break end
            
            self:UpdateStatus(string.format("Testing timing pattern %d/%d", i, #timingTests))
            
            self:SendWebhook(
                "Timing Pattern Test",
                string.format("Pattern %d", i),
                3447003,
                {
                    {name = "Cast Delay", value = tostring(timing.cast) .. "s", inline = true},
                    {name = "Charge Delay", value = tostring(timing.charge) .. "s", inline = true},
                    {name = "Spam Delay", value = tostring(timing.spam) .. "s", inline = true}
                }
            )
            
            task.wait(3)
        end
        
        table.sort(self.State.SuccessfulTests, function(a, b)
            return a.Score > b.Score
        end)
        
        if #self.State.SuccessfulTests > 0 then
            self.State.BestInstantMethod = self.State.SuccessfulTests[1]
        end
        
        local capturedCount = #self.State.CapturedCalls
        local capturedSummary = ""
        if capturedCount > 0 then
            capturedSummary = "\n\nCaptured Calls:\n"
            for i = 1, math.min(5, capturedCount) do
                local call = self.State.CapturedCalls[i]
                capturedSummary = capturedSummary .. string.format("- %s: %s\n", 
                    call.Remote, 
                    HttpService:JSONEncode(call.Args):sub(1, 50)
                )
            end
        end
        
        self:SendWebhook(
            "🎯 Instant Research Complete",
            string.format(
                "Discovered %d working configurations\n" ..
                "✓ Successful: %d\n" ..
                "⚠ Partial: %d\n" ..
                "📡 Captured: %d remote calls" .. capturedSummary,
                #workingConfigs,
                #self.State.SuccessfulTests,
                #self.State.FailedTests,
                capturedCount
            ),
            65280,
            {
                {name = "Total Configs", value = tostring(#workingConfigs), inline = true},
                {name = "Remotes Tested", value = tostring(#remotes), inline = true},
                {name = "Success Rate", value = string.format("%d%%", 
                    #workingConfigs > 0 and math.floor((#self.State.SuccessfulTests / #workingConfigs) * 100) or 0
                ), inline = true}
            }
        )
        
        if self.State.BestInstantMethod then
            self:SendWebhook(
                "🏆 BEST METHOD FOUND",
                string.format("Remote: %s\nType: %s", 
                    self.State.BestInstantMethod.Remote,
                    self.State.BestInstantMethod.Type
                ),
                3066993,
                {
                    {name = "Arguments", value = self.State.BestInstantMethod.Args, inline = false},
                    {name = "Result", value = self.State.BestInstantMethod.Result:sub(1, 100), inline = false},
                    {name = "Score", value = tostring(self.State.BestInstantMethod.Score), inline = true}
                }
            )
        end
        
        self:DisableRemoteHook()
        
        if not self.Config.AntiLagResearch then
            self:RestoreOriginalSettings()
        end
        
        self:UpdateStatus("Instant research complete")
    end)
    
    table.insert(self.Threads, thread)
end

function RESEARCH:SaveOriginalSettings()
    if self.State.ModifiedSettings then return end
    
    pcall(function()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        local SoundService = game:GetService("SoundService")
        
        self.State.OriginalSettings = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            WaterTransparency = Terrain and Terrain.WaterTransparency or 0.3,
            WaterWaveSize = Terrain and Terrain.WaterWaveSize or 0.15,
            WaterWaveSpeed = Terrain and Terrain.WaterWaveSpeed or 10,
            WaterReflectance = Terrain and Terrain.WaterReflectance or 1,
            RenderQuality = settings().Rendering.QualityLevel,
            MasterVolume = SoundService.Volume
        }
        
        self.State.ModifiedSettings = true
    end)
end

function RESEARCH:RestoreOriginalSettings()
    if not self.State.ModifiedSettings then return end
    
    self:UpdateStatus("Restoring original settings...")
    
    pcall(function()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        local SoundService = game:GetService("SoundService")
        local s = self.State.OriginalSettings
        
        if s.GlobalShadows ~= nil then
            Lighting.GlobalShadows = s.GlobalShadows
        end
        
        if s.FogEnd then
            Lighting.FogEnd = s.FogEnd
        end
        
        if s.Brightness then
            Lighting.Brightness = s.Brightness
        end
        
        if Terrain then
            if s.WaterTransparency then
                Terrain.WaterTransparency = s.WaterTransparency
            end
            if s.WaterWaveSize then
                Terrain.WaterWaveSize = s.WaterWaveSize
            end
            if s.WaterWaveSpeed then
                Terrain.WaterWaveSpeed = s.WaterWaveSpeed
            end
            if s.WaterReflectance then
                Terrain.WaterReflectance = s.WaterReflectance
            end
            Terrain.Decoration = true
        end
        
        if s.RenderQuality then
            settings().Rendering.QualityLevel = s.RenderQuality
        end
        
        if s.MasterVolume then
            SoundService.Volume = s.MasterVolume
        end
        
        for _, data in pairs(self.State.DisabledObjects) do
            pcall(function()
                if data.obj and data.obj.Parent then
                    data.obj.Enabled = true
                end
            end)
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Player and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    pcall(function()
                        if part:IsA("BasePart") and part.Transparency == 1 then
                            part.Transparency = 0
                        end
                    end)
                end
            end
        end
        
        self.State.ModifiedSettings = false
        self.State.OriginalSettings = {}
        self.State.DisabledObjects = {}
    end)
    
    self:SendWebhook(
        "✅ Settings Restored",
        "All game settings have been restored to original state",
        65280
    )
    
    self:UpdateStatus("Settings restored")
end

function RESEARCH:StartAntiLagResearch()
    if not self.Config.AntiLagResearch then return end
    
    local thread = task.spawn(function()
        self:SaveOriginalSettings()
        
        self:UpdateStatus("Research: Measuring baseline FPS...")
        
        self.State.FPSBaseline = self:MeasureFPS(3)
        
        self:SendWebhook(
            "Anti-Lag Research Started",
            "Testing graphics optimization methods",
            3447003,
            {
                {name = "Baseline FPS", value = tostring(self.State.FPSBaseline), inline = true}
            }
        )
        
        local tests = {
            {
                name = "Shadow Disable",
                apply = function()
                    game:GetService("Lighting").GlobalShadows = false
                end,
                restore = function()
                    game:GetService("Lighting").GlobalShadows = true
                end
            },
            {
                name = "Water Optimization",
                apply = function()
                    local terrain = workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        terrain.WaterTransparency = 1
                        terrain.WaterWaveSize = 0
                        terrain.WaterWaveSpeed = 0
                        terrain.WaterReflectance = 0
                    end
                end,
                restore = function()
                    local terrain = workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        terrain.WaterTransparency = 0.3
                        terrain.WaterWaveSize = 0.15
                        terrain.WaterWaveSpeed = 10
                        terrain.WaterReflectance = 1
                    end
                end
            },
            {
                name = "Particle Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ParticleEmitter") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ParticleEmitter") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Light Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if (obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")) and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Quality Level 1",
                apply = function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                end,
                restore = function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
                end
            },
            {
                name = "Sound Disable",
                apply = function()
                    game:GetService("SoundService").Volume = 0
                end,
                restore = function()
                    game:GetService("SoundService").Volume = 0.5
                end
            },
            {
                name = "Player Transparency",
                apply = function()
                    local count = 0
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= Player and player.Character then
                            for _, part in pairs(player.Character:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Transparency = 1
                                    count = count + 1
                                end
                            end
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, player in pairs(Players:GetPlayers()) do
                        if player ~= Player and player.Character then
                            for _, part in pairs(player.Character:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Transparency = 0
                                end
                            end
                        end
                    end
                end
            },
            {
                name = "Terrain Decoration Disable",
                apply = function()
                    local terrain = workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        terrain.Decoration = false
                    end
                end,
                restore = function()
                    local terrain = workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        terrain.Decoration = true
                    end
                end
            },
            {
                name = "Post Effects Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(game:GetService("Lighting"):GetChildren()) do
                        if obj:IsA("PostEffect") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(game:GetService("Lighting"):GetChildren()) do
                        if obj:IsA("PostEffect") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Beam Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Beam") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Beam") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Trail Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Trail") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Trail") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Fire Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Fire") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Fire") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Smoke Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Smoke") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Smoke") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Sparkles Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Sparkles") and obj.Enabled then
                            obj.Enabled = false
                            table.insert(RESEARCH.State.DisabledObjects, {obj = obj})
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Sparkles") then
                            obj.Enabled = true
                        end
                    end
                end
            },
            {
                name = "Animation Disable",
                apply = function()
                    local count = 0
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Character then
                            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                                    track:Stop()
                                    count = count + 1
                                end
                            end
                        end
                    end
                    return count
                end,
                restore = function()
                end
            },
            {
                name = "Sky Removal",
                apply = function()
                    local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
                    if sky then
                        sky.Parent = nil
                        return 1
                    end
                    return 0
                end,
                restore = function()
                end
            },
            {
                name = "Fog Maximum",
                apply = function()
                    local lighting = game:GetService("Lighting")
                    lighting.FogEnd = 100
                    lighting.FogStart = 0
                end,
                restore = function()
                    local lighting = game:GetService("Lighting")
                    lighting.FogEnd = 100000
                    lighting.FogStart = 0
                end
            },
            {
                name = "Ambient Minimal",
                apply = function()
                    game:GetService("Lighting").Ambient = Color3.new(0, 0, 0)
                end,
                restore = function()
                    game:GetService("Lighting").Ambient = Color3.new(0.5, 0.5, 0.5)
                end
            },
            {
                name = "Texture Removal",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Texture") or obj:IsA("Decal") then
                            obj.Transparency = 1
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Texture") or obj:IsA("Decal") then
                            obj.Transparency = 0
                        end
                    end
                end
            },
            {
                name = "MeshPart LOD",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("MeshPart") then
                            obj.RenderFidelity = Enum.RenderFidelity.Performance
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("MeshPart") then
                            obj.RenderFidelity = Enum.RenderFidelity.Automatic
                        end
                    end
                end
            },
            {
                name = "Camera Max Zoom",
                apply = function()
                    Player.CameraMaxZoomDistance = 0.5
                    Player.CameraMinZoomDistance = 0.5
                end,
                restore = function()
                    Player.CameraMaxZoomDistance = 128
                    Player.CameraMinZoomDistance = 0.5
                end
            },
            {
                name = "GUI Performance",
                apply = function()
                    local count = 0
                    for _, gui in pairs(PlayerGui:GetDescendants()) do
                        if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
                            gui.ImageTransparency = 1
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, gui in pairs(PlayerGui:GetDescendants()) do
                        if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
                            gui.ImageTransparency = 0
                        end
                    end
                end
            },
            {
                name = "Cast Shadows Disable",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.CastShadow then
                            obj.CastShadow = false
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") then
                            obj.CastShadow = true
                        end
                    end
                end
            },
            {
                name = "Material Override",
                apply = function()
                    local count = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and obj.Material ~= Enum.Material.SmoothPlastic then
                            obj.Material = Enum.Material.SmoothPlastic
                            count = count + 1
                        end
                    end
                    return count
                end,
                restore = function()
                end
            }
        }
        
        for i, test in ipairs(tests) do
            if not self.Config.AntiLagResearch then break end
            
            self:UpdateStatus(string.format("Testing %d/%d: %s", i, #tests, test.name))
            
            local applyResult = test.apply()
            task.wait(1)
            
            local fpsAfter = self:MeasureFPS(3)
            local improvement = fpsAfter - self.State.FPSBaseline
            local improvementPercent = math.floor((improvement / self.State.FPSBaseline) * 100)
            
            if improvement > 5 then
                self:AutoSaveProgress("ANTILAG_SUCCESS", {
                    Method = test.name,
                    FPSGain = improvement,
                    Percent = improvementPercent,
                    BaselineFPS = self.State.FPSBaseline,
                    AfterFPS = fpsAfter
                })
            end
            
            self:SendWebhook(
                "Anti-Lag Test: " .. test.name,
                string.format("FPS Change: %+d (%+d%%)", improvement, improvementPercent),
                improvement > 0 and 65280 or 16711680,
                {
                    {name = "Baseline FPS", value = tostring(self.State.FPSBaseline), inline = true},
                    {name = "After FPS", value = tostring(fpsAfter), inline = true},
                    {name = "Improvement", value = string.format("%+d FPS", improvement), inline = true},
                    {name = "Percent", value = string.format("%+d%%", improvementPercent), inline = true},
                    {name = "Objects Affected", value = tostring(applyResult or "N/A"), inline = true}
                }
            )
            
            test.restore()
            task.wait(2)
        end
        
        self:UpdateStatus("Research: Testing combinations...")
        
        local comboTests = {
            {name = "Full Optimization", tests = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24}},
            {name = "Graphics Max", tests = {1, 2, 5, 8, 9, 10, 11, 12, 13, 14, 15, 18, 22}},
            {name = "Effects Disable", tests = {3, 4, 6, 7, 8, 9, 10, 11, 12}},
            {name = "Lighting Optimize", tests = {1, 2, 10, 14, 15}},
            {name = "Particles Full", tests = {3, 4, 6, 7, 8, 9, 10, 11}},
            {name = "Transparency Max", tests = {7, 17, 19}},
            {name = "Mesh Optimize", tests = {18, 21, 24}},
            {name = "Minimal Impact", tests = {1, 5, 14}},
            {name = "Medium Impact", tests = {1, 2, 3, 4, 5, 10, 14}},
            {name = "Ultra Performance", tests = {1, 2, 3, 4, 7, 10, 14, 18, 22, 24}},
            {name = "Quality Balance", tests = {1, 5, 10, 14, 21}},
            {name = "Extreme FPS", tests = {1, 2, 3, 4, 6, 7, 10, 14, 17, 18, 19, 22, 24}}
        }
        
        for i, combo in ipairs(comboTests) do
            if not self.Config.AntiLagResearch then break end
            
            self:UpdateStatus(string.format("Combo test %d/%d: %s", i, #comboTests, combo.name))
            
            for _, testIndex in ipairs(combo.tests) do
                tests[testIndex].apply()
            end
            
            task.wait(1)
            local fpsAfter = self:MeasureFPS(3)
            local improvement = fpsAfter - self.State.FPSBaseline
            local improvementPercent = math.floor((improvement / self.State.FPSBaseline) * 100)
            
            combo.improvement = improvement
            combo.fpsAfter = fpsAfter
            
            self:SendWebhook(
                "Combo Test: " .. combo.name,
                string.format("Combined %d optimizations", #combo.tests),
                3447003,
                {
                    {name = "Baseline FPS", value = tostring(self.State.FPSBaseline), inline = true},
                    {name = "After FPS", value = tostring(fpsAfter), inline = true},
                    {name = "Total Gain", value = string.format("%+d FPS (%+d%%)", improvement, improvementPercent), inline = true}
                }
            )
            
            for _, testIndex in ipairs(combo.tests) do
                tests[testIndex].restore()
            end
            
            task.wait(2)
        end
        
        local bestCombo = nil
        local bestImprovement = 0
        
        for i, combo in ipairs(comboTests) do
            if combo.improvement and combo.improvement > bestImprovement then
                bestImprovement = combo.improvement
                bestCombo = combo
            end
        end
        
        if bestCombo then
            self.State.BestAntiLag = bestCombo
        end
        
        self:SendWebhook(
            "🎯 Anti-Lag Research Complete",
            string.format(
                "Tested %d methods + %d combinations\n" ..
                "Baseline FPS: %d\n" ..
                "Best Improvement: +%d FPS",
                #tests,
                #comboTests,
                self.State.FPSBaseline,
                bestImprovement
            ),
            65280
        )
        
        if self.State.BestAntiLag then
            self:SendWebhook(
                "🏆 BEST ANTI-LAG CONFIG",
                string.format("Config: %s", self.State.BestAntiLag.name),
                3066993,
                {
                    {name = "FPS Gain", value = string.format("+%d FPS", bestImprovement), inline = true},
                    {name = "Methods Used", value = tostring(#self.State.BestAntiLag.tests), inline = true}
                }
            )
        end
        
        self:RestoreOriginalSettings()
        self:UpdateStatus("Anti-lag research complete")
    end)
    
    table.insert(self.Threads, thread)
end

function RESEARCH:ScanFishData()
    local fishData = {}
    
    pcall(function()
        for _, obj in pairs(game:GetDescendants()) do
            if obj:IsA("ModuleScript") or obj:IsA("Folder") or obj:IsA("Configuration") then
                local name = obj.Name:lower()
                if name:match("fish") or name:match("catch") or name:match("aqua") or name:match("loot") or name:match("item") then
                    table.insert(fishData, {
                        Name = obj.Name,
                        Type = obj.ClassName,
                        Path = obj:GetFullName(),
                        Parent = obj.Parent and obj.Parent.Name or "nil"
                    })
                end
            end
        end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                for _, obj in pairs(player.Character:GetDescendants()) do
                    if obj:IsA("Tool") or obj:IsA("Model") then
                        local name = obj.Name:lower()
                        if name:match("fish") then
                            table.insert(fishData, {
                                Name = obj.Name,
                                Type = "PlayerItem",
                                Path = obj:GetFullName(),
                                Parent = player.Name
                            })
                        end
                    end
                end
            end
        end
        
        local gui = Player.PlayerGui
        for _, obj in pairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("Frame") then
                local text = obj:IsA("TextLabel") and obj.Text or obj:IsA("TextButton") and obj.Text or obj.Name
                if text and (text:lower():match("fish") or text:lower():match("caught") or text:lower():match("kg") or text:lower():match("legendary") or text:lower():match("mythic")) then
                    table.insert(fishData, {
                        Name = obj.Name,
                        Type = "GUI_" .. obj.ClassName,
                        Path = obj:GetFullName(),
                        Text = text:sub(1, 50)
                    })
                end
            end
        end
    end)
    
    return fishData
end

function RESEARCH:AnalyzeFishRemotes()
    local fishRemotes = {}
    
    pcall(function()
        for _, remote in pairs(game:GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local name = remote.Name:lower()
                if name:match("fish") or name:match("catch") or name:match("reel") or name:match("complete") or name:match("reward") or name:match("claim") then
                    table.insert(fishRemotes, {
                        Name = remote.Name,
                        Type = remote.ClassName,
                        Path = remote:GetFullName()
                    })
                end
            end
        end
    end)
    
    return fishRemotes
end

function RESEARCH:StartFishDataResearch()
    if not self.Config.FishDataResearch then return end
    
    local thread = task.spawn(function()
        self:SendWebhook(
            "⚠️ FISH DATA INJECTION RESEARCH STARTED",
            "**WARNING: This is experimental and risky!**\n" ..
            "Testing fish data modification and injection methods.\n" ..
            "Use at your own risk - ban possible!",
            16776960
        )
        
        self:UpdateStatus("Scanning fish data structures...")
        
        local fishData = self:ScanFishData()
        self.State.FishDatabase = fishData
        
        self:SendWebhook(
            "📊 Fish Data Scan Complete",
            string.format("Found %d fish-related objects", #fishData),
            3447003,
            {
                {name = "Total Objects", value = tostring(#fishData), inline = true}
            }
        )
        
        if #fishData > 0 then
            local report = "FISH DATA OBJECTS:\n\n"
            for i, data in ipairs(fishData) do
                report = report .. string.format("#%d - %s (%s)\n", i, data.Name, data.Type)
                report = report .. string.format("    Path: %s\n", data.Path)
                if data.Text then
                    report = report .. string.format("    Text: %s\n", data.Text)
                end
                report = report .. "\n"
                
                if i >= 30 then
                    report = report .. string.format("... and %d more objects\n", #fishData - 30)
                    break
                end
            end
            
            if #report < 1500 then
                self:SendWebhook(
                    "📋 Fish Data Details",
                    "```\n" .. report .. "```",
                    3447003
                )
            end
        end
        
        task.wait(2)
        
        self:UpdateStatus("Analyzing fish remotes...")
        
        local fishRemotes = self:AnalyzeFishRemotes()
        
        self:SendWebhook(
            "🔍 Fish Remote Analysis",
            string.format("Found %d fish-related remotes", #fishRemotes),
            3447003
        )
        
        if #fishRemotes > 0 then
            local remoteList = "FISH REMOTES:\n\n"
            for i, remote in ipairs(fishRemotes) do
                remoteList = remoteList .. string.format("#%d - %s (%s)\n", i, remote.Name, remote.Type)
                remoteList = remoteList .. string.format("    Path: %s\n", remote.Path)
                remoteList = remoteList .. "\n"
            end
            
            if #remoteList < 1500 then
                self:SendWebhook(
                    "📋 Remote List",
                    "```\n" .. remoteList .. "```",
                    3447003
                )
            end
        end
        
        task.wait(2)
        
        self:UpdateStatus("Testing fish data injection...")
        
        local injectionPatterns = {
            {name = "Legendary Fish ID", args = {"Legendary", 9999, "Megalodon"}},
            {name = "Mythic Fish ID", args = {"Mythic", 99999, "GoldenShark"}},
            {name = "Secret Fish", args = {"Secret", 999999, "DevFish"}},
            {name = "Max Weight", args = {"Common", 99999, "Bass"}},
            {name = "Rarity Override", args = {Rarity = "Legendary", Weight = 9999}},
            {name = "Custom Fish Data", args = {FishType = "Golden", Rarity = "Mythic", Value = 999999}},
            {name = "Direct Inventory", args = {Action = "AddFish", Fish = "Legendary", Amount = 1}},
            {name = "Reward Multiplier", args = {Multiplier = 999, Rarity = "Legendary"}},
            {name = "Fish Table Inject", args = {{Name = "SecretFish", Rarity = "Mythic", Weight = 9999}}},
            {name = "Complete Override", args = {Success = true, Fish = "GoldenMegalodon", Weight = 99999, Rarity = "Secret"}}
        }
        
        for i, pattern in ipairs(injectionPatterns) do
            if not self.Config.FishDataResearch then break end
            
            self:UpdateStatus(string.format("Test %d/%d: %s", i, #injectionPatterns, pattern.name))
            
            for _, remote in ipairs(fishRemotes) do
                if not self.Config.FishDataResearch then break end
                
                local testResult = {
                    Pattern = pattern.name,
                    Remote = remote.Name,
                    RemotePath = remote.Path,
                    Args = HttpService:JSONEncode(pattern.args),
                    Success = false,
                    Result = "No response",
                    Error = nil
                }
                
                local remoteObj = game
                for part in remote.Path:gmatch("[^.]+") do
                    if remoteObj then
                        remoteObj = remoteObj:FindFirstChild(part)
                    end
                end
                
                if remoteObj and (remoteObj:IsA("RemoteEvent") or remoteObj:IsA("RemoteFunction")) then
                    local success, result = pcall(function()
                        if remoteObj:IsA("RemoteFunction") then
                            return remoteObj:InvokeServer(unpack(pattern.args))
                        else
                            remoteObj:FireServer(unpack(pattern.args))
                            return "Fired"
                        end
                    end)
                    
                    testResult.Success = success
                    testResult.Result = success and tostring(result) or "Failed"
                    testResult.Error = not success and tostring(result) or nil
                    
                    task.wait(0.5)
                    
                    local detectedChange = self:DetectSuccess()
                    testResult.GuiDetection = detectedChange and "SUCCESS DETECTED" or "No change"
                    
                    if success or detectedChange then
                        table.insert(self.State.SecretFishFound, testResult)
                        
                        self:AutoSaveProgress("FISH_INJECTION_SUCCESS", testResult)
                        
                        self:SendWebhook(
                            "🎣 FISH INJECTION TEST - " .. (detectedChange and "✅ SUCCESS" or "⚠️ SENT"),
                            string.format(
                                "**Pattern:** %s\n" ..
                                "**Remote:** %s\n" ..
                                "**Args:** %s\n" ..
                                "**Result:** %s\n" ..
                                "**GUI Change:** %s",
                                pattern.name,
                                remote.Name,
                                testResult.Args:sub(1, 100),
                                testResult.Result:sub(1, 100),
                                testResult.GuiDetection
                            ),
                            detectedChange and 65280 or 16776960
                        )
                    end
                    
                    table.insert(self.State.InjectionTests, testResult)
                end
                
                task.wait(1)
            end
            
            task.wait(2)
        end
        
        local successCount = 0
        for _, test in ipairs(self.State.InjectionTests) do
            if test.Success or test.GuiDetection == "SUCCESS DETECTED" then
                successCount = successCount + 1
            end
        end
        
        self:SendWebhook(
            "🎯 FISH INJECTION RESEARCH COMPLETE",
            string.format(
                "**Total Tests:** %d\n" ..
                "**Successful Injections:** %d\n" ..
                "**Success Rate:** %d%%\n\n" ..
                "⚠️ **WARNING:** Use findings carefully - ban risk!",
                #self.State.InjectionTests,
                successCount,
                #self.State.InjectionTests > 0 and math.floor((successCount / #self.State.InjectionTests) * 100) or 0
            ),
            successCount > 0 and 65280 or 16711680
        )
        
        if #self.State.SecretFishFound > 0 then
            self.State.BestInjectionMethod = self.State.SecretFishFound[1]
            
            self:SendWebhook(
                "💎 BEST INJECTION FOUND",
                string.format(
                    "**Pattern:** %s\n" ..
                    "**Remote:** %s\n" ..
                    "**Path:** %s\n" ..
                    "**Args:** %s",
                    self.State.BestInjectionMethod.Pattern,
                    self.State.BestInjectionMethod.Remote,
                    self.State.BestInjectionMethod.RemotePath,
                    self.State.BestInjectionMethod.Args:sub(1, 200)
                ),
                3066993
            )
        end
        
        self:UpdateStatus("Fish injection research complete")
    end)
    
    table.insert(self.Threads, thread)
end

function RESEARCH:ScanFishingLocations()
    local locations = {}
    
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("Folder") then
                local name = obj.Name:lower()
                if name:match("fish") or name:match("spot") or name:match("zone") or 
                   name:match("area") or name:match("location") or name:match("dock") or 
                   name:match("pier") or name:match("lake") or name:match("ocean") or 
                   name:match("pond") or name:match("river") or name:match("sea") then
                    
                    local position = nil
                    if obj:IsA("Model") and obj.PrimaryPart then
                        position = obj.PrimaryPart.Position
                    elseif obj:IsA("Part") then
                        position = obj.Position
                    elseif obj:IsA("Folder") then
                        local firstPart = obj:FindFirstChildOfClass("Part", true)
                        if firstPart then
                            position = firstPart.Position
                        end
                    end
                    
                    if position then
                        table.insert(locations, {
                            Name = obj.Name,
                            Type = obj.ClassName,
                            Path = obj:GetFullName(),
                            Position = position,
                            X = math.floor(position.X),
                            Y = math.floor(position.Y),
                            Z = math.floor(position.Z)
                        })
                    end
                end
            end
        end
    end)
    
    return locations
end

function RESEARCH:TeleportTest(location)
    local success = false
    local error = nil
    local originalPos = nil
    
    pcall(function()
        if Player.Character and Player.Character.PrimaryPart then
            originalPos = Player.Character.PrimaryPart.Position
            
            Player.Character:SetPrimaryPartCFrame(CFrame.new(location.Position))
            task.wait(1)
            
            local newPos = Player.Character.PrimaryPart.Position
            local distance = (newPos - location.Position).Magnitude
            
            if distance < 50 then
                success = true
            else
                error = "Teleport failed - distance: " .. math.floor(distance)
            end
            
            task.wait(2)
            Player.Character:SetPrimaryPartCFrame(CFrame.new(originalPos))
        else
            error = "No character or PrimaryPart"
        end
    end)
    
    return success, error
end

function RESEARCH:StartLocationResearch()
    if not self.Config.LocationResearch then return end
    
    local thread = task.spawn(function()
        self:SendWebhook(
            "🗺️ LOCATION RESEARCH STARTED",
            "Scanning for fishing spots and testing teleports...",
            3447003
        )
        
        self:UpdateStatus("Scanning fishing locations...")
        
        local locations = self:ScanFishingLocations()
        self.State.FishingLocations = locations
        
        self:SendWebhook(
            "📍 Fishing Locations Found",
            string.format("Discovered %d potential fishing spots", #locations),
            65280,
            {
                {name = "Total Locations", value = tostring(#locations), inline = true}
            }
        )
        
        if #locations > 0 then
            local locationReport = "FISHING LOCATIONS:\n\n"
            for i, loc in ipairs(locations) do
                locationReport = locationReport .. string.format(
                    "#%d - %s (%s)\n    Position: %d, %d, %d\n    Path: %s\n\n",
                    i, loc.Name, loc.Type, loc.X, loc.Y, loc.Z, loc.Path
                )
                
                if i >= 20 then
                    locationReport = locationReport .. string.format("... and %d more locations\n", #locations - 20)
                    break
                end
            end
            
            if #locationReport < 1500 then
                self:SendWebhook(
                    "📋 Location Details",
                    "```\n" .. locationReport .. "```",
                    3447003
                )
            end
        end
        
        task.wait(2)
        
        self:UpdateStatus("Testing teleports...")
        
        for i, location in ipairs(locations) do
            if not self.Config.LocationResearch then break end
            
            self:UpdateStatus(string.format("Teleport test %d/%d: %s", i, #locations, location.Name))
            
            local success, error = self:TeleportTest(location)
            
            local testResult = {
                LocationName = location.Name,
                Position = string.format("%d, %d, %d", location.X, location.Y, location.Z),
                Path = location.Path,
                Success = success,
                Error = error or "None"
            }
            
            table.insert(self.State.TeleportTests, testResult)
            
            if success then
                table.insert(self.State.WorkingTeleports, testResult)
                
                self:AutoSaveProgress("TELEPORT_SUCCESS", testResult)
                
                self:SendWebhook(
                    "✅ TELEPORT SUCCESS",
                    string.format(
                        "**Location:** %s\n" ..
                        "**Position:** %s\n" ..
                        "**Path:** %s",
                        location.Name,
                        testResult.Position,
                        location.Path:sub(1, 100)
                    ),
                    65280
                )
            else
                self:SendWebhook(
                    "❌ Teleport Failed",
                    string.format(
                        "**Location:** %s\n" ..
                        "**Error:** %s",
                        location.Name,
                        error or "Unknown"
                    ),
                    16711680
                )
            end
            
            task.wait(3)
        end
        
        local successCount = #self.State.WorkingTeleports
        local successRate = #locations > 0 and math.floor((successCount / #locations) * 100) or 0
        
        if successCount > 0 then
            self.State.BestFishingSpot = self.State.WorkingTeleports[1]
        end
        
        self:SendWebhook(
            "🎯 LOCATION RESEARCH COMPLETE",
            string.format(
                "**Locations Found:** %d\n" ..
                "**Teleports Tested:** %d\n" ..
                "**Successful Teleports:** %d\n" ..
                "**Success Rate:** %d%%",
                #locations,
                #self.State.TeleportTests,
                successCount,
                successRate
            ),
            65280
        )
        
        if self.State.BestFishingSpot then
            self:SendWebhook(
                "🏆 BEST FISHING SPOT",
                string.format(
                    "**Location:** %s\n" ..
                    "**Position:** %s\n" ..
                    "**Ready for teleport!**",
                    self.State.BestFishingSpot.LocationName,
                    self.State.BestFishingSpot.Position
                ),
                3066993
            )
        end
        
        self:UpdateStatus("Location research complete")
    end)
    
    table.insert(self.Threads, thread)
end

function RESEARCH:AnalyzeCapturedCalls()
    local patterns = {}
    
    for _, call in ipairs(self.State.CapturedCalls) do
        local pattern = {
            RemoteName = call.Remote,
            Method = call.Method,
            ArgCount = #call.Args,
            ArgTypes = {}
        }
        
        for i, arg in ipairs(call.Args) do
            local argType = type(arg)
            if argType == "userdata" then
                if typeof(arg) == "Vector3" then
                    argType = "Vector3"
                elseif typeof(arg) == "CFrame" then
                    argType = "CFrame"
                elseif typeof(arg) == "Instance" then
                    argType = "Instance"
                end
            end
            table.insert(pattern.ArgTypes, argType)
        end
        
        local patternKey = pattern.RemoteName .. "_" .. table.concat(pattern.ArgTypes, ",")
        patterns[patternKey] = pattern
    end
    
    return patterns
end

function RESEARCH:GenerateRandomArgs(argTypes)
    local args = {}
    
    for _, argType in ipairs(argTypes) do
        if argType == "number" then
            table.insert(args, math.random(1, 100))
        elseif argType == "string" then
            local strings = {"Perfect", "Good", "Complete", "Success", "Fish"}
            table.insert(args, strings[math.random(1, #strings)])
        elseif argType == "boolean" then
            table.insert(args, math.random() > 0.5)
        elseif argType == "Vector3" then
            table.insert(args, Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)))
        elseif argType == "Instance" then
            table.insert(args, Player)
        else
            table.insert(args, nil)
        end
    end
    
    return args
end

function RESEARCH:StartDiscoveryMode()
    if not self.Config.DiscoveryMode then return end
    
    local thread = task.spawn(function()
        self:SendWebhook(
            "🤖 AI DISCOVERY MODE ACTIVATED",
            "Analyzing captured data and discovering unknown patterns...",
            3447003
        )
        
        self:UpdateStatus("Discovery: Analyzing patterns...")
        
        task.wait(5)
        
        local discoveredPatterns = self:AnalyzeCapturedCalls()
        local patternCount = 0
        for _ in pairs(discoveredPatterns) do
            patternCount = patternCount + 1
        end
        
        self:SendWebhook(
            "🔍 Pattern Analysis Complete",
            string.format("Discovered %d unique patterns from captured calls", patternCount),
            65280
        )
        
        self:UpdateStatus("Discovery: Testing variations...")
        
        for patternKey, pattern in pairs(discoveredPatterns) do
            if not self.Config.DiscoveryMode then break end
            
            local remote = nil
            for _, obj in pairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    if obj.Name == pattern.RemoteName then
                        remote = {
                            Object = obj,
                            Name = obj.Name,
                            Type = obj.ClassName,
                            Path = obj:GetFullName()
                        }
                        break
                    end
                end
            end
            
            if remote then
                for attempt = 1, 10 do
                    if not self.Config.DiscoveryMode then break end
                    
                    local randomArgs = self:GenerateRandomArgs(pattern.ArgTypes)
                    local testHash = self:GenerateTestHash(remote, randomArgs)
                    
                    if not self:HasBeenTested(testHash) then
                        local success, result = pcall(function()
                            if remote.Type == "RemoteFunction" then
                                return remote.Object:InvokeServer(unpack(randomArgs))
                            else
                                remote.Object:FireServer(unpack(randomArgs))
                                return "fired"
                            end
                        end)
                        
                        self:MarkTested(testHash)
                        
                        if success then
                            task.wait(1)
                            local successDetected = self:DetectSuccess()
                            
                            if successDetected then
                                local discovery = {
                                    Remote = remote.Name,
                                    Args = HttpService:JSONEncode(randomArgs),
                                    Pattern = patternKey,
                                    Result = tostring(result),
                                    DiscoveryType = "AI_GENERATED"
                                }
                                
                                table.insert(self.State.UnknownSuccesses, discovery)
                                
                                self:AutoSaveProgress("DISCOVERY_SUCCESS", discovery)
                                
                                self:SendWebhook(
                                    "💡 UNKNOWN PATTERN DISCOVERED!",
                                    string.format(
                                        "**Remote:** %s\n" ..
                                        "**Pattern:** %s\n" ..
                                        "**Args:** %s\n" ..
                                        "**Type:** AI Generated",
                                        remote.Name,
                                        patternKey,
                                        HttpService:JSONEncode(randomArgs):sub(1, 150)
                                    ),
                                    65280
                                )
                            end
                        end
                        
                        task.wait(2)
                    end
                end
            end
            
            task.wait(1)
        end
        
        self:UpdateStatus("Discovery: Testing GUI variations...")
        
        local guiElements = {}
        for _, obj in pairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                if obj.Visible and obj.Parent then
                    table.insert(guiElements, obj)
                end
            end
        end
        
        for i, button in ipairs(guiElements) do
            if not self.Config.DiscoveryMode then break end
            
            self:UpdateStatus(string.format("Discovery: Testing GUI %d/%d", i, #guiElements))
            
            local success = pcall(function()
                firesignal(button.MouseButton1Click)
            end)
            
            if success then
                task.wait(1)
                local successDetected = self:DetectSuccess()
                
                if successDetected then
                    local discovery = {
                        ButtonName = button.Name,
                        ButtonText = button:IsA("TextButton") and button.Text or "[Image]",
                        Path = button:GetFullName(),
                        DiscoveryType = "GUI_INTERACTION"
                    }
                    
                    table.insert(self.State.DiscoveredPatterns, discovery)
                    
                    self:AutoSaveProgress("GUI_DISCOVERY", discovery)
                    
                    self:SendWebhook(
                        "🎯 GUI PATTERN FOUND",
                        string.format(
                            "**Button:** %s\n" ..
                            "**Path:** %s",
                            button.Name,
                            button:GetFullName():sub(1, 100)
                        ),
                        65280
                    )
                end
            end
            
            task.wait(1)
        end
        
        self:SendWebhook(
            "🤖 DISCOVERY MODE COMPLETE",
            string.format(
                "**Unknown Patterns Found:** %d\n" ..
                "**GUI Patterns Found:** %d\n" ..
                "**Total Discoveries:** %d",
                #self.State.UnknownSuccesses,
                #self.State.DiscoveredPatterns,
                #self.State.UnknownSuccesses + #self.State.DiscoveredPatterns
            ),
            65280
        )
        
        self:UpdateStatus("Discovery mode complete")
    end)
    
    table.insert(self.Threads, thread)
end

function RESEARCH:StopAll()
    self.Config.InstantResearch = false
    self.Config.AntiLagResearch = false
    self.Config.FishDataResearch = false
    self.Config.LocationResearch = false
    self.Config.DiscoveryMode = false
    
    self:DisableRemoteHook()
    self:RestoreOriginalSettings()
    
    for _, thread in ipairs(self.Threads) do
        pcall(function()
            task.cancel(thread)
        end)
    end
    
    self.Threads = {}
    self:UpdateStatus("All research stopped")
end

function RESEARCH:GenerateFinalReport()
    local report = "=" .. string.rep("=", 60) .. "\n"
    report = report .. "  DEWA RESEARCH - FINAL REPORT\n"
    report = report .. "  Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    report = report .. "  Player: " .. Player.Name .. "\n"
    report = report .. "=" .. string.rep("=", 60) .. "\n\n"
    
    report = report .. "[BEST CONFIGURATIONS FOUND]\n\n"
    
    if self.State.BestInstantMethod then
        report = report .. ">>> BEST INSTANT METHOD <<<\n"
        report = report .. string.format("  Remote Name: %s\n", self.State.BestInstantMethod.Remote)
        report = report .. string.format("  Remote Type: %s\n", self.State.BestInstantMethod.Type)
        report = report .. string.format("  Remote Path: %s\n", self.State.BestInstantMethod.Path or "N/A")
        report = report .. string.format("  Arguments: %s\n", self.State.BestInstantMethod.Args)
        report = report .. string.format("  Result: %s\n", self.State.BestInstantMethod.Result)
        report = report .. string.format("  Success Score: %d/100\n", self.State.BestInstantMethod.Score)
        report = report .. string.format("  Success Detected: %s\n", self.State.BestInstantMethod.Success and "YES" or "NO")
        report = report .. "\n"
    else
        report = report .. ">>> INSTANT METHOD: No successful method found\n\n"
    end
    
    if self.State.BestAntiLag then
        report = report .. ">>> BEST ANTI-LAG CONFIG <<<\n"
        report = report .. string.format("  Config Name: %s\n", self.State.BestAntiLag.name)
        report = report .. string.format("  FPS Baseline: %d\n", self.State.FPSBaseline)
        report = report .. string.format("  FPS After: %d\n", self.State.BestAntiLag.fpsAfter or 0)
        report = report .. string.format("  FPS Gain: +%d FPS\n", self.State.BestAntiLag.improvement or 0)
        report = report .. string.format("  Improvement: +%d%%\n", 
            self.State.FPSBaseline > 0 and math.floor(((self.State.BestAntiLag.improvement or 0) / self.State.FPSBaseline) * 100) or 0
        )
        report = report .. string.format("  Methods Used: %d optimizations\n", #self.State.BestAntiLag.tests)
        report = report .. "\n"
    else
        report = report .. ">>> ANTI-LAG: No testing performed\n\n"
    end
    
    if self.State.BestInjectionMethod then
        report = report .. ">>> BEST FISH INJECTION METHOD <<<\n"
        report = report .. "⚠️ WARNING: RISKY - BAN POSSIBLE!\n"
        report = report .. string.format("  Pattern: %s\n", self.State.BestInjectionMethod.Pattern)
        report = report .. string.format("  Remote: %s\n", self.State.BestInjectionMethod.Remote)
        report = report .. string.format("  Remote Path: %s\n", self.State.BestInjectionMethod.RemotePath)
        report = report .. string.format("  Arguments: %s\n", self.State.BestInjectionMethod.Args)
        report = report .. string.format("  Result: %s\n", self.State.BestInjectionMethod.Result)
        report = report .. string.format("  GUI Detection: %s\n", self.State.BestInjectionMethod.GuiDetection)
        report = report .. "\n"
    elseif #self.State.InjectionTests > 0 then
        report = report .. ">>> FISH INJECTION: Tests performed but no success\n\n"
    end
    
    report = report .. "\n" .. string.rep("-", 60) .. "\n"
    report = report .. "[STATISTICS]\n\n"
    
    local totalTests = #self.State.SuccessfulTests + #self.State.FailedTests
    local successRate = totalTests > 0 and math.floor((#self.State.SuccessfulTests / totalTests) * 100) or 0
    
    report = report .. string.format("  Total Tests Performed: %d\n", totalTests)
    report = report .. string.format("  Successful Tests: %d\n", #self.State.SuccessfulTests)
    report = report .. string.format("  Failed Tests: %d\n", #self.State.FailedTests)
    report = report .. string.format("  Success Rate: %d%%\n", successRate)
    report = report .. string.format("  Remote Calls Captured: %d\n", #self.State.CapturedCalls)
    report = report .. string.format("  Fish Injection Tests: %d\n", #self.State.InjectionTests)
    report = report .. string.format("  Secret Fish Found: %d\n", #self.State.SecretFishFound)
    report = report .. string.format("  Fishing Locations Discovered: %d\n", #self.State.FishingLocations)
    report = report .. string.format("  Teleport Tests: %d\n", #self.State.TeleportTests)
    report = report .. string.format("  Working Teleports: %d\n", #self.State.WorkingTeleports)
    report = report .. string.format("  AI Discovered Patterns: %d\n", #self.State.UnknownSuccesses)
    report = report .. string.format("  GUI Patterns Found: %d\n", #self.State.DiscoveredPatterns)
    report = report .. string.format("  Errors Logged: %d\n", #self.State.ErrorLog)
    report = report .. string.format("  Unique Tests Cached: %d\n", (function() local c=0 for _ in pairs(self.State.TestedHashes) do c=c+1 end return c end)())
    report = report .. "\n"
    
    if #self.State.SuccessfulTests > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[ALL SUCCESSFUL CONFIGURATIONS]\n\n"
        
        for i, config in ipairs(self.State.SuccessfulTests) do
            report = report .. string.format("#%d - %s (%s)\n", i, config.Remote, config.Type)
            report = report .. string.format("    Args: %s\n", config.Args)
            report = report .. string.format("    Score: %d/100\n", config.Score)
            report = report .. string.format("    Path: %s\n", config.Path or "N/A")
            report = report .. "\n"
        end
    end
    
    if #self.State.CapturedCalls > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[CAPTURED REMOTE CALLS]\n\n"
        
        for i, call in ipairs(self.State.CapturedCalls) do
            report = report .. string.format("#%d - %s (%s)\n", i, call.Remote, call.Method)
            report = report .. string.format("    Args: %s\n", HttpService:JSONEncode(call.Args))
            report = report .. string.format("    Time: %.2f\n", call.Time)
            report = report .. "\n"
            
            if i >= 50 then
                report = report .. string.format("    ... and %d more calls\n", #self.State.CapturedCalls - 50)
                break
            end
        end
    end
    
    if #self.State.SecretFishFound > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[SECRET FISH INJECTION RESULTS]\n"
        report = report .. "⚠️ WARNING: Use at your own risk!\n\n"
        
        for i, fish in ipairs(self.State.SecretFishFound) do
            report = report .. string.format("#%d - %s\n", i, fish.Pattern)
            report = report .. string.format("    Remote: %s\n", fish.Remote)
            report = report .. string.format("    Path: %s\n", fish.RemotePath)
            report = report .. string.format("    Args: %s\n", fish.Args:sub(1, 100))
            report = report .. string.format("    Result: %s\n", fish.Result:sub(1, 50))
            report = report .. string.format("    Detection: %s\n", fish.GuiDetection)
            report = report .. "\n"
        end
    end
    
    if #self.State.WorkingTeleports > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[FISHING LOCATIONS & TELEPORTS]\n\n"
        
        for i, teleport in ipairs(self.State.WorkingTeleports) do
            report = report .. string.format("#%d - %s\n", i, teleport.LocationName)
            report = report .. string.format("    Position: %s\n", teleport.Position)
            report = report .. string.format("    Path: %s\n", teleport.Path)
            report = report .. string.format("    Status: ✅ TELEPORT WORKS\n")
            report = report .. "\n"
            
            if i >= 30 then
                report = report .. string.format("    ... and %d more working spots\n", #self.State.WorkingTeleports - 30)
                break
            end
        end
        
        if self.State.BestFishingSpot then
            report = report .. "\n>>> RECOMMENDED FISHING SPOT <<<\n"
            report = report .. string.format("  Location: %s\n", self.State.BestFishingSpot.LocationName)
            report = report .. string.format("  Position: %s\n", self.State.BestFishingSpot.Position)
            report = report .. string.format("  Teleport Command:\n")
            report = report .. string.format("  game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(%s))\n", self.State.BestFishingSpot.Position)
            report = report .. "\n"
        end
    end
    
    if #self.State.UnknownSuccesses > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[AI DISCOVERED PATTERNS]\n"
        report = report .. "🤖 Patterns discovered by AI analysis\n\n"
        
        for i, discovery in ipairs(self.State.UnknownSuccesses) do
            report = report .. string.format("#%d - %s\n", i, discovery.Remote)
            report = report .. string.format("    Pattern: %s\n", discovery.Pattern)
            report = report .. string.format("    Args: %s\n", discovery.Args:sub(1, 100))
            report = report .. string.format("    Type: %s\n", discovery.DiscoveryType)
            report = report .. string.format("    Result: %s\n", discovery.Result:sub(1, 50))
            report = report .. "\n"
            
            if i >= 20 then
                report = report .. string.format("    ... and %d more discoveries\n", #self.State.UnknownSuccesses - 20)
                break
            end
        end
    end
    
    if #self.State.DiscoveredPatterns > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[GUI INTERACTION PATTERNS]\n\n"
        
        for i, pattern in ipairs(self.State.DiscoveredPatterns) do
            report = report .. string.format("#%d - %s\n", i, pattern.ButtonName)
            report = report .. string.format("    Text: %s\n", pattern.ButtonText)
            report = report .. string.format("    Path: %s\n", pattern.Path)
            report = report .. string.format("    Type: %s\n", pattern.DiscoveryType)
            report = report .. "\n"
            
            if i >= 15 then
                report = report .. string.format("    ... and %d more patterns\n", #self.State.DiscoveredPatterns - 15)
                break
            end
        end
    end
    
    if #self.State.ErrorLog > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[ERROR LOG]\n"
        report = report .. "Errors encountered during research\n\n"
        
        for i, error in ipairs(self.State.ErrorLog) do
            report = report .. string.format("[%s] %s\n", error.Time, error.Context)
            report = report .. string.format("    Error: %s\n", error.Error:sub(1, 100))
            report = report .. "\n"
            
            if i >= 30 then
                report = report .. string.format("    ... and %d more errors\n", #self.State.ErrorLog - 30)
                break
            end
        end
    end
    
    if #self.State.FailedTests > 0 then
        report = report .. "\n" .. string.rep("-", 60) .. "\n"
        report = report .. "[PARTIAL/FAILED CONFIGURATIONS]\n\n"
        
        for i, config in ipairs(self.State.FailedTests) do
            report = report .. string.format("#%d - %s (%s)\n", i, config.Remote, config.Type)
            report = report .. string.format("    Args: %s\n", config.Args)
            report = report .. string.format("    Result: %s\n", config.Result)
            report = report .. "\n"
            
            if i >= 20 then
                report = report .. string.format("    ... and %d more failed tests\n", #self.State.FailedTests - 20)
                break
            end
        end
    end
    
    report = report .. "\n" .. string.rep("=", 60) .. "\n"
    report = report .. "END OF REPORT\n"
    report = report .. string.rep("=", 60) .. "\n"
    
    local filename = string.format("DEWA_Research_%s_%d.txt", Player.Name, os.time())
    
    if writefile then
        pcall(function()
            writefile(filename, report)
        end)
    end
    
    self:SendWebhookFile(
        filename,
        report,
        "📋 **DEWA RESEARCH - FINAL REPORT**\n\n✅ Research complete! Full detailed report attached."
    )
    
    self:SendWebhook(
        "📋 Final Report Generated",
        string.format(
            "Report saved as: %s\n\n" ..
            "Summary:\n" ..
            "• Total Tests: %d\n" ..
            "• Successful: %d\n" ..
            "• Captured Calls: %d\n" ..
            "• Success Rate: %d%%",
            filename,
            totalTests,
            #self.State.SuccessfulTests,
            #self.State.CapturedCalls,
            successRate
        ),
        3066993
    )
    
    self:UpdateStatus("Report generated: " .. filename)
end

function RESEARCH:StartFullAuto()
    if not self.Config.FullAutoMode then return end
    
    self:SendWebhook(
        "🤖 FULL AUTO MODE ACTIVATED",
        string.format(
            "**Starting automated research sequence...**\n\n" ..
            "Sequence:\n" ..
            "1️⃣ Instant Research (5 min)\n" ..
            "2️⃣ Anti-Lag Research (3 min)\n" ..
            "3️⃣ Location Research (2 min)\n" ..
            "4️⃣ Fish Injection (4 min)\n" ..
            "5️⃣ AI Discovery (3 min)\n" ..
            "6️⃣ Auto-Generate Report\n\n" ..
            "⏱️ Total estimated time: ~17 minutes\n" ..
            "💾 Auto-save enabled for all tests"
        ),
        3447003
    )
    
    local autoThread = task.spawn(function()
        for i, step in ipairs(self.Config.AutoSequence) do
            self:UpdateStatus(string.format("Auto: Starting %s (%d/%d)", step.name, i, #self.Config.AutoSequence))
            
            self:SendWebhook(
                string.format("▶️ Step %d/%d: %s Research", i, #self.Config.AutoSequence, step.name),
                string.format("Waiting %d seconds before start...", step.delay),
                16776960
            )
            
            task.wait(step.delay)
            
            if step.name == "Instant" then
                self.Config.InstantResearch = true
                self:StartInstantResearch()
            elseif step.name == "AntiLag" then
                self.Config.AntiLagResearch = true
                self:StartAntiLagResearch()
            elseif step.name == "Location" then
                self.Config.LocationResearch = true
                self:StartLocationResearch()
            elseif step.name == "FishData" then
                self.Config.FishDataResearch = true
                self:StartFishDataResearch()
            elseif step.name == "Discovery" then
                self.Config.DiscoveryMode = true
                self:StartDiscoveryMode()
            end
            
            self:SendWebhook(
                string.format("✅ %s Research Started", step.name),
                string.format("Running for ~%d seconds...", step.duration),
                65280
            )
            
            task.wait(step.duration)
            
            if step.name == "Instant" then
                self.Config.InstantResearch = false
            elseif step.name == "AntiLag" then
                self.Config.AntiLagResearch = false
            elseif step.name == "Location" then
                self.Config.LocationResearch = false
            elseif step.name == "FishData" then
                self.Config.FishDataResearch = false
            elseif step.name == "Discovery" then
                self.Config.DiscoveryMode = false
            end
            
            self:SendWebhook(
                string.format("⏹️ %s Research Stopped", step.name),
                "Moving to next step...",
                3447003
            )
            
            task.wait(5)
        end
        
        task.wait(10)
        
        if self.Config.AutoGenerateReport then
            self:UpdateStatus("Auto: Generating final report...")
            
            self:SendWebhook(
                "📋 AUTO-GENERATING FINAL REPORT",
                "Compiling all research data...",
                3447003
            )
            
            task.wait(3)
            self:GenerateFinalReport()
            
            task.wait(5)
            
            self:SendWebhook(
                "🎉 FULL AUTO RESEARCH COMPLETE!",
                string.format(
                    "**All research finished successfully!**\n\n" ..
                    "✅ Instant Research: Complete\n" ..
                    "✅ Anti-Lag Research: Complete\n" ..
                    "✅ Location Research: Complete\n" ..
                    "✅ Fish Injection: Complete\n" ..
                    "✅ AI Discovery: Complete\n" ..
                    "✅ Final Report: Generated\n\n" ..
                    "📊 Check your Discord for full results!\n" ..
                    "💾 All data saved to file"
                ),
                65280
            )
            
            self:UpdateStatus("Full auto complete! Check Discord.")
        end
    end)
    
    table.insert(self.Threads, autoThread)
end

function RESEARCH:CreateGUI()
    if PlayerGui:FindFirstChild("DEWA_RESEARCH_GUI") then
        PlayerGui.DEWA_RESEARCH_GUI:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DEWA_RESEARCH_GUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 280, 0, 400)
    MainFrame.Position = UDim2.new(1, -300, 0, 20)
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = MainFrame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(255, 200, 0)
    Stroke.Thickness = 2
    Stroke.Transparency = 0.3
    Stroke.Parent = MainFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -16, 0, 30)
    Title.Position = UDim2.new(0, 8, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "DEWA RESEARCH"
    Title.TextColor3 = Color3.fromRGB(255, 200, 0)
    Title.TextSize = 14
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame
    
    local function CreateToggle(text, yPos, callback)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, -16, 0, 36)
        Button.Position = UDim2.new(0, 8, 0, yPos)
        Button.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
        Button.Text = text .. ": OFF"
        Button.TextColor3 = Color3.fromRGB(220, 220, 220)
        Button.TextSize = 12
        Button.Font = Enum.Font.GothamBold
        Button.BorderSizePixel = 0
        Button.Parent = MainFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = Button
        
        local state = false
        Button.MouseButton1Click:Connect(function()
            state = not state
            Button.Text = text .. (state and ": ON" or ": OFF")
            Button.BackgroundColor3 = state and Color3.fromRGB(255, 150, 0) or Color3.fromRGB(25, 25, 28)
            callback(state)
        end)
        
        return Button
    end
    
    CreateToggle("Instant Research", 45, function(enabled)
        self.Config.InstantResearch = enabled
        if enabled then
            self:StartInstantResearch()
        end
    end)
    
    CreateToggle("Anti-Lag Research", 88, function(enabled)
        self.Config.AntiLagResearch = enabled
        if enabled then
            self:StartAntiLagResearch()
        end
    end)
    
    CreateToggle("Fish Injection", 131, function(enabled)
        self.Config.FishDataResearch = enabled
        if enabled then
            self:StartFishDataResearch()
        end
    end)
    
    CreateToggle("Location & Teleport", 174, function(enabled)
        self.Config.LocationResearch = enabled
        if enabled then
            self:StartLocationResearch()
        end
    end)
    
    CreateToggle("AI Discovery Mode", 217, function(enabled)
        self.Config.DiscoveryMode = enabled
        if enabled then
            self:StartDiscoveryMode()
        end
    end)
    
    local AutoBtn = Instance.new("TextButton")
    AutoBtn.Size = UDim2.new(1, -16, 0, 28)
    AutoBtn.Position = UDim2.new(0, 8, 0, 260)
    AutoBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
    AutoBtn.Text = "[AUTO] Start Full Auto (17 min)"
    AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoBtn.TextSize = 11
    AutoBtn.Font = Enum.Font.GothamBold
    AutoBtn.BorderSizePixel = 0
    AutoBtn.Parent = MainFrame
    
    local AutoCorner = Instance.new("UICorner")
    AutoCorner.CornerRadius = UDim.new(0, 6)
    AutoCorner.Parent = AutoBtn
    
    AutoBtn.MouseButton1Click:Connect(function()
        self.Config.FullAutoMode = true
        AutoBtn.Text = "Running Full Auto..."
        AutoBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
        self:StartFullAuto()
    end)
    
    local ReportBtn = Instance.new("TextButton")
    ReportBtn.Size = UDim2.new(1, -16, 0, 28)
    ReportBtn.Position = UDim2.new(0, 8, 0, 298)
    ReportBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
    ReportBtn.Text = "Generate Final Report"
    ReportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ReportBtn.TextSize = 11
    ReportBtn.Font = Enum.Font.GothamBold
    ReportBtn.BorderSizePixel = 0
    ReportBtn.Parent = MainFrame
    
    local ReportCorner = Instance.new("UICorner")
    ReportCorner.CornerRadius = UDim.new(0, 6)
    ReportCorner.Parent = ReportBtn
    
    ReportBtn.MouseButton1Click:Connect(function()
        self:GenerateFinalReport()
    end)
    
    local StatusBar = Instance.new("Frame")
    StatusBar.Size = UDim2.new(1, -16, 0, 32)
    StatusBar.Position = UDim2.new(0, 8, 1, -40)
    StatusBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    StatusBar.BorderSizePixel = 0
    StatusBar.Parent = MainFrame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 6)
    StatusCorner.Parent = StatusBar
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -12, 1, 0)
    StatusLabel.Position = UDim2.new(0, 6, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Ready to research"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    StatusLabel.TextSize = 10
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusBar
    
    self.GUI.StatusLabel = StatusLabel
    
    pcall(function()
        local dragging = false
        local dragStart = nil
        local startPos = nil
        
        MainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
            end
        end)
        
        MainFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        MainFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or 
               input.UserInputType == Enum.UserInputType.Touch then
                if dragging and dragStart and startPos then
                    local delta = input.Position - dragStart
                    MainFrame.Position = UDim2.new(
                        startPos.X.Scale,
                        startPos.X.Offset + delta.X,
                        startPos.Y.Scale,
                        startPos.Y.Offset + delta.Y
                    )
                end
            end
        end)
    end)
    
    self:UpdateStatus("Ready to research")
end

local success, err = pcall(function()
    RESEARCH:CreateGUI()
end)

if not success then
    warn("GUI Creation Error: " .. tostring(err))
    warn("Script loaded but GUI failed. Use _G.RESEARCH to access functions.")
end

if getgenv then
    getgenv().RESEARCH = RESEARCH
else
    _G.RESEARCH = RESEARCH
end

return RESEARCH
