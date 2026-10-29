local function createPyroFollowPlayerModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runPyroFollowPlayer(feature)
        local targetPlayerId = feature:GetPlayerIndex()
        local initialPosition = getPlayerPosition(targetPlayerId)
        local pyroModelHash = Utils.Joaat("pyro")
        request_model(pyroModelHash)
        local pyro = GTA.SpawnVehicle(pyroModelHash, initialPosition.x + 45, initialPosition.y, initialPosition.z + 125, -90, true, true)
        if ENTITY.DOES_ENTITY_EXIST(pyro) then
            setEntProofs(pyro)
            ENTITY.FREEZE_ENTITY_POSITION(pyro, true)
            VEHICLE.SET_VEHICLE_ENGINE_ON(pyro, true, true, false)
            VEHICLE.SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED(pyro, true)
        end

        Script.Yield(50)
        while feature:IsToggled() do
            local targetPosition = getPlayerPosition(targetPlayerId)
            if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(pyro) then
                request_control(pyro)
            end
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(pyro, targetPosition.x + 3, targetPosition.y, targetPosition.z, false, false, false)
            Script.Yield(50)
        end

        DeleteEnt(pyro)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pyroModelHash)
    end

    local pyroFollowPlayerRunner = { variant = "donator", feature = "pyroTroll1", slug = "pyrotroll1" }

    function pyroFollowPlayerRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runPyroFollowPlayer(runContext.feature)
    end

    return pyroFollowPlayerRunner
end

return createPyroFollowPlayerModule
