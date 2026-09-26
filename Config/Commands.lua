local _, addon = ...

local function PrintHelp()
    addon:Print("Alpha 0.1 Phase 1 commands:")
    addon:Print("/cargoui status | show | hide | reset")
    addon:Print("/cargoui position <x> <y>  (-10000 to 10000; right/up are positive)")
    addon:Print("/cargoui fontsize <8-72>")
    addon:Print("/cargoui outline <none|outline|thickoutline>")
    addon:Print("/cargoui scale <0.5-3> | shadow <on|off>")
end

local function PrintStatus()
    local db = addon.db
    addon:Print(string.format("%s | %s | CENTER (%g, %g) | font %g | %s | scale %g | shadow %s",
        addon.version, db.enabled and "shown" or "hidden",
        db.position.x, db.position.y, db.font.size,
        db.font.outline == "" and "no outline" or db.font.outline,
        db.scale, db.shadow.enabled and "on" or "off"))
end

function addon:HandleSlashCommand(message)
    local args = {}
    for word in string.gmatch(message or "", "%S+") do
        args[#args + 1] = string.lower(word)
    end
    local command = args[1] or "help"
    local db = self.db

    if command == "help" and #args <= 1 then
        PrintHelp()
        return
    elseif command == "status" and #args == 1 then
        PrintStatus()
        return
    elseif (command == "show" or command == "hide") and #args == 1 then
        db.enabled = command == "show"
    elseif command == "position" and #args == 3 then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if not self:IsNumberInRange(x, self.limits.offset)
            or not self:IsNumberInRange(y, self.limits.offset) then
            self:Print("Position requires two numbers from -10000 to 10000.")
            return
        end
        db.position.x, db.position.y = x, y
    elseif command == "fontsize" and #args == 2 then
        local size = tonumber(args[2])
        if not self:IsNumberInRange(size, self.limits.fontSize) then
            self:Print("Font size must be a number from 8 to 72.")
            return
        end
        db.font.size = size
    elseif command == "outline" and #args == 2 then
        local outline = args[2] == "none" and "" or string.upper(args[2])
        if not self.outlines[outline] then
            self:Print("Outline must be none, outline, or thickoutline.")
            return
        end
        db.font.outline = outline
    elseif command == "scale" and #args == 2 then
        local scale = tonumber(args[2])
        if not self:IsNumberInRange(scale, self.limits.scale) then
            self:Print("Scale must be a number from 0.5 to 3.")
            return
        end
        db.scale = scale
    elseif command == "shadow" and #args == 2
        and (args[2] == "on" or args[2] == "off") then
        db.shadow.enabled = args[2] == "on"
    elseif command == "reset" and #args == 1 then
        self:ResetDatabase()
        self:Print("Settings reset to defaults.")
        return
    else
        self:Print("Invalid command. Type /cargoui for help.")
        return
    end

    self:ApplySettings()
    PrintStatus()
end

function addon:RegisterSlashCommands()
    SLASH_CARGOUI1 = "/cargoui"
    SlashCmdList.CARGOUI = function(message)
        addon:HandleSlashCommand(message)
    end
end
