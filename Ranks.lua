local _, MT = ...

-- Supports both the C_SpellBook/C_Spell Classic clients and 3.3.5-style clients.

local PLAYER_BOOK = BOOKTYPE_SPELL or "spell"
if _G.GetSpellBookItemName == nil and Enum and Enum.SpellBookSpellBank then
    PLAYER_BOOK = Enum.SpellBookSpellBank.Player
end

local function bookItemName(index)
    if _G.GetSpellBookItemName then
        return GetSpellBookItemName(index, PLAYER_BOOK)
    elseif _G.GetSpellName then
        return GetSpellName(index, PLAYER_BOOK)
    elseif C_SpellBook and C_SpellBook.GetSpellBookItemName then
        return C_SpellBook.GetSpellBookItemName(index, PLAYER_BOOK)
    end
    return nil
end

-- nil for unlearned (future) and off-spec entries, which the 11.0+ spellbook also lists.
local FUTURE_SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell

local function bookItemSpellID(index)
    local _, _, id = bookItemName(index)
    if id then
        return id
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local info = C_SpellBook.GetSpellBookItemInfo(index, PLAYER_BOOK)
        if info and info.spellID then
            if info.isOffSpec or (FUTURE_SPELL and info.itemType == FUTURE_SPELL) then
                return nil
            end
            return info.spellID
        end
    end
    if _G.GetSpellBookItemInfo then
        local itemType, itemID = GetSpellBookItemInfo(index, PLAYER_BOOK)
        if itemType == "SPELL" and itemID then
            return itemID
        end
    end
    if _G.GetSpellLink then
        local link = GetSpellLink(index, PLAYER_BOOK)
        if type(link) == "string" then
            return tonumber(link:match("spell:(%d+)"))
        end
    end
    return nil
end

local function spellName(spellID)
    if _G.GetSpellInfo then
        return GetSpellInfo(spellID)
    elseif C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    elseif C_Spell and C_Spell.GetSpellInfo then
        local si = C_Spell.GetSpellInfo(spellID)
        return si and si.name or nil
    end
    return nil
end

local function spellSubtext(spellID)
    if _G.GetSpellSubtext then
        return GetSpellSubtext(spellID)
    elseif C_Spell and C_Spell.GetSpellSubtext then
        return C_Spell.GetSpellSubtext(spellID)
    end
    return nil
end

-- 3.3.5 returns (type, id, subType, spellID); newer clients return (type, spellID, subType).
local function actionSpellID(slot)
    local actionType, id, _, spellID = GetActionInfo(slot)
    if actionType == "spell" then
        return id
    end
    return spellID
end

local function parseRank(text)
    if type(text) ~= "string" then
        return nil
    end
    local rank = text:match("(%d+)")
    return rank and tonumber(rank) or nil
end

-- bestRanks[name] = { name, rank, id }, idRanks[spellID] = rank
local function scanSpellbook(debug)
    local bestRanks = {}
    local idRanks   = {}
    local seen      = {}
    local unranked  = 0

    local i         = 1
    while true do
        local name, subText = bookItemName(i)
        if not name then
            break
        end

        local id = bookItemSpellID(i)
        if id ~= nil then
            local infoName = spellName(id) or name

            -- Subtext can be lazily loaded on newer clients, so also ask by ID.
            local rank = parseRank(subText) or parseRank(spellSubtext(id))

            seen[infoName] = (seen[infoName] or 0) + 1
            if rank == nil then
                -- Spellbook lists ranks ascending, so a later same-named entry is higher.
                if seen[infoName] > 1 then
                    rank = seen[infoName]
                    unranked = unranked + 1
                else
                    rank = 0
                end
            end

            if debug then
                print("  [" .. i .. "] " .. infoName .. " (id " .. id .. ") rank=" .. rank ..
                    " sub='" .. tostring(subText) .. "'")
            end

            if bestRanks[infoName] == nil then
                bestRanks[infoName] = { name = infoName, rank = -1 }
            end
            if rank > bestRanks[infoName].rank then
                bestRanks[infoName].rank = rank
                bestRanks[infoName].id = id
            end
            if rank > 0 then
                idRanks[id] = rank
            end
        elseif debug then
            print("  [" .. i .. "] " .. name .. " (no spell ID found)")
        end

        i = i + 1
    end

    if debug then
        MT.print("scanned " .. (i - 1) .. " spellbook entries" ..
            (unranked > 0 and (", " .. unranked .. " without rank text") or ""))
    end

    return bestRanks, idRanks
end

local pickupSpell = (C_Spell and C_Spell.PickupSpell) or _G.PickupSpell

local function pickupBestRank(bestRank)
    ClearCursor()
    pickupSpell(bestRank.id)
    if GetCursorInfo() then
        return true
    end
    -- Some clients only accept a name here.
    pickupSpell(bestRank.name)
    return GetCursorInfo() ~= nil
end

function MT.fixRanks(msg)
    local debug = (msg ~= nil) and (msg:lower():find("debug") ~= nil)

    if InCombatLockdown() then
        MT.print("can't change action bars during combat.")
        return
    end

    local bestRanks, idRanks = scanSpellbook(debug)

    -- Bars 6-8 on the 10.0+ engine live at 145-180.
    local upgradedCount = 0
    for i = 1, 180 do
        local id = actionSpellID(i)
        if id ~= nil then
            local infoName = spellName(id)
            if infoName ~= nil then
                local rank = idRanks[id] or parseRank(spellSubtext(id))
                local bestRank = bestRanks[infoName]
                if debug then
                    print("  slot " .. i .. ": " .. infoName .. " (id " .. id .. ") rank=" ..
                        tostring(rank) .. " best=" .. tostring(bestRank and bestRank.rank) ..
                        " bestId=" .. tostring(bestRank and bestRank.id))
                end
                -- Lower ranks may be missing from the book or lack rank text, so a nil rank still counts.
                if bestRank ~= nil and bestRank.id ~= nil and bestRank.id ~= id
                    and (rank == nil or rank < bestRank.rank) then
                    MT.print("Upgrading[" .. i .. ", " .. bestRank.id .. "]: " ..
                        infoName .. " " .. tostring(rank or "?") .. " => " .. bestRank.rank)
                    if pickupBestRank(bestRank) then
                        PlaceAction(i)
                        ClearCursor()
                        upgradedCount = upgradedCount + 1
                    else
                        MT.print("couldn't pick up " .. infoName .. " (id " .. bestRank.id .. ")")
                    end
                end
            end
        end
    end

    MT.print("slots fixed: " .. upgradedCount)
end

MT.register("ranks", "upgrade action bar spells to highest known rank (also /fixranks, /fr)", MT.fixRanks)

SLASH_MULTITOOL_FIXRANKS1 = '/fixranks'
SLASH_MULTITOOL_FIXRANKS2 = '/fr'
SlashCmdList["MULTITOOL_FIXRANKS"] = MT.fixRanks
