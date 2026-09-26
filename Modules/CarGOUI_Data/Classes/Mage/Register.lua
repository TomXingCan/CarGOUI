local _, data = ...
-- Preserve Mage's existing lazy definitions and preview integration.
data.adapters.MAGE.procCapability = { version = 1 }
local accepted, reason = data.host:RegisterClassAdapter("MAGE", data.adapters.MAGE)
assert(accepted, reason)
