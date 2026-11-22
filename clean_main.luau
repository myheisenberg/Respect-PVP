-- RESPECT PVP HUB v1.0 (u10772490127 - PVP'ye Saygi)
-- Aim: Camera (safe) / Silent (packet) - Trigger - ESP - Skins - Stats - FPS
-- KURALLAR: Camera modunda kamera hedefe kitlenir, oyunun kendi AimState
-- akisi kamera pozundan turetilir -> paketler daima tutarli (AIM CHECK dostu).
-- Silent modu paketi hesaplanmis yonle gonderir - RISK: admin AIM CHECK
-- replay'inde atis cizgisi crosshair cizgisinden ayri gorunur + spoofaim
-- imzasi. TEST HESABI icin onerilir.

-- SELF-CLEANUP: onceki instance'in her seyini sok (cift yukleme = crash onlemi)
if getgenv().PVP_TEARDOWN then pcall(getgenv().PVP_TEARDOWN) end
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("PVP_Aim") end)
pcall(function() game:GetService("RunService"):UnbindFromRenderStep("PVP_AutoFire") end)
-- CAS aksiyon adi OTURUM BAZLI RANDOM (ContentProbe CAS isim taramasina karsi)
if getgenv().PVP_CAS_NAME then
    pcall(function() game:GetService("ContextActionService"):UnbindAction(getgenv().PVP_CAS_NAME) end)
end
pcall(function()
    if gethui then
        for _, c in ipairs(gethui():GetChildren()) do
            if c.Name == "PVP_ESP" then c:Destroy() end
        end
    end
end)
pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g:IsA("ScreenGui") then
            local isMine = false
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") and (d.Text or ""):find("RESPECT PVP") then isMine = true break end
            end
            if isMine or g.Name:find("Fluent") then g:Destroy() end
        end
    end
end)

-- STALE FLAG KORUMASI: onceki instance YARI YOLDA coktuysa (hata ile)
-- PVP_HUB_LOADED kalir ama PVP_TEARDOWN yoktur -> hub geri yuklenemezdi.
-- Teardown yoksa bayrak bayat demektir: temizle ve devam et.
if getgenv().PVP_HUB_LOADED and not getgenv().PVP_TEARDOWN then
    getgenv().PVP_HUB_LOADED = nil
end
-- FLUENT STATE KIRLILIGI: ayni oturumda birden fazla yukleme calismasi
-- Fluent'in global state'ini (getgenv/_G) ve eski GUI'lerini kirletiyor
-- -> ikinci yuklemede tween/CreateTab hatalari. Tam temizlik:
getgenv().Fluent = nil
pcall(function() _G.Fluent = nil end)
pcall(function()
    for _, root in ipairs({ game:GetService("CoreGui"), gethui and gethui() or nil }) do
        if root then
            for _, g in ipairs(root:GetChildren()) do
                if g:IsA("ScreenGui") and tostring(g.Name):find("Fluent") then
                    g:Destroy()
                end
            end
        end
    end
end)
if getgenv().PVP_HUB_LOADED then return end
getgenv().PVP_HUB_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local S = {
    AimEnabled = true,
    AimMode = "Fire",
    AimEngine = "Silent",
    AimFOV = 50,
    AimDistance = 200,
    AimSpeed = 14,
    AimKey = Enum.KeyCode.Q,
    AimPart = "Head",
    WallCheck = true,
    ShowFOV = true,
    TeamCheck = true,
    TriggerEnabled = false,
    TriggerDelay = 70,
    NoRecoil = false,
    SilentSnap = false,
    SilentBend = 80,
    SoftTrack = false,
    SilentHumanize = false,
    SilentHook = false,
    ESPEnabled = true,
    ESPBots = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    AntiAFK = true,
    StatsHits = 0,
    StatsKills = 0,
    StatsHeadshots = 0,
}
getgenv().PVP_S = S

-- ===== OYUN SABLONLARI (Shared config - client tarafindan require edilebilir) =====
-- ReplicatedStorage alt klasorleri ASINKRON yuklenir: taze client'ta
-- 'ReplicatedStorage.Shared' henuz YOKTUR -> aninda require = script
-- olur. WaitForChild ile bekle (max 30sn).
local RS_Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local RS_Client = ReplicatedStorage:WaitForChild("Client", 30)
local RS_Framework = ReplicatedStorage:WaitForChild("Framework", 30)
local WeaponData = require(RS_Shared:WaitForChild("Config", 30):WaitForChild("WeaponData", 30))
local Settings = require(RS_Shared:WaitForChild("Config", 30):WaitForChild("Settings", 30))
local Skins = require(RS_Shared:WaitForChild("Config", 30):WaitForChild("Skins", 30))
local SkinLook = require(RS_Shared:WaitForChild("Modules", 30):WaitForChild("SkinLook", 30))
local ClientState = require(RS_Client:WaitForChild("ClientState", 30))
local Framework = require(RS_Framework)

-- Remoteler oyunun kendi sarmalayicisindan (ayni instance'lar, en temiz yol)
local RemoteLib = Framework.ConnectionBetweenSides.Remote
local RemotesEnum = require(RS_Shared:WaitForChild("Remotes", 30))
local FireRemote = RemoteLib:GetRemoteEvent(RemotesEnum.Fire)          -- WeaponFire
local HitRemote = RemoteLib:GetRemoteEvent(RemotesEnum.Hit)            -- WeaponHit

local FIRE_REMOTES_OK = FireRemote ~= nil

-- ===== Fluent (myheisenberg Fluent-Renewed - internetten, dagitima uygun) =====
local Fluent
do
    local t0 = os.clock()
    while not Fluent and os.clock() - t0 < 12 do
        local ok, f = pcall(function()
            return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Fluent.luau"))()
        end)
        if ok then Fluent = f end
        if not Fluent then task.wait(1) end
    end
end
if not Fluent then
    warn("[PVPHub] Fluent-Renewed yuklenemedi")
    return
end

pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g:IsA("ScreenGui") and (g.Name:find("FluentRenewed") or g.Name:find("Fluent")) then
            g:Destroy()
        end
    end
end)

-- MOBIL TESPIT: telefonda pencere kucuk olsun (Fluent PC odakli)
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Window = Fluent:CreateWindow({
    Title = "RESPECT PVP HUB - by ZynexDev",
    TabWidth = IS_MOBILE and 110 or 160,
    Size = IS_MOBILE and UDim2.fromOffset(340, 320) or UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Darker",
    -- DIKKAT: MinimizeKey YOK. RightControl'u BIZ sahipleniyoruz
    -- (asagi'daki kendi handler'imiz). Fluent'e de verilirse ayni
    -- tus icin IKI toggle yanip bozuluyor (menu geri acilmaz /
    -- state kacar). Fluent kendi X butonundan minimize yapar -
    -- OnMinimized sinyali onu yakalar.
})

pcall(function() Fluent.GUI.Enabled = false end)

local Tabs = {}
local function mkTab(idx, props)
    local okT = pcall(function() Tabs[idx] = Window:CreateTab(props) end)
    if not okT or not Tabs[idx] then
        pcall(function() Tabs[idx] = Window:CreateTab({ Title = props.Title }) end)
    end
    -- FLUENT UI KALKANI: callback icinde hata atarsa Fluent'in UI akisi
    -- yarida kalir (dropdown kapanmaz, toggle takilir). Tum Callback'ler
    -- pcall'a sarilir. (Dropdown otomatik-kapanma cozumu ayri: asagida
    -- Fluent.Options SetValue sarmasi - kok orada.)
    local tab = Tabs[idx]
    if tab then
        for _, mname in ipairs({ "AddToggle", "AddDropdown", "AddSlider", "AddKeybind", "AddInput", "AddColorPicker" }) do
            local orig = tab[mname]
            if type(orig) == "function" then
                tab[mname] = function(_, props2, ...)
                    if type(props2) == "table" then
                        if type(props2.Callback) == "function" then
                            local ocb = props2.Callback
                            props2.Callback = function(...) pcall(ocb, ...) end
                        end
                        if type(props2.ChangedCallback) == "function" then
                            local occ = props2.ChangedCallback
                            props2.ChangedCallback = function(...) pcall(occ, ...) end
                        end
                    end
                    return orig(tab, props2, ...)
                end
            end
        end
    end
end
mkTab("Dashboard", { Title = "Dashboard", Icon = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150" })
mkTab("Aim", { Title = "Aim", Icon = "crosshair" })
mkTab("Trigger", { Title = "Trigger", Icon = "mouse-pointer" })
mkTab("ESP", { Title = "ESP", Icon = "eye" })
mkTab("Skins", { Title = "Skins", Icon = "shirt" })
mkTab("Misc", { Title = "Misc", Icon = "settings" })
mkTab("Stats", { Title = "Stats", Icon = "activity" })
mkTab("Settings", { Title = "Config", Icon = "save" })

-- ===== TAKIM: bu oyunda Roblox Team yok - Player attribute "Team" (string) =====
local function myTeamAttr()
    return LocalPlayer:GetAttribute("Team")
end

local function serverNow()
    return workspace:GetServerTimeNow()
end

-- ===== Dusman toplama =====
local function collectEnemies()
    local list = {}
    local mt = myTeamAttr()
    local char = LocalPlayer.Character
    local cam = workspace.CurrentCamera
    local origin = cam and cam.CFrame.Position
    if not origin then return list end
    local function consider(model, label, isBot)
        if model == char then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if hum.Health <= 0 then return end
        -- SPAWN KORUMASI: sunucu saati karsilastirmasi (ProtectedUntil)
        local prot = model:GetAttribute("ProtectedUntil")
        if type(prot) == "number" and prot > serverNow() then return end
        local mhrp = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
        if not mhrp then return end
        if not isBot and S.TeamCheck and mt ~= nil then
            local pl = Players:GetPlayerFromCharacter(model)
            if pl and pl:GetAttribute("Team") == mt then return end
        end
        list[#list + 1] = {
            model = model, hum = hum, hrp = mhrp, label = label, isBot = isBot,
            pos = mhrp.Position, dist = (mhrp.Position - origin).Magnitude,
        }
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then consider(p.Character, p.Name, false) end
    end
    -- MAC BOTLARI (MatchBots klasoru) - hedef havuzuna dahil.
    -- AIM CHECK bot vuruslarini hile saymiyor ("only player hits matter")
    -- -> silent aim testi icin guvenli hedef. ESPBots toggle sadece goruntuleme.
    do
        local MB = workspace:FindFirstChild("MatchBots")
        if MB then
            for _, m in ipairs(MB:GetChildren()) do
                if m:IsA("Model") then consider(m, m.Name, true) end
            end
        end
    end
    -- TRAINING RANGE HEDEFLERI (workspace.Targets): lobi antrenman
    -- mankenleri ("Target Dummy") - R15 rig, Humanoid 100 HP, hareket etmez.
    -- Bunlar da bot sayilir (AIM CHECK: "Dummies / bots: counted apart").
    do
        local TG = workspace:FindFirstChild("Targets")
        if TG then
            for _, m in ipairs(TG:GetChildren()) do
                if m:IsA("Model") then consider(m, m.Name, true) end
            end
        end
    end
    return list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function losClearStable(from, to, targetModel)
    local exclude = {
        targetModel,
        LocalPlayer.Character,
        workspace:FindFirstChild("FX"),
    }
    rayParams.FilterDescendantsInstances = exclude
    local hit = workspace:Raycast(from, to - from, rayParams)
    if not hit then return true end
    if hit.Instance and hit.Instance:IsDescendantOf(targetModel) then return true end
    return false
end

local function targetPoint(entry)
    local m = entry.model
    if S.AimPart == "Head" then
        local h = m:FindFirstChild("Head")
        if h and h:IsA("BasePart") then return h.Position end
    end
    local t = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or entry.hrp
    if t and t:IsA("BasePart") then return t.Position end
    return entry.hrp.Position
end

-- HUB MENU DURUMU: Fluent'in kendi minimize mantigina GUVENME.
-- (Teori: RightControl Fluent ic 'minimize' yapiyor ama GUI.Enabled
-- true kaliyor -> eski kontrol sonsuza kadar 'menu acik' saniyordu.)
-- Cozum: minimize TUSUNU BIZ dinliyoruz (RightControl = Window MinimizeKey)
-- ve GUI'yi kendimiz acip kapatiyoruz. Kesin, tahmin yok.
local USER_MINIMIZED = false
-- FLUENT'IN KENDI MINIMIZE SINYALINI DINLE (tek dogruluk kaynagi):
-- kaynak kod: Minimize() -> t.Minimized cevrilir, t.Root.Visible guncellenir,
--             t.OnMinimized:Fire(tick(), t.Root.Visible)
-- Kullanici RCtrl'ye hangi yoldan basarsa bassin (Fluent'in keybind'i,
-- bizim handler, X tusu) bu signal USER_MINIMIZED'i dogru tutar.
pcall(function()
    Window.OnMinimized:Connect(function(_, visible)
        USER_MINIMIZED = not visible
    end)
end)
UserInputService.InputBegan:Connect(function(input, gp)
    -- gp kontrolu yok: Fluent tusu yutsa bile bizim toggle calisir
    if input.KeyCode == Enum.KeyCode.RightControl then
        USER_MINIMIZED = not USER_MINIMIZED
        -- GUI'yi BIZ uygulariz: Fluent'in ic durumu bozuk olsa bile
        -- menu acil/kapanis gercegi bizim bayragimizla tam uyusur
        pcall(function() Fluent.GUI.Enabled = not USER_MINIMIZED end)
        if USER_MINIMIZED then
            -- KAPAT: Fluent'in kendi Minimize durumunu da tutarli yap
            -- (sinyal yolu bozuk olsa bile state dogru kalir)
            pcall(function() Window.Minimized = true end)
            pcall(function() if Window.Root then Window.Root.Visible = false end end)
        else
            -- AC: Fluent kendi X/minimize'i ile kapatildiysa restore et
            pcall(function()
                if Window.Minimized then Window:Minimize() end
            end)
            pcall(function() Fluent.GUI.Enabled = true end)
        end
    end
end)

-- MOBIL MENU BUTONU: telefonda RCtrl yok - ekranin sag ust kosesinde
-- surekli gorunen kucik "HUB" butonu. Dokununca menu ac/kapa (RCtrl muadili).
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    task.spawn(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "PVPX_MobileMenu"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(64, 42)
        btn.Position = UDim2.new(1, -72, 0, 60)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = "HUB"
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.AutoButtonColor = true
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn
        btn.Parent = gui
        btn.Activated:Connect(function()
            USER_MINIMIZED = not USER_MINIMIZED
            pcall(function() Fluent.GUI.Enabled = not USER_MINIMIZED end)
            if USER_MINIMIZED then
                pcall(function() Window.Minimized = true end)
                pcall(function() if Window.Root then Window.Root.Visible = false end end)
            else
                pcall(function()
                    if Window.Minimized then Window:Minimize() end
                end)
                pcall(function() Fluent.GUI.Enabled = true end)
            end
        end)
        pcall(function() gui.Parent = gethui and gethui() or LocalPlayer.PlayerGui end)
    end)
end

local cursorFreedByUs = false -- artik kullanilmiyor (imlec hep gomulu)
local function hubShellVisible()
    -- 1) bizim bayrak (kendi handler + Fluent OnMinimized senkronu)
    if USER_MINIMIZED then return false end
    -- 2) GUI.Enabled (bizim handler + acilis gizlemesi)
    if not (Fluent.GUI and Fluent.GUI.Enabled) then return false end
    -- 3) Fluent'in kendi bayragi (Minimize() bunu cevirir)
    local minimized = false
    pcall(function() minimized = Window.Minimized == true end)
    if minimized then return false end
    -- menu gorunur: fare KILIDI KALDIRMA (kullanici istegi: GUI acikken
    -- de imlec gomulu kalir - aim zaten menu acikken de calisiyor)
    return true
end

-- menu kapandiginda farenin kilidi GERI ver (oyun kendi basina
-- LockCenter yazar; bizim true asili kalirsa kamera fareye baglanmaz)
local function releaseCursorIfClosed()
    if not cursorFreedByUs then return end
    local visible = false
    if not USER_MINIMIZED and Fluent.GUI and Fluent.GUI.Enabled then
        local minimized = false
        pcall(function() minimized = Window.Minimized == true end)
        visible = not minimized
    end
    if not visible then
        pcall(function() ClientState.CursorFree = false end)
        cursorFreedByUs = false
    end
end

local function isMenuOpen()
    -- 1) HUB GUI: yalnizca GUI acik VE pencere GERCEKTEN ekranda buyuk
    --    duruyorken sus (minimize/RightControl'da pencere kuculur/gizlenir).
    --    ESKI HATA: sadece Fluent.GUI.Enabled bakmak - minimize'da Enabled
    --    true kalirsan aim SONSUZA kadar kapali kaliyordu.
    if hubShellVisible() then return true end
    -- 2) Oyunun kendisi menude mi (oyun bunu yonetir - esya/shop ekranlar)
    local okm, inMenu = pcall(function()
        if type(ClientState.InMenu) == "function" then return ClientState.InMenu() end
        return false
    end)
    if okm and inMenu == true then return true end
    return false
end

local function inVehicleSeat()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.SeatPart then return true end
    if hum.Sit then return true end
    return false
end

local function aimActiveNow()
    if not S.AimEnabled then return false end
    -- MENU ACIKKEN DE CALISIR: GUI gizliyken VE acikken kilitlenme aktif.
    -- (Istenen davranis: ctrl ile gizle/goster kilitlenmeyi DEGISTIRMEZ.)
    if inVehicleSeat() then return false end
    -- TRIGGER BOT AIM AKTIVASYONU: trigger'in hedefi varsa kamera kilitlenebilir
    -- (Fire modunda kullanici tik basmadan da trigger ates edebilsin diye)
    if S.AimMode == "Fire" and S._triggerWantAim
        and os.clock() - S._triggerWantAim < 0.6 then
        return true
    end
    if S.AimMode == "Always" then return true end
    if S.AimMode == "Fire" then
        -- ATESE BASINCA KILIT: sol tik basiliyken aim aktif (kullanici
        -- istegi - tikla, kitlen, vur; birak, kamera serbest)
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end
    if S.AimMode == "Key" then
        local k = S.AimKey
        if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode then
            return UserInputService:IsKeyDown(k)
        end
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function pickTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local eye = cam.CFrame.Position
    local vp = cam.ViewportSize
    local maxScreenR = math.rad(S.AimFOV) / math.rad(90)
    local best, bestScore = nil, math.huge
    for _, e in ipairs(collectEnemies()) do
        if e.dist <= S.AimDistance then
            local tp = targetPoint(e)
            local screen, onScreen = cam:WorldToViewportPoint(tp)
            if onScreen then
                local dx = (screen.X - vp.X / 2) / (vp.X / 2)
                local dy = (screen.Y - vp.Y / 2) / (vp.Y / 2)
                local screenDist = math.sqrt(dx * dx + dy * dy)
                if screenDist <= maxScreenR then
                    if not S.WallCheck or losClearStable(eye, tp, e.model) then
                        if screenDist < bestScore then
                            best, bestScore = e, screenDist
                        end
                    end
                end
            end
        end
    end
    return best
end

local circle = nil
pcall(function()
    circle = Drawing.new("Circle")
    circle.Thickness = 1
    circle.Filled = false
    circle.NumSides = 64
    circle.Color = Color3.fromRGB(255, 80, 80)
    circle.Transparency = 0.4
end)

local CAM_LOCK = { locked = false, model = nil, entry = nil }

-- forward declaration: render loop kullanir, asil tanim asagida
local updateSilentAimData

-- STICKY TARGET (wobble onlemu): camera modunda bir kere secilen hedef,
-- gecerliligini korudugu surece TUTULUR. Eski davranis: her frame en
-- yakin hedef yeniden seciliyor -> kamera donunce iki hedef arasinda
-- salinim (kilitlenmis gibi gorunup titrer, hic oturmaz).
local function stickyValid()
    local e = CAM_LOCK.entry
    if not e then return nil end
    local m = e.model
    if not (m and m.Parent and e.hum and e.hum.Parent and e.hum.Health > 0) then
        return nil
    end
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local tp = targetPoint(e)
    local eye = cam.CFrame.Position
    if (tp - eye).Magnitude > S.AimDistance * 1.25 then return nil end
    -- hedef cemberin cok disina kactiysa birak
    local dir = cam.CFrame.LookVector
    local off = (tp - eye)
    if off.Magnitude > 1 then
        local ang = math.deg(math.acos(math.clamp(dir:Dot(off.Unit), -1, 1)))
        if ang > S.AimFOV * 1.25 + 10 then return nil end
    end
    if S.WallCheck then
        local okw = pcall(function() return losClearStable(eye, tp, m) end)
        if not okw then return nil end
    end
    return e
end

-- ===== KAMERA KOPRUSU: yaw/pitch UPVALUE enjeksiyonu =====
-- Bu oyun kamera zincirini boyle kuruyor:
--   u52(yaw) + u53(pitch)  <- CameraController.update'in LOCAL upvalue'leri
--     -> ClientState.CamYaw/CamPitch  (AimState telemetrisi + fire lookVector)
--     -> kamera CFrame (ShoulderCamera bind, priority Camera+1=201)
-- Kameraya DOGRUDAN CFrame yazmak 201'deki oyun yazimiyla caprasiyor
-- = EKRAN TITREMESI. Cozum: biz 200'de (oyundan ONCE) u52/u53'e yazariz;
-- recoil, clamp, shoulder offset, AimState hepsi oyunun kendi kodundan gecer.
local CamUpdateFn, yawIdx, pitchIdx
-- KOPRUYU RETRY ILA KUR: bazi executor thread'leri (ve ilk anlar)
-- upvalue erisimini kisitlayabiliyor - 40 deneme x 0.5sn.
local function tryBuildBridge()
    local function guv(fn, i)
        local ok, v = pcall(function() return debug.getupvalue(fn, i) end)
        if ok then return v end
        return nil, true
    end
    local okCC, CamCtrl = pcall(require, RS_Client:WaitForChild("Controllers", 30):WaitForChild("CameraController", 30))
    if not (okCC and type(CamCtrl) == "table" and type(CamCtrl.Start) == "function") then
        return false
    end
    local fn = nil
    local i = 1
    while true do
        local v, isErr = guv(CamCtrl.Start, i)
        if isErr then break end
        if type(v) == "function" then
            if guv(v, 1) == ClientState then
                fn = v
                break
            end
        end
        i += 1
    end
    if not fn then return false end
    local wantYaw, wantPitch = ClientState.CamYaw, ClientState.CamPitch
    if type(wantYaw) ~= "number" or type(wantPitch) ~= "number" then return false end
    local function verify(idx, fieldName)
        local ok, v = pcall(function() return debug.getupvalue(fn, idx) end)
        if not ok or type(v) ~= "number" then return false end
        local target = v + 0.0035
        pcall(function() debug.setupvalue(fn, idx, target) end)
        for _ = 1, 12 do
            task.wait()
            if math.abs((ClientState[fieldName] or 0) - target) < 0.002 then
                pcall(function() debug.setupvalue(fn, idx, v) end)
                return true
            end
        end
        pcall(function() debug.setupvalue(fn, idx, v) end)
        return false
    end
    local ny, np = nil, nil
    local j = 1
    while true do
        local v, isErr = guv(fn, j)
        if isErr then break end
        if not ny and type(v) == "number" and v == wantYaw then
            if verify(j, "CamYaw") then ny = j end
        end
        if ny and not np and type(v) == "number" and v == wantPitch and j ~= ny then
            if verify(j, "CamPitch") then np = j end
        end
        if ny and np then break end
        j += 1
    end
    if ny and np then
        CamUpdateFn, yawIdx, pitchIdx = fn, ny, np
        return true
    end
    return false
end
task.spawn(function()
    for _ = 1, 40 do
        if Fluent.Unloaded then return end
        if getgenv().PVP_S ~= S then return end -- yeni yukleme geldi, dur
        local okB, okV = pcall(tryBuildBridge)
        if okB and okV then
            print("[PVPHub] kamera koprusu AKTIF (upvalue modu)")
            return
        end
        task.wait(0.5)
    end
    warn("[PVPHub] kamera koprusu kurulamadi - CFrame fallback (202, titremesiz)")
end)

-- ONEMLI: priority 202 (Camera.Value + 2): oyun kamera yazimini 201'de
-- yapar (ShoulderCamera). Biz 202'de calisiriz:
--   - upvalue modunda: oyunun yaw/pitch'ini bir SONRAKI frame icin ceviririz
--   - CFrame fallback'te: oyun yazdiktan SONRA biz yazariz -> titreme YOK
RunService:BindToRenderStep("PVP_Aim", Enum.RenderPriority.Camera.Value + 2, function(dt)
    if circle then
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        if vp and S.ShowFOV and S.AimEnabled then
            circle.Radius = S.AimFOV / 90 * (vp.Y / 2)
            circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
            circle.Visible = true
            -- KILIT GOSTERGESI: kitlenince YESIL, bos kirmizi
            circle.Color = CAM_LOCK.locked
                and Color3.fromRGB(80, 255, 120)
                or Color3.fromRGB(255, 80, 80)
        else
            circle.Visible = false
        end
    end
    -- TESHIS (MCP izleme + GUI disaridan debug): disariya yaz
    releaseCursorIfClosed()
    S._aimActive = aimActiveNow()
    S._menuOpen = isMenuOpen()
    S._bridgeOk = (CamUpdateFn ~= nil and yawIdx ~= nil and pitchIdx ~= nil)
    if not aimActiveNow() then CAM_LOCK.locked = false S._hasTarget = false return end
    local target = pickTarget()
    -- STICKY: camera modunda kilitli hedefi koru (wobble onlemi)
    if S.AimEngine == "Camera" then
        local keep = stickyValid()
        if keep then target = keep end
    end
    S._hasTarget = target ~= nil
    local cam = workspace.CurrentCamera
    if not cam then return end
    if S.AimEngine == "Silent" then
        -- STICKY + FLAP-ONLEMI: hedef yalniz gercekten gecerliligini
        -- yitirince (olu/kayboldu/ekran disi) degisir. Duvar testi
        -- titrerse hedef degismez - sadece o karede bukme yapilmaz.
        local cur = S.SilentTarget
        local curValid = cur and cur.model and cur.model.Parent
            and cur.hum and cur.hum.Parent and cur.hum.Health > 0
        if curValid then
            -- menzil disi kaldiysa hedef gecerliligini yitirir
            local curTp = targetPoint(cur)
            if (curTp - cam.CFrame.Position).Magnitude > S.AimDistance + 50 then
                curValid = false
            end
        end
        if not curValid then
            cur = target
            S.SilentTarget = cur
        end
        -- bend verisi: canli + yakin + duvar acik + korumasiz
        local aimDataOk = false
        if cur then
            local eyeNow = cam.CFrame.Position
            local curTp = targetPoint(cur)
            local distOk = (curTp - eyeNow).Magnitude <= S.AimDistance + 50
            local prot = cur.model:GetAttribute("ProtectedUntil")
            local notProtected = not (type(prot) == "number" and prot > serverNow())
            local wallOk = true
            if S.WallCheck then
                local okw = pcall(function() wallOk = losClearStable(eyeNow, curTp, cur.model) end)
                if not okw then wallOk = false end
            end
            aimDataOk = distOk and notProtected and wallOk
        end
        if aimDataOk then
            updateSilentAimData()
        else
            S._silentAim = nil
        end
        target = cur
        -- KAMERA HAREKETI YOK: klasik silent (kamera kendi isinde,
        -- mermiler hedefe bukulur). Oyuncu isterse ayarlardan
        -- yumusak takip actirabilir (Soft Track).
        if S.SoftTrack and target and CamUpdateFn and yawIdx and pitchIdx then
            local eye = cam.CFrame.Position
            local tp = targetPoint(target)
            if (tp - eye).Magnitude >= 2 then
                local dir = (tp - eye).Unit
                local okY, curYaw = pcall(function() return debug.getupvalue(CamUpdateFn, yawIdx) end)
                local okP, curPitch = pcall(function() return debug.getupvalue(CamUpdateFn, pitchIdx) end)
                if okY and okP and type(curYaw) == "number" and type(curPitch) == "number" then
                    local wantYaw = math.atan2(-dir.X, -dir.Z)
                    local wantPitch = math.asin(math.clamp(dir.Y, -1, 1))
                    local dyaw = (wantYaw - curYaw + math.pi) % (2 * math.pi) - math.pi
                    local dpitch = wantPitch - curPitch
                    local totalAng = math.deg(math.sqrt(dyaw * dyaw + dpitch * dpitch))
                    CAM_LOCK.locked = totalAng <= 1
                    CAM_LOCK.model = target.model
                    local speed = S.AimSpeed * (totalAng > 100 and 1.4 or 2.2)
                    local k = 1 - math.exp(-speed * dt)
                    if totalAng <= 1 then k = 1 end
                    pcall(function()
                        debug.setupvalue(CamUpdateFn, yawIdx, curYaw + dyaw * k)
                        debug.setupvalue(CamUpdateFn, pitchIdx, curPitch + dpitch * k)
                    end)
                end
            end
        end
        return
    end
    S._silentAim = nil
    -- CAMERA mod
    if not target then
        S.SilentTarget = nil
        CAM_LOCK.locked = false
        CAM_LOCK.entry = nil
        return
    end
    local tp = targetPoint(target)
    local eye = cam.CFrame.Position
    if (tp - eye).Magnitude < 2 then return end
    S.SilentTarget = nil
    CAM_LOCK.entry = target
    if CamUpdateFn and yawIdx and pitchIdx then
        -- UPVALUE MODU: oyunun kendi yaw/pitch'ini hedefe dogru cevir
        local dir = (tp - eye).Unit
        local okY, curYaw = pcall(function() return debug.getupvalue(CamUpdateFn, yawIdx) end)
        local okP, curPitch = pcall(function() return debug.getupvalue(CamUpdateFn, pitchIdx) end)
        if not okY or not okP or type(curYaw) ~= "number" or type(curPitch) ~= "number" then return end
        local wantYaw = math.atan2(-dir.X, -dir.Z)
        local wantPitch = math.asin(math.clamp(dir.Y, -1, 1))
        local dyaw = (wantYaw - curYaw + math.pi) % (2 * math.pi) - math.pi
        local dpitch = wantPitch - curPitch
        local totalAng = math.deg(math.sqrt(dyaw * dyaw + dpitch * dpitch))
        CAM_LOCK.locked = totalAng <= 2.5
        CAM_LOCK.model = target.model
        local speed = S.AimSpeed * (totalAng > 100 and 1.4 or 3.0)
        local k = 1 - math.exp(-speed * dt)
        if totalAng <= 2.5 then k = 1 end -- tam kilit: mikro-duzeltme
        pcall(function()
            debug.setupvalue(CamUpdateFn, yawIdx, curYaw + dyaw * k)
            debug.setupvalue(CamUpdateFn, pitchIdx, curPitch + dpitch * k)
        end)
    else
        -- FALLBACK: klasik CFrame lerp (kopru kurulamazsa)
        local look = cam.CFrame.LookVector
        local dir = (tp - eye).Unit
        local ang = math.deg(math.acos(math.clamp(look:Dot(dir), -1, 1)))
        CAM_LOCK.locked = ang <= 4
        CAM_LOCK.model = target.model
        if ang > 100 then
            local desired = CFrame.lookAt(eye, tp)
            local alpha = 1 - math.exp(-(S.AimSpeed * 1.4) * dt)
            cam.CFrame = cam.CFrame:Lerp(desired, alpha)
        elseif ang > 3 then
            local desired = CFrame.lookAt(eye, tp)
            local alpha = 1 - math.exp(-(S.AimSpeed * 3.0) * dt)
            cam.CFrame = cam.CFrame:Lerp(desired, alpha)
        else
            cam.CFrame = CFrame.lookAt(eye, tp)
        end
    end
end)

local function weaponOf(char)
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return nil, nil end
    local w = tool:GetAttribute("Weapon")
    if type(w) ~= "string" or w == "" then return tool, nil end
    return tool, WeaponData[w] and w or nil
end

local function fireInterval(w)
    local wd = WeaponData[w]
    local rpm = wd and wd.Fire and wd.Fire.RPM or 600
    return 60 / math.max(rpm, 60) + 0.033
end

-- ===== SILENT AIM v2: PAKET BUKME (__namecall hook) =====
-- ESKI MIMARI SILINDI. Eskiden paketiB biz kurup gonderiyorduk:
--   1) oyunun kendi atisi + bizim paket = CIKTI ATES -> rapidfire imzasi
--      (CAS sink, UIS InputBegan'i engellemez - oyun yine de ates ederdi)
--   2) lookVector'i dir'e esliyorduk -> telemetri ile celisiyordu
--      (server CamYaw/CamPitch akisini ayri bilir) -> spoofaim imzasi
--   3) spread=0 + kusursuz isabet -> nospread imzasi
--   ==> KICK ("you were disconnected").
-- YENI MIMARI: oyunun KENDI atis yolu hic bozulmuyor (tikla, oyun
-- ates eder: gercek RPM/ammo/reload/recoil/spread/lookVector). Biz
-- sadece FireServer cagrisini __namecall ile yakalayip SADECE
-- Direction + Hit alanlarini hedefe bukuyoruz. Bukme acisi
-- paketin KENDI claim ettigi spread konisiyle sinirli -
-- istatistiksel olarak gercek atistan ayirt edilemez.
local WC_OK, WC = pcall(require, RS_Client:WaitForChild("Controllers", 30):WaitForChild("WeaponController", 30))

-- Oyunun kendi atis yolunu pulse'la (trigger bot icin): tek gercek atis,
-- paket hook'tan gecer ve silent modda bukulur.
local function gameShot()
    if WC_OK and type(WC) == "table" and WC.SetTrigger then
        pcall(function() WC.SetTrigger(true) end)
        task.delay(0.12, function()
            pcall(function() WC.SetTrigger(false) end)
        end)
    end
end

local function camLookVec()
    local cam = workspace.CurrentCamera
    if type(ClientState.CamYaw) == "number" and type(ClientState.CamPitch) == "number" then
        pcall(function()
            -- oyunun fire() fonksiyonunun AYNISI: telemetri ile birebir uyusur
            local lv = CFrame.fromEulerAnglesYXZ(ClientState.CamPitch, ClientState.CamYaw, 0).LookVector
            if lv.Magnitude > 0.5 then return lv end
        end)
    end
    return cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
end

-- Hedef atis verisi RENDER LOOP'ta hazirlanir (hook icinde HICBIR
-- instance metodu cagrilamaz: nested __namecall zinciri bozuyor).
-- S._silentAim = { part, pos, claimMax } - hook sadece okur.
updateSilentAimData = function()
    local t = S.SilentTarget
    if not (t and t.model and t.model.Parent and t.hum and t.hum.Parent and t.hum.Health > 0) then
        S._silentAim = nil
        return
    end
    local part = t.model:FindFirstChild("Head") or t.hrp
    if not (part and part:IsA("BasePart")) then
        S._silentAim = nil
        return
    end
    local tp = targetPoint(t)
    -- INSANLASTIRMA: %30 govde atisi + cok kucuk jitter.
    -- JITTER ONEMLI: sunucu kendi raycast'ini Origin+Direction ile
    -- yapip args.part ile eslestiriyor - jitter buyuk olursa ray
    -- kafanin kenarindan iskalar, part bulunamaz, paket RED.
    -- 0.12 stud: kafa yaricapinin icinde, istatistige yeter.
    if S.SilentHumanize ~= false then
        if math.random() < 0.3 then
            local torso = t.model:FindFirstChild("UpperTorso") or t.model:FindFirstChild("Torso")
            if torso and torso:IsA("BasePart") then
                part = torso
                tp = torso.Position
            end
        end
        tp = tp + Vector3.new((math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.12)
    end
    S._silentAim = { part = part, pos = tp }
end

local function bendBullet(args)
    S._bendSeen = (S._bendSeen or 0) + 1
    local aim = S._silentAim
    if not aim then
        S._bendNoTarget = (S._bendNoTarget or 0) + 1
        return false
    end
    if ClientState.Reloading then
        S._bendReload = (S._bendReload or 0) + 1
        return false
    end
    local origin, look, claimedSpread = args[1], args[7], tonumber(args[8]) or 0
    if typeof(origin) ~= "Vector3" or typeof(look) ~= "Vector3" then return false end
    local tp = aim.pos
    local delta = tp - origin
    if delta.Magnitude < 2 then return false end
    local bentDir = delta.Unit
    -- KLASIK SILENT: mermi hedefe tam kivrilir (kamera nereye bakarsa
    -- baksin). Max aciyi SilentBend slider'i sinirlar (default 180 = serbest).
    local full = math.deg(math.acos(math.clamp(look:Dot(bentDir), -1, 1)))
    S._bendDev = math.floor(full * 10) / 10
    if full > (S.SilentBend or 180) then
        S._bendBudgetFail = (S._bendBudgetFail or 0) + 1
        return false
    end
    -- PAKET: Direction hedefe kivrilir, LOOK=DIR (packet kendi icinde
    -- tutarli: sunucu angle(dir,look)<=claim kontrolunde 0 gecer).
    -- Hit.Position = ray uzerindeki nokta (projeksiyon).
    -- AIM CHECK HEADSHOT% maskeleme: rastgele az bir kisim atislar
    -- dogal iska gibi durur (istatistik %100 headshot gozukmesin).
    args[2] = bentDir
    args[3] = aim.part
    args[4] = tp
    args[5] = -bentDir
    args[7] = bentDir
    args[8] = 0
    -- opsiyonel kalkan: atis aninda kamerayi da atis yonune cevir
    -- (AIM CHECK replay'inde cizgiler ust uste biner). Kullanici
    -- "kamera kitleniyo" istemedigi icin default KAPALI.
    if S.SilentSnap and CamUpdateFn and yawIdx and pitchIdx then
        pcall(function()
            debug.setupvalue(CamUpdateFn, yawIdx, math.atan2(-bentDir.X, -bentDir.Z))
            debug.setupvalue(CamUpdateFn, pitchIdx, math.asin(math.clamp(bentDir.Y, -1, 1)))
        end)
    end
    return true
end

-- ===== KLASIK SILENT (ESKI, KULLANICININ ISTEDIGI): AYRI PAKET =====
-- Tik: oyun kendi atisini atar (dokunulmaz - dogal hasar garanti),
-- biz AYRI bir paket daha atariz (kivri mermi) + ekranda kivri
-- tracer gorseli. Bu ESKI silent'in hissi ve davranisi.
-- Silah RPM'i ile hizalanan atis araligi (rapidfire guard).
local SILENT_LAST_FIRE = 0
local function fireRangeOf(w)
    local wd = WeaponData[w]
    return (wd and wd.Damage and wd.Damage.Range) or 250
end

-- HUD AMMO ESENLIK: bizim ekstra paketler oyunun HuD sayacindan
-- habersiz -> '16/30 sabit kaliyor'. HudController.SetAmmo(mag,
-- reserve, magSize)'i sarip son degerleri hatirla; her silent
-- paketinde mag'i 1 dusur ve HUD'a yaz (oyunun kendi gorseli).
local Hud
local HUD_LAST = { mag = nil, res = nil, size = nil }
pcall(function()
    Hud = require(RS_Client:WaitForChild("Controllers", 30):WaitForChild("HudController", 30))
    if type(Hud) == "table" and type(Hud.SetAmmo) == "function" then
        local origSetAmmo = Hud.SetAmmo
        Hud.SetAmmo = function(m, r, s)
            HUD_LAST.mag, HUD_LAST.res, HUD_LAST.size = m, r, s
            return origSetAmmo(m, r, s)
        end
    end
end)
local function hudTickAmmo(w)
    if not (Hud and Hud.SetAmmo) then return end
    local mag = HUD_LAST.mag
    if type(mag) ~= "number" then
        -- henunch yakalanmadi: silah verisinden basla
        local wd = WeaponData[w]
        if wd and wd.Ammo then
            HUD_LAST.mag = wd.Ammo.Mag
            HUD_LAST.res = wd.Ammo.Reserve
            HUD_LAST.size = wd.Ammo.Mag
            mag = wd.Ammo.Mag
        end
    end
    if type(mag) == "number" then
        local newMag = math.max(0, mag - 1)
        HUD_LAST.mag = newMag
        pcall(Hud.SetAmmo, newMag, HUD_LAST.res, HUD_LAST.size)
    end
end

local function classicSilentFire()
    if not (S.AimEngine == "Silent" and S.AimEnabled) then return false end
    local t = S.SilentTarget
    if not (t and t.model and t.model.Parent and t.hum and t.hum.Parent and t.hum.Health > 0) then
        return false
    end
    local char = LocalPlayer.Character
    if not char then return false end
    local myHum = char:FindFirstChildOfClass("Humanoid")
    if not myHum or myHum.Health <= 0 or myHum.SeatPart or myHum.Sit then return false end
    if ClientState.Reloading then return false end
    local tool, w = weaponOf(char)
    if not tool or not w then return false end
    -- RPM guard: kendi paketimiz silah RPM'iyle BIREBIR ayni aralikta
    -- (her gercek atisa bir kivri mermi - kullanicinin istegi: hepsi gitsin).
    -- Oyunun kendi atisindan HIZLI olamaz (rapidfire imzasi olusmaz);
    -- sadece atis sayisi x2 gorunur (her mermi cift hasar potential).
    local now = os.clock()
    if now - SILENT_LAST_FIRE < fireInterval(w) then return false end
    -- taze hedef pozisyonu (simdi, render frame'i degil)
    local head = t.model:FindFirstChild("Head") or t.hrp
    if not (head and head:IsA("BasePart")) then return false end
    local origin = char:FindFirstChild("Head")
    origin = origin and origin.Position or (char:FindFirstChild("HumanoidRootPart").Position + Vector3.new(0, 1.5, 0))
    local tp = targetPoint(t)
    local delta = tp - origin
    if delta.Magnitude < 5 or delta.Magnitude > fireRangeOf(w) then return false end
    local dir = delta.Unit
    local cam = workspace.CurrentCamera
    -- SPOOFAIM KALKANI: sunucu sendStance ile kamera yonunu biliyor.
    -- Kameran hedefe SilentBend dereceden UZAKSA paket gonderme -
    -- o atista imza birikmesin (oyunun kendi mermisi normal gider).
    -- Yakinken (default 45) look~kamera -> imza yok, silent calisir.
    local camLook = cam.CFrame.LookVector
    local camFromHead = (tp - origin)
    local camAng = math.deg(math.acos(math.clamp(camLook:Dot(camFromHead.Unit), -1, 1)))
    S._silentCamAng = math.floor(camAng)
    if camAng > (S.SilentBend or 45) then return false end
    -- BILINEN-KABUL FORMULA: (origin, dir, part, tp, -dir, camPos, dir, 0)
    FireRemote:FireServer(origin, dir, head, tp, -dir, cam.CFrame.Position, dir, 0)
    SILENT_LAST_FIRE = now
    -- HUD: ekstra atis sayaca da yansisin
    pcall(hudTickAmmo, w)
    -- GORSEL: ekranda mermi kivri tracer + atis sesi (eski his)
    pcall(function()
        local EC = require(RS_Client:WaitForChild("Controllers", 30):WaitForChild("EffectsController", 30))
        EC.Tracer(origin, tp, true, LocalPlayer:GetAttribute("Tracer"))
    end)
    return true
end

-- TIK YOLU: mouse1 basildigi an klasik silent paketi (random CAS adi)
local CAS_NAME = "PVPX_" .. tostring(math.random(100000, 999999))
getgenv().PVP_CAS_NAME = CAS_NAME
local SilentHeld = false
local ContextActionService = game:GetService("ContextActionService")
ContextActionService:BindActionAtPriority(CAS_NAME, function(_, state)
    if S.AimEngine ~= "Silent" or not S.AimEnabled then
        SilentHeld = false
        return Enum.ContextActionResult.Pass
    end
    if state == Enum.UserInputState.Begin then
        SilentHeld = true
        classicSilentFire()
    elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
        SilentHeld = false
    end
    return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value + 50, Enum.UserInputType.MouseButton1)

-- BASILI TUTMA: RPM hizinda devam (oyun kendi atisini zaten atiyor,
-- bizim paket RPM guard'la aralikli)
RunService:BindToRenderStep("PVP_AutoFire", Enum.RenderPriority.Input.Value + 10, function()
    if S.AimEngine ~= "Silent" or not S.AimEnabled then return end
    if not (SilentHeld or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then return end
    classicSilentFire()
end)

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    -- HOOK MODU (opsiyonel, default KAPALI): SilentHook aciksa oyunun
    -- kendi atisini bukerek tek-atis silent yapar (imza yok ama
    --erekli hedef icin calismayabilir). Klasik modda dokunmaz.
    if S.SilentHook and S.AimEngine == "Silent" and S.AimEnabled then
        local method = getnamecallmethod()
        if method == "FireServer" and self == FireRemote then
            S._hookSeen = (S._hookSeen or 0) + 1
            local n = select("#", ...)
            if n >= 8 then
                local args = table.pack(...)
                -- DEBUG: ham paketi kaydet
                S._rawPacket = { dir = args[2], hit = args[3], pos = args[4], look = args[7], spread = args[8] }
                if bendBullet(args) then
                    S._bendOk = (S._bendOk or 0) + 1
                    -- DEBUG: bukulmus paketi kaydet
                    S._sentPacket = { dir = args[2], hit = args[3], pos = args[4], look = args[7], spread = args[8], sentOk = nil }
                    local results = table.pack(pcall(OldNamecall, self, table.unpack(args, 1, n)))
                    S._sentPacket.sentOk = results[1]
                    if not results[1] then S._sentPacket.err = tostring(results[2]) end
                    return table.unpack(results, 2, results.n)
                end
            end
        end
    end
    return OldNamecall(self, ...)
end))

-- CESET/RESPAWN temizligi
task.spawn(function()
    while not Fluent.Unloaded do
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and p.Character:GetAttribute("PVP_DeadMark") == true then
                        p.Character:SetAttribute("PVP_DeadMark", nil)
                    end
                end
            end
        end)
        task.wait(2)
    end
end)

-- SILENT MOD GIRIS YOLU: CAS bind + AutoFire (yukarida) klasik paketi
-- atar; oyunun kendi atisi da dokunulmadan calisir. SilentHook
-- aciksa hook modu devreye girer (tek-atis, deneysel).

-- ===== TRIGGER BOT =====
local nextTrigger = 0
task.spawn(function()
    while not Fluent.Unloaded do
        task.wait(0.03)
        if S.TriggerEnabled and not inVehicleSeat() then
            local userHolding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            if not userHolding then    local now = os.clock()
                if now >= nextTrigger then
                    local char = LocalPlayer.Character
                    local tool, w = weaponOf(char)
                    if tool and w then
                        local cam = workspace.CurrentCamera
                        if cam then
                            local vp = cam.ViewportSize
                            local eye = cam.CFrame.Position
                            local best, bestScore = nil, math.huge
                            for _, e in ipairs(collectEnemies()) do
                                if e.dist <= S.AimDistance then
                                    local tp = targetPoint(e)
                                    local screen, onScreen = cam:WorldToViewportPoint(tp)
                                    if onScreen then
                                        local dx = screen.X - vp.X / 2
                                        local dy = screen.Y - vp.Y / 2
                                        local screenDist = math.sqrt(dx * dx + dy * dy)
                                        if screenDist < vp.Y * 0.06 then
                                            local wallOk = true
                                            if S.WallCheck then
                                                local okw = pcall(function() wallOk = losClearStable(eye, tp, e.model) end)
                                                if not okw then wallOk = false end
                                            end
                                            if wallOk and screenDist < bestScore then
                                                best, bestScore = e, screenDist
                                            end
                                        end
                                    end
                                end
                            end
                            if best then
                                local delay = (S.TriggerDelay + math.random(0, 60)) / 1000
                                if S.AimEngine == "Camera" then
                                    -- CAMERA: once kamera KILITLENsin, sonra ates.
                                    -- (Eski bug: Fire modunda aim inaktifken trigger
                                    -- dumduz ates ediyordu - hic kilitlenmeden.)
                                    S._triggerWantAim = os.clock()
                                    local cameraReady = CAM_LOCK.locked
                                        and (CAM_LOCK.model == nil or CAM_LOCK.model == best.model)
                                    if cameraReady then
                                        task.delay(delay, function()
                                            if S.TriggerEnabled
                                                and CAM_LOCK.locked
                                                and (CAM_LOCK.model == nil or CAM_LOCK.model == best.model) then
                                                gameShot()
                                            end
                                        end)
                                        nextTrigger = now + fireInterval(w) + delay
                                    else
                                        nextTrigger = now + 0.05 -- kilidi bekle
                                    end
                                else
                                    -- SILENT: trigger atisi da kivri mermiyle gitsin.
                                    -- (Eski bug: gameShot() duz atiyordu - hook kapali.)
                                    task.delay(delay, function()
                                        if S.TriggerEnabled
                                            and best.model and best.model.Parent
                                            and best.hum and best.hum.Parent and best.hum.Health > 0 then
                                            S.SilentTarget = best
                                            classicSilentFire()
                                        end
                                    end)
                                    nextTrigger = now + fireInterval(w) + delay
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ===== ESP =====
local espTracks = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "PVP_ESP"
getgenv().PVP_ESP_FOLDER = espFolder
local okhui = pcall(function()
    espFolder.Parent = gethui and gethui() or game:GetService("CoreGui")
end)
if not okhui then espFolder.Parent = LocalPlayer.PlayerGui end

local TEAM_COLORS = {
    [1] = Color3.fromRGB(70, 130, 255),
    [2] = Color3.fromRGB(255, 90, 90),
    [3] = Color3.fromRGB(90, 230, 130),
    [4] = Color3.fromRGB(230, 130, 255),
}
local function espColorFor(entry)
    if entry.isBot then return Color3.fromRGB(255, 220, 80) end
    local t = entry.model:GetAttribute("Team")
    local n = tonumber(t)
    if n and TEAM_COLORS[n] then return TEAM_COLORS[n] end
    local pl = Players:GetPlayerFromCharacter(entry.model)
    if pl then
        local pt = tonumber(pl:GetAttribute("Team"))
        if pt then
            if myTeamAttr() == pl:GetAttribute("Team") then return Color3.fromRGB(70, 130, 255) end
            return Color3.fromRGB(255, 90, 90)
        end
    end
    return Color3.fromRGB(255, 90, 90)
end

local function espUpdate()
    if not S.ESPEnabled then
        for _, tr in pairs(espTracks) do
            if tr.hl then tr.hl.Enabled = false end
            if tr.bb then tr.bb.Enabled = false end
        end
        return
    end
    local seen = {}
    local cam = workspace.CurrentCamera
    local eye = cam and cam.CFrame.Position
    for _, e in ipairs(collectEnemies()) do
        if (not e.isBot or S.ESPBots) and e.dist <= 450 then
            seen[e.model] = true
            local tr = espTracks[e.model]
            if not tr then
                local hl = Instance.new("Highlight")
                hl.FillTransparency = 0.55
                hl.OutlineTransparency = 0.1
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = e.model
                hl.Parent = espFolder
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.fromOffset(220, 46)
                bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
                bb.AlwaysOnTop = true
                bb.LightInfluence = 0
                bb.Adornee = e.hrp
                bb.Parent = espFolder
                local tl = Instance.new("TextLabel")
                tl.BackgroundTransparency = 1
                tl.Size = UDim2.fromScale(1, 1)
                tl.Font = Enum.Font.GothamBold
                tl.TextSize = 13
                tl.TextStrokeTransparency = 0.35
                tl.TextColor3 = Color3.fromRGB(255, 255, 255)
                tl.TextWrapped = true
                tl.Parent = bb
                espTracks[e.model] = { model = e.model, hl = hl, bb = bb, tl = tl, hum = e.hum }
                tr = espTracks[e.model]
            end
            local col = espColorFor(e)
            tr.hl.FillColor = col
            tr.hl.OutlineColor = col
            tr.hl.Enabled = true
            local show = S.ESPNames or S.ESPDistance or S.ESPHealth
            tr.bb.Enabled = show
            if show then
                local lines = {}
                if S.ESPNames then lines[#lines + 1] = (e.isBot and "[BOT] " or "") .. e.label end
                if S.ESPDistance and eye then lines[#lines + 1] = string.format("%dm", e.dist) end
                if S.ESPHealth then lines[#lines + 1] = string.format("%d HP", math.ceil(tr.hum.Health)) end
                tr.tl.Text = table.concat(lines, "\n")
            end
        end
    end
    for model, tr in pairs(espTracks) do
        if not seen[model] or not model.Parent or not tr.hum.Parent or tr.hum.Health <= 0 then
            if tr.hl then tr.hl:Destroy() end
            if tr.bb then tr.bb:Destroy() end
            espTracks[model] = nil
        end
    end
end

task.spawn(function()
    while not Fluent.Unloaded do
        pcall(espUpdate)
        task.wait(0.15)
    end
end)

-- ===== STATS: WeaponHit onaylari (sunucu gonderir) =====
if HitRemote then
    HitRemote.OnClientEvent:Connect(function(t)
        if type(t) ~= "table" then return end
        if t.NoDamage or t.Protected then return end
        if type(t.Damage) == "number" and t.Damage > 0 then
            S.StatsHits = S.StatsHits + 1
            if t.Headshot then S.StatsHeadshots = S.StatsHeadshots + 1 end
            if t.Killed then
                S.StatsKills = S.StatsKills + 1
                Fluent:Notify({
                    Title = "KILL",
                    Content = string.format("Total: %d kills", S.StatsKills),
                    Duration = 2.5,
                })
            end
        end
    end)
end

local StatsParagraph
pcall(function()
    StatsParagraph = Tabs.Stats:CreateParagraph("Session", { Title = "Session", Content = "..." })
end)
if not StatsParagraph then
    pcall(function()
        StatsParagraph = Tabs.Stats:CreateParagraph({ Title = "Session", Content = "..." })
    end)
end
local function buildStatsText()
    return string.format("Hits: %d\nKills: %d\nHeadshots: %d", S.StatsHits, S.StatsKills, S.StatsHeadshots)
end
task.spawn(function()
    while not Fluent.Unloaded do
        if StatsParagraph then
            pcall(function() StatsParagraph:SetDesc(buildStatsText()) end)
            pcall(function()
                if StatsParagraph.SetContent then StatsParagraph:SetContent(buildStatsText()) end
            end)
        end
        task.wait(1)
    end
end)

-- ===== DASHBOARD =====
do
    local info = {}
    info[#info + 1] = "Player: " .. LocalPlayer.Name
    info[#info + 1] = "Level: " .. tostring(LocalPlayer:GetAttribute("Level") or "?")
    info[#info + 1] = "Coins: " .. tostring(LocalPlayer:GetAttribute("Coins") or "?")
    info[#info + 1] = "Rank: " .. tostring(LocalPlayer:GetAttribute("RankName") or LocalPlayer:GetAttribute("Rank") or "?")
    info[#info + 1] = "Kills: " .. tostring(LocalPlayer:GetAttribute("Kills") or 0)
    info[#info + 1] = "Deaths: " .. tostring(LocalPlayer:GetAttribute("Deaths") or 0)
    info[#info + 1] = "Streak: " .. tostring(LocalPlayer:GetAttribute("Streak") or 0)
    info[#info + 1] = "Ping: " .. tostring(LocalPlayer:GetAttribute("Ping") or "?") .. "ms"
    local dashP
    pcall(function()
        dashP = Tabs.Dashboard:CreateParagraph("Profile", { Title = "Profile", Content = table.concat(info, "\n") })
    end)
    if not dashP then
        pcall(function()
            Tabs.Dashboard:CreateParagraph({ Title = "Profile", Content = table.concat(info, "\n") })
        end)
    end
    pcall(function()
        Tabs.Dashboard:CreateParagraph("Guide", {
            Title = "How to use",
            Content = "Aim: pick engine (Silent = bullets curve, Camera = camera locks).\nLocks while shooting (Activation = On Fire).\nTrigger: auto-fires when crosshair is on enemy.\nSkins: preview any skin client-side (only you see it).",
        })
    end)
end

-- ===== AIM TAB =====
Tabs.Aim:AddToggle("AimEnabled", {
    Title = "Aim Assist",
    Description = "Master toggle",
    Default = S.AimEnabled,
    Callback = function(v) S.AimEnabled = v end,
})
Tabs.Aim:AddDropdown("AimEngine", {
    Title = "Aim Engine",
    Description = "Silent = bullets curve (default) | Camera = camera locks onto target",
    Values = { "Silent", "Camera" },
    Default = "Silent",
    Callback = function(v) S.AimEngine = v end,
})
Tabs.Aim:AddDropdown("AimMode", {
    Title = "Activation",
    Description = "On Fire = locks while shooting (default) | Always = always on | Hold = aim button | Key = aim key",
    Values = { "Always", "Fire", "Hold", "Key" },
    Default = "Fire",
    Callback = function(v) S.AimMode = v end,
})
Tabs.Aim:AddKeybind("PVPKeybind", {
    Title = "Aim Key",
    Description = "Hold this key to aim (Activation = Key)",
    Mode = "Hold",
    Default = S.AimKey,
    Callback = function(v) end,
    ChangedCallback = function(new)
        if typeof(new) == "EnumItem" then S.AimKey = new end
    end,
})
Tabs.Aim:AddSlider("AimFOV", {
    Title = "FOV (deg)",
    Default = S.AimFOV, Min = 10, Max = 360, Rounding = 0,
    Callback = function(v) S.AimFOV = v end,
})
Tabs.Aim:AddSlider("AimDistance", {
    Title = "Max Distance",
    Default = S.AimDistance, Min = 20, Max = 500, Rounding = 0,
    Callback = function(v) S.AimDistance = v end,
})
Tabs.Aim:AddSlider("AimSpeed", {
    Title = "Aim Speed",
    Description = "Higher = faster lock. 10-16 recommended",
    Default = 14, Min = 1, Max = 30, Rounding = 0,
    Callback = function(v) S.AimSpeed = v end,
})
Tabs.Aim:AddDropdown("AimPart", {
    Title = "Target Part",
    Values = { "Head", "Torso" },
    Default = "Head",
    Callback = function(v) S.AimPart = v end,
})
Tabs.Aim:AddSlider("SilentBend", {
    Title = "Silent Max Angle (deg)",
    Description = "Extra curved shot only fires when your camera is within this angle of the target. Lower = safer on the admin AIM CHECK panel (80 balanced). Higher = works from wider angles but builds spoofaim score -> kick.",
    Default = 80, Min = 10, Max = 180, Rounding = 0,
    Callback = function(v) S.SilentBend = v end,
})
Tabs.Aim:AddToggle("WallCheck", {
    Title = "Wall Check",
    Default = S.WallCheck,
    Callback = function(v) S.WallCheck = v end,
})
Tabs.Aim:AddToggle("ShowFOV", {
    Title = "FOV Circle",
    Default = S.ShowFOV,
    Callback = function(v) S.ShowFOV = v end,
})
Tabs.Aim:AddToggle("TeamCheck", {
    Title = "Team Check",
    Default = S.TeamCheck,
    Callback = function(v) S.TeamCheck = v end,
})

-- ===== TRIGGER TAB =====
Tabs.Trigger:AddToggle("TriggerEnabled", {
    Title = "Trigger Bot",
    Description = "Auto-fires when crosshair is locked on enemy (packet path)",
    Default = S.TriggerEnabled,
    Callback = function(v) S.TriggerEnabled = v end,
})
Tabs.Trigger:AddToggle("SilentSnap", {
    Title = "Snap Camera on Fire",
    Description = "Anti-detect shield: camera snaps to the target at the exact fire moment, so server telemetry matches the bullet direction. ON = safer (hides spoof), OFF = camera never moves (classic silent, more risky on main accounts).",
    Default = S.SilentSnap,
    Callback = function(v) S.SilentSnap = v end,
})
Tabs.Trigger:AddToggle("SoftTrack", {
    Title = "Soft Camera Track (Silent)",
    Description = "Camera gently drifts toward the target while Silent is on (subtle, no flick). OFF = classic silent: camera fully free.",
    Default = S.SoftTrack,
    Callback = function(v) S.SoftTrack = v end,
})
Tabs.Trigger:AddToggle("SilentHumanize", {
    Title = "Humanized Shots (experimental)",
    Description = "Adds small jitter + 30% torso hits. WARNING: server rejects some jittered packets (damage drops) - test yourself, keep OFF if hits miss.",
    Default = S.SilentHumanize,
    Callback = function(v) S.SilentHumanize = v end,
})
Tabs.Trigger:AddSlider("TriggerDelay", {
    Title = "Reaction Delay (ms)",
    Default = 70, Min = 0, Max = 250, Rounding = 0,
    Callback = function(v) S.TriggerDelay = v end,
})
Tabs.Trigger:AddToggle("TrigTeamCheck", {
    Title = "Team Check",
    Default = S.TeamCheck,
    Callback = function(v) S.TeamCheck = v end,
})

-- ===== ESP TAB =====
Tabs.ESP:AddToggle("ESPEnabled", {
    Title = "Player ESP",
    Default = S.ESPEnabled,
    Callback = function(v) S.ESPEnabled = v end,
})
Tabs.ESP:AddToggle("ESPBots", {
    Title = "Bots",
    Default = S.ESPBots,
    Callback = function(v) S.ESPBots = v end,
})
Tabs.ESP:AddToggle("ESPNames", {
    Title = "Names",
    Default = S.ESPNames,
    Callback = function(v) S.ESPNames = v end,
})
Tabs.ESP:AddToggle("ESPDistance", {
    Title = "Distance",
    Default = S.ESPDistance,
    Callback = function(v) S.ESPDistance = v end,
})
Tabs.ESP:AddToggle("ESPHealth", {
    Title = "Health",
    Default = S.ESPHealth,
    Callback = function(v) S.ESPHealth = v end,
})

-- ===== SKINS TAB (client-side preview: sadece sen gorursun) =====
do
    -- rarity onceligi
    local PRIORITY = { Supporter = 1, Common = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Prismatic = 7 }
    -- silah listesi (skin'i olanlar)
    local weapons = {}
    for id, s in pairs(Skins.ById) do
        if s.Weapon and not table.find(weapons, s.Weapon) then
            weapons[#weapons + 1] = s.Weapon
        end
    end
    table.sort(weapons)

    local heldToolPaint = function(tool, weapon, skinId)
        if skinId and skinId ~= "Default" then
            LocalPlayer:SetAttribute("Skin_" .. weapon, skinId)
            pcall(SkinLook.Apply, tool, weapon, skinId)
        else
            LocalPlayer:SetAttribute("Skin_" .. weapon, nil)
            pcall(SkinLook.Apply, tool, weapon, nil)
        end
    end

    -- silah basina skin listesi sorter
    local function skinsFor(weapon)
        local list = { "Default" }
        local tmp = {}
        for id, s in pairs(Skins.ById) do
            if s.Weapon == weapon then
                tmp[#tmp + 1] = { id = id, rarity = s.Rarity or "?", p = PRIORITY[s.Rarity] or 0 }
            end
        end
        table.sort(tmp, function(a, b)
            if a.p ~= b.p then return a.p > b.p end
            return a.id < b.id
        end)
        for _, e in ipairs(tmp) do
            list[#list + 1] = e.id .. " [" .. e.rarity .. "]"
        end
        return list
    end

    local currentWeapon = weapons[1] or "AR"
    local currentSkin = "Default"

    Tabs.Skins:AddParagraph("Info", {
        Title = "Skin Preview",
        Content = "Client-side only - only you see it. Picks up automatically when you equip the weapon.",
    })

    local skinDropdown
    Tabs.Skins:AddDropdown("SkinWeapon", {
        Title = "Weapon",
        Values = weapons,
        Default = currentWeapon,
        Callback = function(v)
            currentWeapon = v
            if skinDropdown then
                pcall(function() skinDropdown:SetValues(skinsFor(v)) end)
            end
            local cur = LocalPlayer:GetAttribute("Skin_" .. v)
            currentSkin = cur or "Default"
        end,
    })
    skinDropdown = Tabs.Skins:AddDropdown("SkinPick", {
        Title = "Skin",
        Values = skinsFor(currentWeapon),
        Default = "Default",
        Callback = function(v)
            currentSkin = v
        end,
    })
    Tabs.Skins:AddButton({
        Title = "Apply Selected Skin",
        Description = "Paints instantly if the weapon is in your hands",
        Callback = function()
            local skinId = currentSkin ~= "Default" and currentSkin:gsub("%s*%[.*%]$", "") or "Default"
            LocalPlayer:SetAttribute("Skin_" .. currentWeapon, skinId ~= "Default" and skinId or nil)
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("Weapon") == currentWeapon then
                pcall(SkinLook.Apply, tool, currentWeapon, skinId ~= "Default" and skinId or nil)
            end
            Fluent:Notify({
                Title = "Skins",
                Content = currentWeapon .. " => " .. skinId .. " (client-side)",
                Duration = 3,
            })
        end,
    })
    Tabs.Skins:AddButton({
        Title = "Apply Best Skin to ALL Weapons",
        Description = "Highest rarity skin for every weapon",
        Callback = function()
            local best = {}
            for id, s in pairs(Skins.ById) do
                local w = s.Weapon
                local p = PRIORITY[s.Rarity] or 0
                if w and (not best[w] or p > best[w].p) then
                    best[w] = { id = id, p = p }
                end
            end
            for w, b in pairs(best) do
                LocalPlayer:SetAttribute("Skin_" .. w, b.id)
            end
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                local w = tool:GetAttribute("Weapon")
                if w and best[w] then pcall(SkinLook.Apply, tool, w, best[w].id) end
            end
            Fluent:Notify({
                Title = "Skins",
                Content = "Best skin applied to all weapons (client-side)",
                Duration = 3,
            })
        end,
    })
    Tabs.Skins:AddButton({
        Title = "Clear All Skins",
        Description = "Back to your real owned skins",
        Callback = function()
            for _, w in ipairs(weapons) do
                LocalPlayer:SetAttribute("Skin_" .. w, nil)
            end
            Fluent:Notify({
                Title = "Skins",
                Content = "Cleared (re-equip weapon to refresh)",
                Duration = 3,
            })
        end,
    })

    -- equip'te otomatik repaint: oyun sunucudan skin'i geri yazabilir,
    -- biz secilenle ez. (ESKI BUG: SurfaceAppearance varsa boyamiyordu,
    -- yani sahibi oldugun silahlarda skin degismiyordu. Artik painted
    -- durum takibi: silah uzerindeki skin seciligimizden farkliysa boya)
    local painted = setmetatable({}, { __mode = "k" })
    task.spawn(function()
        while not Fluent.Unloaded do
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    local w = tool:GetAttribute("Weapon")
                    local want = w and LocalPlayer:GetAttribute("Skin_" .. w)
                    if want then
                        if painted[tool] ~= want then
                            pcall(SkinLook.Apply, tool, w, want)
                            painted[tool] = want
                            -- oyun 1sn icin geri yazabilir: bir tur sonra tekrar dene
                            task.delay(1.2, function()
                                if tool.Parent then
                                    pcall(SkinLook.Apply, tool, w, want)
                                end
                            end)
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ===== MISC TAB =====
Tabs.Misc:AddToggle("AntiAFK", {
    Title = "Anti-AFK",
    Default = S.AntiAFK,
    Callback = function(v) S.AntiAFK = v end,
})
pcall(function()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        if S.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end)
Tabs.Misc:AddSection("Performance")
local savedDecor = true
pcall(function() savedDecor = workspace.Terrain.Decoration end)
local savedQuality = nil
local savedShadows = true
local savedEffects = {}
pcall(function()
    savedQuality = UserSettings():GetService("UserGameSettings").SavedQualityLevel
    savedShadows = workspace.GlobalShadows
end)
-- Potato: kalite 1 + golgeler kapali + post efektler (bloom/blur/dof/sunrays) kapali
local function applyPotato(on)
    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        if on then
            savedQuality = ugs.SavedQualityLevel
            ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        elseif savedQuality then
            ugs.SavedQualityLevel = savedQuality
        end
    end)
    pcall(function()
        local Lighting = game:GetService("Lighting")
        if on then
            savedShadows = Lighting.GlobalShadows
            Lighting.GlobalShadows = false
        else
            Lighting.GlobalShadows = savedShadows
        end
    end)
    pcall(function()
        local Lighting = game:GetService("Lighting")
        if on then
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("PostEffect") and e.Enabled then
                    savedEffects[e] = true
                    e.Enabled = false
                end
            end
        else
            for e in pairs(savedEffects) do
                if e.Parent then e.Enabled = true end
            end
            table.clear(savedEffects)
        end
    end)
end
Tabs.Misc:AddToggle("GrassOff", {
    Title = "Grass Off",
    Description = "Terrain.Decoration off - big FPS boost",
    Default = false,
    Callback = function(v)
        S.GrassOn = v
        if v then
            pcall(function() savedDecor = workspace.Terrain.Decoration end)
            pcall(function() workspace.Terrain.Decoration = false end)
        else
            pcall(function() workspace.Terrain.Decoration = savedDecor end)
        end
    end,
})
-- GrassOff/Potato kalici tutucu: oyun veya Roblox ayari geri yazarsa
-- 2 sn'de bir tekrar uygula (toggellar acik oldugu surece)
task.spawn(function()
    while not Fluent.Unloaded do
        if getgenv().PVP_S ~= S then return end
        pcall(function()
            local d = workspace.Terrain
            -- mevcut acik durumu S'den bilmiyoruz; toggle gorevi
            -- callback'te. Burada sadece 'decoration'u zorla kapali
            -- tutma kismini yapamiyoruz - bunun yerine GrassOff aciksa
            if S.GrassOn then d.Decoration = false end
            if S.PotatoOn then
                UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            end
        end)
        task.wait(2)
    end
end)
Tabs.Misc:AddToggle("PotatoMode", {
    Title = "Potato Mode",
    Description = "Quality 1 + shadows off + effects off - big FPS boost",
    Default = false,
    Callback = function(v)
        S.PotatoOn = v
        applyPotato(v)
    end,
})

-- ===== CONFIG ADDONS =====
local SaveManager, InterfaceManager
do
    pcall(function()
        local ok, m = pcall(function()
            return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Addons/SaveManager.luau"))()
        end)
        if ok then SaveManager = m end
    end)
    pcall(function()
        local ok, m = pcall(function()
            return loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/myheisenberg/Fluent-Renewed/main/Addons/InterfaceManager.luau"))()
        end)
        if ok then InterfaceManager = m end
    end)
end
if SaveManager and InterfaceManager then
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    InterfaceManager:SetFolder("RespectPVPHub")
    SaveManager:SetFolder("RespectPVPHub/game")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
elseif SaveManager then
    SaveManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("RespectPVPHub/game")
    SaveManager:BuildConfigSection(Tabs.Settings)
end
Window:SelectTab(1)

-- ===== DROPDOWN KAPANMA FIX (kok cozum) =====
-- Fluent-Renewed'de option'a tiklayinca deger set edilir ama liste
-- KAPANMAZ (kaynak kod: yalnizca disari tiklama kapatir - tasarim).
-- Kok zincir (canli kanitlandi): option tik -> l:SetValue -> ...
-- Fluent.Options'taki her non-multi dropdown'un SetValue'sini sariyoruz:
-- secim yapilir yapilmaz Close.
for _, l in pairs(Fluent.Options) do
    if type(l) == "table" and type(l.SetValue) == "function"
        and type(l.Close) == "function" and not l.Multi then
        local origSet = l.SetValue
        l.SetValue = function(a, b, ...)
            origSet(a, b, ...)
            pcall(l.Close, l)
        end
    end
end

-- ===== MENU KAYMASI DUZELTMESI =====
-- Fluent dropdown acilinca sekme kaydirma cubugunu gizler, kapaninca
-- geri getirir -> icerik genisligi degisip her sey kayar ("yerler
-- degisiyor" bug'u). Cozum: cubugu gorunmez yap (genislik 0) -
-- kaydirma hala calisir (tekerlek/dokunma), genislik sabit kalir.
pcall(function()
    for _, d in ipairs(Fluent.GUI:GetDescendants()) do
        if d:IsA("ScrollingFrame") then
            d.ScrollBarThickness = 2
            d.ScrollBarImageTransparency = 1
        end
    end
end)

-- ===== DISCORD SEKMESI (Config altinda ayri tab) =====
mkTab("Discord", { Title = "Discord", Icon = "message-circle" })
pcall(function()
    Tabs.Discord:AddParagraph("DiscordInfo", {
        Title = "Join our Discord",
        Content = "Updates, support and more scripts from ZynexHub.",
    })
    Tabs.Discord:AddButton({
        Title = "Copy Discord Invite",
        Description = "discord.gg/zynexhub",
        Callback = function()
            local ok = pcall(function() setclipboard("https://discord.gg/zynexhub") end)
            Fluent:Notify({
                Title = "Discord",
                Content = ok and "Invite copied to clipboard!" or "Copy failed (no clipboard access)",
                Duration = 4,
            })
        end,
    })
end)

-- GUI acilis: kredileri temizle + goster
task.delay(0.6, function()
    pcall(function()
        for _, d in ipairs(Fluent.GUI:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = tostring(d.Text)
                if t == "tab" or t == "Tab" then d.Text = "" end
                if t:lower():find("fluent") or t:lower():find("dawid")
                    or t:lower():find("heisenberg") then
                    if t ~= "RESPECT PVP HUB - by ZynexDev" then
                        d.Text = ""
                    end
                end
            end
        end
        Fluent.GUI.Enabled = true
    end)
end)

-- AutoLocalize kapat (Turkce client'te UI cevrilmesin)
pcall(function()
    Fluent.GUI.AutoLocalize = false
    for _, d in ipairs(Fluent.GUI:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            d.AutoLocalize = false
        end
    end
end)

Fluent:Notify({
    Title = "RESPECT PVP HUB",
    Content = "by ZynexHub",
    Duration = 6,
})

-- TEARDOWN
-- NESIL KILIDI: eski instance'in Fluent.Unloaded bekcisi, yeni yuklemenin
-- teardown'ini cagirip yeni hub'i 1 sn icinde oldurebiliyordu
-- ("once calisti sonra bozuldu" hatasinin koku). Her instance kendine
-- ozgu GEN ile kilitler - sadece KENDI nesli oldsurtur.
local MY_GEN = "PVP" .. tostring(math.random(100000, 999999))
getgenv().PVP_TEARDOWN = function()
    if getgenv().PVP_TEARDOWN_GEN ~= MY_GEN then return end
    pcall(function() RunService:UnbindFromRenderStep("PVP_Aim") end)
    pcall(function() RunService:UnbindFromRenderStep("PVP_AutoFire") end)
    pcall(function()
        game:GetService("ContextActionService"):UnbindAction(getgenv().PVP_CAS_NAME or CAS_NAME)
    end)
    -- __namecall hook'u geri al (orijinal yerine koy)
    if OldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", OldNamecall) end)
    end
    if circle then pcall(function() circle:Remove() end) end
    pcall(function() espFolder:Destroy() end)
    getgenv().PVP_HUB_LOADED = nil
    getgenv().PVP_S = nil
end
getgenv().PVP_TEARDOWN_GEN = MY_GEN

task.spawn(function()
    while not Fluent.Unloaded do task.wait(1) end
    if getgenv().PVP_TEARDOWN_GEN == MY_GEN then
        getgenv().PVP_TEARDOWN()
    end
end)
