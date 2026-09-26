local addonName, addon = ...

addon.name = addonName
addon.version = "0.1.0-alpha.1"
addon.initialized = false
addon.enabled = false

function addon:Print(message)
    local text = "|cff67d5c8CarGOUI|r: " .. tostring(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end
