local function createSpoofedPedSyncCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runSpoofedPedSyncCrash(playerFeature)
        local targetPlayerId = Utils.GetSelectedPlayer()
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
            local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used TV Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(targetPlayerId), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        Script.QueueJob(logFeatureUse)
        local spoofTargetPlayerId = targetPlayerId
        spoofedPid[spoofTargetPlayerId] = true
        local targetPed = PLAYER.GET_PLAYER_PED(spoofTargetPlayerId)
        local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(targetPed, false)
        local spawnedPed = GTA.CreateRandomPed(targetX, targetY, targetZ)
        if type(spawnedPed) ~= "number" or spawnedPed == 0 then
            spoofedPid[spoofTargetPlayerId] = false
            return
        end
        local spawnedPedNetworkId = nil
        local cleanupGuard = setmetatable({}, {
            __close = function()
                if spawnedPedNetworkId ~= nil then
                    pcall(DeleteEnt, spawnedPedNetworkId)
                end
                pcall(DeleteEnt, spawnedPed)
                if spoofedPed == spawnedPedNetworkId then
                    spoofedPed = 0
                end
                spoofedPid[spoofTargetPlayerId] = false
            end,
        })
        local spawnedPedPointer = nil
        for waitAttempt = 1, 20 do
            if ShouldUnload() then
                return
            end
            spawnedPedPointer = GTA.HandleToPointer(spawnedPed)
            if spawnedPedPointer and spawnedPedPointer.NetObject then
                break
            end
            if waitAttempt < 20 then
                Script.Yield(15)
            end
        end
        if not spawnedPedPointer or not spawnedPedPointer.NetObject then
            return
        end
        spawnedPedNetworkId = spawnedPedPointer.NetObject.ObjectID
        if spawnedPedNetworkId == nil then
            return
        end
        spoofedPed = spawnedPedNetworkId
        TASK.TASK_COWER(spawnedPed, 5000)
        Script.Yield(10000)
    end

    local spoofedPedSyncCrashRunner = { variant = "donator", feature = "syncCrash", slug = "synccrash" }

    function spoofedPedSyncCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSpoofedPedSyncCrash(runContext.feature)
    end

    return spoofedPedSyncCrashRunner
end

return createSpoofedPedSyncCrashModule
