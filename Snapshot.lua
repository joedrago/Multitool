local _, MT = ...

-- Account/install-wide state that /tool init deliberately doesn't touch.

-- Per-install bookkeeping that shouldn't follow you to a new install.
local CVAR_SKIP = {
    "^last", "^realm", "^account", "^portal", "Locale$", "^agent",
    "^CACHE%-", "^engineSurvey", "^videoOptionsVersion$", "^currentGameMode$", "^gameTip$",
}

local function skipCVar(name)
    for _, pattern in ipairs(CVAR_SKIP) do
        if name:find(pattern) then
            return true
        end
    end
    return false
end

-- Character-stored CVars are left to /tool init.
local function saveCVars()
    local cvars, count = {}, 0
    for _, info in ipairs(ConsoleGetAllCommands()) do
        if info.commandType == Enum.ConsoleCommandType.Cvar and not skipCVar(info.command) then
            local ok, value, default, _, isChar, locked, secure, readOnly = pcall(C_CVar.GetCVarInfo, info.command)
            if ok and value ~= nil and value ~= default and not (isChar or locked or secure or readOnly) then
                cvars[info.command] = value
                count = count + 1
            end
        end
    end
    return cvars, count
end

local function restoreCVars(cvars)
    local set, failed = 0, {}
    for name, value in pairs(cvars) do
        if GetCVar(name) ~= value then
            local ok, success = pcall(C_CVar.SetCVar, name, value)
            if ok and success then
                set = set + 1
            else
                table.insert(failed, name)
            end
        end
    end
    return set, failed
end

-- GetBinding returns command, category, key1, key2, ...
local function saveBindings()
    local bindings, count = {}, 0
    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        local keys = { select(3, GetBinding(i)) }
        if command and #keys > 0 then
            bindings[command] = keys
            count = count + #keys
        end
    end
    return bindings, count
end

-- Unbind everything first so the result matches the snapshot exactly.
local function restoreBindings(bindings)
    if next(bindings) == nil then
        return 0, {}
    end
    for i = 1, GetNumBindings() do
        for _, key in ipairs({ select(3, GetBinding(i)) }) do
            SetBinding(key)
        end
    end
    local set, failed = 0, {}
    for command, keys in pairs(bindings) do
        for _, key in ipairs(keys) do
            if SetBinding(key, command) then
                set = set + 1
            else
                table.insert(failed, key .. " " .. command)
            end
        end
    end
    SaveBindings(GetCurrentBindingSet())
    return set, failed
end

local function saveLayouts()
    local layouts = {}
    for _, l in ipairs(C_EditMode.GetLayouts().layouts) do
        table.insert(layouts, { name = l.layoutName, data = C_EditMode.ConvertLayoutInfoToString(l) })
    end
    return layouts
end

-- Mirrors EditModeManagerFrameMixin:MakeNewLayout: insert after the last account layout
-- in the presets-first list, save the whole list, then announce the addition.
local function importLayout(saved)
    local layouts, active = MT.allLayouts()
    local lastAccount
    for i, l in ipairs(layouts) do
        if l.layoutName == saved.name then
            return false
        end
        if l.layoutType == Enum.EditModeLayoutType.Account then
            lastAccount = i
        end
    end

    local layout = C_EditMode.ConvertStringToLayoutInfo(saved.data)
    if not layout then
        MT.error("couldn't read saved layout \"" .. saved.name .. "\".")
        return false
    end
    layout.layoutName = saved.name
    layout.layoutType = Enum.EditModeLayoutType.Account

    local index = (lastAccount or #EditModePresetLayoutManager:GetCopyOfPresetLayouts()) + 1
    table.insert(layouts, index, layout)
    if active >= index then
        active = active + 1
    end
    C_EditMode.SaveLayouts({ layouts = layouts, activeLayout = active })
    C_EditMode.OnLayoutAdded(index, false, true)
    return true
end

local function saveEditModeSettings()
    local settings = {}
    for _, s in ipairs(C_EditMode.GetAccountSettings()) do
        settings[s.setting] = s.value
    end
    return settings
end

local function restoreEditModeSettings(settings)
    local current = saveEditModeSettings()
    for setting, value in pairs(settings) do
        if current[setting] ~= nil and current[setting] ~= value then
            C_EditMode.SetAccountSetting(setting, value)
        end
    end
end

local function reportFailed(what, failed)
    if #failed > 0 then
        MT.error(#failed .. " " .. what .. " couldn't be restored: " .. table.concat(failed, ", "))
    end
end

local function save()
    local cvars, numCVars = saveCVars()
    local bindings, numKeys = saveBindings()
    local snapshot = {
        time = date("%Y-%m-%d %H:%M"),
        cvars = cvars,
        bindings = bindings,
        layouts = saveLayouts(),
        editModeSettings = saveEditModeSettings(),
    }
    MT.db().snapshot = snapshot
    MT.print(("snapshot saved: %d settings, %d key bindings, %d UI layouts."):format(numCVars, numKeys, #snapshot.layouts))
    MT.print("/reload or log out to write it to disk before copying WTF.")
end

local function restore()
    local snapshot = MT.db().snapshot
    if not snapshot then
        MT.error("no snapshot saved. Use /tool snapshot save first.")
        return
    end

    local imported = 0
    for _, layout in ipairs(snapshot.layouts or {}) do
        if importLayout(layout) then
            imported = imported + 1
        end
    end
    restoreEditModeSettings(snapshot.editModeSettings or {})
    local numCVars, failedCVars = restoreCVars(snapshot.cvars or {})
    local numKeys, failedKeys = restoreBindings(snapshot.bindings or {})

    MT.print(("restored snapshot from %s: %d settings, %d key bindings, %d UI layouts imported."):format(
        snapshot.time or "?", numCVars, numKeys, imported))
    reportFailed("settings", failedCVars)
    reportFailed("key bindings", failedKeys)
    MT.print("/reload to finish, then /tool init.")
end

function MT.snapshot(msg)
    local cmd = strtrim(msg or ""):lower()
    if InCombatLockdown() then
        MT.error("can't snapshot during combat.")
    elseif cmd == "save" then
        save()
    elseif cmd == "restore" then
        restore()
    else
        MT.print("usage: /tool snapshot save | restore")
    end
end

MT.register("snapshot", "save or restore account-wide settings, key bindings and UI layouts. /tool snapshot save|restore", MT.snapshot)
