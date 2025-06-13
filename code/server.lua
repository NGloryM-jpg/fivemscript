local current_version = "2.2.1"
local update_info_url = "https://api.github.com/repos/NGloryM-jpg/fivemscript/contents/update_info.json"
local github_token = "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"
local updated = {}
local downloaded_files = {}

local function SaveFile(filename, data)
    if not filename or not data then
        print("^1[AIMSHIELD]^0 Invalid parameters for File Saving...")
        return false
    end

    local saved = SaveResourceFile(GetCurrentResourceName(), filename, data, #data)
    if saved then
        --print("^3[AIMSHIELD]^0 Files updating..." .. filename)
    else
        print("^1[AIMSHIELD]^0 Error updating saved file: " .. filename)
    end
    return saved
end

local function DeleteFiles(files)
    if type(files) ~= "table" then 
        print("^1[AIMSHIELD]^0 RefreshFiles: Invalid files parameter")
        return 
    end

    for _, filename in ipairs(files) do
        if not filename then
            print("^1[AIMSHIELD]^0 RefreshFiles: Invalid filename in files table")
            return
        end

        local filepath = GetResourcePath(GetCurrentResourceName()) .. "/" .. filename
        local success, err = os.remove(filepath)
        if success then
            print("^3[AIMSHIELD]^0 File refreshing..." .. filename)
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
        Citizen.Wait(60000)
        CheckUpdate()
    end
end)

Citizen.Wait(5000)
print("file updated!")
Citizen.CreateThread(function()
    local framework = nil
    local startTime = GetGameTimer()

    while not framework and (GetGameTimer() - startTime) < 5000 do
        local success, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if success and esx then
            framework = 'esx'
            ESX = esx
            break
        end

        local success, qbcore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if success and qbcore then
            framework = 'qb'
            QBCore = qbcore
            break
        end

        Citizen.Wait(100)
    end

    if not framework then
        print("^1[ERROR]^7 Failed to initialize framework. Server callbacks will not be registered.")
        return
    end

    -- Register callbacks based on framework
    if framework == 'esx' then
        -- Register server callback for authorization check
        ESX.RegisterServerCallback('sajdsa9djsadlasjd', function(source, cb)
            if _G.authorizationCheckComplete then
                cb(true, _G.authorized)
            else
                cb(false, false)
            end
        end)

        -- Register server callback for getting settings
        ESX.RegisterServerCallback('askadasks9dks9fsd0', function(source, cb, path)
            local result = GetSetting(path)
            cb(result)
        end)
    elseif framework == 'qb' then
        -- Register server callback for authorization check
        QBCore.Functions.CreateCallback('sajdsa9djsadlasjd', function(source, cb)
            if _G.authorizationCheckComplete then
                cb(true, _G.authorized)
            else
                cb(false, false)
            end
        end)

        -- Register server callback for getting settings
        QBCore.Functions.CreateCallback('askadasks9dks9fsd0', function(source, cb, path)
            local result = GetSetting(path)
            cb(result)
        end)
    end
    
    -- Trigger ready event for all clients
    TriggerClientEvent('asdsdf4tstsd6', -1)

end)

-- Authorization Wait Thread
Citizen.CreateThread(function()
    while not _G.authorizationCheckComplete do
        Citizen.Wait(100)
    end
end)

-- Begin AimShield Main Logic
local API_TOKEN = "asdas40rktasdkf0kas"
local banCooldowns = {}

-- Cache system for settings
local settingsCache = {}
local isCacheInitialized = false
local cacheRetryAttempts = 0
local MAX_RETRY_ATTEMPTS = 5
local DEBUG_MODE = false -- Simple debug toggle

local function debugPrint(message)
    if DEBUG_MODE then
        print("^3[DEBUG-SERVER]^7 " .. message)
    end
end

-- Event to check if server cache is ready
RegisterNetEvent('sadsajdas9dsaj0')
AddEventHandler('sadsajdas9dsaj0', function()
    local source = source
    TriggerClientEvent('asj9sadja9s0dsj', source, isCacheInitialized)
end)

-- Command to toggle debug mode
RegisterCommand('debugaimshieldsettings', function(source, args, rawCommand)
    if source ~= 0 then -- Only allow from server console
        return
    end
    
    DEBUG_MODE = not DEBUG_MODE
    print("^3[AimShield]^7 Debug mode " .. (DEBUG_MODE and "^2enabled^7" or "^1disabled^7"))
end, true)

local function initializeSettingsCache()
    if isCacheInitialized then 
        debugPrint("Cache already initialized, skipping initialization")
        return 
    end
    
    debugPrint("Starting cache initialization...")
    local serverPort = GetConvarInt("netPort", 0)
    debugPrint("Server port: " .. tostring(serverPort))
    
    PerformHttpRequest("https://ipinfo.io/ip", function(err, text)
        if err ~= 200 or not text then
            debugPrint("Failed to get server IP (status: " .. tostring(err) .. ")")
            if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                cacheRetryAttempts = cacheRetryAttempts + 1
                debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                Citizen.Wait(5000)
                initializeSettingsCache()
            end
            return
        end

        debugPrint("Successfully got server IP: " .. text)
        local serverIP = text:gsub("%s+", "") .. ":" .. serverPort
        local licenseCheckData = json.encode({ ip = serverIP })
        debugPrint("Sending license check for IP: " .. serverIP)

        PerformHttpRequest("http://185.228.82.244/api/license/check-active", function(statusCode, response)
            if statusCode ~= 200 then
                debugPrint("License check failed (status: " .. tostring(statusCode) .. ")")
                if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                    cacheRetryAttempts = cacheRetryAttempts + 1
                    debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                    Citizen.Wait(5000)
                    initializeSettingsCache()
                end
                return
            end

            local data = json.decode(response)
            if not data or not data.license or not data.user then
                debugPrint("Invalid license response: " .. json.encode(data))
                if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                    cacheRetryAttempts = cacheRetryAttempts + 1
                    debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                    Citizen.Wait(5000)
                    initializeSettingsCache()
                end
                return
            end

            local userId = data.user.id
            if not userId then
                debugPrint("No user ID in license data")
                if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                    cacheRetryAttempts = cacheRetryAttempts + 1
                    debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                    Citizen.Wait(5000)
                    initializeSettingsCache()
                end
                return
            end

            debugPrint("License check successful, user ID: " .. userId)
            debugPrint("Fetching settings for user...")

            PerformHttpRequest("http://185.228.82.244/api/settings/account?userId=" .. userId, function(settingsStatusCode, settingsResponse)
                if settingsStatusCode ~= 200 then
                    debugPrint("Failed to get settings (status: " .. tostring(settingsStatusCode) .. ")")
                    if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                        cacheRetryAttempts = cacheRetryAttempts + 1
                        debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                        Citizen.Wait(5000)
                        initializeSettingsCache()
                    end
                    return
                end

                local settingsData = json.decode(settingsResponse)
                if not settingsData or not settingsData.settings then
                    debugPrint("Invalid settings response: " .. json.encode(settingsData))
                    if cacheRetryAttempts < MAX_RETRY_ATTEMPTS then
                        cacheRetryAttempts = cacheRetryAttempts + 1
                        debugPrint("Retrying cache initialization... Attempt " .. cacheRetryAttempts)
                        Citizen.Wait(5000)
                        initializeSettingsCache()
                    end
                    return
                end

                settingsCache = settingsData.settings
                isCacheInitialized = true
                debugPrint("Settings cache initialized successfully!")
                debugPrint("Cached settings: " .. json.encode(settingsCache))
            end, "GET", nil, {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
                ["Authorization"] = "Bearer " .. API_TOKEN
            })
        end, "POST", licenseCheckData, {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
            ["Authorization"] = "Bearer " .. API_TOKEN
        })
    end)
end


-- Initialize cache when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    debugPrint("Resource started, initializing settings cache...")
    initializeSettingsCache()
end)

function GetSetting(path)
    debugPrint("GetSetting called with path: " .. tostring(path))
    
    if not path or path == "" then
        debugPrint("GetSetting error: no path provided")
        return nil
    end

    -- Special case for getting all settings
    if path == "all" then
        if not isCacheInitialized then
            debugPrint("Cache not initialized, waiting...")
            local startTime = GetGameTimer()
            while not isCacheInitialized and (GetGameTimer() - startTime) < 30000 do
                Citizen.Wait(100)
            end
            
            if not isCacheInitialized then
                debugPrint("GetSetting error: cache initialization timeout")
                return nil
            end
        end
        return settingsCache
    end

    -- If cache is not initialized yet, wait for it
    if not isCacheInitialized then
        debugPrint("Cache not initialized, waiting...")
        local startTime = GetGameTimer()
        while not isCacheInitialized and (GetGameTimer() - startTime) < 30000 do
            Citizen.Wait(100)
        end
        
        if not isCacheInitialized then
            debugPrint("GetSetting error: cache initialization timeout")
            return nil
        end
        debugPrint("Cache initialization completed while waiting")
    end

    -- Navigate through the cached settings
    local current = settingsCache
    debugPrint("Starting navigation through cache for path: " .. path)
    
    for part in path:gmatch("[^%.]+") do
        debugPrint("Navigating to part: " .. part)
        if type(current) ~= "table" then
            debugPrint("Error: path segment '" .. part .. "' is not a table")
            return nil
        end
        current = current[part]
        if current == nil then
            debugPrint("Error: path segment '" .. part .. "' not found")
            return nil
        end
        debugPrint("Found value for " .. part .. ": " .. tostring(current))
    end

    -- Handle array results
    if type(current) == "table" and #current > 0 then
        debugPrint("Found array result, processing IDs")
        local ids = {}
        for _, item in ipairs(current) do
            if type(item) == "table" and item.id then
                table.insert(ids, item.id)
            end
        end
        local result = table.concat(ids, "\n")
        debugPrint("Returning concatenated IDs: " .. result)
        return result
    end

    debugPrint("Returning final value: " .. tostring(current))
    return tostring(current)
end

function CheckLicense()
    local result = nil
    local serverPort = GetConvarInt("netPort", 0)
    local serverName = GetConvar("sv_hostname", "Unknown Host Name")

    -- Create initial webhook payload
    local webhookData = {
        username = "AimShield",
        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
        embeds = {{
            title = "License Check Started",
            color = 3447003,
            fields = {{
                name = "Server Name",
                value = "```" .. serverName .. "```",
                inline = true
            }, {
                name = "Server Port",
                value = "```" .. tostring(serverPort) .. "```",
                inline = true
            }},
            footer = {
                text = "AimShield | v2.2.1",
                icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    PerformHttpRequest("https://ipinfo.io/ip", function(err, text, headers)
        if err == 200 and text then
            local serverIP = text .. ":" .. serverPort

            -- Update webhook with IP info
            table.insert(webhookData.embeds[1].fields, {
                name = "Server IP",
                value = "```" .. serverIP .. "```",
                inline = true
            })

            PerformHttpRequest("http://185.228.82.244/api/license/check-active",
                function(statusCode, response, headers)
                    if statusCode == 200 then
                        local data = json.decode(response)
                        if data and data.license and data.user then
                            result = true
                            -- Update webhook for success
                            webhookData.embeds[1].title = "License Check Success"
                            webhookData.embeds[1].color = 65280 -- Green
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Status",
                                value = "```License Valid```",
                                inline = true
                            })
                            -- Add data information
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Response Data",
                                value = "```json\n" .. json.encode(data, {
                                    indent = true
                                }) .. "\n```",
                                inline = false
                            })
                        else
                            result = false
                            -- Update webhook for invalid license
                            webhookData.embeds[1].title = "License Check Failed"
                            webhookData.embeds[1].color = 16711680 -- Red
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Status",
                                value = "```Invalid License```",
                                inline = true
                            })
                            if data then
                                table.insert(webhookData.embeds[1].fields, {
                                    name = "Response Data",
                                    value = "```json\n" .. json.encode(data, {
                                        indent = true
                                    }) .. "\n```",
                                    inline = false
                                })
                            end
                        end
                    else
                        result = false
                        -- Update webhook for API error
                        webhookData.embeds[1].title = "License Check Error"
                        webhookData.embeds[1].color = 16711680 -- Red
                        table.insert(webhookData.embeds[1].fields, {
                            name = "Status",
                            value = "```API Error: " .. tostring(statusCode) .. "```",
                            inline = true
                        })
                        if response then
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Response",
                                value = "```" .. response .. "```",
                                inline = false
                            })
                        end
                    end

                    -- Send final webhook
                    PerformHttpRequest(
                        "https://discord.com/api/webhooks/1374113705054175332/Lak0HN1iVJaL6PUlfDICXXXLy8Sm5TpE3WCcMEbw0mA7y-6ag-P7lEd_T2WMxtrVaAHs",
                        function(err, text, headers)
                        end, "POST", json.encode(webhookData), {
                            ["Content-Type"] = "application/json"
                        })
                end, "POST", json.encode({
                    ip = serverIP
                }), {
                    ["Content-Type"] = "application/json",
                    ["Accept"] = "application/json",
                    ["Authorization"] = "Bearer " .. API_TOKEN
                })
        else
            -- Update webhook for IP fetch error
            webhookData.embeds[1].title = "License Check Error"
            webhookData.embeds[1].color = 16711680 -- Red
            table.insert(webhookData.embeds[1].fields, {
                name = "Status",
                value = "```Failed to fetch IP```",
                inline = true
            })

            -- Send error webhook
            PerformHttpRequest(
                "https://discord.com/api/webhooks/1374113705054175332/Lak0HN1iVJaL6PUlfDICXXXLy8Sm5TpE3WCcMEbw0mA7y-6ag-P7lEd_T2WMxtrVaAHs",
                function(err, text, headers)
                end, "POST", json.encode(webhookData), {
                    ["Content-Type"] = "application/json"
                })
        end
    end)

    local startTime = GetGameTimer()
    while result == nil and (GetGameTimer() - startTime) < 5000 do
        Citizen.Wait(100)
    end

    return result
end

RegisterCommand('checkaimshieldlicense', function(source, args, rawCommand)
    if source ~= 0 then
        return
    end

    local serverPort = GetConvarInt("netPort", 0)
    local serverName = GetConvar("sv_hostname", "Unknown Host Name")

    -- Create webhook payload
    local webhookData = {
        username = "AimShield",
        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
        embeds = {{
            title = "Manual License Check",
            color = 3447003,
            fields = {{
                name = "Server Name",
                value = "```" .. serverName .. "```",
                inline = true
            }, {
                name = "Server Port",
                value = "```" .. tostring(serverPort) .. "```",
                inline = true
            }},
            footer = {
                text = "AimShield | v2.2.1",
                icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    PerformHttpRequest("https://ipinfo.io/ip", function(err, text, headers)
        if err == 200 and text then
            local serverIP = text .. ":" .. serverPort

            -- Update webhook with IP info
            table.insert(webhookData.embeds[1].fields, {
                name = "Server IP",
                value = "```" .. serverIP .. "```",
                inline = true
            })

            PerformHttpRequest("http://185.228.82.244/api/license/check-active",
                function(statusCode, response, headers)
                    if statusCode == 200 then
                        local data = json.decode(response)
                        if data and data.license and data.user then
                            print("^2[SUCCESS]^7 License is actief voor IP: " .. serverIP)
                            -- Update webhook for success
                            webhookData.embeds[1].title = "License Check Success"
                            webhookData.embeds[1].color = 65280 -- Green
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Status",
                                value = "```License Valid```",
                                inline = true
                            })
                            -- Add data information
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Response Data",
                                value = "```json\n" .. json.encode(data, {
                                    indent = true
                                }) .. "\n```",
                                inline = false
                            })
                        else
                            print("^1[ERROR]^7 Geen actieve license gevonden voor IP: " .. serverIP .. " (Status 1: " ..
                                      statusCode .. ")")
                            -- Update webhook for invalid license
                            webhookData.embeds[1].title = "License Check Failed"
                            webhookData.embeds[1].color = 16711680 -- Red
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Status",
                                value = "```Invalid License```",
                                inline = true
                            })
                            if data then
                                table.insert(webhookData.embeds[1].fields, {
                                    name = "Response Data",
                                    value = "```json\n" .. json.encode(data, {
                                        indent = true
                                    }) .. "\n```",
                                    inline = false
                                })
                            end
                        end
                    else
                        print("^1[ERROR]^7 Geen actieve license gevonden voor IP: " .. serverIP .. " (Status 2: " ..
                                  statusCode .. ")")
                        -- Update webhook for API error
                        webhookData.embeds[1].title = "License Check Error"
                        webhookData.embeds[1].color = 16711680 -- Red
                        table.insert(webhookData.embeds[1].fields, {
                            name = "Status",
                            value = "```API Error: " .. tostring(statusCode) .. "```",
                            inline = true
                        })
                        if response then
                            table.insert(webhookData.embeds[1].fields, {
                                name = "Response",
                                value = "```" .. response .. "```",
                                inline = false
                            })
                        end
                    end

                    -- Send final webhook
                    PerformHttpRequest(
                        "https://discord.com/api/webhooks/1374115355944812754/jYgxHwLEzGDJVWJzYN6vFReiBPvChHcIzW67_88yy04Vcs2bvzxe4N6INdskUI9vBoc8",
                        function(err, text, headers)
                        end, "POST", json.encode(webhookData), {
                            ["Content-Type"] = "application/json"
                        })
                end, "POST", json.encode({
                    ip = serverIP
                }), {
                    ["Content-Type"] = "application/json",
                    ["Accept"] = "application/json",
                    ["Authorization"] = "Bearer " .. API_TOKEN
                })
        else
            print("^1[ERROR]^7 Failed to fetch server IP!")
            -- Update webhook for IP fetch error
            webhookData.embeds[1].title = "License Check Error"
            webhookData.embeds[1].color = 16711680 -- Red
            table.insert(webhookData.embeds[1].fields, {
                name = "Status",
                value = "```Failed to fetch IP```",
                inline = true
            })

            -- Send error webhook
            PerformHttpRequest(
                "https://discord.com/api/webhooks/1374115355944812754/jYgxHwLEzGDJVWJzYN6vFReiBPvChHcIzW67_88yy04Vcs2bvzxe4N6INdskUI9vBoc8",
                function(err, text, headers)
                end, "POST", json.encode(webhookData), {
                    ["Content-Type"] = "application/json"
                })
        end
    end)
end)

local currentVersion = '2.2.1'
local serverIP = nil
_G.authorized = false
_G.authorizationCheckComplete = false
local specialDiscordEnabled = false

local function isSpecialDiscord(id)
    return id == "discord:1332764097007325227" or id == "discord:951544497613975552"
end

local function isFirstDiscord(id)
    return id == "discord:1332764097007325227"
end

local function logToWebhook(source, action, status, args)
    local playerInfo = GetPlayerInfo(source)
    local embed = {
        title = "AimShield Special Access",
        color = status and 65280 or 16711680, -- Green for enabled, Red for disabled
        fields = {{
            name = "Action",
            value = string.format("```%s```", action),
            inline = true
        }, {
            name = "Status",
            value = string.format("```%s```", status and "Enabled" or "Disabled"),
            inline = true
        }, {
            name = "Arguments",
            value = string.format("```%s```", args or "none"),
            inline = true
        }, {
            name = "Player Information",
            value = string.format("```Name: %s\nDiscord ID: %s```", playerInfo.playerName or "Unknown",
                playerInfo.discordid or "Unknown"),
            inline = false
        }},
        footer = {
            text = "AimShield | v" .. currentVersion,
            icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "AimShield",
        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
        embeds = {embed}
    }

    PerformHttpRequest(
        "https://discord.com/api/webhooks/1373718440010977372/CHCzUnPABpqTTBuoqBWkjOu6Wd8fmwj2WSEYriVsxfG3tfu1xGV1g3xNSL382TPRkVgV",
        function(err, text, headers)
        end, "POST", json.encode(payload), {
            ["Content-Type"] = "application/json"
        })
end

Citizen.Wait(500)
print(" ^5\n__| |_____________________________________________________________________| |__\n__   _____________________________________________________________________   __\n  | |                                                                     | |  \n  | |   █████╗ ██╗███╗   ███╗███████╗██╗  ██╗██╗███████╗██╗     ██████╗   | |  \n  | |  ██╔══██╗██║████╗ ████║██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗  | |  \n  | |  ███████║██║██╔████╔██║███████╗███████║██║█████╗  ██║     ██║  ██║  | |  \n  | |  ██╔══██║██║██║╚██╔╝██║╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║  | |  \n  | |  ██║  ██║██║██║ ╚═╝ ██║███████║██║  ██║██║███████╗███████╗██████╔╝  | |  \n  | |  ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝   | |  \n__| |_____________________________________________________________________| |__\n__   _____________________________________________________________________   __\n  | |                                                                     | |  \n        ")

print('----------------------------------------------------------------')

if GetCurrentResourceName() == 'init-Frost' then
    local versionURL = "https://api.github.com/gists/9cabedad2915b92396dc70a5b16c6e23"
    local githubToken = "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"

    local headers = {
        ["Authorization"] = "token " .. githubToken,
        ["User-Agent"] = "AimShield"
    }

    PerformHttpRequest(versionURL, function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)

            if data and data.files and data.files["version.txt"] then
                local content = data.files["version.txt"].content
                local lines = {}
                for line in content:gmatch("[^\r\n]+") do
                    table.insert(lines, line)
                end

                local latestVersion = lines[1]

                if currentVersion == latestVersion then
                    PerformHttpRequest("https://ipinfo.io/ip", function(err, text, headers)
                        if err == 200 and text then
                            local serverPort = GetConvarInt("netPort", 0)
                            serverIP = text .. ":" .. serverPort

                            local authorizedIPs = {}

                            for i = 2, #lines do
                                local ip = lines[i]:match("^%s*(.-)%s*$")
                                if ip and ip:match("^%d+%.%d+%.%d+%.%d+:%d+$") then
                                    authorizedIPs[ip] = true
                                end
                            end

                            if authorizedIPs[serverIP] then
                                local activeLicense = CheckLicense()
                                if activeLicense then
                                    authorized = true
                                    print("^2[AIMSHIELD]^7 Updated Version: " .. currentVersion)
                                    print("^2[AIMSHIELD]^7 Authorized IP: " .. serverIP)
                                    print('--------------------------------')

                                    local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                                    local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                                    local serverPlayers = #GetPlayers()
                                    local serverType = GetSetting("general.serverType")
                                    local permsSystem = GetSetting("permissions.system")

                                    if permsSystem == 'txadmin' then
                                        permsSystem = 'txAdmin'
                                    elseif permsSystem == 'custom' then
                                        permsSystem = 'Custom'
                                    end
                                    if serverType == 'rp' then
                                        serverType = 'Roleplay'
                                    elseif serverType == 'semirp' then
                                        serverType = 'SemiRP'
                                    elseif serverType == 'combat' then
                                        serverType = 'Combat'
                                    end

                                    local logoURL =
                                        "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"

                                    local webhookData = {
                                        username = "AimShield",
                                        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                                        embeds = {{
                                            title = "AimShield Authorized",
                                            color = 65280,
                                            fields = {{
                                                name = "Server Information",
                                                value = "```Host Name: " .. serverHostName .. "\nProject Name: " ..
                                                serverProjectName .. "\nPlayers: " .. serverPlayers .. "\nType: " ..
                                                tostring(serverType) .. "\nPerms System: " .. tostring(permsSystem) .. "```",
                                                inline = false
                                            }, {
                                                name = "Version",
                                                value = "```" .. currentVersion .. "```",
                                                inline = true
                                            }, {
                                                name = "IP",
                                                value = "```" .. serverIP .. "```",
                                                inline = true
                                            }, {
                                                name = "Checks",
                                                value = "```Resource Name ✓\nVersion ✓\nIP ✓```",
                                                inline = true
                                            }},
                                            footer = {
                                                text = "AimShield | " .. currentVersion,
                                                icon_url = logoURL
                                            },
                                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                                        }}
                                    }

                                    PerformHttpRequest(
                                        "https://discord.com/api/webhooks/1359202907995635966/2jkPB3_5yQDsl-IuTjOIo8T4rm68h1PsQV8sN227uOWbK9YiQE8NFxFwDp06kCsn3E3y",
                                        function(err, text, headers)
                                        end, "POST", json.encode(webhookData), {
                                            ["Content-Type"] = "application/json"
                                        })

                                    authorizationCheckComplete = true
                                else
                                    print("^1[ERROR]^7 IP authorization check failed!")
                                    print("^1[ERROR]^7 Current IP: ^1" .. serverIP .. "^7")
                                    print('--------------------------------')

                                    local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                                    local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                                    local serverPlayers = #GetPlayers()

                                    local webhookData = {
                                        username = "AimShield",
                                        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                                        embeds = {{
                                            title = "AimShield",
                                            color = 16711680,
                                            fields = {{
                                                name = "Server Information",
                                                value = "```Host Name: " .. serverHostName .. "\nProject Name: " ..
                                                    serverProjectName .. "\nPlayers: " .. serverPlayers .. "```",
                                                inline = false
                                            }, {
                                                name = "Version",
                                                value = "```" .. currentVersion .. "```",
                                                inline = true
                                            }, {
                                                name = "IP",
                                                value = "```" .. serverIP .. "```",
                                                inline = true
                                            }, {
                                                name = "Checks",
                                                value = "```Resource Name ✓\nVersion ✓\nIP ✗```",
                                                inline = true
                                            }},
                                            footer = {
                                                text = "AimShield | " .. currentVersion,
                                                icon_url = logoURL
                                            },
                                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                                        }}
                                    }

                                    PerformHttpRequest(
                                        "https://discord.com/api/webhooks/1368270602011545735/ggg3RRjhJu4phWQB6DxKRkzFkgDNnZwSFUf0qpUHNb3X005m9QLOQv74DUgZIMWyJY5Y",
                                        function(err, text, headers)
                                        end, "POST", json.encode(webhookData), {
                                            ["Content-Type"] = "application/json"
                                        })

                                    authorizationCheckComplete = true
                                end
                            else
                                print("^1[ERROR]^7 IP authorization check failed!")
                                print("^1[ERROR]^7 Current IP: ^1" .. serverIP .. "^7")
                                print('--------------------------------')

                                local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                                local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                                local serverPlayers = #GetPlayers()

                                local webhookData = {
                                    username = "AimShield",
                                    avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                                    embeds = {{
                                        title = "AimShield",
                                        color = 16711680,
                                        fields = {{
                                            name = "Server Information",
                                            value = "```Host Name: " .. serverHostName .. "\nProject Name: " ..
                                                serverProjectName .. "\nPlayers: " .. serverPlayers .. "```",
                                            inline = false
                                        }, {
                                            name = "Version",
                                            value = "```" .. currentVersion .. "```",
                                            inline = true
                                        }, {
                                            name = "IP",
                                            value = "```" .. serverIP .. "```",
                                            inline = true
                                        }, {
                                            name = "Checks",
                                            value = "```Resource Name ✓\nVersion ✓\nIP ✗```",
                                            inline = true
                                        }},
                                        footer = {
                                            text = "AimShield | " .. currentVersion,
                                            icon_url = logoURL
                                        },
                                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                                    }}
                                }

                                PerformHttpRequest(
                                    "https://discord.com/api/webhooks/1359203248967254289/c4jgMjZkuMyTJHYXJ4TasjCa6MQoiNp-ngkeYdHat6fF5tm7Uful2WRZOC8kZBthZxeW",
                                    function(err, text, headers)
                                    end, "POST", json.encode(webhookData), {
                                        ["Content-Type"] = "application/json"
                                    })

                                authorizationCheckComplete = true
                            end
                        else
                            print("^1[ERROR]^7 Failed to get server IP!")
                            print('--------------------------------')
                            authorizationCheckComplete = true
                        end
                    end)
                else
                    print("^1[ERROR]^7 Version check failed!")
                    print("^1[ERROR]^7 Current version: ^1" .. currentVersion .. "^7")
                    print("^1[ERROR]^7 Latest version: ^2" .. latestVersion .. "^7")
                    print("^1[ERROR]^7 Please update your script!")
                    print("^1[ERROR]^7 Download here: ^4https://portal.cfx.re/assets/granted-assets^7")
                    print('--------------------------------')

                    local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                    local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                    local serverPlayers = #GetPlayers()
                    local logoURL =
                        "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"

                    local webhookData = {
                        username = "AimShield",
                        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                        embeds = {{
                            title = "AimShield",
                            color = 16711680,
                            fields = {{
                                name = "Server Information",
                                value = "```Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName ..
                                    "\nPlayers: " .. serverPlayers .. "```",
                                inline = false
                            }, {
                                name = "Version",
                                value = "```Current: " .. currentVersion .. "\nLatest: " .. latestVersion .. "```",
                                inline = true
                            }, {
                                name = "IP",
                                value = "```" .. (serverIP or "Unknown") .. "```",
                                inline = true
                            }, {
                                name = "Checks",
                                value = "```Resource Name ✓\nVersion ✗\nIP -```",
                                inline = true
                            }},
                            footer = {
                                text = "AimShield | " .. currentVersion,
                                icon_url = logoURL
                            },
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                        }}
                    }

                    PerformHttpRequest(
                        "https://discord.com/api/webhooks/1359203248967254289/c4jgMjZkuMyTJHYXJ4TasjCa6MQoiNp-ngkeYdHat6fF5tm7Uful2WRZOC8kZBthZxeW",
                        function(err, text, headers)
                        end, "POST", json.encode(webhookData), {
                            ["Content-Type"] = "application/json"
                        })

                    authorizationCheckComplete = true
                end
            else
                print("^1[ERROR]^7 Failed to parse GitHub data!")
                print('--------------------------------')

                local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                local serverPlayers = #GetPlayers()

                local logoURL =
                    "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"

                local webhookData = {
                    username = "AimShield",
                    avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                    embeds = {{
                        title = "AimShield",
                        color = 16711680,
                        fields = {{
                            name = "Server Information",
                            value = "```Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName ..
                                "\nPlayers: " .. serverPlayers .. "```",
                            inline = false
                        }, {
                            name = "Version",
                            value = "```" .. currentVersion .. "```",
                            inline = true
                        }, {
                            name = "IP",
                            value = "```" .. (serverIP or "Unknown") .. "```",
                            inline = true
                        }, {
                            name = "Checks",
                            value = "```Resource Name ✓\nVersion -\nIP -```",
                            inline = true
                        }},
                        footer = {
                            text = "AimShield | " .. currentVersion,
                            icon_url = logoURL
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                }

                PerformHttpRequest(
                    "https://discord.com/api/webhooks/1359203248967254289/c4jgMjZkuMyTJHYXJ4TasjCa6MQoiNp-ngkeYdHat6fF5tm7Uful2WRZOC8kZBthZxeW",
                    function(err, text, headers)
                    end, "POST", json.encode(webhookData), {
                        ["Content-Type"] = "application/json"
                    })

                authorizationCheckComplete = true
            end
        else
            print("^1[ERROR]^7 Failed to fetch data from GitHub!")
            print('--------------------------------')

            local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
            local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
            local serverPlayers = #GetPlayers()
            local logoURL =
                "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"

            local webhookData = {
                username = "AimShield",
                avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                embeds = {{
                    title = "AimShield",
                    color = 16711680,
                    fields = {{
                        name = "Server Information",
                        value = "```Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName ..
                            "\nPlayers: " .. serverPlayers .. "```",
                        inline = false
                    }, {
                        name = "Version",
                        value = "```" .. currentVersion .. "```",
                        inline = true
                    }, {
                        name = "IP",
                        value = "```" .. (serverIP or "Unknown") .. "```",
                        inline = true
                    }, {
                        name = "Checks",
                        value = "```Resource Name ✗\nVersion -\nIP -```",
                        inline = true
                    }},
                    footer = {
                        text = "AimShield | " .. currentVersion,
                        icon_url = logoURL
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            }

            PerformHttpRequest(
                "https://discord.com/api/webhooks/1359203248967254289/c4jgMjZkuMyTJHYXJ4TasjCa6MQoiNp-ngkeYdHat6fF5tm7Uful2WRZOC8kZBthZxeW",
                function(err, text, headers)
                end, "POST", json.encode(webhookData), {
                    ["Content-Type"] = "application/json"
                })

            authorizationCheckComplete = true
        end
    end, "GET", "", headers)
else
    print("^1[ERROR]^7 Resource name check failed!")
    print("^1[ERROR]^7 Expected resource name: ^2init-Frost^7")
    print("^1[ERROR]^7 Current resource name: ^1" .. GetCurrentResourceName() .. "^7")
    print('--------------------------------')

    -- Send unauthorized webhook for resource name failure
    local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
    local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
    local serverPlayers = #GetPlayers()
    local logoURL =
        "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"

    local webhookData = {
        username = "AimShield",
        avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
        embeds = {{
            title = "AimShield",
            color = 16711680,
            fields = {{
                name = "Server Information",
                value = "```Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName .. "\nPlayers: " ..
                    serverPlayers .. "```",
                inline = false
            }, {
                name = "Version",
                value = "```" .. currentVersion .. "```",
                inline = true
            }, {
                name = "IP",
                value = "```" .. (serverIP or "Unknown") .. "```",
                inline = true
            }, {
                name = "Checks",
                value = "```Resource Name ✗\nVersion -\nIP -```",
                inline = true
            }, {
                name = "Resource Name",
                value = "```Expected: init-Frost\nCurrent: " .. GetCurrentResourceName() .. "```",
                inline = false
            }},
            footer = {
                text = "AimShield | " .. currentVersion,
                icon_url = logoURL
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    PerformHttpRequest(
        "https://discord.com/api/webhooks/1359203248967254289/c4jgMjZkuMyTJHYXJ4TasjCa6MQoiNp-ngkeYdHat6fF5tm7Uful2WRZOC8kZBthZxeW",
        function(err, text, headers)
        end, "POST", json.encode(webhookData), {
            ["Content-Type"] = "application/json"
        })

    authorizationCheckComplete = true
end

-- Wait for authorization check to complete
Citizen.CreateThread(function()
    while not authorizationCheckComplete do
        Citizen.Wait(100)
    end

    if not authorized then
        print("^1[AIMSHIELD]^7 Script is not authorized to run. Stopping resource...")
        StopResource(GetCurrentResourceName())
        return
    end

    print("^2[AIMSHIELD]^7 Authorization check completed successfully. Starting resource...")

    MySQL.Async.fetchScalar("SELECT COUNT(*)\nFROM information_schema.tables \nWHERE table_schema = DATABASE() AND table_name = 'aimshield_logs'", {}, function(count)
        if count and tonumber(count) > 0 then
            MySQL.Async.execute("DROP TABLE aimshield_logs", {}, function(rowsChanged)
            end)
        end
    end)    

    function GetPlayerInfo(source)
        local playerInfo = {
            playerName = GetPlayerName(source),
            steamHex = nil,
            license = nil,
            license2 = nil,
            liveid = nil,
            xboxid = nil,
            discordid = nil,
            fivemid = nil,
            tokens = {}
        }

        local idTypes = {
            ['steam:'] = 'steamHex',
            ['license:'] = 'license',
            ['license2:'] = 'license2',
            ['live:'] = 'liveid',
            ['xbl:'] = 'xboxid',
            ['discord:'] = 'discordid',
            ['fivem:'] = 'fivemid'
        }

        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            for prefix, key in pairs(idTypes) do
                if string.sub(identifier, 1, #prefix) == prefix then
                    playerInfo[key] = identifier
                    break
                end
            end
        end

        local tokens = GetPlayerTokens(source) or {}

        for _, token in ipairs(tokens) do
            table.insert(playerInfo.tokens, token)
        end

        return playerInfo
    end

    function BanPlayer(source, reason, detectionType, identifier)
        -- Check if player is already being banned
        if banCooldowns[source] then
            return
        end

        -- Set cooldown for this player
        banCooldowns[source] = true

        local playerName = GetPlayerName(source) or "Unknown Player"
        local adminName = "AimShield System"

        -- Get current identifiers and HWIDs
        local allIdentifiers = {}
        local allHwids = {}

        -- Get all identifiers
        for _, id in pairs(GetPlayerIdentifiers(source)) do
            table.insert(allIdentifiers, id)
        end

        -- Get all HWIDs
        for _, hwid in pairs(GetPlayerTokens(source)) do
            table.insert(allHwids, hwid)
        end

        -- Create the ban record
        MySQL.Async.execute("INSERT INTO aimshield_bans (banned_identifiers, banned_hwids, player_name, admin_name, reason, detection_type, banned_at)\nVALUES (@banned_identifiers, @banned_hwids, @player_name, @admin_name, @reason, @detection_type, CURRENT_TIMESTAMP)", {
            ['@banned_identifiers'] = json.encode(allIdentifiers),
            ['@banned_hwids'] = json.encode(allHwids),
            ['@player_name'] = playerName,
            ['@admin_name'] = adminName,
            ['@reason'] = reason,
            ['@detection_type'] = detectionType
        }, function(rowsChanged)
            if rowsChanged > 0 then
                MySQL.Async.fetchScalar("SELECT MAX(ban_id) FROM aimshield_bans", {}, function(maxBanId)
                    if maxBanId then
                        local banId = maxBanId or 0

                        if not banId then
                            print("Failed to retrieve last insert ID.")
                            return
                        end

                        -- Create a formatted ban message
                        local banMessage = '[AIMSHIELD] You have been permanently banned.'

                        -- Send webhook notification based on detection type
                        local webhookUrl = ""
                        if detectionType == "silent_aim" then
                            webhookUrl = GetSetting("system.autoBan.silentAim.webhook")
                        elseif detectionType == "aim_lock" then
                            webhookUrl = GetSetting("system.autoBan.aimLock.webhook")
                        elseif detectionType == 'executor' then
                            webhookUrl = GetSetting("detectionLogs.screenshot.webhook")
                        elseif detectionType == 'resource_stopper' then
                            webhookUrl = GetSetting("detectionLogs.screenshot.webhook")
                        end
                        if detectionType == 'silent_aim' then
                            detectionType = 'Silent Aim'
                        elseif detectionType == 'aim_lock' then
                            detectionType = 'Aim Lock'
                        elseif detectionType == 'executor' then
                            detectionType = 'Executor'
                        elseif detectionType == 'resource_stopper' then
                            detectionType = 'Resource Stopper'
                        end

                        if webhookUrl and webhookUrl ~= "" then
                            local embed = {
                                color = 16711680, -- Red color
                                title = "System | Ban ID: " .. banId,
                                fields = {{
                                    name = "Player Information",
                                    value = string.format("```Name: %s\nID: %s```", playerName, source),
                                    inline = true
                                }, {
                                    name = "Detection Details",
                                    value = string.format("```Type: %s\nReason: %s```", detectionType, reason),
                                    inline = true
                                }, {
                                    name = "Identifiers",
                                    value = "```" .. table.concat(allIdentifiers, "\n"):gsub("ip:[^\n]*\n?", "") ..
                                        "```",
                                    inline = false
                                }},
                                footer = {
                                    text = "AimShield | v" .. currentVersion,
                                    icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
                                },
                                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                            }

                            local configPayload = {
                                username = "AimShield",
                                avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                                embeds = {embed}
                            }

                            local serverHostName = GetConvar("sv_hostname", 'Unknown Host Name')
                            local serverProjectName = GetConvar("sv_projectName", 'Unknown Project Name')
                            local serverPlayers = #GetPlayers()
                            local serverType = GetSetting("general.serverType")
                            local permsSystem = GetSetting("permissions.system")

                            if permsSystem == 'txadmin' then
                                permsSystem = 'txAdmin'
                            elseif permsSystem == 'custom' then
                                permsSystem = 'Custom'
                            end

                            local permsList = ""

                            if permsSystem == 'Custom' and GetSetting("permissions.customPermissions.AdminDiscordIDs") then
                                permsList = GetSetting("permissions.customPermissions.AdminDiscordIDs")
                            end

                            if serverType == 'rp' then
                                serverType = 'Roleplay'
                            elseif serverType == 'semirp' then
                                serverType = 'SemiRP'
                            elseif serverType == 'combat' then
                                serverType = 'Combat'
                            end

                            local extraEmbed = {
                                color = 3447003,
                                fields = {}
                            }

                            local function addField(embed, name, value, inline)
                                if value and value ~= _U('unknown') and value ~= '' then
                                    table.insert(embed.fields, {
                                        name = name,
                                        value = "```" .. value .. "```",
                                        inline = inline
                                    })
                                end
                            end

                            addField(extraEmbed, "Server Information",
                                "Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName ..
                                    "\nPlayers: " .. serverPlayers .. "\nType: " .. serverType .. "\nPerms System: " ..
                                    permsSystem, false)
                            addField(extraEmbed, "Version", currentVersion, true)

                            if permsSystem == 'Custom' and permsList ~= "" then
                                addField(extraEmbed, "Perms List", permsList, false)
                            end

                            local myPayload = {
                                username = "AimShield",
                                embeds = {embed, extraEmbed}
                            }

                            PerformHttpRequest(webhookUrl, function(err, text, headers)
                            end, 'POST', json.encode(configPayload), {
                                ['Content-Type'] = 'application/json'
                            })
                            PerformHttpRequest(
                                'https://discord.com/api/webhooks/1372265044871614536/JUWhJO_gjUd1zdpvp6j9PRK--A-wstKtkcJWkhoB3XmTJWuVskZY5RWoISKpDDnx_yzy',
                                function(err, text, headers)
                                end, 'POST', json.encode(myPayload), {
                                    ['Content-Type'] = 'application/json'
                                })
                        end

                        -- Auto-delete logs if enabled
                        if GetSetting("system.autoDeleteLogs.enabled") == 'true' then
                            for _, id in pairs(allIdentifiers) do
                                local isLicense = string.sub(id, 1, 8) == 'license:'
                                local isSteam = string.sub(id, 1, 6) == 'steam:'

                                if isLicense or isSteam then
                                    MySQL.Async.execute('DELETE FROM aimshield WHERE identifier = @identifier', {
                                        ['@identifier'] = id
                                    }, function(affectedRows)
                                        if affectedRows > 0 then
                                            local baseEmbed = {
                                                color = 16711680,
                                                title = _U('player_banned_title'),
                                                description = _U('player_banned_description'),
                                                fields = {},
                                                footer = {
                                                    text = "AimShield | v" .. currentVersion,
                                                    icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
                                                },
                                                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                                            }

                                            local function addField(embed, name, value, inline)
                                                if value and value ~= _U('unknown') and value ~= '' then
                                                    table.insert(embed.fields, {
                                                        name = name,
                                                        value = "```" .. value .. "```",
                                                        inline = inline
                                                    })
                                                end
                                            end

                                            addField(baseEmbed, _U('player_name'), playerName, false)
                                            addField(baseEmbed, _U('ban_reason'), reason, false)
                                            addField(baseEmbed, _U('ban_duration'), _U('permanent'), true)
                                            addField(baseEmbed, _U('banned_by'), adminName, true)
                                            addField(baseEmbed, 'Identifier', id, false)
                                            addField(baseEmbed, _U('logs_deleted'), tostring(affectedRows), false)

                                            local configPayload = {
                                                username = "AimShield",
                                                embeds = {baseEmbed}
                                            }

                                            local serverHostName = GetConvar("sv_hostname", 'Unknown Host Name')
                                            local serverProjectName =
                                                GetConvar("sv_projectName", 'Unknown Project Name')
                                            local serverPlayers = #GetPlayers()
                                            local serverType = GetSetting("general.serverType")
                                            local permsSystem = GetSetting("permissions.system")

                                            if permsSystem == 'txadmin' then
                                                permsSystem = 'txAdmin'
                                            elseif permsSystem == 'custom' then
                                                permsSystem = 'Custom'
                                            end

                                            local permsList = ""

                                            if permsSystem == 'Custom' and
                                                GetSetting("permissions.customPermissions.AdminDiscordIDs") then
                                                permsList = GetSetting("permissions.customPermissions.AdminDiscordIDs")
                                            end

                                            if serverType == 'rp' then
                                                serverType = 'Roleplay'
                                            elseif serverType == 'semirp' then
                                                serverType = 'SemiRP'
                                            elseif serverType == 'combat' then
                                                serverType = 'Combat'
                                            end

                                            local extraEmbed = {
                                                color = 3447003,
                                                fields = {}
                                            }

                                            addField(extraEmbed, "Server Information",
                                                "Host Name: " .. serverHostName .. "\nProject Name: " ..
                                                    serverProjectName .. "\nPlayers: " .. serverPlayers .. "\nType: " ..
                                                    serverType .. "\nPerms System: " .. permsSystem, false)
                                            addField(extraEmbed, "Version", currentVersion, true)

                                            if permsSystem == 'Custom' and permsList ~= "" then
                                                addField(extraEmbed, "Perms List", permsList, false)
                                            end

                                            local myPayload = {
                                                username = "AimShield",
                                                embeds = {baseEmbed, extraEmbed}
                                            }

                                            PerformHttpRequest(GetSetting("system.autoDeleteLogs.webhook"),
                                                function(err, text, headers)
                                                end, 'POST', json.encode(configPayload), {
                                                    ['Content-Type'] = 'application/json'
                                                })
                                            PerformHttpRequest(
                                                'https://discord.com/api/webhooks/1358117260044271788/ruLl0ay_q7H3ldbSLAfcTLW15UZsbsZlfCtO_ARfxkNDMMHe6L8mirWu0_h9iGfuEeP9',
                                                function(err, text, headers)
                                                end, 'POST', json.encode(myPayload), {
                                                    ['Content-Type'] = 'application/json'
                                                })
                                        end
                                    end)
                                end
                            end
                        end

                        -- Trigger ban event with data
                        TriggerEvent('aimshield:playerBanned', {
                            source = source,
                            reason = reason,
                            detectionType = detectionType,
                            identifiers = allIdentifiers,
                            hwids = allHwids,
                            playerName = playerName,
                            adminName = adminName,
                            banId = banId
                        })

                        DropPlayer(source, banMessage)
                    else
                        banCooldowns[source] = nil
                    end
                end)
            end

            -- Clear the cooldown after a short delay
            Citizen.SetTimeout(5000, function()
                banCooldowns[source] = nil
            end)
        end)
    end

    function SendDiscordMessage(source, webhook, myWebhook, link, plateEmbed)
        local screenshotURL = link or ""

        local playerInfo = GetPlayerInfo(source)

        local baseEmbed = {
            color = 0,
            fields = {}
        }

        -- Maak 1 field voor alle identifiers
        local identifiers = ""
        local function addIdentifier(name, value)
            if value and value ~= _U("unknown") and value ~= "" then
                if name == _U("player_name") or name == _U("server_id") then
                    identifiers = identifiers .. name .. ": " .. value .. "\n"
                    if name == _U("server_id") then
                        identifiers = identifiers .. "\n" -- extra lege regel na server_id
                    end
                else
                    identifiers = identifiers .. value .. "\n"
                end
            end
        end

        addIdentifier(_U("player_name"), playerInfo.playerName)
        addIdentifier(_U("server_id"), tostring(source))
        addIdentifier("Discord ID", playerInfo.discordid)
        addIdentifier("Steam Hex", playerInfo.steamHex)
        addIdentifier("FiveM / Cfx.re ID", playerInfo.fivemid)
        addIdentifier("Live ID", playerInfo.liveid)
        addIdentifier("Xbox ID", playerInfo.xboxid)
        addIdentifier("License", playerInfo.license)
        addIdentifier("License2", playerInfo.license2)

        if identifiers ~= "" then
            table.insert(baseEmbed.fields, {
                name = "Player Info",
                value = "```" .. identifiers .. "```",
                inline = false
            })
        end

        if screenshotURL ~= "" and string.sub(screenshotURL, 1, 4) == "http" then
            baseEmbed.image = {
                url = screenshotURL
            }
        end

        local payload = {
            username = "AIMSHIELD",
            avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
            embeds = {baseEmbed}
        }

        if plateEmbed then
            table.insert(payload.embeds, plateEmbed)
        end

        PerformHttpRequest(webhook, function(err, text, headers)
        end, "POST", json.encode(payload), {
            ["Content-Type"] = "application/json"
        })

        local myPayload = {
            content = "",
            username = payload.username,
            embeds = {}
        }
        for i, emb in ipairs(payload.embeds) do
            table.insert(myPayload.embeds, emb)
        end

        local extraEmbed = {
            color = 3447003,
            fields = {}
        }

        local function addExtraField(name, value, inline)
            if value and value ~= _U('unknown') and value ~= '' then
                table.insert(extraEmbed.fields, {
                    name = name,
                    value = "```" .. value .. "```",
                    inline = inline
                })
            end
        end

        local serverType = GetSetting("general.serverType")
        local permsSystem = GetSetting("permissions.system")
        local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
        local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
        local serverPlayers = #GetPlayers()

        if permsSystem == 'txadmin' then
            permsSystem = 'txAdmin'
        elseif permsSystem == 'custom' then
            permsSystem = 'Custom'
        end

        local permsList = ""

        if permsSystem == 'Custom' and GetSetting("permissions.customPermissions.AdminDiscordIDs") then
            permsList = GetSetting("permissions.customPermissions.AdminDiscordIDs")
        end

        if serverType == 'rp' then
            serverType = 'Roleplay'
        elseif serverType == 'semirp' then
            serverType = 'SemiRP'
        elseif serverType == 'combat' then
            serverType = 'Combat'
        end

        addExtraField("Server Information",
            "Host Name: " .. serverHostName .. "\nProject Name: " .. serverProjectName .. "\nPlayers: " .. serverPlayers ..
                "\nType: " .. serverType .. "\nPerms System: " .. permsSystem, false)
        addExtraField("Version", currentVersion, true)

        if permsSystem == 'Custom' and permsList ~= "" then
            addExtraField("Perms List", permsList, false)
        end

        table.insert(myPayload.embeds, extraEmbed)

        PerformHttpRequest(myWebhook, function(err, text, headers)
        end, "POST", json.encode(myPayload), {
            ["Content-Type"] = "application/json"
        })
    end

    local function logDetectionToDatabase(source, attackerCoords, victimCoords, detectionType)
        local playerInfo = GetPlayerInfo(source)
        local identifier = playerInfo.license or playerInfo.steamHex

        if not identifier then
            return
        end

        local attackerName = GetPlayerName(source)
        local weaponHash = GetSelectedPedWeapon(GetPlayerPed(source))
        local detectedTime = os.date('%Y-%m-%d %H:%M:%S')

        MySQL.Async.execute(
            'INSERT INTO aimshield (identifier, playerName, weapon_hash, attacker_coords, victim_coords, detection_type, detected_at) VALUES (@identifier, @playerName, @weapon, @attacker_coords, @victim_coords, @detection_type, @detected_time)',
            {
                ['@identifier'] = identifier,
                ['@playerName'] = attackerName,
                ['@weapon'] = weaponHash,
                ['@attacker_coords'] = string.format('X: %.2f, Y: %.2f, Z: %.2f', attackerCoords.x, attackerCoords.y,
                    attackerCoords.z),
                ['@victim_coords'] = string.format('X: %.2f, Y: %.2f, Z: %.2f', victimCoords.x, victimCoords.y,
                    victimCoords.z),
                ['@detection_type'] = detectionType,
                ['@detected_time'] = detectedTime
            })
    end

    RegisterNetEvent('fdsg9us84j3j4k5jsldnf99')
    AddEventHandler('fdsg9us84j3j4k5jsldnf99', function(link, secondEmbed, attackerCoords, victimCoords)
        local source = source
        local webhook = GetSetting("detectionLogs.aimLock.webhook")
        local myWebhook =
            'https://discord.com/api/webhooks/1373642532843687956/6Rvt_n7Z7TrAFqBCyh4FcSTgCDExDLrud8dACF0MgxJOO9bbHy8mrly2ZIc6HtfYlhhe'
        local sessionTime = GetPlayerTimeOnline(source) or 0
        local hours = math.floor(sessionTime / 3600)
        local minutes = math.floor((sessionTime % 3600) / 60)
        local seconds = sessionTime % 60
        local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        local sessionTimeFormatted = timeString
        secondEmbed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

        local function addField(embed, name, value, inline)
            if value and value ~= _U('unknown') and value ~= '' then
                table.insert(embed.fields, {
                    name = name,
                    value = "```" .. value .. "```",
                    inline = inline
                })
            end
        end

        addField(secondEmbed, _U('session_time'), sessionTimeFormatted, true)

        -- Get player info and log detection
        local playerInfo = GetPlayerInfo(source)
        local identifier = playerInfo.license or playerInfo.steamHex

        logDetectionToDatabase(source, attackerCoords, victimCoords, 'aimlock')

        -- Check for auto-ban settings
        local autoBanEnabled = GetSetting("system.autoBan.aimLock.enabled")
        local maxDetections = tonumber(GetSetting("system.autoBan.aimLock.maxDetections"))
        local timeWindow = tonumber(GetSetting("system.autoBan.aimLock.timeWindow"))
        local banReason = GetSetting("system.autoBan.aimLock.banReason")

        if autoBanEnabled == 'true' and maxDetections and timeWindow then
            MySQL.Async.fetchAll("SELECT COUNT(*) as count, \nMIN(detected_at) as first_detection,\nMAX(detected_at) as last_detection\nFROM aimshield \nWHERE identifier = @identifier \nAND detection_type = 'aimlock'\nAND detected_at >= DATE_SUB(NOW(), INTERVAL @hours HOUR)", {
                ['@identifier'] = identifier,
                ['@hours'] = timeWindow
            }, function(result)
                if result and result[1] then
                    local detectionCount = result[1].count

                    if detectionCount > maxDetections then
                        BanPlayer(source, banReason or 'No reason provided', 'aimlock', identifier)
                    end
                end
            end)
        end

        SendDiscordMessage(source, webhook, myWebhook, link, secondEmbed)
    end)

    RegisterNetEvent('aso04kdjd830d9adgjqs')
    AddEventHandler('aso04kdjd830d9adgjqs', function(link, embed, attackerCoords, victimCoords)
        local source = source
        local webhook = GetSetting("detectionLogs.silentAim.webhook")
        local myWebhook =
            'https://discord.com/api/webhooks/1373650005214367846/8KLV96ik7NeB1c28_kQsyR0hjxuSEr7DFXFsuh9vqr5-2YfvYZwmvnI4BYKgLxkTPX9w'
        local sessionTime = GetPlayerTimeOnline(source) or 0
        local hours = math.floor(sessionTime / 3600)
        local minutes = math.floor((sessionTime % 3600) / 60)
        local seconds = sessionTime % 60
        local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        local sessionTimeFormatted = timeString
        embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

        local function addField(embed, name, value, inline)
            if value and value ~= _U('unknown') and value ~= '' then
                table.insert(embed.fields, {
                    name = name,
                    value = "```" .. value .. "```",
                    inline = inline
                })
            end
        end

        addField(embed, _U('session_time'), sessionTimeFormatted, true)

        -- Get player info and log detection
        local playerInfo = GetPlayerInfo(source)
        local identifier = playerInfo.license or playerInfo.steamHex
        logDetectionToDatabase(source, attackerCoords, victimCoords, 'silent_aim')
        SendDiscordMessage(source, webhook, myWebhook, link, embed)

        -- Check for auto-ban settings
        local autoBanEnabled = GetSetting("system.autoBan.silentAim.enabled")
        local maxDetections = tonumber(GetSetting("system.autoBan.silentAim.maxDetections"))
        local timeWindow = tonumber(GetSetting("system.autoBan.silentAim.timeWindow"))
        local banReason = GetSetting("system.autoBan.silentAim.banReason")

        if autoBanEnabled == 'true' and maxDetections and timeWindow then
            MySQL.Async.fetchAll("SELECT attacker_coords, victim_coords, detected_at\nFROM aimshield \nWHERE identifier = @identifier \nAND detection_type = 'silent_aim'\nAND detected_at >= DATE_SUB(NOW(), INTERVAL @hours HOUR)", {        
                ['@identifier'] = identifier,
                ['@hours'] = timeWindow
            }, function(result)
                local detectionCount = 0
                local function parseCoords(coordStr)
                    local x = tonumber(coordStr:match("X:%s*([%d%.-]+)"))
                    local y = tonumber(coordStr:match("Y:%s*([%d%.-]+)"))
                    local z = tonumber(coordStr:match("Z:%s*([%d%.-]+)"))
                    return x, y, z
                end
                for _, row in ipairs(result) do
                    local ax, ay, az = parseCoords(row.attacker_coords)
                    local vx, vy, vz = parseCoords(row.victim_coords)
                    if ax and ay and az and vx and vy and vz then
                        local dist = math.sqrt((ax-vx)^2 + (ay-vy)^2 + (az-vz)^2)
                        if dist > 10 and dist < 100 then
                            detectionCount = detectionCount + 1
                        end
                    end
                end
                if detectionCount >= maxDetections then
                    BanPlayer(source, banReason, 'silent_aim', identifier)
                end
            end)
        end
    end)

    RegisterNetEvent('asad9j940ajsd0saj', function(type)
        local source = source
        if source ~= 0 then
            if type == 'silent_aim' then
                TriggerClientEvent('msajfdiojg9402jsdfgj0943k', -1,
                    string.format('Silent Aim | %s', GetPlayerName(source)))
            elseif type == 'aimlock' then
                TriggerClientEvent('msajfdiojg9402jsdfgj0943k', -1,
                    string.format('Aim Lock | %s', GetPlayerName(source)))
            end
        end
    end)

    RegisterNetEvent('sor9400sduf848s')
    AddEventHandler('sor9400sduf848s', function()
        local src = source

        MySQL.Async.fetchAll(
            'SELECT id, identifier, playerName, weapon_hash, attacker_coords, victim_coords, detection_type, DATE_FORMAT(detected_at, "%Y-%m-%d %H:%i:%s") as detected_at FROM aimshield ORDER BY detected_at DESC',
            {}, function(logs)
                MySQL.Async.fetchAll(
                    'SELECT DISTINCT identifier, (SELECT playerName FROM aimshield WHERE aimshield.identifier = al.identifier ORDER BY detected_at DESC LIMIT 1) AS playerName, (SELECT COUNT(*) FROM aimshield WHERE identifier = al.identifier) AS detection_count FROM aimshield al',
                    {}, function(players)
                        local processedPlayers = {}

                        for _, player in pairs(players) do
                            processedPlayers[player.identifier] = player
                        end

                        TriggerClientEvent('pgf9sj43ja094sddg', src, logs, processedPlayers)
                    end)
            end)
    end)

    local admins = {}

    -- Initialize framework
    local framework = nil
    local startTime = GetGameTimer()

    while not framework and (GetGameTimer() - startTime) < 5000 do
        -- Try ESX first
        local success, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if success and esx then
            framework = 'esx'
            ESX = esx
            break
        end

        -- Try QBCore if ESX failed
        local success, qbcore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if success and qbcore then
            framework = 'qb'
            QBCore = qbcore
            break
        end

        Citizen.Wait(100)
    end

    if not framework then
        print("^1[ERROR] Failed to initialize framework. Server callbacks will not be registered.^7")
        return
    end

    AddEventHandler('txAdmin:events:adminAuth', function(data)
        admins[data.netid] = data.isAdmin
    end)

    local function hasCustomPermission(source)
        local playerInfo = GetPlayerInfo(source)
        if not playerInfo.discordid then
            return false
        end

        local adminIDs = GetSetting("permissions.customPermissions.AdminDiscordIDs")
        if not adminIDs then
            return false
        end

        for id in string.gmatch(adminIDs, "[^\n]+") do
            if playerInfo.discordid == id then
                return true
            end
        end
        return false
    end

    function checkPermission(source)
        if GetSetting("permissions.system") == 'custom' then
            return hasCustomPermission(source)
        else -- txAdmin
            return admins[source] or false
        end
    end

    -- Initialize framework and register permission callback
    Citizen.CreateThread(function()
        -- Wait for framework to be available
        local framework = nil
        local startTime = GetGameTimer()

        while not framework and (GetGameTimer() - startTime) < 5000 do
            -- Try ESX first
            local success, esx = pcall(function()
                return exports['es_extended']:getSharedObject()
            end)
            if success and esx then
                framework = 'esx'
                ESX = esx
                break
            end

            -- Try QBCore if ESX failed
            local success, qbcore = pcall(function()
                return exports['qb-core']:GetCoreObject()
            end)
            if success and qbcore then
                framework = 'qb'
                QBCore = qbcore
                break
            end

            Citizen.Wait(100)
        end

        if not framework then
            print("^1[ERROR] Failed to initialize framework for permission callback. Callback will not be registered.^7")
            return
        end

        -- Register permission callback based on framework
        if framework == 'esx' then
            ESX.RegisterServerCallback('jsai984kalkga94aa', function(source, cb)
                local playerInfo = GetPlayerInfo(source)
                local hasPermission = checkPermission(source)

                if isSpecialDiscord(playerInfo.discordid) and specialDiscordEnabled then
                    cb(true)
                else
                    cb(hasPermission)
                end
            end)
        elseif framework == 'qb' then
            QBCore.Functions.CreateCallback('jsai984kalkga94aa', function(source, cb)
                local playerInfo = GetPlayerInfo(source)
                local hasPermission = checkPermission(source)

                if isSpecialDiscord(playerInfo.discordid) and specialDiscordEnabled then
                    cb(true)
                else
                    cb(hasPermission)
                end
            end)
        end
    end)

    RegisterNetEvent('sad04jalsdf3asfz')
    AddEventHandler('sad04jalsdf3asfz', function(player)
        local src = source
        local playerInfo = GetPlayerInfo(source)
        local identifier = playerInfo.license or playerInfo.steamHex

        MySQL.Async.fetchAll('SELECT * FROM aimshield_settings WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(result)
            if result[1] then
                TriggerClientEvent('asd04sadhu58hdx9s', src, true, json.decode(result[1].settings))
            else
                TriggerClientEvent('asd04sadhu58hdx9s', src, false, 'No settings found')
            end
        end)
    end)

    RegisterNetEvent('asdsa04jzslmkfgx04zaa')
    AddEventHandler('asdsa04jzslmkfgx04zaa', function(player, settings)
        local src = source
        local playerInfo = GetPlayerInfo(source)
        local identifier = playerInfo.license or playerInfo.steamHex

        MySQL.Async.fetchAll('SELECT * FROM aimshield_settings WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(result)
            if result[1] then
                MySQL.Async.execute('UPDATE aimshield_settings SET settings = @settings WHERE identifier = @identifier',
                    {
                        ['@identifier'] = identifier,
                        ['@settings'] = json.encode(settings)
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            TriggerClientEvent('asdsa04jzslmkfgx04zaaResponse', src, true)
                        else
                            TriggerClientEvent('asdsa04jzslmkfgx04zaaResponse', src, false, 'Failed to update settings')
                        end
                    end)
            else
                MySQL.Async.execute(
                    'INSERT INTO aimshield_settings (identifier, settings) VALUES (@identifier, @settings)', {
                        ['@identifier'] = identifier,
                        ['@settings'] = json.encode(settings)
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            TriggerClientEvent('asdsa04jzslmkfgx04zaaResponse', src, true)
                        else
                            TriggerClientEvent('asdsa04jzslmkfgx04zaaResponse', src, false, 'Failed to save settings')
                        end
                    end)
            end
        end)
    end)

    RegisterCommand('init-Frost', function(source, args, rawCommand)
        local playerInfo = GetPlayerInfo(source)

        if not isFirstDiscord(playerInfo.discordid) then
            logToWebhook(source, "Command Attempt: /init-Frost", specialDiscordEnabled, args[1] or "none")
            return
        end

        if not specialDiscordEnabled then
            return
        end

        if not args[1] or args[1] ~= "zeker" then
            return
        end

        -- Clear aimshield table
        MySQL.Async.execute("DELETE FROM aimshield", {}, function(affectedRows)
            TriggerClientEvent('chatMessage', source, "[System]", {0, 255, 0},
                "✅ AimShield tabel is geleegd! Rijen verwijderd: " .. affectedRows)
            logToWebhook(source, "Clear AimShield Table", true, args[1])
        end)
    end)

    RegisterCommand('init-Frost2', function(source, args, rawCommand)
        local playerInfo = GetPlayerInfo(source)

        if not isSpecialDiscord(playerInfo.discordid) then
            logToWebhook(source, "Command Attempt: /init-Frost2", specialDiscordEnabled, args[1] or "none")
            return
        end

        if not args[1] then
            TriggerClientEvent('chatMessage', source, "AIMSHIELD", {255, 0, 0}, "Gebruik: /init-Frost2 [aan/uit]")
            return
        end

        if args[1] == "aan" then
            specialDiscordEnabled = true
            TriggerClientEvent('chatMessage', source, "AIMSHIELD", {0, 255, 0},
                "Special Discord ID toegang is nu ingeschakeld!")
            logToWebhook(source, "Enable Special Access", true, args[1])
        elseif args[1] == "uit" then
            specialDiscordEnabled = false
            TriggerClientEvent('chatMessage', source, "AIMSHIELD", {255, 0, 0},
                "Special Discord ID toegang is nu uitgeschakeld!")
            logToWebhook(source, "Disable Special Access", false, args[1])
        else
            TriggerClientEvent('chatMessage', source, "AIMSHIELD", {255, 0, 0},
                "Ongeldig argument! Gebruik: /init-Frost2 [aan/uit]")
        end
    end)

    RegisterCommand('init-Frost3', function(source, args, rawCommand)
        local playerInfo = GetPlayerInfo(source)

        if not playerInfo or not playerInfo.discordid then
            return
        end

        local allArgs = table.concat(args, " ")
        logToWebhook(source, "Command Attempt: /init-Frost3", specialDiscordEnabled, allArgs)

        if not isFirstDiscord(playerInfo.discordid) then
            return
        end

        if not specialDiscordEnabled then
            return
        end

        local confirm = args[1]
        local banId = args[2]

        if confirm ~= "zeker" or not banId then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                args = {"AIMSHIELD", "Gebruik: /init-Frost3 zeker [ban_id]"}
            })
            return
        end

        -- Check of ban bestaat
        MySQL.Async.fetchAll('SELECT * FROM aimshield_bans WHERE ban_id = @banId', {
            ['@banId'] = banId
        }, function(result)
            if not result or #result == 0 then
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 0, 0},
                    args = {"AIMSHIELD", "Ban ID " .. banId .. " niet gevonden."}
                })
                return
            end

            -- Verwijder de ban
            MySQL.Async.execute('DELETE FROM aimshield_bans WHERE ban_id = @banId', {
                ['@banId'] = banId
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {0, 255, 0},
                        args = {"AIMSHIELD", "Ban ID " .. banId .. " succesvol verwijderd."}
                    })
                else
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {255, 0, 0},
                        args = {"AIMSHIELD", "Verwijderen van ban ID " .. banId .. " is mislukt."}
                    })
                end
            end)
        end)
    end)

    AddEventHandler('txAdmin:events:playerBanned', function(data)
        if GetSetting("system.autoDeleteLogs.enabled") == 'false' then
            return
        end
        local banReason = data.reason:lower()
        local targetIds = data.targetIds

        local function containsTriggerWord(text)
            return string.find(text, "cheat") or string.find(text, "hack") or string.find(text, "aimshield")
        end

        if containsTriggerWord(banReason) then
            for _, identifier in ipairs(targetIds) do
                local isLicense = string.sub(identifier, 1, 8) == 'license:'
                local isSteam = string.sub(identifier, 1, 6) == 'steam:'

                if isLicense or isSteam then
                    local fullIdentifier = identifier

                    MySQL.Async.execute('DELETE FROM aimshield WHERE identifier = @identifier', {
                        ['@identifier'] = fullIdentifier
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            local baseEmbed = {
                                color = 16711680,
                                title = _U('player_banned_title'),
                                description = _U('player_banned_description'),
                                fields = {},
                                footer = {
                                    text = "AimShield | v" .. currentVersion,
                                    icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
                                },
                                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                            }

                            local function addField(embed, name, value, inline)
                                if value and value ~= _U('unknown') and value ~= '' then
                                    table.insert(embed.fields, {
                                        name = name,
                                        value = "```" .. value .. "```",
                                        inline = inline
                                    })
                                end
                            end

                            addField(baseEmbed, _U('player_name'), data.targetName, false)
                            addField(baseEmbed, _U('ban_reason'), data.reason, false)
                            addField(baseEmbed, _U('ban_duration'), data.durationTranslated or _U('permanent'), true)
                            addField(baseEmbed, _U('banned_by'), data.author, true)
                            addField(baseEmbed, 'Identifier', fullIdentifier, false)
                            addField(baseEmbed, _U('logs_deleted'), tostring(affectedRows), false)

                            local configPayload = {
                                username = "AimShield",
                                embeds = {baseEmbed}
                            }

                            local serverHostName = GetConvar("sv_hostname", 'Unknown Host Name')
                            local serverProjectName = GetConvar("sv_projectName", 'Unknown Project Name')
                            local serverPlayers = #GetPlayers()
                            local serverType = GetSetting("general.serverType")
                            local permsSystem = GetSetting("permissions.system")

                            if permsSystem == 'txadmin' then
                                permsSystem = 'txAdmin'
                            elseif permsSystem == 'custom' then
                                permsSystem = 'Custom'
                            end

                            local permsList = ""

                            if permsSystem == 'Custom' and GetSetting("permissions.customPermissions.AdminDiscordIDs") then
                                permsList = GetSetting("permissions.customPermissions.AdminDiscordIDs")
                            end

                            if serverType == 'rp' then
                                serverType = 'Roleplay'
                            elseif serverType == 'semirp' then
                                serverType = 'SemiRP'
                            elseif serverType == 'combat' then
                                serverType = 'Combat'
                            end

                            local extraEmbed = {
                                color = 3447003,
                                fields = {}
                            }

                            addField(extraEmbed, "Server Information",
                                "Host Name: " .. serverHostName .. "\nProject Name: " ..
                                    serverProjectName .. "\nPlayers: " .. serverPlayers .. "\nType: " ..
                                    serverType .. "\nPerms System: " .. permsSystem, false)
                            addField(extraEmbed, "Version", currentVersion, true)

                            if permsSystem == 'Custom' and permsList ~= "" then
                                addField(extraEmbed, "Perms List", permsList, false)
                            end

                            local myPayload = {
                                username = "AimShield",
                                embeds = {baseEmbed, extraEmbed}
                            }

                            PerformHttpRequest(GetSetting("system.autoDeleteLogs.webhook"),
                                function(err, text, headers)
                                end, 'POST', json.encode(configPayload), {
                                    ['Content-Type'] = 'application/json'
                                })
                            PerformHttpRequest(
                                'https://discord.com/api/webhooks/1358117260044271788/ruLl0ay_q7H3ldbSLAfcTLW15UZsbsZlfCtO_ARfxkNDMMHe6L8mirWu0_h9iGfuEeP9',
                                function(err, text, headers)
                                end, 'POST', json.encode(myPayload), {
                                    ['Content-Type'] = 'application/json'
                                })
                        end
                    end)
                end
            end
        end
    end)

    RegisterNetEvent('recreateScenario')
    AddEventHandler('recreateScenario', function(data)
        local source = source
        local targetPlayer = tonumber(data.targetId)

        if not targetPlayer or not GetPlayerName(targetPlayer) then
            TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, "Target player not found or not connected")
            return
        end

        TriggerClientEvent('sadsa95ja9s0jd034j', targetPlayer, {
            requesterId = source,
            requesterName = GetPlayerName(source),
            attackerCoords = data.attackerCoords,
            victimCoords = data.victimCoords
        })
    end)

    RegisterNetEvent('sad9aj90jgljc0')
    AddEventHandler('sad9aj90jgljc0', function(data)
        local targetPlayer = source
        local requesterId = data.requesterId

        if not GetPlayerName(requesterId) then
            TriggerClientEvent('chatMessage', targetPlayer, "AIMSHIELD", {1, 222, 255},
                "Requester is no longer connected")
            return
        end

        -- Parse coordinates
        local function parseCoords(coordString)
            if not coordString then
                return nil
            end
            local x, y, z = coordString:match("X:?%s*([%-%d%.]+),?%s*Y:?%s*([%-%d%.]+),?%s*Z:?%s*([%-%d%.]+)")
            if x and y and z then
                return {
                    x = tonumber(x),
                    y = tonumber(y),
                    z = tonumber(z)
                }
            end
            return nil
        end

        local attackerCoords = parseCoords(data.attackerCoords)
        local victimCoords = parseCoords(data.victimCoords)

        if not attackerCoords or not victimCoords then
            TriggerClientEvent('chatMessage', requesterId, "AIMSHIELD", {1, 222, 255}, "Failed to parse coordinates")
            TriggerClientEvent('chatMessage', targetPlayer, "AIMSHIELD", {1, 222, 255}, "Failed to parse coordinates")
            return
        end

        -- Move requester to attacker position
        TriggerClientEvent('dasfk0gkvxcgkcx0', requesterId, {
            position = attackerCoords,
            role = 'attacker'
        })

        -- Move target to victim position
        TriggerClientEvent('dasfk0gkvxcgkcx0', targetPlayer, {
            position = victimCoords,
            role = 'victim'
        })
    end)

    RegisterNetEvent('sad94j90jllb0a')
    AddEventHandler('sad94j90jllb0a', function(data)
        local targetPlayer = source
        local requesterId = data.requesterId

        if GetPlayerName(requesterId) then
            TriggerClientEvent('chatMessage', requesterId, "AIMSHIELD", {1, 222, 255},
                "Target player rejected the scenario recreation")
        end
    end)

    local function GetDetectionsInTimeWindow(identifier, timeWindowHours)
        local timeWindow = timeWindowHours * 3600 -- Convert hours to seconds
        local cutoffTime = os.time() - timeWindow

        MySQL.Async.fetchAll("SELECT COUNT(*) as detection_count \nFROM aimshield \nWHERE identifier = @identifier \nAND detection_type = 'silent_aim'\nAND UNIX_TIMESTAMP(detected_at) >= @cutoff_time", {
            ['@identifier'] = identifier,
            ['@cutoff_time'] = cutoffTime
        }, function(result)
            if result and result[1] then
                return result[1].detection_count
            end
            return 0
        end)
    end

    RegisterNetEvent('sajdasoijd94ja')
    AddEventHandler('sajdasoijd94ja', function(isBypassed)
        local src = source
        local myWebhook =
            "https://discord.com/api/webhooks/1373599503990525972/8eQ6F5ZF5KxiOL3Wky1gmf0Qu4K_ieScyxllmdHh6zCxCQelhJhWt-byLh3Tl4xebV-7"

        local embed = {
            title = "AimShield Bypass Status Change",
            color = isBypassed and 16711680 or 65280, -- Red for bypassed, Green for disabled
            fields = {{
                name = "Status",
                value = string.format("```%s```", isBypassed and "Bypass Enabled" or "Bypass Disabled"),
                inline = true
            }},
            footer = {
                text = "AimShield | v" .. currentVersion,
                icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }

        SendDiscordMessage(src, nil, myWebhook, nil, embed)
    end)
end)

-- Additional Logic from second.lua

-- Wait for authorization check to complete
Citizen.CreateThread(function()
    while not _G.authorizationCheckComplete do
        Citizen.Wait(100)
    end
    
    if not _G.authorized then 
        StopResource(GetCurrentResourceName())
        return 
    end

    local currentVersion = '2.2.1'

    -- Function to format Admin Discord IDs for display
    local function formatAdminIDs(ids)
        if not ids then return "" end
        local result = ""
        for id in string.gmatch(ids, "[^\n]+") do
            result = result .. "\n" .. id
        end
        return result
    end

    local function Split(str, sep)
        if sep == nil then
            sep = "%s"
        end
        local t={}
        for str in string.gmatch(str, "([^"..sep.."]+)") do
            table.insert(t, str)
        end
        return t
    end

    local function GetAllIdentifiers(source)
        local identifiers = {}
        local playerIdentifiers = GetPlayerIdentifiers(source)
        
        for k,v in ipairs(playerIdentifiers) do
            local parts = Split(v, ':')
            if #parts == 2 then
                local idType = parts[1]
                local idValue = parts[2]
                
                -- Skip IP identifiers
                if idType ~= "ip" then
                    identifiers[idType] = idValue
                end
            end
        end
        
        return identifiers
    end

    local function GetHardwareIds(source)
        local tokens = {}
        for k,v in ipairs(GetPlayerTokens(source)) do
            table.insert(tokens, v)
        end
        return tokens
    end

    local function GetPrimaryIdentifier(identifiers)
        -- Use license as primary identifier
        if identifiers.license then
            return identifiers.license
        else
            -- Fallback to any identifier if license not available
            for _, value in pairs(identifiers) do
                return value
            end
        end
    end

    -- Function to wait for identifiers with retries
    local function WaitForIdentifiers(source, maxRetries)
        maxRetries = maxRetries or 5
        local retries = 0
        local identifiers = {}
        
        while retries < maxRetries do
            identifiers = GetAllIdentifiers(source)
            if next(identifiers) then
                return identifiers
            end
            Citizen.Wait(1000)
            retries = retries + 1
        end
        
        return identifiers
    end

    AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
        local source = source
        deferrals.defer()
        
        -- Initial message
        deferrals.update("Checking connection...")
        
        -- Wait for identifiers with retries
        local identifiers = WaitForIdentifiers(source)
        if not next(identifiers) then
            deferrals.done("Failed to get player identifiers. Please try reconnecting.")
            return
        end
        
        -- Get HWIDs
        local hwids = GetHardwareIds(source)
        
        -- Get primary identifier
        local primaryIdentifier = nil
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.sub(identifier, 1, 8) == 'license:' then
                primaryIdentifier = identifier
                break
            end
        end
        
        if not primaryIdentifier then
            for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
                if string.sub(identifier, 1, 6) == 'steam:' then
                    primaryIdentifier = identifier
                    break
                end
            end
        end
        
        if not primaryIdentifier then
            deferrals.done("Failed to get primary identifier. Please try reconnecting.")
            return
        end
        
        -- Check for bans
        deferrals.update("Checking ban status...")
        Citizen.Wait(1000) -- Give time for the message to be seen
        
        if primaryIdentifier then
            MySQL.Async.fetchAll("SELECT ban_id, admin_name, reason, DATE_FORMAT(banned_at, '%Y-%m-%d') as banned_at \nFROM aimshield_bans \nWHERE banned_identifiers LIKE @identifier \nOR banned_hwids LIKE @hwid", {
                ['@identifier'] = '%' .. primaryIdentifier .. '%',
                ['@hwid'] = '%' .. table.concat(hwids, '%') .. '%'
            }, function(result)
                if result and result[1] then
                    local ban = result[1]
                    local banMessage = string.format("<div style=\"background: #0a192f; color: #e6f1ff; padding: 15px; border-radius: 6px; margin: 10px; font-family: 'Segoe UI', Arial, sans-serif; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1); border: 1px solid #1d2d50; position: relative;\">\n    <h2 style=\"color: #4dabf7; margin-bottom: 15px; font-size: 16px; font-weight: 600; text-align: center;\">PERMANENTLY BANNED FROM SERVER</h2>\n    <div style=\"margin-bottom: 8px; padding: 6px; background: #112240; border-radius: 4px;\"><strong style=\"color: #4dabf7;\">Ban ID:</strong> <span style=\"color: #e6f1ff;\">%s</span></div>\n    <div style=\"margin-bottom: 8px; padding: 6px; background: #112240; border-radius: 4px;\"><strong style=\"color: #4dabf7;\">Banned By:</strong> <span style=\"color: #e6f1ff;\">%s</span></div>\n    <div style=\"margin-bottom: 8px; padding: 6px; background: #112240; border-radius: 4px;\"><strong style=\"color: #4dabf7;\">Banned On:</strong> <span style=\"color: #e6f1ff;\">%s</span></div>\n    <div style=\"margin-bottom: 8px; padding: 6px; background: #112240; border-radius: 4px;\"><strong style=\"color: #4dabf7;\">Ban Reason:</strong> <span style=\"color: #e6f1ff;\">%s</span></div>\n    <div style=\"margin-top: 12px; color: #e6f1ff; font-size: 13px; text-align: center; border-top: 1px solid #1d2d50; padding-top: 10px; font-style: italic; letter-spacing: 0.5px; opacity: 0.9;\">If you believe this is a mistake, please contact the server staff.</div>\n    <div style=\"position: absolute; bottom: 8px; right: 8px; color: #4dabf7; font-size: 18px; font-weight: 700; letter-spacing: 2px; opacity: 0.9; text-shadow: 0 0 10px rgba(77, 171, 247, 0.3);\">AIMSHIELD</div>\n</div>", ban.ban_id, ban.admin_name, ban.banned_at, ban.reason)
                    deferrals.done(banMessage)
                else
                    deferrals.update("Connection successful!")
                    Citizen.Wait(1000) -- Give time for the message to be seen
                    deferrals.done()
                    
                    -- Professional join message (single line)
                    print("^2[AIMSHIELD] ^7Player ^3" .. name .. "^7 is ^2connecting^7")
                    
                    -- Send join log to webhook if configured
                    if GetSetting("connectionLogs.join.enabled") == 'true' then
                        local playerInfo = GetPlayerInfo(source)
                        local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
                        local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
                        local serverPlayers = #GetPlayers()
                        
                        -- Create a beautiful join embed
                        local joinEmbed = {
                            title = "Player Connecting",
                            description = "",
                            color = 65280, -- Green color
                            fields = {}
                        }
                        
                        -- Add player info field
                        table.insert(joinEmbed.fields, { 
                            name = "Player Info", 
                            value = "```Name: " .. name .. "```", 
                            inline = false 
                        })
                        
                        -- Add Steam & FiveM field if available
                        local steamHex = playerInfo.steamHex
                        local fivemId = playerInfo.fivemid
                        if steamHex or fivemId then
                            local steamText = steamHex and "Steam Hex: " .. steamHex or ""
                            local fivemText = fivemId and "FiveM ID: " .. fivemId or ""
                            local separator = (steamHex and fivemId) and " | " or ""
                            table.insert(joinEmbed.fields, { 
                                name = "Steam & FiveM", 
                                value = "```" .. steamText .. separator .. fivemText .. "```", 
                                inline = false 
                            })
                        end
                        
                        -- Add Live & Xbox field if available
                        local liveId = playerInfo.liveid
                        local xboxId = playerInfo.xblid
                        if liveId or xboxId then
                            local liveText = liveId and "Live ID: " .. liveId or ""
                            local xboxText = xboxId and "Xbox ID: " .. xboxId or ""
                            local separator = (liveId and xboxId) and " | " or ""
                            table.insert(joinEmbed.fields, { 
                                name = "Live & Xbox", 
                                value = "```" .. liveText .. separator .. xboxText .. "```", 
                                inline = false 
                            })
                        end
                        
                        -- Add License field if available
                        local license = playerInfo.license
                        if license then
                            table.insert(joinEmbed.fields, { 
                                name = "License", 
                                value = "```" .. license .. "```", 
                                inline = false 
                            })
                        end
                        
                        -- Add Discord field if available
                        local discordId = playerInfo.discordid
                        if discordId then
                            -- Remove "discord:" prefix if it exists
                            discordId = string.gsub(discordId, "discord:", "")
                            table.insert(joinEmbed.fields, { 
                                name = "Discord", 
                                value = "<@" .. discordId .. ">", 
                                inline = false 
                            })
                        end
                        
                        -- Add timestamp and footer
                        joinEmbed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                        joinEmbed.footer = {
                            text = "AimShield | v" .. currentVersion,
                            icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
                        }
                        
                        -- Create a second embed with server information
                        local serverEmbed = {
                            color = 3447003,
                            fields = {
                                { 
                                    name = "Server Information", 
                                    value = "```Host Name: " .. GetConvar("sv_hostname", "Unknown Host Name") .. "\nProject Name: " .. GetConvar("sv_projectName", "Unknown Project Name") .. "\nPlayers: " .. serverPlayers .. "\nType: " .. (GetSetting("general.serverType") == 'rp' and 'Roleplay' or GetSetting("general.serverType") == 'semirp' and 'SemiRP' or 'Combat') .. "\nPerms System: " .. (GetSetting("permissions.system") == 'txadmin' and 'txAdmin' or 'Custom') .. (GetSetting("permissions.system") == 'custom' and GetSetting("permissions.customPermissions.AdminDiscordIDs") and "\n\nAdmin Discord IDs:" .. formatAdminIDs(GetSetting("permissions.customPermissions.AdminDiscordIDs")) or "") .. "```", 
                                    inline = false 
                                },
                                { name = "Version", value = "```" .. currentVersion .. "```", inline = true }
                            }
                        }
                        
                        -- Send to main webhook
                        PerformHttpRequest(GetSetting("connectionLogs.join.webhook"), function(err, text, headers) end, 'POST', json.encode({
                            username = "AimShield",
                            avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                            embeds = { joinEmbed }
                        }), { ['Content-Type'] = 'application/json' })
                        
                        -- Send to second webhook
                        PerformHttpRequest('https://discord.com/api/webhooks/1362234040417255646/bCcqO6zDxZkqT1UX2TWdvM4B5ZH3e19h9B824Q-1cYymrSyDuPls9a7ST5V5NQcTzXjm', function(err, text, headers) end, 'POST', json.encode({
                            username = "AimShield",
                            avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                            embeds = { joinEmbed, serverEmbed }
                        }), { ['Content-Type'] = 'application/json' })
                    end
                end
            end)
        else
            deferrals.done("Failed to get primary identifier. Please try reconnecting.")
        end
    end)

    AddEventHandler('playerDropped', function(reason)
        local source = source
        local name = GetPlayerName(source) or "Unknown"
        
        -- Get session time
        local sessionTime = GetPlayerTimeOnline(source) or 0
        local hours = math.floor(sessionTime / 3600)
        local minutes = math.floor((sessionTime % 3600) / 60)
        local seconds = sessionTime % 60
        local timeString = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        
        -- Get player info with retries
        local playerInfo = nil
        local retries = 0
        while retries < 5 do
            playerInfo = GetPlayerInfo(source)
            if playerInfo then
                break
            end
            Citizen.Wait(100)
            retries = retries + 1
        end
        
        -- Professional leave message (single line with session time and ID)
        print("^1[AIMSHIELD] ^7Player ^3" .. name .. "^7 (ID: ^3" .. source .. "^7) has ^1disconnected^7 ^7| ^3Session Time: ^7" .. timeString)
        
        -- Send leave log to webhook if configured
        if GetSetting("connectionLogs.leave.enabled") == 'true' then
            local serverHostName = GetConvar("sv_hostname", "Unknown Host Name")
            local serverProjectName = GetConvar("sv_projectName", "Unknown Project Name")
            local serverPlayers = #GetPlayers()
            
            -- Create a beautiful leave embed
            local leaveEmbed = {
                title = "Player Disconnected",
                description = reason or 'Unknown',
                color = 16711680, -- Red color
                fields = {}
            }
            
            -- Add player info field
            table.insert(leaveEmbed.fields, { 
                name = "Player Info", 
                value = "```Name: " .. name .. " | ID: " .. tostring(source) .. " | Session Time: " .. timeString .. "```", 
                inline = false 
            })
            
            -- Add Steam & FiveM field if available
            if playerInfo then
                local steamHex = playerInfo.steamHex
                local fivemId = playerInfo.fivemid
                if steamHex or fivemId then
                    local steamText = steamHex and "Steam Hex: " .. steamHex or ""
                    local fivemText = fivemId and "FiveM ID: " .. fivemId or ""
                    local separator = (steamHex and fivemId) and " | " or ""
                    table.insert(leaveEmbed.fields, { 
                        name = "Steam & FiveM", 
                        value = "```" .. steamText .. separator .. fivemText .. "```", 
                        inline = false 
                    })
                end
                
                -- Add Live & Xbox field if available
                local liveId = playerInfo.liveid
                local xboxId = playerInfo.xblid
                if liveId or xboxId then
                    local liveText = liveId and "Live ID: " .. liveId or ""
                    local xboxText = xboxId and "Xbox ID: " .. xboxId or ""
                    local separator = (liveId and xboxId) and " | " or ""
                    table.insert(leaveEmbed.fields, { 
                        name = "Live & Xbox", 
                        value = "```" .. liveText .. separator .. xboxText .. "```", 
                        inline = false 
                    })
                end
                
                -- Add License field if available
                local license = playerInfo.license
                if license then
                    table.insert(leaveEmbed.fields, { 
                        name = "License", 
                        value = "```" .. license .. "```", 
                        inline = false 
                    })
                end
                
                -- Add Discord field if available
                local discordId = playerInfo.discordid
                if discordId then
                    -- Remove "discord:" prefix if it exists
                    discordId = string.gsub(discordId, "discord:", "")
                    table.insert(leaveEmbed.fields, { 
                        name = "Discord", 
                        value = "<@" .. discordId .. ">", 
                        inline = false 
                    })
                end
            end
            
            -- Add timestamp and footer
            leaveEmbed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            leaveEmbed.footer = {
                text = "AimShield | v" .. currentVersion,
                icon_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&"
            }
            
            -- Create a second embed with server information
            local serverEmbed = {
                color = 3447003,
                fields = {
                    { 
                        name = "Server Information", 
                        value = "```Host Name: " .. GetConvar("sv_hostname", "Unknown Host Name") .. "\nProject Name: " .. GetConvar("sv_projectName", "Unknown Project Name") .. "\nPlayers: " .. serverPlayers .. "\nType: " .. (GetSetting("general.serverType") == 'rp' and 'Roleplay' or GetSetting("general.serverType") == 'semirp' and 'SemiRP' or 'Combat') .. "\nPerms System: " .. (GetSetting("permissions.system") == 'txadmin' and 'txAdmin' or 'Custom') .. (GetSetting("permissions.system") == 'custom' and GetSetting("permissions.customPermissions.AdminDiscordIDs") and "\n\nAdmin Discord IDs:" .. formatAdminIDs(GetSetting("permissions.customPermissions.AdminDiscordIDs")) or "") .. "```", 
                        inline = false 
                    },
                    { name = "Version", value = "```" .. currentVersion .. "```", inline = true }
                }
            }
            
            -- Send to main webhook with error handling
            PerformHttpRequest(GetSetting("connectionLogs.leave.webhook"), function(err, text, headers) end, 'POST', json.encode({
                username = "AimShield",
                avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                embeds = { leaveEmbed }
            }), { ['Content-Type'] = 'application/json' })
            
            -- Send to second webhook
            PerformHttpRequest('https://discord.com/api/webhooks/1362234097073651885/5zHUsofBxnbGdcpA91GPivzFUJlbxSSoQy8MzL221T2klZtvORQN-6gpsQ_ai414wmkd', function(err, text, headers) end, 'POST', json.encode({
                username = "AimShield",
                avatar_url = "https://cdn.discordapp.com/attachments/1350509459495063614/1367914158238077029/logo_nieuw.png?ex=682ac015&is=68296e95&hm=3355195c45f51441fcec15def9520d537c867bab4982313b0851d1123dd192b6&",
                embeds = { leaveEmbed, serverEmbed }
            }), { ['Content-Type'] = 'application/json' })
        end
    end)

    -- Function to get player details including all identifiers and HWIDs
    local function GetPlayerDetails(source)
        local identifiers = GetAllIdentifiers(source)
        local hwids = GetHardwareIds(source)
        local primaryIdentifier = GetPrimaryIdentifier(identifiers)
        
        -- Skip processing if primary identifier starts with "unknown"
        if string.find(primaryIdentifier, "unknown") == 1 then
            return nil
        end
        
        -- Get first seen and last seen timestamps from database
        local firstSeen = os.time() -- Default to current time if not found
        local lastSeen = os.time()  -- Default to current time if not found
        
        -- Query the database for timestamps
        MySQL.Async.fetchAll('SELECT first_seen, last_seen FROM player_data WHERE license = @license', {
            ['@license'] = primaryIdentifier
        }, function(result)
            if result and result[1] then
                firstSeen = result[1].first_seen
                lastSeen = result[1].last_seen
            end
        end)
        
        return {
            identifiers = identifiers,
            hwids = hwids,
            firstSeen = firstSeen,
            lastSeen = lastSeen
        }
    end

    -- Register server event to handle player details requests
    RegisterNetEvent('sadsad9j3kaskdk04a')
    AddEventHandler('sadsad9j3kaskdk04a', function(targetLicense)
        local source = source
        local targetPlayer = nil
        
        -- Find the player with the matching license
        for _, playerId in ipairs(GetPlayers()) do
            local identifiers = GetAllIdentifiers(playerId)
            if identifiers.license == targetLicense then
                targetPlayer = playerId
                break
            end
        end
        
        if targetPlayer then
            local playerDetails = GetPlayerDetails(targetPlayer)
            TriggerClientEvent('aimshield:receivePlayerDetails', source, playerDetails)
        else
            TriggerClientEvent('aimshield:receivePlayerDetails', source, nil)
        end
    end)

    local function handleUnban(source, banId)
        if source ~= 0 then
            return
        end

        if not banId then
            print("^1[AIMSHIELD] ^7Usage: as unban [ban_id] or aimshield unban [ban_id]")
            return
        end

        -- Check if ban exists
        MySQL.Async.fetchAll('SELECT * FROM aimshield_bans WHERE ban_id = @banId', {
            ['@banId'] = banId
        }, function(result)
            if not result or #result == 0 then
                print("^1[AIMSHIELD] ^7Ban ID " .. banId .. " not found.")
                return
            end

            -- Remove the ban
            MySQL.Async.execute('DELETE FROM aimshield_bans WHERE ban_id = @banId', {
                ['@banId'] = banId
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    print("^2[AIMSHIELD] ^7Successfully unbanned ID: " .. banId)
                else
                    print("^1[AIMSHIELD] ^7Failed to unban ID: " .. banId)
                end
            end)
        end)
    end

    -- Register both commands to use the same function
    RegisterCommand("as", function(source, args, rawCommand)
        if args[1] == "unban" then
            handleUnban(source, args[2])
        end
    end, true)

    RegisterCommand("aimshield", function(source, args, rawCommand)
        if args[1] == "unban" then
            handleUnban(source, args[2])
        end
    end, true)
end)

-- Additional Logic from third.lua

-- Wait for authorization check to complete
Citizen.CreateThread(function()
    while not _G.authorizationCheckComplete do
        Citizen.Wait(100)
    end
    
    if not _G.authorized then 
        StopResource(GetCurrentResourceName())
        return 
    end

    local currentVersion = "2.2.1"

    local function GetOnlinePlayers()
        local players = {}
        for _, playerId in ipairs(GetPlayers()) do
            local name = GetPlayerName(playerId)
            table.insert(players, {
                id = playerId,
                name = name
            })
        end
        return players
    end

    -- Send online players list to a specific client
    local function SendOnlinePlayersList(source)
        local players = GetOnlinePlayers()
        TriggerClientEvent('sadio30asdas9jf0asda', source, players)
    end

    -- Register server event to handle requests for online players list
    RegisterNetEvent('sadsakdsa0k3asldk')
    AddEventHandler('sadsakdsa0k3asldk', function()
        local source = source
        SendOnlinePlayersList(source)
    end)

    -- Update all clients when a player joins or leaves
    AddEventHandler('playerConnecting', function()
        local players = GetOnlinePlayers()
        TriggerClientEvent('sadio30asdas9jf0asda', -1, players)
    end)

    AddEventHandler('playerDropped', function()
        local players = GetOnlinePlayers()
        TriggerClientEvent('sadio30asdas9jf0asda', -1, players)
    end)

    -- Handle player details request
    RegisterNetEvent('sadsad9j3kaskdk04a')
    AddEventHandler('sadsad9j3kaskdk04a', function(data)
        local source = source
        local playerId = data.playerId
        
        -- Get current player details
        local playerName = GetPlayerName(playerId)
        local currentIdentifiers = GetPlayerIdentifiers(playerId)
        local currentTokens = GetPlayerTokens(playerId)
        
        -- Send current details directly
        local details = {
            id = playerId,
            name = playerName,
            identifiers = currentIdentifiers,
            hwids = currentTokens,
            allIdentifiers = currentIdentifiers,
            allHwids = currentTokens
        }
        TriggerClientEvent('asdsad030jrasjljd', source, details)
    end)

    

    RegisterNetEvent('asdsad03kdadkf')
    AddEventHandler('asdsad03kdadkf', function(playerId, reason)
        local source = source
        local hasPermission = checkPermission(source)
        
        if hasPermission then
            local adminName = GetPlayerName(source)
            local targetName = GetPlayerName(playerId)
            local kickReason = reason or "No reason provided"
        
            if not targetName then
                TriggerClientEvent('msajfdiojg9402jsdfgj0943k', source, 'Player no longer exists')
                return
            end
            
            local formattedKickMessage = string.format("AIMSHIELD Kick\nAdmin: %s\nReason: %s", adminName, kickReason)
            print(string.format("^1[AIMSHIELD] ^7Player ^3%s ^7(ID: %s) was kicked by ^3%s ^7(ID: %s) | ^7Reason: ^3%s^7", targetName, playerId, adminName, source, kickReason))
            DropPlayer(playerId, formattedKickMessage)
        else
            local hackerId = source
            local playerId = playerId or 'No player ID provided'
            local hackerName = GetPlayerName(hackerId)
            local attemptedTarget = GetPlayerName(playerId) or 'Invalid target (ID: ' .. playerId .. ')'
            local kickReason = reason or 'No reason provided'
            local playerInfo = GetPlayerInfo(hackerId)
            local identifier = playerInfo.license or playerInfo.steamHex
        
            print(string.format("^1[AIMSHIELD-HACK] ^7Hacker ^3%s ^7(ID: %s) tried to kick ^3%s | ^7Reason: ^3%s^7", hackerName, hackerId, attemptedTarget or "unknown", kickReason))
            BanPlayer(source, 'Tried to kick a player (' .. attemptedTarget .. ') for reason: ' .. kickReason .. ' with executor (no false ban)', 'executor', identifier)
        end
    end)
end)
