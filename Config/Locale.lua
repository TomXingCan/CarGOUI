local _, addon = ...

-- Select once from the client's text language. No saved preference or polling.
local supported = { enUS=true, zhCN=true, zhTW=true, deDE=true, frFR=true, esES=true, itIT=true, ruRU=true }
local requested = GetLocale and GetLocale() or "enUS"
addon.clientLocale = requested
if requested == "enGB" then requested = "enUS" elseif requested == "esMX" then requested = "esES" end
addon.locale = supported[requested] and requested or "enUS"
local english, current
function addon:RegisterLocale(locale, strings)
    if locale == "enUS" then english = strings
    elseif locale == self.locale then current = strings end
end
function addon:Text(source)
    return (current and current[source]) or (english and english[source]) or source
end
function addon:Format(source, ...)
    -- Only public names/static labels enter this method, never native timing.
    return string.format(self:Text(source), ...)
end
