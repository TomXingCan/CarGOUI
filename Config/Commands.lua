local _, addon = ...

local function PrintHelp()
    addon:Print("/cui opens or closes Options. All display settings are available there. /cargoui remains an alias.")
    addon:Print("Optional commands: /cui help | status | show | hide | reset")
    addon:Print("/cui position <x> <y>  (-10000 to 10000; right/up are positive)")
    addon:Print("/cui font <friz|arial|morpheus|skurri|default>")
    addon:Print("/cui fontsize <8-72>")
    addon:Print("/cui outline <none|outline|thickoutline>")
    addon:Print("/cui scale <0.5-3> | shadow <on|off>")
end

local function PrintStatus()
    local db = addon.db
    local face = db.font.face
    for _, font in ipairs(addon.fonts) do
        if font.value == face then face = font.label; break end
    end
    addon:Print(string.format("%s | %s | CENTER (%g, %g) | %s %g | %s | scale %g | shadow %s",
        addon.version, db.enabled and "shown" or "hidden",
        db.position.x, db.position.y, face, db.font.size,
        db.font.outline == "" and "no outline" or db.font.outline,
        db.scale, db.shadow.enabled and "on" or "off"))
end

local fontAliases = {
    friz = "Fonts\\FRIZQT__.ttf",
    arial = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri = "Fonts\\skurri.ttf",
}

function addon:HandleSlashCommand(message)
    local args = {}
    for word in string.gmatch(message or "", "%S+") do
        args[#args + 1] = string.lower(word)
    end
    if #args == 0 then
        self:ToggleOptions()
        return
    end
    local command, patch = args[1]

    if command == "help" and #args == 1 then
        PrintHelp()
        return
    elseif command == "status" and #args == 1 then
        PrintStatus()
        return
    elseif (command == "show" or command == "hide") and #args == 1 then
        patch = { enabled = command == "show" }
    elseif command == "position" and #args == 3 then
        -- Keep invalid text in the patch so shared validation rejects it instead of omitting it.
        patch = { position = { x = tonumber(args[2]) or args[2], y = tonumber(args[3]) or args[3] } }
    elseif command == "font" and #args == 2 then
        local face = fontAliases[args[2]]
        if args[2] == "default" then
            local supported, canonicalFace = self:IsSupportedFont(STANDARD_TEXT_FONT)
            face = supported and canonicalFace or self.defaults.font.face
        end
        if not face then
            self:Print("Font must be friz, arial, morpheus, skurri, or default. Type /cui help for help.")
            return
        end
        patch = { font = { face = face } }
    elseif command == "fontsize" and #args == 2 then
        patch = { font = { size = tonumber(args[2]) or args[2] } }
    elseif command == "outline" and #args == 2 then
        patch = { font = { outline = args[2] == "none" and "" or string.upper(args[2]) } }
    elseif command == "scale" and #args == 2 then
        patch = { scale = tonumber(args[2]) or args[2] }
    elseif command == "shadow" and #args == 2
        and (args[2] == "on" or args[2] == "off") then
        patch = { shadow = { enabled = args[2] == "on" } }
    elseif command == "reset" and #args == 1 then
        self:ResetDatabase()
        self:Print("Settings reset to defaults.")
        return
    else
        self:Print("Invalid command. Type /cui help for help.")
        return
    end

    local valid, errorMessage = self:UpdateSettings(patch)
    if not valid then
        self:Print(errorMessage .. " Type /cui help for help.")
        return
    end
    PrintStatus()
end

function addon:RegisterSlashCommands()
    SLASH_CARGOUI1 = "/cui"
    SLASH_CARGOUI2 = "/cargoui"
    SlashCmdList.CARGOUI = function(message)
        addon:HandleSlashCommand(message)
    end
end
