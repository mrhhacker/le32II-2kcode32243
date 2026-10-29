local function createCargoPlaneSpawnLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runCargoPlaneSpawnLoop(feature)
        local targetPlayerId = feature:GetPlayerIndex()
        local cargoPlaneModelHash = Utils.Joaat("cargoplane")
        request_model(cargoPlaneModelHash)

        while feature:IsToggled() do
            local targetPosition = getPlayerPosition(targetPlayerId)
            local cargoPlane = GTA.SpawnVehicle(Utils.Joaat("cargoplane"), targetPosition.x, targetPosition.y, targetPosition.z, 0, true, true)
            if ENTITY.DOES_ENTITY_EXIST(cargoPlane) then
                setEntProofs(cargoPlane)
                Script.Yield(500)
                DeleteEnt(cargoPlane)
            end
        end

        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(cargoPlaneModelHash)
    end

    local cargoPlaneSpawnLoopRunner = { variant = "donator", feature = "cargoglitch1", slug = "cargoglitch1" }

    function cargoPlaneSpawnLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runCargoPlaneSpawnLoop(runContext.feature)
    end

    return cargoPlaneSpawnLoopRunner
end

return createCargoPlaneSpawnLoopModule
