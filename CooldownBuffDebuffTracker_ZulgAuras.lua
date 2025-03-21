-- Author: ZulgAuras
-- 

local addonName, ZA = ...
ZA.version = GetAddOnMetadata(addonName, "Version")

-- Default settings
local defaults = {
    cooldownLine = {
        enabled = true,
        scale = 1.0,
        position = {"CENTER", UIParent, "CENTER", 0, 150},
        width = 400,
    },
    buffLine = {
        enabled = true,
        scale = 1.0,
        position = {"CENTER", UIParent, "CENTER", 0, 180},
        width = 400,
    },
    debuffLine = {
        enabled = true,
        scale = 1.0,
        position = {"CENTER", UIParent, "CENTER", 0, 120},
        width = 400,
    },
    minimapIcon = {
        hide = false,
        position = 220, -- Angle in degrees
    },
}

-- Initialize the saved variables; this function assumes saved variables are loaded.
function ZA:InitializeDB()
    if not ZBCDT_DB or type(ZBCDT_DB) ~= "table" then
        ZBCDT_DB = CopyTable(defaults)
        print("ZulgAuras: New database created with defaults.")
    else
        for key, defValue in pairs(defaults) do
            if type(defValue) == "table" then
                if not ZBCDT_DB[key] or type(ZBCDT_DB[key]) ~= "table" then
                    ZBCDT_DB[key] = CopyTable(defValue)
                else
                    for subKey, subValue in pairs(defValue) do
                        if ZBCDT_DB[key][subKey] == nil then
                            ZBCDT_DB[key][subKey] = subValue
                        end
                    end
                end
            else
                if ZBCDT_DB[key] == nil then
                    ZBCDT_DB[key] = defValue
                end
            end
        end
        print("ZulgAuras: Merged missing keys from defaults.")
    end
    self.db = ZBCDT_DB
    print("Current cooldown scale:", self.db.cooldownLine.scale, "width:", self.db.cooldownLine.width)
    print("Current buff scale:", self.db.buffLine.scale, "width:", self.db.buffLine.width)
    print("Current debuff scale:", self.db.debuffLine.scale, "width:", self.db.debuffLine.width)
end

-- Create the tracker lines using stored settings.
function ZA:CreateTrackerLines()
    self.cooldownLine = self:CreateTrackerLine("ZA_CooldownLine", "Cooldowns", self.db.cooldownLine)
    self.cooldownLine.markers = self:AddTimeMarkers(self.cooldownLine, {5,10,15,20,25}, 30)
    self.buffLine = self:CreateTrackerLine("ZA_BuffLine", "Buffs", self.db.buffLine)
    self.buffLine.markers = self:AddTimeMarkers(self.buffLine, {5,10,15,20,25}, 30)
    self.debuffLine = self:CreateTrackerLine("ZA_DebuffLine", "Debuffs", self.db.debuffLine)
    self.debuffLine.markers = self:AddTimeMarkers(self.debuffLine, {5,10}, 15)
    self:SetHeadersVisible(false)
end

function ZA:SetHeadersVisible(visible)
    if self.cooldownLine and self.cooldownLine.header then self.cooldownLine.header:SetShown(visible) end
    if self.buffLine and self.buffLine.header then self.buffLine.header:SetShown(visible) end
    if self.debuffLine and self.debuffLine.header then self.debuffLine.header:SetShown(visible) end
end

function ZA:CreateTrackerLine(name, label, settings)
    local line = CreateFrame("Frame", name, UIParent)
    line:SetSize(settings.width, 40)
    line:SetPoint(unpack(settings.position))
    line:SetScale(settings.scale)
    line:SetFrameStrata("MEDIUM")
    line:EnableMouse(true)
    line:SetMovable(true)
    line.icons = {}
    line.bg = line:CreateTexture(nil, "BACKGROUND")
    line.bg:SetAllPoints()
    line.bg:SetColorTexture(0,0,0,0.3)
    line.header = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.header:SetPoint("BOTTOMLEFT", line, "TOPLEFT", 0, 2)
    line.header:SetText(label)
    line.header:Hide()
    line:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not self.isLocked then
            self:StartMoving()
        end
    end)
    line:SetScript("OnMouseUp", function(self, button)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        settings.position = {point, relativeTo, relativePoint, xOfs, yOfs}
    end)
    line:SetShown(settings.enabled)
    return line
end

function ZA:AddTimeMarkers(line, markers, maxTime)
    local markerFrames = {}
    local width = line:GetWidth()
    local height = line:GetHeight()
    for i, time in ipairs(markers) do
        local marker = CreateFrame("Frame", nil, line)
        marker:SetSize(1, height)
        local markerLine = marker:CreateTexture(nil, "ARTWORK")
        markerLine:SetAllPoints()
        markerLine:SetColorTexture(1,1,1,0.7)
        local markerText = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        markerText:SetPoint("TOP", marker, "BOTTOM", 0, 0)
        markerText:SetText(time.."s")
        local position = width * (time / maxTime)
        marker:SetPoint("TOP", line, "TOPLEFT", position, 0)
        table.insert(markerFrames, marker)
    end
    return markerFrames
end

function ZA:CreateTrackerIcon(parent, spellId, duration, expirationTime, maxDuration)
    local size = parent:GetHeight() - 10
    local id = tostring(spellId)
    local width = parent:GetWidth()
    if not parent.icons[id] then
        local icon = CreateFrame("Frame", nil, parent)
        icon:SetSize(size, size)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08,0.92,0.08,0.92)
        icon.border = icon:CreateTexture(nil, "BORDER")
        icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1,1)
        icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1,-1)
        icon.border:SetColorTexture(0,0,0,1)
        icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        icon.text:SetFont(icon.text:GetFont(), 14, "OUTLINE")
        icon.text:SetPoint("CENTER", icon, "CENTER", 0,0)
        icon.text:SetShadowOffset(1,-1)
        icon.text:SetShadowColor(0,0,0,1)
        parent.icons[id] = icon
    end
    local icon = parent.icons[id]
    local name, _, iconTexture = GetSpellInfo(spellId)
    if not name then
        name = "Unknown"
        iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    icon.spellId = spellId
    icon.startTime = expirationTime - duration
    icon.duration = duration
    icon.expirationTime = expirationTime
    icon.texture:SetTexture(iconTexture)
    icon.maxDuration = maxDuration
    if parent == self.buffLine and duration > maxDuration then
        icon:Hide()
        return nil
    end
    icon:Show()
    icon:SetScript("OnUpdate", function(self)
        local remaining = self.expirationTime - GetTime()
        if remaining <= 0 then
            self:Hide()
            parent.icons[id] = nil
            return
        end
        local position = 0
        if parent == ZA.debuffLine then
            if remaining <= self.maxDuration then
                position = width * (remaining / self.maxDuration)
                self.text:SetText(math.floor(remaining+0.5))
            end
        else
            if remaining <= self.maxDuration then
                position = width * (remaining / self.maxDuration)
                self.text:SetText(math.floor(remaining+0.5))
            else
                if parent == ZA.buffLine then
                    self:Hide()
                    parent.icons[id] = nil
                    return
                else
                    position = width - 5
                    local minutes = math.floor(remaining/60)
                    local seconds = math.floor(remaining % 60)
                    self.text:SetText(string.format("%d:%02d", minutes, seconds))
                end
            end
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "LEFT", position, 0)
    end)
    return icon
end

function ZA:UpdateCooldownLine()
    if not self.db.cooldownLine.enabled then return end
    local line = self.cooldownLine
    local maxDuration = 30
    local GCD_DURATION = 1.5
    for tab = 1, GetNumSpellTabs() do
        local _,_,offset,numSpells = GetSpellTabInfo(tab)
        for i = offset+1, offset+numSpells do
            local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if spellName then
                local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
                if start > 0 and duration > GCD_DURATION then
                    local spellType, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                    local expirationTime = start + duration
                    local identifier = spellID or spellName
                    self:CreateTrackerIcon(line, identifier, duration, expirationTime, maxDuration)
                end
            end
        end
    end
    for i = 1, 120 do
        local actionType, id = GetActionInfo(i)
        if actionType == "spell" then
            local start, duration = GetActionCooldown(i)
            if start > 0 and duration > GCD_DURATION then
                local expirationTime = start + duration
                self:CreateTrackerIcon(line, id, duration, expirationTime, maxDuration)
            end
        elseif actionType == "item" then
            local start, duration = GetActionCooldown(i)
            if start > 0 and duration > GCD_DURATION then
                local expirationTime = start + duration
                self:CreateTrackerIcon(line, "item:"..id, duration, expirationTime, maxDuration)
            end
        end
    end
    for i = 0, 19 do
        local start, duration, enable = GetInventoryItemCooldown("player", i)
        if start > 0 and duration > GCD_DURATION and enable == 1 then
            local itemID = GetInventoryItemID("player", i)
            if itemID then
                local expirationTime = start + duration
                self:CreateTrackerIcon(line, "item:"..itemID, duration, expirationTime, maxDuration)
            end
        end
    end
end

function ZA:UpdateBuffLine()
    if not self.db.buffLine.enabled then return end
    local line = self.buffLine
    local maxDuration = 30
    for i = 1,40 do
        local name, iconVal, count, _, duration, expirationTime, source, _, _, spellId = UnitBuff("player", i)
        if name then
            if duration and duration > 0 and source == "player" then
                local remaining = expirationTime - GetTime()
                if remaining <= maxDuration then
                    self:CreateTrackerIcon(line, spellId or name, duration, expirationTime, maxDuration)
                end
            end
        else
            break
        end
    end
end

function ZA:UpdateDebuffLine()
    if not self.db.debuffLine.enabled then return end
    local line = self.debuffLine
    local maxDuration = 15
    if UnitExists("target") then
        for i = 1,40 do
            local name, iconVal, count, _, duration, expirationTime, source, _, _, spellId = UnitDebuff("target", i)
            if name then
                if duration and duration > 0 and source == "player" then
                    local remaining = expirationTime - GetTime()
                    if remaining <= maxDuration then
                        self:CreateTrackerIcon(line, spellId or name, duration, expirationTime, maxDuration)
                    end
                end
            else
                break
            end
        end
    end
end

function ZA:CreateMinimapButton()
    local button = CreateFrame("Button", "ZA_MinimapButton", Minimap)
    button:SetSize(31,31)
    button:SetFrameLevel(8)
    button:SetFrameStrata("MEDIUM")
    local icon = button:CreateTexture(nil,"BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\CooldownBuffDebuffTracker_ZulgAuras\\logo.tta")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08,0.92,0.08,0.92)
    button.icon = icon
    button:EnableMouse(true)
    button:SetMovable(true)
    local angle = self.db.minimapIcon.position or 220
    local rad = angle * (math.pi/180)
    button:SetPoint("TOPLEFT",Minimap,"TOPLEFT",52 - (80 * math.cos(rad)), (80 * math.sin(rad)) - 52)
    local function UpdatePosition()
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        xpos, ypos = xpos/scale, ypos/scale
        local cx, cy = Minimap:GetCenter()
        local angle = math.atan2(ypos - cy, xpos - cx)
        xpos = cx + 80 * math.cos(angle)
        ypos = cy + 80 * math.sin(angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", xpos, ypos)
        ZA.db.minimapIcon.position = angle * 180/math.pi % 360
    end
    button:SetScript("OnMouseDown",function(self,mouseButton)
        if mouseButton=="LeftButton" then
            self:SetScript("OnUpdate",UpdatePosition)
        end
    end)
    button:SetScript("OnMouseUp",function(self)
        self:SetScript("OnUpdate",nil)
    end)
    button:SetScript("OnClick",function(self,mouseButton)
        if mouseButton=="LeftButton" then ZA:ToggleConfigPanel() end
    end)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("ZulgAuras Tracker")
        GameTooltip:AddLine("Left-Click: Open configuration",1,1,1)
        GameTooltip:AddLine("Drag: Move icon",1,1,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetShown(not self.db.minimapIcon.hide)
    self.minimapButton = button
end

function ZA:CreateConfigPanel()
    local panel = CreateFrame("Frame", "ZA_ConfigPanel", UIParent, "BackdropTemplate")
    panel:SetSize(450,400)
    panel:SetPoint("CENTER")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left = 6, right = 6, top = 6, bottom = 6}
    })
    panel:SetBackdropColor(0.1,0.1,0.1,0.9)
    panel.title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    panel.title:SetPoint("TOP",0,-20)
    panel.title:SetText("CooldownBuffDebuffTracker Configuration")
    local y = -60
    local function CreateToggle(text, setting, updateFunc)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT",30,y)
        check.text:SetText(text)
        check.text:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
        check:SetChecked(setting.enabled)
        check:SetScript("OnClick", function(self)
            setting.enabled = self:GetChecked()
            if updateFunc then updateFunc() end
        end)
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetWidth(200)
        slider:SetHeight(20)
        slider:SetPoint("TOPLEFT",240,y-5)
        slider:SetMinMaxValues(0.5, 2.0)
        slider:SetValueStep(0.1)
        slider:SetValue(setting.scale)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText("0.5")
        slider.High:SetText("2.0")
        slider.Text:SetText(string.format("Scale: %.1f", setting.scale))
        slider:SetScript("OnValueChanged", function(self, value)
            setting.scale = value
            self.Text:SetText(string.format("Scale: %.1f", value))
            if updateFunc then updateFunc() end
        end)
        y = y - 40
        return check, slider
    end
    local function CreateWidthSlider(text, setting, updateFunc)
        local label = panel:CreateFontString(nil, "OVERLAY","GameFontNormal")
        label:SetPoint("TOPLEFT",30,y)
        label:SetText(text)
        label:SetFont("Fonts\\FRIZQT__.TTF",13,"OUTLINE")
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetWidth(200)
        slider:SetHeight(20)
        slider:SetPoint("TOPLEFT",240,y-5)
        slider:SetMinMaxValues(200,600)
        slider:SetValueStep(10)
        slider:SetValue(setting.width)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText("200")
        slider.High:SetText("600")
        slider.Text:SetText(string.format("Width: %d", setting.width))
        slider:SetScript("OnValueChanged", function(self, value)
            setting.width = value
            self.Text:SetText(string.format("Width: %d", value))
            if updateFunc then updateFunc() end
        end)
        y = y - 40
        return slider
    end
    panel.cooldownToggle, panel.cooldownSlider = CreateToggle("Enable Cooldowns", self.db.cooldownLine, function()
        self.cooldownLine:SetShown(self.db.cooldownLine.enabled)
        self.cooldownLine:SetScale(self.db.cooldownLine.scale)
    end)
    panel.cooldownWidthSlider = CreateWidthSlider("Cooldown Line Width", self.db.cooldownLine, function()
        self.cooldownLine:SetWidth(self.db.cooldownLine.width)
        for _, marker in ipairs(self.cooldownLine.markers) do marker:Hide() end
        self.cooldownLine.markers = self:AddTimeMarkers(self.cooldownLine, {5,10,15,20,25}, 30)
    end)
    panel.buffToggle, panel.buffSlider = CreateToggle("Enable Buffs", self.db.buffLine, function()
        self.buffLine:SetShown(self.db.buffLine.enabled)
        self.buffLine:SetScale(self.db.buffLine.scale)
    end)
    panel.buffWidthSlider = CreateWidthSlider("Buff Line Width", self.db.buffLine, function()
        self.buffLine:SetWidth(self.db.buffLine.width)
        for _, marker in ipairs(self.buffLine.markers) do marker:Hide() end
        self.buffLine.markers = self:AddTimeMarkers(self.buffLine, {5,10,15,20,25}, 30)
    end)
    panel.debuffToggle, panel.debuffSlider = CreateToggle("Enable Debuffs", self.db.debuffLine, function()
        self.debuffLine:SetShown(self.db.debuffLine.enabled)
        self.debuffLine:SetScale(self.db.debuffLine.scale)
    end)
    panel.debuffWidthSlider = CreateWidthSlider("Debuff Line Width", self.db.debuffLine, function()
        self.debuffLine:SetWidth(self.db.debuffLine.width)
        for _, marker in ipairs(self.debuffLine.markers) do marker:Hide() end
        self.debuffLine.markers = self:AddTimeMarkers(self.debuffLine, {5,10}, 15)
    end)
    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT",30,y)
    minimapCheck.text:SetText("Show Minimap Icon")
    minimapCheck.text:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    minimapCheck:SetChecked(not self.db.minimapIcon.hide)
    minimapCheck:SetScript("OnClick", function(self)
        ZA.db.minimapIcon.hide = not self:GetChecked()
        ZA.minimapButton:SetShown(not ZA.db.minimapIcon.hide)
    end)
    y = y - 50
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(150,30)
    resetButton:SetPoint("TOPLEFT",30,y)
    resetButton:SetText("Reset Positions")
    resetButton:SetScript("OnClick", function()
        ZA.db.cooldownLine.position = CopyTable(defaults.cooldownLine.position)
        ZA.db.buffLine.position = CopyTable(defaults.buffLine.position)
        ZA.db.debuffLine.position = CopyTable(defaults.debuffLine.position)
        ZA.cooldownLine:ClearAllPoints()
        ZA.cooldownLine:SetPoint(unpack(ZA.db.cooldownLine.position))
        ZA.buffLine:ClearAllPoints()
        ZA.buffLine:SetPoint(unpack(ZA.db.buffLine.position))
        ZA.debuffLine:ClearAllPoints()
        ZA.debuffLine:SetPoint(unpack(ZA.db.debuffLine.position))
    end)
    local resetAllButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetAllButton:SetSize(150,30)
    resetAllButton:SetPoint("TOPLEFT",220,y)
    resetAllButton:SetText("Reset All Settings")
    resetAllButton:SetScript("OnClick", function()
        StaticPopupDialogs["ZA_RESET_CONFIRM"] = {
            text = "Are you sure you want to reset all settings? This cannot be undone.",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                ZBCDT_DB = CopyTable(defaults)
                ZA.db = ZBCDT_DB
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("ZA_RESET_CONFIRM")
    end)
    y = y - 60
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    closeButton:SetSize(80,30)
    closeButton:SetPoint("BOTTOMRIGHT",-20,20)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() panel:Hide() end)
    local versionText = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    versionText:SetPoint("BOTTOMLEFT",20,20)
    versionText:SetText("Version: " .. ZA.version)
    panel:SetScript("OnShow", function() ZA:SetHeadersVisible(true) end)
    panel:SetScript("OnHide", function() ZA:SetHeadersVisible(false) end)
    self.configPanel = panel
    panel:Hide() -- Hide by default 
end

function ZA:ToggleConfigPanel()
    if self.configPanel:IsShown() then
        self.configPanel:Hide()
    else
        self.configPanel:Show()
    end
end

function ZA:CleanupStaleIcons()
    local function cleanLine(line)
        for id, icon in pairs(line.icons) do
            if icon.expirationTime and icon.expirationTime < GetTime() then
                icon:Hide()
                line.icons[id] = nil
            end
        end
    end
    cleanLine(self.cooldownLine)
    cleanLine(self.buffLine)
    cleanLine(self.debuffLine)
end

function ZA:Initialize()
    -- Delay initialization until PLAYER_LOGIN so that saved variables are guaranteed loaded:
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event)
        ZA:InitializeDB()
        ZA:CreateTrackerLines()
        ZA:CreateMinimapButton()
        ZA:CreateConfigPanel()
        ZA:UpdateAllLines()
        print("|cff33ff99CooldownBuffDebuffTracker_ZulgAuras|r loaded. Type |cffff6600/za|r to open the configuration panel.")
    end)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
            ZA:UpdateCooldownLine()
        elseif event == "UNIT_AURA" and arg1 == "player" then
            ZA:UpdateBuffLine()
            if UnitExists("target") then ZA:UpdateDebuffLine() end
        elseif event == "PLAYER_TARGET_CHANGED" then
            ZA:UpdateDebuffLine()
        elseif event == "PLAYER_LOGOUT" then
            print("PLAYER_LOGOUT: Saving database:")
            print("Cooldown scale:", ZA.db.cooldownLine.scale, "width:", ZA.db.cooldownLine.width)
            print("Buff scale:", ZA.db.buffLine.scale, "width:", ZA.db.buffLine.width)
            print("Debuff scale:", ZA.db.debuffLine.scale, "width:", ZA.db.debuffLine.width)
        end
    end)
    
    C_Timer.NewTicker(2, function() ZA:CleanupStaleIcons() end)
    
    function ZA:UpdateAllLines()
        self:UpdateCooldownLine()
        self:UpdateBuffLine()
        self:UpdateDebuffLine()
    end
end

ZA:Initialize()