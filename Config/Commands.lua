local _, addon = ...

local function PrintHelp()
    addon:Print("/cui opens or closes Options. All display settings are available there. /cargoui remains an alias.")
    addon:Print("Optional commands: /cui help | status | show | hide | reset")
    addon:Print("/cui position <x> <y>  (-10000 to 10000; right/up are positive)")
    addon:Print("Mobility Appearance is per class; Proc Appearance is per current class and specialization.")
end

local function PrintStatus()
    local db = addon:GetMobilityConfig()
    addon:Print(string.format("%s | %s | CENTER (%g, %g) | current class Mobility",
        addon.version, db.enabled and "shown" or "hidden",
        db.position.x, db.position.y))
end

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
    elseif command == "font" or command == "fontsize" or command == "outline"
        or command == "scale" or command == "shadow" then
        self:Print("Global reminder style commands are retired. Open /cui, open Mobility or Proc, and edit Appearance.")
        return
    elseif command == "reset" and #args == 1 then
        self:ResetDatabase()
        self:Print("Current class and Options settings reset to defaults.")
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
