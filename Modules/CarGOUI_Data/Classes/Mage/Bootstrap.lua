local _, data = ...
local host = data.host
local adapter = { classToken = "MAGE" }
data.adapters.MAGE = adapter

-- Explicit, bound read interfaces avoid inheriting mutable core fields or
-- invoking core configuration methods with the adapter as their receiver.
function adapter:GetCurrentModuleIdentity() return host:GetCurrentModuleIdentity() end
function adapter:GetMobilityStatus() return host:GetMobilityStatus() end
function adapter:GetReminderStyleKey(...) return host:GetReminderStyleKey(...) end
