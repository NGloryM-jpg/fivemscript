local current_version = "1.1.0"
local update_info_url = "https://raw.githubusercontent.com/<gebruikersnaam>/fivem-anticheat-update/main/update_info.json"

local function SaveFile(filename, data)
    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        print("^3[AutoUpdater]^0 Bestand geüpdatet: " .. filename)
    else
        print("^1[AutoUpdater]^0 Fout bij opslaan van: " .. filename)
    end
    return saved
end

local function UpdateFiles(files)
    local files_count = 0
    local downloaded_count = 0

    for _ in pairs(files) do files_count = files_count + 1 end

    for filename, url in pairs(files) do
        PerformHttpRequest(url, function(err, data)
            if err == 200 and data then
                SaveFile(filename, data)
            else
                print("^1[AutoUpdater]^0 Fout bij downloaden bestand: " .. filename)
            end
            downloaded_count = downloaded_count + 1
            if downloaded_count == files_count then
                print("^3[AutoUpdater]^0 Alle bestanden geüpdatet, resource wordt herstart...")
                ExecuteCommand("restart " .. GetCurrentResourceName())
            end
        end)
    end
end

local function CheckUpdate()
    PerformHttpRequest(update_info_url, function(err, data)
        if err ~= 200 or not data then
            print("^1[AutoUpdater]^0 Kon update info niet ophalen.")
            return
        end

        local ok, manifest = pcall(function() return json.decode(data) end)
        if not ok or not manifest then
            print("^1[AutoUpdater]^0 Update info is geen geldige JSON.")
            return
        end

        if not manifest.version or not manifest.files then
            print("^1[AutoUpdater]^0 Update info mist versie of bestanden.")
            return
        end

        if manifest.version ~= current_version then
            print("^3[AutoUpdater]^0 Update beschikbaar: " .. manifest.version)
            UpdateFiles(manifest.files)
        else
            print("^3[AutoUpdater]^0 Script up-to-date (v" .. current_version .. ")")
        end
    end)
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CheckUpdate()
    end
end)

-- Normale scriptcode hieronder, bijvoorbeeld:
print("^2[Anticheat]^0 Server script geladen en draait 1.1 test.")
