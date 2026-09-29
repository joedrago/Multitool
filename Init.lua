local _, MT = ...

-- Groups this client doesn't know are skipped, so these can stay a superset across flavors.

local panel1 = [=[
    SAY
    EMOTE
    YELL
    GUILD
    OFFICER
    WHISPER
    BN_WHISPER
    PARTY
    PARTY_LEADER
    RAID
    RAID_LEADER
    RAID_WARNING
    INSTANCE_CHAT
    INSTANCE_CHAT_LEADER
]=]

local panel2 = [=[
    ACHIEVEMENT
    AFK
    BG_ALLIANCE
    BG_HORDE
    BG_NEUTRAL
    BN_CONVERSATION
    BN_INLINE_TOAST_ALERT
    BN_WHISPER
    BN_WHISPER_INFORM
    BN_WHISPER_PLAYER_OFFLINE
    CHANNEL
    COMBAT_FACTION_CHANGE
    COMBAT_HONOR_GAIN
    COMBAT_MISC_INFO
    COMBAT_XP_GAIN
    CURRENCY
    DND
    EMOTE
    ERRORS
    GUILD_ACHIEVEMENT
    GUILD_ITEM_LOOTED
    IGNORED
    LOOT
    MONEY
    MONSTER_BOSS_EMOTE
    MONSTER_BOSS_WHISPER
    MONSTER_EMOTE
    MONSTER_SAY
    MONSTER_WHISPER
    MONSTER_YELL
    OPENING
    PET_BATTLE_COMBAT_LOG
    PET_BATTLE_INFO
    PET_INFO
    PING
    SKILL
    SYSTEM
    SYSTEM_NOMENU
    TARGETICONS
    TRADESKILLS
]=]

local function knownGroup(s)
    return ChatTypeGroup and ChatTypeGroup[s] ~= nil
end

local function addAll(panelIndex, list)
    for s in list:gmatch("[^\r\n]+") do
        s = strtrim(s)
        if s ~= "" and knownGroup(s) then
            AddChatWindowMessages(panelIndex, s)
        end
    end
end

local function removeEverything(panelIndex)
    for s in pairs(ChatTypeGroup) do
        RemoveChatWindowMessages(panelIndex, s)
    end
end

local function initChat()
    removeEverything(1)
    addAll(1, panel1)

    removeEverything(2)
    addAll(2, panel2)

    ChangeChatColor("GUILD", 0/255, 245/255, 255/255)
    ChangeChatColor("OFFICER", 0/255, 245/255, 255/255)
    ChangeChatColor("PARTY", 0/255, 255/255, 117/255)
    ChangeChatColor("PARTY_LEADER", 0/255, 255/255, 117/255)

    for i = 1, 2 do
        local frame = _G["ChatFrame" .. i]
        FCF_SetWindowColor(frame, 0, 0, 0)
        FCF_SetWindowAlpha(frame, 1)
    end
end

-- GetChatWindowChannels returns name1, zone1, name2, zone2, ...
local function initChannels()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local channels = { GetChatWindowChannels(i) }
        for j = 1, #channels, 2 do
            RemoveChatWindowChannel(i, channels[j])
        end
        local frame = _G["ChatFrame" .. i]
        if frame then
            frame.channelList = {}
            frame.zoneChannelList = {}
        end
    end
end

-- Bars 2-8; bar 1 is always shown.
local function initActionBars()
    SetActionBarToggles(true, true, true, true, true, true, true)
end

-- No enum for modifier bits. Left and right Shift are separate bits that both display
-- as "SHIFT", and a real Shift binding stores them combined (3), so sum every match.
local function shiftModifier()
    local shift = 0
    for bit = 0, 15 do
        local m = 2 ^ bit
        local s = (GetStringFromModifiers(m) or ""):upper()
        if s == "SHIFT" or s == (SHIFT_KEY_TEXT or "SHIFT"):upper() then
            shift = shift + m
        end
    end
    return shift > 0 and shift or nil
end

local BUTTON_ALIASES = { Button1 = "LeftButton", Button2 = "RightButton" }

-- Frees plain clicks for Click Casting.
local function initClickBindings()
    if not C_ClickBindings then
        return
    end
    local shift = shiftModifier()
    if not shift then
        MT.error("couldn't find the Shift modifier; click bindings unchanged.")
        return
    end

    local interaction = Enum.ClickBindingType.Interaction
    local want = {
        [Enum.ClickBindingInteraction.Target] = "LeftButton",
        [Enum.ClickBindingInteraction.OpenContextMenu] = "RightButton",
    }

    local profile = C_ClickBindings.GetProfileInfo()
    local found, changed = {}, false
    for _, b in ipairs(profile) do
        local button = b.type == interaction and want[b.actionID]
        if button then
            found[b.actionID] = true
            if (BUTTON_ALIASES[b.button] or b.button) ~= button or b.modifiers ~= shift then
                b.button, b.modifiers = button, shift
                changed = true
            end
        end
    end
    for actionID, button in pairs(want) do
        if not found[actionID] then
            table.insert(profile, { type = interaction, actionID = actionID, button = button, modifiers = shift })
            changed = true
        end
    end

    if changed then
        C_ClickBindings.SetProfileByInfo(profile)
    end
end

-- SetActiveLayout indexes presets (Modern, Classic) first, then saved layouts.
function MT.allLayouts()
    local layouts = {}
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        for _, l in ipairs(EditModePresetLayoutManager:GetCopyOfPresetLayouts()) do
            table.insert(layouts, l)
        end
    else
        layouts = { {}, {} }
    end
    local info = C_EditMode.GetLayouts()
    for _, l in ipairs(info.layouts) do
        table.insert(layouts, l)
    end
    return layouts, info.activeLayout
end

local function findLayout(name)
    local layouts, active = MT.allLayouts()
    local names = {}
    for i, l in ipairs(layouts) do
        if l.layoutName then
            if l.layoutName:lower() == name:lower() then
                return i, active
            end
            table.insert(names, l.layoutName)
        end
    end
    return nil, active, names
end

local function initLayout(index, active)
    if index ~= active then
        C_EditMode.SetActiveLayout(index)
    end
end

local steps = {
    initChat,
    initChannels,
    MT.enableChatTweaks,
    MT.restoreChatPos,
    initActionBars,
    initClickBindings,
}

function MT.init(msg)
    if InCombatLockdown() then
        MT.error("can't init during combat.")
        return
    end
    if not C_EditMode then
        MT.error("this client has no UI Layouts (Edit Mode).")
        return
    end

    local db = MT.db()
    local name = strtrim(msg or "")
    if name == "" then
        name = db.layoutName
    end
    if not name then
        MT.error("No UI Layout name chosen. Please specify: /tool init SomeUILayoutName")
        return
    end

    local index, active, names = findLayout(name)
    if not index then
        MT.error("No UI Layout named \"" .. name .. "\". Available: " .. table.concat(names, ", "))
        return
    end
    db.layoutName = name

    initLayout(index, active)
    for _, step in ipairs(steps) do
        step()
    end
    ReloadUI()
end

MT.register("init", "apply preferred character settings and UI (reloads UI). /tool init [UILayoutName]", MT.init)
