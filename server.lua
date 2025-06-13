local current_version = "7"
local update_info_url = "https://api.github.com/repos/NGloryM-jpg/fivemscript/contents/update_info.json"
local github_token = "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"
local updated = {}

local function SaveFile(filename, data)
    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        print("^3[AIMSHIELD]^0 File updated: " .. filename)
    else
        print("^1[AIMSHIELD]^0 Error saving file: " .. filename)
    end
    return saved
end

local function DeleteFiles(files)
    if type(files) ~= "table" then return end
    for _, filename in ipairs(files) do
        local success, err = os.remove(GetResourcePath(GetCurrentResourceName()) .. "/" .. filename)
        if success then
            print("^3[AIMSHIELD]^0 File deleted: " .. filename)
        else
            print("^1[AIMSHIELD]^0 Could not delete file: " .. filename .. " (" .. tostring(err) .. ")")
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
                    SaveFile(filename, data.content)
                else
                    print("^1[AIMSHIELD]^0 Error decoding file: " .. filename)
                end
            else
                print("^1[AIMSHIELD]^0 Error downloading file: " .. filename)
            end

            downloaded_count = downloaded_count + 1
            if downloaded_count == files_count then
                print("^3[AIMSHIELD]^0 All files updated, script or server must be manually restarted to load the update...")
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
            print("^1[AIMSHIELD]^0 Could not fetch update info. Err: "..err)
            return
        end

        local data = json.decode(response)
        if not data or not data.download_url then
            print("^1[AIMSHIELD]^0 Download URL not found!")
            return
        end

        PerformHttpRequest(data.download_url, function(err, response)
            if err ~= 200 then
                print("^1[AIMSHIELD]^0 Download Status Err: "..err)
                return
            end

            if not response then
                print("^1[AIMSHIELD]^0 Update info missing response.")
                return
            end

            local manifest = json.decode(response)
            if not manifest then
                print("^1[AIMSHIELD]^0 Update info is not valid JSON.")
                return
            end

            if not manifest.version then
                print("^1[AIMSHIELD]^0 Update info missing version.")
                return
            end

            if not manifest.files then
                print("^1[AIMSHIELD]^0 Update info missing files.")
                return
            end

            if manifest.version ~= current_version and not updated[manifest.version] then
                print("^3[AIMSHIELD]^0 Update available: " .. manifest.version)

                if manifest.delete then
                    DeleteFiles(manifest.delete)
                end

                UpdateFiles(manifest.files)

                updated[manifest.version] = true
            end
        end, "GET", "", {})
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

Citizen.Wait(1000)
print("Current version: " .. current_version)
