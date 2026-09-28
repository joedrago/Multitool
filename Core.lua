local _, MT = ...
Multitool = MT

MT.commands = {}
MT.commandOrder = {}

function MT.print(msg)
    print("Multitool: " .. msg)
end

function MT.error(msg)
    print("|cffff4040Multitool: " .. msg .. "|r")
end

function MT.db()
    MultitoolDB = MultitoolDB or {}
    return MultitoolDB
end

function MT.register(name, help, fn)
    MT.commands[name] = { help = help, fn = fn }
    table.insert(MT.commandOrder, name)
end

local function usage()
    print("Multitool commands:")
    for _, name in ipairs(MT.commandOrder) do
        print("  /tool " .. name .. " - " .. MT.commands[name].help)
    end
end

SLASH_MULTITOOL1 = '/tool'
SlashCmdList["MULTITOOL"] = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    local entry = MT.commands[cmd:lower()]
    if entry then
        entry.fn(rest)
    else
        usage()
    end
end
