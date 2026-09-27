local _, data = ...
local host = _G.CarGOUI_DataHost
assert(type(host) == "table" and type(host.RegisterClassAdapter) == "function",
    "CarGOUI core must load before its Data package.")

-- Private class namespaces contain definitions, not initialized runtime data.
-- There is deliberately no __newindex forwarding into the core addon table.
data.host, data.adapters = host, {}
