local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local DEWA = {
    Version = "3.0-Phase1",
    Webhook = "https://ptb.discord.com/api/webhooks/1441678001396776970/_v41PNSbfFd76m9C4Iirb79RaYdRsFSpL91JwqltiPTQPimg5WvkTJAGolh4Hx_wxzgV",
    Running = false,
    
    Data = {
        Success = {},
        Errors = {},
        Tested = {},
        RemotesCaptured = {}
    },
    
    GUI = {}
}

function DEWA:SendFile(filename, content)
    spawn(function()
        pcall(function()
            local req = (syn and syn.request) or request or http_request or (http and http.request)
            if not req then return end
            
            local boundary = "----WebKitFormBoundary" .. tostring(math.random(1000000, 9999999))
            local body = "--" .. boundary .. "\r\n"
            body = body .. "Content-Disposition: form-data; name=\"file\"; filename=\"" .. filename .. "\"\r\n"
            body = body .. "Content-Type: text/plain\r\n\r\n"
            body = body .. content .. "\r\n"
            body = body .. "--" .. boundary .. "--\r\n"
            
            req({
                Url = self.Webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "multipart/form-data; boundary=" .. boundary},
                Body = body
            })
        end)
    end)
end

function DEWA:LogError(context, err)
    table.insert(self.Data.Errors, {
        Context = context,
        Error = tostring(err),
        Time = os.date("%H:%M:%S")
    })
    warn("[ERROR] " .. context .. ": " .. tostring(err))
end

function DEWA:ValidateRemote(remote)
    if not remote or not remote.Parent then
        return false
    end
    local ok = pcall(function()
        local _ = remote.Name
    end)
    return ok
end

function DEWA:GenerateHash(remote, args)
    local ok, hash = pcall(function()
        return remote.Name .. "_" .. HttpService:JSONEncode(args)
    end)
    return ok and hash or remote.Name
end

function DEWA:HasTested(hash)
    return self.Data.Tested[hash] ~= nil
end

function DEWA:MarkTested(hash)
    self.Data.Tested[hash] = true
end

function DEWA:AutoSave()
    pcall(function()
        if writefile then
            local filename = "DEWA_AutoSave_" .. Player.Name .. ".txt"
            local content = "DEWA V3 Phase 1\nTime: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n"
            content = content .. "Success: " .. #self.Data.Success .. "\n"
            content = content .. "Errors: " .. #self.Data.Errors .. "\n"
            
            writefile(filename, content)
        end
    end)
end

function DEWA:DetectSuccess()
    local found = false
    pcall(function()
        for _, obj in pairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local text = obj.Text:lower()
                if text:find("success") or text:find("complete") or text:find("caught") then
                    found = true
                    break
                end
            end
        end
    end)
    return found
end

function DEWA:UpdateStatus(text)
    if self.GUI.Status then
        self.GUI.Status.Text = text
    end
    print("[DEWA] " .. text)
end

function DEWA:StopAll()
    self.Running = false
    self:UpdateStatus("Stopping...")
    wait(2)
    
    if #self.Data.Success > 0 or #self.Data.Errors > 0 then
        self:UpdateStatus("Generating report...")
        wait(1)
        self:GenerateReport()
        self:UpdateStatus("Report sent")
    else
        self:UpdateStatus("Stopped")
    end
end

function DEWA:StartInstantResearch()
    if not self.Running then return end
    
    self:UpdateStatus("Starting Instant Research...")
    
    local thread = spawn(function()
        local remotes = {}
        
        pcall(function()
            for _, obj in pairs(game:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local n = obj.Name:lower()
                    if n:find("fish") or n:find("cast") or n:find("catch") or n:find("complete") then
                        if self:ValidateRemote(obj) then
                            table.insert(remotes, obj)
                        end
                    end
                end
            end
        end)
        
        self:UpdateStatus(string.format("Found %d remotes", #remotes))
        
        local patterns = {
            {}, {100}, {99}, {true}, {false},
            {"Perfect"}, {"Good"}, {"Complete"},
            {100, true}, {99, false}, {100, "Perfect"}
        }
        
        for i, remote in pairs(remotes) do
            if not self.Running then break end
            
            self:UpdateStatus(string.format("Testing %d/%d", i, #remotes))
            
            for _, args in pairs(patterns) do
                if not self.Running then break end
                
                local hash = self:GenerateHash(remote, args)
                if self:HasTested(hash) then
                    goto continue
                end
                
                local ok, res = pcall(function()
                    if remote:IsA("RemoteFunction") then
                        return remote:InvokeServer(unpack(args))
                    else
                        remote:FireServer(unpack(args))
                        return "fired"
                    end
                end)
                
                self:MarkTested(hash)
                
                if ok then
                    wait(0.5)
                    if self:DetectSuccess() then
                        table.insert(self.Data.Success, {
                            Remote = remote.Name,
                            Args = HttpService:JSONEncode(args),
                            Time = os.date("%H:%M:%S")
                        })
                        self:AutoSave()
                    end
                else
                    self:LogError("Instant Remote", res)
                end
                
                ::continue::
                wait(1)
            end
        end
        
        self:UpdateStatus("Instant research complete")
    end)
end

function DEWA:GenerateReport()
    local report = "DEWA V3 PHASE 1 REPORT\n"
    report = report .. "Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    report = report .. "Player: " .. Player.Name .. "\n\n"
    report = report .. string.rep("=", 60) .. "\n\n"
    
    report = report .. "STATISTICS\n"
    report = report .. "Success Tests: " .. #self.Data.Success .. "\n"
    report = report .. "Errors: " .. #self.Data.Errors .. "\n"
    report = report .. "Tested Combinations: " .. (function() local c=0 for _ in pairs(self.Data.Tested) do c=c+1 end return c end)() .. "\n\n"
    
    if #self.Data.Success > 0 then
        report = report .. string.rep("-", 60) .. "\n"
        report = report .. "SUCCESSFUL TESTS\n\n"
        for i, test in ipairs(self.Data.Success) do
            report = report .. string.format("[%d] %s - %s\n", i, test.Remote, test.Args)
            report = report .. "    Time: " .. test.Time .. "\n\n"
        end
    end
    
    if #self.Data.Errors > 0 then
        report = report .. string.rep("-", 60) .. "\n"
        report = report .. "ERRORS\n\n"
        for i, err in ipairs(self.Data.Errors) do
            report = report .. string.format("[%s] %s: %s\n\n", err.Time, err.Context, err.Error:sub(1, 100))
        end
    end
    
    report = report .. string.rep("=", 60) .. "\n"
    report = report .. "END OF REPORT\n"
    
    local filename = string.format("DEWA_Phase1_%s_%s.txt", Player.Name, os.date("%Y%m%d_%H%M%S"))
    self:SendFile(filename, report)
end

function DEWA:CreateGUI()
    pcall(function()
        if PlayerGui:FindFirstChild("DEWA_V3") then
            PlayerGui.DEWA_V3:Destroy()
        end
        
        local gui = Instance.new("ScreenGui")
        gui.Name = "DEWA_V3"
        gui.ResetOnSpawn = false
        gui.Parent = PlayerGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 250, 0, 150)
        frame.Position = UDim2.new(1, -270, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        frame.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -30, 0, 30)
        title.Position = UDim2.new(0, 10, 0, 5)
        title.BackgroundTransparency = 1
        title.Text = "DEWA V3 - PHASE 1"
        title.TextColor3 = Color3.fromRGB(255, 200, 0)
        title.TextSize = 14
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 25, 0, 25)
        closeBtn.Position = UDim2.new(1, -30, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextSize = 14
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Parent = frame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
        closeCorner.Parent = closeBtn
        
        closeBtn.MouseButton1Click:Connect(function()
            self:StopAll()
            gui:Destroy()
        end)
        
        local runBtn = Instance.new("TextButton")
        runBtn.Size = UDim2.new(1, -20, 0, 45)
        runBtn.Position = UDim2.new(0, 10, 0, 45)
        runBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        runBtn.Text = "RUN PHASE 1"
        runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        runBtn.TextSize = 14
        runBtn.Font = Enum.Font.GothamBold
        runBtn.Parent = frame
        
        local runCorner = Instance.new("UICorner")
        runCorner.CornerRadius = UDim.new(0, 8)
        runCorner.Parent = runBtn
        
        runBtn.MouseButton1Click:Connect(function()
            self.Running = not self.Running
            if self.Running then
                runBtn.Text = "STOP"
                runBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                self:StartInstantResearch()
            else
                runBtn.Text = "RUN PHASE 1"
                runBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                self:StopAll()
            end
        end)
        
        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -20, 0, 30)
        status.Position = UDim2.new(0, 10, 1, -40)
        status.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        status.Text = "Phase 1: Core Systems Ready"
        status.TextColor3 = Color3.fromRGB(0, 255, 100)
        status.TextSize = 10
        status.Font = Enum.Font.Gotham
        status.Parent = frame
        
        local statusCorner = Instance.new("UICorner")
        statusCorner.CornerRadius = UDim.new(0, 6)
        statusCorner.Parent = status
        
        self.GUI.Status = status
    end)
end

print("[DEWA V3] Phase 1 Loading...")
DEWA:CreateGUI()
print("[DEWA V3] Phase 1 Ready!")

_G.DEWA = DEWA
return DEWA
