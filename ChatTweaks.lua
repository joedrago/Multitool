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
