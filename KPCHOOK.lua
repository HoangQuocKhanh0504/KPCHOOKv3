-- ============================================================
-- KPCHOOK v4 — Fix Unlock All HOẠT ĐỘNG
-- - Hook OwnsCosmetic + ItemLibrary + ShopLibrary + DataController (client-side spoof)
-- - Hook _CreateViewModel + ClientViewModel.new (viewmodel override)
-- - Hook EquipCosmetic FireServer (lưu equipped vào config)
-- - Bỏ rawset trên function (lỗi cũ)
-- - Re-hook viewmodel mỗi khi equipped thay đổi
-- ============================================================

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/twistedk1d/BloxStrike/refs/heads/main/Source/UI/source.lua"))()

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local HttpService          = game:GetService("HttpService")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local CoreGui              = game:GetService("CoreGui")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local Workspace            = game:GetService("Workspace")
local MarketplaceService   = game:GetService("MarketplaceService")

local player        = Players.LocalPlayer
local playerScripts = player.PlayerScripts
local controllers   = playerScripts.Controllers
local cam           = workspace.CurrentCamera
local lplr          = player

-- ============================================================
-- KEY AUTH
-- ============================================================
local KEY_URL       = "https://raw.githubusercontent.com/HoangQuocKhanh0504/KPCHOOK/refs/heads/root/keys.lua"
local KEY_FILE      = "kpchook/key.json"
local KEYOLD_FILE   = "kpchook/.keyold.dat"
local KEY_FOLDER    = "kpchook"
local CONFIG_FILE   = "kpchook/kpchook.json"
local CONFIG_FOLDER = "kpchook"

local function ensureKeyFolder()
    if makefolder then pcall(makefolder, KEY_FOLDER) end
end

local function getNow() return os.time() end

local function formatTime(sec)
    sec = math.max(0, math.floor(sec))
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm %ds", h, m, s) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

local function readSavedKey()
    ensureKeyFolder()
    if not isfile or not readfile then return nil end
    if not isfile(KEY_FILE) then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(KEY_FILE)) end)
    if not ok or type(data) ~= "table" then return nil end
    if type(data.key) ~= "string" then return nil end
    return data
end

local function saveKey(keyStr, duration, keyType)
    ensureKeyFolder()
    if not writefile then return end
    local now = getNow()
    local payload = { key = keyStr, activated_at = now, expires_at = now + duration, type = keyType or "unknown" }
    pcall(function() writefile(KEY_FILE, HttpService:JSONEncode(payload)) end)
end

local function clearSavedKey()
    if delfile and isfile and isfile(KEY_FILE) then pcall(delfile, KEY_FILE) end
end

local function readKeyOldFile()
    ensureKeyFolder()
    if not isfile or not readfile then return {} end
    if not isfile(KEYOLD_FILE) then return {} end
    local ok, raw = pcall(readfile, KEYOLD_FILE)
    if not ok or type(raw) ~= "string" then return {} end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return {} end
    if type(data.keys) ~= "table" then return {} end
    return data.keys
end

local function readKeyOldFromConfig()
    if not isfile or not readfile then return {} end
    if not isfile(CONFIG_FILE) then return {} end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" then return {} end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return {} end
    if type(data._keyold_backup) ~= "table" then return {} end
    return data._keyold_backup
end

local function readKeyOld()
    local fromFile   = readKeyOldFile()
    local fromConfig = readKeyOldFromConfig()
    local merged = {}
    for k, v in pairs(fromFile) do merged[k] = v end
    for k, v in pairs(fromConfig) do
        if not merged[k] then merged[k] = v end
    end
    local missingInFile = false
    for k in pairs(fromConfig) do
        if not fromFile[k] then missingInFile = true; break end
    end
    if missingInFile and writefile then
        pcall(function()
            writefile(KEYOLD_FILE, HttpService:JSONEncode({ keys = merged }))
        end)
    end
    return merged
end

local function isKeyUsedBefore(keyStr)
    local old = readKeyOld()
    return old[keyStr] ~= nil
end

local function markKeyUsed(keyStr, duration, keyType)
    ensureKeyFolder()
    local old = readKeyOld()
    old[keyStr] = {
        first_used_at = getNow(),
        duration      = duration,
        type          = keyType,
        expired_at    = getNow() + duration,
    }
    if writefile then
        pcall(function()
            writefile(KEYOLD_FILE, HttpService:JSONEncode({ keys = old }))
        end)
    end
    if isfile and isfile(CONFIG_FILE) and readfile and writefile then
        pcall(function()
            local raw = readfile(CONFIG_FILE)
            local cfg = HttpService:JSONDecode(raw)
            if type(cfg) == "table" then
                cfg._keyold_backup = old
                writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
            end
        end)
    end
    return true
end

local function restoreKeyOldFile()
    if not isfile or not readfile or not writefile then return end
    if isfile(KEYOLD_FILE) then return end
    local backup = readKeyOldFromConfig()
    if next(backup) then
        pcall(function()
            writefile(KEYOLD_FILE, HttpService:JSONEncode({ keys = backup }))
        end)
        print("[KeyOld] Restored from config backup")
    end
end

local function fetchKeys()
    local ok, result = pcall(function()
        return game:HttpGet(KEY_URL .. "?t=" .. tostring(getNow()), true)
    end)
    if not ok or type(result) ~= "string" or #result < 10 then
        return nil, "Không tải được danh sách key"
    end
    local chunk, err = loadstring(result, "keys")
    if not chunk then return nil, "Lỗi parse keys.lua: " .. tostring(err) end
    local ok2, keys = pcall(chunk)
    if not ok2 or type(keys) ~= "table" then return nil, "keys.lua không trả về table" end
    return keys
end

local function checkLocalKey()
    local saved = readSavedKey()
    if not saved then return false, nil end
    if type(saved.expires_at) ~= "number" then
        clearSavedKey()
        return false, nil
    end
    local now = getNow()
    if now >= saved.expires_at then
        clearSavedKey()
        return false, saved
    end
    return true, saved
end

local function showKeyPrompt()
    local ok = checkLocalKey()
    if ok then return true end

    local gui = Instance.new("ScreenGui")
    gui.Name = "KPCHOOK_KeyPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        if gethui then gui.Parent = gethui() else gui.Parent = CoreGui end
    end)
    if not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 420, 0, 280)
    bg.Position = UDim2.new(0.5, 0, 0.5, 0)
    bg.AnchorPoint = Vector2.new(0.5, 0.5)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(140, 100, 255)
    stroke.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "🔐 KPCHOOK — Nhập Key"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.Parent = bg

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -40, 0, 40)
    sub.Position = UDim2.new(0, 20, 0, 60)
    sub.BackgroundTransparency = 1
    sub.Text = "Nhập key 16 ký tự để sử dụng script"
    sub.TextColor3 = Color3.fromRGB(180, 180, 200)
    sub.TextSize = 13
    sub.Font = Enum.Font.Gotham
    sub.TextWrapped = true
    sub.Parent = bg

    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -60, 0, 44)
    inputFrame.Position = UDim2.new(0, 30, 0, 115)
    inputFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    inputFrame.BorderSizePixel = 0
    inputFrame.Parent = bg

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputFrame

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Thickness = 1
    inputStroke.Color = Color3.fromRGB(80, 80, 100)
    inputStroke.Parent = inputFrame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -20, 1, 0)
    input.Position = UDim2.new(0, 10, 0, 0)
    input.BackgroundTransparency = 1
    input.Text = ""
    input.PlaceholderText = "Nhập key 16 ký tự..."
    input.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.TextSize = 16
    input.Font = Enum.Font.Code
    input.ClearTextOnFocus = false
    input.TextXAlignment = Enum.TextXAlignment.Center
    input.Parent = inputFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 30)
    statusLabel.Position = UDim2.new(0, 20, 0, 170)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.TextSize = 13
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = bg

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -60, 0, 44)
    btn.Position = UDim2.new(0, 30, 0, 210)
    btn.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
    btn.BorderSizePixel = 0
    btn.Text = "✅  XÁC THỰC"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.Parent = bg

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    task.wait(0.1)
    pcall(function() input:CaptureFocus() end)

    local done, result = false, false

    btn.MouseButton1Click:Connect(function()
        if done then return end
        local entered = (input.Text or ""):gsub("%s", "")
        if #entered ~= 16 then
            statusLabel.Text = "❌ Key phải đúng 16 ký tự (hiện: " .. #entered .. ")"
            return
        end
        statusLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        statusLabel.Text = "⏳ Đang xác thực..."
        task.spawn(function()
            local keys, err = fetchKeys()
            if not keys then
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                statusLabel.Text = "❌ " .. tostring(err)
                return
            end
            local entry = keys[entered]
            if not entry then
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                statusLabel.Text = "❌ Key không hợp lệ"
                return
            end
            if isKeyUsedBefore(entered) then
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                statusLabel.Text = "❌ Key này đã được sử dụng rồi (không thể dùng lại)"
                return
            end
            local duration = tonumber(entry.duration) or 0
            local keyType  = entry.type or "unknown"
            if duration <= 0 then
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                statusLabel.Text = "❌ Key bị vô hiệu hóa"
                return
            end
            markKeyUsed(entered, duration, keyType)
            saveKey(entered, duration, keyType)
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
            statusLabel.Text = "✅ Thành công! " .. keyType .. " — " .. formatTime(duration)
            done, result = true, true
            task.wait(1)
            pcall(function() gui:Destroy() end)
        end)
    end)

    repeat task.wait(0.1) until done or not gui.Parent
    return result
end

local function requireKey()
    local ok = checkLocalKey()
    if not ok then
        local success = showKeyPrompt()
        if not success then return false end
    end
    local _, saved = checkLocalKey()
    if saved then
        local remaining = saved.expires_at - getNow()
        print(string.format("[KEY] Đã xác thực — Loại: %s | Còn lại: %s", tostring(saved.type), formatTime(remaining)))
    end
    return true
end

if not requireKey() then
    warn("[KPCHOOK] Không có key hợp lệ — script dừng.")
    return
end

restoreKeyOldFile()

repeat task.wait() until game:IsLoaded()
if not lplr.Character then lplr.CharacterAdded:Wait() end
lplr.Character:WaitForChild("Humanoid", 30)

-- ============================================================
-- CONFIG DEFAULT
-- ============================================================
local DEFAULT_EXCHANGE = {
    player_level   = "auto", player_xp      = "auto",
    weapon_level   = "auto", weapon_xp      = "auto",
    prestige       = "auto", unlock_tokens  = "auto",
    weapon_keys    = "auto", glory          = "auto",
    skin_tickets   = "auto", event_currency = "auto",
    gift_tickets   = "auto",
}

local CONFIG = {
    SilentAimEnabled = false, MaxDistance = 3000, IgnoreTeam = true,
    CacheTime = 0.15, FOV = 100, CheckWall = true,
    UnlockAllActive = false, Exchange = table.clone(DEFAULT_EXCHANGE),

    MouseAimEnabled = false, MouseAimHoldRMB = true, MouseAimSpeed = 1.0,
    MouseAimPart = "Head", MouseAimFOV = 150, MouseAimMaxDistance = 800,
    MouseAimCheckWall = true, MouseAimIgnoreTeam = true,
    MouseAimRequireWeapon = true, MouseAimToggleKey = Enum.KeyCode.RightAlt,

    ESP_Enabled = false, ESP_OnlyWhenWeapon = true, ESP_Distance = 500,
    ESP_ShowHealth = true, ESP_ShowName = true, ESP_ShowBox = true, ESP_ShowHighlight = true,
    ESP_HealthFullColor = Color3.fromRGB(0, 255, 80),
    ESP_HealthMidColor  = Color3.fromRGB(255, 220, 0),
    ESP_HealthLowColor  = Color3.fromRGB(255, 0, 0),
    ESP_HealthMidPoint  = 0.5,

    Rage_Mode = "RageV1", Rage_Enabled = false, Rage_RequireWeapon = true,
    Rage_V1_MaxDistance = 300, Rage_FireRate = 0.0002, Rage_AutoSwitch = true,
    Rage_Desync = true, Rage_MeleeKeep = true, Rage_AutoPickup = true,
    Rage_ShowEnemyWeapon = true, Rage_UseRealAmmo = true, Rage_WeaponSlot = "Primary",
    Rage_SwitchThreshold = 1, Rage_VelocityMultiplier = -1500,
    Rage_DesyncJitter = 4.5, Rage_DesyncYaw = 180, Rage_DesyncPitch = 0, Rage_DesyncRoll = 0,

    AvatarBorderColor = { r = 140/255, g = 100/255, b = 255/255 },
    AvatarBorderThickness = 3,
    AvatarSide = "Left",

    MenuKeybind = Enum.KeyCode.RightShift, Theme = "DarkBlue",
    MAX_NUM = 9007199254740991,
}
local MAX_NUM = CONFIG.MAX_NUM

local function getExchangeValue(key)
    local v = CONFIG.Exchange[key]
    if v == "auto" or v == nil then return nil end
    return tonumber(v)
end

local GameOriginal = {}
local PlayerStats  = {}

-- ============================================================
-- CONFIG SYSTEM
-- ============================================================
local equipped, favorites = {}, {}
local ConfigData = { version = 3, settings = {}, equipped = {}, favorites = {} }
local isConfigLoaded, isLoadingConfig = false, true

local function ensureFolder()
    if makefolder then pcall(makefolder, CONFIG_FOLDER) end
end

local function keyCodeToString(kc)
    if typeof(kc) == "EnumItem" then return kc.Name end
    return tostring(kc)
end

local function stringToKeyCode(s)
    if type(s) ~= "string" then return Enum.KeyCode.RightShift end
    local ok, kc = pcall(function() return Enum.KeyCode[s] end)
    if ok and kc then return kc end
    return Enum.KeyCode.RightShift
end

local function colorToString(c)
    if typeof(c) == "Color3" then return { r = c.R, g = c.G, b = c.B } end
    if type(c) == "table" and c.r and c.g and c.b then return c end
    return nil
end

local function stringToColor(t)
    if type(t) ~= "table" then return nil end
    return Color3.new(tonumber(t.r) or 1, tonumber(t.g) or 1, tonumber(t.b) or 1)
end

local function createDefaultConfigData()
    return {
        version = 3,
        settings = {
            silent_aim = { enabled = false, fov = 100, max_distance = 3000, cache_time = 0.15, check_wall = true, ignore_team = true },
            mouse_aim = { enabled = false, hold_rmb = true, speed = 1.0, aim_part = "Head", fov = 150, max_distance = 800, check_wall = true, ignore_team = true, require_weapon = true, toggle_key = "RightAlt" },
            esp = { enabled = false, only_when_weapon = true, distance = 500, show_health = true, show_name = true, show_box = true, show_highlight = true, color_full = { r = 0, g = 1, b = 0.31 }, color_mid = { r = 1, g = 0.86, b = 0 }, color_low = { r = 1, g = 0, b = 0 }, mid_point = 0.5 },
            rage = { mode = "RageV1", enabled = false, require_weapon = true, v1_max_distance = 300, fire_rate = 0.0002, auto_switch = true, desync = true, melee_keep = true, auto_pickup = true, show_enemy_weapon = true, use_real_ammo = true, weapon_slot = "Primary", switch_threshold = 1, velocity_multiplier = -1500, desync_jitter = 4.5, desync_yaw = 180, desync_pitch = 0, desync_roll = 0 },
            unlock_all = { active = false },
            exchange = table.clone(DEFAULT_EXCHANGE),
            ui = { theme = "DarkBlue", menu_keybind = "RightShift", avatar_border_color = { r = 140/255, g = 100/255, b = 255/255 }, avatar_border_thickness = 3, avatar_side = "Left" },
        },
        equipped = {}, favorites = {},
    }
end

local function readConfigFile()
    if not readfile or not isfile then return nil end
    if not isfile(CONFIG_FILE) then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok or type(decoded) ~= "table" then return nil end
    return decoded
end

local function syncConfigData()
    ConfigData.settings = ConfigData.settings or {}
    ConfigData.settings.silent_aim = { enabled = CONFIG.SilentAimEnabled, fov = CONFIG.FOV, max_distance = CONFIG.MaxDistance, cache_time = CONFIG.CacheTime, check_wall = CONFIG.CheckWall, ignore_team = CONFIG.IgnoreTeam }
    ConfigData.settings.mouse_aim = { enabled = CONFIG.MouseAimEnabled, hold_rmb = CONFIG.MouseAimHoldRMB, speed = CONFIG.MouseAimSpeed, aim_part = CONFIG.MouseAimPart, fov = CONFIG.MouseAimFOV, max_distance = CONFIG.MouseAimMaxDistance, check_wall = CONFIG.MouseAimCheckWall, ignore_team = CONFIG.MouseAimIgnoreTeam, require_weapon = CONFIG.MouseAimRequireWeapon, toggle_key = keyCodeToString(CONFIG.MouseAimToggleKey) }
    ConfigData.settings.esp = { enabled = CONFIG.ESP_Enabled, only_when_weapon = CONFIG.ESP_OnlyWhenWeapon, distance = CONFIG.ESP_Distance, show_health = CONFIG.ESP_ShowHealth, show_name = CONFIG.ESP_ShowName, show_box = CONFIG.ESP_ShowBox, show_highlight = CONFIG.ESP_ShowHighlight, color_full = colorToString(CONFIG.ESP_HealthFullColor), color_mid = colorToString(CONFIG.ESP_HealthMidColor), color_low = colorToString(CONFIG.ESP_HealthLowColor), mid_point = CONFIG.ESP_HealthMidPoint }
    ConfigData.settings.rage = {
        mode = CONFIG.Rage_Mode, enabled = false, require_weapon = CONFIG.Rage_RequireWeapon,
        v1_max_distance = CONFIG.Rage_V1_MaxDistance, fire_rate = CONFIG.Rage_FireRate,
        auto_switch = CONFIG.Rage_AutoSwitch, desync = CONFIG.Rage_Desync,
        melee_keep = CONFIG.Rage_MeleeKeep, auto_pickup = CONFIG.Rage_AutoPickup,
        show_enemy_weapon = CONFIG.Rage_ShowEnemyWeapon, use_real_ammo = CONFIG.Rage_UseRealAmmo,
        weapon_slot = CONFIG.Rage_WeaponSlot, switch_threshold = CONFIG.Rage_SwitchThreshold,
        velocity_multiplier = CONFIG.Rage_VelocityMultiplier, desync_jitter = CONFIG.Rage_DesyncJitter,
        desync_yaw = CONFIG.Rage_DesyncYaw, desync_pitch = CONFIG.Rage_DesyncPitch, desync_roll = CONFIG.Rage_DesyncRoll,
    }
    ConfigData.settings.unlock_all = { active = CONFIG.UnlockAllActive }
    ConfigData.settings.exchange   = table.clone(CONFIG.Exchange)
    ConfigData.settings.ui = {
        theme = CONFIG.Theme, menu_keybind = keyCodeToString(CONFIG.MenuKeybind),
        avatar_border_color = colorToString(CONFIG.AvatarBorderColor),
        avatar_border_thickness = CONFIG.AvatarBorderThickness, avatar_side = CONFIG.AvatarSide,
    }

    ConfigData.equipped = ConfigData.equipped or {}
    for weapon, cosmetics in pairs(equipped) do
        ConfigData.equipped[weapon] = ConfigData.equipped[weapon] or {}
        for cType, cData in pairs(cosmetics) do
            if cData and cData.Name then
                ConfigData.equipped[weapon][cType] = { name = cData.Name, seed = cData.Seed, inverted = cData.Inverted }
            end
        end
    end
    ConfigData.favorites = ConfigData.favorites or {}
    for cat, favs in pairs(favorites) do
        ConfigData.favorites[cat] = ConfigData.favorites[cat] or {}
        for name, state in pairs(favs) do
            if state then ConfigData.favorites[cat][name] = true end
        end
    end
    ConfigData.version = 3

    local currentKeyOld = readKeyOld()
    if next(currentKeyOld) then
        ConfigData._keyold_backup = currentKeyOld
    end
end

local function saveConfigNow()
    if not isConfigLoaded or isLoadingConfig then return end
    if not writefile then return end
    ensureFolder()
    if isfile and isfile(CONFIG_FILE) then
        pcall(function() writefile(CONFIG_FILE .. ".backup", readfile(CONFIG_FILE)) end)
    end
    syncConfigData()
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigData)) end)
end

local saveScheduled = false
local function scheduleSave()
    if not isConfigLoaded or isLoadingConfig then return end
    if saveScheduled then return end
    saveScheduled = true
    task.delay(2, function()
        saveScheduled = false
        saveConfigNow()
    end)
end

local function loadOrCreateConfig()
    ensureFolder()
    local decoded = readConfigFile()
    if not decoded then
        print("[Config] Tạo file mặc định")
        ConfigData = createDefaultConfigData()
        if writefile then
            pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigData)) end)
        end
        return false
    end

    ConfigData = decoded
    ConfigData.version   = decoded.version or 1
    ConfigData.equipped  = decoded.equipped or {}
    ConfigData.favorites = decoded.favorites or {}
    ConfigData.settings  = decoded.settings or {}

    local s = ConfigData.settings or {}
    local sa = s.silent_aim or {}
    if sa.enabled      ~= nil then CONFIG.SilentAimEnabled = sa.enabled end
    if sa.fov          ~= nil then CONFIG.FOV             = sa.fov end
    if sa.max_distance ~= nil then CONFIG.MaxDistance     = sa.max_distance end
    if sa.cache_time   ~= nil then CONFIG.CacheTime       = sa.cache_time end
    if sa.check_wall   ~= nil then CONFIG.CheckWall       = sa.check_wall end
    if sa.ignore_team  ~= nil then CONFIG.IgnoreTeam      = sa.ignore_team end

    local ma = s.mouse_aim or {}
    if ma.enabled        ~= nil then CONFIG.MouseAimEnabled       = ma.enabled end
    if ma.hold_rmb       ~= nil then CONFIG.MouseAimHoldRMB       = ma.hold_rmb end
    if ma.speed          ~= nil then CONFIG.MouseAimSpeed         = ma.speed end
    if ma.aim_part       ~= nil then CONFIG.MouseAimPart          = ma.aim_part end
    if ma.fov            ~= nil then CONFIG.MouseAimFOV           = ma.fov end
    if ma.max_distance   ~= nil then CONFIG.MouseAimMaxDistance   = ma.max_distance end
    if ma.check_wall     ~= nil then CONFIG.MouseAimCheckWall     = ma.check_wall end
    if ma.ignore_team    ~= nil then CONFIG.MouseAimIgnoreTeam    = ma.ignore_team end
    if ma.require_weapon ~= nil then CONFIG.MouseAimRequireWeapon = ma.require_weapon end
    if ma.toggle_key     ~= nil then CONFIG.MouseAimToggleKey     = stringToKeyCode(ma.toggle_key) end

    local e = s.esp or {}
    if e.enabled          ~= nil then CONFIG.ESP_Enabled         = e.enabled end
    if e.only_when_weapon ~= nil then CONFIG.ESP_OnlyWhenWeapon  = e.only_when_weapon end
    if e.distance         ~= nil then CONFIG.ESP_Distance        = e.distance end
    if e.show_health      ~= nil then CONFIG.ESP_ShowHealth      = e.show_health end
    if e.show_name        ~= nil then CONFIG.ESP_ShowName        = e.show_name end
    if e.show_box         ~= nil then CONFIG.ESP_ShowBox         = e.show_box end
    if e.show_highlight   ~= nil then CONFIG.ESP_ShowHighlight   = e.show_highlight end
    if e.color_full       ~= nil then local c = stringToColor(e.color_full); if c then CONFIG.ESP_HealthFullColor = c end end
    if e.color_mid        ~= nil then local c = stringToColor(e.color_mid); if c then CONFIG.ESP_HealthMidColor = c end end
    if e.color_low        ~= nil then local c = stringToColor(e.color_low); if c then CONFIG.ESP_HealthLowColor = c end end
    if e.mid_point        ~= nil then CONFIG.ESP_HealthMidPoint = e.mid_point end

    local r = s.rage or {}
    if r.mode                ~= nil then CONFIG.Rage_Mode               = r.mode end
    if r.require_weapon      ~= nil then CONFIG.Rage_RequireWeapon      = r.require_weapon end
    if r.v1_max_distance     ~= nil then CONFIG.Rage_V1_MaxDistance     = r.v1_max_distance end
    if r.fire_rate           ~= nil then CONFIG.Rage_FireRate           = r.fire_rate end
    if r.auto_switch         ~= nil then CONFIG.Rage_AutoSwitch         = r.auto_switch end
    if r.desync              ~= nil then CONFIG.Rage_Desync             = r.desync end
    if r.melee_keep          ~= nil then CONFIG.Rage_MeleeKeep          = r.melee_keep end
    if r.auto_pickup         ~= nil then CONFIG.Rage_AutoPickup         = r.auto_pickup end
    if r.show_enemy_weapon   ~= nil then CONFIG.Rage_ShowEnemyWeapon    = r.show_enemy_weapon end
    if r.use_real_ammo       ~= nil then CONFIG.Rage_UseRealAmmo        = r.use_real_ammo end
    if r.weapon_slot         ~= nil then CONFIG.Rage_WeaponSlot         = r.weapon_slot end
    if r.switch_threshold    ~= nil then CONFIG.Rage_SwitchThreshold    = r.switch_threshold end
    if r.velocity_multiplier ~= nil then CONFIG.Rage_VelocityMultiplier = r.velocity_multiplier end
    if r.desync_jitter       ~= nil then CONFIG.Rage_DesyncJitter       = r.desync_jitter end
    if r.desync_yaw          ~= nil then CONFIG.Rage_DesyncYaw          = r.desync_yaw end
    if r.desync_pitch        ~= nil then CONFIG.Rage_DesyncPitch        = r.desync_pitch end
    if r.desync_roll         ~= nil then CONFIG.Rage_DesyncRoll         = r.desync_roll end

    CONFIG.Rage_Enabled = false

    local ua = s.unlock_all or {}
    if ua.active ~= nil then CONFIG.UnlockAllActive = ua.active end

    local ex = s.exchange or {}
    for key, defVal in pairs(DEFAULT_EXCHANGE) do
        if ex[key] ~= nil then CONFIG.Exchange[key] = ex[key] else CONFIG.Exchange[key] = defVal end
    end

    local ui = s.ui or {}
    if ui.theme then CONFIG.Theme = ui.theme end
    if ui.menu_keybind then CONFIG.MenuKeybind = stringToKeyCode(ui.menu_keybind) end
    if ui.avatar_border_color then CONFIG.AvatarBorderColor = ui.avatar_border_color end
    if ui.avatar_border_thickness then CONFIG.AvatarBorderThickness = ui.avatar_border_thickness end
    if ui.avatar_side then CONFIG.AvatarSide = ui.avatar_side end

    print("[Config] Loaded (Rage forced OFF)")
    return true
end

-- ============================================================
-- BIẾN QUAN TRỌNG — KHAI BÁO TRƯỚC
-- ============================================================
local Gun, U, FighterController
local isHoldingWeapon = function() return false end
local equipHookInstalled = false
local equipHookOK = false
local installEquipHook = nil
local equippedChangedSignal = Instance.new("BindableEvent") -- Signal để trigger re-render viewmodel

-- ============================================================
-- LOAD CONFIG + UI
-- ============================================================
local hasConfigFile = loadOrCreateConfig()

local hasHookMeta = (type(hookmetamethod) == "function") and (type(getnamecallmethod) == "function")
print("[Hook] hookmetamethod:", hasHookMeta and "YES" or "NO")

local ExecutorInfo = { Name = "Unknown", Version = "Unknown" }
if identifyexecutor then
    local ok, name, version = pcall(identifyexecutor)
    if ok then
        ExecutorInfo.Name    = name or "Unknown"
        ExecutorInfo.Version = version or "Unknown"
    end
end

local mouseAimHasMoveRel = (type(mousemoverel) == "function")
local mouseAimRMBHeld = false
local currentRayfieldGui = nil
local avatarGui = nil
local avatarFrame = nil
local avatarImg = nil
local avatarInner = nil

local Window = Rayfield:CreateWindow({
    Name = "KPCHOOK v4", Icon = 0,
    LoadingTitle = "KPCHOOK v4", LoadingSubtitle = "Config: kpchook.json",
    Theme = CONFIG.Theme, DisableRayfieldPrompts = false, DisableBuildWarnings = true,
    ConfigurationSaving = { Enabled = false }, Discord = { Enabled = false },
    KeySystem = false, ToggleUIKeybind = Enum.KeyCode.RightShift,
})

task.wait(0.3)

pcall(function()
    if Rayfield.SetToggleKeybind then Rayfield:SetToggleKeybind(CONFIG.MenuKeybind) end
    if Rayfield.SetKeybind then Rayfield:SetKeybind(CONFIG.MenuKeybind) end
end)
pcall(function()
    for _, name in ipairs({"ToggleUI", "RayfieldToggle", "ToggleRayfield", "RayfieldKeybind", "ToggleInterface", "Toggle"}) do
        ContextActionService:UnbindAction(name)
    end
end)

local function findRayfieldGui()
    if get_hidden_gui then
        local ok, hg = pcall(get_hidden_gui)
        if ok and hg then
            local gui = hg:FindFirstChild("Rayfield")
            if gui and gui:IsA("ScreenGui") then return gui end
        end
    end
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            local gui = hui:FindFirstChild("Rayfield")
            if gui and gui:IsA("ScreenGui") then return gui end
        end
    end
    for _, root in ipairs({CoreGui, lplr:FindFirstChild("PlayerGui")}) do
        if root then
            local gui = root:FindFirstChild("Rayfield")
            if gui and gui:IsA("ScreenGui") then return gui end
        end
    end
    return nil
end

task.spawn(function()
    for _ = 1, 30 do
        currentRayfieldGui = findRayfieldGui()
        if currentRayfieldGui then break end
        task.wait(0.2)
    end
end)

RunService:BindToRenderStep("KPCHOOKCursor", 2001, function()
    if not currentRayfieldGui or not currentRayfieldGui.Parent then
        currentRayfieldGui = findRayfieldGui()
        if not currentRayfieldGui then return end
    end

    local main = currentRayfieldGui:FindFirstChild("Main")
    if not main then return end

    if main.Visible then
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end)
        end
        if not UserInputService.MouseIconEnabled then
            pcall(function()
                UserInputService.MouseIconEnabled = true
            end)
        end
    end
end)

-- ============================================================
-- TAB PLAYER INFO (same as before)
-- ============================================================
task.wait(0.15)
local Tab_Player = Window:CreateTab("Player Info", "user")

local function accountAgeStr(days)
    local y = math.floor(days / 365)
    local rem = days - y * 365
    local m = math.floor(rem / 30)
    local d = rem - m * 30
    local parts = {}
    if y > 0 then table.insert(parts, y .. " năm") end
    if m > 0 then table.insert(parts, m .. " tháng") end
    if d > 0 then table.insert(parts, d .. " ngày") end
    if #parts == 0 then parts = { "0 ngày" } end
    return table.concat(parts, " ")
end

local function getJoinDate(accAge)
    local t = os.time() - accAge * 86400
    return os.date("%d/%m/%Y", t)
end

local function getMembershipText()
    local m = tostring(lplr.MembershipType)
    return (m:gsub("Enum.MembershipType%.", ""))
end

local function getTeamText()
    if lplr.Team then return lplr.Team.Name end
    return "Không có"
end

Tab_Player:CreateSection("👤 Thông tin cơ bản")
Tab_Player:CreateLabel("• Username: " .. lplr.Name)
Tab_Player:CreateLabel("• Display Name: " .. lplr.DisplayName)
Tab_Player:CreateLabel("• User ID: " .. tostring(lplr.UserId))
Tab_Player:CreateLabel("• Trạng thái: Đang chơi")
Tab_Player:CreateLabel("• Team: " .. getTeamText())

Tab_Player:CreateSection("📅 Tài khoản")
Tab_Player:CreateLabel("• Tuổi tài khoản: " .. accountAgeStr(lplr.AccountAge))
Tab_Player:CreateLabel("• Ngày tham gia: " .. getJoinDate(lplr.AccountAge))
Tab_Player:CreateLabel("• Membership: " .. getMembershipText())
Tab_Player:CreateLabel("• Có Roblox Premium: " .. (lplr.MembershipType == Enum.MembershipType.Premium and "✅ Có" or "❌ Không"))

-- ============================================================
-- AVATAR (same)
-- ============================================================
local function createAvatarGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "KPCHOOK_Avatar"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 5
    pcall(function()
        if gethui then gui.Parent = gethui() else gui.Parent = CoreGui end
    end)
    if not gui.Parent then gui.Parent = lplr:WaitForChild("PlayerGui") end

    local wrapper = Instance.new("Frame")
    wrapper.Name = "AvatarBox"
    wrapper.Size = UDim2.fromOffset(110, 110)
    wrapper.Position = UDim2.new(0, 0, 0, 0)
    wrapper.BackgroundTransparency = 1
    wrapper.BorderSizePixel = 0
    wrapper.Visible = false
    wrapper.Parent = gui

    local inner = Instance.new("Frame")
    inner.Name = "AvatarInner"
    inner.Size = UDim2.fromScale(1, 1)
    inner.Position = UDim2.new(0.5, 0, 0.5, 0)
    inner.AnchorPoint = Vector2.new(0.5, 0.5)
    inner.BackgroundTransparency = 1
    inner.BorderSizePixel = 0
    inner.Parent = wrapper

    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(1, 0)
    innerCorner.Parent = inner

    local innerStroke = Instance.new("UIStroke")
    innerStroke.Name = "AvatarBorder"
    innerStroke.Thickness = CONFIG.AvatarBorderThickness
    local bc0 = CONFIG.AvatarBorderColor
    innerStroke.Color = Color3.new(bc0.r, bc0.g, bc0.b)
    innerStroke.Parent = inner

    local img = Instance.new("ImageLabel")
    img.Name = "AvatarImg"
    img.Size = UDim2.fromScale(1, 1)
    img.BackgroundTransparency = 1
    img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(lplr.UserId) .. "&w=420&h=420"
    img.Parent = inner

    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(1, 0)
    imgCorner.Parent = img

    return gui, wrapper, inner, img
end

task.spawn(function()
    task.wait(1)
    avatarGui, avatarFrame, avatarInner, avatarImg = createAvatarGui()
end)

local function applyAvatarBorder()
    if avatarInner and avatarInner.Parent then
        local bc = CONFIG.AvatarBorderColor
        local stroke = avatarInner:FindFirstChild("AvatarBorder")
        if stroke then
            stroke.Color = Color3.new(bc.r, bc.g, bc.b)
            stroke.Thickness = CONFIG.AvatarBorderThickness
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not avatarGui or not avatarGui.Parent then return end
    if not currentRayfieldGui or not currentRayfieldGui.Parent then return end

    local main = currentRayfieldGui:FindFirstChild("Main")
    if not main then
        if avatarFrame then avatarFrame.Visible = false end
        return
    end

    if not main.Visible then
        if avatarFrame then avatarFrame.Visible = false end
        return
    end

    local pos  = main.AbsolutePosition
    local size = main.AbsoluteSize

    if size.X < 50 or size.Y < 50 then
        if avatarFrame then avatarFrame.Visible = false end
        return
    end

    if CONFIG.AvatarSide == "Right" then
        avatarFrame.Position = UDim2.fromOffset(pos.X + size.X + 10, pos.Y + 70)
    else
        avatarFrame.Position = UDim2.fromOffset(pos.X - 120, pos.Y + 70)
    end
    avatarFrame.Visible = true
end)

Tab_Player:CreateSection("🎨 Viền Avatar")
Tab_Player:CreateLabel("(Avatar hiển thị bên cạnh menu)")
Tab_Player:CreateDropdown({
    Name = "Vị trí avatar",
    Options = {"Left", "Right"},
    CurrentOption = {CONFIG.AvatarSide or "Left"},
    Flag = "AvatarSideDropdown",
    Callback = function(opt)
        CONFIG.AvatarSide = opt[1]
        scheduleSave()
    end,
})
Tab_Player:CreateButton({ Name = "🔵 Màu Xanh Dương", Callback = function() CONFIG.AvatarBorderColor = { r = 0.2, g = 0.5, b = 1 }; applyAvatarBorder(); scheduleSave() end })
Tab_Player:CreateButton({ Name = "🟣 Màu Tím", Callback = function() CONFIG.AvatarBorderColor = { r = 140/255, g = 100/255, b = 255/255 }; applyAvatarBorder(); scheduleSave() end })
Tab_Player:CreateButton({ Name = "🟢 Màu Xanh Lá", Callback = function() CONFIG.AvatarBorderColor = { r = 0.2, g = 1, b = 0.3 }; applyAvatarBorder(); scheduleSave() end })
Tab_Player:CreateButton({ Name = "🔴 Màu Đỏ", Callback = function() CONFIG.AvatarBorderColor = { r = 1, g = 0.2, b = 0.2 }; applyAvatarBorder(); scheduleSave() end })
Tab_Player:CreateButton({ Name = "🟡 Màu Vàng", Callback = function() CONFIG.AvatarBorderColor = { r = 1, g = 0.9, b = 0.1 }; applyAvatarBorder(); scheduleSave() end })
Tab_Player:CreateSlider({
    Name = "Độ dày viền", Range = {0, 10}, Increment = 1, Suffix = "px",
    CurrentValue = CONFIG.AvatarBorderThickness, Flag = "AvatarBorderThickness",
    Callback = function(v) CONFIG.AvatarBorderThickness = v; applyAvatarBorder(); scheduleSave() end,
})

Tab_Player:CreateSection("🎮 Nhân vật")
local charLabel   = Tab_Player:CreateLabel("• Nhân vật: Đang tải...")
local hpLabel     = Tab_Player:CreateLabel("• Máu: Đang tải...")
local posLabel    = Tab_Player:CreateLabel("• Vị trí: Đang tải...")
local speedLabel  = Tab_Player:CreateLabel("• Tốc độ: Đang tải...")
local jumpLabel   = Tab_Player:CreateLabel("• Lực nhảy: Đang tải...")
local stateLabel  = Tab_Player:CreateLabel("• Trạng thái: Đang tải...")
local stateLabel2 = Tab_Player:CreateLabel("• Đang nhảy: Đang tải...")
local weaponLabel = Tab_Player:CreateLabel("• Vũ khí: Đang tải...")

Tab_Player:CreateSection("🎯 Game")
local gameNameLabel = Tab_Player:CreateLabel("• Tên game: Đang tải...")
task.spawn(function()
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name then
        pcall(function() gameNameLabel:Set("• Tên game: " .. info.Name) end)
    else
        pcall(function() gameNameLabel:Set("• Tên game: Unknown") end)
    end
end)
Tab_Player:CreateLabel("• Place ID: " .. tostring(game.PlaceId))
Tab_Player:CreateLabel("• Job ID: " .. tostring(game.JobId):sub(1, 8) .. "...")
local playerCountLabel = Tab_Player:CreateLabel("• Số người chơi: " .. tostring(#Players:GetPlayers()))

Tab_Player:CreateSection("📊 Thống kê")
local statFPSLabel  = Tab_Player:CreateLabel("• FPS: Đang đo...")
local statPingLabel = Tab_Player:CreateLabel("• Ping: Đang đo...")
local statMemLabel  = Tab_Player:CreateLabel("• Bộ nhớ: Đang đo...")
local statTimeLabel = Tab_Player:CreateLabel("• Thời gian chơi: 00:00:00")

Tab_Player:CreateSection("🔑 Key")
local keyStatusLabel  = Tab_Player:CreateLabel("• Trạng thái: Đang tải...")
local keyTypePlayer   = Tab_Player:CreateLabel("• Loại: --")
local keyRemainPlayer = Tab_Player:CreateLabel("• Còn lại: --")

local fpsAcc, fpsCount = 0, 0
local lastFPS = 60
RunService.Heartbeat:Connect(function(dt)
    fpsAcc = fpsAcc + dt
    fpsCount = fpsCount + 1
end)

task.spawn(function()
    task.wait(3)
    local startTime = tick()
    while task.wait(0.5) do
        if fpsAcc > 0 then
            lastFPS = math.floor(fpsCount / fpsAcc)
            fpsAcc, fpsCount = 0, 0
        end
        pcall(function() statFPSLabel:Set("• FPS: " .. tostring(lastFPS)) end)
        pcall(function()
            if lplr.GetNetworkPing then
                local ping = math.floor(lplr:GetNetworkPing() * 1000)
                statPingLabel:Set("• Ping: " .. tostring(ping) .. " ms")
            end
        end)
        pcall(function()
            if gcinfo then
                statMemLabel:Set("• Bộ nhớ: " .. tostring(math.floor(gcinfo() / 1024)) .. " MB")
            end
        end)
        pcall(function()
            local elapsed = tick() - startTime
            local h = math.floor(elapsed / 3600)
            local m = math.floor((elapsed % 3600) / 60)
            local s = math.floor(elapsed % 60)
            statTimeLabel:Set(string.format("• Thời gian chơi: %02d:%02d:%02d", h, m, s))
        end)
        pcall(function() playerCountLabel:Set("• Số người chơi: " .. tostring(#Players:GetPlayers())) end)

        local char = lplr.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                pcall(function() charLabel:Set("• Nhân vật: " .. char.Name) end)
                pcall(function() hpLabel:Set(string.format("• Máu: %.0f / %.0f", hum.Health, hum.MaxHealth)) end)
                pcall(function() posLabel:Set(string.format("• Vị trí: X=%.0f Y=%.0f Z=%.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)) end)
                pcall(function() speedLabel:Set(string.format("• Tốc độ: %.1f", hum.WalkSpeed)) end)
                pcall(function() jumpLabel:Set(string.format("• Lực nhảy: %.1f", hum.JumpPower)) end)
                pcall(function() stateLabel:Set("• Trạng thái: " .. tostring(hum:GetState())) end)
                pcall(function() stateLabel2:Set("• Đang nhảy: " .. (hum:GetState() == Enum.HumanoidStateType.Jumping and "Có" or "Không")) end)
            end
            pcall(function()
                local tool = char:FindFirstChildWhichIsA("Tool")
                weaponLabel:Set("• Vũ khí: " .. (tool and tool.Name or "Không cầm gì"))
            end)
        else
            pcall(function() charLabel:Set("• Nhân vật: ❌ Chưa spawn") end)
        end

        local _, saved = checkLocalKey()
        if saved then
            local r = saved.expires_at - getNow()
            pcall(function()
                keyStatusLabel:Set("• Trạng thái: ✅ Hoạt động")
                keyTypePlayer:Set("• Loại: " .. tostring(saved.type))
                keyRemainPlayer:Set("• Còn lại: " .. formatTime(r))
            end)
        else
            pcall(function()
                keyStatusLabel:Set("• Trạng thái: ❌ Hết hạn")
                keyTypePlayer:Set("• Loại: --")
                keyRemainPlayer:Set("• Còn lại: --")
            end)
        end
    end
end)

-- ============================================================
-- TAB SILENT AIM
-- ============================================================
task.wait(0.15)
local Tab_Aim = Window:CreateTab("Silent Aim", "crosshair")
Tab_Aim:CreateSection("Bật/Tắt")
Tab_Aim:CreateToggle({ Name = "Bật Silent Aim", CurrentValue = CONFIG.SilentAimEnabled, Flag = "SilentAimToggle", Callback = function(v) CONFIG.SilentAimEnabled = v; scheduleSave() end })
Tab_Aim:CreateSection("Cấu hình")
Tab_Aim:CreateSlider({ Name = "FOV", Range = {10, 360}, Increment = 5, Suffix = "°", CurrentValue = CONFIG.FOV, Flag = "SilentAimFOV", Callback = function(v) CONFIG.FOV = v; scheduleSave() end })
Tab_Aim:CreateSlider({ Name = "Max Distance", Range = {100, 10000}, Increment = 100, Suffix = " studs", CurrentValue = CONFIG.MaxDistance, Flag = "SilentAimMaxDist", Callback = function(v) CONFIG.MaxDistance = v; scheduleSave() end })
Tab_Aim:CreateSlider({ Name = "Cache Time", Range = {0.05, 1}, Increment = 0.05, Suffix = "s", CurrentValue = CONFIG.CacheTime, Flag = "SilentAimCache", Callback = function(v) CONFIG.CacheTime = v; scheduleSave() end })
Tab_Aim:CreateToggle({ Name = "Check Wall", CurrentValue = CONFIG.CheckWall, Flag = "SilentAimWall", Callback = function(v) CONFIG.CheckWall = v; scheduleSave() end })
Tab_Aim:CreateToggle({ Name = "Ignore Team", CurrentValue = CONFIG.IgnoreTeam, Flag = "SilentAimTeam", Callback = function(v) CONFIG.IgnoreTeam = v; scheduleSave() end })

-- ============================================================
-- TAB MOUSE AIM
-- ============================================================
task.wait(0.15)
local Tab_Mouse = Window:CreateTab("Mouse Aim", "mouse-pointer")
Tab_Mouse:CreateSection("🎯 Mouse Aim")
Tab_Mouse:CreateToggle({ Name = "Bật Mouse Aim", CurrentValue = CONFIG.MouseAimEnabled, Flag = "MouseAimToggle", Callback = function(v) CONFIG.MouseAimEnabled = v; scheduleSave() end })
Tab_Mouse:CreateToggle({ Name = "Chỉ aim khi giữ chuột phải", CurrentValue = CONFIG.MouseAimHoldRMB, Flag = "MouseAimHoldRMB", Callback = function(v) CONFIG.MouseAimHoldRMB = v; scheduleSave() end })
Tab_Mouse:CreateToggle({ Name = "Chỉ aim khi đang cầm vũ khí", CurrentValue = CONFIG.MouseAimRequireWeapon, Flag = "MouseAimReqWeapon", Callback = function(v) CONFIG.MouseAimRequireWeapon = v; scheduleSave() end })
Tab_Mouse:CreateSlider({ Name = "Độ nhạy (Speed)", Range = {0.05, 8}, Increment = 0.05, Suffix = "", CurrentValue = CONFIG.MouseAimSpeed, Flag = "MouseAimSpeed", Callback = function(v) CONFIG.MouseAimSpeed = v; scheduleSave() end })
Tab_Mouse:CreateDropdown({ Name = "Aim vào bộ phận", Options = {"Head", "Torso", "Random"}, CurrentOption = {CONFIG.MouseAimPart}, Flag = "MouseAimPart", Callback = function(opt) CONFIG.MouseAimPart = opt[1]; scheduleSave() end })
Tab_Mouse:CreateSlider({ Name = "FOV", Range = {10, 360}, Increment = 5, Suffix = "°", CurrentValue = CONFIG.MouseAimFOV, Flag = "MouseAimFOV", Callback = function(v) CONFIG.MouseAimFOV = v; scheduleSave() end })
Tab_Mouse:CreateSlider({ Name = "Max Distance", Range = {100, 2000}, Increment = 50, Suffix = " studs", CurrentValue = CONFIG.MouseAimMaxDistance, Flag = "MouseAimMaxDist", Callback = function(v) CONFIG.MouseAimMaxDistance = v; scheduleSave() end })
Tab_Mouse:CreateToggle({ Name = "Check Wall", CurrentValue = CONFIG.MouseAimCheckWall, Flag = "MouseAimWall", Callback = function(v) CONFIG.MouseAimCheckWall = v; scheduleSave() end })
Tab_Mouse:CreateToggle({ Name = "Ignore Team", CurrentValue = CONFIG.MouseAimIgnoreTeam, Flag = "MouseAimTeam", Callback = function(v) CONFIG.MouseAimIgnoreTeam = v; scheduleSave() end })

Tab_Mouse:CreateSection("⌨️ Keybind")
Tab_Mouse:CreateLabel("Phím toggle Mouse Aim: " .. tostring(CONFIG.MouseAimToggleKey.Name))
Tab_Mouse:CreateButton({
    Name = "🔧 Đổi phím toggle Mouse Aim",
    Callback = function()
        Rayfield:Notify({ Title = "Đổi phím", Content = "Nhấn một phím...", Duration = 3 })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                conn:Disconnect()
                CONFIG.MouseAimToggleKey = input.KeyCode
                scheduleSave()
                Rayfield:Notify({ Title = "✅ Đã đổi", Content = "Phím: " .. tostring(input.KeyCode.Name), Duration = 2 })
            end
        end)
    end,
})

-- ============================================================
-- TAB RAGE
-- ============================================================
task.wait(0.15)
local Tab_Rage = Window:CreateTab("Rage", "zap")
Tab_Rage:CreateSection("⚡ Chế độ")
Tab_Rage:CreateDropdown({
    Name = "Chế độ Rage", Options = {"RageV1 (Aimbot)", "RageV2 (Ragebot)"},
    CurrentOption = {CONFIG.Rage_Mode == "RageV2" and "RageV2 (Ragebot)" or "RageV1 (Aimbot)"},
    Flag = "RageModeDropdown",
    Callback = function(opt)
        local newMode = (opt[1] == "RageV2 (Ragebot)") and "RageV2" or "RageV1"
        local wasEnabled = CONFIG.Rage_Enabled
        local modeChanged = (CONFIG.Rage_Mode ~= newMode)
        CONFIG.Rage_Mode = newMode
        if wasEnabled and modeChanged and _G.ApplyRageState then _G.ApplyRageState() end
        scheduleSave()
        Rayfield:Notify({ Title = "Rage", Content = "Đã đổi mode: " .. CONFIG.Rage_Mode, Duration = 2 })
    end,
})
Tab_Rage:CreateSection("🎯 Bật/Tắt")
Tab_Rage:CreateToggle({
    Name = "Bật Rage", CurrentValue = false, Flag = "RageEnabled",
    Callback = function(v)
        CONFIG.Rage_Enabled = v
        if v then
            Rayfield:Notify({ Title = "Rage", Content = "⏳ Đang khởi động " .. CONFIG.Rage_Mode .. "...", Duration = 2 })
            task.spawn(function()
                task.wait(0.3)
                if CONFIG.Rage_Enabled and _G.ApplyRageState then
                    _G.ApplyRageState()
                    Rayfield:Notify({ Title = "Rage", Content = "✅ Đã bật — " .. CONFIG.Rage_Mode, Duration = 2 })
                end
            end)
        else
            if _G.ApplyRageState then _G.ApplyRageState() end
            Rayfield:Notify({ Title = "Rage", Content = "Tắt ❌", Duration = 2 })
        end
        scheduleSave()
    end,
})
Tab_Rage:CreateToggle({ Name = "Yêu cầu đang cầm vũ khí", CurrentValue = CONFIG.Rage_RequireWeapon, Flag = "RageReqWeapon", Callback = function(v) CONFIG.Rage_RequireWeapon = v; scheduleSave() end })
Tab_Rage:CreateSection("🎯 Cài đặt RageV1 (Aimbot)")
Tab_Rage:CreateSlider({ Name = "RageV1 — Max Distance", Range = {50, 2000}, Increment = 50, Suffix = " studs", CurrentValue = CONFIG.Rage_V1_MaxDistance, Flag = "RageV1MaxDist", Callback = function(v) CONFIG.Rage_V1_MaxDistance = v; scheduleSave() end })
Tab_Rage:CreateSection("🔥 Cài đặt RageV2 (Ragebot)")
Tab_Rage:CreateSlider({ Name = "RageV2 — Fire Rate", Range = {0.0001, 0.05}, Increment = 0.0001, Suffix = "s", CurrentValue = CONFIG.Rage_FireRate, Flag = "RageFireRate", Callback = function(v) CONFIG.Rage_FireRate = v; if getgenv().RageConfig then getgenv().RageConfig.FireRate = v end; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Auto Switch Weapon", CurrentValue = CONFIG.Rage_AutoSwitch, Flag = "RageAutoSwitch", Callback = function(v) CONFIG.Rage_AutoSwitch = v; if getgenv().RageConfig then getgenv().RageConfig.AutoSwitch = v end; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Desync", CurrentValue = CONFIG.Rage_Desync, Flag = "RageDesync", Callback = function(v) CONFIG.Rage_Desync = v; if getgenv().RageConfig then getgenv().RageConfig.DesyncEnabled = v end; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Melee Keep", CurrentValue = CONFIG.Rage_MeleeKeep, Flag = "RageMeleeKeep", Callback = function(v) CONFIG.Rage_MeleeKeep = v; if getgenv().RageConfig then getgenv().RageConfig.MeleeKeep = v end; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Auto Pickup", CurrentValue = CONFIG.Rage_AutoPickup, Flag = "RageAutoPickup", Callback = function(v) CONFIG.Rage_AutoPickup = v; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Show Enemy Weapon", CurrentValue = CONFIG.Rage_ShowEnemyWeapon, Flag = "RageShowEnemyWeapon", Callback = function(v) CONFIG.Rage_ShowEnemyWeapon = v; if getgenv().RageConfig then getgenv().RageConfig.ShowEnemyWeapon = v end; scheduleSave() end })
Tab_Rage:CreateToggle({ Name = "RageV2 — Use Real Ammo", CurrentValue = CONFIG.Rage_UseRealAmmo, Flag = "RageUseRealAmmo", Callback = function(v) CONFIG.Rage_UseRealAmmo = v; if getgenv().RageConfig then getgenv().RageConfig.UseRealAmmo = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Switch Threshold", Range = {0, 10}, Increment = 1, Suffix = " ammo", CurrentValue = CONFIG.Rage_SwitchThreshold, Flag = "RageSwitchThreshold", Callback = function(v) CONFIG.Rage_SwitchThreshold = v; if getgenv().RageConfig then getgenv().RageConfig.SwitchThreshold = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Velocity Multiplier", Range = {-5000, 0}, Increment = 50, Suffix = "", CurrentValue = CONFIG.Rage_VelocityMultiplier, Flag = "RageVelocityMult", Callback = function(v) CONFIG.Rage_VelocityMultiplier = v; if getgenv().RageConfig then getgenv().RageConfig.VelocityMultiplier = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Desync Jitter", Range = {0, 20}, Increment = 0.5, Suffix = "", CurrentValue = CONFIG.Rage_DesyncJitter, Flag = "RageDesyncJitter", Callback = function(v) CONFIG.Rage_DesyncJitter = v; if getgenv().RageConfig then getgenv().RageConfig.DesyncJitter = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Desync Yaw", Range = {-180, 180}, Increment = 5, Suffix = "°", CurrentValue = CONFIG.Rage_DesyncYaw, Flag = "RageDesyncYaw", Callback = function(v) CONFIG.Rage_DesyncYaw = v; if getgenv().RageConfig then getgenv().RageConfig.DesyncAngles.Yaw = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Desync Pitch", Range = {-180, 180}, Increment = 5, Suffix = "°", CurrentValue = CONFIG.Rage_DesyncPitch, Flag = "RageDesyncPitch", Callback = function(v) CONFIG.Rage_DesyncPitch = v; if getgenv().RageConfig then getgenv().RageConfig.DesyncAngles.Pitch = v end; scheduleSave() end })
Tab_Rage:CreateSlider({ Name = "RageV2 — Desync Roll", Range = {-180, 180}, Increment = 5, Suffix = "°", CurrentValue = CONFIG.Rage_DesyncRoll, Flag = "RageDesyncRoll", Callback = function(v) CONFIG.Rage_DesyncRoll = v; if getgenv().RageConfig then getgenv().RageConfig.DesyncAngles.Roll = v end; scheduleSave() end })
Tab_Rage:CreateSection("📖 Hướng dẫn")
Tab_Rage:CreateLabel("• Chọn mode ở dropdown trên")
Tab_Rage:CreateLabel("• Bật 1 toggle duy nhất — tự chạy mode đã chọn")
Tab_Rage:CreateLabel("• Cả 2 mode đều cần ĐANG CẦM VŨ KHÍ")
Tab_Rage:CreateLabel("• ✅ Rage luôn OFF khi load script")

-- ============================================================
-- TAB ESP
-- ============================================================
task.wait(0.15)
local Tab_ESP = Window:CreateTab("ESP", "eye")
Tab_ESP:CreateSection("🎯 Bật/Tắt")
Tab_ESP:CreateToggle({ Name = "Bật ESP", CurrentValue = CONFIG.ESP_Enabled, Flag = "ESPToggle", Callback = function(v) CONFIG.ESP_Enabled = v; scheduleSave() end })
Tab_ESP:CreateToggle({ Name = "Chỉ hiện khi cầm vũ khí", CurrentValue = CONFIG.ESP_OnlyWhenWeapon, Flag = "ESPOnlyWhenWeapon", Callback = function(v) CONFIG.ESP_OnlyWhenWeapon = v; scheduleSave() end })
Tab_ESP:CreateSlider({ Name = "Khoảng cách", Range = {50, 3000}, Increment = 50, Suffix = " studs", CurrentValue = CONFIG.ESP_Distance, Flag = "ESPDistance", Callback = function(v) CONFIG.ESP_Distance = v; scheduleSave() end })
Tab_ESP:CreateSection("👁️ Hiển thị")
Tab_ESP:CreateToggle({ Name = "Hiện Box", CurrentValue = CONFIG.ESP_ShowBox, Flag = "ESPShowBox", Callback = function(v) CONFIG.ESP_ShowBox = v; scheduleSave() end })
Tab_ESP:CreateToggle({ Name = "Hiện Tên", CurrentValue = CONFIG.ESP_ShowName, Flag = "ESPShowName", Callback = function(v) CONFIG.ESP_ShowName = v; scheduleSave() end })
Tab_ESP:CreateToggle({ Name = "Hiện Thanh Máu", CurrentValue = CONFIG.ESP_ShowHealth, Flag = "ESPShowHealth", Callback = function(v) CONFIG.ESP_ShowHealth = v; scheduleSave() end })
Tab_ESP:CreateToggle({ Name = "Hiện Highlight", CurrentValue = CONFIG.ESP_ShowHighlight, Flag = "ESPShowHighlight", Callback = function(v) CONFIG.ESP_ShowHighlight = v; scheduleSave() end })
Tab_ESP:CreateSection("🎨 Màu theo % máu")
Tab_ESP:CreateColorPicker({ Name = "Máu đầy (100%)", Color = CONFIG.ESP_HealthFullColor, Flag = "ESPColorFull", Callback = function(c) CONFIG.ESP_HealthFullColor = c; scheduleSave() end })
Tab_ESP:CreateColorPicker({ Name = "Máu trung bình (50%)", Color = CONFIG.ESP_HealthMidColor, Flag = "ESPColorMid", Callback = function(c) CONFIG.ESP_HealthMidColor = c; scheduleSave() end })
Tab_ESP:CreateColorPicker({ Name = "Máu thấp (0%)", Color = CONFIG.ESP_HealthLowColor, Flag = "ESPColorLow", Callback = function(c) CONFIG.ESP_HealthLowColor = c; scheduleSave() end })
Tab_ESP:CreateSlider({ Name = "Ngưỡng Vàng → Đỏ", Range = {0.1, 0.9}, Increment = 0.05, Suffix = "", CurrentValue = CONFIG.ESP_HealthMidPoint, Flag = "ESPMidPoint", Callback = function(v) CONFIG.ESP_HealthMidPoint = v; scheduleSave() end })

-- ============================================================
-- TAB UNLOCK ALL
-- ============================================================
task.wait(0.15)
local Tab_UnlockAll = Window:CreateTab("Unlock All", "unlock")
Tab_UnlockAll:CreateSection("Trạng thái")

Tab_UnlockAll:CreateToggle({
    Name = "Bật Equip (phím 9 toggle nhanh)",
    CurrentValue = CONFIG.UnlockAllActive,
    Flag = "UnlockAllToggle",
    Callback = function(v)
        CONFIG.UnlockAllActive = v
        scheduleSave()
        -- Auto cài hook khi bật toggle
        if v then
            task.spawn(function()
                for i = 1, 20 do
                    if equipHookInstalled then break end
                    if installEquipHook then
                        local ok = installEquipHook()
                        if ok then
                            equipHookOK = true
                            print("[UnlockAll] Hook installed via toggle (attempt " .. i .. ")")
                            pcall(function() unlockInfoLabel:Set("Số vũ khí: " .. weaponCount .. " | Equip hook: ✅ OK") end)
                            break
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

Tab_UnlockAll:CreateSection("🔧 Cài Hook Thủ Công")
Tab_UnlockAll:CreateLabel("Nhấn nút dưới để cài hook EquipCosmetic")
Tab_UnlockAll:CreateLabel("Nếu toggle đã ON mà vẫn không equip được → bấm nút này")

local unlockInfoLabel = Tab_UnlockAll:CreateLabel("⏳ Đang tải thông tin...")

Tab_UnlockAll:CreateButton({
    Name = "🔧 CÀI HOOK NGAY",
    Callback = function()
        if not installEquipHook then
            Rayfield:Notify({
                Title = "❌ Lỗi",
                Content = "installEquipHook chưa sẵn sàng — đợi 5-10s",
                Duration = 3,
            })
            return
        end
        local ok = installEquipHook()
        equipHookOK = ok
        if ok then
            Rayfield:Notify({
                Title = "✅ Thành công",
                Content = "Đã cài hook EquipCosmetic",
                Duration = 3,
            })
            pcall(function()
                unlockInfoLabel:Set("Số vũ khí: " .. weaponCount .. " | Equip hook: ✅ OK")
            end)
            print("[UnlockAll] Manual hook install: OK")
        else
            Rayfield:Notify({
                Title = "❌ Thất bại",
                Content = "Không cài được hook — executor có thể không hỗ trợ",
                Duration = 3,
            })
            print("[UnlockAll] Manual hook install: FAIL")
        end
    end,
})

Tab_UnlockAll:CreateButton({
    Name = "🔄 Kiểm Tra Trạng Thái Hook",
    Callback = function()
        if equipHookInstalled then
            Rayfield:Notify({
                Title = "📊 Trạng thái Hook",
                Content = "✅ Đã cài hook (equipHookInstalled = true)",
                Duration = 3,
            })
        else
            Rayfield:Notify({
                Title = "📊 Trạng thái Hook",
                Content = "❌ Chưa cài hook — bấm 'CÀI HOOK NGAY'",
                Duration = 3,
            })
        end
    end,
})
-- ============================================================
-- TAB EXCHANGE
-- ============================================================
task.wait(0.15)
local Tab_Exchange = Window:CreateTab("Exchange", "coins")
Tab_Exchange:CreateSection("💰 Currency")
local exchangeInputs = {}
local currencyFields = {
    { key = "unlock_tokens",  name = "Unlock Tokens" },
    { key = "weapon_keys",    name = "Weapon Keys" },
    { key = "glory",          name = "Glory" },
    { key = "skin_tickets",   name = "Skin Tickets" },
    { key = "event_currency", name = "Event Currency" },
    { key = "gift_tickets",   name = "Gift Tickets" },
}
for _, field in ipairs(currencyFields) do
    exchangeInputs[field.key] = Tab_Exchange:CreateInput({
        Name = field.name, CurrentValue = tostring(CONFIG.Exchange[field.key]),
        PlaceholderText = "auto", RemoveTextAfterFocusLost = false, Flag = "Exchange_" .. field.key,
        Callback = function(v)
            local s = v:lower():gsub("%s", "")
            if s == "" or s == "auto" then CONFIG.Exchange[field.key] = "auto"
            else local n = tonumber(v); if n then CONFIG.Exchange[field.key] = n end end
            scheduleSave()
            if _G.applyExchangeDirect then _G.applyExchangeDirect() end
        end,
    })
end
Tab_Exchange:CreateSection("📊 Level / XP")
local levelFields = {
    { key = "player_level", name = "Player Level" },
    { key = "player_xp",    name = "Player XP" },
    { key = "weapon_level", name = "Weapon Level" },
    { key = "weapon_xp",    name = "Weapon XP" },
    { key = "prestige",     name = "Prestige" },
}
for _, field in ipairs(levelFields) do
    exchangeInputs[field.key] = Tab_Exchange:CreateInput({
        Name = field.name, CurrentValue = tostring(CONFIG.Exchange[field.key]),
        PlaceholderText = "auto", RemoveTextAfterFocusLost = false, Flag = "Exchange_" .. field.key,
        Callback = function(v)
            local s = v:lower():gsub("%s", "")
            if s == "" or s == "auto" then CONFIG.Exchange[field.key] = "auto"
            else local n = tonumber(v); if n then CONFIG.Exchange[field.key] = n end end
            scheduleSave()
            if _G.applyExchangeDirect then _G.applyExchangeDirect() end
        end,
    })
end
Tab_Exchange:CreateSection("⚡ Công cụ")
Tab_Exchange:CreateButton({
    Name = "📖 Đọc giá trị gốc từ game",
    Callback = function()
        if _G.kpchook_snapshot then _G.kpchook_snapshot() end
        local map = {
            unlock_tokens = GameOriginal.unlock_tokens, weapon_keys = GameOriginal.weapon_keys,
            glory = GameOriginal.glory, skin_tickets = GameOriginal.skin_tickets,
            event_currency = GameOriginal.event_currency, gift_tickets = GameOriginal.gift_tickets,
            player_level = GameOriginal.player_level, player_xp = GameOriginal.player_xp,
            weapon_level = GameOriginal.weapon_level, weapon_xp = GameOriginal.weapon_xp,
            prestige = GameOriginal.prestige,
        }
        for k, val in pairs(map) do
            if val and exchangeInputs[k] then exchangeInputs[k]:Set(tostring(val)); CONFIG.Exchange[k] = val end
        end
        scheduleSave()
        Rayfield:Notify({ Title = "Exchange", Content = "Đã đọc ✅", Duration = 2 })
    end,
})
Tab_Exchange:CreateButton({
    Name = "🔄 Đặt tất cả về auto",
    Callback = function()
        for k in pairs(CONFIG.Exchange) do
            CONFIG.Exchange[k] = "auto"
            if exchangeInputs[k] then exchangeInputs[k]:Set("auto") end
        end
        scheduleSave()
    end,
})
Tab_Exchange:CreateButton({
    Name = "💰 Áp dụng ngay",
    Callback = function()
        if _G.applyExchangeDirect then _G.applyExchangeDirect() end
        Rayfield:Notify({ Title = "Exchange", Content = "Đã áp dụng ✅", Duration = 2 })
    end,
})

-- ============================================================
-- TAB STATISTICS
-- ============================================================
task.wait(0.15)
local Tab_Stats = Window:CreateTab("Statistics", "bar-chart")
Tab_Stats:CreateSection("📊 Trạng thái")
local statsStatusLabel = Tab_Stats:CreateLabel("⏳ Đang quét getgc()...")

-- ============================================================
-- TAB INFO
-- ============================================================
task.wait(0.15)
local Tab_Info = Window:CreateTab("Info", "info")
Tab_Info:CreateSection("📌 Executor")
Tab_Info:CreateLabel("Tên: " .. ExecutorInfo.Name)
Tab_Info:CreateLabel("Phiên bản: " .. tostring(ExecutorInfo.Version))
Tab_Info:CreateLabel("Hook metamethod: " .. (hasHookMeta and "✅ Có" or "❌ Không"))
Tab_Info:CreateLabel("getgc: " .. (type(getgc) == "function" and "✅ Có" or "❌ Không"))
Tab_Info:CreateLabel("mousemoverel: " .. (mouseAimHasMoveRel and "✅ Có" or "❌ Không"))
local fcLabel = Tab_Info:CreateLabel("FighterController: ⏳ Đang tải")
Tab_Info:CreateSection("🔑 Key")
local keyKeyLabel    = Tab_Info:CreateLabel("Key: --")
local keyTypeLabel   = Tab_Info:CreateLabel("Loại: --")
local keyRemainLabel = Tab_Info:CreateLabel("Còn lại: --")
Tab_Info:CreateSection("📜 Lịch sử Key")
local keyOldCountLabel = Tab_Info:CreateLabel("Số key đã dùng: ⏳")

task.spawn(function()
    task.wait(2)
    while task.wait(1) do
        local _, saved = checkLocalKey()
        if saved then
            local r = saved.expires_at - getNow()
            pcall(function()
                keyKeyLabel:Set("Key: " .. tostring(saved.key))
                keyTypeLabel:Set("Loại: " .. tostring(saved.type))
                keyRemainLabel:Set("Còn lại: " .. formatTime(r))
            end)
        else
            pcall(function()
                keyKeyLabel:Set("Key: ❌ Hết hạn / chưa kích hoạt")
                keyTypeLabel:Set("Loại: --")
                keyRemainLabel:Set("Còn lại: --")
            end)
        end
        pcall(function()
            local old = readKeyOld()
            local n = 0
            for _ in pairs(old) do n = n + 1 end
            keyOldCountLabel:Set("Số key đã dùng: " .. n)
        end)
    end
end)

-- ============================================================
-- TAB SETTINGS
-- ============================================================
task.wait(0.15)
local Tab_Settings = Window:CreateTab("Settings", "settings")
Tab_Settings:CreateSection("Theme")
Tab_Settings:CreateDropdown({
    Name = "Chọn Theme (restart để áp dụng)",
    Options = {"DarkBlue", "Amethyst", "Green", "BloodRed", "Ocean", "Serenity", "Light"},
    CurrentOption = {CONFIG.Theme}, Flag = "ThemeDropdown",
    Callback = function(opt) CONFIG.Theme = opt[1]; scheduleSave() end,
})
Tab_Settings:CreateSection("Keybind")
Tab_Settings:CreateLabel("Phím mở Menu: " .. tostring(CONFIG.MenuKeybind.Name))
Tab_Settings:CreateLabel("Phím 9 = Toggle Equip")
Tab_Settings:CreateLabel("Phím MouseAim: " .. tostring(CONFIG.MouseAimToggleKey.Name))
Tab_Settings:CreateButton({
    Name = "🔧 Đổi phím mở Menu",
    Callback = function()
        Rayfield:Notify({ Title = "Đổi phím", Content = "Nhấn một phím...", Duration = 3 })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                conn:Disconnect()
                CONFIG.MenuKeybind = input.KeyCode
                scheduleSave()
            end
        end)
    end,
})
Tab_Settings:CreateSection("Config")
Tab_Settings:CreateButton({
    Name = "💾 Lưu Config Ngay",
    Callback = function()
        saveConfigNow()
        Rayfield:Notify({ Title = "Config", Content = "Đã lưu ✅", Duration = 2 })
    end,
})
Tab_Settings:CreateButton({
    Name = "🗑️ Xoá Config",
    Callback = function()
        if delfile then pcall(delfile, CONFIG_FILE) end
        Rayfield:Notify({ Title = "Config", Content = "Đã xoá", Duration = 3 })
    end,
})

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Nine then
        CONFIG.UnlockAllActive = not CONFIG.UnlockAllActive
        if CONFIG.UnlockAllActive and not equipHookInstalled and installEquipHook then
            equipHookOK = installEquipHook()
        end
        scheduleSave()
        pcall(function()
            if Rayfield.SetFlag then Rayfield:SetFlag("UnlockAllToggle", CONFIG.UnlockAllActive) end
        end)
    end
end)

lplr.AncestryChanged:Connect(function()
    if not lplr:IsDescendantOf(game) then saveConfigNow() end
end)

-- ============================================================
-- RAGE CORE — biến state
-- ============================================================
local RageState = {
    V1Instance = nil,
    V2Started  = false,
    V2Conns    = {},
    V2Tasks    = {},
}

-- ============================================================
-- BACKGROUND LOAD
-- ============================================================
task.spawn(function()
    task.wait(3)

    local function safeRequire(parent, name, timeout)
        local ok, mod = pcall(function() return require(parent:WaitForChild(name, timeout or 10)) end)
        return ok and mod or nil
    end

    local EnumLibrary     = safeRequire(ReplicatedStorage.Modules, "EnumLibrary")
    if EnumLibrary and EnumLibrary.WaitForEnumBuilder then pcall(function() EnumLibrary:WaitForEnumBuilder() end) end
    local CosmeticLibrary = safeRequire(ReplicatedStorage.Modules, "CosmeticLibrary")
    local ItemLibrary     = safeRequire(ReplicatedStorage.Modules, "ItemLibrary")
    local ShopLibrary     = safeRequire(ReplicatedStorage.Modules, "ShopLibrary")
    local DataController  = safeRequire(controllers, "PlayerDataController")
    local EmoteController = safeRequire(controllers, "EmoteController")

    pcall(function() FighterController = require(playerScripts.Controllers.FighterController) end)

    local psModules     = playerScripts:WaitForChild("Modules", 30)
    local itemTypes     = psModules:WaitForChild("ItemTypes", 15)
    local gunModule     = itemTypes:WaitForChild("Gun", 15)
    local rsModules     = ReplicatedStorage:WaitForChild("Modules", 30)
    local utilityModule = rsModules:WaitForChild("Utility", 15)

    do
        local ok
        ok, U = pcall(require, utilityModule)
        if not ok then U = nil end
        ok, Gun = pcall(require, gunModule)
        if not ok then Gun = nil end
    end

    pcall(function() fcLabel:Set("FighterController: " .. (FighterController and "✅ Loaded" or "❌ NULL")) end)

    isHoldingWeapon = function()
        if not FighterController or not FighterController.LocalFighter then return false end
        local eq = FighterController.LocalFighter.EquippedItem
        if not eq then return false end
        return (eq.Name or "") ~= ""
    end

    task.wait()

    local ORIG = {
        CosmeticLibrary_OwnsCosmetic = CosmeticLibrary and CosmeticLibrary.OwnsCosmetic or nil,
        DataController_Get = DataController and DataController.Get or nil,
        DataController_GetWeaponData = DataController and DataController.GetWeaponData or nil,
    }

    local function snapshotGameOriginal()
        if not DataController or not ORIG.DataController_Get then return end
        local get = ORIG.DataController_Get
        pcall(function()
            GameOriginal.player_level   = get(DataController, "Level")
            GameOriginal.player_xp      = get(DataController, "XP")
            GameOriginal.unlock_tokens  = get(DataController, "UnlockTokens")
            GameOriginal.weapon_keys    = get(DataController, "WeaponKeys")
            GameOriginal.glory          = get(DataController, "Glory")
            GameOriginal.skin_tickets   = get(DataController, "SkinTickets")
            GameOriginal.event_currency = get(DataController, "EventCurrency")
            GameOriginal.gift_tickets   = get(DataController, "GiftTickets")
        end)
        pcall(function()
            local d = DataController and DataController.CurrentData
            if d and d.Data and d.Data.WeaponInventory then
                for _, wData in pairs(d.Data.WeaponInventory) do
                    if type(wData) == "table" and wData.Name then
                        GameOriginal.weapon_level = wData.Level
                        GameOriginal.weapon_xp    = wData.XP
                        GameOriginal.prestige     = wData.Prestige
                        break
                    end
                end
            end
        end)
    end
    _G.kpchook_snapshot = snapshotGameOriginal

    task.wait()

    local weaponSet = {}
    if ItemLibrary and ItemLibrary.Items then
        for name, wData in pairs(ItemLibrary.Items) do
            if type(wData) == "table" and name ~= "MISSING_WEAPON" then
                local itemType = wData.Type or ""
                local class = wData.Class or ""
                if itemType == "Gun" or itemType == "Melee" or itemType == "Custom" or itemType == "Utility" or itemType == "Throwable"
                    or class == "Primary" or class == "Secondary" or class == "Melee" or class == "Utility" or class == "Throwable" then
                    weaponSet[name] = true
                end
            end
        end
    end

    local cosmeticMetaCache = {}
    local function getCosmeticMeta(name)
        if not name then return nil end
        local c = cosmeticMetaCache[name]
        if c then return c end
        local base = CosmeticLibrary and CosmeticLibrary.Cosmetics[name]
        if not base then return nil end
        local meta = { type = base.Type, data = base }
        cosmeticMetaCache[name] = meta
        return meta
    end
    local function isAllowed(name) return getCosmeticMeta(name) ~= nil end

    local function cloneCosmetic(name, cosmeticType, options)
        local base = CosmeticLibrary and CosmeticLibrary.Cosmetics[name]
        if not base then return nil end
        local data = {}
        for k, v in pairs(base) do data[k] = v end
        data.Name = name
        data.Type = data.Type or cosmeticType
        data.Seed = data.Seed or math.random(1, 1000000)
        if EnumLibrary then
            local ok, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
            if ok and enumId then
                data.Enum     = enumId
                data.ObjectID = data.ObjectID or enumId
            end
        end
        if options then
            if options.inverted      ~= nil then data.Inverted         = options.inverted end
            if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
        end
        return data
    end

    do
        local savedEquipped = ConfigData.equipped or {}
        for weapon, cosmetics in pairs(savedEquipped) do
            equipped[weapon] = {}
            for cType, cData in pairs(cosmetics) do
                if cData and cData.name and isAllowed(cData.name) then
                    local cloned = cloneCosmetic(cData.name, cType, { inverted = cData.inverted })
                    if cloned then
                        cloned.Seed = cData.seed
                        equipped[weapon][cType] = cloned
                    end
                end
            end
            if not next(equipped[weapon]) then equipped[weapon] = nil end
        end

        local savedFavs = ConfigData.favorites or {}
        for cat, favs in pairs(savedFavs) do
            favorites[cat] = {}
            for name, state in pairs(favs) do
                if isAllowed(name) then favorites[cat][name] = state end
            end
        end
    end

    isLoadingConfig = false
    isConfigLoaded = true

    task.wait()

    -- ============================================================
    -- INSTALL EQUIP HOOK (FIXED — không dùng rawset trên function)
    -- ============================================================
    installEquipHook = function()
        if equipHookInstalled then return true end
        if not CosmeticLibrary then return false end

        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local dataRemotes = remotes and remotes:FindFirstChild("Data")
        if not dataRemotes then return false end

        local equipRemote          = dataRemotes:FindFirstChild("EquipCosmetic")
        local favoriteRemote       = dataRemotes:FindFirstChild("FavoriteCosmetic")
        local unlockWeaponRemote   = dataRemotes:FindFirstChild("UnlockWeapon")
        local favoriteWeaponRemote = dataRemotes:FindFirstChild("FavoriteWeapon")
        if not equipRemote then return false end

        -- ✅ Dùng getrawmetatable + setreadonly (đã hoạt động)
        if type(getrawmetatable) == "function" and type(setreadonly) == "function" then
            local function hookRemote(remote, handler)
                if not remote then return end
                local mt = getrawmetatable(remote)
                if not mt then return end
                local old = mt.__namecall
                local newFn
                newFn = function(self, ...)
                    if getnamecallmethod() == "FireServer" then
                        pcall(handler, ...)
                    end
                    if old then
                        local ok, ret = pcall(old, self, ...)
                        if ok then return ret end
                        return nil
                    end
                end
                pcall(function() setreadonly(mt, false) end)
                mt.__namecall = newFn
                pcall(function() setreadonly(mt, true) end)
            end

            hookRemote(equipRemote, function(...)
                if not CONFIG.UnlockAllActive then return end
                local args = {...}
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {
                        inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites,
                    })
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                    print("[Equip] " .. weaponName .. " | " .. cosmeticType .. " = " .. cosmeticName)
                end
                scheduleSave()
                -- ✅ Trigger re-render viewmodel
                equippedChangedSignal:Fire()
            end)

            hookRemote(favoriteRemote, function(...)
                if not CONFIG.UnlockAllActive then return end
                local args = {...}
                local category, name, state = args[1], args[2], args[3]
                if isAllowed(name) then
                    favorites[category] = favorites[category] or {}
                    favorites[category][name] = state or nil
                    scheduleSave()
                end
            end)

            equipHookInstalled = true
            return true
        end

        if hasHookMeta then
            local originalNamecall
            originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method ~= "FireServer" then return originalNamecall(self, ...) end
                if not CONFIG.UnlockAllActive then return originalNamecall(self, ...) end
                if self == equipRemote then
                    local args = {...}
                    local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                    equipped[weaponName] = equipped[weaponName] or {}
                    if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                        equipped[weaponName][cosmeticType] = nil
                        if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                    else
                        local cloned = cloneCosmetic(cosmeticName, cosmeticType, {
                            inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites,
                        })
                        if cloned then equipped[weaponName][cosmeticType] = cloned end
                        print("[Equip] " .. weaponName .. " | " .. cosmeticType .. " = " .. cosmeticName)
                    end
                    scheduleSave()
                    equippedChangedSignal:Fire()
                    return originalNamecall(self, ...)
                end
                if self == favoriteRemote then
                    local args = {...}
                    local category, name, state = args[1], args[2], args[3]
                    if isAllowed(name) then
                        favorites[category] = favorites[category] or {}
                        favorites[category][name] = state or nil
                        scheduleSave()
                    end
                    return originalNamecall(self, ...)
                end
                if self == unlockWeaponRemote then return end
                if self == favoriteWeaponRemote then return end
                return originalNamecall(self, ...)
            end)
            equipHookInstalled = true
            return true
        end
        return false
    end

    local weaponCount = 0
    for _ in pairs(weaponSet) do weaponCount = weaponCount + 1 end
    pcall(function()
        unlockInfoLabel:Set("Số vũ khí: " .. weaponCount .. " | Equip hook: " .. (equipHookInstalled and "✅ OK" or "⏸️ Chưa cài"))
    end)

    -- ✅ AUTO CÀI HOOK NẾU CONFIG BẬT
    if CONFIG.UnlockAllActive then
        local ok = installEquipHook()
        equipHookOK = ok
        print("[UnlockAll] Auto-installed hook from config:", ok and "OK" or "FAIL")
        if ok then
            pcall(function()
                unlockInfoLabel:Set("Số vũ khí: " .. weaponCount .. " | Equip hook: ✅ OK")
            end)
        end
    end

    task.wait()

    -- ============================================================
    -- SPOOF OWNERSHIP (luôn chạy)
    -- ============================================================
    if CosmeticLibrary then
        local originalOwnsCosmetic = ORIG.CosmeticLibrary_OwnsCosmetic
        CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
            if name and name:find("MISSING_", 1, true) then
                return originalOwnsCosmetic(self, inventory, name, weapon)
            end
            if isAllowed(name) then return true end
            return originalOwnsCosmetic(self, inventory, name, weapon)
        end
        CosmeticLibrary.OwnsCosmeticNormally    = function(_, _, name) return isAllowed(name) end
        CosmeticLibrary.OwnsCosmeticUniversally = function(_, _, name) return isAllowed(name) end
        CosmeticLibrary.OwnsCosmeticForWeapon   = function(_, _, name) return isAllowed(name) end
    end

    if ItemLibrary then
        for _, fnName in ipairs({"IsWeaponOwned", "OwnsWeapon", "HasWeapon", "IsWeaponUnlocked", "OwnsItem", "HasItem"}) do
            if ItemLibrary[fnName] then
                local orig = ItemLibrary[fnName]
                ItemLibrary[fnName] = function(self, name, ...)
                    if weaponSet[name] then return true end
                    return orig(self, name, ...)
                end
            end
        end
    end

    if ShopLibrary then
        if ShopLibrary.OwnableWeapons then
            for name in pairs(weaponSet) do
                if not ShopLibrary.OwnableWeapons[name] then
                    ShopLibrary.OwnableWeapons[name] = { Name = name, Owned = true, Released = true }
                end
            end
        end
        if ShopLibrary.OwnableWeaponsAlphabetized then
            for name in pairs(weaponSet) do
                if not table.find(ShopLibrary.OwnableWeaponsAlphabetized, name) then
                    table.insert(ShopLibrary.OwnableWeaponsAlphabetized, name)
                end
            end
        end
        if ShopLibrary.OwnableWeaponsCanEliminate then
            for name in pairs(weaponSet) do ShopLibrary.OwnableWeaponsCanEliminate[name] = true end
        end
        if ShopLibrary.GetReleasedOwnableWeapons then
            local orig = ShopLibrary.GetReleasedOwnableWeapons
            ShopLibrary.GetReleasedOwnableWeapons = function(self)
                local list = orig(self) or {}
                for name in pairs(weaponSet) do
                    if not table.find(list, name) then table.insert(list, name) end
                end
                return list
            end
        end
        if ShopLibrary.IsWeaponReleased then
            local orig = ShopLibrary.IsWeaponReleased
            ShopLibrary.IsWeaponReleased = function(self, name)
                if weaponSet[name] then return true end
                return orig(self, name)
            end
        end
    end

    task.wait()

    local function applyExchangeDirect()
        pcall(function()
            local d = DataController and DataController.CurrentData
            if d and d.Data then
                local v
                v = getExchangeValue("unlock_tokens");  if v then d.Data.UnlockTokens  = v end
                v = getExchangeValue("weapon_keys");    if v then d.Data.WeaponKeys    = v end
                v = getExchangeValue("glory");          if v then d.Data.Glory         = v end
                v = getExchangeValue("skin_tickets");   if v then d.Data.SkinTickets   = v end
                v = getExchangeValue("event_currency"); if v then d.Data.EventCurrency = v end
                v = getExchangeValue("gift_tickets");   if v then d.Data.GiftTickets   = v end
                v = getExchangeValue("player_level");   if v then d.Data.Level         = v end
                v = getExchangeValue("player_xp");      if v then d.Data.XP            = v end
            end
        end)
    end
    _G.applyExchangeDirect = applyExchangeDirect

    if DataController then
        local originalGet = ORIG.DataController_Get
        local invCache, invCacheTime = nil, 0

        DataController.Get = function(self, key)
            if key == "UnlockTokens"  then local v = getExchangeValue("unlock_tokens");  if v then return v end end
            if key == "WeaponKeys"    then local v = getExchangeValue("weapon_keys");    if v then return v end end
            if key == "Glory"         then local v = getExchangeValue("glory");          if v then return v end end
            if key == "SkinTickets"   then local v = getExchangeValue("skin_tickets");   if v then return v end end
            if key == "EventCurrency" then local v = getExchangeValue("event_currency"); if v then return v end end
            if key == "GiftTickets"   then local v = getExchangeValue("gift_tickets");   if v then return v end end
            if key == "Level"         then local v = getExchangeValue("player_level");   if v then return v end end
            if key == "XP"            then local v = getExchangeValue("player_xp");      if v then return v end end
            if key == "LastLoggedNumWeaponsUnlocked"  then return MAX_NUM end
            if key == "LastLoggedNumWeaponsUnlocked2" then return MAX_NUM end

            if key == "CosmeticInventory" then
                local now = tick()
                if invCache and now - invCacheTime < 1 then return invCache end
                local data = originalGet(self, key)
                local proxy = {}
                if data then
                    for k, v in pairs(data) do
                        if type(k) == "string" and k ~= "" and isAllowed(k) then
                            proxy[k] = v
                        end
                    end
                end
                invCache = setmetatable(proxy, {
                    __index = function(_, k)
                        if type(k) == "string" and k ~= "" and isAllowed(k) then
                            return true
                        end
                        return nil
                    end,
                })
                invCacheTime = now
                return invCache
            end
            if key == "WeaponInventory" then
                local data = originalGet(self, key)
                local proxy = {}
                local existingNames = {}
                if type(data) == "table" then
                    for k, v in pairs(data) do
                        if type(v) == "table" and v.Name then
                            proxy[k] = { Name = v.Name, Level = v.Level, XP = v.XP, Prestige = v.Prestige or 0, IsFavorited = v.IsFavorited or false, Unlocked = true, Owned = true }
                            existingNames[v.Name] = true
                        else
                            proxy[k] = v
                        end
                    end
                end
                local nextIdx = 1
                for name in pairs(weaponSet) do
                    if type(name) == "string" and name ~= "" and not existingNames[name] then
                        while proxy[nextIdx] ~= nil do nextIdx = nextIdx + 1 end
                        proxy[nextIdx] = { Name = name, Level = 1, XP = 0, Prestige = 0, IsFavorited = false, Unlocked = true, Owned = true }
                        nextIdx = nextIdx + 1
                    end
                end
                return proxy
            end

            if key == "WeaponStatistics" then
                local data = originalGet(self, key)
                local proxy = {}
                if type(data) == "table" then
                    for k, v in pairs(data) do proxy[k] = v end
                end
                for name in pairs(weaponSet) do
                    if not proxy[name] then
                        proxy[name] = { Kills = 0, Eliminations = 0, Uses = 0, Level = 1, XP = 0, Headshots = 0 }
                    end
                end
                return proxy
            end

            if key == "FavoritedCosmetics" then
                local data = originalGet(self, key)
                local result = data and table.clone(data) or {}
                for category, favs in pairs(favorites) do
                    if type(category) == "string" and category ~= "" and type(favs) == "table" then
                        result[category] = result[category] or {}
                        for name, isFav in pairs(favs) do
                            if type(name) == "string" and isAllowed(name) then
                                result[category][name] = isFav
                            end
                        end
                    end
                end
                return result
            end
            return originalGet(self, key)
        end

        local originalGetWeaponData = ORIG.DataController_GetWeaponData
        DataController.GetWeaponData = function(self, weaponName)
            local cosmetics = equipped[weaponName]
            local result = originalGetWeaponData(self, weaponName)
            if result then
                if type(result) == "table" and result.Name then
                    local wlvl = getExchangeValue("weapon_level")
                    local wxp  = getExchangeValue("weapon_xp")
                    local pres = getExchangeValue("prestige")
                    if wlvl then result.Level    = wlvl end
                    if wxp  then result.XP       = wxp end
                    if pres then result.Prestige = pres end
                end
                if cosmetics then
                    local merged = table.clone(result)
                    for cType, cData in pairs(cosmetics) do merged[cType] = cData end
                    return merged
                end
                return result
            end
            if weaponSet[weaponName] then
                local fake = { Name = weaponName, Level = getExchangeValue("weapon_level") or 1, XP = getExchangeValue("weapon_xp") or 0, Prestige = getExchangeValue("prestige") or 0, IsFavorited = false }
                if cosmetics then
                    for cType, cData in pairs(cosmetics) do fake[cType] = cData end
                end
                return fake
            end
            return nil
        end
    end

    task.wait()

    -- ============================================================
    -- VIEWMODEL OVERRIDE — FIX CHÍNH
    -- Hook _CreateViewModel + new() của ClientViewModel để áp skin lên viewmodel
    -- ============================================================
    local ClientItem = safeRequire(playerScripts.Modules.ClientReplicatedClasses.ClientFighter, "ClientItem")
    local constructingWeapon = nil

    if ClientItem and ClientItem._CreateViewModel then
        local originalCreateViewModel = ClientItem._CreateViewModel
        ClientItem._CreateViewModel = function(self, viewmodelRef)
            local weaponName   = self.Name
            local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
            constructingWeapon = (weaponPlayer == player) and weaponName or nil
            local cosmetics = (weaponPlayer == player) and equipped[weaponName]

            if cosmetics and viewmodelRef then
                local dataKey  = self:ToEnum("Data")
                local target   = viewmodelRef[dataKey] or viewmodelRef.Data
                if target then
                    if cosmetics.Skin  then target[self:ToEnum("Skin")]  = cosmetics.Skin  end
                    if cosmetics.Charm then target[self:ToEnum("Charm")] = cosmetics.Charm end
                    if cosmetics.Wrap  then target[self:ToEnum("Wrap")]  = cosmetics.Wrap  end
                    if cosmetics.Skin  then target[self:ToEnum("Name")]  = cosmetics.Skin.Name end
                end
            end

            local result = originalCreateViewModel(self, viewmodelRef)
            constructingWeapon = nil
            return result
        end
    end

    local cvmParent = playerScripts.Modules.ClientReplicatedClasses.ClientFighter:FindFirstChild("ClientItem")
    if cvmParent then
        local ClientViewModel = safeRequire(cvmParent, "ClientViewModel")
        if ClientViewModel and ClientViewModel.new then
            local originalNew = ClientViewModel.new
            ClientViewModel.new = function(replicatedData, clientItem)
                local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
                local weaponName   = constructingWeapon or clientItem.Name
                local cosmetics    = (weaponPlayer == player) and equipped[weaponName]

                if cosmetics then
                    local ReplicatedClass = safeRequire(ReplicatedStorage.Modules, "ReplicatedClass")
                    if ReplicatedClass then
                        local dataKey = ReplicatedClass:ToEnum("Data")
                        replicatedData[dataKey] = replicatedData[dataKey] or {}
                        local t = replicatedData[dataKey]
                        if cosmetics.Skin  then t[ReplicatedClass:ToEnum("Skin")]  = cosmetics.Skin  end
                        if cosmetics.Charm then t[ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
                        if cosmetics.Wrap  then t[ReplicatedClass:ToEnum("Wrap")]  = cosmetics.Wrap  end
                    end
                end

                local result = originalNew(replicatedData, clientItem)
                if cosmetics and cosmetics.Wrap and result._UpdateWrap then
                    task.defer(function()
                        if not result._destroyed then
                            pcall(function() result:_UpdateWrap() end)
                        end
                    end)
                end
                return result
            end
        end

        if ClientViewModel then
            if ClientViewModel.GetCharm then
                local orig = ClientViewModel.GetCharm
                ClientViewModel.GetCharm = function(self)
                    local item = self.ClientItem
                    local weaponName = item and item.Name
                    local wp = item and item.ClientFighter and item.ClientFighter.Player
                    if weaponName and wp == player and equipped[weaponName] and equipped[weaponName].Charm then
                        return equipped[weaponName].Charm
                    end
                    return orig(self)
                end
            end
            if ClientViewModel.GetWrap then
                local orig = ClientViewModel.GetWrap
                ClientViewModel.GetWrap = function(self)
                    local item = self.ClientItem
                    local weaponName = item and item.Name
                    local wp = item and item.ClientFighter and item.ClientFighter.Player
                    if weaponName and wp == player and equipped[weaponName] and equipped[weaponName].Wrap then
                        return equipped[weaponName].Wrap
                    end
                    return orig(self)
                end
            end
        end
    end

    -- ✅ Re-create viewmodel khi equipped thay đổi (khi user equip skin mới)
    equippedChangedSignal.Event:Connect(function()
        if not lplr.Character then return end
        local tool = lplr.Character:FindFirstChildWhichIsA("Tool")
        if not tool then return end
        -- Force recreate viewmodel bằng cách unequip + equip lại
        pcall(function()
            local FighterController_local = FighterController
            if FighterController_local and FighterController_local.LocalFighter then
                local lf = FighterController_local.LocalFighter
                local eq = lf.EquippedItem
                if eq then
                    -- Gọi Update để refresh viewmodel với data mới
                    if eq.Update then eq:Update() end
                    if eq.RenderViewModel then eq:RenderViewModel() end
                end
            end
        end)
    end)

    task.wait()

    -- ============================================================
    -- SILENT AIM
    -- ============================================================
    if Gun and type(Gun.StartShooting) == "function" then
        pcall(function()
            if Gun.IsFullyAiming then Gun.IsFullyAiming = function() return true end end
        end)

        local myRootCache, myRootCacheTime = nil, 0
        local function getMyRoot()
            local now = tick()
            if myRootCache and now - myRootCacheTime < 0.5 and myRootCache.Parent then return myRootCache end
            local char = lplr.Character
            myRootCache = char and char:FindFirstChild("HumanoidRootPart") or nil
            myRootCacheTime = now
            return myRootCache
        end

        local function isEnemy(p)
            if p == lplr then return false end
            if CONFIG.IgnoreTeam then
                local pT = p:GetAttribute("TeamID")
                local lT = lplr:GetAttribute("TeamID")
                if pT and lT and pT == lT then return false end
                if p.Team and lplr.Team and p.Team == lplr.Team then return false end
            end
            return true
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true

        local function isVisible(targetChar, headPart)
            if not CONFIG.CheckWall then return true end
            local myChar = lplr.Character
            if not myChar then return false end
            local origin = cam.CFrame.Position
            local direction = headPart.Position - origin
            rayParams.FilterDescendantsInstances = { myChar, targetChar }
            local result = workspace:Raycast(origin, direction, rayParams)
            return result == nil
        end

        local cachedTarget, cacheExpire = nil, 0
        local function findTarget()
            local myRoot = getMyRoot()
            if not myRoot then return nil end
            local camCF = cam.CFrame
            local camPos = camCF.Position
            local camLook = camCF.LookVector
            local maxD = CONFIG.MaxDistance
            local best, bestScore = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if not isEnemy(p) then continue end
                local c = p.Character
                if not c then continue end
                local hum = c:FindFirstChildWhichIsA("Humanoid")
                if not hum or hum.Health <= 0 then continue end
                local head = c:FindFirstChild("Head")
                if not head then continue end
                local toTarget = head.Position - camPos
                local dist = toTarget.Magnitude
                if dist > maxD or dist < 1 then continue end
                local dir = toTarget / dist
                local dot = camLook:Dot(dir)
                if dot <= 0 then continue end
                local cosFov = math.cos(math.rad(CONFIG.FOV * 0.5))
                if dot < cosFov then continue end
                if not isVisible(c, head) then continue end
                local score = 1 - dot
                if score < bestScore then
                    bestScore = score
                    best = { player = p, root = myRoot, head = head, dist3D = dist }
                end
            end
            return best
        end

        local function getTarget()
            local now = tick()
            if now < cacheExpire and cachedTarget then
                local h = cachedTarget.head
                if h and h.Parent then
                    local hum = h.Parent:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health > 0 then return cachedTarget end
                end
            end
            cachedTarget = findTarget()
            cacheExpire = now + CONFIG.CacheTime
            return cachedTarget
        end

        local function getWeaponOrigin()
            local char = lplr.Character
            if char then
                local weapon = char:FindFirstChildWhichIsA("Tool")
                if weapon then
                    local handle = weapon:FindFirstChild("Handle")
                    if handle then return handle.Position end
                end
            end
            return cam.CFrame.Position
        end

        local oldStartShooting = Gun.StartShooting
        Gun.StartShooting = function(self, ...)
            local result = { oldStartShooting(self, ...) }
            if not CONFIG.SilentAimEnabled or not U then return unpack(result) end
            local t = getTarget()
            if not t or not t.head or not t.head.Parent then return unpack(result) end
            local bulletData = nil
            for i = 1, #result do
                local v = result[i]
                if type(v) == "table" and v[utf8.char(2)] ~= nil then
                    bulletData = v
                    break
                end
            end
            if not bulletData and type(result[3]) == "table" then bulletData = result[3] end
            if not bulletData then return unpack(result) end
            local headCF  = t.head.CFrame
            local headPos = headCF.Position
            local origin  = getWeaponOrigin()
            local lookCF   = CFrame.lookAt(origin, headPos)
            local offsetCF = headCF:ToObjectSpace(CFrame.new(headPos))
            bulletData[utf8.char(0)] = U:EncodeCFrame(lookCF)
            bulletData[utf8.char(1)] = U:EncodeCFrame(headCF)
            bulletData[utf8.char(2)] = t.head
            bulletData[utf8.char(3)] = U:EncodeCFrame(offsetCF)
            return unpack(result)
        end
    end

    task.wait()

    -- ============================================================
    -- MOUSE AIM
    -- ============================================================
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            mouseAimRMBHeld = true
        end
        if input.KeyCode == CONFIG.MouseAimToggleKey then
            CONFIG.MouseAimEnabled = not CONFIG.MouseAimEnabled
            scheduleSave()
            pcall(function()
                if Rayfield.SetFlag then Rayfield:SetFlag("MouseAimToggle", CONFIG.MouseAimEnabled) end
            end)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            mouseAimRMBHeld = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not CONFIG.MouseAimEnabled then return end
        if not lplr.Character then return end
        if not mouseAimHasMoveRel then return end
        if CONFIG.MouseAimRequireWeapon and not isHoldingWeapon() then return end
        if CONFIG.MouseAimHoldRMB and not mouseAimRMBHeld then return end

        local camCF   = cam.CFrame
        local camPos  = camCF.Position
        local camLook = camCF.LookVector
        local best, bestScore = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == lplr then continue end
            if CONFIG.MouseAimIgnoreTeam then
                local pT = plr:GetAttribute("TeamID")
                local lT = lplr:GetAttribute("TeamID")
                if pT and lT and pT == lT then continue end
            end
            local char = plr.Character
            if not char then continue end
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local aimPart
            if CONFIG.MouseAimPart == "Head" then aimPart = char:FindFirstChild("Head")
            elseif CONFIG.MouseAimPart == "Torso" then aimPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
            else
                local parts = { char:FindFirstChild("Head"), char:FindFirstChild("UpperTorso"), char:FindFirstChild("Torso"), char:FindFirstChild("LowerTorso") }
                local valid = {}
                for _, p in ipairs(parts) do if p then table.insert(valid, p) end end
                if #valid > 0 then aimPart = valid[math.random(1, #valid)] end
            end
            if not aimPart then continue end
            local toTarget = aimPart.Position - camPos
            local dist = toTarget.Magnitude
            if dist > CONFIG.MouseAimMaxDistance or dist < 1 then continue end
            local dir = toTarget / dist
            local dot = camLook:Dot(dir)
            if dot <= 0 then continue end
            local cosFov = math.cos(math.rad(CONFIG.MouseAimFOV * 0.5))
            if dot < cosFov then continue end
            local score = 1 - dot
            if score < bestScore then
                bestScore = score
                best = aimPart
            end
        end
        if not best or not best.Parent then return end
        local viewport = cam.ViewportSize
        local screenPoint, onScreen = cam:WorldToViewportPoint(best.Position)
        if not onScreen then return end
        local dx = screenPoint.X - viewport.X / 2
        local dy = screenPoint.Y - viewport.Y / 2
        local moveX = dx * CONFIG.MouseAimSpeed
        local moveY = dy * CONFIG.MouseAimSpeed
        if math.abs(moveX) < 0.5 and math.abs(moveY) < 0.5 then return end
        pcall(function() mousemoverel(moveX, moveY) end)
    end)

    task.wait()

    -- ============================================================
    -- ESP
    -- ============================================================
    local ESP_Holder
    do
        local parent
        if gethui then
            local ok, hui = pcall(gethui)
            if ok and hui then parent = hui end
        end
        if not parent then parent = CoreGui end
        ESP_Holder = Instance.new("Folder")
        ESP_Holder.Name = "ESP_Holder"
        ESP_Holder.Parent = parent
    end

    local ESP_BoxTemplate = Instance.new("BoxHandleAdornment")
    ESP_BoxTemplate.Name = "nilBox"
    ESP_BoxTemplate.Size = Vector3.new(1, 2, 1)
    ESP_BoxTemplate.Color3 = Color3.new(0, 1, 0)
    ESP_BoxTemplate.Transparency = 0.7
    ESP_BoxTemplate.ZIndex = 0
    ESP_BoxTemplate.AlwaysOnTop = false
    ESP_BoxTemplate.Visible = false

    local ESP_NameTagTemplate = Instance.new("BillboardGui")
    ESP_NameTagTemplate.Name = "nilNameTag"
    ESP_NameTagTemplate.Enabled = false
    ESP_NameTagTemplate.Size = UDim2.new(0, 200, 0, 50)
    ESP_NameTagTemplate.AlwaysOnTop = true
    ESP_NameTagTemplate.StudsOffset = Vector3.new(0, 1.8, 0)
    local ESP_TagLabel = Instance.new("TextLabel", ESP_NameTagTemplate)
    ESP_TagLabel.Name = "Tag"
    ESP_TagLabel.BackgroundTransparency = 1
    ESP_TagLabel.Position = UDim2.new(0, -50, 0, 0)
    ESP_TagLabel.Size = UDim2.new(0, 300, 0, 20)
    ESP_TagLabel.TextSize = 15
    ESP_TagLabel.TextColor3 = Color3.new(0, 1, 0)
    ESP_TagLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    ESP_TagLabel.TextStrokeTransparency = 0.4
    ESP_TagLabel.Text = "nil"
    ESP_TagLabel.Font = Enum.Font.SourceSansBold

    local ESP_HighlightTemplate = Instance.new("Highlight")
    ESP_HighlightTemplate.Name = "nilHighlight"
    ESP_HighlightTemplate.FillColor = Color3.new(1, 0, 0)
    ESP_HighlightTemplate.OutlineColor = Color3.new(1, 1, 1)
    ESP_HighlightTemplate.FillTransparency = 0.5
    ESP_HighlightTemplate.OutlineTransparency = 0
    ESP_HighlightTemplate.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    ESP_HighlightTemplate.Enabled = false

    local function ESP_LerpColor(c1, c2, t)
        return Color3.new(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t)
    end
    local function ESP_GetHealthColor(pct)
        pct = math.clamp(pct, 0, 1)
        if pct >= CONFIG.ESP_HealthMidPoint then
            local t = (1 - pct) / (1 - CONFIG.ESP_HealthMidPoint)
            return ESP_LerpColor(CONFIG.ESP_HealthFullColor, CONFIG.ESP_HealthMidColor, t)
        else
            local t = (CONFIG.ESP_HealthMidPoint - pct) / CONFIG.ESP_HealthMidPoint
            return ESP_LerpColor(CONFIG.ESP_HealthMidColor, CONFIG.ESP_HealthLowColor, t)
        end
    end
    local function ESP_IsInRange(plr)
        local myChar = lplr.Character
        local targetChar = plr.Character
        if not myChar or not targetChar then return false end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not myRoot or not targetRoot then return false end
        return (myRoot.Position - targetRoot.Position).Magnitude <= CONFIG.ESP_Distance
    end

    local function ESP_LoadCharacter(plr)
        if plr == lplr then return end
        repeat task.wait() until plr.Character ~= nil
        plr.Character:WaitForChild("Humanoid", 10)
        local holder = ESP_Holder:FindFirstChild(plr.Name)
        if not holder then return end
        holder:ClearAllChildren()

        local char = plr.Character

        local b = ESP_BoxTemplate:Clone()
        b.Name = "Box"
        b.Adornee = char
        b.Parent = holder
        b.Visible = false

        local t = ESP_NameTagTemplate:Clone()
        t.Name = "NameTag"
        t.Enabled = false
        t.Parent = holder
        local head = char:FindFirstChild("Head")
        if head then
            t.Adornee = head
            t.Tag.Text = plr.Name
        end

        local h = ESP_HighlightTemplate:Clone()
        h.Name = "Highlight"
        h.Adornee = char
        h.Parent = holder
        h.Enabled = false
    end

    local function ESP_UnloadCharacter(plr)
        local holder = ESP_Holder:FindFirstChild(plr.Name)
        if holder then holder:ClearAllChildren() end
    end
    local function ESP_LoadPlayer(plr)
        if plr == lplr then return end
        local holder = ESP_Holder:FindFirstChild(plr.Name)
        if not holder then
            holder = Instance.new("Folder", ESP_Holder)
            holder.Name = plr.Name
        end
        plr.CharacterAdded:Connect(function() pcall(ESP_LoadCharacter, plr) end)
        plr.CharacterRemoving:Connect(function() pcall(ESP_UnloadCharacter, plr) end)
        pcall(ESP_LoadCharacter, plr)
    end
    local function ESP_UnloadPlayer(plr)
        ESP_UnloadCharacter(plr)
        local holder = ESP_Holder:FindFirstChild(plr.Name)
        if holder then holder:Destroy() end
    end

    task.wait(1)
    for _, plr in pairs(Players:GetPlayers()) do
        task.spawn(function()
            task.wait(0.05)
            pcall(ESP_LoadPlayer, plr)
        end)
    end
    Players.PlayerAdded:Connect(function(plr) pcall(ESP_LoadPlayer, plr) end)
    Players.PlayerRemoving:Connect(function(plr) pcall(ESP_UnloadPlayer, plr) end)

    task.spawn(function()
        while task.wait(0.1) do
            if not lplr.Character then continue end
            local holdingWeapon = true
            if CONFIG.ESP_OnlyWhenWeapon then holdingWeapon = isHoldingWeapon() end
            for _, plr in pairs(Players:GetPlayers()) do
                if plr == lplr then continue end
                local holder = ESP_Holder:FindFirstChild(plr.Name)
                if not holder then continue end
                local box = holder:FindFirstChild("Box")
                local nametag = holder:FindFirstChild("NameTag")
                local highlight = holder:FindFirstChild("Highlight")
                local char = plr.Character
                local hum = char and char:FindFirstChildWhichIsA("Humanoid")

                local color = Color3.fromRGB(255, 255, 255)
                if hum and hum.MaxHealth > 0 then
                    color = ESP_GetHealthColor(math.clamp(hum.Health / hum.MaxHealth, 0, 1))
                end

                local shouldShow = CONFIG.ESP_Enabled and holdingWeapon and ESP_IsInRange(plr) and hum and hum.Health > 0

                if box then
                    box.Visible = shouldShow and CONFIG.ESP_ShowBox
                    box.Color3 = color
                end
                if nametag then
                    nametag.Enabled = shouldShow and CONFIG.ESP_ShowName
                    nametag.Tag.TextColor3 = color
                    if char and char:FindFirstChild("Head") then
                        nametag.Adornee = char:FindFirstChild("Head")
                    end
                end
                if highlight then
                    highlight.Enabled = shouldShow and CONFIG.ESP_ShowHighlight
                    highlight.FillColor = color
                    highlight.OutlineColor = Color3.new(1, 1, 1)
                end
            end
        end
    end)

    task.wait()

    -- ============================================================
    -- RAGEV1
    -- ============================================================
    local function StartRageV1()
        if RageState.V1Instance then
            pcall(function() RageState.V1Instance:Shutdown() end)
            RageState.V1Instance = nil
        end
        if not Gun or type(Gun.StartShooting) ~= "function" then
            warn("[RAGEV1] Gun.StartShooting không phải function")
            return
        end
        if getgenv().__AimbotInstance then
            pcall(function() getgenv().__AimbotInstance:Shutdown() end)
        end

        local Aimbot = {}
        Aimbot.__active       = true
        Aimbot.__target       = nil
        Aimbot.__curr         = nil
        Aimbot.__desync       = false
        Aimbot.__conn1        = nil
        Aimbot.__conn2        = nil
        Aimbot.__task1        = nil
        Aimbot.__oldfunc      = nil
        Aimbot.__maxDistance  = CONFIG.Rage_V1_MaxDistance

        function Aimbot:__find()
            if CONFIG.Rage_RequireWeapon and not isHoldingWeapon() then return nil end
            local myChar = lplr.Character
            if not myChar then return nil end
            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return nil end

            local closest, closestDist = nil, math.huge
            for _, player in next, Players:GetPlayers() do
                if player == lplr then continue end
                local pTeam = player:GetAttribute("TeamID")
                local myTeam = lplr:GetAttribute("TeamID")
                if pTeam ~= nil and myTeam ~= nil and pTeam == myTeam then continue end

                local char = player.Character
                if not char then continue end
                local root = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if not (root and head and hum and hum.Health > 0) then continue end

                local dist = (myRoot.Position - root.Position).Magnitude
                if dist > self.__maxDistance then continue end
                if dist < closestDist then closestDist = dist; closest = player end
            end
            return closest
        end

        function Aimbot:__desync_start(target)
            if rawget(self, "__conn2") then
                pcall(function() rawget(self, "__conn2"):Disconnect() end)
                rawset(self, "__conn2", nil)
            end

            rawset(self, "__desync", true)
            rawset(self, "__curr", target)

            local selfRef = self

            local conn = RunService.Heartbeat:Connect(function()
                local isDesync = rawget(selfRef, "__desync")
                local isEnabled = CONFIG.Rage_Enabled
                local modeOK = CONFIG.Rage_Mode == "RageV1"

                if not isDesync or not isEnabled or not modeOK then
                    if rawget(selfRef, "__conn2") then
                        pcall(function() rawget(selfRef, "__conn2"):Disconnect() end)
                    end
                    rawset(selfRef, "__conn2", nil)
                    rawset(selfRef, "__desync", false)
                    return
                end

                if CONFIG.Rage_RequireWeapon and not isHoldingWeapon() then
                    if rawget(selfRef, "__conn2") then
                        pcall(function() rawget(selfRef, "__conn2"):Disconnect() end)
                    end
                    rawset(selfRef, "__conn2", nil)
                    rawset(selfRef, "__desync", false)
                    return
                end

                local myChar = lplr.Character
                if not myChar then return end
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end

                local targetObj = rawget(selfRef, "__curr")
                if not targetObj then return end

                local targetRoot = targetObj.Character
                    and targetObj.Character:FindFirstChild("HumanoidRootPart")
                if not targetRoot then return end

                local savedCFrame = myRoot.CFrame
                local savedVel    = myRoot.Velocity
                local savedRot    = myRoot.RotVelocity

                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, -5, 0)

                RunService:BindToRenderStep("__ragev1_restore", 101, function()
                    if myRoot then
                        myRoot.CFrame     = savedCFrame
                        myRoot.Velocity   = savedVel
                        myRoot.RotVelocity = savedRot
                    end
                    RunService:UnbindFromRenderStep("__ragev1_restore")
                end)
            end)

            rawset(self, "__conn2", conn)
        end

        function Aimbot:__desync_stop()
            rawset(self, "__desync", false)
            rawset(self, "__curr", nil)
            if rawget(self, "__conn2") then
                pcall(function() rawget(self, "__conn2"):Disconnect() end)
                rawset(self, "__conn2", nil)
            end
        end

        function Aimbot:Shutdown()
            rawset(self, "__active", false)
            if rawget(self, "__conn1") then
                pcall(function() rawget(self, "__conn1"):Disconnect() end)
                rawset(self, "__conn1", nil)
            end
            if rawget(self, "__conn2") then
                pcall(function() rawget(self, "__conn2"):Disconnect() end)
                rawset(self, "__conn2", nil)
            end
            if rawget(self, "__task1") then
                pcall(function() task.cancel(rawget(self, "__task1")) end)
                rawset(self, "__task1", nil)
            end
            if rawget(self, "__oldfunc") then
                Gun.StartShooting = rawget(self, "__oldfunc")
            end
        end

        Aimbot.__oldfunc = Gun.StartShooting
        Gun.StartShooting = function(self, ...)
            local result = {Aimbot.__oldfunc(self, ...)}
            if not self.ClientFighter or not self.ClientFighter.IsLocalPlayer then return unpack(result) end
            if CONFIG.Rage_RequireWeapon and not isHoldingWeapon() then return unpack(result) end

            local bulletData = result[3]
            if not bulletData or typeof(bulletData) ~= "table" then return unpack(result) end
            result[4] = true
            local target = Aimbot.__target
            if not Aimbot.__active or not CONFIG.Rage_Enabled or CONFIG.Rage_Mode ~= "RageV1" or not target or not target.Character then
                return unpack(result)
            end

            if not rawget(Aimbot, "__desync") or rawget(Aimbot, "__curr") ~= target then
                Aimbot:__desync_start(target)
                task.wait(0.1)
            end
            if Aimbot.__task1 then task.cancel(Aimbot.__task1); Aimbot.__task1 = nil end

            local head = target.Character:FindFirstChild("Head")
            if not head then return unpack(result) end
            local headPos = head.Position
            local headCF = head.CFrame
            local randomOffset = Vector3.new((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.2)
            local aimPos = headPos + randomOffset
            local lookCF = CFrame.lookAt(aimPos, headPos)
            local offsetCF = headCF:ToObjectSpace(CFrame.new(headPos + randomOffset))

            if U then
                bulletData[utf8.char(0)] = U:EncodeCFrame(CFrame.new(aimPos, headPos) * CFrame.Angles(lookCF:ToOrientation()))
                bulletData[utf8.char(1)] = U:EncodeCFrame(CFrame.new(headPos) * CFrame.Angles(lookCF:ToOrientation()))
                bulletData[utf8.char(2)] = head
                bulletData[utf8.char(3)] = U:EncodeCFrame(offsetCF)
            end

            Aimbot.__task1 = task.delay(0.15, function() Aimbot:__desync_stop() end)
            return unpack(result)
        end

        Aimbot.__conn1 = RunService.Heartbeat:Connect(function()
            if not Aimbot.__active or not CONFIG.Rage_Enabled or CONFIG.Rage_Mode ~= "RageV1" then
                Aimbot.__target = nil
                return
            end
            if CONFIG.Rage_RequireWeapon and not isHoldingWeapon() then
                Aimbot.__target = nil
                return
            end
            Aimbot.__target = Aimbot:__find()
        end)

        getgenv().__AimbotInstance = Aimbot
        RageState.V1Instance = Aimbot
        print("[RAGEV1] Hooked")
    end

    local function StopRageV1()
        if RageState.V1Instance then
            pcall(function() RageState.V1Instance:Shutdown() end)
            RageState.V1Instance = nil
        end
        if getgenv().__AimbotInstance then
            pcall(function() getgenv().__AimbotInstance:Shutdown() end)
            getgenv().__AimbotInstance = nil
        end
    end

    -- ============================================================
    -- RAGEV2 (giữ nguyên code gốc)
    -- ============================================================
    local function StartRageV2()
        if RageState.V2Started then return end
        RageState.V2Started = true
        RageState.V2Conns = {}
        RageState.V2Tasks = {}

        local function trackConn(conn)
            table.insert(RageState.V2Conns, conn)
            return conn
        end
        local function trackTask(thread)
            table.insert(RageState.V2Tasks, thread)
            return thread
        end

        local success, err = pcall(function()
            local util = U or require(ReplicatedStorage.Modules.Utility)
            local enum = require(ReplicatedStorage.Modules.EnumLibrary)
            local FC = require(lplr.PlayerScripts.Controllers.FighterController)
            local SpectateController = require(lplr.PlayerScripts.Controllers:WaitForChild("SpectateController"))

            getgenv().RageConfig = {
                Enabled = false,
                FireRate = CONFIG.Rage_FireRate,
                WeaponSlot = CONFIG.Rage_WeaponSlot,
                DesyncEnabled = false,
                DesyncAngles = { Yaw = CONFIG.Rage_DesyncYaw, Pitch = CONFIG.Rage_DesyncPitch, Roll = CONFIG.Rage_DesyncRoll },
                DesyncJitter = CONFIG.Rage_DesyncJitter,
                VelocityMultiplier = CONFIG.Rage_VelocityMultiplier,
                AutoSwitch = false,
                SwitchThreshold = CONFIG.Rage_SwitchThreshold,
                MaxAmmo = { Primary = 20, Secondary = 13, Melee = 999 },
                CurrentShot = 0,
                UseRealAmmo = CONFIG.Rage_UseRealAmmo,
                MeleeKeep = false,
                ShowEnemyWeapon = CONFIG.Rage_ShowEnemyWeapon,
            }

            local slots = { Primary = 1, Secondary = 2, Melee = 3 }
            local slotOrder = {"Primary", "Secondary", "Melee"}
            local function getSlotNumber(slotName) return slots[slotName] or 1 end

            local isRespawning = false
            local respawnLock = false
            local lastSwitchTime = 0
            local scriptToggled = false

            local meleeKeywords = {"Melee", "Knife", "Katana", "Sword", "Dagger", "Blade", "Axe", "Hammer", "Club", "Stick", "Machete", "Fists", "Punch"}
            local isMeleeWeapon = false

            local function checkIfMelee()
                if getgenv().RageConfig.MeleeKeep and getgenv().RageConfig.WeaponSlot == "Melee" then isMeleeWeapon = true; return true end
                local lf = FC.LocalFighter
                if not lf then return false end
                local eq = lf.EquippedItem
                if not eq then return false end
                local name = eq.Name or ""
                for _, kw in ipairs(meleeKeywords) do
                    if string.find(name, kw) then isMeleeWeapon = true; return true end
                end
                if getgenv().RageConfig.WeaponSlot == "Melee" then isMeleeWeapon = true; return true end
                isMeleeWeapon = false
                return false
            end

            local function isHoldingWeaponV2()
                if not CONFIG.Rage_RequireWeapon then return true end
                local lf = FC.LocalFighter
                if not lf then return false end
                local eq = lf.EquippedItem
                if not eq then return false end
                local name = eq.Name or ""
                if name == "" then return false end
                return true
            end

            local function getRealAmmo()
                if checkIfMelee() then return 999, 999 end
                if not getgenv().RageConfig.UseRealAmmo then
                    return getgenv().RageConfig.CurrentShot or 0, getgenv().RageConfig.MaxAmmo[getgenv().RageConfig.WeaponSlot] or 999
                end
                local lf = FC.LocalFighter
                if not lf then return getgenv().RageConfig.CurrentShot or 0, getgenv().RageConfig.MaxAmmo[getgenv().RageConfig.WeaponSlot] or 999 end
                local eq = lf.EquippedItem
                if not eq then return "N/A", "N/A" end
                local cur, max, found = 0, 0, false
                if eq.Data then
                    for _, p in ipairs({"CurrentAmmo","Ammo","Clip","Magazine","Bullets","AmmoCount","Loaded"}) do
                        local s, v = pcall(function() return eq.Data[p] end)
                        if s and type(v) == "number" then cur = v; found = true; break end
                    end
                    if found then
                        for _, p in ipairs({"MaxAmmo","MaxClip","MagazineSize","AmmoCapacity"}) do
                            local s, v = pcall(function() return eq.Data[p] end)
                            if s and type(v) == "number" and v > 0 then max = v; break end
                        end
                    end
                end
                if not found or cur == 0 then
                    for _, p in ipairs({"Ammo","CurrentAmmo","Clip","Magazine"}) do
                        local s, v = pcall(function() return eq[p] end)
                        if s and type(v) == "number" then cur = v; found = true; break end
                    end
                end
                if cur > 0 then
                    getgenv().RageConfig.CurrentShot = cur
                    if max > 0 then getgenv().RageConfig.MaxAmmo[getgenv().RageConfig.WeaponSlot] = max end
                    return cur, max
                end
                if cur == 0 and max > 0 then getgenv().RageConfig.CurrentShot = 0; return 0, max end
                return getgenv().RageConfig.CurrentShot or 0, getgenv().RageConfig.MaxAmmo[getgenv().RageConfig.WeaponSlot] or 999
            end

            local function getNextSlot(cur)
                if cur == "Melee" then return "Melee" end
                for i, s in ipairs(slotOrder) do
                    if s == cur then
                        local n = i + 1
                        if n > #slotOrder then return slotOrder[#slotOrder] end
                        return slotOrder[n]
                    end
                end
                return slotOrder[1]
            end

            local function checkRespawn()
                if respawnLock then return false end
                local char = lplr.Character
                if not char then isRespawning = true; return true end
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if not hum then isRespawning = true; return true end
                local hp = hum.Health
                if hp > 50 and isRespawning then
                    respawnLock = true
                    getgenv().RageConfig.WeaponSlot = "Primary"
                    getgenv().RageConfig.CurrentShot = 0
                    local lf = FC.LocalFighter
                    if lf then pcall(function() lf:EquipItem(1) end) end
                    task.wait(0.5)
                    isRespawning = false
                    respawnLock = false
                    return true
                end
                if isRespawning and hp == 0 then return true end
                isRespawning = false
                return false
            end

            trackConn(lplr.CharacterAdded:Connect(function()
                if not scriptToggled or not CONFIG.Rage_Enabled then return end
                if not respawnLock then
                    respawnLock = true
                    task.wait(0.5)
                    getgenv().RageConfig.WeaponSlot = "Primary"
                    getgenv().RageConfig.CurrentShot = 0
                    local lf = FC.LocalFighter
                    if lf then pcall(function() lf:EquipItem(1) end) end
                    task.wait(0.5)
                    isRespawning = false
                    respawnLock = false
                end
            end))

            trackTask(task.spawn(function()
                while true do
                    task.wait(0.5)
                    if not scriptToggled or not CONFIG.Rage_Enabled then continue end
                    checkRespawn()
                end
            end))

            local function checkAndSwitchWeapon()
                if not getgenv().RageConfig.AutoSwitch or isRespawning or respawnLock then return false end
                local cur = getgenv().RageConfig.WeaponSlot
                if cur == "Melee" then return false end
                if checkIfMelee() then return false end
                local shot, max = getRealAmmo()
                if shot == "N/A" then return false end
                getgenv().RageConfig.CurrentShot = shot
                if max > 0 and max ~= "N/A" then getgenv().RageConfig.MaxAmmo[cur] = max end
                if shot > (getgenv().RageConfig.SwitchThreshold or 1) then return false end
                if tick() - lastSwitchTime < 0.8 then return false end
                local nxt = getNextSlot(cur)
                if nxt == cur then return false end
                getgenv().RageConfig.WeaponSlot = nxt
                getgenv().RageConfig.CurrentShot = 0
                lastSwitchTime = tick()
                local lf = FC.LocalFighter
                if lf then pcall(function() lf:EquipItem(getSlotNumber(nxt)) end) end
                return true
            end

            local autoPickupEnabled = false
            local visitedDrops = {}
            local isPickingUp = false

            local function isInCombat()
                local char = lplr.Character
                if not char then return false end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return false end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == lplr then continue end
                    local pc = p.Character
                    if not pc then continue end
                    local pr = pc:FindFirstChild("HumanoidRootPart")
                    if not pr then continue end
                    if (root.Position - pr.Position).Magnitude < 50 then return true end
                end
                return false
            end

            local function handleNewDrop(obj)
                if not autoPickupEnabled or isPickingUp or isRespawning then return end
                if not scriptToggled or not CONFIG.Rage_Enabled then return end
                if not (obj:IsA("BasePart") and obj.Name == "_drop") then return end
                if visitedDrops[obj] then return end
                if isInCombat() then return end
                visitedDrops[obj] = true
                isPickingUp = true
                task.wait()
                pcall(function()
                    if obj:IsDescendantOf(Workspace) and lplr.Character then
                        local root = lplr.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local oe, od = getgenv().RageConfig.Enabled, getgenv().RageConfig.DesyncEnabled
                            getgenv().RageConfig.Enabled = false
                            getgenv().RageConfig.DesyncEnabled = false
                            root.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.2)
                            getgenv().RageConfig.Enabled = oe
                            getgenv().RageConfig.DesyncEnabled = od
                        end
                    end
                end)
                isPickingUp = false
            end

            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "_drop" then visitedDrops[obj] = true end
            end
            trackConn(Workspace.DescendantAdded:Connect(handleNewDrop))

            local deflecting = {}
            local currentDesyncCF = nil
            trackConn(Players.PlayerRemoving:Connect(function(p) deflecting[p] = nil end))

            local function updateDeflection()
                if not FC or not FC.Objects then return end
                for _, fo in FC.Objects do
                    local p = fo.Player
                    if not p then continue end
                    if not fo.Entity or not fo.Entity:IsAlive() or fo:Get("IsSpectating") then deflecting[p] = false; continue end
                    local eq = fo.EquippedItem
                    local isKatana = eq and eq.ViewModel and eq.ViewModel.Name == "Katana"
                    local isDef = false
                    if isKatana then isDef = (eq._attack_cooldown and eq._attack_cooldown > tick()) or false end
                    deflecting[p] = isDef
                end
            end

            local function isEnemyV2(player)
                if player == lplr then return false end
                local duel = SpectateController.CurrentDuelSubject
                local localDueler = duel and duel:GetDueler(lplr)
                local localTeam = localDueler and localDueler:Get("TeamID") or nil
                if localTeam and duel and duel.Duelers then
                    for _, dueler in duel.Duelers do
                        if dueler.Player == player then return dueler:Get("TeamID") ~= localTeam end
                    end
                end
                local pTeam = player:GetAttribute("TeamID")
                local lTeam = lplr:GetAttribute("TeamID")
                if pTeam ~= nil and lTeam ~= nil then return pTeam ~= lTeam end
                return true
            end

            local function getClosestTarget()
                local char = lplr.Character
                if not char then return nil, nil, nil end
                local myRoot = char:FindFirstChild("HumanoidRootPart")
                if not myRoot then return nil, nil, nil end
                local cp, cr, ch, cd = nil, nil, nil, 500
                for _, p in ipairs(Players:GetPlayers()) do
                    if not isEnemyV2(p) then continue end
                    local pc = p.Character
                    if not pc then continue end
                    local pr = pc:FindFirstChild("HumanoidRootPart")
                    local ph = pc:FindFirstChild("Head")
                    local phu = pc:FindFirstChildWhichIsA("Humanoid")
                    if not (pr and ph and phu and phu.Health > 0) then continue end
                    local d = (myRoot.Position - pr.Position).Magnitude
                    if d < cd then cd = d; cp = p; cr = pr; ch = ph end
                end
                return cp, cr, ch
            end

            local function hasKnifeViewModel(targetPlayer)
                if not targetPlayer then return false end
                local vms = Workspace:FindFirstChild("ViewModels")
                if not vms then return false end
                local tn = targetPlayer.Name
                for _, m in ipairs(vms:GetChildren()) do
                    if m:IsA("Model") and string.find(m.Name, tn, 1, true) and string.find(m.Name, "Knife", 1, true) then return true end
                end
                return false
            end

            trackConn(RunService.Heartbeat:Connect(function()
                if not scriptToggled or not CONFIG.Rage_Enabled then return end
                if CONFIG.Rage_Mode ~= "RageV2" then return end
                updateDeflection()
                local tp, tr, th = getClosestTarget()
                if tr and th then
                    local dp
                    if hasKnifeViewModel(tp) then dp = (tr.CFrame * CFrame.new(0, 6, 0)).Position
                    else dp = (tr.CFrame * CFrame.new(0, 1, 2)).Position end
                    currentDesyncCF = CFrame.lookAt(dp, th.Position)
                else
                    currentDesyncCF = nil
                end

                if lplr.Character then
                    local myRoot = lplr.Character:FindFirstChild("HumanoidRootPart")
                    if myRoot and not isPickingUp and not isRespawning and isHoldingWeaponV2() then
                        local oldCF, oldVel, oldRot = myRoot.CFrame, myRoot.Velocity, myRoot.RotVelocity
                        if getgenv().RageConfig.DesyncEnabled then
                            local jx = (math.random() - 0.5) * getgenv().RageConfig.DesyncJitter
                            local jz = (math.random() - 0.5) * getgenv().RageConfig.DesyncJitter
                            local jitter = Vector3.new(jx, 0, jz)
                            local ang = CFrame.Angles(
                                math.rad(getgenv().RageConfig.DesyncAngles.Pitch),
                                math.rad(getgenv().RageConfig.DesyncAngles.Yaw),
                                math.rad(getgenv().RageConfig.DesyncAngles.Roll)
                            )
                            myRoot.CFrame = (currentDesyncCF or oldCF) * ang + jitter
                            myRoot.Velocity = oldVel.Unit * getgenv().RageConfig.VelocityMultiplier
                            myRoot.RotVelocity = Vector3.new(0, 500, 0)
                        else
                            if currentDesyncCF then myRoot.CFrame = currentDesyncCF end
                        end
                        RunService:BindToRenderStep("__ragev2_restore", 101, function()
                            if myRoot then
                                myRoot.CFrame = oldCF
                                myRoot.Velocity = oldVel
                                myRoot.RotVelocity = oldRot
                            end
                            RunService:UnbindFromRenderStep("__ragev2_restore")
                        end)
                    end
                end
            end))

            trackTask(task.spawn(function()
                while true do
                    task.wait(getgenv().RageConfig.FireRate)
                    if not scriptToggled or not CONFIG.Rage_Enabled then continue end
                    if CONFIG.Rage_Mode ~= "RageV2" then continue end
                    if not getgenv().RageConfig.Enabled then continue end
                    if isPickingUp then continue end
                    if isRespawning then task.wait(0.3); continue end
                    if not isHoldingWeaponV2() then continue end
                    if getgenv().RageConfig.AutoSwitch then checkAndSwitchWeapon() end
                    local isMelee = checkIfMelee()
                    local shot, _ = getRealAmmo()
                    if not isMelee and (shot == "N/A" or shot <= 0) then continue end
                    local tp, tr, th = getClosestTarget()
                    if not tp or not th or not tr then continue end
                    if deflecting[tp] then continue end
                    if not lplr.Character or not lplr.Character:FindFirstChild("HumanoidRootPart") then continue end
                    if not FC or not FC.LocalFighter then continue end
                    local item = FC.LocalFighter.EquippedItem
                    if not item then continue end
                    local origin = currentDesyncCF and currentDesyncCF.Position or tr.Position
                    local target = th.Position
                    local aimCF = CFrame.lookAt(origin, target)
                    local targetCF = th.CFrame
                    local off = Vector3.new((math.random()-0.5)*0.1, (math.random()-0.5)*0.1, (math.random()-0.5)*0.1)
                    local aimed = target + off
                    local objOff = th.CFrame:ToObjectSpace(CFrame.new(aimed))
                    local cam = {}
                    cam[utf8.char(1)] = {
                        [utf8.char(0)] = util:EncodeCFrame(aimCF),
                        [utf8.char(1)] = util:EncodeCFrame(targetCF),
                        [utf8.char(2)] = th,
                        [utf8.char(3)] = util:EncodeCFrame(objOff)
                    }
                    pcall(function()
                        ReplicatedStorage.Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"), enum:ToEnum("StartShooting"), cam, nil)
                        pcall(function()
                            ReplicatedStorage.Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"), enum:ToEnum("StopShooting"), nil, nil)
                        end)
                    end)
                end
            end))

            trackTask(task.spawn(function()
                while true do
                    task.wait(0.2)
                    local shouldBeOn = CONFIG.Rage_Enabled and CONFIG.Rage_Mode == "RageV2"
                    if shouldBeOn ~= scriptToggled then
                        scriptToggled = shouldBeOn
                        getgenv().RageConfig.Enabled = shouldBeOn
                        getgenv().RageConfig.AutoSwitch = shouldBeOn
                        getgenv().RageConfig.DesyncEnabled = shouldBeOn
                        getgenv().RageConfig.MeleeKeep = shouldBeOn
                        autoPickupEnabled = shouldBeOn
                        if not shouldBeOn then
                            isRespawning = false
                            respawnLock = false
                            isPickingUp = false
                        end
                    end
                end
            end))

            print("[RAGEV2] Loaded (idle)")
        end)

        if not success then warn("[RAGEV2] Error: " .. tostring(err)) end
    end

    local function StopRageV2()
        RageState.V2Started = false

        for _, conn in ipairs(RageState.V2Conns) do
            pcall(function() conn:Disconnect() end)
        end
        RageState.V2Conns = {}

        for _, thread in ipairs(RageState.V2Tasks) do
            pcall(function() task.cancel(thread) end)
        end
        RageState.V2Tasks = {}

        if getgenv().RageConfig then
            getgenv().RageConfig.Enabled = false
            getgenv().RageConfig.AutoSwitch = false
            getgenv().RageConfig.DesyncEnabled = false
            getgenv().RageConfig.MeleeKeep = false
        end

        pcall(function() RunService:UnbindFromRenderStep("__ragev2_restore") end)

        print("[RAGEV2] Stopped")
    end

    local function ApplyRageState()
        if CONFIG.Rage_Enabled then
            if CONFIG.Rage_Mode == "RageV1" then
                StopRageV2()
                StopRageV1()
                StartRageV1()
            else
                StopRageV1()
                StopRageV2()
                StartRageV2()
                if getgenv().RageConfig then
                    getgenv().RageConfig.Enabled = true
                    getgenv().RageConfig.AutoSwitch = true
                    getgenv().RageConfig.DesyncEnabled = true
                    getgenv().RageConfig.MeleeKeep = true
                end
            end
        else
            StopRageV1()
            StopRageV2()
        end
    end

    _G.ApplyRageState = ApplyRageState

    CONFIG.Rage_Enabled = false
    if Rayfield.SetFlag then
        pcall(function() Rayfield:SetFlag("RageEnabled", false) end)
    end
    print("[Rage] Forced OFF on startup")

    task.wait()

    -- ============================================================
    -- STATISTICS
    -- ============================================================
    task.spawn(function()
        local ok = false
        if DataController then
            local cd = rawget(DataController, "CurrentData")
            if cd and type(cd) == "table" then
                local d = cd.Data or cd
                if type(d) == "table" then
                    local n = 0
                    for _ in pairs(d) do n = n + 1 end
                    if n >= 5 then
                        PlayerStats.data = d
                        PlayerStats.count = n
                        ok = true
                    end
                end
            end
        end
        if not ok and getgc then
            local gcOK, gc = pcall(getgc, true)
            if gcOK and type(gc) == "table" then
                local best, bestCount = nil, 0
                for i = 1, #gc do
                    local v = gc[i]
                    if type(v) == "table" then
                        local d = rawget(v, "Data")
                        if type(d) == "table" then
                            local n = 0
                            for _ in pairs(d) do n = n + 1 end
                            if n > bestCount then bestCount = n; best = d end
                        end
                    end
                end
                if best and bestCount >= 5 then
                    PlayerStats.data = best
                    PlayerStats.count = bestCount
                    ok = true
                end
            end
        end
        if not ok then
            pcall(function() statsStatusLabel:Set("❌ Không tìm thấy data") end)
            return
        end
        pcall(function() statsStatusLabel:Set("✅ Đã tìm thấy " .. PlayerStats.count .. " keys") end)
        local function getStat(k, def)
            if not PlayerStats.data then return def or 0 end
            return PlayerStats.data[k] ~= nil and PlayerStats.data[k] or (def or 0)
        end
        local function formatNum(x)
            if type(x) ~= "number" then return tostring(x or 0) end
            local s = tostring(math.floor(x))
            local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
            return r:gsub("^,", "")
        end
        Tab_Stats:CreateSection("📌 Tổng quan")
        Tab_Stats:CreateLabel("Level: " .. tostring(getStat("Level")))
        Tab_Stats:CreateLabel("XP: " .. formatNum(getStat("XP")))
        Tab_Stats:CreateSection("⚔️ Duels")
        Tab_Stats:CreateLabel("Trận: " .. formatNum(getStat("StatisticDuelsPlayed")))
        Tab_Stats:CreateLabel("Thắng: " .. formatNum(getStat("StatisticDuelsWon")))
        Tab_Stats:CreateLabel("Thua: " .. formatNum(getStat("StatisticDuelsLost")))
    end)

    print("===========================================")
    print("[KPCHOOK v4] Loaded!")
    print("  Silent Aim: " .. (CONFIG.SilentAimEnabled and "ON" or "OFF"))
    print("  Mouse Aim: " .. (CONFIG.MouseAimEnabled and "ON" or "OFF"))
    print("  Rage: " .. CONFIG.Rage_Mode .. " | Enabled: " .. tostring(CONFIG.Rage_Enabled) .. " (forced OFF)")
    print("  ESP: " .. (CONFIG.ESP_Enabled and "ON" or "OFF"))
    print("  Unlock All: " .. (CONFIG.UnlockAllActive and "ON" or "OFF"))
    print("  Executor: " .. ExecutorInfo.Name)
    print("===========================================")

    Rayfield:Notify({ Title = "KPCHOOK v4", Content = "✅ Tải xong! Rage OFF.", Duration = 3 })
end)
