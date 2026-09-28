local _, MT = ...

-- Window 1 is owned by Edit Mode, so only 2+ are handled here.

local function chatFrameByName(name)
    for i = 2, (NUM_CHAT_WINDOWS or 10) do
        if GetChatWindowInfo(i) == name then
            return _G["ChatFrame" .. i]
        end
    end
    return nil
end

function MT.saveChatPos()
    local saved = {}
    for i = 2, (NUM_CHAT_WINDOWS or 10) do
        local name, _, _, _, _, _, shown, locked, docked = GetChatWindowInfo(i)
        local frame = _G["ChatFrame" .. i]
        if name and name ~= "" and shown and not docked and frame then
            FCF_SavePositionAndDimensions(frame)
            local point, x, y = GetChatWindowSavedPosition(i)
            local w, h = GetChatWindowSavedDimensions(i)
            table.insert(saved, { name = name, point = point, x = x, y = y, w = w, h = h, locked = locked and true or false })
            MT.print("saved \"" .. name .. "\"")
        end
    end
    MT.db().chatWindows = saved
    if #saved == 0 then
        MT.print("no undocked chat windows found; cleared saved positions.")
    end
end

function MT.restoreChatPos()
    for _, s in ipairs(MT.db().chatWindows or {}) do
        local frame = chatFrameByName(s.name)
        if frame then
            local id = frame:GetID()
            FCF_UnDockFrame(frame)
            FCF_SetTabPosition(frame, 0)
            SetChatWindowSavedPosition(id, s.point, s.x, s.y)
            SetChatWindowSavedDimensions(id, s.w, s.h)
            FCF_RestorePositionAndDimensions(frame)
            FCF_SetLocked(frame, s.locked)
        else
            MT.error("no chat window named \"" .. s.name .. "\" to position.")
        end
    end
end

MT.register("savechatpos", "remember positions of undocked chat windows for /tool init", MT.saveChatPos)
