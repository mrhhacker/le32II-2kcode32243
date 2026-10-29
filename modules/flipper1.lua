local function createArenaFlipperSpawnLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runArenaFlipperSpawnLoop(feature)
        local targetPlayerId = feature:GetPlayerIndex()
        local flipperModelHash = Utils.Joaat("xs_prop_arena_flipper_xl_01a")
        request_model(flipperModelHash)
        local spawnedFlippers = {}

        while feature:IsToggled() do
            local targetPosition = getPlayerPosition(targetPlayerId)
            if #spawnedFlippers > 8 then
                local oldestFlipper = table.remove(spawnedFlippers, 1)
                DeleteEnt(oldestFlipper)
            end

            local flipper = GTA.CreateObject(flipperModelHash, targetPosition.x, targetPosition.y, targetPosition.z - 13.5, true, true)
            if ENTITY.DOES_ENTITY_EXIST(flipper) then
                table.insert(spawnedFlippers, flipper)
            end
            Script.Yield(200)
        end

        for _, flipper in ipairs(spawnedFlippers) do
            DeleteEnt(flipper)
        end
    end

    local arenaFlipperSpawnLoopRunner = { variant = "donator", feature = "flipper1", slug = "flipper1" }

    function arenaFlipperSpawnLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runArenaFlipperSpawnLoop(runContext.feature)
    end

    return arenaFlipperSpawnLoopRunner
end

return createArenaFlipperSpawnLoopModule
