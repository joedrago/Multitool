local addonName, MT = ...

-- Re-applied every login. Only anchors, bounds and post-hooks: no Blizzard globals or
-- script handlers are replaced, so secure chat code never reads addon-written values.

local function chatFrames()
    local frames = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then
            table.insert(frames, frame)
        end
    end
    return frames
end

local function unclamp(frame)
    local raw = frame.SetClampRectInsets
    raw(frame, 0, 0, 0, 0)
    hooksecurefunc(frame, "SetClampRectInsets", function(self)
        raw(self, 0, 0, 0, 0)
    end)
end

local function unlimitSize(frame)
    local _, _, maxW, maxH = frame:GetResizeBounds()
    frame:SetResizeBounds(100, 10, maxW, maxH)
end

local function editBoxOnTop(frame)
    local eb = frame.editBox or _G[frame:GetName() .. "EditBox"]
    eb:ClearAllPoints()
    eb:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -5, -2)
    eb:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 5, -2)
end

-- Tabs stay fully hidden until the window is moused over (hasBeenFaded) or the tab is alerting.
local function hideTab(frame)
    local tab = _G[frame:GetName() .. "Tab"]
    local raw = tab.SetAlpha
    local function apply(self)
        if not frame.hasBeenFaded and not ChatFrameUtil.IsTabAlerting(self) then
            raw(self, 0)
        end
    end
    hooksecurefunc(tab, "SetAlpha", apply)
    apply(tab)
end

local function applyChatTweaks()
    for _, frame in ipairs(chatFrames()) do
        unclamp(frame)
        unlimitSize(frame)
        editBoxOnTop(frame)
        hideTab(frame)
    end
end

-- Background opacity for the General and Combat Log windows. Blizzard saves it per window, and
-- /tool fade scales whatever is set here, so nothing else needs to know about it.
local CHAT_ALPHA = 0.5

function MT.applyChatAlpha()
    local alpha = MT.db().chatAlpha or CHAT_ALPHA
    for i = 1, 2 do
        FCF_SetWindowAlpha(_G["ChatFrame" .. i], alpha)
    end
end

function MT.chatAlpha(msg)
    local db = MT.db()
    msg = strtrim(msg or "")
    if msg ~= "" then
        local alpha = tonumber(msg)
        if not alpha or alpha < 0 or alpha > 1 then
            MT.error("usage: /tool chat <0 to 1>")
            return
        end
        db.chatAlpha = alpha
        MT.applyChatAlpha()
    end
    MT.print("chat background opacity is " .. (db.chatAlpha or CHAT_ALPHA) .. ".")
end

MT.register("chat", "set the General and Combat Log background opacity, also used by /tool init. /tool chat 0.5", MT.chatAlpha)

function MT.enableChatTweaks()
    MT.db().chatTweaks = true
    SetCVar("chatStyle", "classic")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        if MT.db().chatTweaks then
            applyChatTweaks()
        end
    end
end)
