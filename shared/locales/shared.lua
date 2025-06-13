Locales = Locales or {}
local currentLocale = nil

local function InitializeLocale()
    if not GetSetting then
        return false
    end
    currentLocale = GetSetting("general.locale")
    return true
end

function UpdateLocale()
    if not GetSetting then
        return false
    end
    currentLocale = GetSetting("general.locale")
    return true
end

function Translate(str, ...)
    if not str then
        return "Translate parameter is nil!"
    end

    if not currentLocale then
        if not InitializeLocale() then
            return str
        end
    end

    if Locales[currentLocale] and Locales[currentLocale][str] then
        return string.format(Locales[currentLocale][str], ...)
    elseif currentLocale ~= "en" and Locales["en"] and Locales["en"][str] then
        return string.format(Locales["en"][str], ...)
    else
        return "Translation [" .. currentLocale .. "][" .. str .. "] does not exist"
    end
end

function TranslateCap(str, ...)
    local result = Translate(str, ...)
    return result:gsub("^%l", string.upper)
end

_ = Translate
_U = TranslateCap

Citizen.CreateThread(function()
    while not InitializeLocale() do
        Citizen.Wait(100)
    end
end)
