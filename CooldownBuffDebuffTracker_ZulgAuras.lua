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

-- Initialize the saved variables
function ZA:InitializeDB()
    ZBCDT_DB = ZBCDT_DB or {}
    for k, v in pairs(defaults) do
        if ZBCDT_DB[k] == nil then
            ZBCDT_DB[k] = CopyTable(v)
        end
    end
    self.db = ZBCDT_DB
end

-- Create the tracker lines
function ZA:CreateTrackerLines()
    -- Create cooldown line
    self.cooldownLine = self:CreateTrackerLine("ZA_CooldownLine", "Cooldowns", self.db.cooldownLine)
    self.cooldownLine.markers = self:AddTimeMarkers(self.cooldownLine, {5, 10, 15, 20, 25}, 30) -- Max 30s
    
    -- Create buff line
    self.buffLine = self:CreateTrackerLine("ZA_BuffLine", "Buffs", self.db.buffLine)
    self.buffLine.markers = self:AddTimeMarkers(self.buffLine, {5, 10, 15, 20, 25}, 30) -- Max 30s
    
    -- Create debuff line
    self.debuffLine = self:CreateTrackerLine("ZA_DebuffLine", "Debuffs", self.db.debuffLine)
    self.debuffLine.markers = self:AddTimeMarkers(self.debuffLine, {5, 10}, 15) -- Max 15s
    
    -- Initially hide the headers
    self:SetHeadersVisible(false)
end

-- Show or hide all line headers
function ZA:SetHeadersVisible(visible)
    if self.cooldownLine and self.cooldownLine.header then
        self.cooldownLine.header:SetShown(visible)
    end
    if self.buffLine and self.buffLine.header then
        self.buffLine.header:SetShown(visible)
    end
    if self.debuffLine and self.debuffLine.header then
        self.debuffLine.header:SetShown(visible)
    end
end

-- Create a single tracker line
function ZA:CreateTrackerLine(name, label, settings)
    local line = CreateFrame("Frame", name, UIParent)
    line:SetSize(settings.width, 40)
    line:SetPoint(unpack(settings.position))
    line:SetScale(settings.scale)
    line:SetFrameStrata("MEDIUM")
    line:EnableMouse(true)
    line:SetMovable(true)
    line.icons = {}
    
    -- Add a background for visibility
    line.bg = line:CreateTexture(nil, "BACKGROUND")
    line.bg:SetAllPoints()
    line.bg:SetColorTexture(0, 0, 0, 0.3)
    
    -- Add a header text
    line.header = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.header:SetPoint("BOTTOMLEFT", line, "TOPLEFT", 0, 2)
    line.header:SetText(label)
    line.header:Hide() -- Initially hidden
    
    -- Make the line draggable
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
-- Add time markers to a tracker line
function ZA:AddTimeMarkers(line, markers, maxTime)
    local markerFrames = {}
    local width = line:GetWidth()
    local height = line:GetHeight()
    
    for i, time in ipairs(markers) do
        local marker = CreateFrame("Frame", nil, line)
        marker:SetSize(1, height) -- Full height of the line
        
        local markerLine = marker:CreateTexture(nil, "ARTWORK")
        markerLine:SetAllPoints()
        markerLine:SetColorTexture(1, 1, 1, 0.7)
        
        local markerText = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        markerText:SetPoint("TOP", marker, "BOTTOM", 0, 0) -- Place text below marker line
        markerText:SetText(time .. "s")
        
        -- Position from right to left (0s at left, maxTime at right)
        -- For right to left movement, use time/maxTime ratio
        local position = width * (time / maxTime)
        
        marker:SetPoint("TOP", line, "TOPLEFT", position, 0)
        
        table.insert(markerFrames, marker)
    end
    
    return markerFrames
end

-- Create or update an icon for a cooldown/buff/debuff
function ZA:CreateTrackerIcon(parent, spellId, duration, expirationTime, maxDuration)
    local size = parent:GetHeight() - 10
    local id = tostring(spellId)
    local width = parent:GetWidth()
    
    if not parent.icons[id] then
        local icon = CreateFrame("Frame", nil, parent)
        icon:SetSize(size, size)
        
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Remove border padding
        
        icon.border = icon:CreateTexture(nil, "BORDER")
        icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        icon.border:SetColorTexture(0, 0, 0, 1)
        
        -- Create larger text with shadow for better visibility
        icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        icon.text:SetFont(icon.text:GetFont(), 14, "OUTLINE")
        icon.text:SetPoint("CENTER", icon, "CENTER", 0, 0)
        icon.text:SetShadowOffset(1, -1)
        icon.text:SetShadowColor(0, 0, 0, 1)
        
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
    icon.maxDuration = maxDuration -- Maximum duration for timeline
    
    -- Skip buffs with duration > maxDuration
    if parent == self.buffLine and duration > maxDuration then
        icon:Hide()
        return nil
    end
    
    icon:Show()
    
    -- Update the position and time text
    icon:SetScript("OnUpdate", function(self)
        local remaining = self.expirationTime - GetTime()
        
        if remaining <= 0 then
            self:Hide()
            parent.icons[id] = nil
            return
        end
        
        -- Calculate position (right to left)
        local position = 0
        if parent == ZA.debuffLine then
            -- For debuffs: 15s at right, 0s at left
            if remaining <= self.maxDuration then
                position = width * (remaining / self.maxDuration)
                self.text:SetText(math.floor(remaining + 0.5))
            end
        else
            -- For cooldowns and buffs: 30s at right, 0s at left
            if remaining <= self.maxDuration then
                position = width * (remaining / self.maxDuration)
                self.text:SetText(math.floor(remaining + 0.5))
            else
                -- Hide if over max duration (for buffs)
                if parent == ZA.buffLine then
                    self:Hide()
                    parent.icons[id] = nil
                    return
                else
                    -- For cooldowns over maxDuration, show at far right
                    position = width - 5 -- Small offset from right edge
                    local minutes = math.floor(remaining / 60)
                    local seconds = math.floor(remaining % 60)
                    self.text:SetText(string.format("%d:%02d", minutes, seconds))
                end
            end
        end
        
        -- Set the position (right to left)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "LEFT", position, 0)
    end)
    
    return icon
end

-- Update the cooldown line with active cooldowns
function ZA:UpdateCooldownLine()
    if not self.db.cooldownLine.enabled then return end
    
    local line = self.cooldownLine
    local maxDuration = 30 -- Max duration to show on timeline
    local GCD_DURATION = 1.5 -- Ignore GCD cooldowns
    
    -- Method 1: Scan spells directly using the spellbook index (more reliable for SoD runes)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = offset + 1, offset + numSpells do
            local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            if spellName then
                local start, duration = GetSpellCooldown(i, BOOKTYPE_SPELL)
                if start > 0 and duration > GCD_DURATION then
                    local spellType, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                    local expirationTime = start + duration
                    
                    -- Use spellID if available, otherwise use name as identifier
                    local identifier = spellID or spellName
                    self:CreateTrackerIcon(line, identifier, duration, expirationTime, maxDuration)
                end
            end
        end
    end
        -- Method 2: Scan action bars (catches any abilities placed on action bars)
        for i = 1, 120 do  -- Check all action slots
            local actionType, id = GetActionInfo(i)
            if actionType == "spell" then
                local start, duration = GetActionCooldown(i)
                if start > 0 and duration > GCD_DURATION then -- Ignore GCD
                    local expirationTime = start + duration
                    self:CreateTrackerIcon(line, id, duration, expirationTime, maxDuration)
                end
            elseif actionType == "item" then
                local start, duration = GetActionCooldown(i)
                if start > 0 and duration > GCD_DURATION then
                    local expirationTime = start + duration
                    self:CreateTrackerIcon(line, "item:" .. id, duration, expirationTime, maxDuration)
                end
            end
        end
        
        -- Method 3: Scan inventory items with cooldowns
        for i = 0, 19 do -- Check all inventory slots
            local start, duration, enable = GetInventoryItemCooldown("player", i)
            if start > 0 and duration > GCD_DURATION and enable == 1 then
                local itemID = GetInventoryItemID("player", i)
                if itemID then
                    local expirationTime = start + duration
                    self:CreateTrackerIcon(line, "item:" .. itemID, duration, expirationTime, maxDuration)
                end
            end
        end
    end
    
    -- Update the buff line with active buffs
    function ZA:UpdateBuffLine()
        if not self.db.buffLine.enabled then return end
        
        local line = self.buffLine
        local maxDuration = 30 -- Only show buffs with <= 30s remaining
        
        -- Check for player buffs
        for i = 1, 40 do
            local name, icon, count, _, duration, expirationTime, source, _, _, spellId = UnitBuff("player", i)
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
    
    -- Update the debuff line with active debuffs on target
    function ZA:UpdateDebuffLine()
        if not self.db.debuffLine.enabled then return end
        
        local line = self.debuffLine
        local maxDuration = 15 -- Max duration to show on timeline (debuffs use 15s)
        
        -- Check for target debuffs applied by player
        if UnitExists("target") then
            for i = 1, 40 do
                local name, icon, count, _, duration, expirationTime, source, _, _, spellId = UnitDebuff("target", i)
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
    
    -- Create the minimap button
    function ZA:CreateMinimapButton()
        local button = CreateFrame("Button", "ZA_MinimapButton", Minimap)
        button:SetSize(31, 31)
        button:SetFrameLevel(8)
        button:SetFrameStrata("MEDIUM")
        
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetTexture("Interface\\AddOns\\CooldownBuffDebuffTracker_ZulgAuras\\logo.tga")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Remove border padding
        button.icon = icon
        
        -- Circle/border removed as requested
        
        button:EnableMouse(true)
        button:SetMovable(true)
        
        -- Set initial position
        local angle = self.db.minimapIcon.position or 220
        local rad = angle * (math.pi / 180)
        button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(rad)), (80 * math.sin(rad)) - 52)
        
        -- Dragging functions
        local function UpdatePosition()
            local xpos, ypos = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            xpos, ypos = xpos / scale, ypos / scale
            local cx, cy = Minimap:GetCenter()
            local angle = math.atan2(ypos - cy, xpos - cx)
            
            -- Calculate position
            xpos = cx + 80 * math.cos(angle)
            ypos = cy + 80 * math.sin(angle)
            
            button:ClearAllPoints()
            button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", xpos, ypos)
            ZA.db.minimapIcon.position = angle * 180 / math.pi % 360
        end
        
        button:SetScript("OnMouseDown", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                self:SetScript("OnUpdate", UpdatePosition)
            end
        end)
        
        button:SetScript("OnMouseUp", function(self)
            self:SetScript("OnUpdate", nil)
        end)
        
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                ZA:ToggleConfigPanel()
            end
        end)
        
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("ZulgAuras Tracker")
            GameTooltip:AddLine("Left-Click: Open configuration", 1, 1, 1)
            GameTooltip:AddLine("Drag: Move icon", 1, 1, 1)
            GameTooltip:Show()
        end)
        
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Show/hide based on settings
        button:SetShown(not self.db.minimapIcon.hide)
        
        self.minimapButton = button
    end
    
    -- Create the configuration panel
    function ZA:CreateConfigPanel()
        local panel = CreateFrame("Frame", "ZA_ConfigPanel", UIParent, "BasicFrameTemplate")
        panel:SetSize(400, 350)
        panel:SetPoint("CENTER")
        panel:Hide()
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        
        panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        panel.title:SetPoint("TOPLEFT", 15, -4) -- Updated position as requested
        panel.title:SetText("CooldownBuffDebuffTracker Configuration")
        
        local y = -50
        
        -- Create toggle for each line
        local function CreateToggle(text, setting, updateFunc)
            local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 20, y)
            check.text:SetText(text)
            check:SetChecked(setting.enabled)
            
            check:SetScript("OnClick", function(self)
                setting.enabled = self:GetChecked()
                if updateFunc then updateFunc() end
            end)
            
            -- Create scale slider
            local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
            slider:SetWidth(200)
            slider:SetHeight(20)
            slider:SetPoint("TOPLEFT", 120, y - 2)
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
            
            y = y - 35
            return check, slider
        end
        
        -- Create width slider for each line
        local function CreateWidthSlider(text, setting, updateFunc)
            local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", 20, y)
            label:SetText(text)
            
            local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
            slider:SetWidth(200)
            slider:SetHeight(20)
            slider:SetPoint("TOPLEFT", 120, y - 2)
            slider:SetMinMaxValues(200, 600)
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
            
            y = y - 35
            return slider
        end
        
        -- Cooldown line toggle and slider
        panel.cooldownToggle, panel.cooldownSlider = CreateToggle("Enable Cooldowns", self.db.cooldownLine, function()
            self.cooldownLine:SetShown(self.db.cooldownLine.enabled)
            self.cooldownLine:SetScale(self.db.cooldownLine.scale)
        end)
        
        panel.cooldownWidthSlider = CreateWidthSlider("Cooldown Line Width", self.db.cooldownLine, function()
            self.cooldownLine:SetWidth(self.db.cooldownLine.width)
            -- Recreate time markers with new width
            for _, marker in ipairs(self.cooldownLine.markers) do
                marker:Hide()
            end
            self.cooldownLine.markers = self:AddTimeMarkers(self.cooldownLine, {5, 10, 15, 20, 25}, 30)
        end)
        
        -- Buff line toggle and slider
        panel.buffToggle, panel.buffSlider = CreateToggle("Enable Buffs", self.db.buffLine, function()
            self.buffLine:SetShown(self.db.buffLine.enabled)
            self.buffLine:SetScale(self.db.buffLine.scale)
        end)
        
        panel.buffWidthSlider = CreateWidthSlider("Buff Line Width", self.db.buffLine, function()
            self.buffLine:SetWidth(self.db.buffLine.width)
            -- Recreate time markers with new width
            for _, marker in ipairs(self.buffLine.markers) do
                marker:Hide()
            end
            self.buffLine.markers = self:AddTimeMarkers(self.buffLine, {5, 10, 15, 20, 25}, 30)
        end)
        
        -- Debuff line toggle and slider
        panel.debuffToggle, panel.debuffSlider = CreateToggle("Enable Debuffs", self.db.debuffLine, function()
            self.debuffLine:SetShown(self.db.debuffLine.enabled)
            self.debuffLine:SetScale(self.db.debuffLine.scale)
        end)
        
        panel.debuffWidthSlider = CreateWidthSlider("Debuff Line Width", self.db.debuffLine, function()
            self.debuffLine:SetWidth(self.db.debuffLine.width)
            -- Recreate time markers with new width
            for _, marker in ipairs(self.debuffLine.markers) do
                marker:Hide()
            end
            self.debuffLine.markers = self:AddTimeMarkers(self.debuffLine, {5, 10}, 15)
        end)
        
        -- Minimap icon toggle
        panel.minimapToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        panel.minimapToggle:SetPoint("TOPLEFT", 20, y)
        panel.minimapToggle.text:SetText("Show Minimap Icon")
        panel.minimapToggle:SetChecked(not self.db.minimapIcon.hide)
        
        panel.minimapToggle:SetScript("OnClick", function(self)
            ZA.db.minimapIcon.hide = not self:GetChecked()
            ZA.minimapButton:SetShown(not ZA.db.minimapIcon.hide)
        end)
        
        y = y - 35
        
        -- Reset positions button
        panel.resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.resetButton:SetSize(150, 24)
        panel.resetButton:SetPoint("TOPLEFT", 20, y)
        panel.resetButton:SetText("Reset Positions")
        
        panel.resetButton:SetScript("OnClick", function()
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
        
        -- Reset all button
        panel.resetAllButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.resetAllButton:SetSize(150, 24)
        panel.resetAllButton:SetPoint("TOPLEFT", 200, y)
        panel.resetAllButton:SetText("Reset All Settings")
        
        panel.resetAllButton:SetScript("OnClick", function()
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
        
        y = y - 35
        
        -- Close button
        panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        panel.closeButton:SetSize(80, 24)
        panel.closeButton:SetPoint("BOTTOMRIGHT", -10, 10)
        panel.closeButton:SetText("Close")
        panel.closeButton:SetScript("OnClick", function() panel:Hide() end)
        
        -- Version text
        panel.versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.versionText:SetPoint("BOTTOMLEFT", 10, 10)
        panel.versionText:SetText("Version: " .. ZA.version)
        
        -- When hiding the panel, hide the headers
        panel:SetScript("OnHide", function() 
            ZA:SetHeadersVisible(false)
        end)
        
        -- When showing the panel, show the headers
        panel:SetScript("OnShow", function()
            ZA:SetHeadersVisible(true)
        end)
        
        self.configPanel = panel
    end
    
    -- Toggle the configuration panel
    function ZA:ToggleConfigPanel()
        if self.configPanel:IsShown() then
            self.configPanel:Hide()
        else
            self.configPanel:Show()
        end
    end
    
    -- Clean up stale icons (those that should no longer be displayed)
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
    
    -- Initialize the addon
    function ZA:Initialize()
        self:InitializeDB()
        self:CreateTrackerLines()
        self:CreateMinimapButton()
        self:CreateConfigPanel()
        
        -- Register events
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        
        eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
            if event == "ADDON_LOADED" and arg1 == addonName then
                ZA:OnAddonLoaded()
            elseif event == "PLAYER_ENTERING_WORLD" then
                ZA:UpdateAllLines()
            elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
                ZA:UpdateCooldownLine()
            elseif event == "UNIT_AURA" and arg1 == "player" then
                ZA:UpdateBuffLine()
                if UnitExists("target") then
                    ZA:UpdateDebuffLine()
                end
            elseif event == "PLAYER_TARGET_CHANGED" then
                ZA:UpdateDebuffLine()
            end
        end)
        
        -- Set up a timer to periodically clean up stale icons
        C_Timer.NewTicker(2, function() ZA:CleanupStaleIcons() end)
        
        -- This function updates all the lines at once
        function ZA:UpdateAllLines()
            self:UpdateCooldownLine()
            self:UpdateBuffLine()
            self:UpdateDebuffLine()
        end
        
        -- This function is called when the addon is loaded
        function ZA:OnAddonLoaded()
            print("|cff33ff99CooldownBuffDebuffTracker_ZulgAuras|r loaded. Type |cffff6600/za|r to open the configuration panel.")
        end
        
        -- Create slash command
        SLASH_ZULGAURAS1 = "/za"
        SlashCmdList["ZULGAURAS"] = function(msg)
            ZA:ToggleConfigPanel()
        end
        
        -- Initial update
        self:UpdateAllLines()
    end
    
    -- Start the addon
    ZA:Initialize()