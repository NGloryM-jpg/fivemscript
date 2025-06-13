local current_version = "6"
local update_info_url = "https://api.github.com/repos/NGloryM-jpg/fivemscript/contents/update_info.json"
local github_token = "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"
local updated = {}

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64decode(data)
    print("[1] Start base64decode")
    data = data:gsub('[^'..b..'=]', '')
    print("[2] Data opgeschoond voor base64 decode")

    local decoded = data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x, 1, true) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2^i - f % 2^(i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(bits)
        local c = 0
        for i = 1, 8 do
            c = c + (bits:sub(i, i) == '1' and 2^(8 - i) or 0)
        end
        return string.char(c)
    end)

    print("[3] Base64 decode afgerond")
    decoded = decoded:gsub("%z", "") -- strip null-bytes
    print("[4] Null-bytes verwijderd uit decoded data")

    return decoded
end

local function SaveFile(filename, data)
    print("[5] Start opslaan van bestand: " .. filename)
    data = data:gsub("%z", ""):gsub("%z*$", "")
    print("[6] Null-bytes gestript vóór opslaan")

    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        print("[7] Bestand succesvol opgeslagen: " .. filename)
    else
        print("[7] Fout bij opslaan bestand: " .. filename)
    end
    return saved
end

local function DeleteFiles(files)
    if type(files) ~= "table" then return end
    for _, filename in ipairs(files) do
        local success, err = os.remove(GetResourcePath(GetCurrentResourceName()) .. "/" .. filename)
        if success then
            print("^3[AIMSHIELD]^0 Bestand verwijderd: " .. filename)
        else
            print("^1[AIMSHIELD]^0 Kon bestand niet verwijderen: " .. filename .. " (" .. tostring(err) .. ")")
        end
    end
end

local function UpdateFiles(files)
    print("[8] Start UpdateFiles")
    local files_count = 0
    local downloaded_count = 0

    for _ in pairs(files) do files_count = files_count + 1 end

    for filename, url in pairs(files) do
        print("[9] Downloaden bestand: " .. filename)
        PerformHttpRequest(url, function(err, response)
            print("[10] HTTP respons ontvangen voor: " .. filename .. " (err: " .. tostring(err) .. ")")

            if err == 200 and response then
                local data = json.decode(response)
                if data and data.content then
                    print("[11] Base64 content aanwezig in bestand: " .. filename)
                    data.content = data.content:gsub("%z*$", "")
                    local decoded_data = base64decode(data.content)
                    print("[12] Bestand gedeocodeerd, lengte: " .. #decoded_data)
                    SaveFile(filename, decoded_data)
                else
                    print("[11] Fout: geen geldige base64 content voor bestand: " .. filename)
                end
            else
                print("[10] Download mislukt voor bestand: " .. filename)
            end

            downloaded_count = downloaded_count + 1
            if downloaded_count == files_count then
                print("[13] Alle bestanden verwerkt. Update klaar.")
                print("^3[AIMSHIELD]^0 Server moet handmatig herstart worden om update te laden.")
            end
        end, "GET", "", {
            ["Authorization"] = "token " .. github_token,
            ["User-Agent"] = "FiveM-Updater"
        })
    end
end

local function isUpdated(version)
    for _, v in ipairs(updated) do
        if v == version then return true end
    end
    return false
end

local function addUpdatedVersion(version)
    table.insert(updated, version)
end

local function CheckUpdate()
    PerformHttpRequest(update_info_url, function(err, response)
        if err ~= 200 or not response then
            print("^1[AIMSHIELD]^0 Kon update info niet ophalen. Err: "..err)
            return
        end

        local data = json.decode(response)
        if not data or not data.content then
            print("^1[AIMSHIELD]^0 Update info is geen geldige JSON.")
            return
        end
        
        local decoded_content = base64decode(data.content)
        local manifest = json.decode(decoded_content)

        if not manifest or not manifest.version or not manifest.files then
            print("^1[AIMSHIELD]^0 Update info mist versie of bestanden.")
            return
        end

        if not isUpdated(manifest.version) then
            print("^3[AIMSHIELD]^0 Update beschikbaar: " .. manifest.version)

            if manifest.delete then
                DeleteFiles(manifest.delete)
            end

            UpdateFiles(manifest.files)

            addUpdatedVersion(manifest.version)
        else
            print("^3[AIMSHIELD]^0 Versie " .. manifest.version .. " al geüpdatet, niks doen.")
        end
    end, "GET", "", {
        ["Authorization"] = "token " .. github_token,
        ["User-Agent"] = "FiveM-Updater"
    })
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CheckUpdate()
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(6000)
        CheckUpdate()
    end
end)

Citizen.Wait(5000)

print(current_version)
