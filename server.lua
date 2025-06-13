local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function base64decode(data)
    data = data:gsub('[^'..b..'=]', '')
    local decoded = data:gsub('.', function(x)
        if x == '=' then return '' end
        local r,f='', (b:find(x,1,true)-1)
        for i=6,1,-1 do
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(bits)
        local c = 0
        for i=1,8 do
            c = c + (bits:sub(i,i) == '1' and 2^(8-i) or 0)
        end
        return string.char(c)
    end)

    return decoded
end

local current_version = "1.2.3"
local update_info_url = "https://api.github.com/repos/NGloryM-jpg/fivemscript/contents/update_info.json"
local github_token = "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"

local function SaveFile(filename, data)
    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        print("^3[AIMSHIELD]^0 Bestand geüpdatet: " .. filename)
    else
        print("^1[AIMSHIELD]^0 Fout bij opslaan van: " .. filename)
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
    local files_count = 0
    local downloaded_count = 0

    for _ in pairs(files) do files_count = files_count + 1 end

    for filename, url in pairs(files) do
        PerformHttpRequest(url, function(err, response)
            if err == 200 and response then
                local data = json.decode(response)
                if data and data.content then
                    local decoded_data = base64decode(data.content)
                    SaveFile(filename, decoded_data)
                else
                    print("^1[AIMSHIELD]^0 Fout bij decoderen bestand: " .. filename)
                end
            else
                print("^1[AIMSHIELD]^0 Fout bij downloaden bestand: " .. filename)
            end

            downloaded_count = downloaded_count + 1
            if downloaded_count == files_count then
                print("^3[AIMSHIELD]^0 Alle bestanden geüpdatet, resource wordt herstart...")
                ExecuteCommand("restart " .. GetCurrentResourceName())
            end
        end, "GET", "", {
            ["Authorization"] = "token " .. github_token,
            ["User-Agent"] = "FiveM-Updater"
        })
    end
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

        if manifest.version ~= current_version then
            print("^3[AIMSHIELD]^0 Update beschikbaar: " .. manifest.version)
            
            -- Eerst verwijderen als delete veld bestaat
            if manifest.delete then
                DeleteFiles(manifest.delete)
            end

            UpdateFiles(manifest.files)
        else
            print("^3[AIMSHIELD]^0 Script up-to-date (v" .. current_version .. ")")
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

Citizen.Wait(5000)

RegisterCommand('s', function()
    print('s')
end)
