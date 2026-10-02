local _, MT = ...

local SOUL_SHARD = 6265
local SOUL_BAG_FAMILY = 4 -- fallback if the shard's item family isn't cached yet

local getItemFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily

-- Container values can be secret on this engine; anything not a plain number is unknown.
local function num(v)
    return type(v) == "number" and v or nil
end

local function isSoulBag(bag, shardFamily)
    if bag == 0 then
        return false
    end
    local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
    bagFamily = num(bagFamily)
    return bagFamily ~= nil and bagFamily ~= 0 and bit.band(bagFamily, shardFamily) ~= 0
end

local function cursorHoldsShard()
    local kind, itemID = GetCursorInfo()
    return kind == "item" and itemID == SOUL_SHARD
end

-- Everything runs synchronously inside the macro's key press. Anything left over
-- (extra shards, locked slots, full soul bag) is handled on the next press.
-- Combat is skipped because the server reverts in-combat deletes when combat ends.
function MT.shards(msg)
    if InCombatLockdown() or UnitAffectingCombat("player") then
        return
    end
    local keep = tonumber(strtrim(msg or ""))
    if not keep or keep < 0 then
        MT.error("usage: /tool shards <number to keep>")
        return
    end
    if GetCursorInfo() then
        return
    end

    local shardFamily = num(getItemFamily(SOUL_SHARD)) or SOUL_BAG_FAMILY
    local inSoulBag, elsewhere, freeSoulSlots = {}, {}, {}
    for bag = 0, NUM_BAG_SLOTS do
        local soulBag = isSoulBag(bag, shardFamily)
        for slot = 1, num(C_Container.GetContainerNumSlots(bag)) or 0 do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if num(itemID) == SOUL_SHARD then
                table.insert(soulBag and inSoulBag or elsewhere, { bag = bag, slot = slot })
            elseif itemID == nil and soulBag then
                table.insert(freeSoulSlots, { bag = bag, slot = slot })
            end
        end
    end

    -- The game allows only one delete per key press, so trim one shard and stop;
    -- moves wait until nothing is left to delete. Outside the soul bag goes first, back to front.
    -- A locked slot fails the pickup, and the next press tries again.
    local excess = #inSoulBag + #elsewhere - keep
    if excess > 0 then
        local list = #elsewhere > 0 and elsewhere or inSoulBag
        local loc = list[#list]
        C_Container.PickupContainerItem(loc.bag, loc.slot)
        if not cursorHoldsShard() then
            ClearCursor()
            return
        end
        DeleteCursorItem()
        local stillHeld = GetCursorInfo()
        ClearCursor()
        if not stillHeld then
            excess = excess - 1
            -- MT.print("shards: deleted 1" .. (excess > 0 and (", " .. excess .. " more to go.") or "."))
        end
        return
    end

    local moved = 0
    for _, loc in ipairs(elsewhere) do
        local dest = freeSoulSlots[moved + 1]
        if not dest then
            break
        end
        C_Container.PickupContainerItem(loc.bag, loc.slot)
        if cursorHoldsShard() then
            C_Container.PickupContainerItem(dest.bag, dest.slot)
            if not GetCursorInfo() then
                moved = moved + 1
            end
        end
        ClearCursor()
    end

    -- if moved > 0 then
    --     MT.print("shards: moved " .. moved .. " to soul bag.")
    -- end
end

MT.register("shards", "delete soul shards beyond N and move the rest into a soul bag (no-op in combat). /tool shards 6", MT.shards)
