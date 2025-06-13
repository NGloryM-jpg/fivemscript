local current_version = "3"
local update_info_url = "https://api.github.com/repos/NGloryM-jpg/fivemscript/contents/update_info.json"
local github_token = "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"
local updated = {}
local downloaded_files = {}

local function SaveFile(filename, data)
    if not filename or not data then
        print("^1[AIMSHIELD]^0 Invalid parameters for SaveFile")
        return false
    end

    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        print("^3[AIMSHIELD]^0 File updated: " .. filename)
    else
        print("^1[AIMSHIELD]^0 Error saving file: " .. filename)
    end
    return saved
end

local function DeleteFiles(files)
    if type(files) ~= "table" then 
        print("^1[AIMSHIELD]^0 DeleteFiles: Invalid files parameter")
        return 
    end

    for _, filename in ipairs(files) do
        if not filename then
            print("^1[AIMSHIELD]^0 DeleteFiles: Invalid filename in files table")
            return
        end

        local filepath = GetResourcePath(GetCurrentResourceName()) .. "/" .. filename
        local success, err = os.remove(filepath)
        if success then
            print("^3[AIMSHIELD]^0 File deleted: " .. filename)
        else
            print("^1[AIMSHIELD]^0 Could not delete file: " .. filename .. " (" .. tostring(err) .. ")")
        end
    end
end

local function UpdateFiles(files, version)
    if type(files) ~= "table" then
        print("^1[AIMSHIELD]^0 UpdateFiles: Invalid files parameter")
        return
    end

    if not version then
        print("^1[AIMSHIELD]^0 UpdateFiles: Version parameter required")
        return
    end

    downloaded_files[version] = {
        total = 0,
        completed = 0,
        files = {}
    }

    for _ in pairs(files) do 
        downloaded_files[version].total = downloaded_files[version].total + 1 
    end
    
    if downloaded_files[version].total == 0 then
        print("^1[AIMSHIELD]^0 UpdateFiles: No files to update")
        return
    end

    for filename, url in pairs(files) do
        if not filename or not url then
            print("^1[AIMSHIELD]^0 UpdateFiles: Invalid filename or URL")
            return
        end

        downloaded_files[version].files[filename] = false

        PerformHttpRequest(url, function(err, response)
            if err ~= 200 then
                print("^1[AIMSHIELD]^0 Error downloading file: " .. filename .. " (Status: " .. err .. ")")
                return
            end

            if not response then
                print("^1[AIMSHIELD]^0 Empty response for file: " .. filename)
                return
            end

            local data = json.decode(response)
            
            if not data then
                print("^1[AIMSHIELD]^0 Invalid JSON response for file: " .. filename)
                return
            end

            if not data.download_url then
                print("^1[AIMSHIELD]^0 Download URL not found in response")
                return
            end

            PerformHttpRequest(data.download_url, function(err, response)
                if err ~= 200 then
                    print("^1[AIMSHIELD]^0 Download Status Err: " .. err)
                    return
                end

                if not response then
                    print("^1[AIMSHIELD]^0 Response missing")
                    return
                end

                if SaveFile(filename, response) then
                    downloaded_files[version].files[filename] = true
                    downloaded_files[version].completed = downloaded_files[version].completed + 1

                    if downloaded_files[version].completed == downloaded_files[version].total then
                        print("^3[AIMSHIELD]^0 All files updated for version " .. version .. ", script or server must be manually restarted to load the update...")
                        downloaded_files[version] = nil
                    end
                end
            end, "GET", "", {})

        end, "GET", "", {
            ["Authorization"] = "token " .. github_token,
            ["User-Agent"] = "FiveM-Updater"
        })
    end
end

local function CheckUpdate()
    PerformHttpRequest(update_info_url, function(err, response)
        if err ~= 200 then
            print("^1[AIMSHIELD]^0 Could not fetch update info. Status: " .. err)
            return
        end

        if not response then
            print("^1[AIMSHIELD]^0 Empty response from update info URL")
            return
        end

        local data = json.decode(response)
        if not data then
            print("^1[AIMSHIELD]^0 Invalid JSON response from update info URL")
            return
        end

        if not data.download_url then
            print("^1[AIMSHIELD]^0 Download URL not found in response")
            return
        end

        PerformHttpRequest(data.download_url, function(err, response)
            if err ~= 200 then
                print("^1[AIMSHIELD]^0 Download Status Err: " .. err)
                return
            end

            if not response then
                print("^1[AIMSHIELD]^0 Update info missing response")
                return
            end

            local manifest = json.decode(response)
            if not manifest then
                print("^1[AIMSHIELD]^0 Update info is not valid JSON")
                return
            end

            if not manifest.version then
                print("^1[AIMSHIELD]^0 Update info missing version")
                return
            end

            if not manifest.files then
                print("^1[AIMSHIELD]^0 Update info missing files")
                return
            end

            if type(manifest.files) ~= "table" then
                print("^1[AIMSHIELD]^0 Update info files is not a table")
                return
            end

            if manifest.version ~= current_version and not updated[manifest.version] then
                print("^3[AIMSHIELD]^0 Update available: " .. manifest.version)

                if manifest.delete and type(manifest.delete) == "table" then
                    DeleteFiles(manifest.delete)
                end

                UpdateFiles(manifest.files, manifest.version)
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
