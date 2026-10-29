local function createTugBoatSpawnLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runTugBoatSpawnLoop(feature)
        if not feature:IsToggled() then
            return
        end
        local targetPlayerId = feature:GetPlayerIndex()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == GTA.GetLocalPlayerId() or targetPlayerId == nil or not (isSupporter or isAdmin) then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] and not isDev then
            blacklistSound()
            SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)! @everyone"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
            ))
            return
        end
        local function logTugSpawn()
            local playerTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(playerTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Lag em hoes! against %s with UID %i, isSupporter: %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), Players.GetName(Utils.GetSelectedPlayer()),
                Cherax.GetUID(), tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        log = logTugSpawn
        Script.QueueJob(log)

        local tugModelHash = Utils.Joaat("tug")
        request_model(tugModelHash)
        local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)))
        ENTITY.SET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId()), targetPosition.x, targetPosition.y, targetPosition.z + 200)
        ENTITY.FREEZE_ENTITY_POSITION(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId()), true)
        local spawnedTugs = {}
        while feature:IsToggled() do
            targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)))
            ENTITY.SET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId()), targetPosition.x, targetPosition.y, targetPosition.z + 200)
            for spawnIndex = 1, 10 do
                local tugBoat = GTA.SpawnVehicle(tugModelHash, targetPosition.x, targetPosition.y + 250, targetPosition.z + 350, 1, true, true)
                if ENTITY.DOES_ENTITY_EXIST(tugBoat) then
                    table.insert(spawnedTugs, tugBoat)
                end
                Script.Yield(0)
            end
            Script.Yield(600)
            for _, tugBoat in ipairs(spawnedTugs) do
                DeleteEnt(tugBoat, true)
                Script.Yield(0)
            end
        end
        ENTITY.FREEZE_ENTITY_POSITION(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId()), false)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(tugModelHash)
    end

    local tugBoatSpawnLoopRunner = { variant = "donator", feature = "tugLagger", slug = "tuglagger" }

    function tugBoatSpawnLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runTugBoatSpawnLoop(runContext.feature)
    end

    return tugBoatSpawnLoopRunner
end

return createTugBoatSpawnLoopModule
