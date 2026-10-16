local addonName, MT = ...

-- Fades groups of frames out after a stretch out of combat with the mouse away from them.
-- Each group keeps its own clock: hovering one brings back just that group. Combat or
-- Edit Mode brings back everything. Faded frames keep taking clicks.
--
-- A group:
--   fade  frames whose alpha is scaled (children follow along)
--   hover extra frames that count as hovering the group, e.g. children outside the parent's rect
--   hide  frames hidden once fully faded, because the engine draws parts of them
--         (minimap arrow, tracking blips) without regard to alpha
--   awake optional function; while it returns true the group stays shown
--   apply optional function(alpha) for anything that needs more than a plain SetAlpha
--   floor optional function; the alpha the group stops at instead of 0 while idle

local FADE_OUT_SECONDS = 1.5
local FADE_IN_SECONDS = 0.15
local UNIT_FLOOR = 0.5 -- default for /tool fade unit
local BARS_SETTLED_SECONDS = 7 -- comfortably longer than mana's 5 second pause after casting
local TARGET_RECENT_SECONDS = 5
local CHAT_TEXT_FLOOR = 0.5 -- default for /tool fade chat

-- Some values can be secret on this engine; comparing one is an error.
local function num(v)
    if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then
        return nil
    end
    return v
end

local function plainString(v)
    return type(v) == "string" and not (issecretvalue and issecretvalue(v))
end

-- Health and power are secret, so instead of comparing them to their max we watch for change:
-- out of combat they only move while regenerating (or draining, for rage), and stop once settled.
local barsChanged = -math.huge
local barWatcher = CreateFrame("Frame")
barWatcher:RegisterUnitEvent("UNIT_HEALTH", "player")
barWatcher:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
barWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
barWatcher:RegisterUnitEvent("UNIT_MAXPOWER", "player")
barWatcher:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
barWatcher:SetScript("OnEvent", function(_, event, _, powerToken)
    -- Only the primary bar counts; combo points and the like aren't what the frame is showing.
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        local _, primaryToken = UnitPowerType("player")
        if plainString(powerToken) and plainString(primaryToken) and powerToken ~= primaryToken then
            return
        end
    end
    barsChanged = GetTime()
end)

-- How far the player and target frames fade while they still matter: in combat, while the
-- player's bars are moving, or right after picking a target. 0 is a real setting, so no "or nil".
local function unitFloor()
    return MT.db().unitFloor or UNIT_FLOOR
end

-- How far the main chat window's text fades once its background is gone. 0 is a real setting.
local function chatTextFloor()
    return MT.db().chatTextFloor or CHAT_TEXT_FLOOR
end

local function inCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function playerAtRest()
    return GetTime() - barsChanged >= BARS_SETTLED_SECONDS
end

local targetChanged = -math.huge
local targetWatcher = CreateFrame("Frame")
targetWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
targetWatcher:SetScript("OnEvent", function()
    targetChanged = GetTime()
end)

local function targetIsNew()
    return GetTime() - targetChanged < TARGET_RECENT_SECONDS
end

local xpChanged = -math.huge
local xpWatcher = CreateFrame("Frame")
xpWatcher:RegisterEvent("PLAYER_XP_UPDATE")
xpWatcher:SetScript("OnEvent", function()
    xpChanged = GetTime()
end)

-- Recent means within the fade delay, so a kill keeps the bar up about as long as a hover would.
local function xpIsNew()
    return GetTime() - xpChanged < (MT.db().fade or 0)
end

local function chatFrameNames(suffix)
    local names = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        table.insert(names, "ChatFrame" .. i .. suffix)
    end
    return names
end

local chatFrames = chatFrameNames("")
local chatEditBoxes = chatFrameNames("EditBox")

-- Blizzard fades chat backgrounds itself on mouseover, so their SetAlpha is hooked and
-- whatever Blizzard asks for is scaled by our multiplier instead of being overwritten.
local chromeAlpha = {} -- what Blizzard last asked for
local chromeScale = {} -- our multiplier
local chromeRaw = {} -- the unhooked SetAlpha

local function scaleChrome(object, scale)
    if not chromeRaw[object] then
        if scale == 1 then
            return
        end
        local raw = object.SetAlpha
        chromeRaw[object] = raw
        chromeAlpha[object] = num(object:GetAlpha()) or 1
        hooksecurefunc(object, "SetAlpha", function(self, alpha)
            chromeAlpha[self] = num(alpha) or 1
            raw(self, chromeAlpha[self] * chromeScale[self])
        end)
    end
    chromeScale[object] = scale
    chromeRaw[object](object, chromeAlpha[object] * scale)
end

-- The window background and border, plus the button frame (its own textures ride along with it).
local function eachChrome(chatFrame, fn)
    local name = chatFrame:GetName()
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local texture = _G[name .. suffix]
        if texture and not suffix:find("^ButtonFrame") then
            fn(texture)
        end
    end
    if chatFrame.buttonFrame then
        fn(chatFrame.buttonFrame)
    end
end

-- The main window is everything in the dock. Docking can change at any time, so it's checked
-- live rather than baked into the groups' frame lists.
local function eachChatFrame(docked, fn)
    for _, name in ipairs(chatFrames) do
        local chatFrame = _G[name]
        -- isDocked is 1 or nil, not a boolean.
        if chatFrame and (not not chatFrame.isDocked or chatFrame == DEFAULT_CHAT_FRAME) == docked then
            fn(chatFrame)
        end
    end
end

local function chatHovered(docked)
    local found = false
    eachChatFrame(docked, function(chatFrame)
        found = found or (chatFrame:IsVisible() and chatFrame:IsMouseOver())
    end)
    return found
end

local function typing()
    for _, name in ipairs(chatEditBoxes) do
        local editBox = _G[name]
        if editBox and editBox:HasFocus() then
            return true
        end
    end
    return false
end

-- The main window loses its chrome but only dims its text, so it stays readable.
-- Tabs are left alone: ChatTweaks already hides them.
local function applyMainChat(alpha)
    local floor = chatTextFloor()
    local textAlpha = floor + (1 - floor) * alpha
    eachChatFrame(true, function(chatFrame)
        chatFrame:SetAlpha(textAlpha)
        eachChrome(chatFrame, function(object)
            scaleChrome(object, alpha)
        end)
    end)
end

-- Undocked windows (e.g. a separate Combat Log) fade entirely.
local function applyOtherChat(alpha)
    eachChatFrame(false, function(chatFrame)
        chatFrame:SetAlpha(alpha)
        eachChrome(chatFrame, function(object)
            scaleChrome(object, 1)
        end)
    end)
end

local unitFrameHover = {
    "PlayerFrame", "PersonalResourceDisplayFrame", "PetFrame", "TargetFrame", "TargetFrameToT", "FocusFrame", "FocusFrameToT",
    "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager",
}

local actionBarHover = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar",
}

local GROUPS = {
    {
        fade = { "MinimapCluster" },
        hide = { "Minimap" }, -- only reached with a minimap floor of 0
        floor = function()
            return MT.db().minimapFloor or 0
        end,
    },
    {
        fade = { "QuickJoinToastButton" },
        apply = applyMainChat,
        awake = function()
            return typing() or chatHovered(true)
        end,
    },
    {
        fade = {},
        apply = applyOtherChat,
        awake = function()
            return chatHovered(false)
        end,
    },
    -- Action bars are split so the main bar can stop at its own floor; they share a hover list
    -- so hovering any bar brings back all of them.
    {
        fade = { "MainActionBar" },
        hover = actionBarHover,
        hoverOnly = true,
        floor = function()
            return inCombat() and MT.db().mainBarFloor or 0
        end,
    },
    {
        fade = {
            "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
            "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar",
        },
        hover = actionBarHover,
        hoverOnly = true,
    },
    -- Unit frames are split so the player and target frames can stop at their own floors; they
    -- share a hover list so hovering any unit frame brings back all of them.
    {
        fade = { "PlayerFrame", "PersonalResourceDisplayFrame", "PartyFrame" },
        hover = unitFrameHover,
        hoverOnly = true,
        floor = function()
            return (inCombat() or not playerAtRest()) and unitFloor() or 0
        end,
    },
    {
        fade = { "TargetFrame" },
        hover = unitFrameHover,
        hoverOnly = true,
        floor = function()
            return (inCombat() or targetIsNew()) and unitFloor() or 0
        end,
    },
    {
        fade = { "FocusFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" },
        hover = unitFrameHover,
        hoverOnly = true,
    },
    {
        -- The session windows are children, but can sit anywhere; DamageMeter's own rect is just a placeholder.
        fade = { "DamageMeter" },
        hover = { "DamageMeterSessionWindow1", "DamageMeterSessionWindow2", "DamageMeterSessionWindow3" },
        hoverOnly = true,
        floor = function()
            return inCombat() and IsInGroup() and MT.db().damageFloor or 0
        end,
    },
    {
        fade = { "BagsBar" },
    },
    {
        fade = { "MicroMenuContainer" },
    },
    {
        -- The manager has no size of its own; the containers are what's on screen.
        fade = { "StatusTrackingBarManager" },
        hover = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" },
        hoverOnly = true,
        floor = function()
            return xpIsNew() and MT.db().xpFloor or 0
        end,
    },
    {
        fade = { "ObjectiveTrackerFrame" },
    },
    {
        fade = { "BuffFrame", "DebuffFrame" },
    },
}

local driver = CreateFrame("Frame")

-- Frames that don't exist on this client (or haven't been created yet) are skipped.
local function eachFrame(names, fn)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            fn(frame)
        end
    end
end

for _, group in ipairs(GROUPS) do
    group.alpha = 1
    group.lastActive = GetTime()
    group.base = {} -- each frame's own alpha (e.g. Edit Mode opacity) before we started fading it
    group.hidden = {} -- frames we hid, so one the player hid themselves stays hidden
end

local function canToggle(frame)
    return not (InCombatLockdown() and frame:IsProtected())
end

-- A protected frame can't be shown in combat, so it stays on the list for later.
local function showHidden(group)
    for frame in pairs(group.hidden) do
        if canToggle(frame) then
            frame:Show()
            group.hidden[frame] = nil
        end
    end
end

-- Regions that ignore their parents' alpha, so they have to be faded by hand. Each maps to the
-- group it fades with, or false if it isn't inside any of ours (e.g. a nameplate).
local detached = {}

local function setAlpha(group, a)
    if a > 0 then
        showHidden(group)
    end
    if group.alpha == 1 and a < 1 then
        eachFrame(group.fade, function(frame)
            group.base[frame] = num(frame:GetAlpha()) or 1
        end)
    end
    group.alpha = a
    eachFrame(group.fade, function(frame)
        frame:SetAlpha((group.base[frame] or 1) * a)
    end)
    for region, owner in pairs(detached) do
        if owner == group then
            region:SetAlpha(a)
        end
    end
    if group.apply then
        group.apply(a)
    end
    if a == 0 and group.hide then
        eachFrame(group.hide, function(frame)
            if frame:IsShown() and canToggle(frame) then
                frame:Hide()
                group.hidden[frame] = true
            end
        end)
    end
end

local function owningGroup(frame)
    while frame do
        for _, group in ipairs(GROUPS) do
            for _, name in ipairs(group.fade) do
                if _G[name] == frame then
                    return group
                end
            end
        end
        frame = frame:GetParent()
    end
    return nil
end

-- Party and raid frames draw their target highlight with ignoreParentAlpha, which would leave a
-- bright rectangle behind on a faded frame. Each one is picked up the first time Blizzard updates
-- it, and caught up to its group's alpha whenever Blizzard touches it after that.
if CompactUnitFrame_UpdateSelectionHighlight then
    hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", function(frame)
        local highlight = frame.selectionHighlight
        if not highlight then
            return
        end
        if detached[highlight] == nil then
            detached[highlight] = owningGroup(frame) or false
        end
        local group = detached[highlight]
        if group then
            highlight:SetAlpha(group.alpha)
        end
    end)
end

local function hovered(names)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame:IsVisible() and frame:IsMouseOver() then
            return true
        end
    end
    return false
end

local function isActive(group)
    if not group.hoverOnly and hovered(group.fade) then
        return true
    end
    if group.hover and hovered(group.hover) then
        return true
    end
    return group.awake ~= nil and group.awake()
end

local function everythingActive()
    if MT.db().fadeCombat ~= false and inCombat() then
        return true
    end
    return EditModeManagerFrame ~= nil and EditModeManagerFrame:IsEditModeActive()
end

local function onUpdate(_, elapsed)
    local now = GetTime()
    local delay = MT.db().fade
    local all = everythingActive()
    for _, group in ipairs(GROUPS) do
        if all or isActive(group) then
            group.lastActive = now
        end
        local target = 1
        if now - group.lastActive >= delay then
            target = group.floor and group.floor() or 0
        end
        if target > group.alpha then
            setAlpha(group, math.min(target, group.alpha + elapsed / FADE_IN_SECONDS))
        elseif target < group.alpha then
            setAlpha(group, math.max(target, group.alpha - elapsed / FADE_OUT_SECONDS))
        end
    end
end

local function refresh()
    for _, group in ipairs(GROUPS) do
        group.lastActive = GetTime()
    end
    if (MT.db().fade or 0) > 0 then
        driver:SetScript("OnUpdate", onUpdate)
    else
        driver:SetScript("OnUpdate", nil)
        for _, group in ipairs(GROUPS) do
            setAlpha(group, 1)
        end
    end
end

local function printFade()
    local db = MT.db()
    local seconds = db.fade or 0
    if seconds == 0 then
        MT.print("fade is off.")
        return
    elseif db.fadeCombat == false then
        MT.print("fading after " .. seconds .. "s without hovering, even in combat.")
    else
        MT.print("fading after " .. seconds .. "s out of combat.")
    end
    local floor = db.minimapFloor or 0
    MT.print(floor > 0 and ("the minimap fades to " .. floor .. ".") or "the minimap fades out completely.")
    local main = db.mainBarFloor or 0
    MT.print(main > 0 and ("the main action bar fades to " .. main .. " in combat.") or "the main action bar fades out completely.")
    MT.print("player, party and target frames fade to " .. unitFloor() .. " while they matter.")
    local damage = db.damageFloor or 0
    MT.print(damage > 0 and ("the damage meter fades to " .. damage .. " in combat in a group.") or "the damage meter fades out completely.")
    local xp = db.xpFloor or 0
    MT.print(xp > 0 and ("the xp bar fades to " .. xp .. " after gaining xp.") or "the xp bar fades out completely.")
    MT.print("main chat text fades to " .. chatTextFloor() .. ".")
end

local FADE_USAGE = "usage: /tool fade <seconds, 0 = off> | combat <on | off> | minimap <0 to 1> | main <0 to 1> | unit <0 to 1> | damage <0 to 1> | xp <0 to 1> | chat <0 to 1>"

local function fraction(value)
    local n = tonumber(value)
    return n and n >= 0 and n <= 1 and n or nil
end

function MT.fade(msg)
    local db = MT.db()
    msg = strtrim(msg or ""):lower()
    local option, value = msg:match("^(%a+)%s*(.-)$")
    if option == "combat" and (value == "on" or value == "off") then
        -- Combat bringing everything back is the default, so only "off" is stored.
        if value == "off" then
            db.fadeCombat = false
        else
            db.fadeCombat = nil
        end
    elseif option == "minimap" and fraction(value) then
        local floor = fraction(value)
        db.minimapFloor = floor > 0 and floor or nil
    elseif option == "main" and fraction(value) then
        local floor = fraction(value)
        db.mainBarFloor = floor > 0 and floor or nil
    elseif option == "unit" and fraction(value) then
        db.unitFloor = fraction(value)
    elseif option == "damage" and fraction(value) then
        local floor = fraction(value)
        db.damageFloor = floor > 0 and floor or nil
    elseif option == "xp" and fraction(value) then
        local floor = fraction(value)
        db.xpFloor = floor > 0 and floor or nil
    elseif option == "chat" and fraction(value) then
        db.chatTextFloor = fraction(value)
        -- The text alpha is derived from the group's alpha, so redraw it if it's already faded.
        for _, group in ipairs(GROUPS) do
            if group.apply == applyMainChat then
                setAlpha(group, group.alpha)
            end
        end
    elseif option == nil and tonumber(msg) and tonumber(msg) >= 0 then
        local seconds = tonumber(msg)
        db.fade = seconds > 0 and seconds or nil
        refresh()
    elseif msg ~= "" then
        MT.error(FADE_USAGE)
        return
    end
    printFade()
end

-- Protected frames can only be shown or hidden out of combat. PLAYER_REGEN_DISABLED handlers
-- still run before lockdown starts, so any protected frame we hid is shown there (it couldn't be
-- brought back by hovering in combat). Once combat ends, anything still faded out gets hidden.
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(_, event)
    for _, group in ipairs(GROUPS) do
        if event == "PLAYER_REGEN_DISABLED" then
            for frame in pairs(group.hidden) do
                if frame:IsProtected() then
                    frame:Show()
                    group.hidden[frame] = nil
                end
            end
        elseif group.alpha == 0 then
            setAlpha(group, 0)
        end
    end
end)

-- MultitoolDB isn't loaded until ADDON_LOADED.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name == addonName then
        self:UnregisterAllEvents()
        refresh()
    end
end)

MT.register("fade", "fade most of the UI after N seconds out of combat; hover a piece or enter combat to bring it back. /tool fade N (0 = off) | combat <on | off> | minimap <0 to 1> | main <0 to 1> | unit <0 to 1> | damage <0 to 1> | xp <0 to 1> | chat <0 to 1>", MT.fade)
