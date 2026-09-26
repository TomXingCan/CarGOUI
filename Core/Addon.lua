local addonName, addon = ...

addon.name = addonName
addon.version = "0.1.0-alpha.14"
addon.initialized = false
addon.enabled = false
-- The unified Data package registers isolated adapters through this host.
_G.CarGOUI_DataHost = addon
-- An accidentally enabled alpha.8 CarGOUI_Mage may still execute its old
-- forwarding bootstrap. Quarantine those writes instead of exposing the host.
-- No files or SavedVariables are deleted. The installer omits that old addon.
_G.CarGOUI_Internal = {}

function addon:Print(message)
    local text = "|cff67d5c8CarGOUI|r: " .. tostring(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end
