--------------------------------------------------------------------------------
-- Bootloader entrypoint
--------------------------------------------------------------------------------
function onThisResourceStart()
    prepareBootloaderSettings()
    startBootloaderResources()
    setTimer(keepAliveTimerCallback, 10 * 60000, 0)
end
addEventHandler("onResourceStart", resourceRoot, onThisResourceStart, false)

function startBootloaderResources()
    local resourceList = getBootloaderResources()

    for i = 1, #resourceList do
        local resource = resourceList[i]

        if getResourceState(resource) == "loaded" then
            startResource(resource, true)
        end
    end
end

function keepAliveTimerCallback()
    local keepAlive = getBool("keepAlive", true)

    if keepAlive then
        startBootloaderResources()
    end
end

--------------------------------------------------------------------------------
-- Settings management
--------------------------------------------------------------------------------
local settingsResourceDict = {}

function prepareBootloaderSettings()
    local resourceNameList = getBootloaderResourcesSetting()

    for i = 1, #resourceNameList do
        local resourceName = resourceNameList[i]
        settingsResourceDict[resourceName] = true
    end
end

function getBootloaderResourceNamesDict()
    return settingsResourceDict
end

function isBootloaderResource(resourceName)
    return settingsResourceDict[resourceName] ~= nil
end

function getBootloaderResources()
    local result = {}
    local length = 0

    for resourceName in pairs(settingsResourceDict) do
        local resource = getResourceFromName(resourceName)

        if resource then
            length = length + 1
            result[length] = resource
        end
    end

    return result
end

function getBootloaderResourcesSetting()
    local result = {}
    local length = 0
    local resourceNameList = get("@resources") or ""
    
    for index, resourceName in pairs(split(resourceNameList, ",")) do
        resourceName = utf8.trim(resourceName)
        
        if resourceName ~= "" then
            length = length + 1
            result[length] = resourceName
        end
    end

    return result
end

function saveBootloaderResourcesSetting()
    local resourceNameList = {}
    local length = 0

    for resourceName in pairs(settingsResourceDict) do
        if getResourceFromName(resourceName) then
            length = length + 1
            resourceNameList[length] = resourceName
        end
    end

    set("@resources", table.concat(resourceNameList, ","))
end

function toggleBootloaderResource(resourceName, enabled)
    if enabled and settingsResourceDict[resourceName] == nil then
        settingsResourceDict[resourceName] = true
        saveBootloaderResourcesSetting()
    elseif not enabled and settingsResourceDict[resourceName] ~= nil then
        settingsResourceDict[resourceName] = nil
        saveBootloaderResourcesSetting()
    end
end

--------------------------------------------------------------------------------
-- Access control and session management
--------------------------------------------------------------------------------
local activePlayerSessions = {}

function getPlayerSession(player)
    return activePlayerSessions[player]
end

function clearPlayerSession(player)
    local session = activePlayerSessions[player]
    activePlayerSessions[player] = nil

    if session then
        stopSessionDataTransfers(session)
    end
end

function onPlayerBootloaderCommand(player)
    local enabled = false

    if activePlayerSessions[player] ~= nil then
        activePlayerSessions[player] = nil
    else
        activePlayerSessions[player] = {}
        enabled = true
    end

    triggerClientEvent(player, "Bootloader.toggleConfigurationPanel", resourceRoot, enabled)
end
addCommandHandler("bootloader", onPlayerBootloaderCommand, true, false)

function onPlayerQuit()
    clearPlayerSession(source)
end
addEventHandler("onPlayerQuit", root, onPlayerQuit)

function onClientBootloaderClosePanel()
    clearPlayerSession(client)
end
addEvent("BootloaderClient.closePanel", true)
addEventHandler("BootloaderClient.closePanel", resourceRoot, onClientBootloaderClosePanel, false)

function isPlayerBootloaderAuthorized(player)
    return activePlayerSessions[player] ~= nil
end

--------------------------------------------------------------------------------
-- Data stream events
--------------------------------------------------------------------------------
function stopSessionDataTransfers(session)
    stopSessionResourceDataListTransfer(session)
end

function onClientBootloaderResourceDataListRequest()
    sendPlayerBootloaderResourceDataList(client)
end
addEvent("BootloaderClient.requestResourceDataList", true)
addEventHandler("BootloaderClient.requestResourceDataList", resourceRoot, onClientBootloaderResourceDataListRequest, false)

function onClientBootloaderToggleResource(resourceName, enabled)
    if type(resourceName) ~= "string" or resourceName == "" then
        return
    end

    if type(enabled) ~= "boolean" then
        return
    end

    local resource = getResourceFromName(resourceName)

    if not resource then
        return sendPlayerBootloaderResourceDataList(client)
    end

    if not isPlayerBootloaderAuthorized(client) then
        return
    end

    toggleBootloaderResource(resourceName, enabled)
    enabled = isBootloaderResource(resourceName)

    outputServerLog(("BOOTLOADER: Resource '%s' has been %s by player '%s' (account: %s, ip: %s, serial: %s)"):format(
        resourceName,
        (enabled and "enabled" or "disabled"),
        getPlayerName(client),
        getAccountName(getPlayerAccount(client)),
        getPlayerIP(client),
        getPlayerSerial(client)
    ))

    local resourceState = getResourceState(resource)

    if resourceState == "loaded" and enabled then
        startResource(resource, true)
    elseif resourceState == "running" and not enabled then
        stopResource(resource)
    end

    setTimer(sendPlayerBootloaderResourceData, 100, 1, client, resourceName)
end
addEvent("BootloaderClient.toggleBootloaderResource", true)
addEventHandler("BootloaderClient.toggleBootloaderResource", resourceRoot, onClientBootloaderToggleResource, false)

function stopSessionResourceDataListTransfer(session)
    local transfer = session.resourcesBatchTransfer
    session.resourcesBatchTransfer = nil

    if transfer ~= nil then
        if isTimer(transfer.timer) then
            killTimer(transfer.timer)
        end
    end
end

function sendPlayerResourceDataListThread(player, session, transfer)
    local length = #transfer.resources

    if length > 0 then
        local index = 1

        while index <= length do
            local batch = {}
            local batchLength = 0
            local batchSize = 5

            while index <= length and batchLength < batchSize do
                local resource = transfer.resources[index]
                index = index + 1

                if getUserdataType(resource) == "resource-data" then
                    local resourceName = getResourceName(resource)

                    local data = {
                        enabled     = transfer.enableds[resourceName] ~= nil,
                        running     = getResourceState(resource) == "running",
                        name        = resourceName,
                        type        = getResourceInfo(resource, "type"),
                        description = getResourceInfo(resource, "description"),
                    }

                    batchLength = batchLength + 1
                    batch[batchLength] = data
                end
            end

            if batchLength > 0 then
                triggerClientEvent(player, "Bootloader.resourceDataListBatch", resourceRoot, batch)
                coroutine.yield()
            end
        end
    end

    triggerClientEvent(player, "Bootloader.resourceDataListComplete", resourceRoot)
    stopSessionResourceDataListTransfer(session)
end

function sendPlayerBootloaderResourceDataList(player)
    local session = getPlayerSession(player)

    if session == nil then
        return
    end

    stopSessionResourceDataListTransfer(session)

    local coroutine = coroutine.wrap(sendPlayerResourceDataListThread)

    local transfer = {
        resources = getResourcesSnapshot(),
        enableds = table.shallowcopy(getBootloaderResourceNamesDict()),
        coroutine = coroutine,
        timer = setTimer(coroutine, 100, 0),
    }

    session.resourcesBatchTransfer = transfer

    coroutine(player, session, transfer)
end

function sendPlayerBootloaderResourceData(player, resourceName)
    if not isPlayerBootloaderAuthorized(player) then
        return
    end

    local resource = getResourceFromName(resourceName)

    if not resource then
        return sendPlayerBootloaderResourceDataList(player)
    end

    local enabled = isBootloaderResource(resourceName)
    local running = getResourceState(resource) == "running"
    triggerClientEvent(player, "Bootloader.resourceDataResponse", resourceRoot, resourceName, enabled, running)
end

--------------------------------------------------------------------------------
-- Utility and extension functions
--------------------------------------------------------------------------------
function getResourcesSnapshot()
    local thisResource = getThisResource()
    local resources = getResources()
    local snapshot = {}
    local snapshotLength = 0
    local showGamemodes = getBool("showGamemodes", false)
    local showMaps = getBool("showMaps", false)
    local showRaceAddons = getBool("showRaceAddons", true)
    
    for i = 1, #resources do
        local resource = resources[i]
        
        if resource ~= thisResource then
            local include = true
            local resourceType = getResourceInfo(resource, "type")
            local resourceAddon = getResourceInfo(resource, "addon")

            if resourceType == "gamemode" and not showGamemodes then
                include = false
            elseif resourceType == "map" and not showMaps then
                include = false
            elseif resourceAddon == "race" and not showRaceAddons then
                include = false
            end
            
            if include then
                snapshotLength = snapshotLength + 1
                snapshot[snapshotLength] = resource
            end
        end
    end

    return snapshot
end

function utf8.trim(self)
    assert(type(self) == "string", "expected string at argument 1, got ".. type(self))
    local from = utf8.match(self, "^%s*()")
    return from > utf8.len(self) and "" or utf8.match(self, ".*%S", from)
end

function table.shallowcopy(input)
    local result = {}

    for key, value in pairs(input) do
        result[key] = value
    end

    return result
end

function getBool(settingName, defaultValue)
    local value = get(settingName)
    
    if value == false then
        return defaultValue
    else
        return value == "true"
    end
end
