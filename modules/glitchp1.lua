local function createPropTrailerSpawnLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runPropTrailerSpawnLoop(feature)
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

        local function logTrailerSpawn()
            local playerTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(playerTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Yeet from Existence against %s with UID %i, isSupporter: %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), Players.GetName(Utils.GetSelectedPlayer()),
                Cherax.GetUID(), tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        log = logTrailerSpawn
        Script.QueueJob(log)

        local trailerModelHash = Utils.Joaat("proptrailer")
        local spawnedTrailers = {}
        request_model(trailerModelHash)
        while feature:IsToggled() do
            local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
            local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId))
            local spawnX = targetX + math.random(-2, 2)
            local spawnY = targetY + math.random(-2, 2)
            local spawnZ = targetZ + math.random(-1, 1)
            for spawnIndex = 1, 12 do
                local trailer = GTA.SpawnVehicle(trailerModelHash, spawnX, spawnY, spawnZ, math.random(0, 360), true, true)
                if ENTITY.DOES_ENTITY_EXIST(trailer) then
                    request_control(trailer)
                    ENTITY.SET_ENTITY_INVINCIBLE(trailer, true)
                    table.insert(spawnedTrailers, trailer)
                end
            end
            Script.Yield(125)
            for trailerIndex = 1, #spawnedTrailers do
                local trailer = spawnedTrailers[trailerIndex]
                if ENTITY.DOES_ENTITY_EXIST(trailer) then
                    DeleteEnt(trailer)
                end
            end
            Script.Yield(15)
        end
        spawnedTrailers = nil
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(trailerModelHash)
    end

    local propTrailerSpawnLoopRunner = { variant = "donator", feature = "glitchP1", slug = "glitchp1" }

    function propTrailerSpawnLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runPropTrailerSpawnLoop(runContext.feature)
    end

    return propTrailerSpawnLoopRunner
end

return createPropTrailerSpawnLoopModule
