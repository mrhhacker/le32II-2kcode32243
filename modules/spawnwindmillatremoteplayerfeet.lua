local function createSpawnWindmillNearRemotePlayerModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runSpawnWindmillNearRemotePlayer(feature)
        if not (isDev or isAdmin or isSupporter) then
            notify("This feature is for Supporters")
            return false
        end
        local targetPlayerId = feature:GetPlayerIndex()
        local windmillModelHash = Utils.Joaat("prop_windmill_01")
        if not STREAMING.IS_MODEL_VALID(windmillModelHash) then
            notify("Windmill spawning failed: model unavailable.")
            return false
        end
        STREAMING.REQUEST_MODEL(windmillModelHash)
        local modelLoadAttempts = 0
        while not STREAMING.HAS_MODEL_LOADED(windmillModelHash) and modelLoadAttempts < 500 do
            STREAMING.REQUEST_MODEL(windmillModelHash)
            Script.Yield(10)
            modelLoadAttempts = modelLoadAttempts + 1
        end
        if not STREAMING.HAS_MODEL_LOADED(windmillModelHash) then
            STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(windmillModelHash)
            notify("Windmill spawning failed: model load timed out.")
            return false
        end

        local windmillSpawned = false
        GTA.ForceScriptHost(Utils.Joaat("main_persistent"))
        local function spawnWindmillAsPersistentScript()
            local playerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
            if playerPed == nil or playerPed == 0 or not ENTITY.DOES_ENTITY_EXIST(playerPed) then
                return
            end
            local playerX, playerY, playerZ = ENTITY.GET_ENTITY_COORDS(playerPed, true)
            if type(playerX) ~= "number" or type(playerY) ~= "number" or type(playerZ) ~= "number" then
                return
            end

            local windmill = GTA.CreateWorldObject(windmillModelHash, playerX + 1, playerY + 38, playerZ - 2.5, true, true)
            if windmill ~= 0 and ENTITY.DOES_ENTITY_EXIST(windmill) then
                table.insert(yeetwindmills, windmill)
                windmillSpawned = true
                ENTITY.SET_ENTITY_LOD_DIST(windmill, 100000)
                if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(windmill) then
                    NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(windmill)
                    local controlWaitAttempts = 0
                    while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(windmill) and controlWaitAttempts < 50 do
                        Script.Yield(10)
                        controlWaitAttempts = controlWaitAttempts + 1
                    end
                end
                ENTITY.FREEZE_ENTITY_POSITION(windmill, true)
            end
        end
        Script.ExecuteAsScript("main_persistent", spawnWindmillAsPersistentScript)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(windmillModelHash)
        notify(windmillSpawned and "Windmill spawned." or "Windmill spawning failed.")
        return windmillSpawned
    end

    local spawnWindmillNearRemotePlayerRunner = { variant = "donator", feature = "SpawnWindmillAtRemotePlayerFeet", slug = "spawnwindmillatremoteplayerfeet" }

    function spawnWindmillNearRemotePlayerRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSpawnWindmillNearRemotePlayer(runContext.feature)
    end

    return spawnWindmillNearRemotePlayerRunner
end

return createSpawnWindmillNearRemotePlayerModule
