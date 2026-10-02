local addonName, MT = ...

-- Blizzard re-anchors the bar from AdjustPosition (target change, ToT, aura rows) and on
-- every show, so the override is re-applied after each of those.
-- Coordinates are the bar's center relative to UIParent's center, in UIParent units.

local bar = TargetFrameSpellBar

local function num(v)
    return type(v) == "number" and v or nil
end

-- Converts between UIParent units and the bar's own units (it inherits TargetFrame's scale).
local function scaleRatio()
    return bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function apply()
    local pos = MT.db().targetCast
    if not pos then
        return
    end
    local ratio = scaleRatio()
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", pos.x / ratio, pos.y / ratio)
end

local function currentPos()
    local bx, by = bar:GetCenter()
    local ux, uy = UIParent:GetCenter()
    bx, by, ux, uy = num(bx), num(by), num(ux), num(uy)
    if not (bx and by and ux and uy) then
        return nil
    end
    local ratio = scaleRatio()
    return math.floor(bx * ratio - ux + 0.5), math.floor(by * ratio - uy + 0.5)
end

function MT.targetCast(msg)
    if not bar then
        MT.error("this client has no TargetFrameSpellBar.")
        return
    end

    local db = MT.db()
    msg = strtrim(msg or ""):lower()

    if msg == "" then
        local x, y = currentPos()
        local where = x and (x .. " " .. y) or "unknown (target something first)"
        MT.print("target cast bar is at " .. where .. (db.targetCast and " (forced)" or " (Blizzard default)"))
        return
    end

    if msg == "reset" then
        db.targetCast = nil
        bar:AdjustPosition()
        MT.print("target cast bar returned to the Blizzard default.")
        return
    end

    local x, y = msg:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
    x, y = tonumber(x), tonumber(y)
    if not (x and y) then
        MT.error("usage: /tool targetcast [X Y | reset]")
        return
    end
    db.targetCast = { x = x, y = y }
    apply()
    MT.print("target cast bar forced to " .. x .. " " .. y)
end

if bar then
    hooksecurefunc(bar, "AdjustPosition", apply)
    bar:HookScript("OnShow", apply)

    -- MultitoolDB isn't loaded until ADDON_LOADED.
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == addonName then
            self:UnregisterAllEvents()
            apply()
        end
    end)
end

MT.register("targetcast", "show or force the target cast bar position (center offset from screen center). /tool targetcast [X Y | reset]", MT.targetCast)
