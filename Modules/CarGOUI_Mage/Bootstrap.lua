local _, module = ...
local core = _G.CarGOUI_Internal
assert(type(core) == "table", "CarGOUI core must load before its Mage module.")

-- One internal namespace bridge preserves the already validated spell adapter.
-- This is neither a second configuration store nor a copy of mutable settings.
setmetatable(module, { __index = core, __newindex = function(_, key, value) core[key] = value end })
core.mageModuleRegistered = true
