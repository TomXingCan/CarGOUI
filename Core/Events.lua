local _, addon = ...

local eventFrame = CreateFrame("Frame")
local listeners = {}

-- Callbacks receive (addon, event, ...). Keep the same function to unsubscribe.
function addon:RegisterEvent(event, callback)
    assert(type(event) == "string", "CarGOUI: event must be a string")
    assert(type(callback) == "function", "CarGOUI: callback must be a function")

    local callbacks = listeners[event]
    if not callbacks then
        -- Restricted research events may be rejected without throwing.
        if eventFrame:RegisterEvent(event) == false then return false end
        callbacks = {}
        listeners[event] = callbacks
    end

    for i = 1, #callbacks do
        if callbacks[i] == callback then
            return true
        end
    end
    callbacks[#callbacks + 1] = callback
    return true
end

function addon:UnregisterEvent(event, callback)
    local callbacks = listeners[event]
    if not callbacks then
        return
    end

    for i = #callbacks, 1, -1 do
        if callbacks[i] == callback then
            table.remove(callbacks, i)
        end
    end

    if #callbacks == 0 then
        listeners[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

-- Explicit diagnostic snapshot only; does not inspect callbacks or engine state.
function addon:GetEventDiagnostics()
    local result = { events = 0, callbacks = 0, perEvent = {} }
    for event, callbacks in pairs(listeners) do
        result.events = result.events + 1
        result.callbacks = result.callbacks + #callbacks
        result.perEvent[event] = #callbacks
    end
    return result
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local callbacks = listeners[event]
    if not callbacks then
        return
    end

    -- Subscription changes affect the next event, not this dispatch.
    local snapshot = {}
    for i = 1, #callbacks do
        snapshot[i] = callbacks[i]
    end
    local arguments = { n = select("#", ...), ... }
    for i = 1, #snapshot do
        local callback = snapshot[i]
        xpcall(function()
            callback(addon, event, unpack(arguments, 1, arguments.n))
        end, geterrorhandler())
    end
end)
