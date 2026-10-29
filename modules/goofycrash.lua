local function createSpoofedVehicleControlCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function removeRegisteredVehicleIds(vehicleIds, idsToRemove)
        for vehicleIndex = #vehicleIds, 1, -1 do
            if idsToRemove[vehicleIds[vehicleIndex]] then
                table.remove(vehicleIds, vehicleIndex)
            end
        end
    end

    local function runSpoofedVehicleControlCrash(playerFeature, onRemovalComplete)
        local targetPlayerId = playerFeature:GetPlayerIndex()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == GTA.GetLocalPlayerId() or targetPlayerId == nil or not (isSupporter or isAdmin) then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)! @everyone"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(targetPlayerId)
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
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetIpAddress = Players.GetIP(targetPlayerId):ToString(false)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Goofy Goober Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(targetPlayerId), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend),
                targetIpInfo.country, targetIpInfo.continent, targetIpAddress
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        local spawnedVehicles = {}
        local spoofTargetPlayerId = playerFeature:GetPlayerIndex()
        spoofedPid[spoofTargetPlayerId] = true
        local registeredVehicleIds = {}
        local cleanupGuard = setmetatable({}, {
            __close = function()
                spoofedPid[spoofTargetPlayerId] = false
                removeRegisteredVehicleIds(spoofedVehicle, registeredVehicleIds)
            end,
        })

        for spawnIndex = 0, 5 do
            local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(playerFeature:GetPlayerIndex())
            local spawnX, spawnY, spawnZ = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, 3, 0)
            local vehicleModelHash = Utils.Joaat(randomCars[math.random(1, #randomCars)])
            local spawnedVehicle = GTA.SpawnVehicle(vehicleModelHash, spawnX, spawnY, spawnZ + 200, 0, true, true)
            local waitAttempt = 0
            if not spawnedVehicle then
                notify("Goofy Goober Crash failed #1, Try again!")
                return
            end
            local vehiclePointer = GTA.HandleToPointer(spawnedVehicle)
            while true do
                if vehiclePointer and vehiclePointer.NetObject then
                    break
                end
                if ShouldUnload() then
                    break
                end
                if waitAttempt >= 20 then
                    notify("Goofy Goober Crash failed #2, Be near them!")
                    DeleteEnt(spawnedVehicle)
                    return
                end
                waitAttempt = waitAttempt + 1
                Script.Yield(15)
            end
            if ShouldUnload() or not vehiclePointer or not vehiclePointer.NetObject then
                DeleteEnt(spawnedVehicle)
                return
            end
            table.insert(spoofedVehicle, vehiclePointer.NetObject.ObjectID)
            registeredVehicleIds[vehiclePointer.NetObject.ObjectID] = true
            table.insert(spawnedVehicles, spawnedVehicle)
            for controlAttempt = 0, 5 do
                GTA.GiveControl(spoofTargetPlayerId, spawnedVehicle)
            end
            Script.Yield(350)
        end
        Script.Yield(10000)
        if type(onRemovalComplete) == "function" then
            onRemovalComplete()
        end
        for vehicleIndex = 0, #spawnedVehicles do
            DeleteEnt(spawnedVehicles[vehicleIndex])
            Script.Yield(20)
        end
    end

    local spoofedVehicleControlCrashRunner = { variant = "donator", feature = "goofycrash", slug = "goofycrash" }

    function spoofedVehicleControlCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSpoofedVehicleControlCrash(runContext.feature, runContext.__ksRemovalComplete)
    end

    return spoofedVehicleControlCrashRunner
end

return createSpoofedVehicleControlCrashModule
