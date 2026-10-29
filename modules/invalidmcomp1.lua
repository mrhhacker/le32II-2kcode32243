local function createInvalidPedComponentSyncModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local terminalViolation = moduleContext.KSRuntimeTerminalViolation
    if type(terminalViolation) ~= "function" then
        error("player-feature terminal violation context invalid", 2)
    end

    local capabilities = moduleContext.KS_RUNTIME_CAPABILITIES
    local exclusiveSync = type(capabilities) == "table" and capabilities["feature_plane.exclusive_sync"] or nil
    local syncData = type(capabilities) == "table" and capabilities["feature_plane.sync_data"] or nil
    if not (
        type(exclusiveSync) == "table" and type(syncData) == "table"
        and exclusiveSync.provider == "m2" and syncData.provider == "m2"
        and exclusiveSync.generation == tonumber(moduleContext.KS_RUNTIME_LOAD_GENERATION)
        and syncData.generation == tonumber(moduleContext.KS_RUNTIME_LOAD_GENERATION)
        and exclusiveSync.active == true and syncData.active == true
    ) then
        error("invalidmcomp1 feature-plane capability contract invalid", 2)
    end
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}
    KSRuntimePlayerFeatureState.invalidMCompEntities = KSRuntimePlayerFeatureState.invalidMCompEntities or {}
    local trackedEntitiesByPlayer = KSRuntimePlayerFeatureState.invalidMCompEntities
    local pedModelName = "P_Michael_02"
    local requiredPedCount = 5
    local pedType = 28
    local requiredEmissionCount = 2
    local confirmationAttempts = 60
    local confirmationDelayMs = 50
    local maintenanceDelayMs = 250
    local componentSettings = {
        componentId = 3,
        componentIndex = 4,
        drawableId = 0,
        textureMin = 0,
        textureMax = 2,
        paletteId = 0,
        usedComponents = 8,
    }

    local function runInvalidPedComponentSync(componentFeature)
        if componentFeature == nil or not componentFeature:IsToggled() then
            return false
        end
        local targetPlayerId = componentFeature:GetPlayerIndex()
        local function disableFeature()
            componentFeature:SetValue(false)
            componentFeature:OnClick()
        end
        if type(targetPlayerId) ~= "number" or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            disableFeature()
            return false
        end
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            disableFeature()
            return false
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            disableFeature()
            return false
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if not targetGamerInfo then
            disableFeature()
            return false
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
                ))
                disableFeature()
                return false
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" and not isDev then
            blacklistSound("forbidden_protected_runtime_target")
            SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
            ))
            disableFeature()
            return false
        end
        local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
        local targetIsFriend = string.find(targetTags, "[F]", 1, true) ~= nil
        local targetName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        local function logComponentAttempt()
            local currentTargetTags = tostring(Players.GetTags(targetPlayerId) or "")
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetCountry = targetIpInfo and targetIpInfo.country or "Unknown"
            local targetContinent = targetIpInfo and targetIpInfo.continent or "Unknown"
            local targetIpObject = Players.GetIP(targetPlayerId)
            local targetIp = targetIpObject and targetIpObject:ToString(false) or "Unknown"
            local currentTargetIsFriend = string.find(currentTargetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Gas Chamber Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), targetName, Cherax.GetUID(),
                tostring(isSupporter), tostring(currentTargetIsFriend), tostring(targetCountry),
                tostring(targetContinent), tostring(targetIp)
            ))
        end
        Script.QueueJob(logComponentAttempt)
        if targetIsFriend and not isDev then
            terminalViolation("forbidden_friend_target")
            disableFeature()
            return false
        end
        onCrashCooldown = true
        local localPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId())
        local originalPosition = V3.New(ENTITY.GET_ENTITY_COORDS(localPed, false))
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(targetPed, true))
        local spawnedPeds = {}
        local trackedPeds = {}
        local registeredPedCount = 0
        trackedEntitiesByPlayer[targetPlayerId] = trackedPeds

        local function cleanupSpawnedPeds()
            for objectId, pedState in pairs(trackedPeds) do
                if pedState.networkId ~= nil and pedState.networkId ~= 0 then
                    NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(pedState.networkId, targetPlayerId, false)
                    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(pedState.networkId, true)
                end
            end
            trackedEntitiesByPlayer[targetPlayerId] = nil
            for pedIndex, spawnedPed in ipairs(spawnedPeds) do
                if spawnedPed ~= 0 and ENTITY.DOES_ENTITY_EXIST(spawnedPed) then
                    ENTITY.FREEZE_ENTITY_POSITION(spawnedPed, false)
                    DeleteEnt(spawnedPed)
                end
            end
            if localPed ~= 0 and ENTITY.DOES_ENTITY_EXIST(localPed) then
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, originalPosition.x, originalPosition.y, originalPosition.z, false, false, false)
            end
        end

        local function followTargetPosition()
            if not ENTITY.DOES_ENTITY_EXIST(targetPed) then
                return false
            end
            targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(targetPed, true))
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, targetPosition.x, targetPosition.y, targetPosition.z - 25, false, false, false)
            for pedIndex, spawnedPed in ipairs(spawnedPeds) do
                if spawnedPed == 0 or ENTITY.DOES_ENTITY_EXIST(spawnedPed) ~= true then
                    return false
                end
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(spawnedPed, targetPosition.x, targetPosition.y, targetPosition.z + 20, false, false, false)
            end
            return true
        end

        local function hasRequiredEmissions()
            for objectId, pedState in pairs(trackedPeds) do
                if pedState.emissionCount < requiredEmissionCount then
                    return false
                end
            end
            return true
        end

        local function cycleComponentTexture(cycleIndex)
            local textureCount = componentSettings.textureMax - componentSettings.textureMin + 1
            for objectId, pedState in pairs(trackedPeds) do
                if pedState.ped == 0 or ENTITY.DOES_ENTITY_EXIST(pedState.ped) ~= true then
                    return false
                end
                local textureId = componentSettings.textureMin + (cycleIndex - 1) % textureCount
                PED.SET_PED_COMPONENT_VARIATION(pedState.ped, componentSettings.componentId,
                    componentSettings.drawableId, textureId, componentSettings.paletteId)
            end
            return true
        end

        local function confirmAppearanceSync()
            for confirmationIndex = 1, confirmationAttempts do
                if not followTargetPosition() or not cycleComponentTexture(confirmationIndex) then
                    return false
                end
                Script.Yield(confirmationDelayMs)
                if hasRequiredEmissions() then
                    return true
                end
                if not componentFeature:IsToggled() or not ENTITY.DOES_ENTITY_EXIST(targetPed) then
                    return false
                end
            end
            return false
        end

        local pedModel = Utils.Joaat(pedModelName)
        if not STREAMING.IS_MODEL_VALID(pedModel) then
            notify("Gas Chamber failed: P_Michael_02 is unavailable.")
            trackedEntitiesByPlayer[targetPlayerId] = nil
            onCrashCooldown = false
            disableFeature()
            return false
        end
        STREAMING.REQUEST_MODEL(pedModel)
        local modelLoadAttempts = 0
        while not STREAMING.HAS_MODEL_LOADED(pedModel) and modelLoadAttempts < 500 do
            STREAMING.REQUEST_MODEL(pedModel)
            Script.Yield(10)
            modelLoadAttempts = modelLoadAttempts + 1
        end
        if not STREAMING.HAS_MODEL_LOADED(pedModel) then
            notify("Gas Chamber failed: P_Michael_02 did not load.")
            STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedModel)
            trackedEntitiesByPlayer[targetPlayerId] = nil
            onCrashCooldown = false
            disableFeature()
            return false
        end
        if not followTargetPosition() then
            cleanupSpawnedPeds()
            STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedModel)
            onCrashCooldown = false
            notify("Gas Chamber failed: target became unavailable.")
            disableFeature()
            return false
        end
        for pedIndex = 1, requiredPedCount do
            local spawnedPed = GTA.CreatePed(pedModel, pedType, targetPosition.x, targetPosition.y,
                targetPosition.z + 20, ENTITY.GET_ENTITY_HEADING(targetPed), true, false)
            if spawnedPed == nil or spawnedPed == 0 or not ENTITY.DOES_ENTITY_EXIST(spawnedPed) then
                break
            end
            spawnedPeds[#spawnedPeds + 1] = spawnedPed
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(spawnedPed, true, true)
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(spawnedPed, targetPosition.x, targetPosition.y, targetPosition.z + 20, false, false, false)
            local pedObjectId = nil
            local pedNetworkId = nil
            for networkAttempt = 1, 200 do
                if not followTargetPosition() then
                    break
                end
                local pedPointer = GTA.HandleToPointer(spawnedPed)
                local networkObject = pedPointer and pedPointer.NetObject or nil
                local candidateObjectId = networkObject and networkObject.ObjectID or nil
                if not candidateObjectId then
                    pedObjectId = nil
                end
                pedNetworkId = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(spawnedPed)
                if pedObjectId ~= nil and pedNetworkId ~= nil and pedNetworkId ~= 0 then
                    break
                end
                Script.Yield(10)
            end
            if pedObjectId == nil or pedNetworkId == nil or pedNetworkId == 0 then
                break
            end
            NETWORK.SET_NETWORK_ID_CAN_MIGRATE(pedNetworkId, false)
            NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(pedNetworkId, targetPlayerId, true)
            trackedPeds[pedObjectId] = {
                ped = spawnedPed,
                networkId = pedNetworkId,
                componentId = componentSettings.componentId,
                componentIndex = componentSettings.componentIndex,
                drawableId = componentSettings.drawableId,
                textureMin = componentSettings.textureMin,
                textureMax = componentSettings.textureMax,
                paletteId = componentSettings.paletteId,
                usedComponents = componentSettings.usedComponents,
                emissionCount = 0,
            }
            registeredPedCount = registeredPedCount + 1
        end
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedModel)
        if #spawnedPeds ~= requiredPedCount or registeredPedCount ~= requiredPedCount then
            cleanupSpawnedPeds()
            onCrashCooldown = false
            notify("Gas Chamber failed: could not network all 5 P_Michael_02 peds.")
            disableFeature()
            return false
        end
        if not confirmAppearanceSync() then
            cleanupSpawnedPeds()
            onCrashCooldown = false
            notify("Gas Chamber failed: appearance sync was not confirmed.")
            disableFeature()
            return false
        end
        local cycleIndex = confirmationAttempts + 1
        while componentFeature:IsToggled() do
            if not followTargetPosition() or not cycleComponentTexture(cycleIndex) then
                break
            end
            cycleIndex = cycleIndex + 1
            Script.Yield(maintenanceDelayMs)
        end
        cleanupSpawnedPeds()
        onCrashCooldown = false
        if componentFeature:IsToggled() then
            disableFeature()
        end
        return true
    end

    local invalidPedComponentSyncRunner = { variant = "donator", feature = "InvalidMComp1", slug = "invalidmcomp1" }

    function invalidPedComponentSyncRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runInvalidPedComponentSync(runContext.feature)
    end

    return invalidPedComponentSyncRunner
end

return createInvalidPedComponentSyncModule
